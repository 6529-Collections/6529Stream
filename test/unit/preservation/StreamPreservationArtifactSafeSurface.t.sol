// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PreservationActualInventoryFixture.sol";
import "./PreservationOnchainArchiveFixture.sol";
import "./PreservationSafeCallProbe.sol";

interface PreservationArtifactSafeVm {
    function computeCreateAddress(address, uint256) external returns (address);
    function getNonce(address) external returns (uint64);
}

/// @dev The six archive setup hooks below retain the accepted full547 fixture's
/// actual Archive/Store/aggregate composition and original leaf, without repeating
/// bundle admission. Core/Artist/Executor/seed boundaries remain explicitly inherited.
contract StreamPreservationArtifactSafeSurfaceTest is
    PreservationActualInventoryFixture,
    PreservationOnchainArchiveFixture
{
    PreservationArtifactSafeVm private constant artifactSafeVm =
        PreservationArtifactSafeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PreservationSafeCallProbe private probe;
    bytes32 private leafArtifact;
    bytes32 private leafCoverage;

    function setUp() public override {
        super.setUp();
        probe = new PreservationSafeCallProbe();
    }

    function _createArtifactCoverage() internal override returns (address) {
        _ocSetupArchive(address(core), address(executor), address(artist));
        address predicted = artifactSafeVm.computeCreateAddress(
            address(this), uint256(artifactSafeVm.getNonce(address(this))) + 3
        );
        return _ocDeployArtifact(address(schemas), address(store), predicted);
    }

    function _createArchiveRoles() internal override returns (StreamRoleRegistry) {
        return ocRoles;
    }

    function _leafReadGas() internal pure override returns (uint256) {
        return 1000000;
    }

    function _ocBindArchiveRoles(address authority, address registry) internal override {
        cheat.mockCall(authority, abi.encodeWithSignature("roleRegistry()"), abi.encode(registry));
        cheat.mockCall(
            core.selected(keccak256("MODULE_REGISTRY")),
            abi.encodeWithSignature("governanceExecutor()"),
            abi.encode(authority)
        );
    }

    function _ocArtistId() internal view override returns (bytes32) {
        return artist.artistId();
    }

    function _coverOriginalLeaf(bytes memory raw) internal override returns (bytes32, bytes32) {
        cheat.mockCall(
            address(artist),
            abi.encodeWithSignature("archivalCoverage()"),
            abi.encode(address(ocArchive))
        );
        (leafArtifact, leafCoverage) = _ocCover(
            raw,
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1")
        );
        return (leafArtifact, leafCoverage);
    }

    function _read(
        OfficialSafe account,
        uint256[] memory keys,
        bytes memory input,
        bytes memory expected
    ) private {
        uint256 nonce = account.nonce();
        bytes32 owners = keccak256(abi.encode(account.getOwners()));
        uint256 threshold = account.getThreshold();
        require(
            executeSafe(
                account,
                keys,
                address(probe),
                0,
                abi.encodeCall(
                    probe.check, (address(account), address(ocArtifact), input, expected)
                ),
                1
            ),
            "actual Safe-context artifact return"
        );
        require(
            account.nonce() == nonce + 1 && account.getThreshold() == threshold
                && keccak256(abi.encode(account.getOwners())) == owners,
            "Safe nonce and authority"
        );
    }

    function _transaction(bytes memory input) private returns (bytes memory) {
        bytes32 digest = archiveAgentSafe.getTransactionHash(
            address(ocArtifact),
            0,
            input,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            archiveAgentSafe.nonce()
        );
        return abi.encodeCall(
            archiveAgentSafe.execTransaction,
            (
                address(ocArtifact),
                0,
                input,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(archiveAgentKeys, digest)
            )
        );
    }

    function _reject(bytes memory input) private {
        uint256 nonce = archiveAgentSafe.nonce();
        (bool ok,) = address(archiveAgentSafe).call(_transaction(input));
        require(
            !ok && archiveAgentSafe.nonce() == nonce,
            "invalid original locator preserves Safe nonce"
        );
    }

    function _expectedEnvironment() private view returns (bytes memory) {
        address target = core.selected(keccak256("ARTWORK_FINALITY_REGISTRY"));
        bytes32 environment = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_ENVIRONMENT_V1"),
                block.chainid,
                address(ocArtifact),
                address(core),
                address(core).codehash,
                address(ocArchive),
                address(ocArchive).codehash,
                address(schemas),
                address(schemas).codehash,
                address(store),
                address(store).codehash,
                target,
                target.codehash,
                ocArchive.requireCoverageEnvironment()
            )
        );
        return abi.encode(environment, ocArchive.coverageValidationEpoch());
    }

    function testSafeOriginalPartAndEnvironmentExactReturnAndInvalidLocators() public {
        OcF.Coverage memory c = ocArtifact.coverage(leafCoverage);
        require(
            c.chunkCount != 0 && c.artifactHash == leafArtifact && c.artistId == artist.artistId(),
            "actual original leaf artifact"
        );
        bytes32 part = ocArtifact.originalArtifactChunkCoverage(leafCoverage, 0);
        require(
            part != 0
                && ocArchive.coverage(part).evidenceHash
                    == ocArtifact.artifact(leafArtifact).chunkHashes[0],
            "actual original signed chunk coverage"
        );
        _read(
            archiveAgentSafe,
            archiveAgentKeys,
            abi.encodeCall(ocArtifact.originalArtifactChunkCoverage, (leafCoverage, uint32(0))),
            abi.encode(part)
        );
        _read(
            archiveAgentSafe,
            archiveAgentKeys,
            abi.encodeCall(ocArtifact.currentArtifactEnvironment, ()),
            _expectedEnvironment()
        );
        _reject(abi.encodeCall(ocArtifact.originalArtifactChunkCoverage, (bytes32(0), uint32(0))));
        _reject(
            abi.encodeCall(
                ocArtifact.originalArtifactChunkCoverage,
                (keccak256("unknown completion"), uint32(0))
            )
        );
        _reject(
            abi.encodeCall(ocArtifact.originalArtifactChunkCoverage, (leafCoverage, c.chunkCount))
        );
        bytes32 validation = ocArtifact.currentCoverageValidation(leafCoverage).validationRecordHash;
        require(validation != 0 && validation != leafCoverage, "validation is a separate identity");
        _reject(abi.encodeCall(ocArtifact.originalArtifactChunkCoverage, (validation, uint32(0))));
        require(
            keccak256(abi.encode(ocArtifact.coverage(leafCoverage))) == keccak256(abi.encode(c)),
            "original completion unchanged"
        );
    }

    function testSafeHistoricalPartSurvivesCurrentGraphFailureAndExactSignedRetry() public {
        bytes memory expected = _expectedEnvironment();
        bytes32 part = ocArtifact.originalArtifactChunkCoverage(leafCoverage, 0);
        bytes memory transaction =
            _transaction(abi.encodeCall(ocArtifact.currentArtifactEnvironment, ()));
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 kind = keccak256("ARTWORK_FINALITY_REGISTRY");
        address target = core.selected(kind);
        core.setPointer(kind, address(0));
        (bool ok,) = address(archiveAgentSafe).call(transaction);
        require(!ok && archiveAgentSafe.nonce() == nonce, "current graph failure rolls back Safe");
        // A second actual Safe reads history without consuming the signed retry's nonce.
        _read(
            archiveFixitySafe,
            archiveFixityKeys,
            abi.encodeCall(ocArtifact.originalArtifactChunkCoverage, (leafCoverage, uint32(0))),
            abi.encode(part)
        );
        core.setPointer(kind, target);
        bytes memory result;
        (ok, result) = address(archiveAgentSafe).call(transaction);
        require(
            ok && result.length == 32 && abi.decode(result, (bool))
                && archiveAgentSafe.nonce() == nonce + 1,
            "identical original Safe retry commits once"
        );
        _read(
            archiveAgentSafe,
            archiveAgentKeys,
            abi.encodeCall(ocArtifact.currentArtifactEnvironment, ()),
            expected
        );
        _read(
            archiveAgentSafe,
            archiveAgentKeys,
            abi.encodeCall(ocArtifact.originalArtifactChunkCoverage, (leafCoverage, uint32(0))),
            abi.encode(part)
        );
    }
}
