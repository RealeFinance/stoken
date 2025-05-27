// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

/**
 * @title ICollateralConfig
 * @author zhangwenhai
 * @notice Interface for a blocklist contract to manage blocked addresses.
 */
interface ICollateralConfig {
    /**
     * @notice Gets a specific Collateral by its address.
     * @param _addr The address of the Collateral to retrieve.
     * @return The name, address, ratio, isMCollateral, and isEnabled status of the Collateral.
     */
    function getCollateral(
        address _addr
    ) external view returns (string memory, address, uint, bool, bool);

    /**
     * @notice Gets the list of all Collateral addresses.
     * @return An array of addresses of all Collaterals.
     */
    function getReUSDAmount(
        address _addr,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @notice Gets the amount of collateral needed for a given reUSD amount.
     * @param _addr The address of the Collateral.
     * @param reUSDAmount The amount of reUSD to convert.
     * @return The amount of collateral needed.
     */
    function getAmountByReUSD(
        address _addr,
        uint256 reUSDAmount
    ) external view returns (uint256);
}
