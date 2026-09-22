// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistCompleteHistoryBindingImport as CHBindingImport
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingImport.sol";
import {
    StreamArtistCompleteHistoryCollectionImport as CHCollectionImport
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCollectionImport.sol";
import {
    StreamArtistBindingCorrectionState as CHCorrectionState
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistCompleteHistoryIdentityImport as CHIdentityImport
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryIdentityImport.sol";
import {
    StreamArtistCompleteHistoryPayoutImport as CHPayoutImport
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPayoutImport.sol";
import {
    StreamArtistRecoveredHydrationTypes as CHRH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @dev Storage-only host for the real dispatch entry points. No alternate decoder or
/// raw-inventory apply surface is exposed; this harness tests only nonselected routing.
contract CompleteHistoryImportSelectionHarness {
    mapping(uint256 => T.Binding) private current;
    mapping(uint256 => mapping(uint64 => T.Binding)) private history;
    mapping(uint256 => mapping(uint64 => C.BindingTerms)) private terms;
    mapping(uint256 => mapping(uint64 => L.Terminal)) private terminals;
    mapping(bytes32 => CHCorrectionState.Correction) private corrections;
    mapping(uint256 => mapping(uint64 => T.CollaboratorRecord[])) private rows;
    mapping(bytes32 => C.IdentityProposalState) private proposals;
    mapping(bytes32 => C.Join) private joins;
    mapping(bytes32 => uint32) private counts;
    mapping(bytes32 => mapping(address => bool)) private links;
    mapping(bytes32 => bytes32) private primary;
    mapping(bytes32 => uint64) private times;
    mapping(bytes32 => bytes32) private accepted;

    function seed(bytes32 key, address account) external {
        current[1].artistId = key;
        history[1][1].bindingHash = key;
        terms[1][1].count = 1;
        terminals[1][1].kind = 1;
        corrections[key].recordHash = key;
        rows[1][1].push(T.CollaboratorRecord(account, key, key));
        proposals[key].acceptedArtistId = key;
        joins[key].acceptanceRecordHash = key;
        counts[key] = 1;
        links[key][account] = true;
        primary[key] = key;
        times[key] = 7;
        accepted[key] = key;
    }

    function state(bytes32 key, address account) external view returns (bytes32) {
        bytes32 binding = keccak256(
            abi.encode(
                current[1],
                history[1][1],
                terms[1][1],
                terminals[1][1],
                corrections[key],
                rows[1][1]
            )
        );
        bytes32 collaborators =
            keccak256(abi.encode(proposals[key], joins[key], counts[key], links[key][account]));
        return
            keccak256(abi.encode(binding, collaborators, primary[key], times[key], accepted[key]));
    }

    function route(uint8 owner, AH.Query memory anchor, bytes memory outer)
        external
        returns (bool)
    {
        if (owner == 0) {
            return CHBindingImport.applyState(
                current, history, terms, terminals, corrections, rows, anchor, outer
            );
        }
        if (owner == 1) {
            return CHCollectionImport.collaborators(proposals, joins, counts, links, anchor, outer);
        }
        require(owner == 3, "supported harness owner");
        return CHCollectionImport.acceptances(primary, times, accepted, anchor, outer);
    }

    function principal(uint8 owner, AH.Query memory anchor, bytes memory outer) external {
        // Distinct empty storage slots for the original opaque-root APIs. This harness
        // only exercises envelope rejection and cannot bypass the fixed source decoder.
        if (owner == 2) {
            uint256[17] memory roots;
            for (uint256 i; i < roots.length; ++i) {
                roots[i] = 1000 + i;
            }
            CHIdentityImport.importState(roots, anchor, outer, bytes32(0));
        } else {
            require(owner == 5, "supported principal owner");
            uint256[6] memory roots;
            for (uint256 i; i < roots.length; ++i) {
                roots[i] = 2000 + i;
            }
            CHPayoutImport.importState(roots, anchor, outer);
        }
    }
}

/// @notice Authentic old-PC owner envelopes remain outside the new import workers.
/// @dev This is a routing regression, not a complete-history import or mapping-acceptance proof.
contract StreamArtistCompleteHistoryImportSelectionActualTest is ArtistPrimaryCollaboratorFixture {
    function testCompleteImportWorkersDeclineOriginalPCEnvelopesWithoutTouchingStorage() external {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _pcPrepare(next);
        CompleteHistoryImportSelectionHarness host = new CompleteHistoryImportSelectionHarness();
        bytes32 key = keccak256("existing destination sentinel");
        host.seed(key, address(artist));
        bytes32 before_ = host.state(key, address(artist));
        require(!host.route(0, p.query, p.data[0].typedState), "old owner0 profile not selected");
        require(!host.route(1, p.query, p.data[1].typedState), "old owner1 profile not selected");
        require(!host.route(3, p.query, p.data[3].typedState), "old owner3 profile not selected");
        require(host.state(key, address(artist)) == before_, "all original target maps unchanged");
    }

    function testCompletePrincipalImportWorkersRejectOriginalPCEnvelopesAtProfileBoundary()
        external
    {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _pcPrepare(next);
        CompleteHistoryImportSelectionHarness host = new CompleteHistoryImportSelectionHarness();
        bytes32 key = keccak256("existing destination principal sentinel");
        host.seed(key, address(artist));
        bytes32 before_ = host.state(key, address(artist));
        _principalProfileRejects(host, 2, p.query, p.data[2].typedState);
        _principalProfileRejects(host, 5, p.query, p.data[5].typedState);
        require(host.state(key, address(artist)) == before_, "original target maps unchanged");
    }

    function _principalProfileRejects(
        CompleteHistoryImportSelectionHarness host,
        uint8 owner,
        AH.Query memory anchor,
        bytes memory outer
    ) private {
        (bool ok, bytes memory reason) = address(host)
            .call(
                abi.encodeCall(
                    CompleteHistoryImportSelectionHarness.principal, (owner, anchor, outer)
                )
            );
        require(!ok, "original profile cannot enter complete-history principal import");
        require(
            keccak256(reason)
                == keccak256(
                    abi.encodeWithSelector(CHRH.InvalidRecoveredHydrationProfile.selector)
                ),
            "explicit profile rejection precedes destination or source checks"
        );
    }
}
