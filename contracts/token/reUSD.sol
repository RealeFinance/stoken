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
import {IRWAOracle} from "contracts/Interfaces/rwaOracles/IRWAOracle.sol";

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

    IRWAOracle public oracle;

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
        address _realeAdmin,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, upgrader);

        mammmf = IMAmMMF(_mAmMMF);
        rammmf = IERC20(_rAmMMF);
        oracle = IRWAOracle(address(0));
        realeAdmin = _realeAdmin;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function getReUSDByMAmMMFMount(
        uint256 _mAmMMFMount
    ) internal view returns (uint256) {
        return (_mAmMMFMount * getAmMMFPrice()) / getReUSDPrice();
    }

    function getMAmMMFByReUSDMount(
        uint256 _reUSDMount
    ) internal view returns (uint256) {
        return (_reUSDMount * getReUSDPrice()) / getAmMMFPrice();
    }

    /**
     * @return price AmMMF
     */
    function getAmMMFPrice() internal view returns (uint256 price) {
        // (price, ) = oracle.getPriceData();
        return 1.00000000;
    }

    /**
     * @return price ReUSD
     */
    function getReUSDPrice() internal view returns (uint256 price) {
        // (price, ) = oracle.getPriceData();
        return 1.00000000;
    }

    /**
     * @dev Allows users to exchange their rAmMMF tokens for reUSD tokens 1:1.
     * User must approve this contract to spend their rAmMMF before calling.
     * @param _rAmMMFMount The amount of rAmMMF to exchange.
     */
    function swapByRAmMMf(uint256 _rAmMMFMount) external {
        require(_rAmMMFMount > 0, "Amount must be greater than zero");
        rammmf.transferFrom(msg.sender, address(this), _rAmMMFMount);
        _mint(msg.sender, _rAmMMFMount);
    }

    /**
     * @dev Allows users to exchange their mAmMMF tokens for reUSD tokens 1:1.
     * User must approve this contract to spend their mAmMMF before calling.
     * @param _mAmMMFMount The amount of mAmMMF to exchange.
     */
    function swapByMAmMMf(uint256 _mAmMMFMount) external {
        require(_mAmMMFMount > 0, "Amount must be greater than zero");
        mammmf.transferFrom(msg.sender, address(this), _mAmMMFMount);
        _mint(msg.sender, getReUSDByMAmMMFMount(_mAmMMFMount));
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for rAmMMF tokens 1:1.
     * Burns the reUSD tokens and transfers rAmMMF to the user.
     * @param _reUSDMount The amount of reUSD to exchange.
     */
    function redeemToRAmMMf(uint256 _reUSDMount) external {
        require(_reUSDMount > 0, "Amount must be greater than zero");
        _burn(msg.sender, _reUSDMount);
        require(
            rammmf.transfer(msg.sender, _reUSDMount),
            "Transfer of rAmMMF failed"
        );
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for mAmMMF tokens.
     * Burns the reUSD tokens and transfers mAmMMF to the user based on price.
     * @param _reUSDMount The amount of reUSD to exchange.
     */
    function redeemToMAmMMf(uint256 _reUSDMount) external {
        require(_reUSDMount > 0, "Amount must be greater than zero");
        uint256 mAmMMFMount = getMAmMMFByReUSDMount(_reUSDMount);
        _burn(msg.sender, _reUSDMount);
        require(
            mammmf.transfer(msg.sender, mAmMMFMount),
            "Transfer of mAmMMF failed"
        );
    }

    function mint(
        address account,
        uint256 value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(account, value);
    }
}
