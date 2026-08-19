// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract GovernanceAddressMock {
    function execute(
        address target,
        bytes calldata data
    ) external returns (bytes memory result) {
        (bool success, bytes memory returnData) = target.call(data);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        return returnData;
    }
}
