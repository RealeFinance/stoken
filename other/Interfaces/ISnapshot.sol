// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface ISnapshot {
    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) external view returns (uint256);

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);
}
