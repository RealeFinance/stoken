// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMAmMMF} from "contracts/Interfaces/mAmMMF/ImAmMMF.sol";
contract MAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IMAmMMF
{
    // Role identifier for accounts allowed to perform contract upgrades.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Address of the escrow administrator responsible for minting and burning tokens.
    address public escrowAdmin;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the specified roles and addresses.
     * @param defaultAdmin The address to be granted the DEFAULT_ADMIN_ROLE.
     * @param upgrader The address to be granted the UPGRADER_ROLE, allowing contract upgrades.
     */
    function initialize(
        address defaultAdmin,
        address upgrader
    ) public initializer {
        __ERC20_init("mAmMMF", "MTK");
        __ERC20Permit_init("mAmMMF");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Sets the escrow administrator address.
     * @dev This function can only be called by the DEFAULT_ADMIN_ROLE.
     * @param _escrowAdmin The address of the escrow administrator.
     */
    function setEscrowAdmin(
        address _escrowAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _escrowAdmin != address(0),
            "MAmMMF: escrowAdmin cannot be the zero address"
        );
        escrowAdmin = _escrowAdmin;
    }

    /**
     * @notice Burns a specific amount of tokens from the specified account.
     * @dev This function can only be called by the `escrowAdmin`.
     *      It ensures that the account has a sufficient balance before burning.
     * @param _account The address of the account from which tokens will be burned.
     * @param _amount The amount of tokens to burn.
     */
    function burnFrom(address _account, uint256 _amount) external {
        require(
            msg.sender == escrowAdmin,
            "MAmMMF:Only the escrowAdmin can call burnFrom"
        );
        require(
            balanceOf(_account) >= _amount,
            "MAmMMF: Insufficient balance to burn"
        );
        _burn(_account, _amount);
    }

    /**
     * @notice Mints a specified amount of tokens to a given account.
     * @dev This function can only be called by the `escrowAdmin`.
     *      It uses the `_mint` internal function to create new tokens.
     * @param _account The address of the account to receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     */
    function mintFrom(address _account, uint256 _amount) external {
        require(
            msg.sender == escrowAdmin,
            "MAmMMF:Only the escrowAdmin can call mintFrom"
        );
        _mint(_account, _amount);
    }
}
