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

    address[] private tokenHolders;

    using SafeERC20 for IERC20;

    address public reUSD;

    uint256 public valueByReUSD;

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event calculateDailyInterestEvent(uint256 totalInterest);
    event stakeEvent(address sender, uint256 stakeAmount, uint256 reUSDAmount);
    event unStakeEvent(
        address sender,
        uint256 stakeAmount,
        uint256 reUSDAmount
    );

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
        valueByReUSD = 0;

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
        return (balanceOf(account) * valueByReUSD) / totalSupply();
    }

    function calculateDailyInterest() external onlyRole(STAKE_ADMIN) {
        uint256 totalInterest = IReUSD(reUSD).getTotalInterest();
        require(totalInterest > 0, "No interest to distribute");
        // Accumulate total interest into valueByReUSD
        if (totalSupply() > 0) {
            valueByReUSD += totalInterest;
            IReUSD(reUSD).resetTotalInterest();
            emit calculateDailyInterestEvent(totalInterest);
        }
    }

    /**
     * @notice Allows a user to stake a specified reUSDAmount of reUSD tokens.
     * @dev This function transfers the specified reUSDAmount of reUSD tokens from the user to the contract
     *      and mints an equivalent reUSDAmount of stakedReUSD tokens for the user.
     *      The function is only executable when the contract is not paused.
     * @param reUSDAmount The reUSDAmount of reUSD tokens to stake. Must be greater than zero.
     */
    function stake(uint256 reUSDAmount) external whenNotPaused {
        require(reUSDAmount > 0, "Amount must be greater than zero");
        uint256 stakeAmount = 0;
        if (valueByReUSD == 0) {
            stakeAmount = reUSDAmount;
        } else {
            stakeAmount = (reUSDAmount * totalSupply()) / valueByReUSD;
        }
        IERC20(reUSD).safeTransferFrom(msg.sender, address(this), reUSDAmount);
        valueByReUSD += reUSDAmount;
        // Mint stakedReUSD tokens to the user
        _mint(msg.sender, stakeAmount);

        emit stakeEvent(msg.sender, stakeAmount, reUSDAmount);
    }

    function unstake(uint256 stakeAmount) external whenNotPaused {
        require(stakeAmount > 0, "Amount must be greater than zero");
        uint256 reUSDAmount = (stakeAmount * valueByReUSD) / totalSupply();

        // Transfer reUSD tokens from the contract to the user
        require(
            IERC20(reUSD).transfer(msg.sender, reUSDAmount),
            "Transfer failed"
        );
        valueByReUSD -= reUSDAmount;
        // Burn the stakedReUSD tokens from the user
        _burn(msg.sender, stakeAmount);
        emit unStakeEvent(msg.sender, stakeAmount, reUSDAmount);
    }
}
