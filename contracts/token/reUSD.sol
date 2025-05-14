// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
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

    AggregatorV2V3Interface internal priceFeed;

    address public realeAdmin;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address upgrader,
        address _mAmMMF,
        address _rAmMMF,
        address _realeAdmin
    ) public initializer {
        __ERC20_init("reUSD", "MTK");
        __ERC20Permit_init("reUSD");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, upgrader);

        rammmf = IERC20(_mAmMMF);
        mammmf = IMAmMMF(_rAmMMF);
        realeAdmin = _realeAdmin;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

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

    function setPriceFeed(
        address _priceFeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        priceFeed = AggregatorV2V3Interface(_priceFeed);
    }

    function getLatestETHPrice() public view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;
    }
}
