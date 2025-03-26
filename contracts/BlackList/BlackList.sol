// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "hardhat/console.sol";

contract BlackList is AccessControlEnumerableUpgradeable {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Staking vault address
    bytes32 public constant BLACKLIST_ADMIN_ROLE =
        keccak256("BLACKLIST_ADMIN_ROLE");
    bytes32 public constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier notInBlacklist() {
        require(!hasRole(BLACKLIST_ROLE, msg.sender), "Sender is in blacklist");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              initialize
    //////////////////////////////////////////////////////////////*/

    function initialize() public initializer {
        __AccessControlEnumerable_init();
        __BlackList_init();
    }

    function __BlackList_init() internal onlyInitializing {
        __BlackList_init_unchained();
    }

    function __BlackList_init_unchained() internal onlyInitializing {
        _grantRole(BLACKLIST_ADMIN_ROLE, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addToBlacklist(
        address account
    ) external onlyRole(BLACKLIST_ADMIN_ROLE) {
        _beforeCheck(account, _msgSender());
        _grantRole(BLACKLIST_ROLE, account);
    }

    function removeFromBlacklist(
        address account
    ) external onlyRole(BLACKLIST_ADMIN_ROLE) {
        _beforeCheck(account, _msgSender());
        _revokeRole(BLACKLIST_ROLE, account);
    }

    function hasBlack(
        address account
    ) external view onlyRole(BLACKLIST_ADMIN_ROLE) returns (bool) {
        _beforeCheck(account, _msgSender());
        return super.hasRole(BLACKLIST_ROLE, account);
    }

    function getBlackAdmin() external view returns (bytes32) {
        return super.getRoleAdmin(DEFAULT_ADMIN_ROLE);
    }

    // function _authorizeUpgrade(
    //     address newImplementation
    // ) internal override onlyRole(BLACKLIST_ADMIN_ROLE) {}

    function _beforeCheck(address from, address to) internal pure {
        require(from != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(to != address(0), "APPROVE_TO_ZERO_ADDRESS");
    }
}
