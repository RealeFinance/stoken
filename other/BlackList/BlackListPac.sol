// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBlocklist} from "contracts/Interfaces/BlackList/IBlocklistPac.sol";
import "hardhat/console.sol";

contract BlockListPac is
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    IBlocklist
{
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Staking vault address
    bytes32 public constant BLOCKLIST_ADMIN_ROLE =
        keccak256("BLOCKLIST_ADMIN_ROLE");
    bytes32 public constant BLOCKLIST_ROLE = keccak256("BLOCKLIST_ROLE");

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier notInBlacklist() {
        require(!hasRole(BLOCKLIST_ROLE, msg.sender), "Sender is in blacklist");
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
        _grantRole(BLOCKLIST_ADMIN_ROLE, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addRamMMFAddress(
        address accounts
    ) external onlyRole(BLOCKLIST_ADMIN_ROLE) {
        _grantRole(BLOCKLIST_ADMIN_ROLE, accounts);
    }

    function addToBlocklist(
        address[] calldata accounts
    ) external onlyRole(BLOCKLIST_ADMIN_ROLE) {
        for (uint256 i; i < accounts.length; ) {
            _beforeCheck(accounts[i], _msgSender());
            _grantRole(BLOCKLIST_ROLE, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function removeFromBlocklist(
        address[] calldata accounts
    ) external onlyRole(BLOCKLIST_ADMIN_ROLE) {
        for (uint256 i; i < accounts.length; ) {
            _beforeCheck(accounts[i], _msgSender());
            _revokeRole(BLOCKLIST_ROLE, accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function isBlocked(address account) external view returns (bool) {
        require(
            hasRole(BLOCKLIST_ADMIN_ROLE, _msgSender()),
            "Sender is not in Admin"
        );
        _beforeCheck(account, _msgSender());
        return hasRole(BLOCKLIST_ROLE, account);
    }

    function hasBlack(address account) external view returns (bool) {
        require(
            hasRole(BLOCKLIST_ADMIN_ROLE, _msgSender()),
            "Sender is not in Admin"
        );
        _beforeCheck(account, _msgSender());
        return hasRole(BLOCKLIST_ROLE, account);
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
