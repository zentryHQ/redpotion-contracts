// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {RedeemQueue} from "../src/RedeemQueue.sol";
import {IRedeemQueue} from "../src/interfaces/IRedeemQueue.sol";
import {TransferHelper} from "../src/libraries/TransferHelper.sol";

contract MockShareToken is ERC20 {
    constructor() ERC20("Share", "SHR") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Stands in for Fund: serves a configurable batch id (mirroring the
/// oracle's virtual id, which points past the closed batch after the cutoff),
/// accepts every redeem check, and grants every role so tests can drive the
/// queue directly.
contract MockFund {
    uint256 internal currentBatchId;
    uint256 internal settlingBatchId;
    uint48 internal settlingCutoffTime;
    address public share;

    constructor(address share_) {
        share = share_;
    }

    function setCurrentBatchId(uint256 batchId) external {
        currentBatchId = batchId;
    }

    function getCurrentBatchId() external view returns (uint256) {
        return currentBatchId;
    }

    function setSettlingBatch(uint256 batchId, uint48 cutoffTime) external {
        settlingBatchId = batchId;
        settlingCutoffTime = cutoffTime;
    }

    function getSettlingBatch() external view returns (uint256, uint48) {
        return (settlingBatchId, settlingCutoffTime);
    }

    function checkRedeem(uint256, uint256) external view {}

    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }

    receive() external payable {}
}

contract RedeemQueueTest is Test {
    address internal constant REDEEMER = address(uint160(uint256(keccak256("REDEEMER"))));
    address internal constant ETH = TransferHelper.ETH;
    uint256 internal constant REDEEM_SHARES = 100e18;
    uint256 internal constant PAYOUT_AMOUNT = 1 ether;

    MockShareToken internal shareToken;
    MockFund internal fundMock;
    RedeemQueue internal redeemQueue;

    address[] internal noAssets;

    function setUp() public {
        shareToken = new MockShareToken();
        fundMock = new MockFund(address(shareToken));

        address[] memory allowedAssets = new address[](1);
        allowedAssets[0] = ETH;

        RedeemQueue implementation = new RedeemQueue();
        bytes memory initData = abi.encodeCall(RedeemQueue.initialize, (address(fundMock), allowedAssets));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        redeemQueue = RedeemQueue(payable(address(proxy)));
    }

    function _redeemAsRedeemer() internal {
        shareToken.mint(REDEEMER, REDEEM_SHARES);
        vm.startPrank(REDEEMER);
        shareToken.approve(address(redeemQueue), REDEEM_SHARES);
        redeemQueue.redeem(ETH, REDEEM_SHARES);
        vm.stopPrank();
    }

    function _settleBatchZero() internal {
        vm.prank(address(fundMock));
        redeemQueue.settleRedeem(ETH, 0, PAYOUT_AMOUNT);
    }

    function _fundBatchZero() internal {
        vm.deal(address(redeemQueue), PAYOUT_AMOUNT);
        vm.prank(address(fundMock));
        redeemQueue.fundRedeem(ETH, 0);
    }

    function _redeemAs(address redeemer, uint256 shares) internal {
        shareToken.mint(redeemer, shares);
        vm.startPrank(redeemer);
        shareToken.approve(address(redeemQueue), shares);
        redeemQueue.redeem(ETH, shares);
        vm.stopPrank();
    }

    // ---------------------------------------------------- setAllowedAssets

    function test_setAllowedAssets_revertsWhenCurrentBatchHasPendingRedeems() public {
        _redeemAsRedeemer();

        vm.expectRevert(IRedeemQueue.AssetHasPendingRequests.selector);
        redeemQueue.setAllowedAssets(noAssets);
    }

    /// @dev Regression: after the cutoff the virtual batch id points at the
    /// empty next batch, which previously let removal bypass the guard and
    /// strand escrowed shares in the closed-but-unsettled batch.
    function test_setAllowedAssets_revertsWhenClosedUnsettledBatchHasPendingRedeems() public {
        _redeemAsRedeemer();
        fundMock.setCurrentBatchId(1);

        vm.expectRevert(IRedeemQueue.AssetHasPendingRequests.selector);
        redeemQueue.setAllowedAssets(noAssets);
    }

    function test_setAllowedAssets_removesAssetAfterClosedBatchSettles() public {
        _redeemAsRedeemer();
        _settleBatchZero();
        fundMock.setCurrentBatchId(1);

        redeemQueue.setAllowedAssets(noAssets);

        assertEq(redeemQueue.getAllowedAssets().length, 0);
    }

    function test_setAllowedAssets_removesAssetAfterCancel() public {
        _redeemAsRedeemer();
        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);
        fundMock.setCurrentBatchId(1);

        redeemQueue.setAllowedAssets(noAssets);

        assertEq(redeemQueue.getAllowedAssets().length, 0);
    }

    function test_setAllowedAssets_keepsAssetWithPendingRedeems() public {
        _redeemAsRedeemer();
        fundMock.setCurrentBatchId(1);

        address[] memory keptAssets = new address[](1);
        keptAssets[0] = ETH;
        redeemQueue.setAllowedAssets(keptAssets);

        assertEq(redeemQueue.getAllowedAssets().length, 1);
    }

    // ----------------------------------------------- getClaimableRedeems

    function test_getClaimableRedeems_showsFundedBatchAfterAssetRemoved() public {
        _redeemAsRedeemer();
        _settleBatchZero();
        _fundBatchZero();
        fundMock.setCurrentBatchId(1);
        redeemQueue.setAllowedAssets(noAssets);

        IRedeemQueue.RedeemRequestInfo[] memory claimable = redeemQueue.getClaimableRedeems(REDEEMER);

        assertEq(claimable.length, 1);
        assertEq(claimable[0].asset, ETH);
        assertEq(claimable[0].batchId, 0);
        assertEq(claimable[0].shares, REDEEM_SHARES);
    }

    // -------------------------------------------------------- claimRedeem

    function test_claimRedeem_worksAfterAssetRemoved() public {
        _redeemAsRedeemer();
        _settleBatchZero();
        _fundBatchZero();
        fundMock.setCurrentBatchId(1);
        redeemQueue.setAllowedAssets(noAssets);

        vm.prank(REDEEMER);
        redeemQueue.claimRedeem(ETH, 0);

        assertEq(REDEEMER.balance, PAYOUT_AMOUNT);
    }

    // --------------------------------------------- redeem accumulation

    function test_redeem_accumulatesWithinBatch() public {
        _redeemAs(REDEEMER, 100e18);
        vm.warp(block.timestamp + 1 hours);
        _redeemAs(REDEEMER, 200e18);

        IRedeemQueue.RedeemRequest memory request = redeemQueue.getRedeemRequest(ETH, 0, REDEEMER);
        assertEq(request.shares, 300e18);
        assertEq(request.timestamp, uint48(block.timestamp));
        assertEq(redeemQueue.batchRedeemTotals(ETH, 0), 300e18);
    }

    function test_redeem_emitsDeltaAndAccumulatedTotal() public {
        _redeemAs(REDEEMER, 100e18);
        shareToken.mint(REDEEMER, 200e18);
        vm.prank(REDEEMER);
        shareToken.approve(address(redeemQueue), 200e18);

        vm.expectEmit(true, true, false, true, address(redeemQueue));
        emit IRedeemQueue.RedeemSubmitted(REDEEMER, ETH, 0, 200e18, 300e18);
        vm.prank(REDEEMER);
        redeemQueue.redeem(ETH, 200e18);
    }

    function test_redeem_keepsBatchesSeparate() public {
        _redeemAs(REDEEMER, 100e18);
        fundMock.setCurrentBatchId(1);
        _redeemAs(REDEEMER, 200e18);

        assertEq(redeemQueue.getRedeemRequest(ETH, 0, REDEEMER).shares, 100e18);
        assertEq(redeemQueue.getRedeemRequest(ETH, 1, REDEEMER).shares, 200e18);
        assertEq(redeemQueue.batchRedeemTotals(ETH, 0), 100e18);
        assertEq(redeemQueue.batchRedeemTotals(ETH, 1), 200e18);
    }

    function test_cancelRedeem_refundsAccumulatedShares() public {
        _redeemAs(REDEEMER, 100e18);
        _redeemAs(REDEEMER, 200e18);

        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), 300e18);
        assertEq(redeemQueue.batchRedeemTotals(ETH, 0), 0);
        assertEq(redeemQueue.getRedeemRequest(ETH, 0, REDEEMER).shares, 0);
    }

    function test_claimRedeem_paysProRataOnAccumulatedShares() public {
        address otherRedeemer = address(uint160(uint256(keccak256("OTHER_REDEEMER"))));
        _redeemAs(REDEEMER, 100e18);
        _redeemAs(REDEEMER, 200e18);
        _redeemAs(otherRedeemer, 100e18);
        _settleBatchZero();
        _fundBatchZero();
        fundMock.setCurrentBatchId(1);

        vm.prank(REDEEMER);
        redeemQueue.claimRedeem(ETH, 0);
        vm.prank(otherRedeemer);
        redeemQueue.claimRedeem(ETH, 0);

        assertEq(REDEEMER.balance, PAYOUT_AMOUNT * 3 / 4);
        assertEq(otherRedeemer.balance, PAYOUT_AMOUNT / 4);
    }

    // -------------------------------------------------- forceCancelRedeem

    /// @dev Simulates a stuck batch: cutoff passed (virtual id moved on) but
    /// the batch was never settled, so `cancelRedeem` cannot reach it.
    function _strandRedeemInClosedBatchZero() internal returns (uint48 cutoffTime) {
        _redeemAsRedeemer();
        cutoffTime = uint48(block.timestamp) + 1 days;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(cutoffTime);
        fundMock.setCurrentBatchId(1);
    }

    function test_forceCancelRedeem_returnsSharesAfterDelay() public {
        uint48 cutoffTime = _strandRedeemInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + redeemQueue.FORCE_CANCEL_DELAY());

        vm.prank(REDEEMER);
        redeemQueue.forceCancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
        assertEq(redeemQueue.batchRedeemTotals(ETH, 0), 0);
        assertEq(redeemQueue.getRedeemRequest(ETH, 0, REDEEMER).shares, 0);
    }

    function test_forceCancelRedeem_worksWhilePaused() public {
        uint48 cutoffTime = _strandRedeemInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + redeemQueue.FORCE_CANCEL_DELAY());
        redeemQueue.pause();

        vm.prank(REDEEMER);
        redeemQueue.forceCancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
    }

    function test_forceCancelRedeem_revertsBeforeDelayElapsed() public {
        uint48 cutoffTime = _strandRedeemInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + redeemQueue.FORCE_CANCEL_DELAY() - 1);

        vm.prank(REDEEMER);
        vm.expectRevert(IRedeemQueue.ForceCancelNotOpen.selector);
        redeemQueue.forceCancelRedeem(ETH);
    }

    function test_forceCancelRedeem_revertsWhileBatchOpen() public {
        _redeemAsRedeemer();
        fundMock.setSettlingBatch(0, uint48(block.timestamp) + 1 days);

        vm.prank(REDEEMER);
        vm.expectRevert(IRedeemQueue.ForceCancelNotOpen.selector);
        redeemQueue.forceCancelRedeem(ETH);
    }

    function test_forceCancelRedeem_revertsWhenBatchSettled() public {
        uint48 cutoffTime = _strandRedeemInClosedBatchZero();
        _settleBatchZero();
        vm.warp(uint256(cutoffTime) + redeemQueue.FORCE_CANCEL_DELAY());

        vm.prank(REDEEMER);
        vm.expectRevert(IRedeemQueue.AlreadySettled.selector);
        redeemQueue.forceCancelRedeem(ETH);
    }

    function test_forceCancelRedeem_revertsWithoutRequest() public {
        uint48 cutoffTime = _strandRedeemInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + redeemQueue.FORCE_CANCEL_DELAY());

        vm.expectRevert(IRedeemQueue.NoRequest.selector);
        redeemQueue.forceCancelRedeem(ETH);
    }

    // ----------------------------------------------- cancelRedeem lock window

    function test_setCancelLockWindow_updatesAndEmits() public {
        vm.expectEmit(false, false, false, true, address(redeemQueue));
        emit IRedeemQueue.CancelLockWindowUpdated(2 hours);
        redeemQueue.setCancelLockWindow(2 hours);

        assertEq(redeemQueue.cancelLockWindow(), 2 hours);
    }

    function test_cancelRedeem_allowedBeforeLockWindow() public {
        redeemQueue.setCancelLockWindow(1 hours);
        _redeemAsRedeemer();
        fundMock.setSettlingBatch(0, uint48(block.timestamp) + 1 days);

        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
        assertEq(redeemQueue.batchRedeemTotals(ETH, 0), 0);
    }

    function test_cancelRedeem_revertsInsideLockWindow() public {
        redeemQueue.setCancelLockWindow(1 hours);
        _redeemAsRedeemer();
        uint48 cutoffTime = uint48(block.timestamp) + 1 hours;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(uint256(cutoffTime) - 30 minutes);

        vm.prank(REDEEMER);
        vm.expectRevert(IRedeemQueue.CancelLocked.selector);
        redeemQueue.cancelRedeem(ETH);
    }

    function test_cancelRedeem_lockBoundaryIsInclusive() public {
        redeemQueue.setCancelLockWindow(1 hours);
        _redeemAsRedeemer();
        uint48 cutoffTime = uint48(block.timestamp) + 2 hours;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(uint256(cutoffTime) - 1 hours);

        vm.prank(REDEEMER);
        vm.expectRevert(IRedeemQueue.CancelLocked.selector);
        redeemQueue.cancelRedeem(ETH);
    }

    function test_cancelRedeem_allowedOneSecondBeforeLockWindow() public {
        redeemQueue.setCancelLockWindow(1 hours);
        _redeemAsRedeemer();
        uint48 cutoffTime = uint48(block.timestamp) + 2 hours;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(uint256(cutoffTime) - 1 hours - 1);

        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
    }

    function test_cancelRedeem_notLockedWhenWindowZero() public {
        _redeemAsRedeemer();
        uint48 cutoffTime = uint48(block.timestamp) + 1;
        fundMock.setSettlingBatch(0, cutoffTime);

        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
    }

    /// @dev In the limbo after cutoff the virtual batch id has advanced ahead of
    /// the settling batch, so its stale cutoff must not freeze cancellation of a
    /// fresh request in the new (virtual) batch.
    function test_cancelRedeem_notLockedAfterCutoff() public {
        redeemQueue.setCancelLockWindow(1 days);
        fundMock.setCurrentBatchId(1);
        _redeemAsRedeemer();
        fundMock.setSettlingBatch(0, uint48(block.timestamp));

        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
    }

    /// @dev Regression guard: the lock must key off the batch being cancelled,
    /// not the settling batch's cutoff. Here the virtual batch (1) is ahead of
    /// the settling batch (0) while that cutoff is still in-window — keying off
    /// the settling cutoff would wrongly lock. Only the mock can hold this
    /// state, but it pins the fix against reintroducing the id mix-up.
    function test_cancelRedeem_lockKeysOffCancelledBatchNotSettlingBatch() public {
        redeemQueue.setCancelLockWindow(1 hours);
        fundMock.setCurrentBatchId(1);
        _redeemAsRedeemer();
        fundMock.setSettlingBatch(0, uint48(block.timestamp) + 1 hours);

        vm.prank(REDEEMER);
        redeemQueue.cancelRedeem(ETH);

        assertEq(shareToken.balanceOf(REDEEMER), REDEEM_SHARES);
    }
}
