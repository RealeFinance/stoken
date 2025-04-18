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
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public amMMFAdmin;

    address public realeAdmin;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address upgrader,
        address _amMMFAdmin,
        address _realeAdmin
    ) public initializer {
        __ERC20_init("mAmMMF", "MTK");
        __ERC20Permit_init("mAmMMF");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);

        amMMFAdmin = _amMMFAdmin;
        realeAdmin = _realeAdmin;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function mintForm(address _account, uint256 _amount) external {
        require(
            msg.sender == amMMFAdmin,
            "MAmMMF:Only the amMMFadmin can call mintForm"
        );
        _mint(_account, _amount);
    }

    function burnForm(address _account, uint256 _amount) external {
        require(
            msg.sender == realeAdmin,
            "MAmMMF:Only the realeAdmin can call burnForm"
        );
        _burn(_account, _amount);
    }
}
