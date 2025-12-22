// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface IETF {
    // ========== 事件 ==========
    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        uint256 usdtAmount,
        uint256 etfAmount,
        uint256 settleTime
    );
    event ETFSettled(
        uint256 indexed orderId,
        address indexed user,
        uint256 etfAmount
    );
    event OrderCancelled(
        uint256 indexed orderId,
        address indexed user,
        uint256 penalty,
        uint256 refundUsdt
    );
    event assetRecipientUpdatedEvent(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event lotSizeUpdated(uint256 oldLotSize, uint256 newLotSize);
}
