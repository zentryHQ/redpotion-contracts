// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Fund} from "../src/Fund.sol";
import {FundShare} from "../src/FundShare.sol";
import {FeeManager} from "../src/FeeManager.sol";
import {DepositQueue} from "../src/DepositQueue.sol";
import {RedeemQueue} from "../src/RedeemQueue.sol";
import {Oracle} from "../src/Oracle.sol";
import {IFeeManager} from "../src/interfaces/IFeeManager.sol";
import {IFeeManagerModule} from "../src/interfaces/IFeeManagerModule.sol";
import {IQueueModule} from "../src/interfaces/IQueueModule.sol";
import {IReportModule} from "../src/interfaces/IReportModule.sol";
import {ACLModule} from "../src/modules/ACLModule.sol";

contract MockAsset is ERC20 {
    constructor() ERC20("Mock Asset", "ASSET") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Accepts every request so queue submissions never hit risk checks.
contract MockRiskManager {
    function checkDeposit(address, address, uint256, uint256, bytes32[] calldata) external view {}

    function checkRedeem(uint256, uint256) external view {}
}

/// @dev Stands in for FundManager: fee accrual only needs the protocol fee
/// recipient lookup.
contract MockFundManager {
    address public protocolFeeRecipient;

    constructor(address protocolFeeRecipient_) {
        protocolFeeRecipient = protocolFeeRecipient_;
    }
}

/// @dev Settlement tests over the real star (Fund, FundShare, Oracle, queues,
/// FeeManager): base-asset fees (management, performance, protocol) must
/// accrue on the share supply as it stood before any of this batch's
/// settlement, so deposit mints, redeem burns and entry/exit fee shares
/// minted while settling never leak into the supply-based fee formulas.
///
/// The fee base asset is deliberately listed AFTER the secondary deposit
/// asset, so accruing fees inside the settlement loop (instead of before it)
/// would settle the secondary asset's deposits first and pollute the fee base.
contract FundSettlementTest is Test {
    address internal constant USER = address(uint160(uint256(keccak256("USER"))));
    address internal constant FEE_RECIPIENT = address(uint160(uint256(keccak256("FEE_RECIPIENT"))));
    address internal constant PROTOCOL_FEE_RECIPIENT = address(uint160(uint256(keccak256("PROTOCOL_FEE_RECIPIENT"))));

    uint256 internal constant ENTRY_FEE_BPS = 100;
    uint256 internal constant EXIT_FEE_BPS = 100;
    uint256 internal constant MANAGEMENT_FEE_BPS = 1000;
    uint256 internal constant PERFORMANCE_FEE_BPS = 2000;
    uint256 internal constant PROTOCOL_FEE_BPS = 500;

    uint256 internal constant SEED_DEPOSIT_AMOUNT = 1_000 ether;
    uint256 internal constant PENDING_DEPOSIT_AMOUNT = 500 ether;
    uint256 internal constant PENDING_REDEEM_SHARES = 200 ether;
    uint256 internal constant INITIAL_BASE_PRICE = 1e18;
    uint256 internal constant RAISED_BASE_PRICE = 1.1e18;
    uint256 internal constant SECONDARY_PRICE = 2e18;
    uint256 internal constant MAIN_BATCH_ID = 2;

    MockAsset internal baseAsset;
    MockAsset internal secondaryAsset;
    Fund internal fund;
    FundShare internal shareToken;
    DepositQueue internal depositQueue;
    RedeemQueue internal redeemQueue;
    Oracle internal oracle;
    FeeManager internal feeManager;

    bytes32[] internal emptyProof;

    struct SettlementExpectations {
        uint256 preSettlementSupply;
        uint256 managementFeeShares;
        uint256 performanceFeeShares;
        uint256 protocolFeeShares;
        uint256 depositUserShares;
        uint256 entryFeeShares;
        uint256 exitFeeShares;
    }

    function setUp() public {
        baseAsset = new MockAsset();
        secondaryAsset = new MockAsset();
        MockRiskManager riskManagerMock = new MockRiskManager();
        MockFundManager fundManagerMock = new MockFundManager(PROTOCOL_FEE_RECIPIENT);

        fund = Fund(payable(address(new ERC1967Proxy(address(new Fund()), ""))));

        shareToken = FundShare(address(new ERC1967Proxy(
            address(new FundShare()),
            abi.encodeCall(FundShare.initialize, ("Fund Share", "SHARE", address(fund)))
        )));

        // Secondary first so the fee base asset settles LAST in _settleAll.
        address[] memory depositAssets = new address[](2);
        depositAssets[0] = address(secondaryAsset);
        depositAssets[1] = address(baseAsset);
        address[] memory redeemAssets = new address[](1);
        redeemAssets[0] = address(baseAsset);

        depositQueue = DepositQueue(payable(address(new ERC1967Proxy(
            address(new DepositQueue()),
            abi.encodeCall(DepositQueue.initialize, (address(fund), depositAssets))
        ))));

        redeemQueue = RedeemQueue(payable(address(new ERC1967Proxy(
            address(new RedeemQueue()),
            abi.encodeCall(RedeemQueue.initialize, (address(fund), redeemAssets))
        ))));

        oracle = Oracle(address(new ERC1967Proxy(
            address(new Oracle()),
            abi.encodeCall(Oracle.initialize, (
                address(fund),
                uint48(block.timestamp + 1 days),
                0,
                0,
                new IReportModule.PriceSafetyInit[](0)
            ))
        )));

        feeManager = FeeManager(address(new ERC1967Proxy(
            address(new FeeManager()),
            abi.encodeCall(FeeManager.initialize, (
                address(fund),
                FEE_RECIPIENT,
                address(baseAsset),
                IFeeManager.FeeConfig({
                    entryFeeBps: ENTRY_FEE_BPS,
                    exitFeeBps: EXIT_FEE_BPS,
                    managementFeeBps: MANAGEMENT_FEE_BPS,
                    performanceFeeBps: PERFORMANCE_FEE_BPS,
                    protocolFeeBps: PROTOCOL_FEE_BPS
                })
            ))
        )));

        ACLModule.RoleHolder[] memory roleHolders = new ACLModule.RoleHolder[](2);
        roleHolders[0] = ACLModule.RoleHolder({role: fund.SUBMIT_REPORT_ROLE(), account: address(this)});
        roleHolders[1] = ACLModule.RoleHolder({role: fund.ACCEPT_REPORT_ROLE(), account: address(this)});

        fund.initialize(
            address(shareToken),
            address(depositQueue),
            address(redeemQueue),
            address(oracle),
            address(feeManager),
            address(riskManagerMock),
            address(fundManagerMock),
            address(this),
            roleHolders
        );

        // Batch 0 seeds the share supply; batch 1 accrues once on that supply
        // so the high-water mark is seeded at INITIAL_BASE_PRICE and the main
        // batch's performance fee is measurable.
        _deposit(baseAsset, USER, SEED_DEPOSIT_AMOUNT);
        _settleBatch(INITIAL_BASE_PRICE);
        _settleBatch(INITIAL_BASE_PRICE);
        assertEq(feeManager.highWaterMark(), INITIAL_BASE_PRICE, "high-water mark seeded");

        // Stage the batch under test: a pending secondary-asset deposit
        // (mints on settle, before the base asset's turn) and a pending
        // base-asset redeem (burns on settle) alongside the fee accrual.
        vm.prank(USER);
        depositQueue.claimDeposit(address(baseAsset), 0);
        _deposit(secondaryAsset, USER, PENDING_DEPOSIT_AMOUNT);
        vm.startPrank(USER);
        shareToken.approve(address(redeemQueue), PENDING_REDEEM_SHARES);
        redeemQueue.redeem(address(baseAsset), PENDING_REDEEM_SHARES);
        vm.stopPrank();

        uint48 cutoffTime = oracle.nextCutoffTime();
        vm.warp(cutoffTime);
        _submitReports(RAISED_BASE_PRICE);
        vm.warp(uint256(cutoffTime) + 1 hours);
    }

    function _deposit(MockAsset asset, address depositor, uint256 amount) internal {
        asset.mint(depositor, amount);
        vm.startPrank(depositor);
        asset.approve(address(depositQueue), amount);
        depositQueue.deposit(address(asset), amount, emptyProof);
        vm.stopPrank();
    }

    function _submitReports(uint256 basePrice) internal {
        IReportModule.ReportSubmission[] memory reports = new IReportModule.ReportSubmission[](2);
        reports[0] = IReportModule.ReportSubmission({asset: address(secondaryAsset), price: SECONDARY_PRICE});
        reports[1] = IReportModule.ReportSubmission({asset: address(baseAsset), price: basePrice});
        oracle.submitReport(reports);
    }

    function _settleBatch(uint256 basePrice) internal {
        uint48 cutoffTime = oracle.nextCutoffTime();
        vm.warp(cutoffTime);
        _submitReports(basePrice);
        vm.warp(uint256(cutoffTime) + 1 hours);
        fund.acceptReport(uint48(block.timestamp + 1 days));
    }

    /// @dev Mirrors the fee formulas using the supply as it stands right now —
    /// before acceptReport runs — i.e. the batch's pre-settlement supply. Any
    /// implementation that lets this batch's settlement mints/burns into the
    /// supply-based fee formulas produces different numbers.
    function _expectationsFromPreSettlementSupply() internal view returns (SettlementExpectations memory expectations) {
        expectations.preSettlementSupply = shareToken.totalSupply();
        uint256 elapsed = block.timestamp - feeManager.lastFeeAccrual();
        expectations.managementFeeShares =
            (expectations.preSettlementSupply * MANAGEMENT_FEE_BPS * elapsed) / (10000 * 365 days);
        expectations.performanceFeeShares =
            (expectations.preSettlementSupply * (RAISED_BASE_PRICE - INITIAL_BASE_PRICE) * PERFORMANCE_FEE_BPS)
                / (RAISED_BASE_PRICE * 10000);
        expectations.protocolFeeShares =
            (expectations.preSettlementSupply * PROTOCOL_FEE_BPS * elapsed) / (10000 * 365 days);

        uint256 depositTotalShares = (PENDING_DEPOSIT_AMOUNT * 1e18) / SECONDARY_PRICE;
        expectations.entryFeeShares = (depositTotalShares * ENTRY_FEE_BPS) / 10000;
        expectations.depositUserShares = depositTotalShares - expectations.entryFeeShares;
        expectations.exitFeeShares = (PENDING_REDEEM_SHARES * EXIT_FEE_BPS) / 10000;
    }

    function test_settleAll_accruesBaseAssetFeesBeforeSettlingDepositsAndRedeems() public {
        SettlementExpectations memory expectations = _expectationsFromPreSettlementSupply();

        // Ordered expectations: all three fee accruals — at amounts only
        // reachable from the pre-settlement supply — must precede every
        // queue settlement, including the secondary asset settled before the
        // fee base asset's position in the asset list.
        vm.expectEmit(address(fund));
        emit IFeeManagerModule.ManagementFeeAccrued(MAIN_BATCH_ID, expectations.managementFeeShares);
        vm.expectEmit(address(fund));
        emit IFeeManagerModule.PerformanceFeeAccrued(
            MAIN_BATCH_ID, expectations.performanceFeeShares, RAISED_BASE_PRICE
        );
        vm.expectEmit(address(fund));
        emit IFeeManagerModule.ProtocolFeeAccrued(MAIN_BATCH_ID, expectations.protocolFeeShares);
        vm.expectEmit(address(fund));
        emit IQueueModule.EntryFeeAccrued(address(secondaryAsset), MAIN_BATCH_ID, expectations.entryFeeShares);
        vm.expectEmit(address(fund));
        emit IQueueModule.ExitFeeAccrued(address(baseAsset), MAIN_BATCH_ID, expectations.exitFeeShares);

        fund.acceptReport(uint48(block.timestamp + 1 days));
    }

    function test_settleAll_feeAccrualBaseExcludesCurrentBatchMintsAndBurns() public {
        SettlementExpectations memory expectations = _expectationsFromPreSettlementSupply();
        uint256 feeRecipientBalanceBefore = shareToken.balanceOf(FEE_RECIPIENT);
        uint256 protocolRecipientBalanceBefore = shareToken.balanceOf(PROTOCOL_FEE_RECIPIENT);

        fund.acceptReport(uint48(block.timestamp + 1 days));

        assertEq(
            shareToken.balanceOf(PROTOCOL_FEE_RECIPIENT) - protocolRecipientBalanceBefore,
            expectations.protocolFeeShares,
            "protocol fee accrued on the pre-settlement supply"
        );
        assertEq(
            shareToken.balanceOf(FEE_RECIPIENT) - feeRecipientBalanceBefore,
            expectations.managementFeeShares + expectations.performanceFeeShares
                + expectations.entryFeeShares + expectations.exitFeeShares,
            "management + performance fees accrued on the pre-settlement supply, plus this batch's entry/exit fee shares"
        );
        assertEq(
            shareToken.balanceOf(address(depositQueue)),
            expectations.depositUserShares,
            "secondary-asset deposit settled at its own price"
        );
        assertEq(
            shareToken.totalSupply(),
            expectations.preSettlementSupply
                + expectations.managementFeeShares + expectations.performanceFeeShares + expectations.protocolFeeShares
                + expectations.depositUserShares + expectations.entryFeeShares + expectations.exitFeeShares
                - PENDING_REDEEM_SHARES,
            "supply moves by accrued fees plus settlement mints minus the redeem burn"
        );
    }
}

contract MockAllowedAssetsQueue {
    address[] internal allowedAssets;

    function setAllowedAssets(address[] memory assets_) external {
        allowedAssets = assets_;
    }

    function getAllowedAssets() external view returns (address[] memory) {
        return allowedAssets;
    }
}

contract MockBaseAssetFeeManager {
    address public feeBaseAsset;

    function setFeeBaseAsset(address feeBaseAsset_) external {
        feeBaseAsset = feeBaseAsset_;
    }
}

/// @dev Exposes the internal asset union used by acceptReport /
/// acceptSuspiciousReport so its set semantics can be asserted directly.
contract FundHarness is Fund {
    function allowedAssetsUnion() external view returns (address[] memory) {
        return _allowedAssetsUnion();
    }
}

/// @dev The union must always cover every depositable asset, every redeemable
/// asset, and the fee base asset — each exactly once — whatever the overlap
/// between the three sources.
contract FundAllowedAssetsUnionTest is Test {
    address internal constant ASSET_A = address(uint160(uint256(keccak256("ASSET_A"))));
    address internal constant ASSET_B = address(uint160(uint256(keccak256("ASSET_B"))));
    address internal constant ASSET_C = address(uint160(uint256(keccak256("ASSET_C"))));
    address internal constant ASSET_D = address(uint160(uint256(keccak256("ASSET_D"))));
    address internal constant FEE_BASE_ASSET = address(uint160(uint256(keccak256("FEE_BASE_ASSET"))));

    MockAllowedAssetsQueue internal depositQueueMock;
    MockAllowedAssetsQueue internal redeemQueueMock;
    MockBaseAssetFeeManager internal feeManagerMock;
    FundHarness internal fund;

    function setUp() public {
        depositQueueMock = new MockAllowedAssetsQueue();
        redeemQueueMock = new MockAllowedAssetsQueue();
        feeManagerMock = new MockBaseAssetFeeManager();

        fund = FundHarness(payable(address(new ERC1967Proxy(address(new FundHarness()), ""))));
        fund.initialize(
            address(uint160(uint256(keccak256("SHARE")))),
            address(depositQueueMock),
            address(redeemQueueMock),
            address(uint160(uint256(keccak256("ORACLE")))),
            address(feeManagerMock),
            address(uint160(uint256(keccak256("RISK_MANAGER")))),
            address(uint160(uint256(keccak256("FUND_MANAGER")))),
            address(this),
            new ACLModule.RoleHolder[](0)
        );
    }

    function _configure(
        address[] memory depositAssets,
        address[] memory redeemAssets,
        address feeBaseAsset
    ) internal {
        depositQueueMock.setAllowedAssets(depositAssets);
        redeemQueueMock.setAllowedAssets(redeemAssets);
        feeManagerMock.setFeeBaseAsset(feeBaseAsset);
    }

    function _assets(address first, address second) internal pure returns (address[] memory assets) {
        assets = new address[](2);
        assets[0] = first;
        assets[1] = second;
    }

    /// @dev Asserts `actual` is exactly the set `expected`: same size, and
    /// every expected asset present exactly once (so no duplicates either).
    function _assertSetEq(address[] memory actual, address[] memory expected) internal pure {
        assertEq(actual.length, expected.length, "union size mismatch");
        for (uint256 i = 0; i < expected.length; i++) {
            uint256 occurrences = 0;
            for (uint256 j = 0; j < actual.length; j++) {
                if (actual[j] == expected[i]) occurrences++;
            }
            assertEq(occurrences, 1, "expected asset missing or duplicated");
        }
    }

    function test_allowedAssetsUnion_noIntersection() public {
        _configure(_assets(ASSET_A, ASSET_B), _assets(ASSET_C, ASSET_D), FEE_BASE_ASSET);

        address[] memory expected = new address[](5);
        expected[0] = ASSET_A;
        expected[1] = ASSET_B;
        expected[2] = ASSET_C;
        expected[3] = ASSET_D;
        expected[4] = FEE_BASE_ASSET;
        _assertSetEq(fund.allowedAssetsUnion(), expected);
    }

    function test_allowedAssetsUnion_someIntersection() public {
        _configure(_assets(ASSET_A, ASSET_B), _assets(ASSET_B, ASSET_C), FEE_BASE_ASSET);

        address[] memory expected = new address[](4);
        expected[0] = ASSET_A;
        expected[1] = ASSET_B;
        expected[2] = ASSET_C;
        expected[3] = FEE_BASE_ASSET;
        _assertSetEq(fund.allowedAssetsUnion(), expected);
    }

    function test_allowedAssetsUnion_fullIntersection() public {
        _configure(_assets(ASSET_A, ASSET_B), _assets(ASSET_B, ASSET_A), ASSET_A);

        address[] memory expected = new address[](2);
        expected[0] = ASSET_A;
        expected[1] = ASSET_B;
        _assertSetEq(fund.allowedAssetsUnion(), expected);
    }

    function test_allowedAssetsUnion_feeBaseAssetInDepositAssetsOnly() public {
        _configure(_assets(ASSET_A, ASSET_B), _assets(ASSET_C, ASSET_D), ASSET_A);

        address[] memory expected = new address[](4);
        expected[0] = ASSET_A;
        expected[1] = ASSET_B;
        expected[2] = ASSET_C;
        expected[3] = ASSET_D;
        _assertSetEq(fund.allowedAssetsUnion(), expected);
    }

    function test_allowedAssetsUnion_feeBaseAssetInRedeemAssetsOnly() public {
        _configure(_assets(ASSET_A, ASSET_B), _assets(ASSET_C, ASSET_D), ASSET_D);

        address[] memory expected = new address[](4);
        expected[0] = ASSET_A;
        expected[1] = ASSET_B;
        expected[2] = ASSET_C;
        expected[3] = ASSET_D;
        _assertSetEq(fund.allowedAssetsUnion(), expected);
    }

    function test_allowedAssetsUnion_emptyQueuesStillIncludeFeeBaseAsset() public {
        _configure(new address[](0), new address[](0), FEE_BASE_ASSET);

        address[] memory expected = new address[](1);
        expected[0] = FEE_BASE_ASSET;
        _assertSetEq(fund.allowedAssetsUnion(), expected);
    }
}
