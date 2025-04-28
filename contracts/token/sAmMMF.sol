// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Address of the AmMMF token
    IERC20 public ammmf;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address _ammmf,
        address upgrader
    ) public initializer {
        __ERC20_init("sAmMMF", "MTK");
        __ERC20Permit_init("sAmMMF");
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);

        ammmf = IERC20(_ammmf);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    /**
     * @notice Wraps a specified amount of AmMMF tokens into sAmMMF tokens.
     * @dev Transfers the specified amount of AmMMF tokens from the caller to the contract
     *      and mints an equivalent amount of sAmMMF tokens for the caller.
     *      This function can only be called when the contract is not paused.
     * @param _AmMMFAmount The amount of AmMMF tokens to wrap.
     * @notice Emits a `Transfer` event for the minting of sAmMMF tokens.
     */
    function wrap(uint256 _AmMMFAmount) external whenNotPaused {
        require(_AmMMFAmount > 0, "sAmMMF: can't wrap zero AmMMF tokens");
        require(
            ammmf.transferFrom(msg.sender, address(this), _AmMMFAmount),
            "sAmMMF: Transfer failed"
        );
        _mint(msg.sender, _AmMMFAmount);
    }

    /**
     * @notice Unwraps a specified amount of sAmMMF tokens into the underlying amMMF tokens.
     * @dev This function burns the specified amount of sAmMMF tokens from the caller's balance
     *      and transfers the equivalent amount of amMMF tokens to the caller.
     *      The function is only executable when the contract is not paused.
     * @param _sAmMMFAmount The amount of sAmMMF tokens to unwrap.
     * @notice Emits a `Transfer` event for the burn operation.
     * @notice Emits a `Transfer` event for the amMMF token transfer.
     */
    function unwrap(uint256 _sAmMMFAmount) external whenNotPaused {
        require(_sAmMMFAmount > 0, "sAmMMF: can't unwrap zero sAmMMF tokens");
        _burn(msg.sender, _sAmMMFAmount);
        require(
            ammmf.transfer(msg.sender, _sAmMMFAmount),
            "sAmMMF: Transfer failed"
        );
    }
}
