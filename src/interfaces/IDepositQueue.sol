// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IDepositQueue {
    struct DepositRequest {
        uint256 amount;
        uint48 timestamp;
    }

    struct DepositRequestInfo {
        address asset;
        uint256 batchId;
        uint256 amount;
        uint48 timestamp;
    }

    struct AssetStatus {
        address asset;
        bool paused;
    }

    // Events

    event DepositSubmitted(
        address indexed investor,
        address indexed asset,
        uint256 batchId,
        uint256 amount
    );
    event DepositCancelled(
        address indexed investor,
        address indexed asset,
        uint256 batchId,
        uint256 amount
    );
    event DepositClaimed(
        address indexed investor,
        address indexed asset,
        uint256 batchId,
        uint256 shares
    );
    event DepositAllowedAssetsUpdated(address[] assets);
    event DepositSettled(
        address indexed asset,
        uint256 indexed batchId,
        uint256 totalAssets,
        uint256 totalShares
    );
    event AssetPulled(address indexed asset, uint256 amount);
    event DepositQueuePaused();
    event DepositQueueUnpaused();
    event AssetPaused(address indexed asset);
    event AssetUnpaused(address indexed asset);
    event FundUpdated(address indexed fund);
    event DepositQueueCreated(address indexed fund, address[] allowedAssets);

    // Errors

    error ZeroAddress();
    error ZeroAmount();
    error NoRequest();
    error RequestExists();
    error BatchClosed();
    error BatchNotSettled();
    error AlreadySettled();
    error NothingToClaim();
    error UnsupportedAsset();
    error AssetIsPaused();
    error OnlyFund();
    error AssetHasPendingRequests();
    error DuplicateAsset();
    error FundExist();
    error InvalidETHAmount();

    // View functions

    function fund() external view returns (address);

    function getAllowedAssets() external view returns (address[] memory);

    function getAssetStatuses() external view returns (AssetStatus[] memory);

    function batchDepositTotals(
        address asset,
        uint256 batchId
    ) external view returns (uint256);

    function batchShareTotals(
        address asset,
        uint256 batchId
    ) external view returns (uint256);

    function getDepositRequest(
        address asset,
        uint256 batchId,
        address investor
    ) external view returns (DepositRequest memory);

    function getPendingDeposits(
        address investor
    ) external view returns (DepositRequestInfo[] memory);

    function getClaimableDeposits(
        address investor
    ) external view returns (DepositRequestInfo[] memory);

    // Mutable functions

    function initialize(
        address fund_,
        address[] calldata allowedAssets_
    ) external;

    function setAllowedAssets(address[] calldata assets_) external;

    function deposit(address asset, uint256 amount, bytes32[] calldata proof) external payable;

    function cancelDeposit(address asset) external;

    /// @notice Called by Fund. Admin-cancels a user's deposit request in the
    /// current batch and refunds the original amount to the user.
    function adminCancelDeposit(address asset, uint256 batchId, address user) external;

    function claimDeposit(address asset, uint256 batchId) external;

    /// @notice Called by Fund during acceptReport. Transfers assets to Fund.
    function settleDeposit(
        address asset,
        uint256 batchId,
        uint256 sharesToMint
    ) external;

    /// @notice Called by Fund. Pulls assets back to Fund.
    function pullAsset(address asset, uint256 amount) external;

    function pause() external;

    function unpause() external;

    function pauseAssets(address[] calldata assets) external;

    function unpauseAssets(address[] calldata assets) external;

    function isAssetPaused(address asset) external view returns (bool);
}
