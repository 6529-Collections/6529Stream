// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamStaticC2PAAttributionCompanion
} from "../../../smart-contracts/domains/metadata/StreamStaticC2PAAttributionCompanion.sol";
import {
    IStreamC2PAReconciliation as C2PA
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface C2PACompanionVm {
    function expectRevert() external;
    function etch(address, bytes calldata) external;
}

contract C2PAOriginalBoundary {
    address public core = address(this);
    address public router = address(this);
    address public artist = address(this);

    function attribution(uint256, uint256) external pure returns (bytes memory) {
        return '{"state":"accepted","primary_artist":{"display_name":"Original Artist"}}';
    }
}

contract C2PAReportsBoundary {
    address public core;
    address public router;
    address public artist;
    mapping(bytes32 => C2PA.Display) private facts;

    constructor(address a) {
        core = a;
        router = a;
        artist = a;
    }

    function set(bytes32 subject, C2PA.Display memory d) external {
        facts[subject] = d;
    }

    function display(uint256, bytes32 subject) external view returns (C2PA.Display memory) {
        return facts[subject];
    }
}

/// @notice Actual bounded companion transport with explicit report/Artist source boundaries.
contract StreamStaticC2PACompanionTest {
    C2PACompanionVm constant vm =
        C2PACompanionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    C2PAOriginalBoundary original;
    C2PAReportsBoundary reports;
    StreamStaticC2PAAttributionCompanion companion;

    function setUp() public {
        original = new C2PAOriginalBoundary();
        reports = new C2PAReportsBoundary(address(original));
        companion = new StreamStaticC2PAAttributionCompanion(
            address(original),
            address(reports),
            address(0),
            G.GasParameterConfig("C2PA_STATIC_ARTIST_GAS", 200000, 100000, 2),
            G.GasParameterConfig("C2PA_STATIC_REPORT_GAS", 300000, 100000, 2)
        );
    }

    function testAbsentReportsPreserveExactOriginalArtistBytes() public view {
        (bytes memory value, C2PA.Display memory d, bytes32 subject) =
            companion.attributionWithC2PA(1, 91);
        require(keccak256(value) == keccak256(original.attribution(1, 91)));
        require(keccak256(companion.attribution(1, 91)) == keccak256(value));
        require(d.recordHash == 0 && subject == _subject(false));
    }

    function testTokenReportHasPrecedenceIncludingStaleTokenReport() public {
        reports.set(_subject(false), _display(keccak256("collection"), true));
        reports.set(_subject(true), _display(keccak256("token"), false));
        (bytes memory value, C2PA.Display memory d, bytes32 subject) =
            companion.attributionWithC2PA(1, 91);
        require(keccak256(value) == keccak256(original.attribution(1, 91)));
        require(subject == _subject(true) && d.recordHash == keccak256("token") && !d.current);
        require(d.authorship == C2PA.AuthorshipStatus.UNEVALUATED);
        reports.set(_subject(true), _display(0, false));
        (, d, subject) = companion.attributionWithC2PA(1, 91);
        require(subject == _subject(false) && d.recordHash == keccak256("collection") && d.current);
    }

    function testCodeDriftIsUnavailableAndRestoringExactRuntimeRestoresRead() public {
        bytes memory code = address(reports).code;
        vm.etch(address(reports), hex"00");
        vm.expectRevert();
        companion.attributionWithC2PA(1, 91);
        vm.etch(address(reports), code);
        (bytes memory value,,) = companion.attributionWithC2PA(1, 91);
        require(keccak256(value) == keccak256(original.attribution(1, 91)));
    }

    function testForeignConstructorRelationshipsAreRejected() public {
        C2PAReportsBoundary foreign = new C2PAReportsBoundary(address(this));
        vm.expectRevert();
        new StreamStaticC2PAAttributionCompanion(
            address(original),
            address(foreign),
            address(0),
            G.GasParameterConfig("C2PA_STATIC_ARTIST_GAS", 200000, 100000, 2),
            G.GasParameterConfig("C2PA_STATIC_REPORT_GAS", 300000, 100000, 2)
        );
    }

    function _display(bytes32 record, bool current) private pure returns (C2PA.Display memory d) {
        if (record == 0) return d;
        d.recordHash = record;
        d.selectionHash = keccak256(abi.encode(record));
        d.current = current;
        d.assertsAuthorship = true;
        if (current) {
            d.validation = C2PA.ValidationStatus.VALID;
            d.authorship = C2PA.AuthorshipStatus.CONSISTENT;
        }
    }

    function _subject(bool token) private view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(original),
            StreamFinalityScope(
                token ? StreamFinalityScopeType.TOKEN : StreamFinalityScopeType.COLLECTION,
                1,
                token ? 91 : 0,
                0
            )
        );
    }
}
