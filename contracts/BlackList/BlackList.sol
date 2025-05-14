// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBlacklist} from "contracts/Interfaces/BlackList/IBlacklist.sol";
import {IBlacklistCheck} from "contracts/Interfaces/BlackList/IBlacklistCheck.sol";
import "hardhat/console.sol";

contract BlackList is
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    IBlacklist,
    IBlacklistCheck
{
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
        __BlackList_init();
    }

    function __BlackList_init() internal onlyInitializing {
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __BlackList_init_unchained();
    }

    function __BlackList_init_unchained() internal onlyInitializing {
        _grantRole(BLACKLIST_ADMIN_ROLE, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addRamMMFAddress(
        address accounts
    ) external onlyRole(BLACKLIST_ADMIN_ROLE) {
        _grantRole(BLACKLIST_ADMIN_ROLE, accounts);
    }

    function addToBlacklist(
        address[] calldata accounts
    ) external onlyRole(BLACKLIST_ADMIN_ROLE) {
        for (uint256 i; i < accounts.length; ) {
            _beforeCheck(accounts[i], _msgSender());
            _grantRole(BLACKLIST_ROLE, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function removeFromBlacklist(
        address[] calldata accounts
    ) external onlyRole(BLACKLIST_ADMIN_ROLE) {
        for (uint256 i; i < accounts.length; ) {
            _beforeCheck(accounts[i], _msgSender());
            _revokeRole(BLACKLIST_ROLE, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function hasBlack(address account) external view returns (bool) {
        require(
            hasRole(BLACKLIST_ADMIN_ROLE, _msgSender()),
            "Sender is not in Admin"
        );
        _beforeCheck(account, _msgSender());
        return hasRole(BLACKLIST_ROLE, account);
    }

    function getBlackAdmin() external view returns (bytes32) {
        return super.getRoleAdmin(DEFAULT_ADMIN_ROLE);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _beforeCheck(address from, address to) internal pure {
        require(from != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(to != address(0), "APPROVE_TO_ZERO_ADDRESS");
    }
}
