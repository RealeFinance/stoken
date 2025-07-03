// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant STOKEN_ADMIN = keccak256("STOKEN_ADMIN");

    // TokenData structure to hold token ID and amount
    struct TokenData {
        uint256 tokenId; // Token ID
        uint256 tokenMintTime; // Token minting time
        address tokenOwner; // Token owner address
    }

    // tokenId => TokenData
    mapping(uint256 => TokenData) private _tokenDataMap;

    // Address → List of owned token IDs
    mapping(address => uint256[]) private _tokenList;

    // Address → Token ID → Token amount
    mapping(address => mapping(uint256 => uint256)) private _tokenMap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init(name);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    function mint(address to, uint256 amount) public onlyRole(STOKEN_ADMIN) {
        require(to != address(0), "Cannot mint to the zero address");
        require(amount > 0, "Amount must be greater than zero");

        uint256 tokenId = _addNewTokenData(to);
        _tokenList[to].push(tokenId);
        _tokenMap[to][tokenId] += amount;
        _mint(to, amount);
    }

    // Burn tokens from the sender's address
    // This function allows the sender to burn a specified amount of their tokens
    // It checks if the sender has enough balance and then removes the tokens
    // from their balance and burns them
    function burn(uint256 amount) public onlyRole(STOKEN_ADMIN) {
        require(amount > 0, "Amount must be greater than zero");
        require(
            balanceOf(msg.sender) >= amount,
            "Insufficient balance to burn"
        );
        _removeTokenByIdList(msg.sender, amount);
        _burn(msg.sender, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 totalBalance = 0;
        uint256[] storage tokenIds = _tokenList[account];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            totalBalance += _tokenMap[account][tokenIds[i]];
        }
        return totalBalance;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        _addTokenByIdList(to, amount);
        _removeTokenByIdList(from, amount);
    }

    function _addNewTokenData(address to) internal returns (uint256) {
        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(to, block.timestamp, block.prevrandao))
        );
        TokenData memory newTokenData = TokenData({
            tokenId: tokenId,
            tokenMintTime: block.timestamp,
            tokenOwner: to
        });
        _tokenDataMap[tokenId] = newTokenData;
        return tokenId;
    }

    // Remove a specified amount of tokens according to the FIFO (First-In-First-Out) rule
    // This function iterates through the token IDs associated with the address
    // and removes tokens until the specified amount is reached.
    function _removeTokenByIdList(address account, uint256 amount) internal {
        // Find the token ID associated with the sender's address
        uint256[] storage tokenIds = _tokenList[account];
        require(tokenIds.length > 0, "No tokens to burn");
        uint256 remaining = amount;
        uint256 i = 0;
        while (remaining > 0 && i < tokenIds.length) {
            uint256 tokenId = tokenIds[i];
            uint256 tokenAmount = _tokenMap[account][tokenId];
            if (tokenAmount == 0) {
                continue;
            }
            if (tokenAmount > remaining) {
                _tokenMap[account][tokenId] -= remaining;
                remaining = 0;
            } else {
                remaining -= tokenAmount;
                _tokenMap[account][tokenId] = 0;
                continue;
            }
            i++;
        }
        require(remaining == 0, "Not enough tokens to burn");

        // Clean up empty token IDs
        for (uint256 j = 0; j < tokenIds.length; j++) {
            if (_tokenMap[account][tokenIds[j]] == 0) {
                // Remove empty tokenId from list
                for (uint256 k = j; k < tokenIds.length - 1; k++) {
                    tokenIds[k] = tokenIds[k + 1];
                }
                tokenIds.pop();
                j--; // Adjust index after removal
            }
        }
        // If all tokens are burned, remove the address from the token list
        if (tokenIds.length == 0) {
            delete _tokenList[account];
        }
        _tokenList[account] = tokenIds;
    }

    function _addTokenByIdList(address account, uint256 amount) internal {
        // TODO 代币添加逻辑 还要涉及到相同 tokenId 的合并情况
        // This function should handle the logic of adding tokens to the list
        // and merging them if necessary.
        // For now, it is left empty as a placeholder.
    }
}
