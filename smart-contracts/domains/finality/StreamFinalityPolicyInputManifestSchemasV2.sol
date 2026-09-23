// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact additive interpretation, preserving every original V1 document byte.
library StreamFinalityPolicyInputManifestSchemasV2 {
    bytes32 internal constant SCHEMA_ID = keccak256("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2");
    bytes32 internal constant CANON_ID =
        keccak256("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2");
    error UnknownManifestDefinition(bytes32 id);

    function document(bytes32 id) public pure returns (bytes memory) {
        if (id == SCHEMA_ID) {
            return bytes(
                '{"name":"6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2","version":2,"format":"Solidity ABI","profile":"COLLECTION current STATIC full output with complete original and explicit entropy policies","statement":"StreamFinalityPolicyInputManifestTypesV2.Statement","fields":["StreamFinalityScope scope","bytes32 coreFactsHash","bytes32 contentRoot","uint64 leafCount","bytes32 contentRootSchemaId","bytes32 snapshotManifestHash","bytes32 referenceRenderManifestHash","StreamFinalityScopeInputs inputs","StreamFinalityComponentExpectation[] nonSanctionComponents","Entropy entropy","uint8 postFreezePolicy","uint8 sanctionPolicy"],"entropyTuple":["address sourceSet","bytes32 sourceSetCodeHash","bytes32 sourceSetProfile","bytes32 inventoryPlan","bytes32 inventoryHash","bytes32 policyChainHash","uint256 policyCount","bytes32 snapshotProfileHash","bytes32 referenceProfileHash"],"entropyMeaning":"Complete ordered sourcePolicyAt rows, including every explicit twelve-word policy and full H, are retained by the constructor-pinned source set and canonical current snapshot. The original V2 policy chain commits all original rows. All policies frozen; status1 DISABLED and status2 NOT_REQUIRED require seed0 and finalizedfalse and explicit admitted rendering. Other accepted outputs require original finalized status5. No deferred entropy exception or fabricated provider/epoch/seed.","inputOrder":["rootRecordHash","snapshotRecordHash","referenceRenderRecordHash","intentRecordHash","intentWaiverRecordHash","interviewEvidenceHash","rightsStatementRecordHash","workDescriptionRecordHash","renderCriticalEvidenceHash","bundleCoverageHash"],"components":"Exactly nine independent families, ascending, all seven original expectation fields","postFreezePolicy":1,"sanctionPolicy":1,"authority":"Actual selected combined provider derives current sources and exact V2 profiles. Actual Artist sanction and its archive are separate requirements. Materializing bytes grants no authority.","excluded":"Own manifest hash, sanction record/signature, finality record and mutable fixity heads"}'
            );
        }
        if (id == CANON_ID) {
            return bytes(
                '{"name":"6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2","version":2,"encoding":"abi.encode(bytes32 schemaId,bytes32 canonicalizationId,uint256 chainId,address core,address metadataHost,address finalityRegistry,StreamFinalityPolicyInputManifestTypesV2.Statement statement)","schemaId":"keccak256(6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2)","canonicalizationId":"keccak256(6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2)","scopeTuple":["uint8 scopeType","uint256 collectionId","uint256 tokenId","bytes32 scopeId"],"scope":"COLLECTION=0; nonzero collectionId; zero tokenId/scopeId","inputTuple":["rootRecordHash","snapshotRecordHash","referenceRenderRecordHash","intentRecordHash","intentWaiverRecordHash","interviewEvidenceHash","rightsStatementRecordHash","workDescriptionRecordHash","renderCriticalEvidenceHash","bundleCoverageHash"],"componentTuple":["bytes32 componentType","address component","bytes4 interfaceId","bytes32 codeHash","bytes32 moduleVersion","bytes32 manifestHash","bytes32 dataHash"],"entropyTuple":["address sourceSet","bytes32 sourceSetCodeHash","bytes32 sourceSetProfile","bytes32 inventoryPlan","bytes32 inventoryHash","bytes32 policyChainHash","uint256 policyCount","bytes32 snapshotProfileHash","bytes32 referenceProfileHash"],"componentCount":9,"policies":["uint8 postFreezePolicy=1","uint8 sanctionPolicy=1"],"words":"Solidity0.8.19 canonical ABI; all narrow integers and addresses zero extended; bytes4 right padded","arrays":"Exact ascending family order; no duplicate/omission","alternateOffsets":"Forbidden","trailingBytes":"Forbidden","maximumBytes":8192,"hash":"Keccak256 of exact full bytes","scopeInputCommitment":"Unchanged original 6529STREAM_FINALITY_SCOPE_INPUTS_V1(chainId,core,metadataHost,scope,ten inputs) for actual Registry; V2 schema and original record identities remain distinct","retention":"Actual Schema Store and original Registry staging both retain identical full bytes"}'
            );
        }
        revert UnknownManifestDefinition(id);
    }
}
