// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface ICashPlus {
    struct SubscribeData {
        uint256 id; // Subscription ID
        uint256 uAmount; // Amount of USDT to subscribe
        address uAddress; // User address who subscribed
        uint256 stokenAmount; // Amount of stoken to subscribe
        address user; // User address who subscribed
        uint256 price; // Price of the subscription
        uint256 time; // Subscription time
        bytes32 udaTxHash; // Transaction hash for the subscription
        uint16 source; // Source of the subscription
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
        uint16 source; // Source of the Redemption
        TokenTransferDetail[] tokenTransferDetails; // Details of token transfers during Redemption
        uint256 technicalServiceFee; // Technical service fee for the Redemption
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
    event assetSenderUpdatedEvent(
        address indexed oldSender,
        address indexed newSender
    );
    event serviceFeeRecipientUpdatedEvent(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event supportedTokenAddressAddedEvent(address indexed token);
    event supportedTokenAddressRemovedEvent(address indexed token);

    event subscribeEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source,
        string offChainId
    );

    event onChainSubscribeEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        address user,
        uint16 source
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
        address user,
        uint16 source
    );

    event onChainBurnEvent(
        uint256 redemptionId,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint16 source
    );

    event overwriteOnChainRedemptionEvent(
        uint256 redemptionId,
        uint256 uAmount,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint256 technicalServiceFee
    );

    event overwriteOnChainRedemptionEvent(
        uint256 redemptionId,
        uint256 uAmount,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint256 technicalServiceFee,
        TokenTransferDetail[] tokenTransferDetails
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
        uint16 source,
        string offChainId
    );

    event claimUSDEvent(
        uint256 redemptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source,
        uint256 technicalServiceFee
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
        bytes32 udaTxHash,
        uint16 source
    );

    event executeEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source,
        uint256 tokenId
    );

    event claimEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source
    );

    event claimEvent(
        uint256 subscriptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source,
        uint256 tokenId
    );

    event burnEvent(
        uint256 redemptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source,
        uint256 technicalServiceFee
    );

    event burnEvent(
        uint256 redemptionId,
        uint256 uAmount,
        address uAddress,
        uint256 stokenAmount,
        address user,
        uint256 price,
        uint256 time,
        bytes32 udaTxHash,
        uint16 source,
        uint256 technicalServiceFee,
        TokenTransferDetail[] tokenTransferDetails
    );

    event technicalServiceFeeEvent(
        uint256 redemptionId,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event minSubscriptionAmountUpdatedEvent(uint256 oldAmount, uint256 newAmount);

    event maxSubscriptionAmountUpdatedEvent(uint256 oldAmount, uint256 newAmount);

    event minRedemptionAmountUpdatedEvent(uint256 oldAmount, uint256 newAmount);

    event maxRedemptionAmountUpdatedEvent(uint256 oldAmount, uint256 newAmount);
}
