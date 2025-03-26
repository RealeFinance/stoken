// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title IBlacklist
 * @author MARS Finance
 * @notice Interface for a blocklist contract to manage blocked addresses.
 */
interface IBlacklist {
  /**
   * @notice Adds an array of addresses to the blocklist.
   *
   * @param accounts The array of addresses to be added to the blocklist.
   */
  function addToBlacklist(address[] calldata accounts) external;

  /**
   * @notice Removes an array of addresses from the blocklist.
   *
   * @param accounts The array of addresses to be removed from the blocklist.
   */
  function removeFromBlacklist(address[] calldata accounts) external;

  /**
   * @notice Event emitted when addresses are added to the blocklist.
   *
   * @param accounts The array of addresses that were added to the blocklist.
   */
  event BlockedAddressesAdded(address[] accounts);

  /**
   * @notice Event emitted when addresses are removed from the blocklist.
   *
   * @param accounts The array of addresses that were removed from the blocklist.
   */
  event BlockedAddressesRemoved(address[] accounts);
}
