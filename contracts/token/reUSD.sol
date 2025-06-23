// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import {IMAmMMF} from "contracts/Interfaces/mAmMMF/ImAmMMF.sol";
import {Collateral, CollateralType, ICollateralConfig} from "contracts/Interfaces/ICollateralConfig.sol";
import {IReUSD} from "contracts/Interfaces/IReUSD.sol";

contract ReUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    IReUSD
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REBASE_ADMIN = keccak256("REBASE_ADMIN");

    // Address of the token config contract
    ICollateralConfig public collateralConfig;

    AggregatorV2V3Interface internal priceFeed;

    // Total interest accrued in the system
    uint256 public totalInterest;

    address public stakedReUSD;

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
        address _stakedReUSD,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REBASE_ADMIN, msg.sender);
        totalInterest = 0;
        stakedReUSD = _stakedReUSD;

        collateralConfig = ICollateralConfig(_collateralConfig);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // The following functions are overrides required by Solidity.
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    function pause() public onlyRole(REBASE_ADMIN) {
        _pause();
    }

    function unpause() public onlyRole(REBASE_ADMIN) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event SwapReUSD(
        address indexed to,
        uint256 reUSDAmount,
        address tokenAddress,
        uint256 lockAmount
    );

    event RedeemReUSD(
        address indexed from,
        uint256 reUSDAmount,
        address tokenAddress,
        uint256 redeemAmount
    );

    event AddInterestByReUSD(address indexed to, uint256 reUSDAmount);

    event resetInterest();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Locks a specified amount of collateral and mints reUSD tokens.
     * @param _address The address of the collateral token.
     * @param _amount The amount of collateral to lock.
     */
    function lock(address _address, uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero");
        (, , , bool isMtoken, ) = collateralConfig.getCollateral(_address);
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
        emit SwapReUSD(msg.sender, reUSDAmount, _address, _amount);
    }

    /**
     * @dev Redeems reUSD tokens for the underlying collateral.
     * @param _address The address of the collateral token.
     * @param _reUSDAmount The amount of reUSD tokens to redeem.
     */
    function redeem(
        address _address,
        uint256 _reUSDAmount
    ) external whenNotPaused {
        require(_reUSDAmount > 0, "Amount must be greater than zero");
        (, , , bool isMtoken, ) = collateralConfig.getCollateral(_address);
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
        emit RedeemReUSD(msg.sender, _reUSDAmount, _address, amount);
    }

    /**
     * @dev Updates the total interest accrued in the system by summing up the balances of all enabled collateral tokens.
     * This function can only be called by the REBASE_ADMIN role.
     */
    function updateTotalInterest() external onlyRole(REBASE_ADMIN) {
        Collateral[] memory list = collateralConfig.getAllCollaterals();
        uint256 _totalInterest = 0;
        for (uint256 i = 0; i < list.length; i++) {
            Collateral memory collateral = list[i];
            if (collateral.isEnabled) {
                _totalInterest =
                    _totalInterest +
                    IERC20(collateral.addr).balanceOf(address(this));
            }
        }
        require(_totalInterest - totalSupply() > 0, "No interest to mint");
        totalInterest = _totalInterest - totalSupply();
        _mint(stakedReUSD, totalInterest);
        emit AddInterestByReUSD(stakedReUSD, totalInterest);
    }

    function getTotalInterest() external view returns (uint256) {
        return totalInterest;
    }

    function resetTotalInterest() external onlyRole(REBASE_ADMIN) {
        totalInterest = 0;
        emit resetInterest();
    }

    /**
     * @dev Allows the admin to mint new reUSD tokens to a specified account.
     * @param account The address of the account to mint tokens to.
     * @param value The amount of reUSD tokens to mint.
     */
    function mint(
        address account,
        uint256 value
    ) external onlyRole(REBASE_ADMIN) {
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
    ) external onlyRole(REBASE_ADMIN) {
        _burn(account, value);
    }
}
