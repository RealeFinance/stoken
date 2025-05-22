// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title ITokenConfig
 * @author zhangwenhai
 * @notice Interface for a blocklist contract to manage blocked addresses.
 */
interface ITokenConfig {
    /**
     * @notice Retrieves the token information for a given token name.
     * @param _name The name of the token.
     * @return The token's name and address.
     */
    function getToken(
        string memory _name
    ) external view returns (string memory, address);

    /**
     * @notice Retrieves the token address for a given token name.
     * @param _name The name of the token.
     * @return The address of the token contract.
     */
    function getTokenAddress(
        string memory _name
    ) external view returns (address);
}
