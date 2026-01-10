// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMAmMMF} from "contracts/Interfaces/mAmMMF/ImAmMMF.sol";

contract MAmMMFManagement is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    // Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Mapping to track the amount of MAmMMF minted by each user
    mapping(address => uint256) public mintedAmounts;

    // State variable to store an owner address
    address public owner;

    // State variables to store addresses
    IMAmMMF public MAmMMF;
    IERC20 public AmMMF;

    // Event to log changes
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // Initialize MAmMMF and AmMMF addresses in the initializer
    function initialize(
        string memory name,
        string memory symbol,
        address _MAmMMFAddress,
        address _AmMMFAddress
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        require(
            _MAmMMFAddress != address(0),
            "MAmMMF address cannot be the zero address"
        );
        require(
            _AmMMFAddress != address(0),
            "AmMMF address cannot be the zero address"
        );

        MAmMMF = IMAmMMF(_MAmMMFAddress);
        AmMMF = IERC20(_AmMMFAddress);

        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    // Modifier to restrict access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Function to transfer ownership
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Required by UUPSUpgradeable
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Calculates the maximum amount of MAmMMF tokens that can be minted by a given account.
     * @dev This function checks the balance of AmMMF tokens held by the account and subtracts the amount
     *      of MAmMMF tokens that the account has already minted.
     * @param _account The address of the account whose AmMMF balance and already minted MAmMMF tokens are being checked.
     * @return The maximum number of MAmMMF tokens that the account can mint. Returns 0 if the account's
     *         AmMMF balance is less than or equal to the amount already minted.
     */
    function getMaxMintableMAmMMF(
        address _account
    ) external view returns (uint256) {
        uint256 userAmMMFBalance = AmMMF.balanceOf(_account);
        uint256 alreadyMinted = mintedAmounts[_account];
        return
            userAmMMFBalance > alreadyMinted
                ? userAmMMFBalance - alreadyMinted
                : 0;
    }

    /**
     * @notice Mints MAmMMF tokens for a specified account based on their AmMMF balance.
     * @dev This function can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     *      It ensures that the minting amount is greater than zero and does not exceed
     *      the user's current AmMMF balance.
     * @param _account The address of the account for which MAmMMF tokens will be minted.
     * @param _amount The amount of MAmMMF tokens to mint.
     * @notice Updates the minted amounts for the account and calls the `mintFrom` function
     *         on the MAmMMF contract to mint the tokens.
     */
    function mintFromAmMMF(
        address _account,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_amount > 0, "Mint amount must be greater than zero");
        uint256 userAmMMFBalance = AmMMF.balanceOf(_account);
        require(userAmMMFBalance >= _amount, "Insufficient AmMMF balance");
        // Ensure the minting amount does not exceed the user's AmMMF balance

        // Update minted amounts and mint MAmMMF tokens
        mintedAmounts[_account] += _amount;
        MAmMMF.mintFrom(_account, _amount);
    }

    /**
     * @notice Burns a specified amount of MAmMMF tokens from a given account.
     * @dev This function can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     *      It ensures that the amount to be burned is greater than zero and that the
     *      account has sufficient MAmMMF balance. The function also verifies that the
     *      MAmMMF contract address is set and updates the minted amounts to prevent
     *      underflow.
     * @param _account The address of the account from which the tokens will be burned.
     * @param _amount The amount of MAmMMF tokens to burn.
     */
    function burnMAmMMF(
        address _account,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 userMAmMMFBalance = MAmMMF.balanceOf(_account);
        require(userMAmMMFBalance >= _amount, "Insufficient MAmMMF balance");

        // Burn the specified amount of MAmMMF tokens
        require(
            address(MAmMMF) != address(0),
            "MAmMMF contract address is not set"
        );
        MAmMMF.burnFrom(_account, _amount);

        // Update minted amounts
        require(
            mintedAmounts[_account] >= _amount,
            "Underflow: insufficient minted amount"
        );
        uint256 mintedAmount = mintedAmounts[_account];
        require(
            mintedAmount >= _amount,
            "Underflow: insufficient minted amount"
        );
        mintedAmount -= _amount;
        mintedAmounts[_account] = mintedAmount;
    }
}
