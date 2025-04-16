// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title IMAmMMF
 * @author zhangwenhai
 * @notice Interface for mAmMMF contract to manage mint.
 */
interface IMAmMMF is IERC20 {
    /**
     * @notice
     *
     * @param _account The address for minting tokens.
     * @param _amount The amount of minted token.
     */
    function mintForm(address _account, uint256 _amount) external;
}
