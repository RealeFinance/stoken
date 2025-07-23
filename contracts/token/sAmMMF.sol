// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/ISAmMMF.sol";
import {Blacklistable} from "../BlackList/Blacklistable.sol";

contract SAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    ISAmMMF,
    Blacklistable
{
    using SafeERC20 for IERC20;
    bytes32 public constant VERSION = keccak256("VERSION_2");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant STOKEN_ADMIN = keccak256("STOKEN_ADMIN");

    // Asset recipient address
    address public assetRecipient;

    // Technical Service Fee (%) 10 ==> 0.1%  50 ==> 0.5%  100 ==> 1%
    uint256 private technicalServiceFeeRate;

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

    // List of supported USDT/USDC address
    address[] private supportedTokenAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init(name);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(BLACKLIST_ADMIN_ROLE, msg.sender);
        blacklister = msg.sender; // Set the initial blacklister to the deployer

        assetRecipient = address(this); // Set the asset recipient to this contract address
        technicalServiceFeeRate = 10; // Default technical service fee rate set to 0.1%
        supportedTokenAddress.push(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC address on Ethereum mainnet
        supportedTokenAddress.push(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT address on Ethereum mainnet
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    /**
     * @dev Set the technical service fee rate.
     * @param newRate The new fee rate (in percent).
     */
    function setTechnicalServiceFeeRate(
        uint256 newRate
    ) external onlyRole(STOKEN_ADMIN) {
        technicalServiceFeeRate = newRate;
    }

    /**
     * @dev Get the current technical service fee rate.
     * @return The current fee rate (in percent).
     */
    function getTechnicalServiceFeeRate() external view returns (uint256) {
        return technicalServiceFeeRate;
    }

    /**
     * @dev Set the asset recipient address.
     * @param newRecipient The new asset recipient address.
     */
    function setAssetRecipient(
        address newRecipient
    ) external onlyRole(STOKEN_ADMIN) {
        require(newRecipient != address(0), "Invalid address");
        address oldRecipient = assetRecipient;
        assetRecipient = newRecipient;
        emit AssetRecipientUpdated(oldRecipient, newRecipient); // Emit event for asset recipient update
    }

    /**
     * @dev Get the current asset recipient address.
     * @return The asset recipient address.
     */
    function getAssetRecipient() external view returns (address) {
        return assetRecipient;
    }

    /**
     * @dev Subscribe to the service with USDT/USDC on-chain.
     * @param uAddress The address of the USDT/USDC contract.
     * @param uAmount The amount of USDT/USDC to subscribe.
     */
    function onChainSubscribe(
        address uAddress,
        uint256 uAmount
    ) external notBlacklisted(msg.sender) whenNotPaused {
        require(uAmount > 0, "Amount must be greater than zero");
        require(containsAddress(uAddress), "Unsupported token address");

        IERC20(uAddress).safeTransferFrom(msg.sender, assetRecipient, uAmount); // Transfer USDT from the user to this contract

        uint256 subscriptionId = uint256(
            keccak256(
                abi.encodePacked(
                    uAddress,
                    uAmount,
                    block.timestamp,
                    block.prevrandao
                )
            )
        );

        _subscribeDataMap[subscriptionId] = SubscribeData({
            id: subscriptionId,
            uAmount: uAmount,
            uAddress: uAddress,
            stokenAmount: 0, // Initial stoken amount is zero
            user: msg.sender,
            price: 0, // Initial price is zero
            time: bytes32(0), // Initial time is zero
            transactionHash: 0 // Initial transaction hash is zero
        });

        emit onChainSubscribeEvent(
            subscriptionId,
            uAmount,
            uAddress,
            msg.sender
        ); // Emit event for off-chain subscription
    }

    /**
     * @dev Overwrite on-chain subscription data.
     * @param subscriptionId The ID of the subscription to overwrite.
     * @param uAmount The amount of USDT/USDC to subscribe.
     * @param uAddress The address of the USDT/USDC contract.
     * @param stokenAmount The amount of stoken to subscribe.
     * @param user The user address who subscribed.
     * @param price The price of the subscription.
     * @param time The subscription time.
     * @param transactionHash The transaction hash for the subscription.
     * @param offChainId The off-chain identifier for the subscription.
     */
    function overwriteOnChainSubscribe(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        bytes32 transactionHash,
        string memory offChainId
    ) external onlyRole(STOKEN_ADMIN) notBlacklisted(user) whenNotPaused {
        require(subscriptionId != 0, "Invalid subscription ID");
        require(user != address(0), "Invalid user address");
        require(stokenAmount > 0, "Stoken amount must be greater than zero");

        _subscribeDataMap[subscriptionId] = SubscribeData({
            id: subscriptionId,
            uAmount: uAmount,
            uAddress: uAddress,
            stokenAmount: stokenAmount,
            user: user,
            price: price,
            time: time,
            transactionHash: transactionHash
        });

        emit overwriteOnChainSubscribeEvent(
            subscriptionId,
            uAmount,
            uAddress,
            stokenAmount,
            user,
            price,
            time,
            transactionHash,
            offChainId
        ); // Emit event for subscription
    }

    /**
     * @dev Subscribe to the service with USDT and stoken amounts.
     * @param uAmount The amount of USDT to subscribe.
     * @param uAddress The address of the USDT contract.
     * @param stokenAmount The amount of stoken to subscribe.
     * @param user The user address who subscribed.
     * @param price The price of the subscription.
     * @param time The subscription time.
     * @param transactionHash The transaction hash for the subscription.
     * @param offChainId The off-chain identifier for the subscription.
     */
    function subscribe(
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        bytes32 transactionHash,
        string memory offChainId
    ) external onlyRole(STOKEN_ADMIN) notBlacklisted(user) whenNotPaused {
        require(user != address(0), "Invalid user address");
        require(stokenAmount > 0, "Stoken amount must be greater than zero");
        uint256 subscriptionId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    uAmount,
                    uAddress,
                    stokenAmount,
                    price,
                    time,
                    block.timestamp,
                    block.prevrandao
                )
            )
        );
        _subscribeDataMap[subscriptionId] = SubscribeData({
            id: subscriptionId,
            uAmount: uAmount,
            uAddress: uAddress,
            stokenAmount: stokenAmount,
            user: user,
            price: price,
            time: time,
            transactionHash: transactionHash
        });
        emit subscribeEvent(
            subscriptionId,
            uAmount,
            uAddress,
            stokenAmount,
            user,
            price,
            time,
            transactionHash,
            offChainId
        ); // Emit event for subscription
    }

    /**
     * @dev Handle on-chain redemption with USDT/USDC.
     * @param uAddress The address of the USDT/USDC contract.
     * @param stokenAmount The amount of stoken to redeem.
     */
    function onChainRedemption(
        address uAddress,
        uint256 stokenAmount
    ) external notBlacklisted(msg.sender) whenNotPaused {
        require(stokenAmount > 0, "Amount must be greater than zero");
        require(containsAddress(uAddress), "Unsupported token address");

        uint256 redemptionId = uint256(
            keccak256(
                abi.encodePacked(
                    uAddress,
                    stokenAmount,
                    block.timestamp,
                    block.prevrandao
                )
            )
        );

        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        wd.id = redemptionId;
        wd.uAmount = 0; // Set USDT amount to the stoken
        wd.uAddress = uAddress; // Set user address to the uAddress
        wd.stokenAmount = stokenAmount; // Set stoken amount to the stoken
        wd.user = msg.sender; // Set user to the sender
        wd.price = 0; // Initial price is zero
        wd.time = bytes32(0); // Initial time is zero
        wd.transactionHash = bytes32(0); // Initial transaction hash is zero
        delete wd.tokenTransferDetailList; // Initialize as empty

        emit onChainRedemptionEvent(
            redemptionId,
            uAddress,
            stokenAmount,
            msg.sender
        ); // Emit event for off-chain redemption
    }

    function overwriteOnChainRedemption(
        uint256 redemptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        bytes32 transactionHash,
        string memory offChainId
    ) external onlyRole(STOKEN_ADMIN) notBlacklisted(user) whenNotPaused {
        require(redemptionId != 0, "Invalid redemption ID");
        require(user != address(0), "Invalid user address");
        require(stokenAmount > 0, "Stoken amount must be greater than zero");

        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        wd.id = redemptionId;
        wd.uAmount = uAmount;
        wd.uAddress = uAddress;
        wd.stokenAmount = stokenAmount;
        wd.user = user;
        wd.price = price;
        wd.time = time;
        wd.transactionHash = transactionHash;
        delete wd.tokenTransferDetailList; // Initialize as empty

        emit overwriteOnChainRedemptionEvent(
            redemptionId,
            uAmount,
            uAddress,
            stokenAmount,
            user,
            price,
            time,
            transactionHash,
            offChainId
        ); // Emit event for redemption
    }

    function redemption(
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        bytes32 transactionHash,
        string memory offChainId
    ) external onlyRole(STOKEN_ADMIN) notBlacklisted(user) whenNotPaused {
        require(user != address(0), "Invalid user address");
        require(stokenAmount > 0, "Stoken amount must be greater than zero");
        uint256 redemptionId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    uAmount,
                    uAddress,
                    stokenAmount,
                    price,
                    time,
                    block.timestamp,
                    block.prevrandao
                )
            )
        );

        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        wd.id = redemptionId;
        wd.uAmount = uAmount;
        wd.uAddress = uAddress;
        wd.stokenAmount = stokenAmount;
        wd.user = user;
        wd.price = price;
        wd.time = time;
        wd.transactionHash = transactionHash;
        delete wd.tokenTransferDetailList; // Initialize as empty
        emit RedemptionEvent(
            redemptionId,
            uAmount,
            uAddress,
            stokenAmount,
            user,
            price,
            time,
            transactionHash,
            offChainId
        ); // Emit event for redemption
    }

    function removeRedemptionData(
        uint256 redemptionId
    ) external onlyRole(STOKEN_ADMIN) {
        require(redemptionId != 0, "Invalid redemption ID");
        require(
            _redemptionDataMap[redemptionId].id != 0,
            "redemption does not exist"
        );
        delete _redemptionDataMap[redemptionId];
    }

    function execute(
        uint256 subscriptionId
    )
        public
        onlyRole(STOKEN_ADMIN)
        notBlacklisted(_subscribeDataMap[subscriptionId].user)
        whenNotPaused
    {
        _mintStoken(subscriptionId);
        emit executeEvent(
            subscriptionId,
            _subscribeDataMap[subscriptionId].uAmount,
            _subscribeDataMap[subscriptionId].uAddress,
            _subscribeDataMap[subscriptionId].stokenAmount,
            _subscribeDataMap[subscriptionId].user,
            _subscribeDataMap[subscriptionId].price,
            _subscribeDataMap[subscriptionId].time,
            _subscribeDataMap[subscriptionId].transactionHash
        ); // Emit event for execution
        delete _subscribeDataMap[subscriptionId];
    }

    function claim(
        uint256 subscriptionId
    )
        public
        notBlacklisted(msg.sender)
        notBlacklisted(_subscribeDataMap[subscriptionId].user)
        whenNotPaused
    {
        require(
            _subscribeDataMap[subscriptionId].user == msg.sender,
            "Only the subscriber can claim"
        );
        _mintStoken(subscriptionId);
        emit claimEvent(
            subscriptionId,
            _subscribeDataMap[subscriptionId].uAmount,
            _subscribeDataMap[subscriptionId].uAddress,
            _subscribeDataMap[subscriptionId].stokenAmount,
            _subscribeDataMap[subscriptionId].user,
            _subscribeDataMap[subscriptionId].price,
            _subscribeDataMap[subscriptionId].time,
            _subscribeDataMap[subscriptionId].transactionHash
        ); // Emit event for execution
        delete _subscribeDataMap[subscriptionId];
    }

    // Mint tokens for a specified subscription ID
    // This function allows the admin to mint tokens based on a subscription.
    // It checks if the subscription ID is valid and retrieves the subscription data.
    // It then adds new token data and updates the user's token list and map.
    function _mintStoken(uint256 subscriptionId) internal {
        require(subscriptionId != 0, "Invalid subscription ID");
        SubscribeData storage sub = _subscribeDataMap[subscriptionId];
        require(sub.id != 0, "Subscription does not exist");

        uint256 tokenId = _addNewTokenData(sub);
        _tokenList[sub.user].push(tokenId);
        _tokenMap[sub.user][tokenId] += sub.stokenAmount;
        _mint(sub.user, sub.stokenAmount);
    }

    // Burn tokens for a specified redemption ID
    // This function allows the admin to burn tokens based on a redemption.
    function burn(
        uint256 redemptionId
    )
        public
        onlyRole(STOKEN_ADMIN)
        notBlacklisted(_redemptionDataMap[redemptionId].user)
        whenNotPaused
    {
        require(redemptionId != 0, "Invalid redemption ID");
        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        require(wd.id != 0, "redemption does not exist");

        TokenTransferDetail[] memory _tt = _removeTokenByIdList(
            wd.user,
            wd.stokenAmount
        );
        // Clear existing storage array by deleting each element
        delete wd.tokenTransferDetailList;
        TokenTransferDetail[] storage tokenTransferDetailList = wd
            .tokenTransferDetailList;
        for (uint256 i = 0; i < _tt.length; i++) {
            uint256 tokenId = _tt[i].id;
            uint256 amount = _tt[i].amount;
            TokenTransferDetail memory _temp = TokenTransferDetail({
                id: tokenId,
                amount: amount
            });
            tokenTransferDetailList.push(_temp);
        }
        // No need to reassign wd to _redemptionDataMap, as wd is a storage pointer
        emit burnEvent(
            redemptionId,
            wd.uAmount,
            wd.uAddress,
            wd.stokenAmount,
            wd.user,
            wd.price,
            wd.time,
            wd.transactionHash
        ); // Emit event for burn
    }

    // Get the token data for a specified token ID
    // This function retrieves the token data for a given token ID.
    function balanceOf(address account) public view override returns (uint256) {
        uint256 totalBalance = 0;
        uint256[] storage tokenIds = _tokenList[account];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            totalBalance += _tokenMap[account][tokenIds[i]];
        }
        return totalBalance;
    }

    // Get the token IDs and amounts for a specified account
    // This function returns two arrays: one for token IDs and another for their corresponding amounts.
    function balanceOfWithId(
        address account
    )
        external
        view
        returns (uint256[] memory tokenIds, uint256[] memory amounts)
    {
        uint256 len = _tokenList[account].length;
        tokenIds = new uint256[](len);
        amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = _tokenList[account][i];
            tokenIds[i] = tokenId;
            amounts[i] = _tokenMap[account][tokenId];
        }
    }

    function transfer(
        address recipient,
        uint256 amount
    )
        public
        override
        notBlacklisted(msg.sender)
        notBlacklisted(recipient)
        returns (bool)
    {
        _transferWithTokenId(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        override
        notBlacklisted(msg.sender)
        notBlacklisted(sender)
        notBlacklisted(recipient)
        returns (bool)
    {
        _transferWithTokenId(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    function _transferWithTokenId(
        address from,
        address to,
        uint256 amount
    ) internal {
        TokenTransferDetail[] memory _tt = _removeTokenByIdList(from, amount);
        _addTokenByIdList(to, _tt);
    }

    // Add new token data for a specified address
    // This function generates a new token ID based on the address and current block parameters.
    function _addNewTokenData(
        SubscribeData memory sub
    ) internal returns (uint256) {
        uint256 tokenId = uint256(
            keccak256(
                abi.encodePacked(sub.user, block.timestamp, block.prevrandao)
            )
        );
        TokenData memory newTokenData = TokenData({
            id: tokenId,
            mintTime: sub.time,
            mintPrice: sub.price,
            tokenOwner: sub.user
        });
        _tokenDataMap[tokenId] = newTokenData;
        return tokenId;
    }

    // Get the token data for a specified token ID
    // This function retrieves the token data for a given token ID.
    function getTokenData(
        uint256[] memory tokenIds
    ) external view onlyRole(STOKEN_ADMIN) returns (TokenData[] memory) {
        require(tokenIds.length > 0, "No token IDs provided");
        TokenData[] memory tokenDataArray = new TokenData[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(
                _tokenDataMap[tokenId].id != 0,
                "Token data does not exist"
            );
            tokenDataArray[i] = _tokenDataMap[tokenId];
        }
        return tokenDataArray;
    }

    // Return redemption details for calculating technical service fee
    function getTokenDataByRedemptionId(
        uint256 redemptionId
    )
        external
        view
        onlyRole(STOKEN_ADMIN)
        returns (TokenDataWithAmount[] memory)
    {
        require(redemptionId != 0, "Invalid redemption ID");
        RedemptionData memory rd = _redemptionDataMap[redemptionId];
        require(rd.id != 0, "Redemption does not exist");
        TokenTransferDetail[] memory tokenTransferDetails = rd
            .tokenTransferDetailList;
        TokenDataWithAmount[]
            memory tokenDataWithAmountArray = new TokenDataWithAmount[](
                tokenTransferDetails.length
            );
        for (uint256 i = 0; i < tokenTransferDetails.length; i++) {
            uint256 tokenId = tokenTransferDetails[i].id;
            require(
                _tokenDataMap[tokenId].id != 0,
                "Token data does not exist"
            );
            TokenData memory tokenData = _tokenDataMap[tokenId];
            tokenDataWithAmountArray[i] = TokenDataWithAmount({
                id: tokenData.id,
                mintTime: tokenData.mintTime,
                redemptionTime: rd.time,
                mintPrice: tokenData.mintPrice,
                tokenOwner: tokenData.tokenOwner,
                amount: tokenTransferDetails[i].amount
            });
        }
        return tokenDataWithAmountArray;
    }

    // Add tokens to the user's list by token ID and amount
    // This function checks if the token ID already exists for the user.
    // If it does not exist, it adds the token ID to the user's list.
    // If it exists, it updates the token amount for the user.
    function _addTokenByIdList(
        address account,
        TokenTransferDetail[] memory tokenTransferDetail
    ) internal {
        for (uint256 i = 0; i < tokenTransferDetail.length; i++) {
            uint256 tokenId = tokenTransferDetail[i].id;
            uint256 amount = tokenTransferDetail[i].amount;

            // Add the token ID to the user's list if it doesn't exist
            if (_tokenMap[account][tokenId] == 0) {
                _tokenList[account].push(tokenId);
            }

            // Update the token amount for the user
            _tokenMap[account][tokenId] += amount;
        }
    }

    // Remove a specified amount of tokens according to the FIFO (First-In-First-Out) rule
    // This function iterates through the token IDs associated with the address
    // and removes tokens until the specified amount is reached.
    function _removeTokenByIdList(
        address account,
        uint256 amount
    ) internal returns (TokenTransferDetail[] memory) {
        // Find the token ID associated with the sender's address
        uint256[] storage tokenIds = _tokenList[account];
        require(tokenIds.length > 0, "No tokens to burn");
        uint256 remaining = amount;
        uint256 i = 0;

        // Use a fixed-size memory array and manual indexing since push is not available for memory arrays
        TokenTransferDetail[] memory tempTokens = new TokenTransferDetail[](
            tokenIds.length
        );
        uint256 tempTokensLength = 0;

        while (remaining > 0 && i < tokenIds.length) {
            uint256 tokenId = tokenIds[i];
            uint256 tokenAmount = _tokenMap[account][tokenId];
            if (tokenAmount == 0) {
                i++;
                continue;
            }
            if (tokenAmount > remaining) {
                _tokenMap[account][tokenId] -= remaining;
                tempTokens[tempTokensLength] = TokenTransferDetail({
                    id: tokenId,
                    amount: remaining
                });
                tempTokensLength++;
                remaining = 0;
            } else {
                remaining -= tokenAmount;
                _tokenMap[account][tokenId] = 0;
                tempTokens[tempTokensLength] = TokenTransferDetail({
                    id: tokenId,
                    amount: tokenAmount
                });
                tempTokensLength++;
            }
            i++;
        }
        require(remaining == 0, "Not enough tokens to burn");

        // Clean up empty token IDs
        uint256[] memory _tokenIds = new uint256[](tokenIds.length);
        uint256 count = 0;
        for (uint256 j = 0; j < tokenIds.length; j++) {
            if (_tokenMap[account][tokenIds[j]] != 0) {
                _tokenIds[count] = tokenIds[j];
                count++;
            }
        }
        // Resize the array to the correct length
        uint256[] storage tokenListStorage = _tokenList[account];
        if (count == 0) {
            delete _tokenList[account];
        } else {
            // Overwrite the storage array with the cleaned memory array
            // First, clear the storage array
            delete _tokenList[account];
            // Then, copy the valid token IDs back to storage
            for (uint256 k = 0; k < count; k++) {
                tokenListStorage.push(_tokenIds[k]);
            }
        }
        return tempTokens;
    }

    /*//////////////////////////////////////////////////////////////
                              Blacklist
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds account to blacklist.
     * @param _account The address to blacklist.
     */
    function blacklist(address _account) external onlyRole(STOKEN_ADMIN){
        _blacklist(_account);
        emit Blacklisted(_account);
    }

    /**
     * @notice Removes account from blacklist.
     * @param _account The address to remove from the blacklist.
     */
    function unBlacklist(address _account) external onlyRole(STOKEN_ADMIN){
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

    /*//////////////////////////////////////////////////////////////
                        supportedTokenAddress
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the list of supported token addresses.
     */
    function getSupportedTokenAddresses()
        external
        view
        returns (address[] memory)
    {
        return supportedTokenAddress;
    }

    /**
     * @dev Adds a new supported token address.
     * @param token The address to add.
     */
    function addSupportedTokenAddress(
        address token
    ) external onlyRole(STOKEN_ADMIN) {
        require(token != address(0), "Invalid address");
        supportedTokenAddress.push(token);
    }

    /**
     * @dev Removes a supported token address.
     * @param token The address to remove.
     */
    function removeSupportedTokenAddress(
        address token
    ) external onlyRole(STOKEN_ADMIN) {
        require(token != address(0), "Invalid address");
        for (uint256 i = 0; i < supportedTokenAddress.length; i++) {
            if (supportedTokenAddress[i] == token) {
                supportedTokenAddress[i] = supportedTokenAddress[
                    supportedTokenAddress.length - 1
                ];
                supportedTokenAddress.pop();
                return;
            }
        }
        revert("Token address not found");
    }

    /**
     * @dev Checks if an address is in the supported token addresses.
     * @param addr The address to check.
     * @return True if the address is supported, false otherwise.
     */
    function containsAddress(address addr) internal view returns (bool) {
        for (uint i = 0; i < supportedTokenAddress.length; i++) {
            if (supportedTokenAddress[i] == addr) {
                return true;
            }
        }
        return false;
    }
}
