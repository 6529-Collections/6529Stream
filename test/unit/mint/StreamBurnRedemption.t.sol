// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamBurnRedemption
} from "../../../smart-contracts/domains/mint/StreamBurnRedemption.sol";
import {
    IStreamBurnRedemption as R
} from "../../../smart-contracts/interfaces/stream/mint/IStreamBurnRedemption.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import { ERC721 } from "../../../smart-contracts/vendor/openzeppelin/ERC721.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract RedemptionGovernanceBoundary {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, 0, 0, 0, 0, 0);
    }
}

contract RedemptionRegistryBoundary {
    StreamModuleRecord private _record;

    function bind(StreamBurnRedemption host) external {
        (string memory uri, bytes32 hash) = host.streamModuleManifest();
        _record = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            host.streamModuleType(),
            host.streamModuleVersion(),
            type(R).interfaceId,
            500000,
            address(host).codehash,
            host.streamModuleDeploymentManifestHash(),
            hash,
            uri,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1
        );
    }

    function setStatus(ModuleRegistryStatus status) external {
        _record.status = status;
        _record.statusUpdatedAt = uint64(block.timestamp);
        ++_record.revision;
    }

    function corruptRuntime() external {
        _record.runtimeCodeHash = keccak256("wrong runtime");
    }

    function moduleRecord(address) external view returns (StreamModuleRecord memory) {
        return _record;
    }
}

/// @dev Real ERC721 approvals/burn with explicit Core identity/selection and failure boundaries.
contract RedemptionCoreBoundary is ERC721 {
    address public registry;
    bool public blocked;
    bool public corruptAfterBurn;
    bool public reentrySucceeded;
    address public reentryTarget;
    bytes public reentryData;
    mapping(uint256 => uint256) private _collection;
    mapping(uint256 => bool) private _burned;
    constructor() ERC721("Redemption boundary", "R") { }

    function mint(address recipient, uint256 tokenId, uint256 collection) external {
        _collection[tokenId] = collection;
        _mint(recipient, tokenId);
    }

    function setRegistry(address value) external {
        registry = value;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function setBlocked(bool value) external {
        blocked = value;
    }

    function setCorrupt(bool value) external {
        corruptAfterBurn = value;
    }

    function setReentry(address target, bytes calldata data) external {
        reentryTarget = target;
        reentryData = data;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (registry, registry.codehash, false, 0, 0, address(0), 0, 0, 0, 0);
    }

    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (
            _collection[tokenId] != 0,
            _collection[tokenId],
            tokenId + (corruptAfterBurn && _burned[tokenId] ? 1 : 0),
            _burned[tokenId]
        );
    }

    function burn(uint256 tokenId) external {
        require(!blocked && _isApprovedOrOwner(msg.sender, tokenId), "native burn rejected");
        _burn(tokenId);
        _burned[tokenId] = true;
        if (reentryTarget != address(0)) (reentrySucceeded,) = reentryTarget.call(reentryData);
    }
}

contract StreamBurnRedemptionTest is CharacterizationTestBase, OfficialSafeFixture {
    StreamBurnRedemption private host;
    RedemptionCoreBoundary private core;
    RedemptionRegistryBoundary private registry;
    bytes32 private sale;
    bytes32 private constant TERMS =
        keccak256("Burn one work for the editioned physical print, delivery terms v1");
    string private constant URI = "ipfs://fulfillment";
    bytes32 private constant REF =
        keccak256("Private fulfillment instructions; hash only, no address onchain");
    address private constant HOLDER = address(0xB0B);
    address private constant OPERATOR = address(0xA11CE);

    function setUp() public {
        vm.warp(1000);
        core = new RedemptionCoreBoundary();
        registry = new RedemptionRegistryBoundary();
        core.setRegistry(address(registry));
        StreamBurnRedemption.Configuration memory c;
        c.core = address(core);
        c.registry = address(registry);
        c.governance = address(new RedemptionGovernanceBoundary());
        c.operator = address(this);
        c.deploymentManifestHash = keccak256("redemption deployment");
        c.moduleManifestHash = keccak256("redemption manifest");
        c.moduleManifestURI = "ipfs://redemption-module";
        c.dependencyReadGas = G.GasParameterConfig("BURN_DEPENDENCY_READ_GAS", 150000, 100000, 2);
        c.burnGas = G.GasParameterConfig("BURN_EXECUTION_GAS", 400000, 200000, 2);
        host = new StreamBurnRedemption(c);
        registry.bind(host);
        sale = host.registerProgram(R.ProgramConfig(1, 1000, 2000, TERMS));
        core.mint(HOLDER, 1, 1);
        vm.prank(HOLDER);
        core.setApprovalForAll(address(host), true);
    }

    function testOriginalIdentityEventAndImmutableFulfillmentHistory() public {
        R.Program memory p = host.program(sale);
        require(
            p.saleNonce == 1 && p.config.termsHash == TERMS && p.registryRevision == 1,
            "original terms saved before execution"
        );
        require(
            sale
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SALE_V1"),
                        block.chainid,
                        address(host),
                        uint8(9),
                        uint256(1),
                        bytes32(0),
                        uint256(1)
                    )
                ),
            "original kind9 sale identity"
        );
        vm.recordLogs();
        vm.prank(HOLDER);
        bytes32 id = host.redeem(sale, 1, TERMS, REF, URI);
        require(
            id
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_REDEMPTION_V1"),
                        block.chainid,
                        address(host),
                        address(core),
                        uint256(1)
                    )
                ),
            "original redemption identity"
        );
        R.Redemption memory original = host.redemption(id);
        require(
            original.tokenOwner == HOLDER && original.redeemer == HOLDER
                && original.collectionId == 1 && original.collectionSerial == 1,
            "retained native identity and actor"
        );
        require(
            original.fulfillmentReferenceHash == REF && original.termsHash == TERMS,
            "redeemer bound exact original commitments"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool seen;
        bool contextSeen;
        bytes32 canonicalTopic =
            keccak256("RedemptionRecorded(uint16,bytes32,uint256,uint256,address,bytes32,string)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(host)) {
                if (logs[i].topics[0] == canonicalTopic) {
                    require(
                        logs[i].topics.length == 4 && logs[i].topics[1] == id
                            && logs[i].topics[2] == bytes32(uint256(1))
                            && logs[i].topics[3] == bytes32(uint256(1)),
                        "canonical indexed redemption facts"
                    );
                    (uint16 version, address actor, bytes32 referenceHash, string memory uri) =
                        abi.decode(logs[i].data, (uint16, address, bytes32, string));
                    require(
                        version == 1 && actor == HOLDER && referenceHash == REF
                            && keccak256(bytes(uri)) == keccak256(bytes(URI)),
                        "original canonical event data"
                    );
                    seen = true;
                } else {
                    require(
                        logs[i].topics.length == 3 && logs[i].topics[1] == id
                            && logs[i].topics[2] == sale,
                        "context joins original sale"
                    );
                    (uint16 version, R.Redemption memory eventRecord) =
                        abi.decode(logs[i].data, (uint16, R.Redemption));
                    require(
                        version == 1
                            && keccak256(abi.encode(eventRecord))
                                == keccak256(abi.encode(original)),
                        "full context equals stored record"
                    );
                    contextSeen = true;
                }
            }
        }
        require(
            seen && contextSeen && host.redemptionCount(sale) == 1
                && host.redemptionAt(sale, 0) == id,
            "durable enumeration and both events"
        );
        bytes32 first = host.recordFulfillment(id, keccak256("shipped"), URI);
        vm.warp(1001);
        bytes32 second =
            host.recordFulfillment(id, keccak256("delivered according to operator"), URI);
        require(first != second && host.fulfillmentCount(id) == 2, "two immutable updates");
        require(
            host.fulfillmentAt(id, 0).previousUpdateHash == 0
                && host.fulfillmentAt(id, 1).previousUpdateHash == first,
            "linked update order"
        );
        require(
            keccak256(abi.encode(host.redemption(id))) == keccak256(abi.encode(original)),
            "fulfillment never overwrites redemption"
        );
    }

    function testApprovedOperatorAndExecutorNeedIndependentGrants() public {
        vm.prank(HOLDER);
        core.setApprovalForAll(OPERATOR, true);
        vm.prank(OPERATOR);
        bytes32 id = host.redeem(sale, 1, TERMS, REF, URI);
        require(
            host.redemption(id).redeemer == OPERATOR && host.redemption(id).tokenOwner == HOLDER,
            "operator never impersonates holder"
        );
    }

    function testExecutorApprovalDoesNotAuthorizeUnrelatedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionAuthorityRequired.selector, uint256(1)));
        vm.prank(OPERATOR);
        host.redeem(sale, 1, TERMS, REF, URI);
        require(
            core.ownerOf(1) == HOLDER && host.redemptionCount(sale) == 0,
            "no theft through approved executor"
        );
    }

    function testHolderAuthorityDoesNotReplaceExecutorApproval() public {
        vm.prank(HOLDER);
        core.setApprovalForAll(address(host), false);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionAuthorityRequired.selector, uint256(1)));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
    }

    function testTokenSpecificApprovalAndSeparateCallerOperator() public {
        vm.prank(HOLDER);
        core.setApprovalForAll(address(host), false);
        vm.prank(HOLDER);
        core.approve(address(host), 1);
        vm.prank(HOLDER);
        core.setApprovalForAll(OPERATOR, true);
        vm.prank(OPERATOR);
        host.redeem(sale, 1, TERMS, REF, URI);
    }

    function testPreBurnedAndWrongCollectionCannotClaim() public {
        vm.prank(HOLDER);
        core.burn(1);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTokenInvalid.selector, uint256(1)));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        core.mint(HOLDER, 2, 2);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTokenInvalid.selector, uint256(2)));
        vm.prank(HOLDER);
        host.redeem(sale, 2, TERMS, REF, URI);
    }

    function testWrongTermsAndEmptyReferenceNeverBurn() public {
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTermsMismatch.selector));
        vm.prank(HOLDER);
        host.redeem(sale, 1, keccak256("other terms"), REF, URI);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTermsMismatch.selector));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, 0, URI);
        require(core.ownerOf(1) == HOLDER, "invalid consent kept token");
    }

    function testUnsafeAndOversizedURIsRejectAndHashOnlyReferenceWorks() public {
        vm.expectRevert(abi.encodeWithSelector(R.InvalidRedemptionProgram.selector));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, "javascript:alert(1)");
        vm.expectRevert(abi.encodeWithSelector(R.InvalidRedemptionProgram.selector));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, string(new bytes(2049)));
        vm.prank(HOLDER);
        bytes32 id = host.redeem(sale, 1, TERMS, REF, "");
        require(
            bytes(host.redemption(id).fulfillmentURI).length == 0,
            "private commitment without public URI"
        );
        vm.expectRevert(abi.encodeWithSelector(R.InvalidRedemptionProgram.selector));
        host.recordFulfillment(id, REF, "https://unsafe\nvalue");
        require(host.fulfillmentCount(id) == 0, "invalid update did not append");
    }

    function testExpiredWindowAndUnauthorizedProgramDoNotConsumeNonce() public {
        vm.expectRevert();
        vm.prank(HOLDER);
        host.registerProgram(R.ProgramConfig(1, 1000, 2000, TERMS));
        require(host.nextSaleNonce() == 2, "unauthorized configuration has no nonce effect");
        vm.warp(2001);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionProgramClosed.selector, sale));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        require(core.ownerOf(1) == HOLDER, "expired program preserves token");
    }

    function testNativeBurnBlockRollsBackRecordAndExactRetryWorks() public {
        core.setBlocked(true);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionBurnFailed.selector, uint256(1)));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        require(
            host.redemptionCount(sale) == 0 && core.ownerOf(1) == HOLDER,
            "failed native burn atomic"
        );
        core.setBlocked(false);
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        require(host.redemptionCount(sale) == 1, "identical retry");
    }

    function testPostBurnIdentityFailureRollsBackTokenAndRecord() public {
        core.setCorrupt(true);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTokenInvalid.selector, uint256(1)));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        require(
            core.ownerOf(1) == HOLDER && host.redemptionCount(sale) == 0,
            "post-call rejection restores native ownership"
        );
        core.setCorrupt(false);
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
    }

    function testDeprecatedServesOldProgramAndIncidentStopsWritesButNotHistory() public {
        vm.warp(1001);
        registry.setStatus(ModuleRegistryStatus.DEPRECATED);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionModuleNotAdmitted.selector));
        host.registerProgram(R.ProgramConfig(1, 1001, 2000, TERMS));
        vm.prank(HOLDER);
        bytes32 id = host.redeem(sale, 1, TERMS, REF, URI);
        host.recordFulfillment(id, REF, URI);
        registry.setStatus(ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionModuleNotAdmitted.selector));
        host.recordFulfillment(id, keccak256("later"), URI);
        require(
            host.redemption(id).redeemer == HOLDER && host.fulfillmentCount(id) == 1,
            "retired original records remain readable"
        );
    }

    function testRegistryDriftAndRegisteredRuntimeMismatchFailClosed() public {
        core.setRegistry(address(new RedemptionRegistryBoundary()));
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionModuleNotAdmitted.selector));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        core.setRegistry(address(registry));
        registry.corruptRuntime();
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionModuleNotAdmitted.selector));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
    }

    function testWindowCancellationAndUnauthorizedFulfillment() public {
        bytes32 future = host.registerProgram(R.ProgramConfig(1, 1010, 1020, TERMS));
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionProgramClosed.selector, future));
        vm.prank(HOLDER);
        host.redeem(future, 1, TERMS, REF, URI);
        vm.warp(1020);
        vm.prank(HOLDER);
        bytes32 id = host.redeem(future, 1, TERMS, REF, URI);
        vm.expectRevert();
        vm.prank(HOLDER);
        host.recordFulfillment(id, REF, URI);
        host.cancelProgram(future);
        host.recordFulfillment(id, REF, URI);
        require(
            host.program(future).cancelled && host.fulfillmentCount(id) == 1,
            "cancelled sale still permits existing fulfillment"
        );
        core.mint(HOLDER, 2, 1);
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionProgramClosed.selector, future));
        vm.prank(HOLDER);
        host.redeem(future, 2, TERMS, REF, URI);
    }

    function testCallbackCannotReenterAndNoDuplicateBurnCredit() public {
        core.setReentry(address(host), abi.encodeCall(host.redeem, (sale, 1, TERMS, REF, URI)));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
        require(
            !core.reentrySucceeded() && host.redemptionCount(sale) == 1,
            "guard rejects callback reentry"
        );
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTokenInvalid.selector, uint256(1)));
        vm.prank(HOLDER);
        host.redeem(sale, 1, TERMS, REF, URI);
    }

    function testSafeHolderAndOperatorAllMutatingCalls() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xA11CE;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 991);
        host.transferOwnership(address(safe));
        bytes32 safeSale = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(host),
                uint8(9),
                uint256(1),
                bytes32(0),
                uint256(2)
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                address(host),
                0,
                abi.encodeCall(host.registerProgram, (R.ProgramConfig(1, 1000, 2000, TERMS))),
                0
            ),
            "Safe configures terms"
        );
        core.mint(address(safe), 2, 1);
        require(
            executeSafe(
                safe,
                keys,
                address(core),
                0,
                abi.encodeCall(core.setApprovalForAll, (address(host), true)),
                0
            ),
            "Safe approves burn executor"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(host),
                0,
                abi.encodeCall(host.redeem, (safeSale, 2, TERMS, REF, URI)),
                0
            ),
            "Safe redeems"
        );
        bytes32 id = host.redemptionIdFor(2);
        require(host.redemption(id).redeemer == address(safe), "Safe itself is recorded actor");
        require(
            executeSafe(
                safe,
                keys,
                address(host),
                0,
                abi.encodeCall(host.recordFulfillment, (id, REF, URI)),
                0
            ),
            "Safe records fulfillment"
        );
        require(
            executeSafe(
                safe, keys, address(host), 0, abi.encodeCall(host.cancelProgram, (safeSale)), 0
            ),
            "Safe cancels program"
        );
    }

    function testFuzzOneNativeBurnHasOneImmutableRedemption(uint64 seed, bytes32 referenceHash)
        public
    {
        uint256 token = uint256(seed) + 2;
        if (referenceHash == 0) referenceHash = REF;
        core.mint(HOLDER, token, 1);
        vm.prank(HOLDER);
        bytes32 id = host.redeem(sale, token, TERMS, referenceHash, URI);
        require(
            host.redemption(id).fulfillmentReferenceHash == referenceHash
                && host.redemptionCount(sale) == 1,
            "exact single record"
        );
        vm.expectRevert(abi.encodeWithSelector(R.RedemptionTokenInvalid.selector, token));
        vm.prank(HOLDER);
        host.redeem(sale, token, TERMS, referenceHash, URI);
    }
}
