// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IReUSD} from "contracts/Interfaces/IReUSD.sol";

contract StakedReUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant STAKE_ADMIN = keccak256("STAKE_ADMIN");

    mapping(address => uint256) private interestBalances;

    address[] private tokenHolders;

    using SafeERC20 for IERC20;

    address public reUSD;

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event calculateDailyInterestEvent(uint256 totalInterest);
    event stakeEvent(address sender, uint256 amount);
    event unStakeEvent(address sender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              initialize
    //////////////////////////////////////////////////////////////*/
    function initialize(
        string memory name,
        string memory symbol,
        address _reUSD
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControl_init();
        reUSD = _reUSD;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STAKE_ADMIN, msg.sender);
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
        whenNotPaused
    {
        super._update(from, to, value);
        _updateTokenHolders(from);
        _updateTokenHolders(to);
    }

    /**
     * @notice Pauses all token transfers.
     * @dev Can only be called by the owner.
     */
    function pause() external onlyRole(STAKE_ADMIN) {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers.
     * @dev Can only be called by the owner.
     */
    function unpause() external onlyRole(STAKE_ADMIN) {
        _unpause();
    }

    /**
     * @dev Updates the list of token holders based on their balances.
     *
     * This function ensures that the `tokenHolders` array accurately reflects
     * the current holders of tokens. It performs the following operations:
     *
     * - If the `account` is not already in the `tokenHolders` array and has a
     *   positive token balance, it adds the `account` to the array.
     * - If the `account` is already in the `tokenHolders` array but its token
     *   balance is zero, it removes the `account` from the array by replacing
     *   it with the last element and then popping the last element.
     *
     * @param account The address of the account to update in the `tokenHolders` array.
     */
    function _updateTokenHolders(address account) private {
        bool exists = false;
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            if (tokenHolders[i] == account) {
                exists = true;
                break;
            }
        }
        if (!exists && balanceOf(account) > 0) {
            tokenHolders.push(account);
        } else if (exists && balanceOf(account) == 0) {
            for (uint256 i = 0; i < tokenHolders.length; i++) {
                if (tokenHolders[i] == account) {
                    tokenHolders[i] = tokenHolders[tokenHolders.length - 1];
                    tokenHolders.pop();
                    break;
                }
            }
        }
    }

    /**
     * @notice Retrieves the balance of an account, including the accumulated interest.
     * @param account The address of the account.
     * @return The total balance including interest.
     */
    function getBalanceWithInterest(
        address account
    ) public view returns (uint256) {
        return balanceOf(account) + interestBalances[account];
    }

    /**
     * @notice Retrieves the accumulated interest balance for an account.
     * @param account The address of the account.
     * @return The accumulated interest balance.
     */
    function getInterestBalance(
        address account
    ) external view returns (uint256) {
        return interestBalances[account];
    }

    function calculateDailyInterest() external onlyRole(STAKE_ADMIN) {
        uint256 totalInterest = IReUSD(reUSD).getTotalInterest();
        require(totalInterest > 0, "No interest to distribute");
        for (uint256 i = 0; i < tokenHolders.length; i++) {
            address account = tokenHolders[i];
            uint256 balance = balanceOf(account);
            uint256 interest = (totalInterest * balance) / totalSupply();
            interestBalances[account] += interest;
        }
        IReUSD(reUSD).resetTotalInterest();
        emit calculateDailyInterestEvent(totalInterest);
    }

    /**
     * @notice Allows a user to stake a specified amount of reUSD tokens.
     * @dev This function transfers the specified amount of reUSD tokens from the user to the contract
     *      and mints an equivalent amount of stakedReUSD tokens for the user.
     *      The function is only executable when the contract is not paused.
     * @param amount The amount of reUSD tokens to stake. Must be greater than zero.
     */
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        // Transfer reUSD tokens from the user to the contract
        IERC20(reUSD).safeTransferFrom(msg.sender, address(this), amount);

        // Mint stakedReUSD tokens to the user
        _mint(msg.sender, amount);

        emit stakeEvent(msg.sender, amount);
    }

    /**
     * @notice Allows users to unstake their stakedReUSD tokens and withdraw reUSD tokens.
     * @dev The function first deducts the unstake amount from the principal balance (staked tokens).
     *      If the unstake amount exceeds the principal balance, the remaining amount is deducted
     *      from the accumulated interest balance. The function ensures that the user has sufficient
     *      combined principal and interest balance to cover the unstake amount.
     * @param amount The amount of stakedReUSD tokens to unstake.
     */
    function unstake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        require(
            getBalanceWithInterest(msg.sender) >= amount,
            "Insufficient stakedReUSD balance"
        );

        uint256 principalBalance = balanceOf(msg.sender);
        uint256 interestBalance = interestBalances[msg.sender];

        if (amount <= principalBalance) {
            // Burn the amount from the principal balance
            _burn(msg.sender, amount);
        } else {
            // Calculate the remaining amount after exhausting the principal balance
            // Calculate the portion of the unstake amount that will be covered by the interest balance
            uint256 remainingAmount = amount - principalBalance;

            // Ensure the interest balance is sufficient to cover the remaining amount
            require(
                remainingAmount <= interestBalance,
                "Insufficient interest balance to unstake"
            );

            require(
                interestBalances[msg.sender] >= remainingAmount,
                "Insufficient interest balance"
            );
            interestBalances[msg.sender] -= remainingAmount;
            _burn(msg.sender, principalBalance);
        }

        // Transfer reUSD tokens from the contract to the user
        require(IERC20(reUSD).transfer(msg.sender, amount), "Transfer failed");

        emit unStakeEvent(msg.sender, amount);
    }
}
