// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IETF} from "../Interfaces/IETF.sol";
import {BaseStorageETF} from "../base/BaseStorageETF.sol";
import {Blacklistable} from "../BlackList/Blacklistable.sol";

contract MyERC20Upgradeable is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    BaseStorageETF,
    Blacklistable
{
    using SafeERC20 for IERC20;
    // ========== 角色定义 ==========
    bytes32 public constant ETF_ADMIN = keccak256("ETF_ADMIN");
    uint256 public constant MIN_AMOUNT = 1e16; // 0.01 in 18 decimals

    // subscriptionId => SubscribeData
    mapping(uint256 => SubscribeData) private _subscribeDataMap;

    // redemptionId => redemptionData
    mapping(uint256 => RedemptionData) private _redemptionDataMap;

    // tokenId => TokenData
    mapping(uint256 => TokenData) private _tokenDataMap;

    // Address → List of owned token IDs
    mapping(address => uint256[]) private _tokenList;

    // Address → Token ID → Token amount
    mapping(address => mapping(uint256 => uint256)) private _tokenMap;

    uint256 public nextId;

    uint256 private _totalSupply;

    uint256 public MIN_SUBSCRIPTION_USD_AMOUNT; // Minimum subscription amount (100 USDT/USDC with 6 decimals)

    uint256 public MIN_REDEMPTION_CASH_AMOUNT; // Minimum redemption amount (0.948 Cash+ with 18 decimals)

    modifier checkUSDAmount(uint256 uAmount, uint8 dec) {
        if (MIN_SUBSCRIPTION_USD_AMOUNT > 0) {
            if (uAmount < MIN_SUBSCRIPTION_USD_AMOUNT * 10 ** dec) {
                revert BelowMinAmount();
            }
        }
        // if (MAX_SUBSCRIPTION_USD_AMOUNT > 0) {
        //     require(
        //         uAmount <= MAX_SUBSCRIPTION_USD_AMOUNT * 10 ** dec,
        //         "Exceeds max subscription"
        //     );
        // }
        _;
    }

    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ETF_ADMIN, _msgSender());
    }

    function pause() public onlyRole(ETF_ADMIN) {
        _pause();
    }

    function unpause() public onlyRole(ETF_ADMIN) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Allows a user to subscribe on-chain by transferring USDT/USDC to the contract.
     * @param uAddress The address of the USDT/USDC token.
     * @param uAmount The amount of USDT/USDC to subscribe.
     * @param source The source identifier for the subscription.
     */
    function onChainSubscribe(
        address uAddress,
        uint256 uAmount,
        uint16 source
    )
        external
        notBlacklisted(msg.sender)
        checkUSDAmount(uAmount, IERC20Metadata(uAddress).decimals())
        whenNotPaused
        nonReentrant
    {
        if (!containsAddress(uAddress)) {
            revert UnSupportedTokenAddress();
        }
        uint256 balanceBefore = IERC20(uAddress).balanceOf(address(this));
        IERC20(uAddress).safeTransferFrom(msg.sender, address(this), uAmount);
        uint256 balanceAfter = IERC20(uAddress).balanceOf(address(this));
        uAmount = balanceAfter - balanceBefore;

        nextId++;
        uint256 subscriptionId = uint256(
            keccak256(
                abi.encodePacked(
                    uAddress,
                    uAmount,
                    msg.sender,
                    block.timestamp,
                    block.prevrandao,
                    nextId
                )
            )
        );

        SubscribeData storage sd = _subscribeDataMap[subscriptionId];
        sd.id = subscriptionId;
        sd.uAmount = uAmount;
        sd.uAddress = uAddress;
        sd.source = source;
        sd.user = msg.sender;

        emit onChainSubscribeEvent(
            subscriptionId,
            uAmount,
            uAddress,
            msg.sender,
            source
        );
    }

    /**
     * @notice Updates an existing on-chain subscription.
     * @param subscriptionId The ID of the subscription to update.
     * @param price The new price for the subscription.
     * @param stokenAmount The new stoken amount for the subscription.
     * @param time The new time for the subscription.
     * @param udaTxHash The new UDA transaction hash for the subscription.
     * @param offChainId The off-chain identifier for the subscription.
     */
    function updateOnChainSubscribe(
        uint256 subscriptionId,
        uint256 price,
        uint256 stokenAmount,
        uint256 costAmount,
        uint256 time,
        bytes32 udaTxHash,
        string memory offChainId
    )
        external
        onlyRole(ETF_ADMIN)
        notBlacklisted(_subscribeDataMap[subscriptionId].user)
        whenNotPaused
    {
        require(
            stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        );
        require(
            _subscribeDataMap[subscriptionId].id != 0,
            "Subscription does not exist"
        );

        SubscribeData storage sd = _subscribeDataMap[subscriptionId];
        require(
            costAmount > 0 && costAmount <= sd.uAmount,
            "Invalid cost amount"
        );

        sd.stokenAmount = stokenAmount;
        sd.price = price;
        sd.time = time;
        sd.refundAmount = sd.uAmount - costAmount;
        sd.udaTxHash = udaTxHash;

        IERC20(sd.uAddress).safeTransfer(assetRecipient, costAmount);

        emit updateOnChainSubscribeEvent(
            subscriptionId,
            stokenAmount,
            costAmount,
            sd.refundAmount,
            price,
            time,
            udaTxHash,
            offChainId
        );
    }

    function executeSubscribe(
        uint256 subscriptionId
    )
        public
        onlyRole(ETF_ADMIN)
        notBlacklisted(_subscribeDataMap[subscriptionId].user)
        whenNotPaused
    {
        uint256 tokenId = _mintStoken(subscriptionId);
        SubscribeData memory sd = _subscribeDataMap[subscriptionId];
        emit executeEvent(
            subscriptionId,
            sd.uAmount,
            sd.uAddress,
            sd.stokenAmount,
            sd.user,
            sd.price,
            sd.time,
            sd.udaTxHash,
            sd.source,
            tokenId
        ); // Emit event for execution
        delete _subscribeDataMap[subscriptionId];
    }

    function claim(uint256 orderId) external nonReentrant {}

    // Mint tokens for a specified subscription ID
    // This function allows the admin to mint tokens based on a subscription.
    // It checks if the subscription ID is valid and retrieves the subscription data.
    // It then adds new token data and updates the user's token list and map.
    function _mintStoken(uint256 subscriptionId) internal returns (uint256) {
        SubscribeData storage sub = _subscribeDataMap[subscriptionId];
        require(sub.id != 0, "Subscription does not exist");
        require(
            sub.stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        );
        require(sub.user != address(0), "Invalid user address");
        require(sub.price > 0, "Invalid price");
        require(sub.time > 0, "Invalid time");
        uint256 tokenId = _addNewTokenData(
            sub.user,
            sub.stokenAmount,
            sub.price,
            sub.time
        );
        return tokenId;
    }

    function _addNewTokenData(
        address user,
        uint256 stokenAmount,
        uint256 price,
        uint256 time
    ) internal returns (uint256) {
        nextId++;
        uint256 tokenId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    block.timestamp,
                    block.prevrandao,
                    nextId
                )
            )
        );
        TokenData memory newTokenData = TokenData({
            id: tokenId,
            mintTime: time,
            mintPrice: price,
            tokenOwner: user
        });

        _tokenDataMap[tokenId] = newTokenData;
        _tokenList[user].push(tokenId);
        _tokenMap[user][tokenId] += stokenAmount;
        _totalSupply += stokenAmount;

        emit Transfer(address(0), user, stokenAmount);
        return tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                              Blacklist
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds account to blacklist.
     * @param _account The address to blacklist.
     */
    function blacklist(address _account) external onlyRole(ETF_ADMIN) {
        _blacklist(_account);
        emit Blacklisted(_account);
    }

    /**
     * @notice Removes account from blacklist.
     * @param _account The address to remove from the blacklist.
     */
    function unBlacklist(address _account) external onlyRole(ETF_ADMIN) {
        _unBlacklist(_account);
        emit UnBlacklisted(_account);
    }

    /**
     * @inheritdoc Blacklistable
     */
    function _blacklist(address _account) internal override {
        _setBlacklistState(_account, true);
    }

    /**
     * @inheritdoc Blacklistable
     */
    function _unBlacklist(address _account) internal override {
        _setBlacklistState(_account, false);
    }

    /**
     * @dev Helper method that sets the blacklist state of an account.
     * @param _account         The address of the account.
     * @param _shouldBlacklist True if the account should be blacklisted, false if the account should be unblacklisted.
     */
    function _setBlacklistState(
        address _account,
        bool _shouldBlacklist
    ) internal virtual {
        _deprecatedBlacklisted[_account] = _shouldBlacklist;
    }

    /**
     * @inheritdoc Blacklistable
     */
    function _isBlacklisted(
        address _account
    ) internal view virtual override returns (bool) {
        return _deprecatedBlacklisted[_account];
    }
}
