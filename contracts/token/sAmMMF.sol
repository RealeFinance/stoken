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
import "../Interfaces/ISAmMMF.sol";

contract SAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    ISAmMMF
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant STOKEN_ADMIN = keccak256("STOKEN_ADMIN");

    // Technical Service Fee (%) 10 ==> 0.1%  50 ==> 0.5%  100 ==> 1%
    uint256 private technicalServiceFeeRate = 10;

    // subscriptionId => SubscribeData
    mapping(uint256 => SubscribeData) private _subscribeDataMap;

    // withdrawalId => WithdrawalData
    mapping(uint256 => WithdrawalData) private _withdrawalDataMap;

    // tokenId => TokenData
    mapping(uint256 => TokenData) private _tokenDataMap;

    // Address → List of owned token IDs
    mapping(address => uint256[]) private _tokenList;

    // Address → Token ID → Token amount
    mapping(address => mapping(uint256 => uint256)) private _tokenMap;

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
     * @dev Create a new subscription entry.
     * @param amount The amount of tokens to subscribe.
     * @param user The address of the user subscribing.
     * @param price The price of the subscription.
     */
    function subscribe(
        uint256 amount,
        address user,
        uint256 price
    ) external onlyRole(STOKEN_ADMIN) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than zero");
        uint256 subscriptionId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    amount,
                    price,
                    block.timestamp,
                    block.prevrandao
                )
            )
        );
        _subscribeDataMap[subscriptionId] = SubscribeData({
            id: subscriptionId,
            amount: amount,
            user: user,
            price: price
        });
        emit subscribeEvent(subscriptionId, amount, user, price); // Emit event for subscription
    }

    /**
     * @dev Update an existing subscription entry.
     * @param subscriptionId The ID of the subscription to update.
     * @param newAmount The new amount of tokens for the subscription.
     * @param newPrice The new price of the subscription.
     */
    function updateSubscribe(
        uint256 subscriptionId,
        uint256 newAmount,
        uint256 newPrice,
        address newUser
    ) external onlyRole(STOKEN_ADMIN) {
        require(subscriptionId != 0, "Invalid subscription ID");
        SubscribeData storage oldSub = _subscribeDataMap[subscriptionId];
        require(oldSub.id != 0, "Subscription does not exist");
        require(newAmount > 0, "Amount must be greater than zero");
        _subscribeDataMap[subscriptionId] = SubscribeData({
            id: subscriptionId,
            amount: newAmount,
            user: newUser,
            price: newPrice
        });
        emit updateSubscribeEvent(
            subscriptionId,
            oldSub.amount,
            oldSub.user,
            oldSub.price,
            newAmount,
            newUser,
            newPrice
        ); // Emit event for subscription update
    }

    function withdrawal(
        uint256 amount,
        address user,
        uint256 price
    ) external onlyRole(STOKEN_ADMIN) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than zero");
        uint256 withdrawalId = uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    amount,
                    price,
                    block.timestamp,
                    block.prevrandao
                )
            )
        );
        _withdrawalDataMap[withdrawalId] = WithdrawalData({
            id: withdrawalId,
            amount: amount,
            user: user,
            price: price
        });
        emit withdrawalEvent(withdrawalId, amount, user, price); // Emit event for withdrawal
    }

    function updateWithdrawal(
        uint256 withdrawalId,
        uint256 newAmount,
        uint256 newPrice,
        address newUser
    ) external onlyRole(STOKEN_ADMIN) {
        require(withdrawalId != 0, "Invalid withdrawal ID");
        WithdrawalData storage oldwd = _withdrawalDataMap[withdrawalId];
        require(oldwd.id != 0, "Withdrawal does not exist");
        require(newAmount > 0, "Amount must be greater than zero");
        _withdrawalDataMap[withdrawalId] = WithdrawalData({
            id: withdrawalId,
            amount: newAmount,
            user: newUser,
            price: newPrice
        });
        emit updateWithdrawalEvent(
            withdrawalId,
            oldwd.amount,
            oldwd.user,
            oldwd.price,
            newAmount,
            newUser,
            newPrice
        ); // Emit event for withdrawal update
    }

    // Mint tokens for a specified subscription ID
    // This function allows the admin to mint tokens based on a subscription.
    // It checks if the subscription ID is valid and retrieves the subscription data.
    // It then adds new token data and updates the user's token list and map.
    function mint(uint256 subscriptionId) public onlyRole(STOKEN_ADMIN) {
        require(subscriptionId != 0, "Invalid subscription ID");
        SubscribeData storage sub = _subscribeDataMap[subscriptionId];
        require(sub.id != 0, "Subscription does not exist");

        uint256 tokenId = _addNewTokenData(sub);
        _tokenList[sub.user].push(tokenId);
        _tokenMap[sub.user][tokenId] += sub.amount;
        _mint(sub.user, sub.amount);
    }

    // Burn tokens for a specified withdrawal ID
    // This function allows the admin to burn tokens based on a withdrawal.
    function burn(uint256 withdrawalId) public onlyRole(STOKEN_ADMIN) {
        require(withdrawalId != 0, "Invalid withdrawal ID");
        WithdrawalData storage wd = _withdrawalDataMap[withdrawalId];
        require(wd.id != 0, "Withdrawal does not exist");
        require(wd.user == msg.sender, "Not authorized to burn");

        _removeTokenByIdList(msg.sender, wd.amount);
        _burn(msg.sender, wd.amount);
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
    ) public override returns (bool) {
        _transferWithTokenId(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transferWithTokenId(msg.sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    function _transferWithTokenId(
        address from,
        address to,
        uint256 amount
    ) internal {
        TokenTemporary[] memory _tt = _removeTokenByIdList(from, amount);
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
            mintTime: block.timestamp,
            price: sub.price,
            tokenOwner: sub.user
        });
        _tokenDataMap[tokenId] = newTokenData;
        return tokenId;
    }

    // Add tokens to the user's list by token ID and amount
    // This function checks if the token ID already exists for the user.
    // If it does not exist, it adds the token ID to the user's list.
    // If it exists, it updates the token amount for the user.
    function _addTokenByIdList(
        address account,
        TokenTemporary[] memory tokenTemporary
    ) internal {
        for (uint256 i = 0; i < tokenTemporary.length; i++) {
            uint256 tokenId = tokenTemporary[i].id;
            uint256 amount = tokenTemporary[i].amount;

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
    ) internal returns (TokenTemporary[] memory) {
        // Find the token ID associated with the sender's address
        uint256[] storage tokenIds = _tokenList[account];
        require(tokenIds.length > 0, "No tokens to burn");
        uint256 remaining = amount;
        uint256 i = 0;

        // Use a fixed-size memory array and manual indexing since push is not available for memory arrays
        TokenTemporary[] memory tempTokens = new TokenTemporary[](
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
                tempTokens[tempTokensLength] = TokenTemporary({
                    id: tokenId,
                    amount: remaining
                });
                tempTokensLength++;
                remaining = 0;
            } else {
                remaining -= tokenAmount;
                _tokenMap[account][tokenId] = 0;
                tempTokens[tempTokensLength] = TokenTemporary({
                    id: tokenId,
                    amount: tokenAmount
                });
                tempTokensLength++;
            }
            i++;
        }
        require(remaining == 0, "Not enough tokens to burn");

        // Clean up empty token IDs
        for (uint256 j = 0; j < tokenIds.length; j++) {
            if (_tokenMap[account][tokenIds[j]] == 0) {
                // Remove empty tokenId from list
                for (uint256 k = j; k < tokenIds.length - 1; k++) {
                    tokenIds[k] = tokenIds[k + 1];
                }
                tokenIds.pop();
                j--; // Adjust index after removal
            }
        }
        // If all tokens are burned, remove the address from the token list
        if (tokenIds.length == 0) {
            delete _tokenList[account];
        }
        _tokenList[account] = tokenIds;
        return tempTokens;
    }
}
