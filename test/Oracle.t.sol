// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Oracle} from "../src/Oracle.sol";
import {IReportModule} from "../src/interfaces/IReportModule.sol";

/// @dev Stands in for Fund: grants every role so tests can drive the oracle's
/// role-gated setters directly.
contract MockFund {
    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }
}

contract OracleTest is Test {
    uint48 internal constant START_TIME = 1_000_000;
    uint48 internal constant FIRST_CUTOFF = START_TIME + 1 days;
    address internal constant ASSET = address(0xA55E7);

    MockFund internal fundMock;
    Oracle internal oracle;

    function setUp() public {
        vm.warp(START_TIME);

        fundMock = new MockFund();

        Oracle implementation = new Oracle();
        IReportModule.PriceSafetyInit[] memory priceSafeties = new IReportModule.PriceSafetyInit[](0);
        bytes memory initData = abi.encodeCall(
            Oracle.initialize,
            (address(fundMock), FIRST_CUTOFF, 0, 0, priceSafeties)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        oracle = Oracle(address(proxy));
    }

    function test_setNextCutoffTime_succeedsWhileBatchOpen() public {
        uint48 newCutoff = FIRST_CUTOFF + 1 days;
        oracle.setNextCutoffTime(newCutoff);
        assertEq(oracle.nextCutoffTime(), newCutoff);
    }

    /// @dev Regression: once the cutoff is reached the batch is closed and a
    /// price may already be public; re-extending would collapse
    /// getCurrentBatchId() back onto the priced batch (free-option attack).
    function test_setNextCutoffTime_revertsAfterCutoffReached() public {
        vm.warp(FIRST_CUTOFF);
        vm.expectRevert(IReportModule.BatchAlreadyClosed.selector);
        oracle.setNextCutoffTime(FIRST_CUTOFF + 1 days);
    }

    function test_setNextCutoffTime_revertsAfterCutoffPassed() public {
        vm.warp(FIRST_CUTOFF + 1 hours);
        vm.expectRevert(IReportModule.BatchAlreadyClosed.selector);
        oracle.setNextCutoffTime(FIRST_CUTOFF + 2 days);
    }

    function _submitReport(uint256 price) internal {
        IReportModule.ReportSubmission[] memory reports = new IReportModule.ReportSubmission[](1);
        reports[0] = IReportModule.ReportSubmission({asset: ASSET, price: price});
        oracle.submitReport(reports);
    }

    function _setMinPrice(uint256 minPrice) internal {
        oracle.setPriceSafety(
            ASSET,
            IReportModule.PriceSafety({
                minPrice: minPrice,
                maxPrice: 0,
                maxAbsoluteDelta: 0,
                maxDeviationBps: 0
            })
        );
    }

    function _singleAsset() internal pure returns (address[] memory assets) {
        assets = new address[](1);
        assets[0] = ASSET;
    }

    /// @dev Regression: suspicious is derived from the current price-safety
    /// config, so bounds tightened after submit must gate settlement behind
    /// the suspicious-accept path instead of honoring a submit-time snapshot.
    function test_acceptReport_revertsWhenBoundsTightenAfterSubmit() public {
        vm.warp(FIRST_CUTOFF);
        _submitReport(100e18);
        assertFalse(oracle.getPendingReport(ASSET, 0).suspicious);

        _setMinPrice(150e18);
        assertTrue(oracle.getPendingReport(ASSET, 0).suspicious);

        vm.warp(FIRST_CUTOFF + 1 hours);
        vm.prank(address(fundMock));
        vm.expectRevert(IReportModule.SuspiciousReportPending.selector);
        oracle.acceptReport(_singleAsset(), uint48(block.timestamp + 1 days));
    }

    function test_acceptSuspiciousReport_succeedsWhenBoundsTightenAfterSubmit() public {
        vm.warp(FIRST_CUTOFF);
        _submitReport(100e18);
        _setMinPrice(150e18);

        vm.warp(FIRST_CUTOFF + 1 hours);
        vm.prank(address(fundMock));
        oracle.acceptSuspiciousReport(_singleAsset(), uint48(block.timestamp + 1 days));

        assertEq(oracle.lastAcceptedPrice(ASSET), 100e18);
        assertEq(oracle.currentBatchId(), 1);
    }

    function test_acceptReport_succeedsWhenBoundsLoosenAfterSubmit() public {
        _setMinPrice(150e18);
        vm.warp(FIRST_CUTOFF);
        _submitReport(100e18);
        assertTrue(oracle.getPendingReport(ASSET, 0).suspicious);

        _setMinPrice(0);
        assertFalse(oracle.getPendingReport(ASSET, 0).suspicious);

        vm.warp(FIRST_CUTOFF + 1 hours);
        vm.prank(address(fundMock));
        oracle.acceptReport(_singleAsset(), uint48(block.timestamp + 1 days));

        assertEq(oracle.lastAcceptedPrice(ASSET), 100e18);
        assertEq(oracle.currentBatchId(), 1);
    }

    /// @dev The accept-window check runs before the live safety check so an
    /// absent report reverts NoPendingReport, not SuspiciousReportPending
    /// (price 0 in an empty slot would read as below any configured minPrice).
    function test_acceptReport_missingReportRevertsNoPendingReport() public {
        _setMinPrice(150e18);
        assertFalse(oracle.getPendingReport(ASSET, 0).suspicious);

        vm.warp(FIRST_CUTOFF + 1 hours);
        vm.prank(address(fundMock));
        vm.expectRevert(IReportModule.NoPendingReport.selector);
        oracle.acceptReport(_singleAsset(), uint48(block.timestamp + 1 days));
    }
}
