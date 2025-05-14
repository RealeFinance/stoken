// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title IAllowlistCheck
 * @author zhangwenhai 
 * @notice Interface for a allowlist contract to manage allowed addresses.
 */
interface IAllowlistCheck {

    /**
     * @notice Checks if an address is allowed.
     *
     * @param account The address to check.
     * @return bool Returns `true` if the address is allowed, otherwise `false`.
     */
    function hasAllow(address account) external view returns (bool);
}
