// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface ISAmMMF {
    struct SubscribeData {
        uint256 id; // Subscription ID
        uint256 usdtAmount; // Amount of USDT to subscribe
        uint256 stokenAmount; // Amount of stoken to subscribe
        address user; // User address who subscribed
        uint256 price; // Price of the subscription
        bytes32 time; // Subscription time
        uint256 transactionHash; // Transaction hash for the subscription
    }

    struct RedemptionData {
        uint256 id; // Redemption ID
        uint256 usdtAmount; // Amount of USDT to Redemption
        uint256 stokenAmount; // Amount of tokens to Redemption
        address user; // User address who requested the Redemption
        uint256 price; // Price of the Redemption
        bytes32 time; // Redemption time
        uint256 transactionHash; // Transaction hash for the Redemption
        TokenTransferDetail[] tokenTransferDetailList; // Temporary token data for the Redemption, can be initialized as empty
    }

    // TokenData structure to hold token ID and amount
    struct TokenData {
        uint256 id; // Token ID
        bytes32 mintTime; // Token minting time
        uint256 mintPrice; // Token price
        address tokenOwner; // Token owner address
    }

    struct TokenDataWithAmount {
        uint256 id; // Token ID
        bytes32 mintTime; // Token minting time
        bytes32 redemptionTime; // Token redemption time
        uint256 mintPrice; // Token price
        address tokenOwner; // Token owner address
        uint256 amount; // Amount of tokens
    }

    struct TokenTransferDetail {
        uint256 id; // Token ID
        uint256 amount; // Token minting time
    }

    event subscribeEvent(
        uint256 subscriptionId,
        uint256 usdtAmount,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        uint256 transactionHash,
        string offChainId
    );

    event RedemptionEvent(
        uint256 redemptionId,
        uint256 usdtAmount,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        uint256 transactionHash,
        string offChainId
    );

    event addNewTokenDataEvent(
        uint256 id,
        uint256 mintTime,
        uint256 price,
        address tokenOwner
    );

    event executeEvent(
        uint256 subscriptionId,
        uint256 usdtAmount,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        uint256 transactionHash
    );

    event claimEvent(
        uint256 subscriptionId,
        uint256 usdtAmount,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        uint256 transactionHash
    );

    event burnEvent(
        uint256 redemptionId,
        uint256 usdtAmount,
        uint256 stokenAmount,
        address user,
        uint256 price,
        bytes32 time,
        uint256 transactionHash
    );
}
