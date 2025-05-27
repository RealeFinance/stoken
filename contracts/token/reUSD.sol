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
import "contracts/Interfaces/ICollateralConfig.sol";

contract ReUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Address of the token config contract
    ICollateralConfig public collateralConfig;

    AggregatorV2V3Interface internal priceFeed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     */
    function initialize(
        address _collateralConfig,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        collateralConfig = ICollateralConfig(_collateralConfig);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event SwapReUSD(address indexed to, uint256 amount, string tokenName);

    event RedeemReUSD(address indexed from, uint256 amount, string tokenName);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function lock(address _address, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        (string memory _tokenName, , , bool isMtoken, ) = collateralConfig
            .getCollateral(_address);
        if (isMtoken) {
            IMAmMMF(_address).transferFrom(msg.sender, address(this), _amount);
        } else {
            IERC20(_address).transferFrom(msg.sender, address(this), _amount);
        }
        uint256 reUSDAmount = collateralConfig.getReUSDAmount(
            _address,
            _amount
        );
        _mint(msg.sender, reUSDAmount);
        emit SwapReUSD(msg.sender, reUSDAmount, _tokenName);
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for mAmMMF tokens.
     * Burns the reUSD tokens and transfers mAmMMF to the user based on price.
     * @param _reUSDAmount The amount of reUSD to exchange.
     */
    function redeem(address _address, uint256 _reUSDAmount) external {
        require(_reUSDAmount > 0, "Amount must be greater than zero");
        (string memory _tokenName, , , bool isMtoken, ) = collateralConfig
            .getCollateral(_address);
        uint256 amount = collateralConfig.getAmountByReUSD(
            _address,
            _reUSDAmount
        );
        if (isMtoken) {
            IMAmMMF(_address).transfer(msg.sender, amount);
        } else {
            IERC20(_address).transfer(msg.sender, amount);
        }
        _burn(msg.sender, _reUSDAmount);
        emit RedeemReUSD(msg.sender, _reUSDAmount, _tokenName);

        // getAmountByReUSD
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
