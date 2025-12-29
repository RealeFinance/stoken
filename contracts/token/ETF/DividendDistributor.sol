// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ISnapshot} from "../../Interfaces/ISnapshot.sol";
import {IDividendDistributor} from "../../Interfaces/IDividendDistributor.sol";

contract DividendDistributor is Ownable(msg.sender), IDividendDistributor {
    IERC20 public dividendToken; // USDT / USDC
    ISnapshot public navToken;

    struct DividendRound {
        uint256 snapshotId;
        uint256 totalAmount;
    }

    DividendRound[] public rounds;
    mapping(uint256 => mapping(address => bool)) public claimed;

    constructor(address _navToken, address _dividendToken) {
        navToken = ISnapshot(_navToken);
        dividendToken = IERC20(_dividendToken);
    }

    /// 创建一轮分红（在快照之后）
    function createDividend(
        uint256 snapshotId,
        uint256 amount
    ) external onlyOwner {
        dividendToken.transferFrom(msg.sender, address(this), amount);
        rounds.push(DividendRound(snapshotId, amount));
    }

    /// 用户领取指定轮次分红
    function claim(uint256 roundId) external {
        require(!claimed[roundId][msg.sender], "Already claimed");
        uint256 payout = _getDividendbyRoundId(roundId, msg.sender);
        claimed[roundId][msg.sender] = true;
        dividendToken.transfer(msg.sender, payout);
    }

    function getLastRoundsId() external view returns (uint256) {
        return rounds.length;
    }

    function getRoundInfo(
        uint256 roundId
    ) external view returns (uint256, uint256) {
        DividendRound memory r = rounds[roundId];
        return (r.snapshotId, r.totalAmount);
    }

    function getClaimedStatus(
        uint256 roundId,
        address account
    ) external view returns (uint256, bool, uint256) {
        return (
            _getDividendbyRoundId(roundId, account),
            claimed[roundId][account],
            rounds[roundId].totalAmount
        );
    }

    function _getDividendbyRoundId(
        uint256 roundId,
        address account
    ) internal view returns (uint256) {
        DividendRound memory r = rounds[roundId];
        require(r.snapshotId != 0, "Invalid snapshotId");
        uint256 userBalance = navToken.balanceOfAt(account, r.snapshotId);
        uint256 totalSupply = navToken.totalSupplyAt(r.snapshotId);
        uint256 payout = (r.totalAmount * userBalance) / totalSupply;
        return payout;
    }
}
