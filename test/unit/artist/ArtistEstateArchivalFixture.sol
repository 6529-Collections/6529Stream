// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";

interface EstateGovernanceFixture {
    function configureContestReads(address, address, bytes32, string calldata) external;
    function executeModuleContext(address, bytes calldata, uint8, bytes32, bytes32, bytes32)
        external;
}

interface EstateArchivalVm {
    function parseJsonUint(string calldata, string calldata) external pure returns (uint256);
}

/// @dev Actual preservation/RoleRegistry products with synthetic quorum data and an explicit
/// governance/Core unit boundary. This does not claim a network rehearsal or actual Executor delay.
abstract contract ArtistEstateArchivalFixture is OfficialSafeFixture {
    bool internal estateNetworkVector;
    StreamArchivalCoverage internal estateCoverageProvider;
    StreamArweaveCheckpointVerifier internal estateCheckpointVerifier;
    StreamRoleRegistry internal estateFixityRoles;
    EstateGovernanceFixture private estateGovernance;
    uint256 private constant OBSERVER_A = 0xE5701;
    uint256 private constant OBSERVER_B = 0xE5702;
    uint256 private constant AGENT_A = 0xE5703;
    uint256 private constant AGENT_B = 0xE5704;
    uint256 private constant FIXITY = 0xE5705;

    function _deployEstateArchival(address core, address governance) internal {
        estateGovernance = EstateGovernanceFixture(governance);
        estateFixityRoles = new StreamRoleRegistry(governance);
        estateGovernance.configureContestReads(
            address(estateFixityRoles),
            address(this),
            keccak256("archival fixture"),
            "urn:unit:archival"
        );
        A.Observer[] memory observers = new A.Observer[](2);
        observers[0] = A.Observer(safeVm.addr(OBSERVER_A), keccak256("estate observer A"));
        observers[1] = A.Observer(safeVm.addr(OBSERVER_B), keccak256("estate observer B"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        IStreamGasParameterHost.GasParameterConfig memory sig =
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            );
        estateCheckpointVerifier =
            new StreamArweaveCheckpointVerifier(governance, observers, 2, sig);
        estateCoverageProvider = new StreamArchivalCoverage(
            core,
            governance,
            address(estateFixityRoles),
            address(estateCheckpointVerifier),
            sig,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
    }

    function _estateArchiveEvidence(bytes32 artistId)
        internal
        returns (bytes32 evidence, bytes32 coverage)
    {
        _estateGrantFixity();
        bytes32 first = _estateFamily(true);
        bytes32 second = _estateFamily(false);
        string memory json = safeVm.readFile(
            estateNetworkVector
                ? "test/fixtures/preservation/arweave-mainnet-899979.json"
                : "test/fixtures/preservation/arweave-single-chunk-v1.json"
        );
        string memory prefix = estateNetworkVector ? "." : ".second.";
        bytes memory payload = safeVm.parseJsonBytes(json, string.concat(prefix, "payload"));
        evidence = keccak256(payload);
        A.Checkpoint memory c;
        c.networkId = estateCheckpointVerifier.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        if (estateNetworkVector) {
            c.blockHash = safeVm.parseJsonBytes(json, ".blockHash");
            c.blockHeight =
                uint64(EstateArchivalVm(address(safeVm)).parseJsonUint(json, ".blockHeight"));
        }
        c.transactionRoot =
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, "transactionRoot")));
        EstateArchivalVm parser = EstateArchivalVm(address(safeVm));
        c.blockDataSize = parser.parseJsonUint(json, string.concat(prefix, "blockDataSize"));
        c.transactionId = estateNetworkVector
            ? bytes32(safeVm.parseJsonBytes(json, ".transactionId"))
            : keccak256("estate synthetic network transaction");
        c.dataRoot = bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, "dataRoot")));
        c.dataSize = uint64(payload.length);
        c.transactionStart = parser.parseJsonUint(json, string.concat(prefix, "transactionStart"));
        c.transactionEnd = parser.parseJsonUint(json, string.concat(prefix, "transactionEnd"));
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = estateCheckpointVerifier.configurationHash();
        bytes32 digest = estateCheckpointVerifier.checkpointDigest(c);
        A.ObserverProof[] memory certificate = new A.ObserverProof[](2);
        certificate[0] = A.ObserverProof(safeVm.addr(OBSERVER_A), _estateSign(OBSERVER_A, digest));
        certificate[1] = A.ObserverProof(safeVm.addr(OBSERVER_B), _estateSign(OBSERVER_B, digest));
        if (certificate[0].account > certificate[1].account) {
            (certificate[0], certificate[1]) = (certificate[1], certificate[0]);
        }
        bytes32 checkpoint = estateCheckpointVerifier.recordCheckpoint(
            c,
            safeVm.parseJsonBytes(json, string.concat(prefix, "transactionPath")),
            safeVm.parseJsonBytes(json, string.concat(prefix, "dataPath")),
            payload,
            certificate
        );
        A.Envelope memory envelope = A.Envelope(
            artistId,
            evidence,
            keccak256("6529STREAM_PUBLIC_ESTATE_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            0
        );
        bytes32 envelopeHash = estateCoverageProvider.recordEnvelope(envelope, payload);
        bytes32 firstReceipt = _estateReceipt(
            envelopeHash, first, checkpoint, abi.encodePacked(c.transactionId), AGENT_A, true
        );
        bytes32 secondReceipt = _estateReceipt(
            envelopeHash,
            second,
            bytes32(0),
            abi.encodePacked(bytes4(0x01551220), envelope.payloadDigest),
            AGENT_B,
            false
        );
        _estateFixity(firstReceipt, envelope, 0);
        _estateFixity(secondReceipt, envelope, 1);
        coverage = estateCoverageProvider.recordCoverage(firstReceipt, secondReceipt);
        require(
            estateCoverageProvider.requireCoverage(coverage, artistId, evidence).coverageRecordHash
                == coverage,
            "actual complete coverage"
        );
    }

    function _estateFamily(bool endowed) private returns (bytes32 hash) {
        string memory name = endowed ? "estate-arweave" : "estate-ipfs";
        bytes memory salt = bytes(name);
        A.Family memory f = A.Family(
            keccak256(salt),
            endowed ? estateCheckpointVerifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256(bytes.concat(salt, "jurisdiction")),
            endowed ? 1 : 2,
            safeVm.addr(endowed ? AGENT_A : AGENT_B),
            endowed
                ? estateCheckpointVerifier.profileHash()
                : estateCoverageProvider.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = estateCoverageProvider.familyRegistrationContext(name, f);
        estateGovernance.executeModuleContext(
            address(estateCoverageProvider),
            abi.encodeCall(estateCoverageProvider.admitFamily, (name, f)),
            1,
            scope,
            oldHash,
            newHash
        );
    }

    function _estateReceipt(
        bytes32 envelope,
        bytes32 family,
        bytes32 checkpoint,
        bytes memory identifier,
        uint256 key,
        bool endowed
    ) private returns (bytes32) {
        A.ReceiptTerms memory r = A.ReceiptTerms(
            envelope,
            family,
            keccak256(identifier),
            keccak256(bytes(endowed ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            endowed
                ? estateCheckpointVerifier.profileHash()
                : estateCoverageProvider.POSSESSION_PROFILE(),
            checkpoint,
            safeVm.addr(key),
            uint64(block.timestamp),
            0,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = estateCoverageProvider.possessionHash(
                A.Possession(envelope, family, r.storageIdentifierHash, r.writer, r.observedAt)
            );
        }
        return estateCoverageProvider.recordReceipt(
            r, identifier, _estateSign(key, estateCoverageProvider.receiptDigest(r))
        );
    }

    function _estateFixity(bytes32 receipt, A.Envelope memory e, uint256 nonce) private {
        (A.ReceiptTerms memory r,,) = estateCoverageProvider.receipt(receipt);
        A.FixityTerms memory f = A.FixityTerms(
            receipt,
            r.envelopeHash,
            r.familyRecordHash,
            e.payloadDigest,
            e.payloadDigest,
            e.byteSize,
            uint64(block.timestamp),
            1,
            keccak256(abi.encode("estate fixity", receipt)),
            0,
            0,
            safeVm.addr(FIXITY),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        estateCoverageProvider.recordFixity(
            f, _estateSign(FIXITY, estateCoverageProvider.fixityDigest(f))
        );
    }

    function _estateSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _estateGrantFixity() private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        address holder = safeVm.addr(FIXITY);
        (bytes32 chain, uint64 revision) = estateFixityRoles.roleMutationState(role);
        (bytes32 global, uint64 globalRevision) = estateFixityRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(estateFixityRoles),
                role,
                holder
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(estateFixityRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                global,
                block.chainid,
                address(estateFixityRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 oldHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(estateFixityRoles),
                scope,
                false,
                chain,
                revision,
                global,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(estateFixityRoles),
                scope,
                true,
                next,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        estateGovernance.executeModuleContext(
            address(estateFixityRoles),
            abi.encodeCall(estateFixityRoles.grantRole, (role, holder)),
            1,
            scope,
            oldHash,
            newHash
        );
    }
}
