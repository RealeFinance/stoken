// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TokenConfig is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    struct token {
        string name;
        address addr;
        IERC20 _IERC20;
    }

    mapping(string => token) public nameToToken;

    string[] private _tokenNames;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, initialSupply_);
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyAdmin {}

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
    function setToken(string memory _name, address _addr) public onlyAdmin {
        if (bytes(nameToToken[_name].name).length == 0) {
            _tokenNames.push(_name);
        }
        nameToToken[_name] = token(_name, _addr, IERC20(_addr));
    }

    /**
     * @notice Retrieves the token information for a given token name.
     * @param _name The name of the token.
     * @return The token's name, address, and IERC20 interface.
     */
    function getToken(
        string memory _name
    ) public view returns (string memory, address, IERC20) {
        token memory t = nameToToken[_name];
        return (t.name, t.addr, t._IERC20);
    }

    /**
     * @notice Retrieves the token address for a given token name.
     * @param _name The name of the token.
     * @return The address of the token contract.
     */
    function getTokenAddress(
        string memory _name
    ) public view returns (address) {
        return nameToToken[_name].addr;
    }
}
