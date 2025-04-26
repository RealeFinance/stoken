// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import {IAllowlist} from "contracts/Interfaces/AllowList/IAllowlist1.sol";
import {IAllowlistCheck} from "contracts/Interfaces/AllowList/IAllowlistCheck.sol";
import "hardhat/console.sol";
contract AllowList is
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    IAllowlist,
    IAllowlistCheck
{
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

    function initialize() public initializer {
        __Allowlist_init();
    }

    function __Allowlist_init() internal onlyInitializing {
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __Allowlist_init_unchained();
    }

    function __Allowlist_init_unchained() internal onlyInitializing {
        _grantRole(ALLOWLIST_ADMIN_ROLE, _msgSender());
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(ALLOWLIST_ADMIN_ROLE) {}

    function addToAllowlist(
        address[] calldata accounts
    ) external onlyRole(ALLOWLIST_ADMIN_ROLE) {
        for (uint256 i; i < accounts.length; ) {
            _beforeCheck(accounts[i], _msgSender());
            _grantRole(ALLOWLIST_ROLE, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function removeFromAllowlist(
        address[] calldata accounts
    ) external onlyRole(ALLOWLIST_ADMIN_ROLE) {
        for (uint256 i; i < accounts.length; ) {
            _beforeCheck(accounts[i], _msgSender());
            _revokeRole(ALLOWLIST_ROLE, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function hasAllow(
        address msgSender,
        address account
    ) external view returns (bool) {
        require(
            hasRole(ALLOWLIST_ADMIN_ROLE, msgSender),
            "Sender is not in Admin"
        );
        _beforeCheck(account, _msgSender());
        return hasRole(ALLOWLIST_ROLE, account);
    }

    function hasAllow(
        address account
    ) external view onlyRole(ALLOWLIST_ADMIN_ROLE) returns (bool) {
        _beforeCheck(account, _msgSender());
        return hasRole(ALLOWLIST_ROLE, account);
    }

    function _beforeCheck(address from, address to) internal pure {
        require(from != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(to != address(0), "APPROVE_TO_ZERO_ADDRESS");
    }
}
