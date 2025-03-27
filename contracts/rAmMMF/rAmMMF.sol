// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBlacklistCheck} from "contracts/Interfaces/BlackList/IBlacklistCheck.sol";
import {IAllowlistCheck} from "contracts/Interfaces/AllowList/IAllowlistCheck.sol";
import {IRWAOracle} from "contracts/Interfaces/rwaOracles/IRWAOracle.sol";

import "hardhat/console.sol";

contract RAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    /**
     * @dev rAmMMF balances are dynamic and are calculated based on the accounts' shares (AmMMF)
     * and the the price of AmMMF. Account shares aren't
     * normalized, so the contract also stores the sum of all shares to calculate
     * each account's token balance which equals to:
     *
     *   shares[account] * AmMMFPrice
     */
    mapping(address => uint256) private shares;

    /// @dev Allowances are nominated in tokens, not token shares.
    mapping(address => mapping(address => uint256)) private allowances;

    // Total shares in existence
    uint256 public totalShares;

    // Address of the AmMMF token
    IERC20 public ammmf;

    // Address of the oracle that provides the `AMMMFPrice`
    IRWAOracle public oracle;

    // Address of the Blacklist
    IBlacklistCheck public blacklist;

    // Address of the Allowlist
    IAllowlistCheck public allowlist;

    // Used to scale up ammmf amount -> shares
    uint256 public constant AMMMF_TO_RAMMMF_SHARES_MULTIPLIER = 10_000;

    // Name of the token
    string internal _name;

    // Symbol of the token
    string internal _symbol;

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    // Error when redeeming shares < `AMMMF_TO_RAMMMF_SHARES_MULTIPLIER`
    error UnwrapTooSmall();

    // Error when setting the oracle address to zero
    error CannotSetToZeroAddress();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(
        address _blacklist,
        address _allowlist,
        address _ammmf,
        address _oracle
    ) public initializer {
        __ERC20_init("rAmMMF", "MTK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("rAmMMF");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        blacklist = IBlacklistCheck(_blacklist);
        allowlist = IAllowlistCheck(_allowlist);
        ammmf = IERC20(_ammmf);
        oracle = IRWAOracle(_oracle);
        _name = "Ondo Short-Term U.S. Government Bond Fund (Rebasing)";
        _symbol = "rAmMMF";
    }

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the name is set
     *
     * @param oldName The old name of the token
     * @param newName The new name of the token
     */
    event NameSet(string oldName, string newName);

    /**
     * @notice Emitted when the symbol is set
     *
     * @param oldSymbol The old symbol of the token
     * @param newSymbol The new symbol of the token
     */

    event SymbolSet(string oldSymbol, string newSymbol);
    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     *
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     */
    event TransferShares(
        address indexed from,
        address indexed to,
        uint256 sharesValue
    );

    /**
     * @notice Emitted when the oracle address is set
     *
     * @param oldOracle The address of the old oracle
     * @param newOracle The address of the new oracle
     */
    event OracleSet(address indexed oldOracle, address indexed newOracle);

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isBlack(
        address account
    ) public view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return blacklist.hasBlack(_msgSender(), account);
    }

    function isAllow(
        address account
    ) public view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return allowlist.hasAllow(_msgSender(), account);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    /**
     * @return the amount of tokens in existence.
     */
    function totalSupply() public view returns (uint256) {
        return
            (totalShares * getOUSGPrice()) /
            (1e18 * AMMMF_TO_RAMMMF_SHARES_MULTIPLIER);
    }

    /**
     * @notice Sets the Oracle address
     * @dev The new oracle must comply with the IRWAOracle interface
     * @param _oracle Address of the new oracle
     */
    function setOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_oracle == address(0)) {
            revert CannotSetToZeroAddress();
        }
        emit OracleSet(address(oracle), _oracle);
        oracle = IRWAOracle(_oracle);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}
