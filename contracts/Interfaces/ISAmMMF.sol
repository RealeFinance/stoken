// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface ISAmMMF {
    event subscribeEvent(
        uint256 subscriptionId,
        uint256 amount,
        address user,
        uint256 price
    );
    event updateSubscribeEvent(
        uint256 subscriptionId,
        uint256 oldAmount,
        address oldUser,
        uint256 oldPrice,
        uint256 newAmount,
        address newUser,
        uint256 newPrice
    );
    event withdrawalEvent(
        uint256 withdrawalId,
        uint256 amount,
        address user,
        uint256 price
    );
    event updateWithdrawalEvent(
        uint256 withdrawalId,
        uint256 oldAmount,
        address oldUser,
        uint256 oldPrice,
        uint256 newAmount,
        address newUser,
        uint256 newPrice
    );
    event addNewTokenDataEvent(
        uint256 id,
        uint256 mintTime,
        uint256 price,
        address tokenOwner
    );
}
