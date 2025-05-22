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
import "contracts/Interfaces/ITokenConfig.sol";

contract ReUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Address of the token config contract
    ITokenConfig public tokenConfig;

    // Address of the rAmMMF token
    IERC20 public rammmf;

    // Address of the mAmMMF token
    IMAmMMF public mammmf;

    // Address of the oracle
    IRWAOracle public oracle;

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
     * @param _mAmMMF The address of the mAmMMF token.
     * @param _rAmMMF The address of the rAmMMF token.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     */
    function initialize(
        address _mAmMMF,
        address _rAmMMF,
        address _tokenConfig,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        mammmf = IMAmMMF(_mAmMMF);
        rammmf = IERC20(_rAmMMF);
        oracle = IRWAOracle(address(0));
        tokenConfig = ITokenConfig(_tokenConfig);
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
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Converts a given amount of mAmMMF to reUSD based on the current price.
     * @param _mAmMMFAmount The amount of mAmMMF to convert.
     * @return The equivalent amount of reUSD.
     */
    function getReUSDByMAmMMFAmount(
        uint256 _mAmMMFAmount
    ) internal view returns (uint256) {
        return (_mAmMMFAmount * getAmMMFPrice()) / getReUSDPrice();
    }

    /**
     * @dev Converts a given amount of reUSD to mAmMMF based on the current price.
     * @param _reUSDAmount The amount of reUSD to convert.
     * @return The equivalent amount of mAmMMF.
     */
    function getMAmMMFByReUSDAmount(
        uint256 _reUSDAmount
    ) internal view returns (uint256) {
        return (_reUSDAmount * getReUSDPrice()) / getAmMMFPrice();
    }

    /**
     * @dev Converts a given amount of mAmMMF to reUSD based on the current price.
     * @param _tokenAmount The amount of mAmMMF to convert.
     * @return The equivalent amount of reUSD.
     */
    function getReUSDAmountByToken(
        address _address,
        uint256 _tokenAmount
    ) internal view returns (uint256) {
        return (_tokenAmount * getTokenPrice(_address)) / getReUSDPrice();
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
     * @return price Token
     */
    function getTokenPrice(
        address _address
    ) internal view returns (uint256 price) {
        // (price, ) = oracle.getPriceData();
        return 1.00000000;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function lock(string memory _tokenName, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        if (keccak256(bytes(_tokenName)) == keccak256(bytes("mAmMMF"))) {
            lockByMAmMMF(_amount);
            return;
        } else if (keccak256(bytes(_tokenName)) == keccak256(bytes("rAmMMF"))) {
            lockByRAmMMF(_amount);
            return;
        } else {
            (, address _address) = tokenConfig.getToken(_tokenName);
            IERC20(_address).transferFrom(msg.sender, address(this), _amount);
            uint256 reUSDAmount = getReUSDAmountByToken(_address, _amount);
            _mint(msg.sender, reUSDAmount);
            emit SwapReUSD(msg.sender, reUSDAmount, _tokenName);
        }
    }

    /**
     * @dev Allows users to exchange their rAmMMF tokens for reUSD tokens 1:1.
     * User must approve this contract to spend their rAmMMF before calling.
     * @param _rAmMMFAmount The amount of rAmMMF to exchange.
     */
    function lockByRAmMMF(uint256 _rAmMMFAmount) internal {
        rammmf.transferFrom(msg.sender, address(this), _rAmMMFAmount);
        _mint(msg.sender, _rAmMMFAmount);
        emit SwapReUSD(msg.sender, _rAmMMFAmount, "rAmMMF");
    }

    /**
     * @dev Allows users to exchange their mAmMMF tokens for reUSD tokens 1:1.
     * User must approve this contract to spend their mAmMMF before calling.
     * @param _mAmMMFAmount The amount of mAmMMF to exchange.
     */
    function lockByMAmMMF(uint256 _mAmMMFAmount) internal {
        mammmf.transferFrom(msg.sender, address(this), _mAmMMFAmount);
        uint256 reUSDAmount = getReUSDByMAmMMFAmount(_mAmMMFAmount);
        _mint(msg.sender, reUSDAmount);
        emit SwapReUSD(msg.sender, reUSDAmount, "mAmMMF");
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for mAmMMF tokens.
     * Burns the reUSD tokens and transfers mAmMMF to the user based on price.
     * @param _reUSDAmount The amount of reUSD to exchange.
     */
    function redeem(string memory _tokenName, uint256 _reUSDAmount) external {
        require(_reUSDAmount > 0, "Amount must be greater than zero");
        if (keccak256(bytes(_tokenName)) == keccak256(bytes("mAmMMF"))) {
            redeemToMAmMMF(_reUSDAmount);
            return;
        } else if (keccak256(bytes(_tokenName)) == keccak256(bytes("rAmMMF"))) {
            redeemToRAmMMF(_reUSDAmount);
            return;
        } else {
            (, address _address) = tokenConfig.getToken(_tokenName);
            uint256 mAmMMFAmount = getReUSDAmountByToken(
                _address,
                _reUSDAmount
            );
            _burn(msg.sender, _reUSDAmount);
            IERC20(_address).transfer(msg.sender, mAmMMFAmount);
            emit RedeemReUSD(msg.sender, _reUSDAmount, _tokenName);
        }
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for rAmMMF tokens.
     * Burns the reUSD tokens and transfers rAmMMF to the user.
     * @param _reUSDAmount The amount of reUSD to exchange.
     */
    function redeemToRAmMMF(uint256 _reUSDAmount) internal {
        _burn(msg.sender, _reUSDAmount);
        rammmf.transfer(msg.sender, _reUSDAmount);
        emit RedeemReUSD(msg.sender, _reUSDAmount, "rAmMMF");
    }

    /**
     * @dev Allows users to exchange their reUSD tokens for mAmMMF tokens.
     * Burns the reUSD tokens and transfers mAmMMF to the user based on price.
     * @param _reUSDAmount The amount of reUSD to exchange.
     */
    function redeemToMAmMMF(uint256 _reUSDAmount) internal {
        uint256 mAmMMFAmount = getMAmMMFByReUSDAmount(_reUSDAmount);
        _burn(msg.sender, _reUSDAmount);
        mammmf.transfer(msg.sender, mAmMMFAmount);
        emit RedeemReUSD(msg.sender, _reUSDAmount, "mAmMMF");
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
