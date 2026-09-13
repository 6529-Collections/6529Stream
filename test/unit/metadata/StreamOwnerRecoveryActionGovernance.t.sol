// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerRecoveryActionReads.t.sol";
import "../../helpers/StreamGovernanceBootstrapHarness.sol";

/// @dev Explicit recovery-intent/owner/Core boundaries around the actual sealed Executor.
contract OwnerActionGovernanceTarget {
    address public immutable core;
    address public immutable governanceAuthority;
    address public immutable ownerEvidence;
    StreamFinalityRecoveryRequest private request;
    bool public callbackAccepted;
    bool public failAfterCallback;

    constructor(address c, address e, address owner) {
        core = c;
        governanceAuthority = e;
        ownerEvidence = owner;
    }

    function prepare(StreamFinalityRecoveryRequest memory r) external {
        request = r;
    }

    function fail(bool value) external {
        failAfterCallback = value;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return 0x83685f5c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == 0x83685f5c;
    }

    function noise() external view {
        require(msg.sender == governanceAuthority, "executor noise");
    }

    function requireArtistRecoveryIntent(
        StreamFinalityScope calldata scope,
        bytes32 original,
        bytes32 manifest
    ) external view returns (IStreamArtistRecoveryIntent.Facts memory) {
        require(
            keccak256(abi.encode(scope)) == keccak256(abi.encode(request.scope))
                && original == request.expectedOriginalFinalityRecordHash
                && manifest == request.recoveryManifest.contentHash,
            "fixture exact original request"
        );
        return facts();
    }

    function facts() public view returns (IStreamArtistRecoveryIntent.Facts memory) {
        return IStreamArtistRecoveryIntent.Facts(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_RECOVERY_SCOPE_V1"),
                    block.chainid,
                    address(this),
                    request.scope
                )
            ),
            keccak256("fixture old"),
            keccak256("fixture new"),
            keccak256(abi.encode(request))
        );
    }

    function executeFinalityRecovery(StreamFinalityRecoveryRequest memory r) external {
        require(
            msg.sender == governanceAuthority
                && keccak256(abi.encode(r)) == keccak256(abi.encode(request)),
            "exact execution"
        );
        (, bytes32 id,,,,) = IStreamGovernanceExecutor(governanceAuthority).currentAction();
        require(
            IStreamGovernanceActionFacts(governanceAuthority).governanceActionFacts(id).status
                == GovernanceActionStatus.EXECUTED,
            "actual stored executed before callback"
        );
        callbackAccepted = OwnerActionReadHost(ownerEvidence)
            .eligible(id, r.scope, r.recoveryManifest.contentHash);
        require(callbackAccepted, "actual active callback admitted");
        require(!failAfterCallback, "intentional later effect failure");
    }
}

/// @notice Actual Executor/RoleRegistry/SSTORE2 publication and action policy; explicit bootstrap
/// Core/manifest/guardian actor, recovery-intent and owner host fixtures. No current Core proof.
contract StreamOwnerRecoveryActionGovernanceTest is StreamGovernanceBootstrapHarness {
    BootstrapArtifacts private deployed;
    OwnerActionReadHost private host;
    OwnerActionGovernanceTarget private target;
    StreamFinalityRecoveryRequest private request;

    function _additionalActionPolicies(BootstrapArtifacts memory a)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory entries)
    {
        host = new OwnerActionReadHost(address(a.core), address(a.executor));
        target =
            new OwnerActionGovernanceTarget(address(a.core), address(a.executor), address(host));
        entries = new GovernanceActionPolicyEntry[](2);
        entries[0] = _zeroPolicy(
            2,
            address(target),
            IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector,
            keccak256("fixture recovery profile")
        );
        entries[1] = _zeroPolicy(
            2, address(target), target.noise.selector, keccak256("fixture recovery profile")
        );
    }

    function setUp() public {
        vm.warp(1000000);
        deployed = _deploySealedExecutor(address(this));
        deployed.core
            .setPointer(
                keccak256("ARTWORK_FINALITY_RECOVERY"),
                address(target),
                false,
                keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
                0x83685f5c,
                address(deployed.registry),
                keccak256("module"),
                deployed.manifestHash
            );
        request.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 42, 0);
        request.expectedOriginalFinalityRecordHash = keccak256("fixture original");
        request.expectedOldRouteHash = keccak256("fixture old route");
        request.recoveryManifest = StreamFinalityManifestRef(
            "urn:fixture:manifest",
            keccak256("urn:fixture:manifest"),
            keccak256("fixture staged manifest"),
            keccak256("schema"),
            keccak256("canon")
        );
        request.reasonHash = keccak256("reason");
        request.reasonURI = "urn:fixture:reason";
        target.prepare(request);
    }

    function _schedule()
        private
        returns (bytes32 id, uint64 ready, GovernanceCall[] memory calls, bytes[] memory data)
    {
        calls = new GovernanceCall[](3);
        data = new bytes[](3);
        IStreamArtistRecoveryIntent.Facts memory f = target.facts();
        data[0] = abi.encodeCall(target.noise, ());
        data[1] = abi.encodeCall(target.executeFinalityRecovery, (request));
        data[2] = data[0];
        calls[0] = GovernanceCall(
            address(target),
            0,
            target.noise.selector,
            keccak256(data[0]),
            keccak256("first noise scope"),
            0,
            keccak256("first new")
        );
        calls[1] = GovernanceCall(
            address(target),
            0,
            IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector,
            keccak256(data[1]),
            f.scopeHash,
            f.oldValueHash,
            f.newValueHash
        );
        calls[2] = GovernanceCall(
            address(target),
            0,
            target.noise.selector,
            keccak256(data[2]),
            keccak256("last noise scope"),
            0,
            keccak256("last new")
        );
        deployed.executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + deployed.executor.minimumDelay(2));
        id = deployed.executor
            .scheduleGovernanceBatch(
                2,
                calls,
                scope,
                oldHash,
                newHash,
                ready,
                ready + 7 days,
                keccak256("reason"),
                "urn:actual:owner-action",
                deployed.manifestHash
            );
    }

    function testActualPublishedCompleteBatchAndExecutionOnlyEligibility() public {
        (bytes32 id, uint64 ready, GovernanceCall[] memory calls, bytes[] memory data) = _schedule();
        StreamOwnerRecoveryActionReads.Binding memory b = host.admit(id, calls, request);
        require(
            b.callHash == StreamGovernanceBootstrap.governanceCallsHash(calls),
            "real shared calls preimage"
        );
        host.keep(id, calls, request);
        require(
            host.eligible(id, request.scope, request.recoveryManifest.contentHash),
            "scheduled notice before delay"
        );
        GovernanceCall[] memory forged = abi.decode(abi.encode(calls), (GovernanceCall[]));
        forged[2].callDataHash = keccak256("same header wrong tail");
        (bool ok,) = address(host).staticcall(abi.encodeCall(host.admit, (id, forged, request)));
        require(!ok, "actual stored complete commitment");
        vm.warp(ready);
        deployed.executor.executeGovernanceBatch(id, calls, data);
        require(
            target.callbackAccepted(),
            "actual executed status and currentAction accepted during callback"
        );
        require(
            !host.eligible(id, request.scope, request.recoveryManifest.contentHash),
            "historical executed not eligible"
        );
    }

    function testActualFailedExecutionRollsBackAndSameActionRetries() public {
        (bytes32 id, uint64 ready, GovernanceCall[] memory calls, bytes[] memory data) = _schedule();
        host.keep(id, calls, request);
        target.fail(true);
        vm.warp(ready);
        (bool ok,) = address(deployed.executor)
            .call(abi.encodeCall(deployed.executor.executeGovernanceBatch, (id, calls, data)));
        require(!ok && !target.callbackAccepted(), "entire callback frame rolls back");
        require(
            deployed.executor.governanceActionFacts(id).status == GovernanceActionStatus.SCHEDULED
                && host.eligible(id, request.scope, request.recoveryManifest.contentHash),
            "same scheduled action retained"
        );
        target.fail(false);
        deployed.executor.executeGovernanceBatch(id, calls, data);
        require(
            target.callbackAccepted()
                && !host.eligible(id, request.scope, request.recoveryManifest.contentHash),
            "identical successful retry then historical false"
        );
    }
}
