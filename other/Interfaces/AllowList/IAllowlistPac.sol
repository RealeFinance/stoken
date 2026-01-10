// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

/**
 * @title IAllowlist
 * @author MARS Finance
 * @notice Interface for managing an allowlist of addresses.
 */
interface IAllowlist {
    /**
     * @notice Adds a list of addresses to the allowlist.
     *
     * @param accounts The addresses to be added to the allowlist.
     */
    function addToAllowlist(address[] calldata accounts) external;

    /**
     * @notice Removes a list of addresses from the allowlist.
     *
     * @param accounts The addresses to be removed from the allowlist.
     */
    function removeFromAllowlist(address[] calldata accounts) external;

    /**
     * @notice Checks if an address is allowed (i.e., if it is in the allowlist).
     *
     * @param account The address to check.
     * @return bool True if the address is allowed, false otherwise.
     */
    function isAllowed(address account) external view returns (bool);

    /**
     * @notice Event emitted when addresses are added to the allowlist
     *
     * @param accounts The addresses that were added to the allowlist
     */
    event AllowedAddressesAdded(address[] accounts);

    /**
     * @notice Event emitted when addresses are removed from the allowlist
     *
     * @param accounts The addresses that were removed from the allowlist
     */
    event AllowedAddressesRemoved(address[] accounts);
}
