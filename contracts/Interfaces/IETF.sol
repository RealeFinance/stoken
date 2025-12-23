// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface IETF {
    // ========== 事件 ==========
    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        address uAddress,
        uint256 uAmount,
        uint256 lockTime,
        uint256 settleTime,
        bool isLotType
    );
    event assetRecipientUpdatedEvent(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event lotSizeUpdated(uint256 oldLotSize, uint256 newLotSize);

    event supportedTokenAddressAddedEvent(address indexed token);
    event supportedTokenAddressRemovedEvent(address indexed token);
}
