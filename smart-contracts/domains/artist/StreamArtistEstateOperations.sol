// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateCoverage.sol";
import "./StreamArtistEstateHashes.sol";
import "./StreamArtistGovernanceWitness.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice Explicit Identity-only estate recipes in the locked Coordinator context.
library StreamArtistEstateOperations {
    function request(
        D.CoordinatorContext memory x,
        address actor,
        Estate.Request memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x);
        StreamArchivalTypes.CoverageFacts memory coverage =
            StreamArtistEstateCoverage.requireCoverage(
                x.suite.registry, x.suite.core, p.selectedCoverageHash, p.artistId, p.evidenceHash
            );
        IStreamArtistEstateOwner owner = IStreamArtistEstateOwner(x.suite.owners[2]);
        // Validate the actual selection before asking any signer contract to verify it.
        Estate.RequestFacts memory facts = owner.estateRequestFacts(p, coverage.envelopeHash);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            p.successor,
            StreamArtistEstateHashes.digest(_environment(x), p, a),
            a.signature
        );
        record = owner.requestEstate(T.ActionContext(38, actor, before_[2]), p, a, proof, coverage);
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory execution) =
            owner.estateActivationRecord(record);
        _archive(
            x,
            38,
            actor,
            record,
            before_,
            abi.encode(p, a, proof, coverage, facts, saved, phase, execution)
        );
    }

    function cancel(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 artistId,
        bytes32 expected
    ) public {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistEstateOwner(x.suite.owners[2])
            .cancelEstate(T.ActionContext(39, actor, before_[2]), artistId, expected);
        _archive(x, 39, actor, expected, before_, abi.encode(artistId, expected));
    }

    function execute(D.CoordinatorContext memory x, address actor, Estate.Execution memory p)
        public
    {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistEstateOwner owner = IStreamArtistEstateOwner(x.suite.owners[2]);
        (Estate.RequestRecord memory item,,) =
            owner.estateActivationRecord(p.expectedActivationRecordHash);
        StreamArchivalTypes.CoverageFacts memory coverage =
            StreamArtistEstateCoverage.requireCoverage(
                x.suite.registry,
                x.suite.core,
                p.currentCoverageHash,
                p.artistId,
                item.terms.evidenceHash
            );
        (uint32 capabilities, Estate.AccelerationContext memory context) =
            owner.estateExecutionFacts(p, coverage.envelopeHash);
        Contest.GovernanceWitness memory governance;
        if (block.timestamp < item.noticeEndsAt) {
            address authority =
                IStreamArtistIdentityContestOwner(address(owner)).artistWindowAuthority();
            if (actor != authority) revert Estate.EstateNoticeNotElapsed(item.noticeEndsAt);
            governance = StreamArtistGovernanceWitness.readEstateAcceleration(
                authority,
                item.terms.evidenceHash,
                context.scopeHash,
                context.oldValueHash,
                context.newValueHash
            );
        }
        owner.executeEstate(T.ActionContext(40, actor, before_[2]), p, coverage, governance);
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory execution) =
            owner.estateActivationRecord(p.expectedActivationRecordHash);
        _archive(
            x,
            40,
            actor,
            p.expectedActivationRecordHash,
            before_,
            abi.encode(p, coverage, capabilities, context, governance, saved, phase, execution)
        );
    }

    function acceleration(D.CoordinatorContext memory x, Estate.Execution memory p)
        public
        view
        returns (Estate.AccelerationContext memory context)
    {
        IStreamArtistEstateOwner owner = IStreamArtistEstateOwner(x.suite.owners[2]);
        (Estate.RequestRecord memory item,,) =
            owner.estateActivationRecord(p.expectedActivationRecordHash);
        StreamArchivalTypes.CoverageFacts memory coverage =
            StreamArtistEstateCoverage.requireCoverage(
                x.suite.registry,
                x.suite.core,
                p.currentCoverageHash,
                p.artistId,
                item.terms.evidenceHash
            );
        (, context) = owner.estateExecutionFacts(p, coverage.envelopeHash);
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (T.SignerApproval memory) {
        if (actor == address(0) || signer == address(0)) {
            revert T.InvalidSignature();
        }
        bool direct = actor == signer && signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function _environment(D.CoordinatorContext memory x)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(
            block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
        );
    }

    function _snapshots(D.CoordinatorContext memory x)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        result[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, op, actor, record, before_, _snapshots(x), payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
