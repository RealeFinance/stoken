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
import {BaseStorage} from "../base/BaseStorage.sol";
import "../Interfaces/ICashPlus.sol";
import {Blacklistable} from "../BlackList/Blacklistable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CashPlus is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    BaseStorage,
    Blacklistable
{
    using SafeERC20 for IERC20;
    bytes32 public constant VERSION = keccak256("VERSION_2");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant STOKEN_ADMIN = keccak256("STOKEN_ADMIN");
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

    uint256 private _totalSupply;

    uint256 public nextId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address supportedTokenAddress1,
        address supportedTokenAddress2
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init(name);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(STOKEN_BLACKLIST_ADMIN_ROLE, msg.sender);

        assetRecipient = address(this); // Set the asset recipient to this contract address
        assetSender = address(this); // Set the asset sender to this contract address
        serviceFeeRecipient = address(this); // Set the service fee recipient to this contract address

        technicalServiceFeeRate = 10; // Default technical service fee rate set to 0.1%
        supportedTokenAddress.push(supportedTokenAddress1); // USDC address on Ethereum mainnet
        supportedTokenAddress.push(supportedTokenAddress2); // USDT address on Ethereum mainnet
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function pause() public onlyRole(STOKEN_ADMIN) {
        _pause();
    }

    function unpause() public onlyRole(STOKEN_ADMIN) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Subscribe to the service with USDT/USDC on-chain.
     * @param uAddress The address of the USDT/USDC contract.
     * @param uAmount The amount of USDT/USDC to subscribe.
     * @param source The source of the subscription (e.g., 0 for off-chain, 1 for on-chain).
     * @notice onchainSubscribe ==> overwriteOnChainSubscribe ==> claim
     */
    function onChainSubscribe(
        address uAddress,
        uint256 uAmount,
        uint16 source
    ) external notBlacklisted(msg.sender) whenNotPaused {
        require(uAmount > 0, "Amount must be greater than zero");
        require(containsAddress(uAddress), "Unsupported token address");

        uint256 balanceBefore = IERC20(uAddress).balanceOf(assetRecipient);
        IERC20(uAddress).safeTransferFrom(msg.sender, assetRecipient, uAmount); // Transfer USDT from the user to this contract
        uint256 balanceAfter = IERC20(uAddress).balanceOf(assetRecipient);
        uAmount = balanceAfter - balanceBefore;

        nextId++; // Increment the nextId for subscription ID generation
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
        sd.uAmount = uAmount; // Set USDT amount to the uAmount
        sd.uAddress = uAddress; // Set user address to the uAddress
        sd.source = source; // Source of the subscription
        sd.user = msg.sender; // Set user to the sender

        emit onChainSubscribeEvent(
            subscriptionId,
            uAmount,
            uAddress,
            msg.sender,
            source
        ); // Emit event for off-chain subscription
    }

    /**
     * @dev Overwrite the on-chain subscription data.
     * @param subscriptionId The ID of the subscription to overwrite.
     * @param price The price of the subscription.
     * @param stokenAmount The amount of stoken to subscribe.
     * @param time The subscription time.
     * @param udaTxHash The transaction hash for the subscription.
     * @param offChainId The off-chain identifier for the subscription.
     */
    function overwriteOnChainSubscribe(
        uint256 subscriptionId,
        uint256 price,
        uint256 stokenAmount,
        uint256 time,
        bytes32 udaTxHash,
        string memory offChainId
    )
        external
        onlyRole(STOKEN_ADMIN)
        notBlacklisted(_subscribeDataMap[subscriptionId].user)
        whenNotPaused
    {
        require(subscriptionId != 0, "Invalid subscription ID");
        require(
            stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        );
        require(
            _subscribeDataMap[subscriptionId].id != 0,
            "Subscription does not exist"
        );

        SubscribeData storage sd = _subscribeDataMap[subscriptionId];
        sd.stokenAmount = stokenAmount;
        sd.price = price;
        sd.time = time;
        sd.udaTxHash = udaTxHash;

        emit overwriteOnChainSubscribeEvent(
            subscriptionId,
            stokenAmount,
            price,
            time,
            udaTxHash,
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
     * @param udaTxHash The transaction hash for the subscription.
     * @param offChainId The off-chain identifier for the subscription.
     * @notice subscribe ==> execute
     */
    function subscribe(
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        string memory offChainId
    )
        external
        onlyRole(STOKEN_ADMIN)
        notBlacklisted(user)
        zeroAddress(user)
        zeroAddress(uAddress)
        whenNotPaused
    {
        require(
            stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        );
        require(containsAddress(uAddress), "Unsupported token address");
        uint256 subscriptionId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    uAmount,
                    uAddress,
                    stokenAmount,
                    price,
                    time,
                    offChainId
                )
            )
        );
        require(
            _subscribeDataMap[subscriptionId].id == 0,
            "Subscription already exists"
        ); // Ensure the subscription ID does not already exist
        _subscribeDataMap[subscriptionId] = SubscribeData({
            id: subscriptionId,
            uAmount: uAmount,
            uAddress: uAddress,
            stokenAmount: stokenAmount,
            user: user,
            price: price,
            time: time,
            udaTxHash: udaTxHash,
            source: 0
        });
        emit subscribeEvent(
            subscriptionId,
            uAmount,
            uAddress,
            stokenAmount,
            user,
            price,
            time,
            udaTxHash,
            0,
            offChainId
        ); // Emit event for subscription
    }

    /**
     * @dev Handle on-chain redemption with USDT/USDC.
     * @param uAddress The address of the USDT/USDC contract.
     * @param stokenAmount The amount of stoken to redeem.
     * @param source The source of the subscription.
     * @notice onchainRedemption ==> overwriteOnChainRedemption ==> claimUSD
     */
    function onChainRedemption(
        address uAddress,
        uint256 stokenAmount,
        uint16 source
    ) external notBlacklisted(msg.sender) zeroAddress(uAddress) whenNotPaused {
        require(
            stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        );
        require(containsAddress(uAddress), "Unsupported token address");

        nextId++; // Increment the nextId for redemption ID generation
        uint256 redemptionId = uint256(
            keccak256(
                abi.encodePacked(
                    uAddress,
                    stokenAmount,
                    msg.sender,
                    block.timestamp,
                    block.prevrandao,
                    nextId
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
        wd.time = 0; // Initial time is zero
        wd.udaTxHash = bytes32(0); // Initial transaction hash is zero
        wd.source = source; // Source of the subscription

        _burn(redemptionId); // Burn the stoken amount for the user

        emit onChainRedemptionEvent(
            redemptionId,
            uAddress,
            stokenAmount,
            msg.sender,
            source
        ); // Emit event for off-chain redemption
        // emit onChainBurnEvent(
        //     redemptionId,
        //     uAddress,
        //     stokenAmount,
        //     msg.sender,
        //     source
        // ); // Emit event for on-chain burn
    }

    /**
     * @dev Overwrite the on-chain redemption data.
     * @param redemptionId The ID of the redemption to overwrite.
     * @param uAmount The amount of USDT/USDC to redeem.
     * @param price The price of the redemption.
     * @param time The redemption time.
     * @param udaTxHash The transaction hash for the redemption.
     * @notice onchainRedemption ==> overwriteOnChainRedemption ==> claimUSD
     */
    function overwriteOnChainRedemption(
        uint256 redemptionId,
        uint256 uAmount,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash
    )
        external
        onlyRole(STOKEN_ADMIN)
        notBlacklisted(_redemptionDataMap[redemptionId].user)
        whenNotPaused
    {
        require(redemptionId != 0, "Invalid redemption ID");
        require(uAmount > 0, "USDT amount must be greater than zero");
        require(
            _redemptionDataMap[redemptionId].id != 0,
            "Redemption does not exist"
        );
        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        wd.id = redemptionId;
        wd.uAmount = uAmount;
        wd.price = price;
        wd.time = time;
        wd.udaTxHash = udaTxHash;

        _calculateTechnicalServiceFee(redemptionId); // Calculate the technical service fee

        emit overwriteOnChainRedemptionEvent(
            redemptionId,
            uAmount,
            price,
            time,
            udaTxHash,
            wd.technicalServiceFee
        ); // Emit event for redemption
    }

    /**
     * @dev Subscribe to the service with USDT and stoken amounts.
     * @param uAmount The amount of USDT to subscribe.
     * @param uAddress The address of the USDT contract.
     * @param stokenAmount The amount of stoken to subscribe.
     * @param user The user address who subscribed.
     * @param price The price of the subscription.
     * @param time The subscription time.
     * @param udaTxHash The transaction hash for the subscription.
     * @param offChainId The off-chain identifier for the subscription.
     * @notice redemption ==> burn
     */
    function redemption(
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        string memory offChainId
    )
        external
        onlyRole(STOKEN_ADMIN)
        notBlacklisted(user)
        zeroAddress(uAddress)
        zeroAddress(user)
        whenNotPaused
    {
        require(
            stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        );
        require(containsAddress(uAddress), "Unsupported token address");
        uint256 redemptionId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    uAmount,
                    uAddress,
                    stokenAmount,
                    price,
                    time,
                    offChainId
                )
            )
        );

        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        require(wd.id == 0, "Redemption already exists"); // Ensure the redemption ID does not already exist
        wd.id = redemptionId;
        wd.uAmount = uAmount;
        wd.uAddress = uAddress;
        wd.stokenAmount = stokenAmount;
        wd.user = user;
        wd.price = price;
        wd.time = time;
        wd.udaTxHash = udaTxHash;
        wd.source = 0;

        emit RedemptionEvent(
            redemptionId,
            uAmount,
            uAddress,
            stokenAmount,
            user,
            price,
            time,
            udaTxHash,
            0, // Source of the redemption
            offChainId
        ); // Emit event for redemption
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
            sd.source
        ); // Emit event for execution
        delete _subscribeDataMap[subscriptionId];
    }

    function claim(
        uint256 subscriptionId
    ) public notBlacklisted(msg.sender) whenNotPaused {
        require(
            _subscribeDataMap[subscriptionId].user == msg.sender,
            "Only the subscriber can claim"
        );
        _mintStoken(subscriptionId);
        SubscribeData memory sd = _subscribeDataMap[subscriptionId];
        emit claimEvent(
            subscriptionId,
            sd.uAmount,
            sd.uAddress,
            sd.stokenAmount,
            sd.user,
            sd.price,
            sd.time,
            sd.udaTxHash,
            sd.source
        ); // Emit event for execution
        delete _subscribeDataMap[subscriptionId];
    }

    function claimUSD(
        uint256 redemptionId
    ) public notBlacklisted(msg.sender) whenNotPaused {
        require(
            _redemptionDataMap[redemptionId].user == msg.sender,
            "Only the redeemer can claim"
        );
        RedemptionData memory wd = _redemptionDataMap[redemptionId];
        require(wd.id != 0, "Redemption does not exist");
        require(
            wd.stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        ); // Ensure stoken amount is greater than 0.01
        require(wd.user != address(0), "Invalid user address");
        require(wd.price > 0, "Invalid price");
        require(wd.time > 0, "Invalid time");
        require(
            wd.uAmount > 0,
            "USDT amount must be greater than zero for redemption"
        ); // Ensure USDT amount is greater than zero
        require(wd.source == 1, "Only on-chain redemption can claim USD");
        delete _redemptionDataMap[redemptionId];

        if (assetSender == serviceFeeRecipient) {
            IERC20(wd.uAddress).safeTransferFrom(
                assetSender,
                wd.user,
                wd.uAmount
            );
        } else {
            // Convert wd.technicalServiceFee (18 decimals) to 6 decimals for subtraction
            uint8 tokenDecimals = 18;
            {
                (bool ok, bytes memory data) = wd.uAddress.staticcall(
                    abi.encodeWithSignature("decimals()")
                );
                if (ok && data.length >= 32) {
                    tokenDecimals = abi.decode(data, (uint8));
                }
            }

            uint256 feeuAddressDecimals;
            if (tokenDecimals == 18) {
                feeuAddressDecimals = wd.technicalServiceFee;
            } else if (tokenDecimals < 18) {
                feeuAddressDecimals =
                    wd.technicalServiceFee /
                    (10 ** (18 - tokenDecimals));
            } else {
                feeuAddressDecimals =
                    wd.technicalServiceFee *
                    (10 ** (tokenDecimals - 18));
            }
            require(wd.uAmount >= feeuAddressDecimals, "Fee exceeds amount");

            IERC20(wd.uAddress).safeTransferFrom(
                assetSender,
                wd.user,
                wd.uAmount - feeuAddressDecimals
            ); // Transfer USDT/USDC from the asset sender to the user

            IERC20(wd.uAddress).safeTransferFrom(
                assetSender,
                serviceFeeRecipient,
                feeuAddressDecimals
            ); // Transfer technical service fee to the service fee recipient
        }

        emit claimUSDEvent(
            redemptionId,
            wd.uAmount,
            wd.uAddress,
            wd.stokenAmount,
            wd.user,
            wd.price,
            wd.time,
            wd.udaTxHash,
            wd.source,
            wd.technicalServiceFee
        ); // Emit event for claim USD
    }

    // Mint tokens for a specified subscription ID
    // This function allows the admin to mint tokens based on a subscription.
    // It checks if the subscription ID is valid and retrieves the subscription data.
    // It then adds new token data and updates the user's token list and map.
    function _mintStoken(uint256 subscriptionId) internal {
        require(subscriptionId != 0, "Invalid subscription ID");
        SubscribeData storage sub = _subscribeDataMap[subscriptionId];
        require(sub.id != 0, "Subscription does not exist");
        require(
            sub.stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        ); // Ensure stoken amount is greater than 0.01
        require(sub.user != address(0), "Invalid user address");
        require(sub.price > 0, "Invalid price");
        require(sub.time > 0, "Invalid time");
        uint256 tokenId = _addNewTokenData(sub);
        _tokenList[sub.user].push(tokenId);
        _tokenMap[sub.user][tokenId] += sub.stokenAmount;

        _totalSupply += sub.stokenAmount;
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
        RedemptionData memory wd = _redemptionDataMap[redemptionId];
        require(wd.id != 0, "Redemption does not exist");
        require(
            wd.stokenAmount >= MIN_AMOUNT,
            "Stoken amount must be greater than 0.01"
        ); // Ensure stoken amount is greater than 0.01
        require(wd.user != address(0), "Invalid user address");
        require(wd.price > 0, "Invalid price");
        require(wd.time > 0, "Invalid time");
        require(
            wd.uAmount > 0,
            "USDT amount must be greater than zero for redemption"
        ); // Ensure USDT amount is greater than zero
        _burn(redemptionId); // Burn the stoken amount for the user
        _calculateTechnicalServiceFee(redemptionId); // Calculate the technical service fee

        emit burnEvent(
            redemptionId,
            wd.uAmount,
            wd.uAddress,
            wd.stokenAmount,
            wd.user,
            wd.price,
            wd.time,
            wd.udaTxHash,
            wd.source,
            wd.technicalServiceFee
        ); // Emit event for burn
        delete _redemptionDataMap[redemptionId]; // Clear the redemption data after burning
    }

    function _burn(uint256 redemptionId) internal {
        RedemptionData storage wd = _redemptionDataMap[redemptionId];
        require(wd.id != 0, "Redemption does not exist");

        TokenTransferDetail[] memory _tt = _removeTokenByIdList(
            wd.user,
            wd.stokenAmount
        );

        // Manually copy memory array to storage array
        delete wd.tokenTransferDetails;
        for (uint256 i = 0; i < _tt.length; i++) {
            wd.tokenTransferDetails.push(_tt[i]);
        }

        _totalSupply -= wd.stokenAmount;
    }

    function _calculateTechnicalServiceFee(
        uint256 redemptionId
    ) internal returns (uint256) {
        RedemptionData storage wd = _redemptionDataMap[redemptionId];

        require(
            wd.tokenTransferDetails.length > 0,
            "No token transfer details available"
        );

        uint256 totalfee = 0;
        for (uint256 i = 0; i < wd.tokenTransferDetails.length; i++) {
            TokenTransferDetail storage detail = wd.tokenTransferDetails[i];
            TokenData storage tokenData = _tokenDataMap[detail.id];
            uint256 timeDay = _getTimeIntervalByDay(
                tokenData.mintTime,
                wd.time
            );
            uint256 fee = detail.amount;
            // SafeMath is not needed in Solidity >=0.8, but for explicitness:
            // fee = (fee * tokenData.mintPrice);
            fee = Math.mulDiv(fee, tokenData.mintPrice, 1e18); // Assuming mintPrice is in 18 decimals
            // fee = (fee * timeDay * technicalServiceFeeRate) / 10000 / 365;
            fee = Math.mulDiv(
                fee,
                timeDay * technicalServiceFeeRate,
                10000 * 365
            );
            totalfee += fee;
        }
        wd.technicalServiceFee = totalfee;
        return totalfee;
    }

    function _getTimeIntervalByDay(
        uint256 mintTime,
        uint256 redemptionTime
    ) internal pure returns (uint256) {
        require(
            redemptionTime >= mintTime,
            "Redemption time must be greater than or equal to mint time"
        );
        uint256 deltaSeconds = redemptionTime - mintTime;
        if (deltaSeconds == 0) {
            return 1; // If no time has passed, count as one day
        }
        // Calculate the number of days, rounding up if there is any remainder
        // Round up to the nearest day, so 1 second or 1.1 days both count as 2 days
        return (deltaSeconds + 1 days - 1) / 1 days;
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
        return (tokenIds, amounts);
    }

    function transfer(
        address recipient,
        uint256 amount
    )
        public
        override
        notBlacklisted(msg.sender)
        notBlacklisted(recipient)
        whenNotPaused
        returns (bool)
    {
        require(
            amount >= MIN_AMOUNT,
            "Transfer amount must be greater than 0.01"
        );
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
        whenNotPaused
        returns (bool)
    {
        require(
            amount >= MIN_AMOUNT,
            "Transfer amount must be greater than 0.01"
        );
        _transferWithTokenId(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    function _transferWithTokenId(
        address from,
        address to,
        uint256 amount
    ) internal zeroAddress(from) zeroAddress(to) {
        require(from != to, "Cannot transfer to self");
        require(amount > 0, "Transfer amount must be greater than zero");
        TokenTransferDetail[] memory _tt = _removeTokenByIdList(from, amount);
        _addTokenByIdList(to, _tt);
    }

    // Add new token data for a specified address
    // This function generates a new token ID based on the address and current block parameters.
    function _addNewTokenData(
        SubscribeData memory sub
    ) internal returns (uint256) {
        nextId++;
        uint256 tokenId = uint256(
            keccak256(
                abi.encodePacked(
                    sub.user,
                    block.timestamp,
                    block.prevrandao,
                    nextId
                )
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
    ) external view returns (TokenData[] memory) {
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
        require(tokenIds.length > 0, "Not enough tokens");
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
        require(remaining == 0, "Not enough tokens");

        // Clean up empty token IDs
        uint256[] memory _tokenIds = new uint256[](tokenIds.length);
        uint256 count = 0;
        for (uint256 j = 0; j < tokenIds.length; j++) {
            if (_tokenMap[account][tokenIds[j]] != 0) {
                _tokenIds[count] = tokenIds[j];
                count++;
            } else {
                // If the token amount is zero, we do not need to keep this token ID
                delete _tokenMap[account][tokenIds[j]];
            }
        }
        // Resize the array to the correct length
        uint256[] storage tokenListStorage = _tokenList[account];
        delete _tokenList[account];
        if (count != 0) {
            for (uint256 k = 0; k < count; k++) {
                tokenListStorage.push(_tokenIds[k]);
            }
        }

        // Remove TokenTransferDetail objects with id == 0 from tempTokens
        uint256 validCount = 0;
        for (uint256 m = 0; m < tempTokensLength; m++) {
            if (tempTokens[m].id != 0) {
                validCount++;
            }
        }
        TokenTransferDetail[] memory result = new TokenTransferDetail[](
            validCount
        );
        uint256 idx = 0;
        for (uint256 n = 0; n < tempTokensLength; n++) {
            if (tempTokens[n].id != 0) {
                result[idx] = tempTokens[n];
                idx++;
            }
        }
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                              Blacklist
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds account to blacklist.
     * @param _account The address to blacklist.
     */
    function blacklist(address _account) external onlyRole(STOKEN_ADMIN) {
        _blacklist(_account);
        emit Blacklisted(_account);
    }

    /**
     * @notice Removes account from blacklist.
     * @param _account The address to remove from the blacklist.
     */
    function unBlacklist(address _account) external onlyRole(STOKEN_ADMIN) {
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
                        set overwrite functions
    //////////////////////////////////////////////////////////////*/

    function setTechnicalServiceFeeRate(
        uint256 newRate
    ) public override onlyRole(STOKEN_ADMIN) {
        require(
            newRate >= 0 && newRate <= 10000,
            "Rate must be between 0 and 10000"
        );
        super.setTechnicalServiceFeeRate(newRate);
    }

    function setAssetRecipient(
        address newRecipient
    ) public override onlyRole(STOKEN_ADMIN) {
        super.setAssetRecipient(newRecipient);
    }

    function setAssetSender(
        address newSender
    ) public override onlyRole(STOKEN_ADMIN) {
        super.setAssetSender(newSender);
    }

    function setServiceFeeRecipient(
        address newRecipient
    ) public override onlyRole(STOKEN_ADMIN) {
        super.setServiceFeeRecipient(newRecipient);
    }

    function addSupportedTokenAddress(
        address newAddress
    ) public override onlyRole(STOKEN_ADMIN) {
        super.addSupportedTokenAddress(newAddress);
    }

    function removeSupportedTokenAddress(
        address token
    ) public override onlyRole(STOKEN_ADMIN) {
        super.removeSupportedTokenAddress(token);
    }
}
