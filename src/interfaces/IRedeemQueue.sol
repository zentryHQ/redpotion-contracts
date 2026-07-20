// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IRedeemQueue {
    struct RedeemRequest {
        uint256 shares;
        uint48 timestamp;
    }

    struct RedeemRequestInfo {
        address asset;
        uint256 batchId;
        uint256 shares;
        uint48 timestamp;
    }

    struct AssetStatus {
        address asset;
        bool paused;
    }

    struct UnfundedBatch {
        address asset;
        uint256 batchId;
    }

    // Events

    event RedeemSubmitted(
        address indexed investor,
        address indexed asset,
        uint256 batchId,
        uint256 shares
    );
    event RedeemCancelled(
        address indexed investor,
        address indexed asset,
        uint256 batchId,
        uint256 shares
    );
    event RedeemClaimed(
        address indexed investor,
        address indexed asset,
        uint256 batchId,
        uint256 assets
    );
    event RedeemAllowedAssetsUpdated(address[] assets);
    event RedeemSettled(
        address indexed asset,
        uint256 indexed batchId,
        uint256 totalShares,
        uint256 totalAssets
    );
    event RedeemFunded(
        address indexed asset,
        uint256 indexed batchId,
        uint256 totalAssets
    );
    event AssetPulled(address indexed asset, uint256 amount);
    event RedeemQueuePaused();
    event RedeemQueueUnpaused();
    event AssetPaused(address indexed asset);
    event AssetUnpaused(address indexed asset);
    event FundUpdated(address indexed fund);
    event RedeemQueueCreated(address indexed fund, address[] allowedAssets);

    // Errors

    error ZeroAddress();
    error ZeroAmount();
    error NoRequest();
    error RequestExists();
    error BatchClosed();
    error BatchNotFunded();
    error NothingToClaim();
    error UnsupportedAsset();
    error AssetIsPaused();
    error OnlyFund();
    error AssetHasPendingRequests();
    error DuplicateAsset();
    error FundExist();
    error NotSettled();
    error AlreadyFunded();
    error AlreadySettled();

    // View functions

    function fund() external view returns (address);

    function getAllowedAssets() external view returns (address[] memory);

    function getAssetStatuses() external view returns (AssetStatus[] memory);

    function batchRedeemTotals(
        address asset,
        uint256 batchId
    ) external view returns (uint256);

    function batchAssetTotals(
        address asset,
        uint256 batchId
    ) external view returns (uint256);

    function isBatchFunded(
        address asset,
        uint256 batchId
    ) external view returns (bool);

    function getRedeemRequest(
        address asset,
        uint256 batchId,
        address investor
    ) external view returns (RedeemRequest memory);

    function getPendingRedeems(
        address investor
    ) external view returns (RedeemRequestInfo[] memory);

    function getClaimableRedeems(
        address investor
    ) external view returns (RedeemRequestInfo[] memory);

    function getUnfundedBatches() external view returns (UnfundedBatch[] memory);

    // Mutable functions

    function initialize(
        address fund_,
        address[] calldata allowedAssets_
    ) external;

    function setAllowedAssets(address[] calldata assets_) external;

    function redeem(address asset, uint256 shares) external;

    function cancelRedeem(address asset) external;

    /// @notice Called by Fund. Admin-cancels a user's redeem request in the
    /// current batch and refunds the original shares to the user.
    function adminCancelRedeem(address asset, uint256 batchId, address user) external;

    function claimRedeem(address asset, uint256 batchId) external;

    /// @notice Called by Fund during acceptReport. Transfers redeem shares to
    /// Fund for burning and snapshots the asset-payout total for the batch at
    /// the accepted price + exit fee.
    function settleRedeem(
        address asset,
        uint256 batchId,
        uint256 assetAmount
    ) external;

    /// @notice Called by Fund. Marks a settled batch as funded; assets must
    /// already have been transferred by Fund using the snapshot in
    /// `batchAssetTotals`.
    function fundRedeem(address asset, uint256 batchId) external;

    /// @notice Called by holder of PULL_REDEEM_ASSET_ROLE. Pulls assets back to Fund.
    function pullAsset(address asset, uint256 amount) external;

    function pause() external;

    function unpause() external;

    function pauseAssets(address[] calldata assets) external;

    function unpauseAssets(address[] calldata assets) external;

    function isAssetPaused(address asset) external view returns (bool);
}
