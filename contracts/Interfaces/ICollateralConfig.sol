// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

enum CollateralType {
    ERC20,
    MTOKEN, // Native isMtoken
    OTHER
}

struct Collateral {
    string name;
    address addr;
    uint ratio; // Ratio of the Collateral, e.g., 100 for 1:1 ratio; 125 for 125(Collateral):100(reUSD); 90 for 90(Collateral):100(reUSD)
    CollateralType collateralType; // Type of the Collateral (e.g., NATIVE, ERC20, etc.)
    bool isEnabled; // Whether the Collateral is enabled
}

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

    function getAllCollaterals() external view returns (Collateral[] memory);
}
