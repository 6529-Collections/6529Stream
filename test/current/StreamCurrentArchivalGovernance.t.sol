// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import {
    StreamArchivalTypes as Arch
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @notice Archival administration through current Core/Registry/Executor and an official 2-of-3 Safe.
/// @dev This suite does not claim estate admission, network evidence or cold signature-gas acceptance.
contract StreamCurrentArchivalGovernanceTest is StreamCurrentSafeGovernanceFixture {
    StreamArchivalCoverage private coverageHost;
    StreamArweaveCheckpointVerifier private checkpointHost;
    uint256 private constant GOVERNOR_ONE = 0xA2C001;
    uint256 private constant GOVERNOR_TWO = 0xA2C002;
    uint256 private constant GOVERNOR_THREE = 0xA2C003;
    bytes32 private constant SIGNATURE_GAS =
        keccak256("6529STREAM_GGP_ARCHIVAL_ERC1271_VERIFY_GAS");
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_ARCHIVAL_DEPENDENCY_READ_GAS");
    bytes32 private constant GAS_SCOPE =
        0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71;
    bytes32 private constant GAS_STATE =
        0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;

    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        uint256[] memory owners = new uint256[](3);
        owners[0] = GOVERNOR_ONE;
        owners[1] = GOVERNOR_TWO;
        owners[2] = GOVERNOR_THREE;
        uint256[] memory signers = new uint256[](2);
        signers[0] = GOVERNOR_ONE;
        signers[1] = GOVERNOR_THREE;
        OfficialSafe safe = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 0xA2C0
        );
        _installGovernorSafe(safe, signers);
        require(safe.getOwners().length == 3 && safe.getThreshold() == 2, "actual 2-of-3 Safe");

        Arch.Observer[] memory observers = new Arch.Observer[](2);
        observers[0] = Arch.Observer(vm.addr(0xA2C011), keccak256("observer organization one"));
        observers[1] = Arch.Observer(vm.addr(0xA2C012), keccak256("observer organization two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        IStreamGasParameterHost.GasParameterConfig memory signatureGas =
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            );
        checkpointHost =
            new StreamArweaveCheckpointVerifier(address(executor), observers, 2, signatureGas);
        coverageHost = new StreamArchivalCoverage(
            address(core),
            address(executor),
            address(roles),
            address(checkpointHost),
            signatureGas,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
        require(address(coverageHost).code.length <= 24576, "coverage deployable");
        require(address(checkpointHost).code.length <= 24576, "checkpoint deployable");
        _admitGovernanceSelectors();
    }

    function testCurrentTwoOfThreeSafeAdmitsBothFamilyKindsAndChangesStatus() public {
        bytes32 first = _admitFamily("endowed-network", 1);
        bytes32 second = _admitFamily("independent-storage", 2);
        require(first != second, "separate family records");
        _setFamilyStatus(first, 2, 1, 2);
        _setFamilyStatus(first, 3, 2, 3);
        _setFamilyStatus(first, 1, 3, 4);
        (Arch.Family memory retained, uint8 status) = coverageHost.family(first);
        require(status == 1 && retained.economics == 1, "restored endowed row remains immutable");
        require(
            coverageHost.familyRevision(first) == 4, "status round trip cannot replay revision one"
        );
        (, uint8 other) = coverageHost.family(second);
        require(other == 1 && coverageHost.familyRevision(second) == 1, "independent row unchanged");
    }

    function testCurrentSafeRaisesEachArchivalBudgetWithExactPerCallContext() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _gasBatch();
        (bytes32 id, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceBatch, (id, calls, data))
        );
        _assertInitialGas();
        vm.warp(ready);
        vm.recordLogs();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceBatch, (id, calls, data))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertGas(checkpointHost, SIGNATURE_GAS, 600000, 90000, 2);
        _assertGas(coverageHost, SIGNATURE_GAS, 600000, 90000, 2);
        _assertGas(coverageHost, READ_GAS, 200000, 50000, 2);
        _assertGasEvent(logs, address(checkpointHost), SIGNATURE_GAS, id, 400000, 600000, 90000);
        _assertGasEvent(logs, address(coverageHost), SIGNATURE_GAS, id, 400000, 600000, 90000);
        _assertGasEvent(logs, address(coverageHost), READ_GAS, id, 150000, 200000, 50000);
        require(
            executor.governanceAction(id).executor == address(governorSafe),
            "Safe executes real batch"
        );
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceBatch, (id, calls, data))
        );
        _assertGas(coverageHost, READ_GAS, 200000, 50000, 2);
    }

    function testCurrentStaleSecondGasContextRollsBackTheFirstRaise() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _gasBatch();
        calls[1].oldValueHash = keccak256("stale archival signature budget");
        (bytes32 rejected, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.warp(ready);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (rejected, calls, data))
        );
        _assertInitialGas();
        require(
            executor.governanceAction(rejected).status == GovernanceActionStatus.SCHEDULED,
            "failed action not consumed"
        );
        // A new exact commitment succeeds after the failed batch rolled back every host.
        (calls, data) = _gasBatch();
        (bytes32 accepted, uint64 nextReady) = _scheduleBatchAsGovernor(1, calls, data);
        vm.warp(nextReady);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (accepted, calls, data))
        );
        _assertGas(checkpointHost, SIGNATURE_GAS, 600000, 90000, 2);
        _assertGas(coverageHost, READ_GAS, 200000, 50000, 2);
    }

    function testCurrentArchivalDirectSafeAndOwnerCallsCannotBypassGovernanceOrThreshold() public {
        Arch.Family memory family_ = _family("independent-storage", 2);
        bytes memory admission =
            abi.encodeCall(coverageHost.admitFamily, ("independent-storage", family_));
        bytes memory raise_ = abi.encodeCall(coverageHost.raiseGasParameter, (READ_GAS, 200000));
        vm.expectRevert(bytes("GS013"));
        this.executeCurrentGovernorCall(address(coverageHost), admission);
        vm.expectRevert(bytes("GS013"));
        this.executeCurrentGovernorCall(address(coverageHost), raise_);
        address owner = vm.addr(GOVERNOR_ONE);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Arch.ArchivalUnauthorized.selector, owner));
        coverageHost.admitFamily("independent-storage", family_);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterNotAuthority.selector, owner)
        );
        coverageHost.raiseGasParameter(READ_GAS, 200000);

        (GovernanceCall memory call_, bytes memory data) = _gasCall(coverageHost, READ_GAS, 200000);
        GovernanceActionRequest memory request = _governanceRequest(
            1, call_.target, data, call_.scopeHash, call_.oldValueHash, call_.newValueHash
        );
        vm.prank(owner);
        vm.expectRevert();
        executor.scheduleGovernanceAction(request);
        uint256 safeNonce = governorSafe.nonce();
        vm.expectRevert(bytes("GS020"));
        this.executeOneSigner(abi.encodeCall(executor.scheduleGovernanceAction, (request)));
        require(governorSafe.nonce() == safeNonce, "one signature cannot consume Safe nonce");
        _assertInitialGas();
        bytes32 id = _govern(request);
        require(
            executor.governanceAction(id).proposer == address(governorSafe),
            "two of three can propose"
        );
        _assertGas(coverageHost, READ_GAS, 200000, 50000, 2);
    }

    function testCurrentArchivalSafePublicEnvelopeAndConfigurationReads() public {
        bytes memory payload = bytes("Public archival governance integration evidence");
        Arch.Envelope memory envelope_ = Arch.Envelope(
            fixtureArtistId,
            keccak256(payload),
            keccak256("6529STREAM_PUBLIC_ESTATE_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            bytes32(0)
        );
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_ENVELOPE_V1"),
                block.chainid,
                address(coverageHost),
                envelope_
            )
        );
        this.executeCurrentGovernorCall(
            address(coverageHost), abi.encodeCall(coverageHost.recordEnvelope, (envelope_, payload))
        );
        _safeRead(
            address(coverageHost),
            abi.encodeCall(coverageHost.envelope, (hash)),
            abi.encode(envelope_, payload)
        );
        _safeRead(
            address(coverageHost),
            abi.encodeCall(IStreamArchivalCoverage.core, ()),
            abi.encode(address(core))
        );
        _safeRead(
            address(coverageHost),
            abi.encodeCall(IStreamArchivalCoverage.roleRegistry, ()),
            abi.encode(address(roles))
        );
        _safeRead(
            address(coverageHost),
            abi.encodeCall(IStreamArchivalCoverage.checkpointVerifier, ()),
            abi.encode(address(checkpointHost))
        );
        _safeRead(
            address(checkpointHost),
            abi.encodeCall(IStreamArchivalCheckpointVerifier.quorum, ()),
            abi.encode(uint8(2))
        );
        _safeRead(
            address(checkpointHost),
            abi.encodeCall(IStreamArchivalCheckpointVerifier.networkId, ()),
            abi.encode(keccak256("ARWEAVE_MAINNET"))
        );
        _safeGasReads(checkpointHost, false);
        _safeGasReads(coverageHost, true);
        _safeRead(
            address(coverageHost),
            abi.encodeCall(
                coverageHost.supportsInterface, (type(IStreamArchivalCoverage).interfaceId)
            ),
            abi.encode(true)
        );
        _safeRead(
            address(checkpointHost),
            abi.encodeCall(
                checkpointHost.supportsInterface,
                (type(IStreamArchivalCheckpointVerifier).interfaceId)
            ),
            abi.encode(true)
        );
    }

    function executeOneSigner(bytes calldata data) external {
        require(msg.sender == address(this), "test only");
        uint256[] memory signer = new uint256[](1);
        signer[0] = GOVERNOR_ONE;
        require(
            executeSafe(governorSafe, signer, address(executor), 0, data, 0),
            "one signer cannot execute"
        );
    }

    function _family(string memory name, uint8 economics)
        private
        view
        returns (Arch.Family memory)
    {
        return Arch.Family(
            keccak256(bytes(name)),
            economics == 1
                ? keccak256("ARWEAVE_MAINNET")
                : keccak256("independent content-addressed network"),
            keccak256(abi.encode(name, "protocol")),
            keccak256(abi.encode(name, "addressing")),
            keccak256(abi.encode(name, "custodian")),
            keccak256(abi.encode(name, "funding")),
            keccak256(abi.encode(name, "retrieval")),
            keccak256(abi.encode(name, "jurisdiction")),
            economics,
            address(governorSafe),
            economics == 1
                ? keccak256("6529STREAM_ARWEAVE_SINGLE_CHUNK_QUORUM_V1")
                : keccak256("6529STREAM_RAW_CID_SHA256_POSSESSION_V1")
        );
    }

    function _admitFamily(string memory name, uint8 economics) private returns (bytes32 hash) {
        Arch.Family memory f = _family(name, economics);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FAMILY_V1"), block.chainid, address(coverageHost), f
            )
        );
        (bytes32 actual, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            coverageHost.familyRegistrationContext(name, f);
        require(
            actual == hash && scope == _familyScope(hash), "independent family and scope preimages"
        );
        require(
            oldHash == _familyState(hash, 0, 0) && newHash == _familyState(hash, 1, 1),
            "independent family state preimages"
        );
        bytes memory data = abi.encodeCall(coverageHost.admitFamily, (name, f));
        bytes32 id =
            _govern(_governanceRequest(1, address(coverageHost), data, scope, oldHash, newHash));
        (Arch.Family memory stored, uint8 status) = coverageHost.family(hash);
        require(
            keccak256(abi.encode(stored)) == keccak256(abi.encode(f)) && status == 1,
            "exact family admitted"
        );
        require(coverageHost.familyRevision(hash) == 1, "first family revision");
        require(
            executor.governanceAction(id).executor == address(governorSafe),
            "Safe executes admission"
        );
    }

    function _setFamilyStatus(bytes32 hash, uint8 next, uint8 prior, uint64 revision) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            coverageHost.familyStatusContext(hash, next);
        require(scope == _familyScope(hash), "status scope");
        require(
            oldHash == _familyState(hash, prior, revision - 1)
                && newHash == _familyState(hash, next, revision),
            "revision-bound status context"
        );
        bytes memory data = abi.encodeCall(coverageHost.setFamilyStatus, (hash, next));
        bytes32 id = _scheduleAsGovernor(
            _governanceRequest(1, address(coverageHost), data, scope, oldHash, newHash)
        );
        vm.warp(executor.governanceAction(id).notBefore);
        vm.recordLogs();
        _executeAsGovernor(id, data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic =
            keccak256("ArchivalFamilyStatusChanged(uint16,bytes32,bytes32,uint8,uint8,uint64)");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(coverageHost) || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == hash && logs[i].topics[2] == id,
                "status event identity"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), prior, next, revision)),
                "exact status event"
            );
            ++count;
        }
        require(
            count == 1 && coverageHost.familyRevision(hash) == revision, "single revision event"
        );
    }

    function _familyScope(bytes32 hash) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FAMILY_SCOPE_V1"),
                block.chainid,
                address(coverageHost),
                hash
            )
        );
    }

    function _familyState(bytes32 hash, uint8 status, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FAMILY_STATE_V1"),
                block.chainid,
                address(coverageHost),
                hash,
                status,
                revision
            )
        );
    }

    function _gasCall(IStreamGasParameterHost host, bytes32 parameter, uint256 next)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            host.gasParameterInfo(parameter);
        bytes32 scope = keccak256(abi.encode(GAS_SCOPE, block.chainid, address(host), parameter));
        data = abi.encodeCall(host.raiseGasParameter, (parameter, next));
        call_ = StreamCurrentStackPlan.call(
            address(host),
            data,
            scope,
            keccak256(abi.encode(GAS_STATE, scope, value, floor, failure, revision)),
            keccak256(abi.encode(GAS_STATE, scope, next, floor, failure, revision + 1))
        );
    }

    function _gasBatch() private view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        calls = new GovernanceCall[](3);
        data = new bytes[](3);
        (calls[0], data[0]) = _gasCall(checkpointHost, SIGNATURE_GAS, 600000);
        (calls[1], data[1]) = _gasCall(coverageHost, SIGNATURE_GAS, 600000);
        (calls[2], data[2]) = _gasCall(coverageHost, READ_GAS, 200000);
    }

    function _assertInitialGas() private view {
        _assertGas(checkpointHost, SIGNATURE_GAS, 400000, 90000, 1);
        _assertGas(coverageHost, SIGNATURE_GAS, 400000, 90000, 1);
        _assertGas(coverageHost, READ_GAS, 150000, 50000, 1);
    }

    function _assertGas(
        IStreamGasParameterHost host,
        bytes32 parameter,
        uint256 expected,
        uint256 floor,
        uint64 revision
    ) private view {
        (uint256 actual, uint256 actualFloor, uint8 failure, uint64 actualRevision) =
            host.gasParameterInfo(parameter);
        require(
            actual == expected && actualFloor == floor && failure == 2
                && actualRevision == revision,
            "exact archival gas facts"
        );
    }

    function _assertGasEvent(
        Vm.Log[] memory logs,
        address host,
        bytes32 parameter,
        bytes32 action,
        uint256 oldValue,
        uint256 newValue,
        uint256 floor
    ) private pure {
        bytes32 topic = keccak256(
            "GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != host || logs[i].topics[0] != topic
                    || logs[i].topics[1] != parameter
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[2] == bytes32(uint256(uint160(host)))
                    && logs[i].topics[3] == action,
                "gas event context"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(abi.encode(uint16(2), oldValue, newValue, floor)),
                "exact gas event"
            );
            ++count;
        }
        require(count == 1, "one host parameter event");
    }

    function _safeRead(address host, bytes memory data, bytes memory expected) private {
        vm.prank(address(governorSafe));
        (bool ok, bytes memory observed) = host.staticcall(data);
        require(ok && keccak256(observed) == keccak256(expected), "exact Safe-context result");
        this.executeCurrentGovernorCall(host, data);
    }

    function _safeGasReads(IStreamGasParameterHost host, bool withReadBudget) private {
        _safeRead(
            address(host),
            abi.encodeCall(host.governanceAuthority, ()),
            abi.encode(address(executor))
        );
        bytes32[] memory ids = new bytes32[](withReadBudget ? 2 : 1);
        ids[0] = SIGNATURE_GAS;
        if (withReadBudget) ids[1] = READ_GAS;
        _safeRead(address(host), abi.encodeCall(host.gasParameterIds, ()), abi.encode(ids));
        _safeRead(
            address(host),
            abi.encodeCall(host.gasParameter, (SIGNATURE_GAS)),
            abi.encode(uint256(400000))
        );
        _safeRead(
            address(host),
            abi.encodeCall(host.gasParameterInfo, (SIGNATURE_GAS)),
            abi.encode(uint256(400000), uint256(90000), uint8(2), uint64(1))
        );
    }

    function _admitGovernanceSelectors() private {
        uint256 initialPublicationCount = manifest.streamSystemManifestPointerCount();
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](4);
        additions[0] = _policy(address(coverageHost), coverageHost.admitFamily.selector);
        additions[1] = _policy(address(coverageHost), coverageHost.setFamilyStatus.selector);
        additions[2] = _policy(address(coverageHost), coverageHost.raiseGasParameter.selector);
        additions[3] = _policy(address(checkpointHost), checkpointHost.raiseGasParameter.selector);
        for (uint256 i = 1; i < additions.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _policyHash(additions[j - 1]) > _policyHash(additions[j]);
                --j
            ) {
                (additions[j - 1], additions[j]) = (additions[j], additions[j - 1]);
            }
        }
        (bytes32 candidate, bytes32 oldCatalog, uint256 count, uint64 revision) =
            executor.governanceActionPolicyState();
        (bytes32 nextCatalog, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(executor), candidate, oldCatalog, count, revision, additions
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(
            executor.extendGovernanceActionPolicy, (revision, oldCatalog, nextCatalog, additions)
        );
        calls[0] = StreamCurrentStackPlan.call(address(executor), data[0], scope, oldHash, newHash);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 payloadHash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                "{\"version\":2,\"catalog\":\"",
                Strings.toHexString(uint256(nextCatalog), 32),
                "\"}"
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            payloadHash,
            "urn:6529stream:current-stack:archival-governance",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
        (bytes32 id, uint64 ready) = _scheduleBatchAsGovernor(3, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceBatch, (id, calls, data))
        );
        (, bytes32 actual, uint256 actualCount, uint64 actualRevision) =
            executor.governanceActionPolicyState();
        require(
            actual == nextCatalog && actualCount == count + 4 && actualRevision == revision + 1,
            "four exact archival selectors admitted"
        );
        require(
            manifest.streamSystemManifestPointerCount() == initialPublicationCount + 1,
            "actual manifest accompanies catalog extension"
        );
    }

    function _policy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _policyHash(GovernanceActionPolicyEntry memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(p.actionClass, p.target, p.selector));
    }
}
