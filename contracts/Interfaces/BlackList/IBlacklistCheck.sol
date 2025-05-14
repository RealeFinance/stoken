// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title IBlacklistCheck
 * @author zhangwenhai 
 * @notice Interface for a blocklist contract to manage blocked addresses.
 */
interface IBlacklistCheck {

    /**
     * @notice Checks if an address is blocked.
     *
     * @param account The address to check.
     * @return bool Returns `true` if the address is blocked, otherwise `false`.
     */
    function hasBlack(
        address account
    ) external view returns (bool);
}
