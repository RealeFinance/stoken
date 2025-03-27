// SPDX-License-Identifier: BUSL-1.1
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

interface IRWAOracle {
    /// @notice Retrieve RWA price data
    function getPriceData()
        external
        view
        returns (uint256 price, uint256 timestamp);
}
