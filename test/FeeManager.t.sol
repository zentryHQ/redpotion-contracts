// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FeeManager} from "../src/FeeManager.sol";
import {IFeeManager} from "../src/interfaces/IFeeManager.sol";
import {FundSpokeACLModule} from "../src/modules/FundSpokeACLModule.sol";

/// @dev Stands in for Fund: exposes the (virtual) batch id FeeManager stages
/// against, the role callback used by onlyRole, and the protocol fee
/// recipient lookup accrueFees resolves through the fund.
contract MockFund {
    uint256 public batchId;
    address public admin;

    constructor(address admin_) {
        admin = admin_;
    }

    function setBatchId(uint256 batchId_) external {
        batchId = batchId_;
    }

    function getCurrentBatchId() external view returns (uint256) {
        return batchId;
    }

    function hasRole(bytes32, address account) external view returns (bool) {
        return account == admin;
    }

    function protocolFeeRecipient() external view returns (address) {
        return address(0);
    }
}

contract FeeManagerTest is Test {
    FeeManager internal feeManager;
    MockFund internal fundMock;
    uint256 internal deployTimestamp;

    address internal constant ADMIN = address(uint160(uint256(keccak256("ADMIN"))));
    address internal constant STRANGER = address(uint160(uint256(keccak256("STRANGER"))));
    address internal constant FEE_RECIPIENT = address(uint160(uint256(keccak256("FEE_RECIPIENT"))));
    address internal constant FEE_BASE_ASSET = address(uint160(uint256(keccak256("FEE_BASE_ASSET"))));
    address internal constant NEW_FEE_BASE_ASSET = address(uint160(uint256(keccak256("NEW_FEE_BASE_ASSET"))));

    uint256 internal constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 internal constant PRICE = 1 ether;

    function setUp() public {
        fundMock = new MockFund(ADMIN);

        FeeManager implementation = new FeeManager();
        bytes memory initData = abi.encodeCall(
            FeeManager.initialize,
            (address(fundMock), FEE_RECIPIENT, FEE_BASE_ASSET, _feeConfig(100, 200, 0, 0, 0))
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        feeManager = FeeManager(address(proxy));
        deployTimestamp = block.timestamp;
    }

    function _feeConfig(
        uint256 entryFeeBps,
        uint256 exitFeeBps,
        uint256 managementFeeBps,
        uint256 performanceFeeBps,
        uint256 protocolFeeBps
    ) internal pure returns (IFeeManager.FeeConfig memory) {
        return IFeeManager.FeeConfig({
            entryFeeBps: entryFeeBps,
            exitFeeBps: exitFeeBps,
            managementFeeBps: managementFeeBps,
            performanceFeeBps: performanceFeeBps,
            protocolFeeBps: protocolFeeBps
        });
    }

    function test_setFeeConfig_stagesForNextBatchWithoutTouchingActive() public {
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(500, 600, 0, 0, 0));

        assertEq(feeManager.entryFeeBps(), 100, "active entry fee unchanged");
        assertEq(feeManager.exitFeeBps(), 200, "active exit fee unchanged");

        IFeeManager.PendingFeeConfig[] memory pending = feeManager.getPendingFeeConfigs();
        assertEq(pending.length, 1, "one staged change");
        assertEq(pending[0].effectiveBatchId, 1, "effective from next batch");
        assertEq(pending[0].config.entryFeeBps, 500, "staged entry fee");

        assertEq(feeManager.getFeeConfigForBatch(0).entryFeeBps, 100, "open batch keeps active config");
        assertEq(feeManager.getFeeConfigForBatch(1).entryFeeBps, 500, "next batch gets staged config");
        assertEq(feeManager.getFeeConfigForBatch(2).entryFeeBps, 500, "later batches get staged config");
    }

    function test_setFeeConfig_restageInSameBatchOverwritesTail() public {
        vm.startPrank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(500, 600, 0, 0, 0));
        feeManager.setFeeConfig(_feeConfig(700, 800, 0, 0, 0));
        vm.stopPrank();

        IFeeManager.PendingFeeConfig[] memory pending = feeManager.getPendingFeeConfigs();
        assertEq(pending.length, 1, "restage collapses into one entry");
        assertEq(pending[0].effectiveBatchId, 1, "same boundary");
        assertEq(pending[0].config.entryFeeBps, 700, "last staged config wins");
    }

    function test_setFeeConfig_afterCutoffTargetsFollowingBatch() public {
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(500, 600, 0, 0, 0));

        fundMock.setBatchId(1);
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(700, 800, 0, 0, 0));

        IFeeManager.PendingFeeConfig[] memory pending = feeManager.getPendingFeeConfigs();
        assertEq(pending.length, 2, "both changes staged");
        assertEq(pending[0].effectiveBatchId, 1, "first effective at batch 1");
        assertEq(pending[1].effectiveBatchId, 2, "second effective at batch 2");

        assertEq(feeManager.getFeeConfigForBatch(0).entryFeeBps, 100, "settling batch keeps active config");
        assertEq(feeManager.getFeeConfigForBatch(1).entryFeeBps, 500, "open batch keeps its quoted config");
        assertEq(feeManager.getFeeConfigForBatch(2).entryFeeBps, 700, "following batch gets latest config");
    }

    function test_accrueFees_promotesAtBatchBoundaryAndTrims() public {
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(500, 600, 0, 0, 0));
        fundMock.setBatchId(1);
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(700, 800, 0, 0, 0));

        vm.prank(address(fundMock));
        feeManager.accrueFees(TOTAL_SUPPLY, PRICE, 0);

        assertEq(feeManager.entryFeeBps(), 500, "batch-1 config promoted after settling batch 0");
        assertEq(feeManager.getPendingFeeConfigs().length, 1, "promoted entry trimmed");
        assertEq(feeManager.getPendingFeeConfigs()[0].effectiveBatchId, 2, "batch-2 config still pending");

        vm.prank(address(fundMock));
        feeManager.accrueFees(TOTAL_SUPPLY, PRICE, 1);

        assertEq(feeManager.entryFeeBps(), 700, "batch-2 config promoted after settling batch 1");
        assertEq(feeManager.getPendingFeeConfigs().length, 0, "queue empty");
    }

    function test_accrueFees_usesRatesInForceOverElapsedPeriod() public {
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(100, 200, 1000, 0, 0));

        vm.warp(deployTimestamp + 365 days);
        vm.prank(address(fundMock));
        (, uint256 feeShares, , ) = feeManager.accrueFees(TOTAL_SUPPLY, PRICE, 0);
        assertEq(feeShares, 0, "elapsed period accrues at the old zero management fee");
        assertEq(feeManager.managementFeeBps(), 1000, "new rate active from the next batch");

        vm.warp(deployTimestamp + 730 days);
        vm.prank(address(fundMock));
        (, feeShares, , ) = feeManager.accrueFees(TOTAL_SUPPLY, PRICE, 1);
        assertEq(feeShares, TOTAL_SUPPLY / 10, "next period accrues at the promoted rate");
    }

    /// @dev Stages a performance fee, promotes it, and accrues once so the
    /// high-water mark is seeded at PRICE in the current base asset.
    function _seedHighWaterMark() internal {
        vm.prank(ADMIN);
        feeManager.setFeeConfig(_feeConfig(100, 200, 0, 2000, 0));
        vm.prank(address(fundMock));
        feeManager.accrueFees(TOTAL_SUPPLY, PRICE, 0);
        vm.prank(address(fundMock));
        feeManager.accrueFees(TOTAL_SUPPLY, PRICE, 1);
        assertEq(feeManager.highWaterMark(), PRICE, "mark seeded in the old denomination");
    }

    function test_setFeeBaseAsset_resetsHighWaterMarkOnAssetChange() public {
        _seedHighWaterMark();

        vm.prank(ADMIN);
        feeManager.setFeeBaseAsset(NEW_FEE_BASE_ASSET);
        assertEq(feeManager.feeBaseAsset(), NEW_FEE_BASE_ASSET, "base asset switched");
        assertEq(feeManager.highWaterMark(), 0, "mark reset on base asset change");

        uint256 newDenominationPrice = 100_000 ether;
        vm.prank(address(fundMock));
        (, uint256 feeShares, , ) = feeManager.accrueFees(TOTAL_SUPPLY, newDenominationPrice, 2);
        assertEq(feeShares, 0, "no phantom performance fee after the switch");
        assertEq(feeManager.highWaterMark(), newDenominationPrice, "mark reseeded at the new asset's price");
    }

    function test_setFeeBaseAsset_sameAssetKeepsHighWaterMark() public {
        _seedHighWaterMark();

        vm.prank(ADMIN);
        feeManager.setFeeBaseAsset(FEE_BASE_ASSET);
        assertEq(feeManager.highWaterMark(), PRICE, "mark kept when asset unchanged");
    }

    function test_setFeeConfig_revertsForUnauthorizedCaller() public {
        vm.prank(STRANGER);
        vm.expectRevert(FundSpokeACLModule.UnauthorizedRole.selector);
        feeManager.setFeeConfig(_feeConfig(500, 600, 0, 0, 0));
    }

    function test_setFeeConfig_validatesBeforeStaging() public {
        vm.prank(ADMIN);
        vm.expectRevert(IFeeManager.EntryFeeTooHigh.selector);
        feeManager.setFeeConfig(_feeConfig(10001, 0, 0, 0, 0));

        assertEq(feeManager.getPendingFeeConfigs().length, 0, "nothing staged");
    }
}
