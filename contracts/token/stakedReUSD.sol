// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IReUSD} from "contracts/Interfaces/IReUSD.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract StakedReUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant STAKE_ADMIN = keccak256("STAKE_ADMIN");

    struct UnstakeRequest {
        uint256 unstaketimestamp;
        uint256 unstakeAmount;
        uint256 unstakeAmountByReUSD;
    }

    using SafeERC20 for IERC20;

    address public reUSD;

    // Total value of staked assets
    uint256 public valueByReUSD;

    // Protocol income ratio (percentage of total interest distributed to the protocol)
    // For example, if protocolIncomeRatio is 15, then 15% of the
    uint256 public protocolIncomeRatio;

    // Mapping to track the unstake request timestamp and amount for each user
    mapping(address => UnstakeRequest) private unstakeRequestMap;
    // Cooldown period in seconds (7 days)
    uint256 public constant UNSTAKE_COOLDOWN = 7 days;

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event calculateDailyInterestEvent(
        uint256 totalInterest,
        uint256 protocolIncome
    );
    event stakeEvent(address sender, uint256 stakeAmount, uint256 reUSDAmount);
    event unStakeEvent(
        address sender,
        uint256 stakeAmount,
        uint256 reUSDAmount
    );
    event withdrewEvent(
        address sender,
        uint256 stakeAmount,
        uint256 reUSDAmount
    );
    event protocolIncomeRatioChanged(uint256 oldRatio, uint256 newRatio);

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
        protocolIncomeRatio = 15; // 15% of the total interest will be distributed to the protocol

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
     * @notice Returns the current protocol income ratio.
     * @return The protocol income ratio.
     */
    function getProtocolIncomeRatio() external view returns (uint256) {
        return protocolIncomeRatio;
    }

    /**
     * @notice Sets the protocol income ratio.
     * @dev Only callable by STAKE_ADMIN.
     * @param ratio The new protocol income ratio.
     */
    function setProtocolIncomeRatio(
        uint256 ratio
    ) external onlyRole(STAKE_ADMIN) {
        require(ratio <= 100, "Ratio must be between 0 and 100");
        require(ratio >= 0, "Ratio must be between 0 and 100");
        uint256 oldRatio = protocolIncomeRatio;
        protocolIncomeRatio = ratio;
        emit protocolIncomeRatioChanged(oldRatio, ratio);
    }

    /**
     * @notice Retrieves the balance of an account, including the accumulated interest.
     * @param account The address of the account.
     * @return The total balance including interest.
     */
    function getBalanceWithInterest(
        address account
    ) public view returns (uint256) {
        return Math.mulDiv(balanceOf(account), valueByReUSD, totalSupply());
    }

    /**
     * @notice Calculates and distributes daily interest to staked reUSD holders.
     * @dev This function can only be called by the STAKE_ADMIN role.
     *      It retrieves the total interest from the reUSD contract, updates the valueByReUSD,
     *      and resets the total interest in the reUSD contract.
     */
    function calculateDailyInterest() external onlyRole(STAKE_ADMIN) {
        uint256 totalInterest = IReUSD(reUSD).getTotalInterest();
        require(totalInterest > 0, "No interest to distribute");
        // Accumulate total interest into valueByReUSD
        uint256 protocolIncome = (totalInterest * protocolIncomeRatio) / 100;
        if (totalSupply() > 0) {
            valueByReUSD += protocolIncome;
            IReUSD(reUSD).resetTotalInterest();
            emit calculateDailyInterestEvent(totalInterest, protocolIncome);
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
            stakeAmount = Math.mulDiv(reUSDAmount, totalSupply(), valueByReUSD);
        }
        IERC20(reUSD).safeTransferFrom(msg.sender, address(this), reUSDAmount);
        valueByReUSD += reUSDAmount;
        // Mint stakedReUSD tokens to the user
        _mint(msg.sender, stakeAmount);

        emit stakeEvent(msg.sender, stakeAmount, reUSDAmount);
    }

    /**
     * @notice Returns the unstakeAmount for a given account's UnstakeRequest.
     * @param account The address to query.
     * @return The unstakeAmount requested by the account.
     */
    function getUnstakeRequestAmount(
        address account
    ) public view returns (uint256) {
        return unstakeRequestMap[account].unstakeAmount;
    }

    function getUnstakeRequestAmountByReUSD(
        address account
    ) public view returns (uint256) {
        return unstakeRequestMap[account].unstakeAmountByReUSD;
    }

    /**
     * @notice Returns the unstaketimestamp for a given account's UnstakeRequest.
     * @param account The address to query.
     * @return The unstaketimestamp of the account's unstake request.
     */
    function getUnstakeimestamp(address account) public view returns (uint256) {
        return unstakeRequestMap[account].unstaketimestamp;
    }

    /**
     * @notice Allows a user to request an unstake of a specified amount of stakedReUSD tokens.
     * @dev The requested amount is added to any existing unstake request for the user.
     *      The function checks that the user has sufficient balance and that the requested amount is greater than zero.
     *      The unstake request is subject to a cooldown period defined by UNSTAKE_COOLDOWN.
     * @param stakeAmount The amount of stakedReUSD tokens to request for unstaking.
     */
    function unstake(uint256 stakeAmount) external whenNotPaused {
        require(stakeAmount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= stakeAmount, "Insufficient balance");
        uint256 _totalAmount = stakeAmount +
            getUnstakeRequestAmount(msg.sender);
        uint256 reUSDAmount = Math.mulDiv(
            _totalAmount,
            valueByReUSD,
            totalSupply()
        );
        _burn(msg.sender, stakeAmount);
        valueByReUSD -= reUSDAmount;
        unstakeRequestMap[msg.sender] = UnstakeRequest({
            unstaketimestamp: block.timestamp + UNSTAKE_COOLDOWN,
            unstakeAmount: _totalAmount,
            unstakeAmountByReUSD: reUSDAmount
        });

        emit unStakeEvent(msg.sender, _totalAmount, reUSDAmount);
    }

    /**
     * @notice Allows a user to unstake their requested amount of stakedReUSD tokens after the cooldown period.
     * @dev The function checks that the user has an unstake request and that the cooldown period has passed.
     *      It transfers the equivalent reUSD amount back to the user and burns the stakedReUSD tokens.
     */
    function withdrew() external whenNotPaused {
        uint256 stakeAmount = getUnstakeRequestAmount(msg.sender);
        uint256 reUSDAmount = getUnstakeRequestAmountByReUSD(msg.sender);
        require(stakeAmount > 0, "No unstake requested");
        require(
            block.timestamp >= getUnstakeimestamp(msg.sender),
            "Cooldown not finished"
        );

        require(
            IERC20(reUSD).transfer(msg.sender, reUSDAmount),
            "Transfer failed"
        );

        // Reset unstake request
        unstakeRequestMap[msg.sender] = UnstakeRequest({
            unstaketimestamp: 0,
            unstakeAmount: 0,
            unstakeAmountByReUSD: 0
        });

        emit withdrewEvent(msg.sender, stakeAmount, reUSDAmount);
    }
}
