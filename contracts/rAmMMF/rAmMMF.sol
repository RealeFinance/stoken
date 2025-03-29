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

    // function isBlack(
    //     address account
    // ) public view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
    //     return blacklist.hasBlack(_msgSender(), account);
    // }

    // function isAllow(
    //     address account
    // ) public view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
    //     return allowlist.hasAllow(_msgSender(), account);
    // }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // /**
    //  * @return the number of decimals for getting user representation of a token amount.
    //  */
    // function decimals() public pure override returns (uint8) {
    //     return 18;
    // }

    /**
     * @return the amount of tokens in existence.
     */
    function totalSupply() public view override returns (uint256) {
        return
            (totalShares * getAmMMFPrice()) /
            (1e18 * AMMMF_TO_RAMMMF_SHARES_MULTIPLIER);
    }

    /**
     * @return the amount of tokens owned by the `_account`.
     *
     * @dev Balances are dynamic and equal the `_account`'s AmMMF shares multiplied
     *      by the price of AmMMF
     */
    function balanceOf(
        address _account
    ) public view override returns (uint256) {
        return
            (_sharesOf(_account) * getAmMMFPrice()) /
            (1e18 * AMMMF_TO_RAMMMF_SHARES_MULTIPLIER);
    }

    /**
     * @return the amount of shares owned by `_account`.
     *
     * @dev This is the equivalent to the amount of AmMMF wrapped by `_account`.
     */
    function sharesOf(address _account) public view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    /**
     * @return the amount of shares that corresponds to `_rAmMMFAmount` of rAmMMF
     */
    function getSharesByRAmMMF(
        uint256 _rAmMMFAmount
    ) public view returns (uint256) {
        return
            (_rAmMMFAmount * 1e18 * AMMMF_TO_RAMMMF_SHARES_MULTIPLIER) /
            getAmMMFPrice();
    }

    /**
     * @return the amount of rAmMMF that corresponds to `_shares` of AmMMF.
     */
    function getRAmMMFByShares(uint256 _shares) public view returns (uint256) {
        return
            (_shares * getAmMMFPrice()) /
            (1e18 * AMMMF_TO_RAMMMF_SHARES_MULTIPLIER);
    }

    function getAmMMFPrice() public view returns (uint256 price) {
        (price, ) = oracle.getPriceData();
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

    /**
     * @notice Moves `_amount` tokens from the caller's account to the `_recipient` account.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the caller must have a balance of at least `_amount`.
     * - the contract must not be paused.
     *
     * @dev The `_amount` argument is the amount of tokens, not shares.
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        uint256 _sharesToTransfer = getSharesByRAmMMF(_amount);
        _transferShares(msg.sender, _recipient, _sharesToTransfer);
        emit Transfer(msg.sender, _recipient, _amount);
        emit TransferShares(msg.sender, _recipient, _sharesToTransfer);
        return true;
    }

    /**
     * @return the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     *
     * @dev This value changes when `approve` or `transferFrom` is called.
     */
    function allowance(
        address _owner,
        address _spender
    ) public view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     * - the contract must not be paused.
     *
     * @dev The `_amount` argument is the amount of tokens, not shares.
     */
    function approve(
        address _spender,
        uint256 _amount
    ) public override returns (bool) {

        _approverAmMMF(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient` using the
     * allowance mechanism. `_amount` is then deducted from the caller's
     * allowance.
     *
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have a balance of at least `_amount`.
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     * - the contract must not be paused.
     *
     * @dev The `_amount` argument is the amount of tokens, not shares.
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(
            currentAllowance >= _amount,
            "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE"
        );
        uint256 _sharesToTransfer = getSharesByRAmMMF(_amount);
        _transferShares(_sender, _recipient, _amount);
        emit Transfer(_sender, _recipient, _amount);
        emit TransferShares(_sender, _recipient, _sharesToTransfer);
        _approverAmMMF(_sender, msg.sender, currentAllowance - _amount);
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol#L42
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_spender` cannot be the the zero address.
     * - the contract must not be paused.
     */
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) public returns (bool) {
        _approverAmMMF(
            msg.sender,
            _spender,
            allowances[msg.sender][_spender] + _addedValue
        );
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol#L42
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     * - `_spender` must have allowance for the caller of at least `_subtractedValue`.
     * - the contract must not be paused.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) public returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(
            currentAllowance >= _subtractedValue,
            "DECREASED_ALLOWANCE_BELOW_ZERO"
        );
        _approverAmMMF(msg.sender, _spender, currentAllowance - _subtractedValue);
        return true;
    }

    /**
     * @notice Function called by users to wrap their AmMMF tokens
     *
     * @param _AmMMFAmount The amount of AmMMF Tokens to wrap
     *
     * @dev KYC checks implicit in AmMMF Transfer
     */
    function wrap(uint256 _AmMMFAmount) external whenNotPaused {
        require(_AmMMFAmount > 0, "rAmMMF: can't wrap zero AmMMF tokens");
        uint256 AmMMFSharesAmount = _AmMMFAmount *
            AMMMF_TO_RAMMMF_SHARES_MULTIPLIER;
        _mintShares(msg.sender, AmMMFSharesAmount);
        ammmf.transferFrom(msg.sender, address(this), _AmMMFAmount);
        emit Transfer(
            address(0),
            msg.sender,
            getRAmMMFByShares(AmMMFSharesAmount)
        );
        emit TransferShares(address(0), msg.sender, AmMMFSharesAmount);
    }

    /**
     * @notice Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the contract must not be paused.
     */
    function _mintShares(address _recipient, uint256 _sharesAmount) internal {
        require(_recipient != address(0), "MINT_TO_THE_ZERO_ADDRESS");
        _beforeTokenTransfer(address(0), _recipient, _sharesAmount);
        totalShares += _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    /**
     * @notice Function called by users to unwrap their rAmMMF tokens by rAmMMF amount
     *
     * @param _rAmMMFAmount The amount of rAmMMF to unwrap
     *
     * @dev KYC checks implicit in AmMMF Transfer
     */
    function unwrap(uint256 _rAmMMFAmount) external whenNotPaused {
        require(_rAmMMFAmount > 0, "rAmMMF: can't unwrap zero rAmMMF tokens");
        uint256 AmMMFSharesAmount = getSharesByRAmMMF(_rAmMMFAmount);
        if (AmMMFSharesAmount < AMMMF_TO_RAMMMF_SHARES_MULTIPLIER)
            revert UnwrapTooSmall();
        _burnShares(msg.sender, AmMMFSharesAmount);
        ammmf.transfer(
            msg.sender,
            AmMMFSharesAmount / AMMMF_TO_RAMMMF_SHARES_MULTIPLIER
        );
        emit Transfer(msg.sender, address(0), _rAmMMFAmount);
        emit TransferShares(msg.sender, address(0), AmMMFSharesAmount);
    }

    /**
     * @notice Function called by users to unwrap their rAmMMF tokens by shares
     *
     * @param _sharesAmount The amount of shares to transfer
     *
     * @dev KYC checks implicit in AmMMF Transfer
     * @dev This is a more precise unwrap, as it avoids the division by price when converting rAmMMF to shares
     */
    function unwrapShares(uint256 _sharesAmount) external whenNotPaused {
        if (_sharesAmount < AMMMF_TO_RAMMMF_SHARES_MULTIPLIER)
            revert UnwrapTooSmall();
        uint256 rAmMMFAmount = getRAmMMFByShares(_sharesAmount);
        _burnShares(msg.sender, _sharesAmount);
        ammmf.transfer(
            msg.sender,
            _sharesAmount / AMMMF_TO_RAMMMF_SHARES_MULTIPLIER
        );
        emit Transfer(msg.sender, address(0), rAmMMFAmount);
        emit TransferShares(msg.sender, address(0), _sharesAmount);
    }

    /**
     * @notice Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.
     * @dev This doesn't decrease the token total supply.
     *
     * Requirements:
     *
     * - `_account` cannot be the zero address.
     * - `_account` must hold at least `_sharesAmount` shares.
     * - the contract must not be paused.
     */
    function _burnShares(address _account, uint256 _sharesAmount) internal {
        require(_account != address(0), "BURN_FROM_THE_ZERO_ADDRESS");
        _beforeTokenTransfer(_account, address(0), _sharesAmount);
        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "BURN_AMOUNT_EXCEEDS_BALANCE");
        totalShares -= _sharesAmount;
        shares[_account] = accountShares - _sharesAmount;
    }

    // /**
    //  * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
    //  * Emits a `Transfer` event.
    //  * Emits a `TransferShares` event.
    //  */
    // function _transfer(
    //     address _sender,
    //     address _recipient,
    //     uint256 _amount
    // ) internal override {
    //     uint256 _sharesToTransfer = getSharesByRAmMMF(_amount);
    //     _transferShares(_sender, _recipient, _sharesToTransfer);
    //     emit Transfer(_sender, _recipient, _amount);
    //     emit TransferShares(_sender, _recipient, _sharesToTransfer);
    // }

    /**
     * @notice Moves `_sharesAmount` shares from `_sender` to `_recipient`.
     *
     * Requirements:
     *
     * - `_sender` cannot be the zero address.
     * - `_recipient` cannot be the zero address.
     * - `_sender` must hold at least `_sharesAmount` shares.
     * - the contract must not be paused.
     */
    function _transferShares(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) internal whenNotPaused {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        _beforeTokenTransfer(_sender, _recipient, _sharesAmount);
        uint256 currentSenderShares = shares[_sender];
        require(
            _sharesAmount <= currentSenderShares,
            "TRANSFER_AMOUNT_EXCEEDS_BALANCE"
        );
        shares[_sender] = currentSenderShares - _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `_owner` cannot be the zero address.
     * - `_spender` cannot be the zero address.
     * - the contract must not be paused.
     */
    function _approverAmMMF(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal whenNotPaused {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal view {
        // Check constraints when `transferFrom` is called to facliitate
        // a transfer between two parties that are not `from` or `to`.
        if (from != msg.sender && to != msg.sender) {
            // require(
            //     _getKYCStatus(msg.sender),
            //     "rAmMMF: 'sender' address not KYC'd"
            // );
        }

        if (from != address(0)) {
            // If not minting
            // require(_getKYCStatus(from), "rAmMMF: 'from' address not KYC'd");
            require(
                !blacklist.hasBlack(_msgSender(), from),
                "rAmMMF: 'from' address in blacklist"
            );
            require(
                allowlist.hasAllow(_msgSender(), from),
                "rAmMMF: 'from' address not in allowlist"
            );
        }

        if (to != address(0)) {
            // If not burning
            // require(_getKYCStatus(to), "rAmMMF: 'to' address not KYC'd");
            require(
                !blacklist.hasBlack(_msgSender(), to),
                "rAmMMF: 'to' address in blacklist"
            );
            require(
                allowlist.hasAllow(_msgSender(), to),
                "rAmMMF: 'to' address not in allowlist"
            );
        }
    }
}
