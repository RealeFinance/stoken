// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.22;

/**
 * @title IBlocklist
 * @author MARS Finance
 * @notice Interface for a blocklist contract to manage blocked addresses.
 */
interface IBlocklist {
    /**
     * @notice Adds an array of addresses to the blocklist.
     *
     * @param accounts The array of addresses to be added to the blocklist.
     */
    function addToBlocklist(address[] calldata accounts) external;

    /**
     * @notice Removes an array of addresses from the blocklist.
     *
     * @param accounts The array of addresses to be removed from the blocklist.
     */
    function removeFromBlocklist(address[] calldata accounts) external;

    /**
     * @notice Checks if an address is blocked.
     *
     * @param account The address to check.
     * @return bool Returns `true` if the address is blocked, otherwise `false`.
     */
    function isBlocked(address account) external view returns (bool);

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
