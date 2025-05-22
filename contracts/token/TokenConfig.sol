// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/Interfaces/ITokenConfig.sol";

contract TokenConfig is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ITokenConfig
{
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20Upgradeable;

    struct token {
        string name;
        address addr;
    }

    // Mapping from token name to token struct
    mapping(string => token) public nameToToken;

    // Array to store all token names
    string[] private _tokenNames;

    // Event emitted when a token is added
    event TokenAdded(string name, address addr);

    // Event emitted when a token is deleted
    event TokenDeleted(string name);

    function initialize(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Retrieves all valid tokens stored in the contract.
     * @dev Iterates through the list of token names, counts the valid tokens,
     *      and returns an array containing all tokens with a non-empty name.
     * @return tokens An array of all valid `token` structs.
     */
    function getAllTokens() public view returns (token[] memory) {
        uint256 count = 0;
        // First, count the number of tokens
        for (uint256 i = 0; i < _tokenNames.length; i++) {
            if (bytes(nameToToken[_tokenNames[i]].name).length != 0) {
                count++;
            }
        }
        token[] memory tokens = new token[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < _tokenNames.length; i++) {
            if (bytes(nameToToken[_tokenNames[i]].name).length != 0) {
                tokens[idx] = nameToToken[_tokenNames[i]];
                idx++;
            }
        }
        return tokens;
    }

    /**
     * @notice Sets the token address for a given token name.
     * @param _name The name of the token.
     * @param _addr The address of the token contract.
     */
    function setToken(
        string memory _name,
        address _addr
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(_name).length != 0, "Token name is empty");
        require(
            bytes(nameToToken[_name].name).length == 0,
            "Token name already exists"
        );
        _tokenNames.push(_name);
        nameToToken[_name] = token(_name, _addr);
        emit TokenAdded(_name, _addr);
    }

    /**
     * @notice Deletes a token by its name.
     * @param _name The name of the token to delete.
     */
    function deleteToken(
        string memory _name
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(_name).length != 0, "Token name is empty");
        require(
            bytes(nameToToken[_name].name).length != 0,
            "Token does not exist"
        );

        // Remove from mapping
        delete nameToToken[_name];

        // Remove from _tokenNames array
        for (uint256 i = 0; i < _tokenNames.length; i++) {
            if (keccak256(bytes(_tokenNames[i])) == keccak256(bytes(_name))) {
                _tokenNames[i] = _tokenNames[_tokenNames.length - 1];
                _tokenNames.pop();
                break;
            }
        }
        emit TokenDeleted(_name);
    }

    /**
     * @notice Retrieves the token information for a given token name.
     * @param _name The name of the token.
     * @return The token's name and address.
     */
    function getToken(
        string memory _name
    ) external view returns (string memory, address) {
        require(bytes(_name).length != 0, "Token name is empty");
        require(
            bytes(nameToToken[_name].name).length != 0,
            "Token does not exist"
        );
        token memory t = nameToToken[_name];
        return (t.name, t.addr);
    }

    /**
     * @notice Retrieves the token address for a given token name.
     * @param _name The name of the token.
     * @return The address of the token contract.
     */
    function getTokenAddress(
        string memory _name
    ) external view returns (address) {
        require(bytes(_name).length != 0, "Token name is empty");
        require(
            bytes(nameToToken[_name].name).length != 0,
            "Token does not exist"
        );
        return nameToToken[_name].addr;
    }
}
