// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title IMAmMMF
 * @author zhangwenhai
 * @notice Interface for mAmMMF contract to manage mint.
 */
interface IMAmMMF is ERC20Upgradeable {
    /**
     * @notice Mint tokens to a specific account.
     *
     * @param _account The address for minting tokens.
     * @param _amount The amount of minted token.
     */
    function mintFrom(address _account, uint256 _amount) external;

    /**
     * @notice Burn tokens from a specific account.
     *
     * @param _account The address for burning tokens.
     * @param _amount The amount of burned token.
     */
    function burnFrom(address _account, uint256 _amount) external;
}
