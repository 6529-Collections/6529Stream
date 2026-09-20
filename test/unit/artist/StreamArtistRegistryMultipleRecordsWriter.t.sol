// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { ArtistArtifactCreate } from "../../helpers/ArtistArtifactCreate.sol";
import {
    StreamArtistRegistryWriterExtension
} from "../../../smart-contracts/domains/artist/StreamArtistRegistryWriterExtension.sol";
import {
    StreamArtistMultipleRecordsTypes as MR,
    IStreamArtistMultipleRecordsHydration,
    IStreamArtistMultipleRecordsHydrationCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as M,
    IStreamArtistMultipleAuthorityHydration,
    IStreamArtistMultipleHydrationCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredHydrationTypes as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration,
    IStreamArtistRecoveredHydrationCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredConsentHydration,
    IStreamArtistRecoveredConsentHydrationCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistIdentityRevisionTypes as Revision,
    IStreamArtistIdentityRevision,
    IStreamArtistIdentityRevisionCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistOnboardingCoordinator
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboardingCoordinator.sol";

interface WriterCallCountVm {
    function expectCall(address callee, bytes calldata data, uint64 count) external;
}

/// @dev Test-only host for comparing the original single writer body with the actual
/// production Writer. Both execute in this same host, preserving their original actor.
contract MultipleRecordsWriterHost {
    address private immutable _controller = msg.sender;
    address private _writer;
    address private _reference;

    function bind(address writer, address referenceWriter) external {
        require(msg.sender == _controller && _writer == address(0), "test host binding");
        _writer = writer;
        _reference = referenceWriter;
    }

    function execute(bool original, bytes calldata input) external returns (bytes32) {
        (bool ok, bytes memory output) = (original ? _reference : _writer).delegatecall(input);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(output, 32), mload(output))
            }
        }
        return abi.decode(output, (bytes32));
    }

    /// @dev Preserve both proposal result words, including exact return length.
    function executeRaw(bool original, bytes calldata input) external returns (bytes memory) {
        (bool ok, bytes memory output) = (original ? _reference : _writer).delegatecall(input);
        if (!ok) {
            assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        }
        return output;
    }
}

/// @dev Exact pre-extraction constructor, guard and selected writer body. This is
/// an encoding/context oracle, not a replacement for the actual production Writer.
contract MultipleRecordsOriginalWriter {
    error ExtensionWrongHost(address actual);
    address private immutable _host;
    address private immutable operationCoordinator;

    constructor(address host_, address coordinator_) {
        if (
            host_ == address(0) || coordinator_ == address(0) || host_ == coordinator_
                || host_ == address(this)
        ) revert T.InvalidBinding();
        _host = host_;
        operationCoordinator = coordinator_;
    }

    modifier onlyHost() {
        if (address(this) != _host) revert ExtensionWrongHost(address(this));
        _;
    }

    function hydrateMultipleArtistAuthorityWithRecords(MR.Request calldata p)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistMultipleRecordsHydrationCoordinator(operationCoordinator)
            .coordinateHydrateMultipleArtistAuthorityWithRecords(msg.sender, p);
    }

    function hydrateMultipleArtistAuthority(M.Request calldata p)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistMultipleHydrationCoordinator(operationCoordinator)
            .coordinateHydrateMultipleArtistAuthority(msg.sender, p);
    }

    function hydrateRecoveredArtistAuthority(Recovered.Request calldata p)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistRecoveredHydrationCoordinator(operationCoordinator)
            .coordinateHydrateRecoveredArtistAuthority(msg.sender, p);
    }

    function hydrateRecoveredArtistAuthorityWithConsents(
        Recovered.Request calldata p,
        T.RoyaltyFreeze[] calldata royaltyFreezes
    ) external onlyHost returns (bytes32) {
        return IStreamArtistRecoveredConsentHydrationCoordinator(operationCoordinator)
            .coordinateHydrateRecoveredArtistAuthorityWithConsents(msg.sender, p, royaltyFreezes);
    }

    function recordIdentityRevision(
        Revision.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32) {
        return IStreamArtistIdentityRevisionCoordinator(operationCoordinator)
            .coordinateRecordIdentityRevision(msg.sender, p, a, document, displayName);
    }

    function proposeArtistBinding(
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32, bytes32) {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateProposeArtistBinding(msg.sender, collectionId, p, document, displayName);
    }
}

/// @dev Explicit typed Coordinator boundary: this records the original call bytes
/// and context, but makes no claim to validate or install Artist authority.
contract MultipleRecordsWriterCoordinator is
    IStreamArtistMultipleRecordsHydrationCoordinator,
    IStreamArtistMultipleHydrationCoordinator,
    IStreamArtistRecoveredHydrationCoordinator,
    IStreamArtistRecoveredConsentHydrationCoordinator,
    IStreamArtistIdentityRevisionCoordinator
{
    error CoordinatorRejected(address caller, address actor, bytes32 requestHash);
    address private immutable _host;
    bool public reject;
    uint256 public calls;
    address public lastActor;
    address public lastCaller;
    bytes32 public lastCallHash;

    constructor(address host) {
        _host = host;
    }

    function setReject(bool value) external {
        reject = value;
    }

    function coordinateHydrateMultipleArtistAuthorityWithRecords(
        address actor,
        MR.Request calldata request
    ) external returns (bytes32) {
        return _capture(actor, keccak256(abi.encode(request)));
    }

    function coordinateHydrateMultipleArtistAuthority(address actor, M.Request calldata request)
        external
        returns (bytes32)
    {
        return _capture(actor, keccak256(abi.encode(request)));
    }

    function coordinateHydrateRecoveredArtistAuthority(
        address actor,
        Recovered.Request calldata request
    ) external returns (bytes32) {
        return _capture(actor, keccak256(abi.encode(request)));
    }

    function coordinateHydrateRecoveredArtistAuthorityWithConsents(
        address actor,
        Recovered.Request calldata request,
        T.RoyaltyFreeze[] calldata royaltyFreezes
    ) external returns (bytes32) {
        return _capture(actor, keccak256(abi.encode(request, royaltyFreezes)));
    }

    function coordinateRecordIdentityRevision(
        address actor,
        Revision.Revision calldata revision,
        T.Authorization calldata authorization,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        return _capture(
            actor, keccak256(abi.encode(revision, authorization, document, displayName))
        );
    }

    // Only this original Onboarding selector is implemented. The boundary does not
    // advertise or substitute the complete production Onboarding Coordinator.
    function coordinateProposeArtistBinding(
        address actor,
        uint256 collectionId,
        T.BindingProposal calldata proposal,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32 artistId, bytes32 bindingHash) {
        artistId = _capture(
            actor, keccak256(abi.encode(collectionId, proposal, document, displayName))
        );
        bindingHash = keccak256(
            abi.encode("proposal binding result", artistId, collectionId, proposal.reasonHash)
        );
    }

    function _capture(address actor, bytes32 requestHash) private returns (bytes32) {
        require(msg.sender == _host, "wrong delegated host");
        if (reject) revert CoordinatorRejected(msg.sender, actor, requestHash);
        ++calls;
        lastActor = actor;
        lastCaller = msg.sender;
        lastCallHash = keccak256(msg.data);
        return lastCallHash;
    }
}

/// @notice Source-authored focused ABI/actor/guard regressions. The Writer is the
/// actual production artifact; the Coordinator is the explicit typed boundary above.
contract StreamArtistRegistryMultipleRecordsWriterTest is
    CharacterizationTestBase,
    ArtistArtifactCreate
{
    MultipleRecordsWriterHost private _host;
    MultipleRecordsWriterCoordinator private _coordinator;
    address private _writer;
    address private _reference;
    address private constant ACTOR = address(0xA47157);

    struct RevisionArguments {
        Revision.Revision revision;
        T.Authorization authorization;
        bytes document;
        string displayName;
    }

    struct ProposalArguments {
        uint256 collectionId;
        T.BindingProposal proposal;
        bytes document;
        string displayName;
    }

    function setUp() public {
        _host = new MultipleRecordsWriterHost();
        _coordinator = new MultipleRecordsWriterCoordinator(address(_host));
        _writer = _artistArtifactCreate(
            "smart-contracts/domains/artist/StreamArtistRegistryWriterExtension.sol:StreamArtistRegistryWriterExtension",
            abi.encode(address(_host), address(_coordinator))
        );
        _reference =
            address(new MultipleRecordsOriginalWriter(address(_host), address(_coordinator)));
        _host.bind(_writer, _reference);
    }

    function testPopulatedRequestPreservesExactCoordinatorBytesActorAndHost() public {
        MR.Request memory request = _request();
        _assertEncoding(request, _input(request), ACTOR);
        _assertEncoding(request, _input(request), address(0xB0B));
        require(_coordinator.calls() == 4, "actual and original calls");
    }

    function testEmptyArraysPreserveOriginalTypedEncoding() public {
        MR.Request memory request;
        _assertEncoding(request, _input(request), ACTOR);
    }

    function testTrailingBytesAndShiftedTupleKeepOriginalArgumentFraming() public {
        MR.Request memory request = _request();
        bytes memory canonical = _input(request);
        _assertEncoding(request, bytes.concat(canonical, hex"aabbccdd00112233"), ACTOR);

        // Move the complete Request body by one word. Its internal offsets remain
        // relative to that body; the outer argument offset is the only changed word.
        bytes memory shifted = new bytes(canonical.length + 32);
        for (uint256 i; i < 4; ++i) {
            shifted[i] = canonical[i];
        }
        _writeWord(shifted, 4, 64);
        _writeWord(shifted, 36, uint256(keccak256("ignored outer padding")));
        for (uint256 i = 36; i < canonical.length; ++i) {
            shifted[i + 32] = canonical[i];
        }
        _assertEncoding(request, shifted, ACTOR);
    }

    function testCoordinatorFailureBubblesExactOriginalBytes() public {
        MR.Request memory request = _request();
        bytes memory input = _input(request);
        bytes memory expected = abi.encodeWithSelector(
            MultipleRecordsWriterCoordinator.CoordinatorRejected.selector,
            address(_host),
            ACTOR,
            keccak256(abi.encode(request))
        );
        _coordinator.setReject(true);
        _assertHostFailure(false, input, expected);
        _assertHostFailure(true, input, expected);
        require(_coordinator.calls() == 0, "no committed Coordinator call");
        _coordinator.setReject(false);
        _assertEncoding(request, input, ACTOR);
    }

    function testDirectWriterRejectsBeforeNestedRequestDecoding() public {
        _expectMultipleRecordsCalls(2);
        bytes memory input = _input(_request());
        _assertWrongHost(_writer, input);
        _assertWrongHost(_reference, input);

        // Keep the outer Request frame valid, but make its authority offset invalid.
        // Both original and extracted writer must run onlyHost before following it.
        _writeWord(input, 36, type(uint256).max);
        _assertWrongHost(_writer, input);
        _assertWrongHost(_reference, input);
        require(_coordinator.calls() == 0, "guard prevents Coordinator entry");
        // The positive pair consumes the exact count. Any earlier call, even one
        // rolled back by a revert, exceeds the cheatcode's observed call count.
        MR.Request memory healthy = _request();
        _assertEncoding(healthy, _input(healthy), ACTOR);
    }

    function testMalformedNestedOffsetHasOriginalRevertAndNoCoordinatorCall() public {
        _expectMultipleRecordsCalls(2);
        bytes memory input = _input(_request());
        _writeWord(input, 36, type(uint256).max);
        (bool actualOk, bytes memory actualOutput) = _hostCall(false, input);
        (bool originalOk, bytes memory originalOutput) = _hostCall(true, input);
        require(!actualOk && !originalOk, "invalid nested offset rejected");
        require(keccak256(actualOutput) == keccak256(originalOutput), "original malformed revert");
        require(_coordinator.calls() == 0, "malformed request never reaches Coordinator");
        MR.Request memory healthy = _request();
        _assertEncoding(healthy, _input(healthy), ACTOR);
    }

    function testRecoveredRequestsPreserveActorHostCapabilitiesAndRoyaltyBytes() public {
        Recovered.Request memory request = _recoveredRequest();
        T.RoyaltyFreeze[] memory freezes = _royaltyFreezes();
        for (uint8 route; route < 2; ++route) {
            bool consents = route != 0;
            bytes memory input = _recoveredInput(consents, request, freezes);
            _assertRecoveredEncoding(consents, request, freezes, input, ACTOR);
            _assertRecoveredEncoding(consents, request, freezes, input, address(0xB0B));
            Recovered.Request memory empty;
            T.RoyaltyFreeze[] memory noFreezes = new T.RoyaltyFreeze[](0);
            _assertRecoveredEncoding(
                consents, empty, noFreezes, _recoveredInput(consents, empty, noFreezes), ACTOR
            );
        }
        require(_coordinator.calls() == 12, "both recovered routes and original calls");
    }

    function testRecoveredTrailingAndShiftedArgumentsMatchOriginal() public {
        Recovered.Request memory request = _recoveredRequest();
        T.RoyaltyFreeze[] memory freezes = _royaltyFreezes();
        for (uint8 route; route < 2; ++route) {
            bool consents = route != 0;
            bytes memory canonical = _recoveredInput(consents, request, freezes);
            _assertRecoveredEncoding(
                consents, request, freezes, bytes.concat(canonical, hex"abcdef0102030405"), ACTOR
            );
            _assertRecoveredEncoding(
                consents, request, freezes, _shiftRecovered(canonical, consents), ACTOR
            );
        }
    }

    function testRecoveredCoordinatorRevertsMatchOriginalAndRemainRetryable() public {
        Recovered.Request memory request = _recoveredRequest();
        T.RoyaltyFreeze[] memory freezes = _royaltyFreezes();
        for (uint8 route; route < 2; ++route) {
            bool consents = route != 0;
            _expectRecoveredCalls(consents, 4);
            bytes memory input = _recoveredInput(consents, request, freezes);
            bytes32 requestHash =
                consents ? keccak256(abi.encode(request, freezes)) : keccak256(abi.encode(request));
            bytes memory expected = abi.encodeWithSelector(
                MultipleRecordsWriterCoordinator.CoordinatorRejected.selector,
                address(_host),
                ACTOR,
                requestHash
            );
            _coordinator.setReject(true);
            _assertHostFailure(false, input, expected);
            _assertHostFailure(true, input, expected);
            require(_coordinator.calls() == uint256(route) * 2, "rejected calls rolled back");
            _coordinator.setReject(false);
            _assertRecoveredEncoding(consents, request, freezes, input, ACTOR);
        }
    }

    function testRecoveredGuardsAndMalformedNestedArgumentsDoNotReachCoordinator() public {
        Recovered.Request memory request = _recoveredRequest();
        T.RoyaltyFreeze[] memory freezes = _royaltyFreezes();
        for (uint8 route; route < 2; ++route) {
            bool consents = route != 0;
            _expectRecoveredCalls(consents, 2);
            bytes memory malformed = _recoveredInput(consents, request, freezes);
            _assertWrongHost(_writer, malformed);
            _assertWrongHost(_reference, malformed);
            // Keep the external Request head valid; corrupt its nested records pointer.
            _writeWord(malformed, 4 + _readWord(malformed, 4), type(uint256).max);
            _assertWrongHost(_writer, malformed);
            _assertWrongHost(_reference, malformed);
            _assertMalformedParity(malformed);
            if (consents) {
                malformed = _recoveredInput(true, request, freezes);
                // The second argument has its own array frame. Its declared length
                // cannot be satisfied by bytes elsewhere in the nested Request.
                _writeWord(malformed, 4 + _readWord(malformed, 36), type(uint256).max);
                _assertMalformedParity(malformed);
            }
            _assertRecoveredEncoding(
                consents, request, freezes, _recoveredInput(consents, request, freezes), ACTOR
            );
        }
        require(_coordinator.calls() == 4, "only the two healthy pairs entered Coordinator");
    }

    function testMultipleAuthorityPopulatedEmptyAndShiftedRequestsPreserveActorHostAndBytes()
        public
    {
        M.Request memory request = _request().authority;
        bytes memory canonical = _authorityInput(request);
        _assertAuthorityEncoding(request, canonical, ACTOR);
        _assertAuthorityEncoding(request, canonical, address(0xB0B));
        _assertAuthorityEncoding(request, bytes.concat(canonical, hex"aabbcc001122"), ACTOR);
        _assertAuthorityEncoding(request, _shiftRecovered(canonical, false), ACTOR);
        M.Request memory empty;
        _assertAuthorityEncoding(empty, _authorityInput(empty), ACTOR);
        require(_coordinator.calls() == 10, "five actual and original authority pairs");
    }

    function testMultipleAuthorityCoordinatorFailureHasExactOriginalBytesAndRetry() public {
        M.Request memory request = _request().authority;
        bytes memory input = _authorityInput(request);
        _expectAuthorityCalls(4);
        bytes memory expected = abi.encodeWithSelector(
            MultipleRecordsWriterCoordinator.CoordinatorRejected.selector,
            address(_host),
            ACTOR,
            keccak256(abi.encode(request))
        );
        _coordinator.setReject(true);
        _assertHostFailure(false, input, expected);
        _assertHostFailure(true, input, expected);
        require(_coordinator.calls() == 0, "rejected authority calls rolled back");
        _coordinator.setReject(false);
        _assertAuthorityEncoding(request, input, ACTOR);
    }

    function testMultipleAuthorityGuardAndMalformedArrayKeepOriginalRevertBeforeCoordinator()
        public
    {
        M.Request memory request = _request().authority;
        _expectAuthorityCalls(2);
        bytes memory malformed = _authorityInput(request);
        _assertWrongHost(_writer, malformed);
        _assertWrongHost(_reference, malformed);
        // Request.bindingIndex is static word zero. Corrupt only the following
        // artistIds offset, leaving the external Request head available to onlyHost.
        _writeWord(malformed, 4 + _readWord(malformed, 4) + 32, type(uint256).max);
        _assertWrongHost(_writer, malformed);
        _assertWrongHost(_reference, malformed);
        _assertMalformedParity(malformed);
        _assertAuthorityEncoding(request, _authorityInput(request), ACTOR);
        require(_coordinator.calls() == 2, "only healthy authority pair entered Coordinator");
    }

    function testIdentityRevisionAllFourArgumentsAndFramingPreserveActorHostAndReturn() public {
        RevisionArguments memory arguments = _revisionArguments();
        bytes memory canonical = _revisionInput(arguments);
        _assertRevisionEncoding(arguments, canonical, ACTOR);
        _assertRevisionEncoding(arguments, canonical, address(0xB0B));
        _assertRevisionEncoding(arguments, bytes.concat(canonical, hex"deadbeef0123456789"), ACTOR);
        _assertRevisionEncoding(arguments, _shiftRevision(canonical), ACTOR);
        RevisionArguments memory empty;
        _assertRevisionEncoding(empty, _revisionInput(empty), ACTOR);
        require(_coordinator.calls() == 10, "five actual and original revision pairs");
    }

    function testIdentityRevisionCoordinatorFailureMatchesOriginalAndAllowsRetry() public {
        RevisionArguments memory arguments = _revisionArguments();
        bytes memory input = _revisionInput(arguments);
        _expectRevisionCalls(4);
        bytes memory expected = abi.encodeWithSelector(
            MultipleRecordsWriterCoordinator.CoordinatorRejected.selector,
            address(_host),
            ACTOR,
            keccak256(
                abi.encode(
                    arguments.revision,
                    arguments.authorization,
                    arguments.document,
                    arguments.displayName
                )
            )
        );
        _coordinator.setReject(true);
        _assertHostFailure(false, input, expected);
        _assertHostFailure(true, input, expected);
        require(_coordinator.calls() == 0, "rejected revision calls rolled back");
        _coordinator.setReject(false);
        _assertRevisionEncoding(arguments, input, ACTOR);
    }

    function testIdentityRevisionGuardAndMalformedURIOrSignatureMatchOriginal() public {
        RevisionArguments memory arguments = _revisionArguments();
        _expectRevisionCalls(2);
        bytes memory canonical = _revisionInput(arguments);
        _assertWrongHost(_writer, canonical);
        _assertWrongHost(_reference, canonical);
        for (uint256 field; field < 2; ++field) {
            bytes memory malformed = _revisionInput(arguments);
            // Both outer tuple heads remain valid. URI is Revision word 3;
            // signature is Authorization word 2. onlyHost must precede each read.
            uint256 tupleOffset = _readWord(malformed, 4 + field * 32);
            uint256 nestedWord = field == 0 ? 96 : 64;
            _writeWord(malformed, 4 + tupleOffset + nestedWord, type(uint256).max);
            _assertWrongHost(_writer, malformed);
            _assertWrongHost(_reference, malformed);
            _assertMalformedParity(malformed);
        }
        _assertRevisionEncoding(arguments, canonical, ACTOR);
        require(_coordinator.calls() == 2, "only healthy revision pair entered Coordinator");
    }

    function testProposalFullTupleEmptyAndShiftedFramePreserveActorHostAndBothReturns() public {
        ProposalArguments memory arguments = _proposalArguments();
        bytes memory canonical = _proposalInput(arguments);
        _assertProposalEncoding(arguments, canonical, ACTOR);
        _assertProposalEncoding(arguments, canonical, address(0xB0B));
        _assertProposalEncoding(arguments, bytes.concat(canonical, hex"001122334455667788"), ACTOR);
        _assertProposalEncoding(arguments, _shiftProposal(canonical), ACTOR);
        ProposalArguments memory empty;
        _assertProposalEncoding(empty, _proposalInput(empty), ACTOR);
        require(_coordinator.calls() == 10, "five actual and original proposal pairs");
    }

    function testProposalCoordinatorExactRevertAndBothWordRetry() public {
        ProposalArguments memory arguments = _proposalArguments();
        bytes memory input = _proposalInput(arguments);
        _expectProposalCalls(4);
        bytes memory expected = abi.encodeWithSelector(
            MultipleRecordsWriterCoordinator.CoordinatorRejected.selector,
            address(_host),
            ACTOR,
            keccak256(
                abi.encode(
                    arguments.collectionId,
                    arguments.proposal,
                    arguments.document,
                    arguments.displayName
                )
            )
        );
        _coordinator.setReject(true);
        for (uint256 i; i < 2; ++i) {
            (bool ok, bytes memory output) = _proposalHostCall(i != 0, input);
            require(
                !ok && keccak256(output) == keccak256(expected), "exact proposal Coordinator revert"
            );
        }
        require(_coordinator.calls() == 0, "rejected proposal calls rolled back");
        _coordinator.setReject(false);
        _assertProposalEncoding(arguments, input, ACTOR);
    }

    function testProposalGuardAndMalformedCollaboratorsOrOverridesRejectBeforeCoordinator() public {
        ProposalArguments memory arguments = _proposalArguments();
        _expectProposalCalls(2);
        bytes memory canonical = _proposalInput(arguments);
        _assertWrongHost(_writer, canonical);
        _assertWrongHost(_reference, canonical);
        for (uint256 field; field < 2; ++field) {
            bytes memory malformed = _proposalInput(arguments);
            // Proposal is the second outer argument. Its nested collaborators and
            // policy overrides occupy words 9 and 10 of the original 13-word head.
            uint256 tupleOffset = _readWord(malformed, 36);
            _writeWord(malformed, 4 + tupleOffset + (9 + field) * 32, type(uint256).max);
            _assertWrongHost(_writer, malformed);
            _assertWrongHost(_reference, malformed);
            (bool actualOk, bytes memory actualOutput) = _proposalHostCall(false, malformed);
            (bool originalOk, bytes memory originalOutput) = _proposalHostCall(true, malformed);
            require(!actualOk && !originalOk, "malformed proposal rejected");
            require(
                keccak256(actualOutput) == keccak256(originalOutput),
                "original proposal decoding revert"
            );
        }
        _assertProposalEncoding(arguments, canonical, ACTOR);
        require(_coordinator.calls() == 2, "only healthy proposal pair entered Coordinator");
    }

    function _expectProposalCalls(uint64 count) private {
        WriterCallCountVm(address(vm))
            .expectCall(
                address(_coordinator),
                abi.encodeWithSelector(
                    IStreamArtistOnboardingCoordinator.coordinateProposeArtistBinding.selector
                ),
                count
            );
    }

    function _proposalInput(ProposalArguments memory arguments)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStreamArtistOnboarding.proposeArtistBinding,
            (arguments.collectionId, arguments.proposal, arguments.document, arguments.displayName)
        );
    }

    function _proposalHostCall(bool original, bytes memory input)
        private
        returns (bool, bytes memory)
    {
        vm.prank(ACTOR);
        return address(_host)
            .call(abi.encodeCall(MultipleRecordsWriterHost.executeRaw, (original, input)));
    }

    function _assertProposalEncoding(
        ProposalArguments memory arguments,
        bytes memory input,
        address actor
    ) private {
        bytes32 expectedCall = keccak256(
            abi.encodeCall(
                IStreamArtistOnboardingCoordinator.coordinateProposeArtistBinding,
                (
                    actor,
                    arguments.collectionId,
                    arguments.proposal,
                    arguments.document,
                    arguments.displayName
                )
            )
        );
        bytes32 expectedBinding = keccak256(
            abi.encode(
                "proposal binding result",
                expectedCall,
                arguments.collectionId,
                arguments.proposal.reasonHash
            )
        );
        require(expectedCall != expectedBinding, "distinct return sentinels");
        bytes memory expected = abi.encode(expectedCall, expectedBinding);
        for (uint256 i; i < 2; ++i) {
            vm.prank(actor);
            bytes memory result = _host.executeRaw(i == 1, input);
            require(
                result.length == 64 && keccak256(result) == keccak256(expected),
                "exact two proposal return words"
            );
            require(_coordinator.lastCallHash() == expectedCall, "complete proposal calldata");
            require(_coordinator.lastActor() == actor, "proposal original actor");
            require(_coordinator.lastCaller() == address(_host), "proposal original facade");
        }
    }

    function _shiftProposal(bytes memory canonical) private pure returns (bytes memory shifted) {
        shifted = new bytes(canonical.length + 32);
        for (uint256 i; i < 132; ++i) {
            shifted[i] = canonical[i];
        }
        // collectionId is a static value, so only the final three offsets move.
        for (uint256 argument = 1; argument < 4; ++argument) {
            uint256 head = 4 + argument * 32;
            _writeWord(shifted, head, _readWord(canonical, head) + 32);
        }
        _writeWord(shifted, 132, uint256(keccak256("proposal ignored outer padding")));
        for (uint256 i = 132; i < canonical.length; ++i) {
            shifted[i + 32] = canonical[i];
        }
    }

    function _proposalArguments() private pure returns (ProposalArguments memory arguments) {
        arguments.collectionId = 31001;
        T.BindingProposal memory p;
        p.artistId = keccak256("proposal original artist");
        p.artistAddress = address(0x32002);
        p.identityRecordHash = keccak256("proposal identity record");
        p.identityRecordURI = "ipfs://proposal-original-identity-document-with-a-long-uri";
        p.consentMode = 1;
        p.saleConsentScope = 2;
        p.registryImmutabilityElection = 3;
        p.collabPolicyMode = 4;
        p.collabThreshold = 35005;
        p.collaborators = new T.CollaboratorRecord[](2);
        p.collaborators[0] = T.CollaboratorRecord(
            address(0x36006), bytes32(uint256(37007)), bytes32(uint256(38008))
        );
        p.collaborators[1] = T.CollaboratorRecord(
            address(0x39009), bytes32(uint256(40010)), bytes32(uint256(41011))
        );
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](2);
        p.capabilityPolicyOverrides[0] = T.CapabilityPolicyOverride(42012, 5, 43013);
        p.capabilityPolicyOverrides[1] = T.CapabilityPolicyOverride(44014, 6, 45015);
        p.reasonHash = keccak256("proposal documentary reason");
        p.reasonURI = "ar://proposal-reason-uri-distinct-from-the-identity-document";
        arguments.proposal = p;
        arguments.document = new bytes(69);
        for (uint256 i; i < 69; ++i) {
            arguments.document[i] = bytes1(uint8(201 - i));
        }
        arguments.displayName = "Original proposal display name with a separate dynamic tail";
    }

    function _expectRevisionCalls(uint64 count) private {
        WriterCallCountVm(address(vm))
            .expectCall(
                address(_coordinator),
                abi.encodeWithSelector(
                    IStreamArtistIdentityRevisionCoordinator.coordinateRecordIdentityRevision
                    .selector
                ),
                count
            );
    }

    function _revisionInput(RevisionArguments memory arguments)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStreamArtistIdentityRevision.recordIdentityRevision,
            (arguments.revision, arguments.authorization, arguments.document, arguments.displayName)
        );
    }

    function _assertRevisionEncoding(
        RevisionArguments memory arguments,
        bytes memory input,
        address actor
    ) private {
        bytes32 expected = keccak256(
            abi.encodeCall(
                IStreamArtistIdentityRevisionCoordinator.coordinateRecordIdentityRevision,
                (
                    actor,
                    arguments.revision,
                    arguments.authorization,
                    arguments.document,
                    arguments.displayName
                )
            )
        );
        for (uint256 i; i < 2; ++i) {
            vm.prank(actor);
            bytes32 result = _host.execute(i == 1, input);
            require(result == expected, "exact revision arguments and return");
            require(_coordinator.lastCallHash() == expected, "full revision calldata capture");
            require(_coordinator.lastActor() == actor, "revision original actor");
            require(_coordinator.lastCaller() == address(_host), "revision original facade");
        }
    }

    function _shiftRevision(bytes memory canonical) private pure returns (bytes memory shifted) {
        shifted = new bytes(canonical.length + 32);
        for (uint256 i; i < 132; ++i) {
            shifted[i] = canonical[i];
        }
        for (uint256 argument; argument < 4; ++argument) {
            uint256 head = 4 + argument * 32;
            _writeWord(shifted, head, _readWord(canonical, head) + 32);
        }
        _writeWord(shifted, 132, uint256(keccak256("revision ignored outer padding")));
        for (uint256 i = 132; i < canonical.length; ++i) {
            shifted[i + 32] = canonical[i];
        }
    }

    function _revisionArguments() private pure returns (RevisionArguments memory arguments) {
        arguments.revision = Revision.Revision({
            artistId: keccak256("revision artist"),
            previousRecordHash: keccak256("previous original identity record"),
            revisedRecordHash: keccak256("new operative identity document"),
            identityRecordURI: "ipfs://identity-revision-distinct-uri-crossing-more-than-one-word"
        });
        arguments.authorization.nonce = 27001;
        arguments.authorization.time = 28002;
        arguments.authorization.signature = new bytes(65);
        arguments.document = new bytes(73);
        for (uint256 i; i < 65; ++i) {
            arguments.authorization.signature[i] = bytes1(uint8(i + 1));
        }
        for (uint256 i; i < 73; ++i) {
            arguments.document[i] = bytes1(uint8(173 - i));
        }
        arguments.displayName = "Distinct revised artist display name across words";
    }

    function _expectAuthorityCalls(uint64 count) private {
        WriterCallCountVm(address(vm))
            .expectCall(
                address(_coordinator),
                abi.encodeWithSelector(
                    IStreamArtistMultipleHydrationCoordinator.coordinateHydrateMultipleArtistAuthority
                    .selector
                ),
                count
            );
    }

    function _authorityInput(M.Request memory request) private pure returns (bytes memory) {
        return abi.encodeCall(
            IStreamArtistMultipleAuthorityHydration.hydrateMultipleArtistAuthority, (request)
        );
    }

    function _assertAuthorityEncoding(M.Request memory request, bytes memory input, address actor)
        private
    {
        bytes32 expected = keccak256(
            abi.encodeCall(
                IStreamArtistMultipleHydrationCoordinator.coordinateHydrateMultipleArtistAuthority,
                (actor, request)
            )
        );
        for (uint256 i; i < 2; ++i) {
            vm.prank(actor);
            bytes32 result = _host.execute(i == 1, input);
            require(result == expected, "exact multiple authority arguments");
            require(_coordinator.lastCallHash() == expected, "full multiple authority calldata");
            require(_coordinator.lastActor() == actor, "multiple authority original actor");
            require(_coordinator.lastCaller() == address(_host), "multiple authority facade");
        }
    }

    function _expectMultipleRecordsCalls(uint64 count) private {
        WriterCallCountVm(address(vm))
            .expectCall(
                address(_coordinator),
                abi.encodeWithSelector(
                    IStreamArtistMultipleRecordsHydrationCoordinator.coordinateHydrateMultipleArtistAuthorityWithRecords
                        .selector
                ),
                count
            );
    }

    function _expectRecoveredCalls(bool consents, uint64 count) private {
        bytes4 selector = consents
            ? IStreamArtistRecoveredConsentHydrationCoordinator.coordinateHydrateRecoveredArtistAuthorityWithConsents
                .selector
            : IStreamArtistRecoveredHydrationCoordinator.coordinateHydrateRecoveredArtistAuthority
                .selector;
        WriterCallCountVm(address(vm))
            .expectCall(address(_coordinator), abi.encodeWithSelector(selector), count);
    }

    function _assertMalformedParity(bytes memory input) private {
        (bool actualOk, bytes memory actualOutput) = _hostCall(false, input);
        (bool originalOk, bytes memory originalOutput) = _hostCall(true, input);
        require(!actualOk && !originalOk, "invalid recovered argument rejected");
        require(keccak256(actualOutput) == keccak256(originalOutput), "original recovered revert");
    }

    function _assertRecoveredEncoding(
        bool consents,
        Recovered.Request memory request,
        T.RoyaltyFreeze[] memory freezes,
        bytes memory input,
        address actor
    ) private {
        bytes memory expectedCall = consents
            ? abi.encodeCall(
                IStreamArtistRecoveredConsentHydrationCoordinator.coordinateHydrateRecoveredArtistAuthorityWithConsents,
                (actor, request, freezes)
            )
            : abi.encodeCall(
                IStreamArtistRecoveredHydrationCoordinator.coordinateHydrateRecoveredArtistAuthority,
                (actor, request)
            );
        bytes32 expected = keccak256(expectedCall);
        for (uint256 i; i < 2; ++i) {
            vm.prank(actor);
            bytes32 result = _host.execute(i == 1, input);
            require(result == expected, "exact recovered Coordinator arguments");
            require(_coordinator.lastCallHash() == expected, "full recovered calldata capture");
            require(_coordinator.lastActor() == actor, "recovered original actor");
            require(_coordinator.lastCaller() == address(_host), "recovered facade context");
        }
    }

    function _recoveredInput(
        bool consents,
        Recovered.Request memory request,
        T.RoyaltyFreeze[] memory freezes
    ) private pure returns (bytes memory) {
        return consents
            ? abi.encodeCall(
                IStreamArtistRecoveredConsentHydration.hydrateRecoveredArtistAuthorityWithConsents,
                (request, freezes)
            )
            : abi.encodeCall(
                IStreamArtistRecoveredHydration.hydrateRecoveredArtistAuthority, (request)
            );
    }

    function _shiftRecovered(bytes memory canonical, bool consents)
        private
        pure
        returns (bytes memory shifted)
    {
        uint256 head = consents ? 64 : 32;
        shifted = new bytes(canonical.length + 32);
        for (uint256 i; i < 4 + head; ++i) {
            shifted[i] = canonical[i];
        }
        _writeWord(shifted, 4, _readWord(canonical, 4) + 32);
        if (consents) _writeWord(shifted, 36, _readWord(canonical, 36) + 32);
        _writeWord(shifted, 4 + head, uint256(keccak256("recovered ignored outer padding")));
        for (uint256 i = 4 + head; i < canonical.length; ++i) {
            shifted[i + 32] = canonical[i];
        }
    }

    function _readWord(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        require(offset + 32 <= data.length, "test read bounds");
        assembly ("memory-safe") { value := mload(add(add(data, 32), offset)) }
    }

    function _recoveredRequest() private pure returns (Recovered.Request memory p) {
        p.records = _request();
        p.expectedSourceImportCommitment = keccak256("original recovered source import");
        p.expectedSemanticInventory = keccak256("complete recovered inventory");
        for (uint256 i; i < 7; ++i) {
            p.expectedCapabilities[i] = Recovered.Capability({
                profile: bytes32(uint256(15000 + i)),
                version: uint16(16000 + i),
                ownerIndex: uint8(i),
                ownerDomain: bytes32(uint256(17000 + i)),
                checkpointSchema: bytes32(uint256(18000 + i)),
                stateSchema: bytes32(uint256(19000 + i)),
                supportedFeatures: 20000 + uint256(i)
            });
        }
    }

    function _royaltyFreezes() private pure returns (T.RoyaltyFreeze[] memory freezes) {
        freezes = new T.RoyaltyFreeze[](2);
        freezes[0] = T.RoyaltyFreeze(
            address(0x21001), 22001, bytes32(uint256(23001)), bytes32(uint256(24001))
        );
        freezes[1] = T.RoyaltyFreeze(
            address(0x21002), 22002, bytes32(uint256(23002)), bytes32(uint256(24002))
        );
    }

    function _assertEncoding(MR.Request memory request, bytes memory input, address actor) private {
        bytes32 expected = keccak256(
            abi.encodeCall(
                IStreamArtistMultipleRecordsHydrationCoordinator.coordinateHydrateMultipleArtistAuthorityWithRecords,
                (actor, request)
            )
        );
        for (uint256 i; i < 2; ++i) {
            vm.prank(actor);
            bytes32 result = _host.execute(i == 1, input);
            require(result == expected, "exact normalized Coordinator arguments");
            require(_coordinator.lastCallHash() == expected, "independent calldata capture");
            require(_coordinator.lastActor() == actor, "original external actor");
            require(_coordinator.lastCaller() == address(_host), "original facade context");
        }
    }

    function _assertWrongHost(address writer, bytes memory input) private {
        (bool ok, bytes memory output) = writer.call(input);
        require(!ok, "direct writer rejected");
        require(
            keccak256(output)
                == keccak256(
                    abi.encodeWithSelector(
                        StreamArtistRegistryWriterExtension.ExtensionWrongHost.selector, writer
                    )
                ),
            "host error precedes nested decode"
        );
    }

    function _assertHostFailure(bool original, bytes memory input, bytes memory expected) private {
        (bool ok, bytes memory output) = _hostCall(original, input);
        require(!ok && keccak256(output) == keccak256(expected), "exact Coordinator revert");
    }

    function _hostCall(bool original, bytes memory input) private returns (bool, bytes memory) {
        vm.prank(ACTOR);
        return
            address(_host)
                .call(abi.encodeCall(MultipleRecordsWriterHost.execute, (original, input)));
    }

    function _input(MR.Request memory request) private pure returns (bytes memory) {
        return abi.encodeCall(
            IStreamArtistMultipleRecordsHydration.hydrateMultipleArtistAuthorityWithRecords,
            (request)
        );
    }

    function _writeWord(bytes memory data, uint256 offset, uint256 value) private pure {
        require(offset + 32 <= data.length, "test mutation bounds");
        assembly ("memory-safe") {
            mstore(add(add(data, 32), offset), value)
        }
    }

    function _request() private pure returns (MR.Request memory p) {
        p.authority.bindingIndex = 123;
        p.authority.artistIds = new bytes32[](2);
        p.authority.artistIds[0] = keccak256("artist zero");
        p.authority.artistIds[1] = keccak256("artist one");
        p.authority.collections = new M.Collection[](2);
        p.witnesses = new MR.CollectionWitness[](2);
        for (uint256 i; i < 7; ++i) {
            p.authority.expectedSource[i] = CP.Checkpoint({
                schema: bytes32(100 + i),
                ownerState: T.Snapshot(
                    bytes32(200 + i), uint64(300 + i), bytes32(400 + i), bytes32(500 + i)
                ),
                replayRoot: bytes32(600 + i),
                replayCount: 700 + i,
                nonceRoot: bytes32(800 + i),
                nonceIndexCount: 900 + i
            });
            p.authority.replayOrigins[i] = new AH.Origin[](i % 3);
            for (uint256 j; j < i % 3; ++j) {
                p.authority.replayOrigins[i][j] =
                    AH.Origin(bytes32(1000 + i * 3 + j), bytes32(2000 + i * 3 + j));
            }
        }
        for (uint256 i; i < 2; ++i) {
            p.authority.collections[i].artistId = p.authority.artistIds[i];
            p.authority.collections[i].collectionId = 3000 + i;
            p.authority.collections[i].policies = new AH.PolicyKey[](i + 1);
            for (uint256 j; j <= i; ++j) {
                p.authority.collections[i].policies[j] =
                    AH.PolicyKey(bytes32(4000 + i * 2 + j), bytes32(5000 + i * 2 + j));
            }
            p.witnesses[i].collectionId = 3000 + i;
            p.witnesses[i].economics = new T.EconomicsConsent[](i + 1);
            p.witnesses[i].attestations = new RH.AttestationInput[](2 - i);
            for (uint256 j; j <= i; ++j) {
                p.witnesses[i].economics[j] = T.EconomicsConsent({
                    collectionId: 3000 + i,
                    resolver: address(uint160(6000 + j)),
                    revenueClass: bytes32(7000 + j),
                    scope: uint8(j + 1),
                    scopeId: 8000 + j,
                    assignmentHash: bytes32(9000 + j)
                });
            }
            for (uint256 j; j < 2 - i; ++j) {
                p.witnesses[i].attestations[j] = RH.AttestationInput({
                    terms: T.Attestation({
                        collectionId: 3000 + i,
                        subjectKind: uint8(j + 1),
                        subjectId: bytes32(10000 + i * 2 + j),
                        subjectStateHash: bytes32(11000 + i * 2 + j),
                        schemaId: bytes32(12000 + j),
                        statementHash: bytes32(13000 + j),
                        statementURI: j == 0
                            ? "ipfs://short"
                            : "ar://a-longer-documentary-test-locator-crossing-one-word"
                    }),
                    nonce: 14000 + i * 2 + j
                });
            }
        }
    }
}
