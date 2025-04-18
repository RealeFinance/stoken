// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMAmMMF} from "contracts/Interfaces/mAmMMF/ImAmMMF.sol";

contract ReUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Address of the rAmMMF token
    IERC20 public rammmf;

    // Address of the mAmMMF token
    IMAmMMF public mammmf;

    address public realeAdmin;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address upgrader,
        address _mAmMMF,
        address _rAmMMF,
        address _realeAdmin
    ) public initializer {
        __ERC20_init("reUSD", "MTK");
        __ERC20Permit_init("reUSD");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);

        rammmf = IERC20(_mAmMMF);
        mammmf = IMAmMMF(_rAmMMF);
        realeAdmin = _realeAdmin;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Function Users can lock rAmMMf tokens to exchange for reUSD.
     *
     * @param _rammfAmount The amount of AmMMF Tokens to lock
     *
     */
    function lockrAmMMfAndMintReUSD(uint256 _rammfAmount) external {
        require(
            rammmf.transferFrom(msg.sender, address(this), _rammfAmount),
            "rAmMMF:transfer failed"
        );
        _mint(msg.sender, _rammfAmount);
    }

    /**
     * @notice Function Users redeem rAmMMf and burn reUSD.
     *
     * @param _reUSDAmount The amount of reUSD Tokens to burn
     *
     */
    function unlockrAmMMfAndBurnReUSD(uint256 _reUSDAmount) external {
        _burn(msg.sender, _reUSDAmount);
        require(
            rammmf.transfer(msg.sender, _reUSDAmount),
            "rAmMMF:transfer failed"
        );
    }

    /**
     * @notice Function Users can lock mAmMMF tokens to exchange for reUSD.
     *
     * @param _mammfAmount The amount of AmMMF Tokens to lock
     *
     */
    function lockmAmMMfAndMintReUSD(uint256 _mammfAmount) external {
        require(
            mammmf.transferFrom(msg.sender, address(this), _mammfAmount),
            "mAmMMF:transfer failed"
        );
        _mint(realeAdmin, _getreUSDbymAmMMF(_mammfAmount));
    }

    /**
     * @notice Function Users redeem mAmMMF and burn reUSD.
     *
     * @param _reUSDAmount The amount of reUSD Tokens to burn
     *
     */
    function unlockmAmMMFAndBurnReUSD(uint256 _reUSDAmount) external {
        require(msg.sender == realeAdmin, "reUSD:not admin");
        _burn(realeAdmin, _reUSDAmount);
        mammmf.burnForm(msg.sender, _getmAmMMFbyreUSD(_reUSDAmount));
    }

    function _getmAmMMFbyreUSD(
        uint256 _reUSDAmount
    ) internal pure returns (uint256) {
        return _reUSDAmount * 1;
    }

    function _getreUSDbymAmMMF(
        uint256 _mammfAmount
    ) internal pure returns (uint256) {
        return _mammfAmount * 1;
    }
}
