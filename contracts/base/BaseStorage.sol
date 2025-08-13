// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;
import "../Interfaces/ICashPlus.sol";

contract BaseStorage is ICashPlus {
    // Asset recipient address
    address public assetRecipient;

    // Asset sender address
    address public assetSender;

    // Service fee recipient address
    address public serviceFeeRecipient;

    // Technical Service Fee (%) 10 ==> 0.1%  50 ==> 0.5%  100 ==> 1%
    uint256 public technicalServiceFeeRate;

    // List of supported USDT/USDC address
    address[] public supportedTokenAddress;

    modifier zeroAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    /**
     * @dev Get the current technical service fee rate.
     * @return The current fee rate (in percent).
     */
    function getTechnicalServiceFeeRate() external view returns (uint256) {
        return technicalServiceFeeRate;
    }

    /**
     * @dev Set the technical service fee rate.
     * @param newRate The new fee rate (in percent).
     */
    function setTechnicalServiceFeeRate(uint256 newRate) public virtual {
        uint256 oldRate = technicalServiceFeeRate;
        technicalServiceFeeRate = newRate;
        emit technicalServiceFeeRateUpdatedEvent(oldRate, newRate); // Emit event for technical service fee rate update
    }

    /**
     * @dev Get the current asset recipient address.
     * @return The asset recipient address.
     */
    function getAssetRecipient() external view returns (address) {
        return assetRecipient;
    }

    /**
     * @dev Set the asset recipient address.
     * @param newRecipient The new asset recipient address.
     */
    function setAssetRecipient(
        address newRecipient
    ) public virtual zeroAddress(newRecipient) {
        address oldRecipient = assetRecipient;
        assetRecipient = newRecipient;
        emit assetRecipientUpdatedEvent(oldRecipient, newRecipient); // Emit event for asset recipient update
    }

    function getAssetSender() external view returns (address) {
        return assetSender;
    }

    function setAssetSender(
        address newSender
    ) public virtual zeroAddress(newSender) {
        address oldSender = assetSender;
        assetSender = newSender;
        emit assetSenderUpdatedEvent(oldSender, newSender); // Emit event for asset sender update
    }

    function getServiceFeeRecipient() external view returns (address) {
        return serviceFeeRecipient;
    }

    function setServiceFeeRecipient(
        address newRecipient
    ) public virtual zeroAddress(newRecipient) {
        address oldRecipient = serviceFeeRecipient;
        serviceFeeRecipient = newRecipient;
        emit serviceFeeRecipientUpdatedEvent(oldRecipient, newRecipient); // Emit event for service fee recipient update
    }

    /*//////////////////////////////////////////////////////////////
                        supportedTokenAddress
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the list of supported token addresses.
     */
    function getSupportedTokenAddresses()
        external
        view
        returns (address[] memory)
    {
        return supportedTokenAddress;
    }

    /**
     * @dev Adds a new supported token address.
     * @param token The address to add.
     */
    function addSupportedTokenAddress(
        address token
    ) public virtual zeroAddress(token) {
        supportedTokenAddress.push(token);
        emit supportedTokenAddressAddedEvent(token); // Emit event for adding supported token address
    }

    /**
     * @dev Removes a supported token address.
     * @param token The address to remove.
     */
    function removeSupportedTokenAddress(
        address token
    ) public virtual zeroAddress(token) {
        for (uint256 i = 0; i < supportedTokenAddress.length; i++) {
            if (supportedTokenAddress[i] == token) {
                supportedTokenAddress[i] = supportedTokenAddress[
                    supportedTokenAddress.length - 1
                ];
                supportedTokenAddress.pop();
                return;
            }
        }
        emit supportedTokenAddressRemovedEvent(token); // Emit event for removing supported token address
        revert("Token address not found");
    }

    /**
     * @dev Checks if an address is in the supported token addresses.
     * @param addr The address to check.
     * @return True if the address is supported, false otherwise.
     */
    function containsAddress(address addr) internal view returns (bool) {
        for (uint i = 0; i < supportedTokenAddress.length; i++) {
            if (supportedTokenAddress[i] == addr) {
                return true;
            }
        }
        return false;
    }
}
