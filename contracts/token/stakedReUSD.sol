// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StakedReUSD is Initializable, ERC20Upgradeable {

    mapping(address account => uint256) override _balances;

    mapping(address => uint256) private interestBalances;

    mapping(uint256 => uint256) public dailyInterestRates;

    mapping(uint256 => bool) public dailyInterestUpdated;

    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC20_init(name, symbol);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @notice Transfers ownership of the contract to a new address.
     * @dev Can only be called by the current owner.
     * @param newOwner The address of the new owner. Must not be the zero address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    // /**
    //  * @notice Updates the interest balances for all accounts based on the daily interest rate.
    //  * @dev Can only be called once per day and updates the interest for the caller's account.
    //  * The interest is calculated as (balance * dailyInterestRate) / 10000 to support basis points.
    //  */
    // function updateInterest(address _account uint256 day) external {
    //     uint256 balance = balanceOf(_account);
    //     require(balance > 0, "No balance to calculate interest");



    //     uint256 interest = (balance * dailyInterestRates[day]) / 10000;
    //     interestBalances[_account] += interest;
    //     // dailyInterestUpdated[day] = true;
    // }

    /**
     * @notice Retrieves the balance of an account, including the accumulated interest.
     * @param account The address of the account.
     * @return The total balance including interest.
     */
    function getBalanceWithInterest(address account) external view returns (uint256) {
        return balanceOf(account) + interestBalances[account];
    }

    /**
     * @notice Sets the daily interest rate for a specific day.
     * @dev Can only be called by the owner.
     * @param day The day for which the interest rate is being set.
     * @param rate The interest rate in basis points (1% = 100 basis points).
     */
    function setDailyInterestRate(uint256 day, uint256 rate) external onlyOwner {
        require(rate > 0, "Interest rate must be greater than zero");
        dailyInterestRates[day] = rate;
    }

    /**
     * @notice Retrieves the accumulated interest balance for an account.
     * @param account The address of the account.
     * @return The accumulated interest balance.
     */
    function getInterestBalance(address account) external view returns (uint256) {
        return interestBalances[account];
    }
}
