// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Interface for ERC-3643: Tokenized Regulatory Compliance
 */
interface IERC3643 is IERC165 {
    // Events
    event JurisdictionSet(address indexed account, bytes32 jurisdiction);
    event ComplianceRuleAdded(bytes32 indexed ruleId, string ruleDescription);
    event ComplianceRuleRemoved(bytes32 indexed ruleId);
    event AccountComplianceStatusChanged(
        address indexed account,
        bool compliant
    );
    event TransferRestrictionSet(bytes32 indexed ruleId, bool restricted);
    event RegulatorAdded(address indexed regulator);
    event RegulatorRemoved(address indexed regulator);

    // Methods
    function addRegulator(address newRegulator) external;
    function removeRegulator(address regulator) external;
    function setJurisdiction(address account, bytes32 jurisdiction) external;
    function getJurisdiction(address account) external view returns (bytes32);
    function addComplianceRule(
        bytes32 ruleId,
        string calldata description
    ) external;
    function removeComplianceRule(bytes32 ruleId) external;
    function setRuleTransferRestriction(
        bytes32 ruleId,
        bool restricted
    ) external;
    function setAccountComplianceStatus(
        address account,
        bool compliant
    ) external;
    function isAccountCompliant(address account) external view returns (bool);
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool, bytes32[] memory failedRules);
}

/**
 * @dev Interface for a ComplianceOracle that provides off-chain compliance data
 */
interface IComplianceOracle {
    function verifyCompliance(
        address from,
        address to,
        uint256 amount,
        bytes32[] memory jurisdictions
    ) external view returns (bool, bytes32[] memory failedRules);
}

/**
 * @dev Implementation of ERC-3643 Tokenized Regulatory Compliance
 */
contract ERC3643 is ERC20, Ownable, IERC3643 {
    // Compliance rule structure
    struct ComplianceRule {
        string description;
        bool transferRestricted;
        bool active;
    }

    // Jurisdiction mapping
    mapping(address => bytes32) private _jurisdictions;

    // Compliance rules mapping
    mapping(bytes32 => ComplianceRule) private _complianceRules;

    // Account compliance status
    mapping(address => bool) private _accountCompliance;

    // Regulators
    mapping(address => bool) private _regulators;

    // Compliance oracle
    IComplianceOracle private _complianceOracle;

    constructor(
        string memory name,
        string memory symbol,
        IComplianceOracle complianceOracle
    ) ERC20(name, symbol) {
        _regulators[msg.sender] = true;
        _complianceOracle = complianceOracle;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC3643).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Modifier to restrict access to regulators
     */
    modifier onlyRegulator() {
        require(
            _regulators[msg.sender] || owner() == msg.sender,
            "Caller is not a regulator"
        );
        _;
    }

    /**
     * @dev Add a new regulator
     */
    function addRegulator(address newRegulator) external override onlyOwner {
        require(!_regulators[newRegulator], "Address is already a regulator");
        _regulators[newRegulator] = true;
        emit RegulatorAdded(newRegulator);
    }

    /**
     * @dev Remove a regulator
     */
    function removeRegulator(address regulator) external override onlyOwner {
        require(_regulators[regulator], "Address is not a regulator");
        _regulators[regulator] = false;
        emit RegulatorRemoved(regulator);
    }

    /**
     * @dev Set jurisdiction for an account
     */
    function setJurisdiction(
        address account,
        bytes32 jurisdiction
    ) external override onlyRegulator {
        _jurisdictions[account] = jurisdiction;
        emit JurisdictionSet(account, jurisdiction);
    }

    /**
     * @dev Get jurisdiction for an account
     */
    function getJurisdiction(
        address account
    ) external view override returns (bytes32) {
        return _jurisdictions[account];
    }

    /**
     * @dev Add a new compliance rule
     */
    function addComplianceRule(
        bytes32 ruleId,
        string calldata description
    ) external override onlyRegulator {
        require(!_complianceRules[ruleId].active, "Rule already exists");
        _complianceRules[ruleId] = ComplianceRule({
            description: description,
            transferRestricted: false,
            active: true
        });
        emit ComplianceRuleAdded(ruleId, description);
    }

    /**
     * @dev Remove a compliance rule
     */
    function removeComplianceRule(
        bytes32 ruleId
    ) external override onlyRegulator {
        require(_complianceRules[ruleId].active, "Rule does not exist");
        _complianceRules[ruleId].active = false;
        emit ComplianceRuleRemoved(ruleId);
    }

    /**
     * @dev Set transfer restriction for a rule
     */
    function setRuleTransferRestriction(
        bytes32 ruleId,
        bool restricted
    ) external override onlyRegulator {
        require(_complianceRules[ruleId].active, "Rule does not exist");
        _complianceRules[ruleId].transferRestricted = restricted;
        emit TransferRestrictionSet(ruleId, restricted);
    }

    /**
     * @dev Set compliance status for an account
     */
    function setAccountComplianceStatus(
        address account,
        bool compliant
    ) external override onlyRegulator {
        _accountCompliance[account] = compliant;
        emit AccountComplianceStatusChanged(account, compliant);
    }

    /**
     * @dev Check if an account is compliant
     */
    function isAccountCompliant(
        address account
    ) external view override returns (bool) {
        return _accountCompliance[account];
    }

    /**
     * @dev Determine if a transfer can proceed and which rules failed
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool, bytes32[] memory) {
        // Check basic compliance
        if (!_accountCompliance[from] || !_accountCompliance[to]) {
            bytes32[] memory failedRules = new bytes32[](1);
            failedRules[0] = "ACCOUNT_NOT_COMPLIANT";
            return (false, failedRules);
        }

        // Get jurisdictions
        bytes32[] memory jurisdictions = new bytes32[](2);
        jurisdictions[0] = _jurisdictions[from];
        jurisdictions[1] = _jurisdictions[to];

        // Query external oracle if available
        if (address(_complianceOracle) != address(0)) {
            return
                _complianceOracle.verifyCompliance(
                    from,
                    to,
                    amount,
                    jurisdictions
                );
        }

        // If no oracle, assume transfer is allowed
        return (true, new bytes32[](0));
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
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        // Skip compliance checks for minting (from == address(0))
        if (from != address(0)) {
            bool allowed;
            bytes32[] memory failedRules;

            (allowed, failedRules) = canTransfer(from, to, amount);

            require(allowed, _formatTransferError(failedRules));
        }
    }

    /**
     * @dev Format error message from failed rules
     */
    function _formatTransferError(
        bytes32[] memory failedRules
    ) internal view returns (string memory) {
        if (failedRules.length == 0) {
            return "Transfer restricted by compliance rules";
        }

        string memory message = "Failed rules: ";
        for (uint256 i = 0; i < failedRules.length; i++) {
            message = string(
                abi.encodePacked(
                    message,
                    failedRules[i],
                    i < failedRules.length - 1 ? ", " : ""
                )
            );
        }

        return message;
    }
}
