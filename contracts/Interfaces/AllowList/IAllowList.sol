// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title IAllowlist
 * @author MARS Finance
 * @notice Interface for a allowlist contract to manage allowed addresses.
 */
interface IAllowlist {
  /**
   * @notice Adds an array of addresses to the allowlist.
   *
   * @param accounts The array of addresses to be added to the allowlist.
   */
  function addToAllowlist(address[] calldata accounts) external;

  /**
   * @notice Removes an array of addresses from the allowlist.
   *
   * @param accounts The array of addresses to be removed from the allowlist.
   */
  function removeFromAllowlist(address[] calldata accounts) external;

  /**
   * @notice Event emitted when addresses are added to the allowlist.
   *
   * @param accounts The array of addresses that were added to the allowlist.
   */
  event AllowedAddressesAdded(address[] accounts);

  /**
   * @notice Event emitted when addresses are removed from the allowlist.
   *
   * @param accounts The array of addresses that were removed from the allowlist.
   */
  event AllowedAddressesRemoved(address[] accounts);
}
