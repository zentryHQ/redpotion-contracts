// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {RiskManager} from "../src/RiskManager.sol";
import {IRiskManager} from "../src/interfaces/IRiskManager.sol";

/// @dev Stands in for Fund: serves a configurable RiskContext and grants
/// every role so tests can call the RiskManager admin setters directly.
contract MockFund {
    IRiskManager.RiskContext internal riskContext;

    function setRiskContext(IRiskManager.RiskContext memory riskContext_) external {
        riskContext = riskContext_;
    }

    function getRiskContext(address, uint256) external view returns (IRiskManager.RiskContext memory) {
        return riskContext;
    }

    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }
}

contract RiskManagerTest is Test {
    MockFund internal fundMock;

    address internal constant DEPOSITOR = address(uint160(uint256(keccak256("DEPOSITOR"))));
    address internal constant ASSET = address(uint160(uint256(keccak256("ASSET"))));
    uint256 internal constant BATCH_ID = 1;

    bytes32[] internal emptyProof;

    function setUp() public {
        fundMock = new MockFund();
    }

    function _deployRiskManager(IRiskManager.RiskConfig memory config) internal returns (RiskManager) {
        RiskManager implementation = new RiskManager();
        bytes memory initData = abi.encodeCall(RiskManager.initialize, (address(fundMock), config));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return RiskManager(address(proxy));
    }

    function _emptyConfig() internal pure returns (IRiskManager.RiskConfig memory config) {}

    /// @dev basePrice and assetPrice at 1e18 so deposit amount == value in base.
    function _defaultContext() internal pure returns (IRiskManager.RiskContext memory context) {
        context.basePrice = 1e18;
        context.assetPrice = 1e18;
    }

    function _leaf(address depositor) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(depositor))));
    }

    function _hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return left < right ? keccak256(abi.encodePacked(left, right)) : keccak256(abi.encodePacked(right, left));
    }

    // ---------------------------------------------------------------- deposit

    function test_checkDeposit_passesWhenNoLimitsConfigured() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());
        // Context left fully zeroed: passing proves the fund is never consulted.
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_revertsWhenEmergencyPaused() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());
        riskManager.emergencyPause();

        vm.expectRevert(IRiskManager.EmergencyPausedError.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_passesAgainAfterEmergencyUnpause() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());
        riskManager.emergencyPause();
        riskManager.emergencyUnpause();

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_revertsWhenNotWhitelisted() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.merkleRoot = _hashPair(_leaf(DEPOSITOR), _leaf(address(0xBEEF)));
        RiskManager riskManager = _deployRiskManager(config);

        vm.expectRevert(IRiskManager.NotWhitelisted.selector);
        riskManager.checkDeposit(address(0xCAFE), ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_passesWithValidWhitelistProof() public {
        bytes32 siblingLeaf = _leaf(address(0xBEEF));
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.merkleRoot = _hashPair(_leaf(DEPOSITOR), siblingLeaf);
        RiskManager riskManager = _deployRiskManager(config);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = siblingLeaf;
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, proof);
    }

    function test_checkDeposit_revertsWhenBasePriceUnavailable() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 1e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.basePrice = 0;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.BaseAssetPriceUnavailable.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_revertsWhenDrawdownBreached() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxDrawdownBps = 1000;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.highWaterMark = 1e18;
        context.basePrice = 0.85e18;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.DrawdownBreached.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_passesWithinDrawdownLimit() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxDrawdownBps = 1000;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.highWaterMark = 1e18;
        context.basePrice = 0.95e18;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_skipsDrawdownWhenNoHighWaterMark() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxDrawdownBps = 1000;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.highWaterMark = 0;
        context.basePrice = 0.5e18;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_revertsWhenAssetPriceUnavailable() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.tvlCap = 1000e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.assetPrice = 0;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.DepositAssetPriceUnavailable.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_revertsBelowMinimumDeposit() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 100e18;
        RiskManager riskManager = _deployRiskManager(config);
        fundMock.setRiskContext(_defaultContext());

        vm.expectRevert(IRiskManager.DepositBelowMinimum.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18 - 1, emptyProof);
    }

    function test_checkDeposit_passesAtExactMinimumDeposit() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 100e18;
        RiskManager riskManager = _deployRiskManager(config);
        fundMock.setRiskContext(_defaultContext());

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 100e18, emptyProof);
    }

    function test_checkDeposit_minimumUsesValueInBaseNotRawAmount() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        // 60 units of a 2x-priced asset -> 30 shares -> 120 in base (basePrice 4e18).
        IRiskManager.RiskContext memory context = _defaultContext();
        context.assetPrice = 2e18;
        context.basePrice = 4e18;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 60e18, emptyProof);

        vm.expectRevert(IRiskManager.DepositBelowMinimum.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 49e18, emptyProof);
    }

    function test_checkDeposit_passesAtExactMinimumWithNonDivisiblePrice() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 10e6;
        RiskManager riskManager = _deployRiskManager(config);

        // 6-decimal base asset, share worth 3 units: depositing exactly 10 of
        // the base asset itself must pass even though 10e6 * 1e18 is not
        // divisible by the price (a share round-trip would floor to 9_999_999).
        IRiskManager.RiskContext memory context;
        context.basePrice = 3e6;
        context.assetPrice = 3e6;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 10e6, emptyProof);
    }

    function test_checkDeposit_batchCapUsesFullPrecisionValueInBase() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxBatchDepositCap = 10e6;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context;
        context.basePrice = 3e6;
        context.assetPrice = 3e6;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 10e6, emptyProof);

        // 1 unit over the cap must revert; a share round-trip floors the value
        // back to exactly the cap and lets it through.
        vm.expectRevert(IRiskManager.BatchDepositCapExceeded.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 10e6 + 1, emptyProof);
    }

    function test_checkDeposit_revertsWhenBatchDepositCapExceeded() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxBatchDepositCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.batchDepositTotalInBase = 50e18;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.BatchDepositCapExceeded.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 50e18 + 1, emptyProof);
    }

    function test_checkDeposit_passesAtExactBatchDepositCap() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxBatchDepositCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.batchDepositTotalInBase = 50e18;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 50e18, emptyProof);
    }

    function test_checkDeposit_revertsWhenTvlCapExceeded() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.tvlCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.shareSupply = 90e18;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.TvlCapExceeded.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 10e18 + 1, emptyProof);
    }

    function test_checkDeposit_passesAtExactTvlCap() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.tvlCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.shareSupply = 90e18;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 10e18, emptyProof);
    }

    function test_checkDeposit_countsPendingBatchDepositsTowardTvlCap() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.tvlCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        // Settled TVL 80 leaves 20 of headroom, but 15 is already pending in
        // the current batch — only 5 more may enter.
        IRiskManager.RiskContext memory context = _defaultContext();
        context.shareSupply = 80e18;
        context.batchDepositTotalInBase = 15e18;
        fundMock.setRiskContext(context);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 5e18, emptyProof);

        vm.expectRevert(IRiskManager.TvlCapExceeded.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, 5e18 + 1, emptyProof);
    }

    // ----------------------------------------------------------------- redeem

    function test_checkRedeem_passesWhenNoLimitsConfigured() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());
        // Context left fully zeroed: passing proves the fund is never consulted.
        riskManager.checkRedeem(BATCH_ID, 100e18);
    }

    function test_checkRedeem_revertsWhenEmergencyPaused() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());
        riskManager.emergencyPause();

        vm.expectRevert(IRiskManager.EmergencyPausedError.selector);
        riskManager.checkRedeem(BATCH_ID, 100e18);
    }

    function test_checkRedeem_revertsWhenBasePriceUnavailable() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minRedeemAmount = 1e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.basePrice = 0;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.BaseAssetPriceUnavailable.selector);
        riskManager.checkRedeem(BATCH_ID, 100e18);
    }

    function test_checkRedeem_revertsBelowMinimumRedeem() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minRedeemAmount = 100e18;
        RiskManager riskManager = _deployRiskManager(config);
        fundMock.setRiskContext(_defaultContext());

        vm.expectRevert(IRiskManager.RedeemBelowMinimum.selector);
        riskManager.checkRedeem(BATCH_ID, 100e18 - 1);
    }

    function test_checkRedeem_passesAtExactMinimumRedeem() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minRedeemAmount = 100e18;
        RiskManager riskManager = _deployRiskManager(config);
        fundMock.setRiskContext(_defaultContext());

        riskManager.checkRedeem(BATCH_ID, 100e18);
    }

    function test_checkRedeem_minimumUsesValueInBaseNotShares() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minRedeemAmount = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        // 60 shares at basePrice 2e18 -> 120 in base.
        IRiskManager.RiskContext memory context = _defaultContext();
        context.basePrice = 2e18;
        fundMock.setRiskContext(context);

        riskManager.checkRedeem(BATCH_ID, 60e18);

        vm.expectRevert(IRiskManager.RedeemBelowMinimum.selector);
        riskManager.checkRedeem(BATCH_ID, 49e18);
    }

    function test_checkRedeem_revertsWhenBatchRedeemCapExceeded() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxBatchRedeemCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.batchRedeemTotalInBase = 50e18;
        fundMock.setRiskContext(context);

        vm.expectRevert(IRiskManager.BatchRedeemCapExceeded.selector);
        riskManager.checkRedeem(BATCH_ID, 50e18 + 1);
    }

    function test_checkRedeem_passesAtExactBatchRedeemCap() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.maxBatchRedeemCap = 100e18;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context = _defaultContext();
        context.batchRedeemTotalInBase = 50e18;
        fundMock.setRiskContext(context);

        riskManager.checkRedeem(BATCH_ID, 50e18);
    }

    // ---------------------------------------------------------- min getters

    function test_getMinDepositAmount_isExactCheckDepositBoundary() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 10e6;
        RiskManager riskManager = _deployRiskManager(config);

        // Non-divisible prices: 6-decimal base at share price 3, 18-decimal
        // deposit asset at share price 7e14.
        IRiskManager.RiskContext memory context;
        context.basePrice = 3e6;
        context.assetPrice = 7e14;
        fundMock.setRiskContext(context);

        uint256 minAssetAmount = riskManager.getMinDepositAmount(ASSET);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, minAssetAmount, emptyProof);

        vm.expectRevert(IRiskManager.DepositBelowMinimum.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, minAssetAmount - 1, emptyProof);
    }

    function test_getMinDepositAmount_isExactValueWhenConversionDividesEvenly() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minDepositAmount = 10e6;
        RiskManager riskManager = _deployRiskManager(config);

        // 10e6 * 5e14 / 2e6 = 2.5e15 exactly — ceil must not add a unit.
        IRiskManager.RiskContext memory context;
        context.basePrice = 2e6;
        context.assetPrice = 5e14;
        fundMock.setRiskContext(context);

        uint256 minAssetAmount = riskManager.getMinDepositAmount(ASSET);
        assertEq(minAssetAmount, 2.5e15);

        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, minAssetAmount, emptyProof);

        vm.expectRevert(IRiskManager.DepositBelowMinimum.selector);
        riskManager.checkDeposit(DEPOSITOR, ASSET, BATCH_ID, minAssetAmount - 1, emptyProof);
    }

    function test_getMinDepositAmount_returnsZeroWhenNoMinimumConfigured() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());

        assertEq(riskManager.getMinDepositAmount(ASSET), 0);
    }

    function test_getMinRedeemShares_isExactCheckRedeemBoundary() public {
        IRiskManager.RiskConfig memory config = _emptyConfig();
        config.minRedeemAmount = 10e6;
        RiskManager riskManager = _deployRiskManager(config);

        IRiskManager.RiskContext memory context;
        context.basePrice = 3e6;
        fundMock.setRiskContext(context);

        uint256 minShares = riskManager.getMinRedeemShares();
        assertEq(minShares, 3333333333333333334);

        riskManager.checkRedeem(BATCH_ID, minShares);

        vm.expectRevert(IRiskManager.RedeemBelowMinimum.selector);
        riskManager.checkRedeem(BATCH_ID, minShares - 1);
    }

    function test_getMinRedeemShares_returnsZeroWhenNoMinimumConfigured() public {
        RiskManager riskManager = _deployRiskManager(_emptyConfig());

        assertEq(riskManager.getMinRedeemShares(), 0);
    }
}
