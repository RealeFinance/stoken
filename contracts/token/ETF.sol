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
    ReentrancyGuardUpgradeable
{
    // ========== 核心配置 ==========
    IERC20 public USDT; // USDT合约地址（需替换为部署链的真实地址）
    uint256 public etfPrice; // ETF单价（USDT/枚，单位：1e6，即1 USDT = 1e6）
    uint256 public constant PENALTY_RATIO = 100; // 紧急解锁手续费比例（1/100 = 1%）
    uint256 public constant DAY_SECONDS = 86400; // 1天秒数
    uint256 public constant USDT_DECIMALS = 6; // USDT小数位
    uint256 public constant ETF_DECIMALS = 18; // ETF小数位
    address public assetRecipient; // 资产接收地址

    // ========== 订单结构体 ==========
    struct ExchangeOrder {
        uint256 orderId; // 订单ID
        address user; // 下单用户
        uint256 usdtAmount; // 锁定的USDT数量（1e6单位）
        uint256 etfAmount; // 待铸造的ETF数量（1e18单位）
        uint256 lockTime; // 锁定时间（下单时间戳）
        uint256 settleTime; // T+2交割时间（铸造时间）
        bool isSettled; // 是否已铸造ETF
        bool isCancelled; // 是否已撤销
    }

    // ========== 角色定义 ==========
    bytes32 public constant ETF_ADMIN = keccak256("ETF_ADMIN");

    // ========== 状态变量 ==========
    mapping(uint256 => ExchangeOrder) public orders; // 订单ID => 订单信息
    mapping(address => uint256[]) public userOrders; // 用户 => 订单ID列表
    uint256 public nextOrderId; // 下一个订单ID

    // ========== 事件 ==========
    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        uint256 usdtAmount,
        uint256 etfAmount,
        uint256 settleTime
    );
    event ETFSettled(
        uint256 indexed orderId,
        address indexed user,
        uint256 etfAmount
    );
    event OrderCancelled(
        uint256 indexed orderId,
        address indexed user,
        uint256 penalty,
        uint256 refundUsdt
    );
    event assetRecipientUpdatedEvent(
        address indexed oldRecipient,
        address indexed newRecipient
    );

    // ========== 修饰符 ==========
    modifier zeroAddress(address addr) {
        require(addr != address(0), "Zero address");
        _;
    }

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

    // ========== 核心功能1：按USDT金额购买ETF ==========
    /**
     * @dev 按USDT金额下单，锁定USDT，T+2后铸造对应ETF
     * @param usdtAmount USDT金额（1e6单位，如100 USDT = 100 * 1e6）
     */
    function buyByUSDTAmount(uint256 usdtAmount) external nonReentrant {
        require(usdtAmount > 0, "USDT amount must > 0");
        require(etfPrice > 0, "ETF price not set");

        // 1. 计算可兑换的ETF数量：ETF数量 = USDT金额 / ETF单价（向下取整）
        // 单位换算：USDT(1e6) → ETF(1e18)，需统一精度
        uint256 etfAmount = (usdtAmount * (10 ** ETF_DECIMALS)) /
            (etfPrice * (10 ** (ETF_DECIMALS - USDT_DECIMALS)));
        require(etfAmount > 0, "USDT amount too small to buy 1 ETF");

        // 2. 转移并锁定用户USDT（需用户提前approve合约）
        bool transferSuccess = USDT.transferFrom(
            msg.sender,
            address(this),
            usdtAmount
        );
        require(transferSuccess, "USDT transfer failed");

        // 3. 计算T+2交割时间（排除周末）
        uint256 settleTime = calculateT2SettleTime(block.timestamp);

        // 4. 创建订单
        uint256 orderId = nextOrderId++;
        orders[orderId] = ExchangeOrder({
            orderId: orderId,
            user: msg.sender,
            usdtAmount: usdtAmount,
            etfAmount: etfAmount,
            lockTime: block.timestamp,
            settleTime: settleTime,
            isSettled: false,
            isCancelled: false
        });
        userOrders[msg.sender].push(orderId);

        emit OrderCreated(
            orderId,
            msg.sender,
            usdtAmount,
            etfAmount,
            settleTime
        );
    }

    // ========== 核心功能2：按ETF数量购买 ==========
    /**
     * @dev 按ETF数量下单，锁定对应USDT，T+2后铸造ETF
     * @param etfAmount ETF数量（1e18单位，如100 ETF = 100 * 1e18）
     */
    function buyByETFAmount(uint256 etfAmount) external nonReentrant {
        require(etfAmount > 0, "ETF amount must > 0");
        require(etfPrice > 0, "ETF price not set");

        // 1. 计算需锁定的USDT金额：USDT金额 = ETF数量 * ETF单价
        // 单位换算：ETF(1e18) → USDT(1e6)
        uint256 usdtAmount = (etfAmount * etfPrice) /
            (10 ** (ETF_DECIMALS - USDT_DECIMALS));
        require(usdtAmount > 0, "ETF amount too small");

        // 2. 转移并锁定用户USDT
        bool transferSuccess = USDT.transferFrom(
            msg.sender,
            address(this),
            usdtAmount
        );
        require(transferSuccess, "USDT transfer failed");

        // 3. 计算T+2交割时间
        uint256 settleTime = calculateT2SettleTime(block.timestamp);

        // 4. 创建订单
        uint256 orderId = nextOrderId++;
        orders[orderId] = ExchangeOrder({
            orderId: orderId,
            user: msg.sender,
            usdtAmount: usdtAmount,
            etfAmount: etfAmount,
            lockTime: block.timestamp,
            settleTime: settleTime,
            isSettled: false,
            isCancelled: false
        });
        userOrders[msg.sender].push(orderId);

        emit OrderCreated(
            orderId,
            msg.sender,
            usdtAmount,
            etfAmount,
            settleTime
        );
    }

    // ========== 核心功能3：T+2到期铸造ETF ==========
    /**
     * @dev 订单到期后铸造ETF（用户主动触发，也可结合Chainlink Keepers实现自动铸造）
     * @param orderId 订单ID
     */
    function settleOrder(uint256 orderId) external nonReentrant {
        ExchangeOrder storage order = orders[orderId];
        require(order.user == msg.sender, "Not order owner");
        require(!order.isSettled, "Order already settled");
        require(!order.isCancelled, "Order cancelled");
        require(block.timestamp >= order.settleTime, "T+2 not expired");

        // 1. 更新订单状态
        order.isSettled = true;
        // 2. 铸造ETF代币给用户
        _mint(msg.sender, order.etfAmount);

        emit ETFSettled(orderId, msg.sender, order.etfAmount);
    }

    // ========== 核心功能4：紧急撤销订单（提前解锁USDT，扣手续费） ==========
    /**
     * @dev 交割前撤销订单，扣1%手续费后退回USDT
     * @param orderId 订单ID
     */
    function cancelOrder(uint256 orderId) external nonReentrant {
        ExchangeOrder storage order = orders[orderId];
        require(order.user == msg.sender, "Not order owner");
        require(!order.isSettled, "Order already settled");
        require(!order.isCancelled, "Order already cancelled");
        require(block.timestamp < order.settleTime, "T+2 already expired");

        // 1. 计算手续费和退款金额
        uint256 penalty = order.usdtAmount / PENALTY_RATIO; // 1%手续费
        uint256 refundUsdt = order.usdtAmount - penalty;

        // 2. 更新订单状态
        order.isCancelled = true;
        // 3. 退回USDT（扣除手续费）
        bool refundSuccess = USDT.transfer(msg.sender, refundUsdt);
        require(refundSuccess, "USDT refund failed");
        // 4. 手续费划转至管理员（可选：销毁/分红）
        if (penalty > 0) {
            USDT.transfer(assetRecipient, penalty);
        }

        emit OrderCancelled(orderId, msg.sender, penalty, refundUsdt);
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
     * @dev 查询订单详情
     * @param orderId 订单ID
     * @return user 下单用户
     * @return usdtAmount 锁定USDT数量
     * @return etfAmount 待铸造ETF数量
     * @return settleTime 交割时间
     * @return isSettled 是否已铸造
     */
    function getOrderDetail(
        uint256 orderId
    )
        external
        view
        returns (
            address user,
            uint256 usdtAmount,
            uint256 etfAmount,
            uint256 settleTime,
            bool isSettled
        )
    {
        ExchangeOrder storage order = orders[orderId];
        return (
            order.user,
            order.usdtAmount,
            order.etfAmount,
            order.settleTime,
            order.isSettled
        );
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
}
