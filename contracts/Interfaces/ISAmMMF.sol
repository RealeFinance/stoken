// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface ISAmMMF {
    struct SubscribeData {
        uint256 id; // Subscription ID
        uint256 amount; // Amount of tokens subscribed
        address user; // User address who subscribed
        uint256 price; // Price of the subscription
    }

    struct RedemptionData {
        uint256 id; // Withdrawal ID
        uint256 amount; // Amount of tokens to withdraw
        address user; // User address who requested the withdrawal
        uint256 price; // Price of the withdrawal
        TokenTemporary[] tokenTemporaryList; // Temporary token data for the withdrawal, can be initialized as empty
    }

    // TokenData structure to hold token ID and amount
    struct TokenData {
        uint256 id; // Token ID
        uint256 mintTime; // Token minting time
        uint256 price; // Token price
        address tokenOwner; // Token owner address
    }

    struct TokenTemporary {
        uint256 id; // Token ID
        uint256 amount; // Token minting time
    }

    event subscribeEvent(
        uint256 subscriptionId,
        uint256 amount,
        address user,
        uint256 price
    );

    event RedemptionEvent(
        uint256 redemptionId,
        uint256 amount,
        address user,
        uint256 price
    );

    event addNewTokenDataEvent(
        uint256 id,
        uint256 mintTime,
        uint256 price,
        address tokenOwner
    );

    event executeEvent(
        uint256 subscriptionId,
        uint256 amount,
        address user,
        uint256 price
    );

    event claimEvent(
        uint256 subscriptionId,
        uint256 amount,
        address user,
        uint256 price
    );

    event burnEvent(
        uint256 redemptionId,
        uint256 amount,
        address user,
        uint256 price
    );
}
