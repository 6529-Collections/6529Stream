// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityCoordinatorPolicyReads.t.sol";
import "../entropy/EntropyCollectionPolicyFixtures.sol";
import {
    IStreamEntropyCollectionPolicy as TerminalPolicy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as V2
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Interface
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyEvidenceV2,
    StreamFinalityCoordinatorPolicyV2
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import {
    IStreamFinalityEntropySourceSet as Legacy
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceSet.sol";

contract TerminalPolicyEvidenceReader {
    function read(V2.Dependencies memory d, StreamFinalityScope memory scope, bytes32 plan)
        external
        view
        returns (StreamFinalityCoordinatorPolicyEvidenceV2 memory)
    {
        return V2.requireCurrent(d, scope, plan);
    }
}

/// @notice Mixed original Coordinators, Metadata/Schema/Store and complete native inventories.
/// Core identity, original Artist consent and governance are explicit typed boundaries. This is
/// source/policy readiness evidence, not rendered-output or reference-publication acceptance.
contract StreamTerminalEntropySourceSetTest is StreamFinalityCoordinatorPolicyReadsTest {
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");

    function testV2MixedSourcesKeepOriginalV1LeafAndFullExplicitPolicyIdentity() public {
        (Fixture memory f, SourceSet source) = _mixed();
        StreamFinalityCoordinatorPolicyEvidenceV2 memory e =
            new TerminalPolicyEvidenceReader().read(_v2(f), _scope(), f.plan);
        require(
            e.allFrozen && e.policyCount == 2 && source.sourceCount() == 2,
            "complete two-source policy inventory"
        );
        StreamFinalityCoordinatorPolicyV2 memory explicit_ = e.policies[0];
        TerminalPolicy.PolicyRecord memory p =
            TerminalPolicy(address(f.first)).collectionEntropyPolicy(1);
        require(
            explicit_.explicitPolicy && explicit_.provider == address(0) && explicit_.epoch == 0
                && explicit_.salt == 0,
            "no V1 policy fabrication"
        );
        require(
            keccak256(abi.encode(explicit_.collectionPolicy)) == keccak256(abi.encode(p)),
            "all original explicit words"
        );
        require(
            explicit_.componentDataHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2"),
                        block.chainid,
                        address(core),
                        address(f.first),
                        _scope(),
                        p
                    )
                ),
            "literal V2 preimage"
        );
        StreamFinalityCoordinatorPolicyV2 memory old = e.policies[1];
        (bool frozen, bytes32 h, address provider, uint32 epoch, bytes32 salt) =
            f.second.entropyPolicyFrozen(1);
        require(
            !old.explicitPolicy && old.frozen == frozen && old.policyHash == h
                && old.provider == provider && old.epoch == epoch && old.salt == salt,
            "original V1 facts"
        );
        require(
            old.componentDataHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"),
                        block.chainid,
                        address(core),
                        address(f.second),
                        _scope(),
                        h,
                        provider,
                        epoch,
                        salt
                    )
                ),
            "original V1 leaf exact"
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
        require(
            !source.supportsInterface(type(Legacy).interfaceId),
            "never aliases original seed-ready profile"
        );
        (bool ok,) = address(source)
            .staticcall(abi.encodeWithSignature("tokenSeedForFinality(uint256)", f.ids[0]));
        require(!ok, "legacy selector unavailable");
    }

    function testV2TerminalReadinessUsesOriginalAtMintAfterReplacementWithoutFinalizedSeed()
        public
    {
        (Fixture memory f, SourceSet source) = _mixed();
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.second));
        Interface.TokenReadiness memory ready = source.tokenEntropyReadiness(f.ids[0]);
        require(
            ready.coordinator == address(f.first)
                && ready.coordinatorCodeHash == address(f.first).codehash,
            "original token coordinator"
        );
        require(
            ready.terminal && !ready.finalized && ready.seed == 0 && ready.status == 1
                && ready.mode == 0 && ready.renderRequirement == 1,
            "terminal is not random finality"
        );
        Interface.TokenReadiness memory pending = source.tokenEntropyReadiness(f.ids[1]);
        require(
            !pending.terminal && !pending.finalized && pending.seed == 0
                && pending.coordinator == address(f.second),
            "legacy pending retained"
        );
        core.setToken(f.ids[0], 1, 1, 3);
        require(
            source.tokenEntropyReadiness(f.ids[0]).terminal,
            "burn keeps original retained terminal identity"
        );
        cheat.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (f.ids[0])),
            abi.encode(address(this))
        );
        vm.expectRevert();
        source.tokenEntropyReadiness(f.ids[0]);
    }

    function testV2ChangedFullPolicyAndNonzeroLegacySurrogateInvalidateCurrentEvidence() public {
        (Fixture memory f, SourceSet source) = _mixed();
        TerminalPolicy.PolicyRecord memory p =
            TerminalPolicy(address(f.first)).collectionEntropyPolicy(1);
        p.policyHash = keccak256("foreign full policy");
        p.contentStateHash = keccak256(abi.encode(FAMILY, p.policyHash, true));
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(TerminalPolicy.collectionEntropyPolicy, (uint256(1))),
            abi.encode(p)
        );
        vm.expectRevert();
        source.requireCurrentSourceSet();
        vm.expectRevert();
        source.tokenEntropyReadiness(f.ids[0]);
    }

    function testV2RefusesExplicitPolicyPresentedThroughLegacyFiveWordProfile() public {
        (Fixture memory f, SourceSet source) = _mixed();
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(IStreamEntropyFinalityPolicy.entropyPolicyFrozen, (uint256(1))),
            abi.encode(true, bytes32(uint256(1)), address(f.second), uint32(1), bytes32(uint256(2)))
        );
        vm.expectRevert();
        source.requireCurrentSourceSet();
    }

    function testV2HistoricalPrefixRemainsReadableButExpandedInventoryIsNotCurrent() public {
        (Fixture memory f, SourceSet source) = _mixed();
        core.setToken(9, 1, 3, 2);
        uint256[] memory one = new uint256[](1);
        one[0] = 9;
        cheat.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (uint256(9))),
            abi.encode(address(f.first))
        );
        inventory.appendCollectionTokens(1, one);
        vm.expectRevert();
        source.requireCurrentSourceSet();
        vm.expectRevert();
        source.tokenEntropyReadiness(9);
        require(
            source.tokenEntropyReadiness(f.ids[0]).terminal,
            "old ordinal prefix and policy remain observable"
        );
    }

    function _mixed() private returns (Fixture memory f, SourceSet source) {
        f.first = _native(false);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.first));
        EntropyCollectionPolicyArtistFixture explicitArtist =
            new EntropyCollectionPolicyArtistFixture(address(core));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(explicitArtist));
        TerminalPolicy.PolicyInput memory input;
        input.renderRequirement = TerminalPolicy.RenderRequirement.NOT_REQUIRED;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            TerminalPolicy(address(f.first)).collectionEntropyPolicyTransition(1, input);
        explicitArtist.approve(
            1, address(f.first), FAMILY, content, keccak256("actual recorded consent fixture")
        );
        this.setCurrentAction(
            true, keccak256("policy configure fixture"), 1, scope, oldHash, newHash
        );
        TerminalPolicy(address(f.first)).configureCollectionEntropyPolicy(1, input);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        // The actual token hooks below freeze both policies; no unrelated scope is needed.
        f.second = _native(false);
        f.sources = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 100000, 2000000
        );
        f.reader = new FixedCoordinatorPolicyConsumer(_dependencies(f.sources));
        f.ids = _tokens(2);
        _index(f.ids, 0, 2);
        for (uint256 i; i < 2; ++i) {
            StreamEntropyCoordinator chosen = i == 0 ? f.first : f.second;
            core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(chosen));
            cheat.mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (f.ids[i])),
                abi.encode(address(chosen))
            );
            vm.prank(address(core));
            chosen.onTokenMinted(
                1, f.ids[i], address(this), keccak256(abi.encode("terminal mixture", i))
            );
        }
        f.plan = f.sources.beginInventory(_scope());
        f.sources.appendInventory(f.plan, 256);
        source = new SourceSet(_v2(f), _scope(), f.plan);
    }

    function _v2(Fixture memory f) private view returns (V2.Dependencies memory d) {
        StreamFinalityCoordinatorPolicyReads.Dependencies memory old = _dependencies(f.sources);
        d.targets = old.targets;
        d.codeHashes = old.codeHashes;
        d.chainId = old.chainId;
        d.readGas = old.readGas;
        d.inventoryGas = old.inventoryGas;
    }
}
