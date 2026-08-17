// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DepositQueue} from "../src/DepositQueue.sol";
import {IDepositQueue} from "../src/interfaces/IDepositQueue.sol";
import {TransferHelper} from "../src/libraries/TransferHelper.sol";

contract MockShareToken is ERC20 {
    constructor() ERC20("Share", "SHR") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Stands in for Fund: serves a configurable batch id (mirroring the
/// oracle's virtual id, which points past the closed batch after the cutoff),
/// accepts every deposit check, and grants every role so tests can drive the
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

    function checkDeposit(address, address, uint256, uint256, bytes32[] calldata) external view {}

    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }

    receive() external payable {}
}

contract DepositQueueTest is Test {
    address internal constant DEPOSITOR = address(uint160(uint256(keccak256("DEPOSITOR"))));
    address internal constant ETH = TransferHelper.ETH;
    uint256 internal constant DEPOSIT_AMOUNT = 1 ether;
    uint256 internal constant SETTLED_SHARES = 100e18;

    MockShareToken internal shareToken;
    MockFund internal fundMock;
    DepositQueue internal depositQueue;

    bytes32[] internal emptyProof;
    address[] internal noAssets;

    function setUp() public {
        shareToken = new MockShareToken();
        fundMock = new MockFund(address(shareToken));

        address[] memory allowedAssets = new address[](1);
        allowedAssets[0] = ETH;

        DepositQueue implementation = new DepositQueue();
        bytes memory initData = abi.encodeCall(DepositQueue.initialize, (address(fundMock), allowedAssets));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        depositQueue = DepositQueue(payable(address(proxy)));
    }

    function _depositAsDepositor() internal {
        vm.deal(DEPOSITOR, DEPOSIT_AMOUNT);
        vm.prank(DEPOSITOR);
        depositQueue.deposit{value: DEPOSIT_AMOUNT}(ETH, DEPOSIT_AMOUNT, emptyProof);
    }

    function _settleBatchZero() internal {
        vm.prank(address(fundMock));
        depositQueue.settleDeposit(ETH, 0, SETTLED_SHARES);
    }

    function _depositAs(address depositor, uint256 amount) internal {
        vm.deal(depositor, amount);
        vm.prank(depositor);
        depositQueue.deposit{value: amount}(ETH, amount, emptyProof);
    }

    // ---------------------------------------------------- setAllowedAssets

    function test_setAllowedAssets_revertsWhenCurrentBatchHasPendingDeposits() public {
        _depositAsDepositor();

        vm.expectRevert(IDepositQueue.AssetHasPendingRequests.selector);
        depositQueue.setAllowedAssets(noAssets);
    }

    /// @dev Regression: after the cutoff the virtual batch id points at the
    /// empty next batch, which previously let removal bypass the guard and
    /// strand deposits in the closed-but-unsettled batch.
    function test_setAllowedAssets_revertsWhenClosedUnsettledBatchHasPendingDeposits() public {
        _depositAsDepositor();
        fundMock.setCurrentBatchId(1);

        vm.expectRevert(IDepositQueue.AssetHasPendingRequests.selector);
        depositQueue.setAllowedAssets(noAssets);
    }

    function test_setAllowedAssets_removesAssetAfterClosedBatchSettles() public {
        _depositAsDepositor();
        _settleBatchZero();
        fundMock.setCurrentBatchId(1);

        depositQueue.setAllowedAssets(noAssets);

        assertEq(depositQueue.getAllowedAssets().length, 0);
    }

    function test_setAllowedAssets_removesAssetAfterCancel() public {
        _depositAsDepositor();
        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);
        fundMock.setCurrentBatchId(1);

        depositQueue.setAllowedAssets(noAssets);

        assertEq(depositQueue.getAllowedAssets().length, 0);
    }

    function test_setAllowedAssets_keepsAssetWithPendingDeposits() public {
        _depositAsDepositor();
        fundMock.setCurrentBatchId(1);

        address[] memory keptAssets = new address[](1);
        keptAssets[0] = ETH;
        depositQueue.setAllowedAssets(keptAssets);

        assertEq(depositQueue.getAllowedAssets().length, 1);
    }

    // ---------------------------------------------- getClaimableDeposits

    function test_getClaimableDeposits_showsSettledBatchAfterAssetRemoved() public {
        _depositAsDepositor();
        _settleBatchZero();
        fundMock.setCurrentBatchId(1);
        depositQueue.setAllowedAssets(noAssets);

        IDepositQueue.DepositRequestInfo[] memory claimable = depositQueue.getClaimableDeposits(DEPOSITOR);

        assertEq(claimable.length, 1);
        assertEq(claimable[0].asset, ETH);
        assertEq(claimable[0].batchId, 0);
        assertEq(claimable[0].amount, DEPOSIT_AMOUNT);
    }

    // ------------------------------------------------------- claimDeposit

    function test_claimDeposit_worksAfterAssetRemoved() public {
        _depositAsDepositor();
        _settleBatchZero();
        shareToken.mint(address(depositQueue), SETTLED_SHARES);
        fundMock.setCurrentBatchId(1);
        depositQueue.setAllowedAssets(noAssets);

        vm.prank(DEPOSITOR);
        depositQueue.claimDeposit(ETH, 0);

        assertEq(shareToken.balanceOf(DEPOSITOR), SETTLED_SHARES);
    }

    // ------------------------------------------- deposit accumulation

    function test_deposit_accumulatesWithinBatch() public {
        _depositAs(DEPOSITOR, 1 ether);
        vm.warp(block.timestamp + 1 hours);
        _depositAs(DEPOSITOR, 2 ether);

        IDepositQueue.DepositRequest memory request = depositQueue.getDepositRequest(ETH, 0, DEPOSITOR);
        assertEq(request.amount, 3 ether);
        assertEq(request.timestamp, uint48(block.timestamp));
        assertEq(depositQueue.batchDepositTotals(ETH, 0), 3 ether);
    }

    function test_deposit_emitsDeltaAndAccumulatedTotal() public {
        _depositAs(DEPOSITOR, 1 ether);

        vm.expectEmit(true, true, false, true, address(depositQueue));
        emit IDepositQueue.DepositSubmitted(DEPOSITOR, ETH, 0, 2 ether, 3 ether);
        _depositAs(DEPOSITOR, 2 ether);
    }

    function test_deposit_keepsBatchesSeparate() public {
        _depositAs(DEPOSITOR, 1 ether);
        fundMock.setCurrentBatchId(1);
        _depositAs(DEPOSITOR, 2 ether);

        assertEq(depositQueue.getDepositRequest(ETH, 0, DEPOSITOR).amount, 1 ether);
        assertEq(depositQueue.getDepositRequest(ETH, 1, DEPOSITOR).amount, 2 ether);
        assertEq(depositQueue.batchDepositTotals(ETH, 0), 1 ether);
        assertEq(depositQueue.batchDepositTotals(ETH, 1), 2 ether);
    }

    function test_cancelDeposit_refundsAccumulatedTotal() public {
        _depositAs(DEPOSITOR, 1 ether);
        _depositAs(DEPOSITOR, 2 ether);

        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, 3 ether);
        assertEq(depositQueue.batchDepositTotals(ETH, 0), 0);
        assertEq(depositQueue.getDepositRequest(ETH, 0, DEPOSITOR).amount, 0);
    }

    function test_claimDeposit_paysProRataOnAccumulatedAmount() public {
        address otherDepositor = address(uint160(uint256(keccak256("OTHER_DEPOSITOR"))));
        _depositAs(DEPOSITOR, 1 ether);
        _depositAs(DEPOSITOR, 2 ether);
        _depositAs(otherDepositor, 1 ether);
        _settleBatchZero();
        shareToken.mint(address(depositQueue), SETTLED_SHARES);
        fundMock.setCurrentBatchId(1);

        vm.prank(DEPOSITOR);
        depositQueue.claimDeposit(ETH, 0);
        vm.prank(otherDepositor);
        depositQueue.claimDeposit(ETH, 0);

        assertEq(shareToken.balanceOf(DEPOSITOR), SETTLED_SHARES * 3 / 4);
        assertEq(shareToken.balanceOf(otherDepositor), SETTLED_SHARES / 4);
    }

    // ------------------------------------------------- forceCancelDeposit

    /// @dev Simulates a stuck batch: cutoff passed (virtual id moved on) but
    /// the batch was never settled, so `cancelDeposit` cannot reach it.
    function _strandDepositInClosedBatchZero() internal returns (uint48 cutoffTime) {
        _depositAsDepositor();
        cutoffTime = uint48(block.timestamp) + 1 days;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(cutoffTime);
        fundMock.setCurrentBatchId(1);
    }

    function test_forceCancelDeposit_refundsAfterDelay() public {
        uint48 cutoffTime = _strandDepositInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + depositQueue.FORCE_CANCEL_DELAY());

        vm.prank(DEPOSITOR);
        depositQueue.forceCancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
        assertEq(depositQueue.batchDepositTotals(ETH, 0), 0);
        assertEq(depositQueue.getDepositRequest(ETH, 0, DEPOSITOR).amount, 0);
    }

    function test_forceCancelDeposit_worksWhilePaused() public {
        uint48 cutoffTime = _strandDepositInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + depositQueue.FORCE_CANCEL_DELAY());
        depositQueue.pause();

        vm.prank(DEPOSITOR);
        depositQueue.forceCancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
    }

    function test_forceCancelDeposit_revertsBeforeDelayElapsed() public {
        uint48 cutoffTime = _strandDepositInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + depositQueue.FORCE_CANCEL_DELAY() - 1);

        vm.prank(DEPOSITOR);
        vm.expectRevert(IDepositQueue.ForceCancelNotOpen.selector);
        depositQueue.forceCancelDeposit(ETH);
    }

    function test_forceCancelDeposit_revertsWhileBatchOpen() public {
        _depositAsDepositor();
        fundMock.setSettlingBatch(0, uint48(block.timestamp) + 1 days);

        vm.prank(DEPOSITOR);
        vm.expectRevert(IDepositQueue.ForceCancelNotOpen.selector);
        depositQueue.forceCancelDeposit(ETH);
    }

    function test_forceCancelDeposit_revertsWhenBatchSettled() public {
        uint48 cutoffTime = _strandDepositInClosedBatchZero();
        _settleBatchZero();
        vm.warp(uint256(cutoffTime) + depositQueue.FORCE_CANCEL_DELAY());

        vm.prank(DEPOSITOR);
        vm.expectRevert(IDepositQueue.AlreadySettled.selector);
        depositQueue.forceCancelDeposit(ETH);
    }

    function test_forceCancelDeposit_revertsWithoutRequest() public {
        uint48 cutoffTime = _strandDepositInClosedBatchZero();
        vm.warp(uint256(cutoffTime) + depositQueue.FORCE_CANCEL_DELAY());

        vm.expectRevert(IDepositQueue.NoRequest.selector);
        depositQueue.forceCancelDeposit(ETH);
    }

    // ---------------------------------------------- cancelDeposit lock window

    function test_setCancelLockWindow_updatesAndEmits() public {
        vm.expectEmit(false, false, false, true, address(depositQueue));
        emit IDepositQueue.CancelLockWindowUpdated(2 hours);
        depositQueue.setCancelLockWindow(2 hours);

        assertEq(depositQueue.cancelLockWindow(), 2 hours);
    }

    function test_cancelDeposit_allowedBeforeLockWindow() public {
        depositQueue.setCancelLockWindow(1 hours);
        _depositAsDepositor();
        fundMock.setSettlingBatch(0, uint48(block.timestamp) + 1 days);

        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
        assertEq(depositQueue.batchDepositTotals(ETH, 0), 0);
    }

    function test_cancelDeposit_revertsInsideLockWindow() public {
        depositQueue.setCancelLockWindow(1 hours);
        _depositAsDepositor();
        uint48 cutoffTime = uint48(block.timestamp) + 1 hours;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(uint256(cutoffTime) - 30 minutes);

        vm.prank(DEPOSITOR);
        vm.expectRevert(IDepositQueue.CancelLocked.selector);
        depositQueue.cancelDeposit(ETH);
    }

    function test_cancelDeposit_lockBoundaryIsInclusive() public {
        depositQueue.setCancelLockWindow(1 hours);
        _depositAsDepositor();
        uint48 cutoffTime = uint48(block.timestamp) + 2 hours;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(uint256(cutoffTime) - 1 hours);

        vm.prank(DEPOSITOR);
        vm.expectRevert(IDepositQueue.CancelLocked.selector);
        depositQueue.cancelDeposit(ETH);
    }

    function test_cancelDeposit_allowedOneSecondBeforeLockWindow() public {
        depositQueue.setCancelLockWindow(1 hours);
        _depositAsDepositor();
        uint48 cutoffTime = uint48(block.timestamp) + 2 hours;
        fundMock.setSettlingBatch(0, cutoffTime);
        vm.warp(uint256(cutoffTime) - 1 hours - 1);

        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
    }

    function test_cancelDeposit_notLockedWhenWindowZero() public {
        _depositAsDepositor();
        uint48 cutoffTime = uint48(block.timestamp) + 1;
        fundMock.setSettlingBatch(0, cutoffTime);

        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
    }

    /// @dev In the limbo after cutoff the virtual batch id has advanced ahead of
    /// the settling batch, so its stale cutoff must not freeze cancellation of a
    /// fresh request in the new (virtual) batch.
    function test_cancelDeposit_notLockedAfterCutoff() public {
        depositQueue.setCancelLockWindow(1 days);
        fundMock.setCurrentBatchId(1);
        _depositAsDepositor();
        fundMock.setSettlingBatch(0, uint48(block.timestamp));

        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
    }

    /// @dev Regression guard: the lock must key off the batch being cancelled,
    /// not the settling batch's cutoff. Here the virtual batch (1) is ahead of
    /// the settling batch (0) while that cutoff is still in-window — keying off
    /// the settling cutoff would wrongly lock. Only the mock can hold this
    /// state, but it pins the fix against reintroducing the id mix-up.
    function test_cancelDeposit_lockKeysOffCancelledBatchNotSettlingBatch() public {
        depositQueue.setCancelLockWindow(1 hours);
        fundMock.setCurrentBatchId(1);
        _depositAsDepositor();
        fundMock.setSettlingBatch(0, uint48(block.timestamp) + 1 hours);

        vm.prank(DEPOSITOR);
        depositQueue.cancelDeposit(ETH);

        assertEq(DEPOSITOR.balance, DEPOSIT_AMOUNT);
    }
}
