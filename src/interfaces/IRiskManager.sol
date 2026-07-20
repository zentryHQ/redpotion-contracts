// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IRiskManager {
    struct RiskConfig {
        uint256 tvlCap;
        uint256 maxBatchDepositCap;
        uint256 maxBatchRedeemCap;
        uint256 minDepositAmount;
        uint256 minRedeemAmount;
        uint256 maxDrawdownBps;
        bytes32 merkleRoot;
    }

    struct RiskContext {
        uint256 basePrice;
        uint256 assetPrice;
        uint256 highWaterMark;
        uint256 batchDepositTotalInBase;
        uint256 batchRedeemTotalInBase;
        uint256 shareSupply;
        uint256 entryFeeBps;
        uint256 exitFeeBps;
    }

    // Events
    event TvlCapUpdated(uint256 cap);
    event MaxBatchDepositCapUpdated(uint256 cap);
    event MaxBatchRedeemCapUpdated(uint256 cap);
    event MinDepositAmountUpdated(uint256 amount);
    event MinRedeemAmountUpdated(uint256 amount);
    event MaxDrawdownUpdated(uint256 bps);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event MerkleRootUpdated(bytes32 root);
    event RiskManagerCreated(address indexed fund);

    // Errors
    error OnlyFund();
    error ZeroAddress();
    error TvlCapExceeded();
    error BaseAssetPriceUnavailable();
    error DepositAssetPriceUnavailable();
    error BatchDepositCapExceeded();
    error BatchRedeemCapExceeded();
    error DepositBelowMinimum();
    error RedeemBelowMinimum();
    error DrawdownBreached();
    error EmergencyPausedError();
    error NotWhitelisted();
    error InvalidDrawdownBps();

    // Views
    function fund() external view returns (address);
    function tvlCap() external view returns (uint256);
    function maxBatchDepositCap() external view returns (uint256);
    function maxBatchRedeemCap() external view returns (uint256);
    function minDepositAmount() external view returns (uint256);
    function minRedeemAmount() external view returns (uint256);
    function maxDrawdownBps() external view returns (uint256);
    function isEmergencyPaused() external view returns (bool);
    function merkleRoot() external view returns (bytes32);

    /// @dev Called by Fund (proxied from DepositQueue).
    function checkDeposit(
        address depositor,
        address asset,
        uint256 batchId,
        uint256 depositAmount,
        bytes32[] calldata proof
    ) external view;

    /// @dev Called by Fund (proxied from RedeemQueue).
    function checkRedeem(
        uint256 batchId,
        uint256 redeemShares
    ) external view;

    function estimateDeposit(address asset, uint256 depositAmount) external view returns (uint256 shares);
    function estimateRedeem(address asset, uint256 redeemShares) external view returns (uint256 assetAmount);

    // Mutable (onlyFund)
    function initialize(address fund_, RiskConfig calldata config_) external;
    function setTvlCap(uint256 cap) external;
    function setMaxBatchDepositCap(uint256 cap) external;
    function setMaxBatchRedeemCap(uint256 cap) external;
    function setMinDepositAmount(uint256 amount) external;
    function setMinRedeemAmount(uint256 amount) external;
    function setMaxDrawdown(uint256 bps) external;
    function emergencyPause() external;
    function emergencyUnpause() external;
    function setMerkleRoot(bytes32 root) external;
}
