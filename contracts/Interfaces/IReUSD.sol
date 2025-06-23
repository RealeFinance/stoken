// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title IReUSD
 * @notice Interface for ReUSD token interest management, providing functions to query and reset total accrued interest.
 */
interface IReUSD {
    /**
     * @notice Returns the total interest accrued in the system.
     * @return The total interest as a uint256 value.
     */
    function getTotalInterest() external view returns (uint256);

    /**
     * @notice Resets the total interest accrued in the system.
     * @dev This function should only be called by authorized accounts. Use with caution as it may affect accounting.
     * @dev Reverts if called by an unauthorized account or if the reset operation fails.
     */
    function resetTotalInterest() external;
}
