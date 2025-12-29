// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.

pragma solidity ^0.8.22;

import {ISnapshot} from "../../Interfaces/ISnapshot.sol";

abstract contract Snapshot is ISnapshot {
    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    uint256 private _currentSnapshotId;

    mapping(address => Snapshots) private _accountSnapshots;
    Snapshots private _totalSupplySnapshots;

    function getCurrentSnapshotId() internal view returns (uint256) {
        return _currentSnapshotId;
    }

    /* ========= Core Snapshot ========= */

    function _snapshot() internal returns (uint256) {
        _currentSnapshotId++;
        return _currentSnapshotId;
    }

    function _writeSnapshot(
        Snapshots storage snapshots,
        uint256 currentValue
    ) private {
        uint256 len = snapshots.ids.length;
        if (len == 0 || snapshots.ids[len - 1] < _currentSnapshotId) {
            snapshots.ids.push(_currentSnapshotId);
            snapshots.values.push(currentValue);
        }
    }

    /* ========= Hooks for Child Contract ========= */

    function _snapshotAccount(
        address account,
        uint256 currentBalance
    ) internal {
        _writeSnapshot(_accountSnapshots[account], currentBalance);
    }

    function _snapshotTotalSupply(uint256 currentTotalSupply) internal {
        _writeSnapshot(_totalSupplySnapshots, currentTotalSupply);
    }

    /* ========= View ========= */

    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) public view returns (uint256) {
        return _valueAt(snapshotId, _accountSnapshots[account]);
    }

    function totalSupplyAt(uint256 snapshotId) public view returns (uint256) {
        return _valueAt(snapshotId, _totalSupplySnapshots);
    }

    function _valueAt(
        uint256 snapshotId,
        Snapshots storage snapshots
    ) private view returns (uint256) {
        uint256 len = snapshots.ids.length;
        if (len == 0) return 0;

        for (uint256 i = len; i > 0; i--) {
            if (snapshots.ids[i - 1] <= snapshotId) {
                return snapshots.values[i - 1];
            }
        }
        return 0;
    }
}
