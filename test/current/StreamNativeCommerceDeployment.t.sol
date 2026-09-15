// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeEnglishAuctionFixture.sol";
import "../../script/current/StreamNativeCommerceDeployment.sol";
import "../../smart-contracts/integrations/delegation/NFTdelegation.sol";

/// @notice Actual current Core/Manager/Registry/recorder/house, with typed governance and Artist boundaries.
/// @dev Tests the additive deployment and admission route; does not attest the full operator graph.
interface NativeCommerceTestVm {
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
    function assume(bool condition) external;
    function etch(address target, bytes calldata code) external;
}

contract StreamNativeCommerceDeploymentTest is NativeEnglishAuctionFixture {
    NativeCommerceTestVm private constant commerceVm =
        NativeCommerceTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function _bindPreparedRecorder() internal override { }

    function _configuration()
        private
        returns (StreamNativeEnglishAuction.DeploymentConfig memory c)
    {
        c.manager = manager;
        c.platform = vm.addr(AUCTION_PLATFORM_KEY);
        c.artists = artists;
        c.entropy = entropy;
        c.roles = auctionRoles;
        c.authority = address(revenueAuthority);
        c.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        c.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2
        );
        c.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        c.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
        );
    }

    function _deploy() private returns (StreamNativeCommerceDeployment.Products memory) {
        return StreamNativeCommerceDeployment.deploy(
            resolver, registry, escrow, _configuration(), MANIFEST, MANIFEST
        );
    }

    function validateSaved(StreamNativeCommerceDeployment.Products calldata p) external view {
        StreamNativeCommerceDeployment.validate(p);
    }

    function binding(StreamNativeCommerceDeployment.Products calldata p)
        external
        view
        returns (address, bytes memory)
    {
        return StreamNativeCommerceDeployment.managerBinding(p);
    }

    function _execute(GenesisBatch memory batch, uint256 count) private {
        require(batch.actionClass == 1 && count <= batch.calls.length, "exact admission class");
        for (uint256 i; i < count; ++i) {
            GovernanceCall memory call_ = batch.calls[i];
            require(
                call_.value == 0 && keccak256(batch.callDatas[i]) == call_.callDataHash,
                "exact value and data"
            );
            _context(call_.scopeHash, call_.oldValueHash, call_.newValueHash, 1);
            vm.prank(address(revenueAuthority));
            (bool ok, bytes memory reason) = call_.target.call(batch.callDatas[i]);
            if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
            _clearContext();
        }
    }

    function deployAnother() external returns (StreamNativeCommerceDeployment.Products memory) {
        return _deploy();
    }

    function testAlreadyBoundManagerRejectsFreshDeployment() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment.selector
        );
        this.deployAnother();
    }

    function testDependencyRuntimeDriftRejectsPlanning() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        commerceVm.etch(address(entropy), hex"60006000fd");
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.NativeCommerceRuntimeChanged.selector
        );
        this.validateSaved(p);
    }

    function testDelegationUsesActualHouseDeclarationManifest() public {
        StreamNativeEnglishAuction.DeploymentConfig memory c = _configuration();
        c.delegateRegistry = address(new DelegationManagementContract());
        c.delegationUsecase = 2;
        c.baseModuleManifestHash = MANIFEST;
        c.delegationGas = IStreamGasParameterHost.GasParameterConfig(
            "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
        );
        StreamNativeCommerceDeployment.Products memory p = StreamNativeCommerceDeployment.deploy(
            resolver, registry, escrow, c, MANIFEST, MANIFEST
        );
        StreamModuleRegistration[] memory rows = StreamNativeCommerceDeployment.registrations(p);
        require(rows[0].moduleManifestHash == MANIFEST, "recorder original module manifest");
        require(
            rows[1].moduleManifestHash == keccak256(p.house.delegationManifest())
                && rows[1].moduleManifestHash != MANIFEST,
            "address-bound house declaration"
        );
        _execute(StreamNativeCommerceDeployment.admission(p), 3);
        require(
            registry.moduleRecord(address(p.house)).moduleManifestHash == p.houseModuleManifestHash,
            "actual registry retains delegation commitment"
        );
        p.houseModuleManifestHash = MANIFEST;
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment.selector
        );
        this.validateSaved(p);
    }

    function testDeploysExactPairWithoutGrantingPermissions() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        require(p.house.primarySaleSettlement() == address(p.recorder), "exact official recorder");
        require(
            address(p.house.mintManager()) == address(manager) && p.house.core() == address(core),
            "original graph"
        );
        require(
            uint8(registry.moduleRecord(address(p.recorder)).status) == 0,
            "recorder not auto-admitted"
        );
        require(
            uint8(registry.moduleRecord(address(p.house)).status) == 0, "house not auto-admitted"
        );
        (bool enabled,,) = escrow.creditProducer(address(p.recorder));
        (address bound,,,) = manager.preparedNativeRecorder();
        require(!enabled && bound == address(0), "activation separate");
    }

    function testActualAdmissionThenOwnerBinding() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        GenesisBatch memory batch = StreamNativeCommerceDeployment.admission(p);
        _execute(batch, 3);
        (address target, bytes memory data) = StreamNativeCommerceDeployment.managerBinding(p);
        require(target == address(manager), "original Manager target");
        (bool ok,) = target.call(data);
        require(ok, "actual owner binding");
        (address bound, bytes32 hash,, uint64 revision) = manager.preparedNativeRecorder();
        require(
            bound == address(p.recorder) && hash == p.recorderCodeHash && revision == 1,
            "exact saved pins"
        );
        require(
            registry.moduleRecord(address(p.house)).runtimeCodeHash == p.houseCodeHash,
            "actual house admission"
        );
    }

    function testCannotPrepareBindingBeforeAdmission() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment.selector
        );
        this.binding(p);
    }

    function testCannotPrepareBindingWithoutEscrowAdmission() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        _execute(StreamNativeCommerceDeployment.admission(p), 2);
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment.selector
        );
        this.binding(p);
    }

    function testCannotReplaceBoundRecorder() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        _execute(StreamNativeCommerceDeployment.admission(p), 3);
        manager.bindPreparedNativeRecorder(address(p.recorder));
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment.selector
        );
        this.binding(p);
    }

    function testWrongChainAndWrongPairAreRejected() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        p.chainId += 1;
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.NativeCommerceRuntimeChanged.selector
        );
        this.validateSaved(p);
        p.chainId = block.chainid;
        p.recorder = recorder;
        p.recorderCodeHash = address(recorder).codehash;
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment.selector
        );
        this.validateSaved(p);
    }

    function testFuzzSavedRuntimePinCannotChange(bytes32 mask) public {
        commerceVm.assume(mask != bytes32(0));
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        p.houseCodeHash ^= mask;
        commerceVm.expectRevert(
            StreamNativeCommerceDeployment.NativeCommerceRuntimeChanged.selector
        );
        this.validateSaved(p);
    }

    function testPoliciesAreExactSortedClassOneZeroValue() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        GovernanceActionPolicyEntry[] memory rows = StreamNativeCommerceDeployment.policies(p);
        require(rows.length == 4, "exact policy count");
        bytes32 previous;
        for (uint256 i; i < rows.length; ++i) {
            GovernanceActionPolicyEntry memory row = rows[i];
            bytes32 key = keccak256(abi.encode(row.actionClass, row.target, row.selector));
            require(i == 0 || key > previous, "sorted exact policy keys");
            require(
                row.actionClass == 1 && row.targetCodeHash == row.target.codehash,
                "class and runtime pin"
            );
            require(
                row.callType == 1 && row.valuePolicy == 0 && row.valueLimit == 0,
                "no native value permission"
            );
            previous = key;
        }
    }

    function testSafeOwnerIdenticalSignedBindingRetriesAfterAdmission() public {
        StreamNativeCommerceDeployment.Products memory p = _deploy();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529061;
        keys[1] = 0x6529062;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 881);
        manager.transferOwnership(address(account));
        bytes memory data = abi.encodeCall(
            IStreamPreparedNativeMint.bindPreparedNativeRecorder, (address(p.recorder))
        );
        bytes32 digest = account.getTransactionHash(
            address(manager), 0, data, 0, 0, 0, 0, address(0), address(0), 0
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        commerceVm.expectRevert(bytes("GS013"));
        account.execTransaction(
            address(manager), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == 0, "failed Safe nonce retained");
        _execute(StreamNativeCommerceDeployment.admission(p), 3);
        require(
            account.execTransaction(
                address(manager), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            ),
            "identical signed retry"
        );
        (address bound,,,) = manager.preparedNativeRecorder();
        require(bound == address(p.recorder) && account.nonce() == 1, "exact Safe binding");
    }
}
