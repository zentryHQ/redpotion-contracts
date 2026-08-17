// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FeeManager} from "../src/FeeManager.sol";
import {IFeeManager} from "../src/interfaces/IFeeManager.sol";

/// @dev Leaf in the resolution chain — mirrors FundManagerDeployer's surface for this lookup.
contract MockProtocolFeeDeployer {
    address public protocolFeeRecipient;

    constructor(address protocolFeeRecipient_) {
        protocolFeeRecipient = protocolFeeRecipient_;
    }
}

/// @dev Stands in for FundManager. Forwards protocolFeeRecipient() down to the deployer
/// the same way the real FundManager does, so the call chain matches production depth.
contract MockFundManager {
    address public deployer;

    constructor(address deployer_) {
        deployer = deployer_;
    }

    function protocolFeeRecipient() external view returns (address) {
        return MockProtocolFeeDeployer(deployer).protocolFeeRecipient();
    }
}

/// @dev Stands in for Fund — forwards protocolFeeRecipient() to its FundManager.
/// FeeManager calls this contract via IFund(fund).protocolFeeRecipient(), so we need
/// a real contract at the `fund` address with the matching function.
contract MockFund {
    address public fundManager;

    constructor(address fundManager_) {
        fundManager = fundManager_;
    }

    function protocolFeeRecipient() external view returns (address) {
        return MockFundManager(fundManager).protocolFeeRecipient();
    }
}

contract FeeManagerGasTest is Test {
    FeeManager internal feeManager;
    MockFund internal fundMock;
    MockFundManager internal fundManagerMock;
    MockProtocolFeeDeployer internal protocolFeeDeployer;

    address internal constant FEE_RECIPIENT = address(uint160(uint256(keccak256("FEE_RECIPIENT"))));
    address internal constant PROTOCOL_FEE_RECIPIENT = address(uint160(uint256(keccak256("PROTOCOL_FEE_RECIPIENT"))));
    address internal constant FEE_BASE_ASSET = address(uint160(uint256(keccak256("FEE_BASE_ASSET"))));

    uint256 internal constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 internal constant NEW_PRICE = 1.1 ether;

    function setUp() public {
        protocolFeeDeployer = new MockProtocolFeeDeployer(PROTOCOL_FEE_RECIPIENT);
        fundManagerMock = new MockFundManager(address(protocolFeeDeployer));
        fundMock = new MockFund(address(fundManagerMock));

        FeeManager implementation = new FeeManager();

        IFeeManager.FeeConfig memory feeConfig = IFeeManager.FeeConfig({
            entryFeeBps: 0,
            exitFeeBps: 0,
            managementFeeBps: 100,
            performanceFeeBps: 1000,
            protocolFeeBps: 50
        });

        bytes memory initData = abi.encodeCall(
            FeeManager.initialize,
            (address(fundMock), FEE_RECIPIENT, FEE_BASE_ASSET, feeConfig)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        feeManager = FeeManager(address(proxy));

        vm.warp(block.timestamp + 365 days);
    }

    /// @dev Exercises the full accrueFees path: management + performance + protocol fee.
    /// The protocol branch now staticcalls Fund -> FundManager -> deployer rather than
    /// reading a local pointer; this test captures the gas cost of that chain.
    function test_gas_accrueFees_fullPath() public {
        vm.prank(address(fundMock));
        uint256 gasBefore = gasleft();
        (address recipient, uint256 feeShares, address protocolRecipient, uint256 protocolFeeShares) =
            feeManager.accrueFees(TOTAL_SUPPLY, NEW_PRICE, 0);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("accrueFees full-path gas:", gasUsed);
        console2.log("  feeShares:", feeShares);
        console2.log("  protocolFeeShares:", protocolFeeShares);

        assertEq(recipient, FEE_RECIPIENT, "fee recipient");
        assertEq(protocolRecipient, PROTOCOL_FEE_RECIPIENT, "protocol fee recipient");
        assertGt(feeShares, 0, "fund fees accrued");
        assertGt(protocolFeeShares, 0, "protocol fees accrued");
    }

    function test_gas_accrueFees_warmSecondCall() public {
        vm.prank(address(fundMock));
        feeManager.accrueFees(TOTAL_SUPPLY, NEW_PRICE, 0);

        vm.warp(block.timestamp + 1 days);

        vm.prank(address(fundMock));
        uint256 gasBefore = gasleft();
        feeManager.accrueFees(TOTAL_SUPPLY, NEW_PRICE, 1);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("accrueFees warm second-call gas:", gasUsed);
    }
}
