// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AllowList is AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    bytes32 public constant ALLOWLIST_ADMIN_ROLE =
        keccak256("ALLOWLIST_ADMIN_ROLE");
    bytes32 public constant ALLOWLIST_ROLE = keccak256("ALLOWLIST_ROLE");

    modifier inAllowlist() {
        require(
            hasRole(ALLOWLIST_ROLE, msg.sender),
            "Sender is not in allowlist"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(ALLOWLIST_ADMIN_ROLE, _msgSender());
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(ALLOWLIST_ADMIN_ROLE) {}

    function addToAllowlist(
        address account
    ) external onlyRole(ALLOWLIST_ADMIN_ROLE) {
        _beforeCheck(account, _msgSender());
        _grantRole(ALLOWLIST_ROLE, account);
    }

    function removeFromAllowlist(
        address account
    ) external onlyRole(ALLOWLIST_ADMIN_ROLE) {
        _beforeCheck(account, _msgSender());
        _revokeRole(ALLOWLIST_ROLE, account);
    }

    function hasAllow(
        address account
    ) external view onlyRole(ALLOWLIST_ADMIN_ROLE) returns (bool) {
        _beforeCheck(account, _msgSender());
        return super.hasRole(ALLOWLIST_ROLE, account);
    }

    function _beforeCheck(address from, address to) internal pure {
        require(from != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(to != address(0), "APPROVE_TO_ZERO_ADDRESS");
    }
}
