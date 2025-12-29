// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Snapshot} from "../ETF/Snapshot.sol";
import {IDividendDistributor} from "../../Interfaces/IDividendDistributor.sol";

/**
 * @title NavToken
 * @notice Platform token with snapshot capability for dividend distribution
 */
contract NavToken is ERC20, Ownable, Snapshot {
    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    IDividendDistributor public dividendDistributor;

    constructor(
        address initialOwner,
        uint256 initialSupply,
        address _dividendDistributor
    ) ERC20("NAV Platform Token", "NAV") Ownable(initialOwner) {
        _mint(initialOwner, initialSupply);

        _snapshotAccount(initialOwner, initialSupply);
        _snapshotTotalSupply(initialSupply);
        dividendDistributor = IDividendDistributor(_dividendDistributor);
    }

    /* ========== Snapshot ========== */

    /**
     * @notice Create a snapshot for dividend distribution
     * @dev Only callable by owner or governance
     */
    function snapshot() external onlyOwner returns (uint256) {
        uint256 id = _snapshot();
        _snapshotTotalSupply(totalSupply());
        return id;
    }

    function createDividend(
        uint256 snapshotId,
        uint256 amount
    ) external onlyOwner {
        dividendDistributor.createDividend(snapshotId, amount);
    }

    function createDividend(uint256 amount) external onlyOwner {
        createDividend(getCurrentSnapshotId(), amount);
    }

    /* ========== Mint / Burn (Optional) ========== */

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        _mint(to, amount);
        _snapshotAccount(to, balanceOf(to));
        _snapshotTotalSupply(totalSupply());
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        _snapshotAccount(msg.sender, balanceOf(msg.sender));
        _snapshotTotalSupply(totalSupply());
    }

    /* ========== Internal Overrides ========== */

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0)) {
            _snapshotAccount(from, balanceOf(from) - amount);
        }
        if (to != address(0)) {
            _snapshotAccount(to, balanceOf(to) + amount);
        }
        _snapshotTotalSupply(totalSupply());
        super._update(from, to, amount);
    }
}
