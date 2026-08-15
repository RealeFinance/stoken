// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

interface IPlusFundFactoryToken {
    function initialize(string memory name, string memory symbol) external;

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function STOKEN_ADMIN() external view returns (bytes32);

    function POOL_ADMIN_ROLE() external view returns (bytes32);

    function STOKEN_BLACKLIST_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address callerConfirmation) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function setAssetRecipient(address newRecipient) external;

    function setAssetSender(address newSender) external;

    function setServiceFeeRecipient(address newRecipient) external;

    function addSupportedTokenAddress(address token) external;

    function setMinSubscriptionAmount(uint256 amount) external;

    function setMinRedemptionAmount(uint256 amount) external;

    function setMaxQueueLength(uint256 newValue) external;

    function setCCIPAdmin(address newAdmin) external;
}

contract PlusFundFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    uint256 public constant MAX_BATCH_SIZE = 5;

    address public implementation;

    struct TokenConfig {
        bytes32 productId;
        string name;
        string symbol;
        address stokenAdmin;
        address poolAdmin;
        address blacklistAdmin;
        address ccipAdmin;
        address assetRecipient;
        address assetSender;
        address serviceFeeRecipient;
        address[] supportedTokens;
        uint256 minSubscriptionAmount;
        uint256 minRedemptionAmount;
        uint256 maxQueueLength;
        uint256 timelockDelay;
        address[] proposers;
        address[] executors;
        address[] cancellers;
    }

    mapping(bytes32 => address) public tokenByProductId;
    mapping(address => address) public timelockByToken;
    address[] private _tokens;

    event ImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);
    event TokenDeployed(
        bytes32 indexed productId,
        address indexed proxy,
        address indexed timelock,
        address implementation,
        bytes32 salt
    );

    error ZeroAddress();
    error InvalidImplementation();
    error ProductAlreadyExists(bytes32 productId);
    error InvalidProductId();
    error InvalidConfiguration();
    error InvalidBatchSize();

    constructor(address implementation_) {
        _setImplementation(implementation_);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
    }

    function setImplementation(address newImplementation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setImplementation(newImplementation);
    }

    function deployToken(TokenConfig calldata config, bytes32 salt)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address proxy, address timelock)
    {
        return _deployToken(config, salt);
    }

    function batchDeploy(TokenConfig[] calldata configs, bytes32[] calldata salts)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address[] memory proxies, address[] memory timelocks)
    {
        if (configs.length == 0 || configs.length != salts.length || configs.length > MAX_BATCH_SIZE) {
            revert InvalidBatchSize();
        }

        proxies = new address[](configs.length);
        timelocks = new address[](configs.length);
        for (uint256 i = 0; i < configs.length; i++) {
            (proxies[i], timelocks[i]) = _deployToken(configs[i], salts[i]);
        }
    }

    function predictTokenAddress(bytes32 salt, string calldata name, string calldata symbol)
        external
        view
        returns (address predicted)
    {
        bytes memory initData = abi.encodeWithSelector(
            IPlusFundFactoryToken.initialize.selector,
            name,
            symbol
        );
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initData))
        );
        predicted = _computeCreate2Address(salt, initCodeHash);
    }

    function getTokens() external view returns (address[] memory) {
        return _tokens;
    }

    function tokenCount() external view returns (uint256) {
        return _tokens.length;
    }

    function _deployToken(TokenConfig calldata config, bytes32 salt)
        internal
        returns (address proxy, address timelock)
    {
        if (config.productId == bytes32(0)) revert InvalidProductId();
        if (tokenByProductId[config.productId] != address(0)) {
            revert ProductAlreadyExists(config.productId);
        }
        if (
            config.stokenAdmin == address(0) ||
            config.assetRecipient == address(0) ||
            config.assetSender == address(0) ||
            config.serviceFeeRecipient == address(0) ||
            config.proposers.length == 0 ||
            config.executors.length == 0 ||
            config.timelockDelay == 0
        ) {
            revert InvalidConfiguration();
        }

        for (uint256 i = 0; i < config.proposers.length; i++) {
            if (config.proposers[i] == address(0)) revert ZeroAddress();
        }

        bytes memory initData = abi.encodeWithSelector(
            IPlusFundFactoryToken.initialize.selector,
            config.name,
            config.symbol
        );
        proxy = address(new ERC1967Proxy{salt: salt}(implementation, initData));

        TimelockController newTimelock = new TimelockController(
            config.timelockDelay,
            config.proposers,
            config.executors,
            address(this)
        );
        timelock = address(newTimelock);

        IPlusFundFactoryToken token = IPlusFundFactoryToken(proxy);
        bytes32 defaultAdminRole = token.DEFAULT_ADMIN_ROLE();
        bytes32 stokenAdminRole = token.STOKEN_ADMIN();

        token.grantRole(stokenAdminRole, address(this));
        token.setAssetRecipient(config.assetRecipient);
        token.setAssetSender(config.assetSender);
        token.setServiceFeeRecipient(config.serviceFeeRecipient);

        for (uint256 i = 0; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i] == address(0)) revert ZeroAddress();
            token.addSupportedTokenAddress(config.supportedTokens[i]);
        }

        if (config.minSubscriptionAmount > 0) {
            token.setMinSubscriptionAmount(config.minSubscriptionAmount);
        }
        if (config.minRedemptionAmount > 0) {
            token.setMinRedemptionAmount(config.minRedemptionAmount);
        }
        if (config.maxQueueLength > 0) {
            token.setMaxQueueLength(config.maxQueueLength);
        }
        if (config.ccipAdmin != address(0)) {
            token.setCCIPAdmin(config.ccipAdmin);
        }

        token.grantRole(stokenAdminRole, config.stokenAdmin);
        if (config.poolAdmin != address(0)) {
            token.grantRole(token.POOL_ADMIN_ROLE(), config.poolAdmin);
        }
        if (config.blacklistAdmin != address(0)) {
            token.grantRole(token.STOKEN_BLACKLIST_ADMIN_ROLE(), config.blacklistAdmin);
        }

        token.grantRole(defaultAdminRole, timelock);
        if (!newTimelock.hasRole(newTimelock.DEFAULT_ADMIN_ROLE(), timelock)) {
            revert InvalidConfiguration();
        }

        bytes32 cancellerRole = newTimelock.CANCELLER_ROLE();
        for (uint256 i = 0; i < config.cancellers.length; i++) {
            if (config.cancellers[i] == address(0)) revert ZeroAddress();
            newTimelock.grantRole(cancellerRole, config.cancellers[i]);
        }

        newTimelock.renounceRole(newTimelock.DEFAULT_ADMIN_ROLE(), address(this));
        if (newTimelock.hasRole(newTimelock.DEFAULT_ADMIN_ROLE(), address(this))) {
            revert InvalidConfiguration();
        }

        token.renounceRole(stokenAdminRole, address(this));
        token.renounceRole(token.STOKEN_BLACKLIST_ADMIN_ROLE(), address(this));
        token.renounceRole(defaultAdminRole, address(this));

        if (token.hasRole(defaultAdminRole, address(this))) {
            revert InvalidConfiguration();
        }

        tokenByProductId[config.productId] = proxy;
        timelockByToken[proxy] = timelock;
        _tokens.push(proxy);

        emit TokenDeployed(config.productId, proxy, timelock, implementation, salt);
    }

    function _setImplementation(address newImplementation) internal {
        if (newImplementation == address(0) || newImplementation.code.length == 0) {
            revert InvalidImplementation();
        }

        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (
            bytes32 slot
        ) {
            if (slot != IMPLEMENTATION_SLOT) revert InvalidImplementation();
        } catch {
            revert InvalidImplementation();
        }

        address previousImplementation = implementation;
        implementation = newImplementation;
        emit ImplementationUpdated(previousImplementation, newImplementation);
    }

    function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash)
        internal
        view
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            initCodeHash
        )))));
    }
}
