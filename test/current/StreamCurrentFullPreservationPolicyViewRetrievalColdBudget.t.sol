// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewRetrievalFixture.sol";
import { OfficialSafe } from "../helpers/OfficialSafeFixture.sol";
import {
    StreamViewRetrievalTransactionProbe as Tx
} from "../helpers/StreamViewRetrievalTransactionProbe.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as ColdCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationRendererV1 as ColdServing
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";

/// @notice Separately measured actual source/output and threshold-Safe retrieval transactions.
/// @dev Original graph/token setup and diagnostics are unchanged. Each signed transaction starts
/// a fresh pinned VM against genuine fixture state, with normal sender/destination/precompile
/// warmth and all remaining reached accounts/slots cold. Gas limits are gross transaction
/// bounds, not gas-used receipts or maximum-scope acceptance.
/// Actual browser reference, sanction, finality and independent renderer analysis remain separate.
contract StreamCurrentFullPreservationPolicyViewRetrievalColdBudgetTest is
    StreamCurrentFullPreservationPolicyViewRetrievalFixture
{
    function _fullPolicyViewCheckpointServingGas() internal pure override returns (uint32) {
        return 6000000;
    }

    function _viewCompleteRetrievalSourceGas(uint256) internal pure override returns (uint256) {
        return 7000000;
    }

    function _prepareColdSource() private {
        _viewPrepareInputSource();
        _viewPrepareReferenceDefinitions();
        if (viewImageCoverage.coverageHash == 0) _viewPrepareImageArchive();
        _viewRequireCurrentPublication();
        require(
            assemblyViewPreservationCheckpoint.configuration().servingGas == 6000000
                && viewRetrieval.configuration().sourceGas == 7000000
                && viewRetrieval.configuration().signatureGas == 400000,
            "unchanged independent leaf budgets"
        );
    }

    function testActualColdSourceAndCurrentHistoricalFullOutputs() external {
        _prepareColdSource();
        (bytes memory raw,) = _executeLeaf(
            address(assemblyViewPreservationCheckpoint),
            abi.encodeCall(assemblyViewPreservationCheckpoint.currentSource, (fullPolicyViewScope)),
            7000000,
            true
        );
        ColdCheckpoint.Source memory source = abi.decode(raw, (ColdCheckpoint.Source));
        require(
            keccak256(raw) == keccak256(abi.encode(source))
                && source.adoption.recordHash == fullPolicyViewAdoption
                && source.adoption.sourceHash == fullPolicyViewOriginal.sourceHash
                && source.adoption.source.payloadHash == keccak256(fullPolicyViewPayload)
                && source.contextHash != 0
                && source.preservation.liveRenderer == address(fullPolicyViewRenderer)
                && source.admission.registry == address(fullPolicyViewRegistry),
            "full actual source/adoption/payload/admission, never a retained hash shortcut"
        );
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            uint256 token = fullPolicyTokens[i];
            _coldOutput(token, false, false, viewPublicationJSON[token]);
            _coldOutput(token, true, false, viewPublicationHTML[token]);
            _coldOutput(token, false, true, viewPublicationJSON[token]);
            _coldOutput(token, true, true, viewPublicationHTML[token]);
        }
        _noFinalityClaim();
    }

    function _coldOutput(uint256 token, bool html, bool historical, bytes memory expected) private {
        bytes memory input;
        if (historical) {
            input = html
                ? abi.encodeCall(
                    ColdServing.historicalPreservationViewHTML, (fullPolicyViewAdoption, token)
                )
                : abi.encodeCall(
                    ColdServing.historicalPreservationViewJSON, (fullPolicyViewAdoption, token)
                );
        } else {
            input = html
                ? abi.encodeCall(ColdServing.preservationViewHTML, (fullPolicyViewScope, token))
                : abi.encodeCall(ColdServing.preservationViewJSON, (fullPolicyViewScope, token));
        }
        (bytes memory raw, Tx.Result memory m) =
            _executeLeaf(address(assemblyViewPreservationRenderer), input, 6000000, true);
        bytes memory canonical = historical
            ? abi.encode(fullPolicyViewScope, string(expected))
            : abi.encode(fullPolicyViewAdoption, string(expected));
        require(
            expected.length != 0 && raw.length == canonical.length
                && keccak256(raw) == keccak256(canonical) && m.outputHash == keccak256(canonical),
            "complete original checkpoint bytes and canonical current/historical transport"
        );
    }

    function testActualColdSafePublicationAndFullCorrespondenceWithinBudgets() external {
        _prepareColdSource();
        VR.Request memory request = _viewImageRequest(19);
        (VR.Observation memory observed, bytes memory witnessSignature) =
            _viewPrepareImageRequest(request);
        bytes memory inner = abi.encodeCall(viewRetrieval.publish, (request, witnessSignature));
        bytes memory outer = _signedSafeCall(address(viewRetrieval), inner);
        uint256 beforeNonce = assemblyRoot.nonce();
        bytes32 expected = _expectedReceipt(observed, witnessSignature);
        (bytes memory response, Tx.Result memory m) =
            _executeLeaf(address(assemblyRoot), outer, 16777216, false);
        require(
            keccak256(response) == keccak256(abi.encode(true))
                && m.intrinsic == Tx.intrinsicGas(outer) && m.intrinsic > Tx.intrinsicGas(inner)
                && assemblyRoot.nonce() == beforeNonce + 1
                && viewRetrieval.nonceUsed(
                    keccak256(abi.encode(VR.NONCE, address(assemblyRoot), uint256(19)))
                ) && viewRetrieval.record(expected).recordHash == expected
                && keccak256(viewRetrieval.encoded(expected))
                    == keccak256(abi.encode(observed, witnessSignature)),
            "one real bounded Safe transaction and immutable original witness"
        );
        (response,) = _executeLeaf(
            address(viewRetrieval),
            abi.encodeCall(viewRetrieval.requireCorrespondence, (expected)),
            8000000,
            true
        );
        (VR.Source memory source, VR.Receipt memory receipt, VRBundle.Admission memory admitted) =
            abi.decode(response, (VR.Source, VR.Receipt, VRBundle.Admission));
        require(
            keccak256(response) == keccak256(abi.encode(source, receipt, admitted))
                && keccak256(abi.encode(source)) == keccak256(abi.encode(observed.source))
                && receipt.recordHash == expected && receipt.writer == address(assemblyRoot)
                && keccak256(abi.encode(admitted.externalOriginal))
                    == keccak256(abi.encode(viewImageCoverage)),
            "complete cold source/receipt/same-pair correspondence under original8m"
        );
        _noFinalityClaim();
    }

    function testActualColdSafeRevocationKeepsHistoryAndRefusesCurrent() external {
        _prepareColdSource();
        bytes32 hash = _viewPublishImage(31);
        bytes32 payloadHash = keccak256(viewRetrieval.encoded(hash));
        uint256 beforeNonce = assemblyRoot.nonce();
        uint64 beforeEpoch = viewRetrieval.revocationEpoch(fullPolicyViewScope);
        bytes memory outer = _signedSafeCall(
            address(viewRetrieval),
            abi.encodeCall(viewRetrieval.revoke, (hash, keccak256("actual cold revocation")))
        );
        (bytes memory raw,) = _executeLeaf(address(assemblyRoot), outer, 16777216, false);
        require(
            keccak256(raw) == keccak256(abi.encode(true)) && assemblyRoot.nonce() == beforeNonce + 1
                && viewRetrieval.revocationEpoch(fullPolicyViewScope) == beforeEpoch + 1
                && viewRetrieval.revoked(hash) && viewRetrieval.record(hash).recordHash == hash
                && keccak256(viewRetrieval.encoded(hash)) == payloadHash,
            "one actual Safe revocation preserves exact original retained history"
        );
        _viewRequireRevokedImage(hash);
        _noFinalityClaim();
    }

    function _signedSafeCall(address target, bytes memory inner) private returns (bytes memory) {
        bytes32 digest = assemblyRoot.getTransactionHash(
            target, 0, inner, 0, 0, 0, 0, address(0), address(0), assemblyRoot.nonce()
        );
        bytes memory signatures = safeThresholdSignature(assemblyRootKeys, digest);
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (target, 0, inner, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
    }

    function _expectedReceipt(VR.Observation memory o, bytes memory signature)
        private
        view
        returns (bytes32)
    {
        VR.Receipt memory r;
        VR.Source memory s = o.source;
        r.sourceKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_SOURCE_V1"),
                s.scope,
                s.core,
                s.router,
                s.adoptionRecord,
                s.adoptionSourceHash,
                s.declaration,
                s.declarationRecord,
                s.payloadHash,
                s.requestedURI,
                s.artistId,
                s.artistPresentationHash
            )
        );
        r.observationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"),
                block.chainid,
                address(viewRetrieval),
                viewRetrieval.configurationHash(),
                o
            )
        );
        r.objectHash = o.coverage.objectHash;
        r.coverageHash = o.coverage.coverageHash;
        r.writer = o.writer;
        r.recordedAt = uint64(block.timestamp);
        r.payloadHash = keccak256(abi.encode(o, signature));
        r.payloadBytes = uint32(abi.encode(o, signature).length);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_RECORD_V1"),
                block.chainid,
                address(viewRetrieval),
                viewRetrieval.configurationHash(),
                r
            )
        );
    }

    /// @dev Read limits remain leaf execution budgets. Publication supplies the complete
    /// gross ceiling and exact outer Safe calldata, including both signature envelopes.
    function _executeLeaf(address target, bytes memory input, uint256 limit, bool readOnly)
        private
        returns (bytes memory, Tx.Result memory)
    {
        uint256 gross = readOnly ? limit + Tx.intrinsicGas(input) : limit;
        require(gross <= 16777216, "original gross transaction limit");
        return Tx.execute(target, input, gross);
    }

    function _noFinalityClaim() private view {
        require(
            assemblyViewReferenceRecord == 0 && viewSanctionRecord == 0 && viewFinalityRecord == 0,
            "cold retrieval acceptance creates no browser reference, sanction or finality"
        );
    }
}
