// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    IStreamStaticC2PAAttribution as OptionalC2PA
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticC2PAAttribution.sol";
import {
    IStreamC2PAReconciliation as C2PAReport
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamC2PAConflicts as CF,
    IStreamStaticC2PAConflicts as SCF
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";

/// @dev Deliberately adversarial typed source, not a report verifier or original Artist producer.
contract C2PARenderSourceBoundary {
    address public core;
    address public router;
    bytes private response;
    bool private conflictsEnabled;
    bytes private conflictResponse;

    function enableConflicts() external {
        conflictsEnabled = true;
    }

    function setConflicts(bytes memory raw) external {
        conflictResponse = raw;
    }

    function attributionC2PAConflicts(uint256, uint256)
        external
        view
        returns (CF.Standing memory, CF.Standing memory)
    {
        bytes memory raw = conflictResponse;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    constructor(address c, address r) {
        core = c;
        router = r;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return
            id == type(OptionalC2PA).interfaceId
                || (conflictsEnabled && id == type(SCF).interfaceId);
    }

    function setResponse(bytes memory raw) external {
        response = raw;
    }

    function attributionWithC2PA(uint256, uint256)
        external
        view
        returns (bytes memory, C2PAReport.Display memory, bytes32)
    {
        bytes memory raw = response;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

/// @notice Actual Renderer/Encoding/Router/Metadata with explicit inherited Core, Artist,
/// governance and version-admission boundaries. No C2PA cryptographic validation is claimed.
contract StreamStaticC2PARenderingTest is StaticMetadataRoutingFixture {
    function testOriginalCompanionNeverAddsC2PAFields() public {
        require(!renderer.c2paAttributionEnabled());
        _activate();
        _mint();
        string memory output = router.tokenJSON(91);
        require(_has(output, '"attribution":{"state":"disputed"}'));
        require(!_has(output, "c2pa_"));
    }

    function testTypedOptionalFieldsPreserveOriginalArtistAndSeparateReportStatus() public {
        C2PARenderSourceBoundary boundary = _optional();
        C2PAReport.Display memory d = _display();
        boundary.setResponse(_encoded(d));
        _activate();
        _mint();
        string memory output = router.tokenJSON(91);
        require(_has(output, '"attribution":{"state":"disputed"}'));
        require(_has(output, '"c2pa_validation_status":"valid"'));
        require(_has(output, '"c2pa_authorship_status":"consistent"'));
        require(_has(output, '"c2pa_attribution_divergence":false'));
        require(_has(output, '"c2pa_basis":"selected_verifier_report"'));
        require(
            _count(output, '"attribution":') == 1
                && _count(output, '"c2pa_authorship_status":') == 1
        );
        d.authorship = C2PAReport.AuthorshipStatus.DIVERGENT;
        boundary.setResponse(_encoded(d));
        require(_has(router.tokenJSON(91), '"c2pa_attribution_divergence":true'));
    }

    function testStaleFactsAreExplicitlyUnevaluatedWithoutReplacingArtist() public {
        C2PARenderSourceBoundary boundary = _optional();
        C2PAReport.Display memory d = _display();
        d.current = false;
        d.validation = C2PAReport.ValidationStatus.UNEVALUATED;
        d.authorship = C2PAReport.AuthorshipStatus.UNEVALUATED;
        boundary.setResponse(_encoded(d));
        _activate();
        _mint();
        string memory output = router.tokenJSON(91);
        require(_has(output, '"attribution":{"state":"disputed"}'));
        require(_has(output, '"c2pa_authorship_status":"unevaluated"'));
        require(_has(output, '"c2pa_attribution_divergence":null'));
        require(_has(output, '"c2pa_report_current":false'));
    }

    function testMalformedOptionalABIHasOnlyUnavailableOutcome() public {
        C2PARenderSourceBoundary boundary = _optional();
        _activate();
        _mint();
        bytes memory good = _encoded(_display());
        // Independent ABI offsets: bytes offset, six display words, subject, bytes length.
        uint256[5] memory offsets = [uint256(0), 96, 128, 160, 192];
        uint256[5] memory invalid = [uint256(288), 3, 3, 2, 2];
        for (uint256 i; i < offsets.length; ++i) {
            bytes memory bad = abi.decode(abi.encode(good), (bytes));
            uint256 at = offsets[i];
            uint256 value = invalid[i];
            assembly ("memory-safe") { mstore(add(add(bad, 32), at), value) }
            boundary.setResponse(bad);
            _unavailable();
        }
        boundary.setResponse(bytes.concat(good, bytes32(0)));
        _unavailable();
        bytes memory padding = abi.decode(abi.encode(good), (bytes));
        padding[padding.length - 1] = 0x01;
        boundary.setResponse(padding);
        _unavailable();
        boundary.setResponse(good);
        require(
            _has(router.tokenJSON(91), '"c2pa_authorship_status":"consistent"'),
            "exact source retry"
        );
    }

    function testUnsupportedOrContradictoryTypedFactsCannotClaimConsistency() public {
        C2PARenderSourceBoundary boundary = _optional();
        _activate();
        _mint();
        C2PAReport.Display memory d = _display();
        d.assertsAuthorship = false;
        boundary.setResponse(_encoded(d));
        _unavailable();
        d = _display();
        d.validation = C2PAReport.ValidationStatus.INVALID;
        boundary.setResponse(_encoded(d));
        _unavailable();
        d = _display();
        d.current = false;
        boundary.setResponse(_encoded(d));
        _unavailable();
        d = _display();
        d.selectionHash = 0;
        boundary.setResponse(_encoded(d));
        _unavailable();
    }

    function _optional() private returns (C2PARenderSourceBoundary boundary) {
        return _optionalMode(false);
    }

    function _optionalMode(bool conflicts) private returns (C2PARenderSourceBoundary boundary) {
        boundary = new C2PARenderSourceBoundary(address(core), address(router));
        if (conflicts) boundary.enableConflicts();
        StreamRendererV1.Deployment memory d;
        (d.sources,) = renderer.sourceBindings();
        d.sources.attribution = address(boundary);
        d.executor = address(executor);
        d.manifest = renderer.rendererManifest();
        d.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        d.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        renderer = new StreamRendererV1(d);
        require(renderer.c2paAttributionEnabled());
        versions = new StaticRouteVersions(address(executor), address(schemas), address(renderer));
        modules = new StaticRouteModules(address(metadata), address(versions));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
    }

    function testStandingCollectionConflictCannotBeHiddenByCurrentTokenReport() public {
        C2PARenderSourceBoundary boundary = _optionalMode(true);
        CF.Standing memory empty;
        CF.Standing memory standing = CF.Standing(
            keccak256("conflict"),
            keccak256("chain"),
            keccak256("record"),
            keccak256("selection"),
            1,
            1
        );
        boundary.setResponse(_encoded(_display()));
        boundary.setConflicts(abi.encode(empty, standing));
        _activate();
        _mint();
        string memory output = router.tokenJSON(91);
        require(_has(output, '"c2pa_attribution_divergence":true'));
        require(_has(output, '"c2pa_authorship_status":"consistent"'));
        require(_has(output, '"attribution":{"state":"disputed"}'));
        // Credential/report staleness changes live status but cannot erase a standing record.
        C2PAReport.Display memory stale = _display();
        stale.current = false;
        stale.validation = C2PAReport.ValidationStatus.UNEVALUATED;
        stale.authorship = C2PAReport.AuthorshipStatus.UNEVALUATED;
        boundary.setResponse(_encoded(stale));
        require(_has(router.tokenJSON(91), '"c2pa_attribution_divergence":true'));
    }

    function testMalformedConflictTupleDegradesWithoutSilentlyClaimingClear() public {
        C2PARenderSourceBoundary boundary = _optionalMode(true);
        boundary.setResponse(_encoded(_display()));
        CF.Standing memory empty;
        bytes memory good = abi.encode(empty, empty);
        boundary.setConflicts(good);
        _activate();
        _mint();
        uint256[4] memory offsets = [uint256(128), 160, 320, 352];
        for (uint256 i; i < 4; ++i) {
            bytes memory bad = abi.decode(abi.encode(good), (bytes));
            uint256 at = offsets[i];
            assembly ("memory-safe") { mstore(add(add(bad, 32), at), not(0)) }
            boundary.setConflicts(bad);
            string memory output = router.tokenJSON(91);
            require(_has(output, '"c2pa_conflict_read_unavailable":true'));
            require(_has(output, '"c2pa_attribution_divergence":null'));
            require(_has(output, '"attribution":{"state":"disputed"}'));
        }
        boundary.setConflicts(bytes.concat(good, bytes32(0)));
        require(_has(router.tokenJSON(91), '"c2pa_conflict_read_unavailable":true'));
        boundary.setConflicts(good);
        require(_has(router.tokenJSON(91), '"c2pa_conflict_state":"none"'));
    }

    function _display() private pure returns (C2PAReport.Display memory) {
        return C2PAReport.Display(
            keccak256("report"),
            keccak256("selection"),
            C2PAReport.ValidationStatus.VALID,
            C2PAReport.AuthorshipStatus.CONSISTENT,
            true,
            true
        );
    }

    function _encoded(C2PAReport.Display memory d) private pure returns (bytes memory) {
        return abi.encode(bytes('{"state":"disputed"}'), d, keccak256("subject"));
    }

    function _unavailable() private view {
        string memory output = router.tokenJSON(91);
        require(_has(output, '"state":"attribution_unavailable"'));
        require(_has(output, '"c2pa_read_unavailable":true'));
        require(!_has(output, '"c2pa_authorship_status":"consistent"'));
    }

    function _count(string memory value, string memory needle)
        private
        pure
        returns (uint256 count)
    {
        bytes memory a = bytes(value);
        bytes memory b = bytes(needle);
        for (uint256 i; i + b.length <= a.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) ++count;
        }
    }
}
