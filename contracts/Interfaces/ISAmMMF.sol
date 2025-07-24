// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface ISAmMMF {
    struct SubscribeData {
        uint256 id; // Subscription ID
        uint256 uAmount; // Amount of USDT to subscribe
        address uAddress; // User address who subscribed
        uint256 stokenAmount; // Amount of stoken to subscribe
        address user; // User address who subscribed
        uint256 price; // Price of the subscription
        uint256 time; // Subscription time
        bytes32 udaTxHash; // Transaction hash for the subscription
    }

    struct RedemptionData {
        uint256 id; // Redemption ID
        uint256 uAmount; // Amount of USDT to Redemption
        address uAddress; // User address who requested the Redemption
        uint256 stokenAmount; // Amount of tokens to Redemption
        address user; // User address who requested the Redemption
        uint256 price; // Price of the Redemption
        uint256 time; // Redemption time
        bytes32 udaTxHash; // Transaction hash for the Redemption
        TokenTransferDetail[] tokenTransferDetailList; // Temporary token data for the Redemption, can be initialized as empty
    }

    // TokenData structure to hold token ID and amount
    struct TokenData {
        uint256 id; // Token ID
        uint256 mintTime; // Token minting time
        uint256 mintPrice; // Token price
        address tokenOwner; // Token owner address
    }

    struct TokenDataWithAmount {
        uint256 id; // Token ID
        uint256 mintTime; // Token minting time
        uint256 redemptionTime; // Token redemption time
        uint256 mintPrice; // Token price
        address tokenOwner; // Token owner address
        uint256 amount; // Amount of tokens
    }

    struct TokenTransferDetail {
        uint256 id; // Token ID
        uint256 amount; // Token minting time
    }

    event assetRecipientUpdatedEvent(
        address indexed oldRecipient,
        address indexed newRecipient
    );

    event technicalServiceFeeRateUpdatedEvent(uint256 oldRate, uint256 newRate);

    event subscribeEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        string offChainId
    );

    event onChainSubscribeEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        address user
    );

    event overwriteOnChainSubscribeEvent(
        uint256 subscriptionId,
        uint256 stokenAmount,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        string offChainId
    );

    event onChainRedemptionEvent(
        uint256 redemptionId,
        address uAddress,
        uint256 stokenAmount,
        address user
    );

    event onChainBurnEvent(
        uint256 redemptionId,
        address uAddress,
        uint256 stokenAmount,
        address user
    );

    event overwriteOnChainRedemptionEvent(
        uint256 redemptionId,
        uint256 uAmount,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash
    );

    event RedemptionEvent(
        uint256 redemptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
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
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash
    );

    event claimEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash
    );

    event burnEvent(
        uint256 redemptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash
    );
}
