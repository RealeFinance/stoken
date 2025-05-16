// SPDX-License-Identifier: BUSL-1.1
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IERC20, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBlacklistCheck} from "contracts/Interfaces/BlackList/IBlacklistCheck.sol";
import {IAllowlistCheck} from "contracts/Interfaces/AllowList/IAllowlistCheck.sol";
import {IBlocklist} from "contracts/Interfaces/BlackList/IBlocklistPac.sol";
import {IAllowlist} from "contracts/Interfaces/AllowList/IAllowlistPac.sol";
import {IRWAOracle} from "contracts/Interfaces/rwaOracles/IRWAOracle.sol";

import "hardhat/console.sol";

contract RAmMMF is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
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
    // mapping(address => mapping(address => uint256)) private allowances;

    // Total shares in existence
    uint256 public totalShares;

    // Address of the AmMMF token
    IERC20 public ammmf;

    // Address of the oracle that provides the `AMMMFPrice`
    IRWAOracle public oracle;

    // Address of the Blacklist
    IBlocklist public blocklist;

    // Address of the Allowlist
    IAllowlist public allowlist;

    // Used to scale up ammmf amount -> shares
    uint256 public constant AMMMF_TO_RAMMMF_SHARES_MULTIPLIER = 10_000;

    // Flag to determine whether to fetch the price from the oracle
    bool public pricefromOracle;

    // Last price update
    uint256 private latestPrice;

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    // Error when redeeming shares < `AMMMF_TO_RAMMMF_SHARES_MULTIPLIER`
    error UnwrapTooSmall();

    // Error when setting the oracle address to zero
    error CannotSetToZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

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

    /**
     * @notice Emitted when the price is updated
     *
     * @param oldPrice The old price of rAmMMF
     * @param latestPrice The new price of rAmMMF
     * @param oldTotalSupply The old total supply of rAmMMF
     * @param latestTotalSupply The new total supply of rAmMMF
     */
    event PriceUpdated(
        uint256 oldPrice,
        uint256 latestPrice,
        uint256 oldTotalSupply,
        uint256 latestTotalSupply
    );

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
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        // __ERC20Permit_init("rAmMMF");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        blocklist = IBlocklist(_blacklist);
        allowlist = IAllowlist(_allowlist);
        ammmf = IERC20(_ammmf);
        oracle = IRWAOracle(address(0));
        pricefromOracle = false;
        latestPrice = 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the blocklist contract address
     * @param _blocklist The address of the new blocklist contract
     */
    function setBlocklist(
        address _blocklist
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_blocklist != address(0), "Blocklist address cannot be zero");
        blocklist = IBlocklist(_blocklist);
    }

    /**
     * @notice Sets the allowlist contract address
     * @param _allowlist The address of the new allowlist contract
     */
    function setAllowlist(
        address _allowlist
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_allowlist != address(0), "Allowlist address cannot be zero");
        allowlist = IAllowlist(_allowlist);
    }

    /**
     * @notice Updates the latest price of rAmMMF tokens.
     * @dev This function allows the admin to manually set the latest price of rAmMMF tokens.
     * @param _latestPrice The new price to be set, represented in 18 decimals.
     */
    function setLatestPrice(
        uint256 _latestPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_latestPrice > 0, "Latest price must be greater than zero");
        uint256 _oldLatestPrice = latestPrice;
        uint256 _oldTotalSupply = totalSupply();
        latestPrice = _latestPrice;
        emit PriceUpdated(
            _oldLatestPrice,
            _latestPrice,
            _oldTotalSupply,
            totalSupply()
        );
    }

    /**
     * @notice Sets the flag to determine whether to fetch the price from the oracle
     * @param _pricefromOracle The new value for the flag
     */
    function setGetPriceFromOracle(
        bool _pricefromOracle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pricefromOracle = _pricefromOracle;
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function decimals() public pure override returns (uint8) {
        return 22;
    }

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

    /**
     * @return price price of AmMMF in rAmMMF
     */
    function getAmMMFPrice() public view returns (uint256 price) {
        if (pricefromOracle) {
            (price, ) = oracle.getPriceData();
            return price;
        } else {
            return latestPrice;
        }
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
        oracle = IRWAOracle(_oracle);
        emit OracleSet(address(oracle), _oracle);
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
        _transferShares(_msgSender(), _recipient, _amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 _rAmMMFamount
    ) public override returns (bool) {
        _spendAllowance(from, _msgSender(), _rAmMMFamount);
        _transferShares(from, to, _rAmMMFamount);
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
        require(_AmMMFAmount > 0, "zero AmMMF tokens");
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
        require(_rAmMMFAmount > 0, "zero rAmMMF tokens");
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
        uint256 _rAmMMFAmount
    ) internal whenNotPaused {
        uint256 _sharesToTransfer = getSharesByRAmMMF(_rAmMMFAmount);
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        _beforeTokenTransfer(_sender, _recipient, _sharesToTransfer);
        uint256 currentSenderShares = shares[_sender];
        require(
            _sharesToTransfer <= currentSenderShares,
            "TRANSFER_AMOUNT_EXCEEDS_BALANCE"
        );
        shares[_sender] = currentSenderShares - _sharesToTransfer;
        shares[_recipient] += _sharesToTransfer;
        emit Transfer(msg.sender, _recipient, _rAmMMFAmount);
        emit TransferShares(msg.sender, _recipient, _sharesToTransfer);
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
        if (from != msg.sender && to != msg.sender) {
            require(!blocklist.isBlocked(msg.sender), "'sender' in blacklist");
            require(
                allowlist.isAllowed(msg.sender),
                "'sender' not in allowlist"
            );
        }

        if (from != address(0)) {
            require(!blocklist.isBlocked(from), "'from' in blacklist");
            require(allowlist.isAllowed(from), "'from' not in allowlist");
        }

        if (to != address(0)) {
            require(!blocklist.isBlocked(to), "'to' in blacklist");
            require(allowlist.isAllowed(to), "'to' not in allowlist");
        }
    }
}
