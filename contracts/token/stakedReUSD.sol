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
    }

    using SafeERC20 for IERC20;

    address public reUSD;

    uint256 public valueByReUSD;

    // Mapping to track the unstake request timestamp and amount for each user
    mapping(address => UnstakeRequest) private unstakeRequestMap;
    // Cooldown period in seconds (7 days)
    uint256 public constant UNSTAKE_COOLDOWN = 7 days;

    // Array to record addresses that have made an UnstakeRequest
    address[] private unstakeRequestUsers;

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
            stakeAmount = Math.mulDiv(reUSDAmount, totalSupply(), valueByReUSD);
        }
        IERC20(reUSD).safeTransferFrom(msg.sender, address(this), reUSDAmount);
        valueByReUSD += reUSDAmount;
        // Mint stakedReUSD tokens to the user
        _mint(msg.sender, stakeAmount);

        emit stakeEvent(msg.sender, stakeAmount, reUSDAmount);
    }

    /**
     * @notice Returns the list of UnstakeRequest objects for all users in unstakeRequestUsers.
     */
    function getUnstakeRequests()
        external
        view
        onlyRole(STAKE_ADMIN)
        returns (UnstakeRequest[] memory)
    {
        UnstakeRequest[] memory requests = new UnstakeRequest[](
            unstakeRequestUsers.length
        );
        for (uint256 i = 0; i < unstakeRequestUsers.length; i++) {
            requests[i] = unstakeRequestMap[unstakeRequestUsers[i]];
        }
        return requests;
    }

    /**
     * @dev Internal function to add a user to the unstakeRequestUsers array if not already present.
     */
    function _addUnstakeRequestUser(address user) internal {
        for (uint256 i = 0; i < unstakeRequestUsers.length; i++) {
            if (unstakeRequestUsers[i] == user) {
                return;
            }
        }
        unstakeRequestUsers.push(user);
    }

    /**
     * @notice Removes a user from the unstakeRequestUsers array.
     * @dev Only removes the first occurrence if present.
     * @param user The address to remove.
     */
    function _removeUnstakeRequestUser(address user) internal {
        for (uint256 i = 0; i < unstakeRequestUsers.length; i++) {
            if (unstakeRequestUsers[i] == user) {
                unstakeRequestUsers[i] = unstakeRequestUsers[
                    unstakeRequestUsers.length - 1
                ];
                unstakeRequestUsers.pop();
                break;
            }
        }
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
    function requestUnstake(uint256 stakeAmount) external whenNotPaused {
        require(stakeAmount > 0, "Amount must be greater than zero");
        uint256 _totalAmount = stakeAmount +
            getUnstakeRequestAmount(msg.sender);
        require(balanceOf(msg.sender) >= _totalAmount, "Insufficient balance");
        unstakeRequestMap[msg.sender] = UnstakeRequest({
            unstaketimestamp: block.timestamp + UNSTAKE_COOLDOWN,
            unstakeAmount: _totalAmount
        });
        _addUnstakeRequestUser(msg.sender);
    }

    /**
     * @notice Allows a user to unstake their requested amount of stakedReUSD tokens after the cooldown period.
     * @dev The function checks that the user has an unstake request and that the cooldown period has passed.
     *      It transfers the equivalent reUSD amount back to the user and burns the stakedReUSD tokens.
     */
    function unstake() external whenNotPaused {
        uint256 stakeAmount = getUnstakeRequestAmount(msg.sender);
        require(stakeAmount > 0, "No unstake requested");
        require(
            block.timestamp >= getUnstakeimestamp(msg.sender),
            "Cooldown not finished"
        );

        uint256 reUSDAmount = Math.mulDiv(
            stakeAmount,
            valueByReUSD,
            totalSupply()
        );
        require(
            IERC20(reUSD).transfer(msg.sender, reUSDAmount),
            "Transfer failed"
        );
        valueByReUSD -= reUSDAmount;
        _burn(msg.sender, stakeAmount);

        // Reset unstake request
        unstakeRequestMap[msg.sender] = UnstakeRequest({
            unstaketimestamp: 0,
            unstakeAmount: 0
        });
        _removeUnstakeRequestUser(msg.sender);

        emit unStakeEvent(msg.sender, stakeAmount, reUSDAmount);
    }
}
