// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../records/StreamReferenceModeDefinitions.sol";
import "../records/StreamReferenceRenderDefinitionReads.sol";
import "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";

library StreamReferenceModeDefinitionsRead {
    function context(StreamReferenceRenderTypes.Dependencies memory d)
        internal
        pure
        returns (StreamWorkRecordContext.Dependencies memory defs)
    {
        for (uint256 i; i < 4; ++i) {
            defs.targets[i] = d.targets[i];
            defs.codeHashes[i] = d.codeHashes[i];
        }
        defs.chainId = d.chainId;
        defs.readGas = d.readGas;
    }

    function requireDefinitions(StreamReferenceRenderTypes.Dependencies memory d) public view {
        // The original environment, PNG and runtime catalog meanings remain pinned unchanged.
        StreamReferenceRenderDefinitionReads.requireDefinitions(d);
        bytes32[6] memory ids = [
            StreamReferenceModeDefinitions.SCHEMA_ID,
            StreamReferenceModeDefinitions.PROFILE_ID,
            StreamReferenceModeDefinitions.CONDITION_ID,
            StreamReferenceModeDefinitions.PROPERTIES_ID,
            StreamReferenceModeDefinitions.CANON_ID,
            StreamReferenceModeDefinitions.DECODE_ID
        ];
        bytes32[6] memory hashes = [
            StreamReferenceModeDefinitions.SCHEMA_HASH,
            StreamReferenceModeDefinitions.PROFILE_HASH,
            StreamReferenceModeDefinitions.CONDITION_HASH,
            StreamReferenceModeDefinitions.PROPERTIES_HASH,
            StreamReferenceModeDefinitions.CANON_HASH,
            StreamReferenceModeDefinitions.DECODE_HASH
        ];
        uint32[6] memory sizes = [
            StreamReferenceModeDefinitions.SCHEMA_BYTES,
            StreamReferenceModeDefinitions.PROFILE_BYTES,
            StreamReferenceModeDefinitions.CONDITION_BYTES,
            StreamReferenceModeDefinitions.PROPERTIES_BYTES,
            StreamReferenceModeDefinitions.CANON_BYTES,
            StreamReferenceModeDefinitions.DECODE_BYTES
        ];
        for (uint256 i; i < 6; ++i) {
            StreamWorkRecordContext.definition(
                context(d),
                ids[i],
                i == 4
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : i == 1
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                hashes[i],
                sizes[i],
                keccak256("RAW_BYTES"),
                true
            );
        }
    }

    function metric(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceModeTypes.Metric memory m
    ) public view returns (bytes32) {
        if (
            m.metricId == 0 || m.algorithm == 0 || bytes(m.tool).length == 0
                || bytes(m.tool).length > 128 || bytes(m.version).length == 0
                || bytes(m.version).length > 128 || m.implementationHash == 0
                || m.parametersHash == 0 || m.scale != 1000000000
        ) {
            revert StreamReferenceModeTypes.InvalidModeEvidence();
        }
        bytes memory encoded = abi.encode(m);
        StreamWorkRecordContext.definition(
            context(d),
            m.metricId,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            keccak256(encoded),
            encoded.length,
            StreamReferenceModeDefinitions.CANON_ID,
            true
        );
        return keccak256(encoded);
    }
}
