// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBlacklistCheck} from "contracts/Interfaces/BlackList/IBlacklistCheck.sol";
import {IAllowlistCheck} from "contracts/Interfaces/AllowList/IAllowlistCheck.sol";
import "hardhat/console.sol";

contract RAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    // Address of the Blacklist
    IBlacklistCheck public blacklist;

    IAllowlistCheck public allowlist;

    // bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _blacklist,
        address _allowlist
    ) public initializer {
        __ERC20_init("rAmMMF", "MTK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("rAmMMF");
        __UUPSUpgradeable_init();
        blacklist = IBlacklistCheck(_blacklist);
        allowlist = IAllowlistCheck(_allowlist);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // _grantRole(PAUSER_ROLE, pauser);
        // _grantRole(MINTER_ROLE, minter);
        // _grantRole(UPGRADER_ROLE, upgrader);
    }

    function isBlack(
        address account
    ) public view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return blacklist.hasBlack(_msgSender(), account);
    }

    function isAllow(
        address account
    ) public view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return allowlist.hasAllow(_msgSender(), account);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}
