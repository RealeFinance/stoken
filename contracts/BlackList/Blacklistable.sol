// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Blacklistable Token
 * @dev Allows accounts to be blacklisted by a "blacklister" role
 */
abstract contract Blacklistable is
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant STOKEN_BLACKLIST_ADMIN_ROLE =
        keccak256("STOKEN_BLACKLIST_ADMIN_ROLE");

    mapping(address => bool) internal _deprecatedBlacklisted;

    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);
    event BlacklisterAdminAdd(address indexed newBlacklister);
    event BlacklisterAdminRemove(address indexed newBlacklister);

    /**
     * @dev Throws if argument account is blacklisted.
     * @param _account The address to check.
     */
    modifier notBlacklisted(address _account) {
        require(
            !_isBlacklisted(_account),
            "Blacklisted"
        );
        _;
    }

    /**
     * @notice Checks if account is blacklisted.
     * @param _account The address to check.
     * @return True if the account is blacklisted, false if the account is not blacklisted.
     */
    function isBlacklisted(address _account) external view returns (bool) {
        return _isBlacklisted(_account);
    }

    /**
     * @notice Updates the blacklister address.
     * @param _newBlacklister The address of the new blacklister.
     */
    function addBlacklistAdmin(
        address _newBlacklister
    ) external onlyRole(STOKEN_BLACKLIST_ADMIN_ROLE) {
        require(
            _newBlacklister != address(0),
            "Blacklister is zero address"
        );
        _grantRole(STOKEN_BLACKLIST_ADMIN_ROLE, _newBlacklister);
        emit BlacklisterAdminAdd(_newBlacklister);
    }

    /**
     * @notice Removes the blacklister role from an account.
     * @param _blacklister The address of the blacklister to remove.
     */
    function removeBlacklistAdmin(
        address _blacklister
    ) external onlyRole(STOKEN_BLACKLIST_ADMIN_ROLE) {
        require(
            hasRole(STOKEN_BLACKLIST_ADMIN_ROLE, _blacklister),
            "Not a blacklister"
        );
        _revokeRole(STOKEN_BLACKLIST_ADMIN_ROLE, _blacklister);
        emit BlacklisterAdminRemove(_blacklister);
    }

    /**
     * @dev Checks if account is blacklisted.
     * @param _account The address to check.
     * @return true if the account is blacklisted, false otherwise.
     */
    function _isBlacklisted(
        address _account
    ) internal view virtual returns (bool);

    /**
     * @dev Helper method that blacklists an account.
     * @param _account The address to blacklist.
     */
    function _blacklist(address _account) internal virtual;

    /**
     * @dev Helper method that unblacklists an account.
     * @param _account The address to unblacklist.
     */
    function _unBlacklist(address _account) internal virtual;
}
