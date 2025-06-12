// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRWAOracle} from "contracts/Interfaces/rwaOracles/IRWAOracle.sol";
import "contracts/Interfaces/ICollateralConfig.sol";

contract CollateralConfig is
    Initializable,
    ERC20Upgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    ICollateralConfig
{
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20Upgradeable;

    bytes32 public constant REUSD_ADMIN = keccak256("REUSD_ADMIN");

    enum CollateralType {
        ERC20,
        MTOKEN, // Native isMtoken
        OTHER
    }

    struct Collateral {
        string name;
        address addr;
        uint ratio; // Ratio of the Collateral, e.g., 100 for 1:1 ratio; 125 for 125(Collateral):100(reUSD); 90 for 90(Collateral):100(reUSD)
        CollateralType collateralType; // Type of the Collateral (e.g., NATIVE, ERC20, etc.)
        bool isEnabled; // Whether the Collateral is enabled
    }

    // Mapping from Collateral address to Collateral struct
    mapping(address => Collateral) public addrToCollateral;

    // Array to store all Collateral addresses
    address[] private _CollateralAddrs;

    // Address of the oracle
    IRWAOracle public oracle;

    event CollateralAdded(
        string name,
        address addr,
        uint ratio,
        bool isMCollateral,
        bool isEnabled
    );
    event CollateralDeleted(address addr);
    event OracleChanged(address oldOracle, address newOracle);

    function initialize(
        string memory name_,
        string memory symbol_,
        address oracleAddr
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        require(oracleAddr != address(0), "Oracle address is zero");
        oracle = IRWAOracle(oracleAddr);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REUSD_ADMIN, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                            External Functions  
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a new oracle address.
     * @param newOracle The address of the new oracle.
     */
    function setOracle(address newOracle) external onlyRole(REUSD_ADMIN) {
        require(newOracle != address(0), "Oracle address is zero");
        address oldOracle = address(oracle);
        oracle = IRWAOracle(newOracle);
        emit OracleChanged(oldOracle, newOracle);
    }

    /**
     * @notice Gets the list of all Collateral addresses.
     * @return An array of addresses of all Collaterals.
     */
    function getAllCollaterals() external view returns (Collateral[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _CollateralAddrs.length; i++) {
            if (addrToCollateral[_CollateralAddrs[i]].addr != address(0)) {
                count++;
            }
        }
        Collateral[] memory Collaterals = new Collateral[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < _CollateralAddrs.length; i++) {
            if (addrToCollateral[_CollateralAddrs[i]].addr != address(0)) {
                Collaterals[idx] = addrToCollateral[_CollateralAddrs[i]];
                idx++;
            }
        }
        return Collaterals;
    }

    /**
     * @notice Adds a new Collateral.
     * @param _name The name of the Collateral.
     * @param _addr The address of the Collateral.
     * @param _ratio The ratio of the Collateral (e.g., 100 for 1:1 ratio).
     * @param _collateralType The type of the Collateral (enum CollateralType).
     * @param _isEnabled Whether the Collateral is enabled.
     */
    function setCollateral(
        string memory _name,
        address _addr,
        uint _ratio,
        CollateralType _collateralType,
        bool _isEnabled
    ) external onlyRole(REUSD_ADMIN) {
        require(bytes(_name).length != 0, "Collateral name is empty");
        require(_addr != address(0), "Collateral address is zero");
        require(
            addrToCollateral[_addr].addr == address(0),
            "Collateral address already exists"
        );
        _CollateralAddrs.push(_addr);
        addrToCollateral[_addr] = Collateral(
            _name,
            _addr,
            _ratio,
            _collateralType,
            _isEnabled
        );
        emit CollateralAdded(
            _name,
            _addr,
            _ratio,
            _collateralType == CollateralType.ERC20,
            _isEnabled
        );
    }

    /**
     * @notice Deletes a Collateral.
     * @param _addr The address of the Collateral to delete.
     */
    function deleteCollateral(address _addr) external onlyRole(REUSD_ADMIN) {
        require(_addr != address(0), "Collateral address is zero");
        require(
            addrToCollateral[_addr].addr != address(0),
            "Collateral does not exist"
        );

        // Remove from mapping
        delete addrToCollateral[_addr];

        // Remove from _CollateralAddrs array
        for (uint256 i = 0; i < _CollateralAddrs.length; i++) {
            if (_CollateralAddrs[i] == _addr) {
                _CollateralAddrs[i] = _CollateralAddrs[
                    _CollateralAddrs.length - 1
                ];
                _CollateralAddrs.pop();
                break;
            }
        }
        emit CollateralDeleted(_addr);
    }

    /**
     * @notice Gets the details of a Collateral.
     * @param _addr The address of the Collateral.
     * @return The name, address, ratio, whether it is an mToken, and whether it is enabled.
     */
    function getCollateral(
        address _addr
    ) external view returns (string memory, address, uint, bool, bool) {
        require(_addr != address(0), "Collateral address is zero");
        require(isSupportedCollateral(_addr), "Collateral is not supported");
        Collateral memory t = addrToCollateral[_addr];
        return (
            t.name,
            t.addr,
            t.ratio,
            t.collateralType == CollateralType.ERC20,
            t.isEnabled
        );
    }

    /**
     * @notice Gets the reUSD amount for a given collateral amount.
     * @param _addr The address of the Collateral.
     * @param amount The amount of the Collateral.
     * @return The equivalent reUSD amount.
     */
    function getReUSDAmount(
        address _addr,
        uint256 amount
    ) external view returns (uint256) {
        require(amount > 0, "Amount must be greater than zero");
        require(isSupportedCollateral(_addr), "Collateral is not supported");
        return
            (amount * getCollateralPrice(_addr) * 100) /
            (addrToCollateral[_addr].ratio * 1e18);
    }

    /**
     * @notice Gets the amount of collateral needed for a given reUSD amount.
     * @param _addr The address of the Collateral.
     * @param reUSDAmount The amount of reUSD to convert.
     * @return The amount of collateral needed.
     */
    function getAmountByReUSD(
        address _addr,
        uint256 reUSDAmount
    ) external view returns (uint256) {
        require(reUSDAmount > 0, "Amount must be greater than zero");
        require(isSupportedCollateral(_addr), "Collateral is not supported");
        return
            (reUSDAmount * addrToCollateral[_addr].ratio * 1e18) /
            (getCollateralPrice(_addr) * 100);
    }

    /**
     * @notice Sets whether a Collateral is enabled or disabled.
     * @param _addr The address of the Collateral.
     * @param _isEnabled Whether the Collateral is enabled.
     */
    function setCollateralEnabled(
        address _addr,
        bool _isEnabled
    ) external onlyRole(REUSD_ADMIN) {
        require(_addr != address(0), "Collateral address is zero");
        require(
            addrToCollateral[_addr].addr != address(0),
            "Collateral does not exist"
        );
        addrToCollateral[_addr].isEnabled = _isEnabled;
    }

    /*//////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the price of a Collateral from the oracle.
     * @param _addr The address of the Collateral.
     * @return The price of the Collateral.
     */
    function getCollateralPrice(address _addr) internal view returns (uint256) {
        // (uint256 price, ) = oracle.getPriceData(_addr);
        return 1 * 1e18; // Placeholder for actual price retrieval logic
    }

    /**
     * @notice Checks if a Collateral is supported and enabled.
     * @param _addr The address of the Collateral.
     * @return True if the Collateral is supported and enabled, false otherwise.
     */
    function isSupportedCollateral(address _addr) internal view returns (bool) {
        return
            addrToCollateral[_addr].addr != address(0) &&
            addrToCollateral[_addr].isEnabled;
    }
}
