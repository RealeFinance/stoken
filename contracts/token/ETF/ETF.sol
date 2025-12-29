// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// # Copyright (c) 2025 Asseto Fintech Limited. All rights reserved.
pragma solidity ^0.8.22;

// 导入OpenZeppelin核心库
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    AccessControlEnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {
    IERC20,
    ERC20Upgradeable,
    IERC20Metadata
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IETF} from "../../Interfaces/IETF.sol";

/**
 * @title ETFToken
 * @dev 基于ERC20扩展的ETF代币合约，支持USDT兑换、T+2锁定铸造、双维度下单
 * 核心规则：
 * 1. 两种兑换方式：按USDT金额买 / 按ETF数量买（自动换算USDT）；
 * 2. 兑换时锁定USDT，T+2（排除周末）后自动铸造ETF；
 * 3. 支持订单查询、到期铸造、紧急解锁（扣1%手续费）；
 * 4. USDT为ERC20标准代币（如泰达币），ETF代币18位小数，与USDT（6位）自动换算。
 */
contract ETFToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IETF
{
    using SafeERC20 for IERC20;
    // ========== 核心配置 ==========
    IERC20 public USDT; // USDT合约地址（需替换为部署链的真实地址）
    uint256 public etfPrice; // ETF单价（USDT/枚，单位：1e6，即1 USDT = 1e6）
    uint256 public constant PENALTY_RATIO = 100; // 紧急解锁手续费比例（1/100 = 1%）
    uint256 public constant DAY_SECONDS = 86400; // 1天秒数
    uint256 public constant USDT_DECIMALS = 6; // USDT小数位
    uint256 public constant ETF_DECIMALS = 18; // ETF小数位
    // List of supported USDT/USDC address
    address[] public supportedTokenAddress;

    // ========== 订单结构体 ==========
    struct Order {
        uint256 orderId; // 订单ID
        address user; // 下单用户
        uint256 uAmount; // 锁定的USDT数量（1e6单位）
        uint256 etfAmount; // 待铸造的ETF数量（1e18单位）
        uint256 etfPrice; // 下单时的ETF单价
        uint256 lockTime; // 锁定时间（下单时间戳）
        uint256 settleTime; // T+2交割时间（铸造时间）
        uint256 refundUAmount; // 需要退回的USDT数量
        bool isLotType; // 是否按照手数购买
        uint256 lotCount; // 手数 当isLotType为true时有效
        bool isSettled; // 是否已铸造ETF
        bool isCancelled; // 是否已撤销
    }

    // ========== 角色定义 ==========
    bytes32 public constant ETF_ADMIN = keccak256("ETF_ADMIN");

    // ========== 状态变量 ==========
    mapping(uint256 => Order) public orders; // 订单ID => 订单信息
    mapping(address => uint256[]) public userOrders; // 用户 => 订单ID列表
    uint256 public nextOrderId; // 下一个订单ID
    uint256 public lotSize; // 批量大小
    address private assetRecipient; // 资产接收地址

    // ========== 修饰符 ==========
    modifier zeroAddress(address addr) {
        require(addr != address(0), "Zero address");
        _;
    }

    //  ========== 事件定义 ==========
    error UnSupportedTokenAddress(address token, string reason);

    // ========== 构造函数 & 初始化 ==========
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address _usdtAddress
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init(name);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        assetRecipient = address(this);
        USDT = IERC20(_usdtAddress);
        etfPrice = 1e6; // 初始化ETF单价（如1e6 = 1 USDT/ETF）
    }

    // ========== 授权升级 ==========
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ========== 暂停与恢复 ==========
    function pause() public onlyRole(ETF_ADMIN) {
        _pause();
    }

    function unpause() public onlyRole(ETF_ADMIN) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    function decimals() public pure override returns (uint8) {
        return uint8(ETF_DECIMALS);
    }

    // ========== 核心功能：链上认购ETF ==========
    function onChainSubscribe(
        address uAddress,
        uint256 uAmount
    ) external nonReentrant {
        if (!_containsAddress(uAddress)) {
            revert UnSupportedTokenAddress(
                uAddress,
                "Unsupported token address"
            );
        }
        _onChainSubscribe(uAddress, uAmount, 0);
    }

    function onChainSubscribe(
        address uAddress,
        uint256 uAmount,
        uint256 lotCount
    ) external nonReentrant {
        if (!_containsAddress(uAddress)) {
            revert UnSupportedTokenAddress(
                uAddress,
                "Unsupported token address"
            );
        }
        require(lotCount > 0, "Lot count must > 0");
        _onChainSubscribe(uAddress, uAmount, lotCount);
    }

    function _onChainSubscribe(
        address uAddress,
        uint256 uAmount,
        uint256 lotCount
    ) internal {
        uint256 balanceBefore = IERC20(uAddress).balanceOf(assetRecipient);
        IERC20(uAddress).safeTransferFrom(msg.sender, assetRecipient, uAmount);
        uint256 balanceAfter = IERC20(uAddress).balanceOf(assetRecipient);
        uAmount = balanceAfter - balanceBefore;

        nextOrderId++;
        uint256 lockTime = block.timestamp;
        uint256 settleTime = calculateT2SettleTime(lockTime);
        uint256 orderId = uint256(
            keccak256(
                abi.encodePacked(
                    uAddress,
                    uAmount,
                    msg.sender,
                    lockTime,
                    block.prevrandao,
                    nextOrderId
                )
            )
        );

        Order storage order = orders[orderId];
        order.orderId = orderId;
        order.user = msg.sender;
        order.uAmount = uAmount;
        order.lockTime = lockTime;
        order.settleTime = settleTime;
        if (lotCount > 0) {
            order.isLotType = true;
            order.lotCount = lotCount;
        } else {
            order.isLotType = false;
            order.lotCount = 0;
        }
        userOrders[msg.sender].push(orderId);

        emit OrderCreated(
            orderId,
            msg.sender,
            uAddress,
            uAmount,
            lockTime,
            settleTime,
            order.isLotType
        );
    }

    function updateSubscribe(uint256 orderId) external onlyRole(ETF_ADMIN) {}

    function execute(uint256 orderId) external onlyRole(ETF_ADMIN) {}

    function claim(uint256 orderId) external nonReentrant {}

    // ========== 辅助函数：计算ETF数量 ==========
    function _getEtfAmount(uint256 uAmount) internal view returns (uint256) {
        return
            ((uAmount * (10 ** ETF_DECIMALS)) /
                (etfPrice * (10 ** (ETF_DECIMALS - USDT_DECIMALS))) /
                lotSize) * lotSize;
    }

    // ========== 辅助函数：计算T+2交割时间（排除周末） ==========
    /**
     * @dev 计算T+2交割时间（仅工作日，排除周六/周日）
     * @param lockTime 下单时间戳
     * @return settleTime T+2交割时间戳
     */
    function calculateT2SettleTime(
        uint256 lockTime
    ) public pure returns (uint256) {
        uint256 settleTime = lockTime;
        uint256 workDayCount = 0;

        while (workDayCount < 2) {
            settleTime += DAY_SECONDS;
            uint256 weekday = getWeekday(settleTime);
            // 排除周日(0)、周六(6)
            if (weekday != 0 && weekday != 6) {
                workDayCount++;
            }
        }

        return settleTime;
    }

    // ========== 辅助函数：获取时间戳对应的星期几 ==========
    /**
     * @dev 获取星期几（0=周日，1=周一...6=周六）
     * @param timestamp 时间戳
     * @return weekday 星期几
     */
    function getWeekday(uint256 timestamp) public pure returns (uint256) {
        uint256 daysSinceEpoch = timestamp / DAY_SECONDS;
        return (daysSinceEpoch + 4) % 7; // 1970-01-01是周四(4)
    }

    // ========== 管理员功能 ==========
    /**
     * @dev 更新ETF单价（仅管理员，适配价格波动）
     * @param _newPrice 新单价（USDT/ETF，1e6单位）
     */
    function updateETFPrice(uint256 _newPrice) external onlyRole(ETF_ADMIN) {
        require(_newPrice > 0, "Price must > 0");
        etfPrice = _newPrice;
    }

    /**
     * @dev 提取合约中多余的USDT（仅应急，如手续费）
     * @param amount USDT数量（1e6单位）
     */
    function emergencyWithdrawUSDT(
        uint256 amount
    ) external onlyRole(ETF_ADMIN) {
        require(amount > 0, "Amount must > 0");
        USDT.transfer(assetRecipient, amount);
    }

    // ========== 视图函数：查询用户订单列表 ==========
    /**
     * @dev 查询用户的所有订单ID
     * @param user 用户地址
     * @return 订单ID数组
     */
    function getUserOrderIds(
        address user
    ) external view returns (uint256[] memory) {
        return userOrders[user];
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

    /**
     * @dev Set the lot size for ETF transactions.
     * @param _lotSize The new lot size.
     */
    function setLotSize(uint256 _lotSize) external onlyRole(ETF_ADMIN) {
        uint256 _oldLotSize = lotSize;
        lotSize = _lotSize;
        emit lotSizeUpdated(_oldLotSize, _lotSize);
    }

    // ========== 支持的USDT/USDC地址管理 ==========
    function getSupportedTokenAddresses()
        external
        view
        returns (address[] memory)
    {
        return supportedTokenAddress;
    }

    function addSupportedTokenAddress(
        address token
    ) public virtual zeroAddress(token) onlyRole(ETF_ADMIN) {
        supportedTokenAddress.push(token);
        emit supportedTokenAddressAddedEvent(token);
    }

    function removeSupportedTokenAddress(
        address token
    ) public virtual zeroAddress(token) onlyRole(ETF_ADMIN) {
        for (uint256 i = 0; i < supportedTokenAddress.length; i++) {
            if (supportedTokenAddress[i] == token) {
                supportedTokenAddress[i] = supportedTokenAddress[
                    supportedTokenAddress.length - 1
                ];
                supportedTokenAddress.pop();
                emit supportedTokenAddressRemovedEvent(token);
                return;
            }
        }
        revert("Address not found");
    }

    function _containsAddress(address addr) internal view returns (bool) {
        for (uint i = 0; i < supportedTokenAddress.length; i++) {
            if (supportedTokenAddress[i] == addr) {
                return true;
            }
        }
        return false;
    }
}
