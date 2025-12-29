// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

interface IDividendDistributor {
    function createDividend(uint256 snapshotId, uint256 amount) external;

    function claim(uint256 roundId) external;
}
