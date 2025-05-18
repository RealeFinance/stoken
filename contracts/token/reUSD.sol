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

    // Address of the oracle
    IRWAOracle public oracle;

    AggregatorV2V3Interface internal priceFeed;

    // Address of the Reale admin
    address public realeAdmin;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the contract with the given parameters.
     * @param upgrader The address of the upgrader role.
     * @param _mAmMMF The address of the mAmMMF token.
     * @param _rAmMMF The address of the rAmMMF token.
     * @param _realeAdmin The address of the Reale admin.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     */
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

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event SwapReUSD(address indexed to, uint256 amount, string tokenType);

    event RedeemReUSD(address indexed from, uint256 amount, string tokenType);

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Converts a given amount of mAmMMF to reUSD based on the current price.
     * @param _mAmMMFMount The amount of mAmMMF to convert.
     * @return The equivalent amount of reUSD.
     */
    function getReUSDByMAmMMFMount(
        uint256 _mAmMMFMount
    ) internal view returns (uint256) {
        return (_mAmMMFMount * getAmMMFPrice()) / getReUSDPrice();
    }

    /**
     * @dev Converts a given amount of reUSD to mAmMMF based on the current price.
     * @param _reUSDMount The amount of reUSD to convert.
     * @return The equivalent amount of mAmMMF.
     */
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

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Allows users to exchange their rAmMMF tokens for reUSD tokens 1:1.
     * User must approve this contract to spend their rAmMMF before calling.
     * @param _rAmMMFMount The amount of rAmMMF to exchange.
     */
    function swapByRAmMMF(uint256 _rAmMMFMount) external {
        require(_rAmMMFMount > 0, "Amount must be greater than zero");
        rammmf.transferFrom(msg.sender, address(this), _rAmMMFMount);
        _mint(msg.sender, _rAmMMFMount);
        emit SwapReUSD(msg.sender, _rAmMMFMount, "rAmMMF");
    }

    /**
     * @dev Allows users to exchange their mAmMMF tokens for reUSD tokens 1:1.
     * User must approve this contract to spend their mAmMMF before calling.
     * @param _mAmMMFMount The amount of mAmMMF to exchange.
     */
    function swapByMAmMMF(uint256 _mAmMMFMount) external {
        require(_mAmMMFMount > 0, "Amount must be greater than zero");
        mammmf.transferFrom(msg.sender, address(this), _mAmMMFMount);
        uint256 reUSDAmount = getReUSDByMAmMMFMount(_mAmMMFMount);
        _mint(msg.sender, reUSDAmount);
        emit SwapReUSD(msg.sender, reUSDAmount, "mAmMMF");
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for rAmMMF tokens.
     * Burns the reUSD tokens and transfers rAmMMF to the user.
     * @param _reUSDMount The amount of reUSD to exchange.
     */
    function redeemToRAmMMF(uint256 _reUSDMount) external {
        require(_reUSDMount > 0, "Amount must be greater than zero");
        _burn(msg.sender, _reUSDMount);
        rammmf.transfer(msg.sender, _reUSDMount);
        emit RedeemReUSD(msg.sender, _reUSDMount, "rAmMMF");
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for mAmMMF tokens.
     * Burns the reUSD tokens and transfers mAmMMF to the user based on price.
     * @param _reUSDMount The amount of reUSD to exchange.
     */
    function redeemToMAmMMF(uint256 _reUSDMount) external {
        require(_reUSDMount > 0, "Amount must be greater than zero");
        uint256 mAmMMFMount = getMAmMMFByReUSDMount(_reUSDMount);
        _burn(msg.sender, _reUSDMount);
        mammmf.transfer(msg.sender, mAmMMFMount);
        emit RedeemReUSD(msg.sender, _reUSDMount, "mAmMMF");
    }

    /**
     * @dev Allows the admin to mint new reUSD tokens to a specified account.
     * @param account The address of the account to mint tokens to.
     * @param value The amount of reUSD tokens to mint.
     */
    function mint(
        address account,
        uint256 value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(account, value);
    }

    /**
     * @dev Allows the admin to burn reUSD tokens from a specified account.
     * @param account The address of the account to burn tokens from.
     * @param value The amount of reUSD tokens to burn.
     */
    function burn(
        address account,
        uint256 value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(account, value);
    }
}
