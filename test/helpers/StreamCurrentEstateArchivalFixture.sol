// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";

interface CurrentEstateArchivalVm {
    function parseJsonUint(string calldata, string calldata) external pure returns (uint256);
}

/// @notice Actual current artist coverage with real delayed governance and exact archived bytes.
/// @dev Uses the retained Arweave network inclusion fixture with locally signed observer evidence.
///      It establishes contract integration, not external observer independence or a live receipt.
abstract contract StreamCurrentEstateArchivalFixture is StreamCurrentSafeGovernanceFixture {
    bool internal estateNetworkVector = true;
    uint256 private constant AGENT_A = 0xE5703;
    uint256 private constant AGENT_B = 0xE5704;
    uint256 private constant FIXITY = 0xE5705;

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(artistArchivalCoverage),
            artistArchivalCoverage.admitFamily.selector,
            address(artistArchivalCoverage).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(artistArchivalCoverage))),
            1,
            0,
            0,
            bytes32(0)
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
        c.networkId = artistArchivalCheckpoint.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        if (estateNetworkVector) {
            c.blockHash = safeVm.parseJsonBytes(json, ".blockHash");
            c.blockHeight = uint64(
                CurrentEstateArchivalVm(address(safeVm)).parseJsonUint(json, ".blockHeight")
            );
        }
        c.transactionRoot =
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, "transactionRoot")));
        CurrentEstateArchivalVm parser = CurrentEstateArchivalVm(address(safeVm));
        c.blockDataSize = parser.parseJsonUint(json, string.concat(prefix, "blockDataSize"));
        c.transactionId = estateNetworkVector
            ? bytes32(safeVm.parseJsonBytes(json, ".transactionId"))
            : keccak256("estate synthetic network transaction");
        c.dataRoot = bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, "dataRoot")));
        c.dataSize = uint64(payload.length);
        c.transactionStart = parser.parseJsonUint(json, string.concat(prefix, "transactionStart"));
        c.transactionEnd = parser.parseJsonUint(json, string.concat(prefix, "transactionEnd"));
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = artistArchivalCheckpoint.configurationHash();
        bytes32 digest = artistArchivalCheckpoint.checkpointDigest(c);
        A.ObserverProof[] memory certificate = new A.ObserverProof[](2);
        certificate[0] = A.ObserverProof(
            safeVm.addr(ARCHIVAL_OBSERVER_ONE), _estateSign(ARCHIVAL_OBSERVER_ONE, digest)
        );
        certificate[1] = A.ObserverProof(
            safeVm.addr(ARCHIVAL_OBSERVER_TWO), _estateSign(ARCHIVAL_OBSERVER_TWO, digest)
        );
        if (certificate[0].account > certificate[1].account) {
            (certificate[0], certificate[1]) = (certificate[1], certificate[0]);
        }
        bytes32 checkpoint = artistArchivalCheckpoint.recordCheckpoint(
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
        bytes32 envelopeHash = artistArchivalCoverage.recordEnvelope(envelope, payload);
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
        coverage = artistArchivalCoverage.recordCoverage(firstReceipt, secondReceipt);
        require(
            artistArchivalCoverage.requireCoverage(coverage, artistId, evidence).coverageRecordHash
                == coverage,
            "actual complete coverage"
        );
    }

    function _estateFamily(bool endowed) private returns (bytes32 hash) {
        string memory name = endowed ? "estate-arweave" : "estate-ipfs";
        bytes memory salt = bytes(name);
        A.Family memory f = A.Family(
            keccak256(salt),
            endowed ? artistArchivalCheckpoint.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256(bytes.concat(salt, "jurisdiction")),
            endowed ? 1 : 2,
            safeVm.addr(endowed ? AGENT_A : AGENT_B),
            endowed
                ? artistArchivalCheckpoint.profileHash()
                : artistArchivalCoverage.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = artistArchivalCoverage.familyRegistrationContext(name, f);
        _govern(
            _governanceRequest(
                1,
                address(artistArchivalCoverage),
                abi.encodeCall(artistArchivalCoverage.admitFamily, (name, f)),
                scope,
                oldHash,
                newHash
            )
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
                ? artistArchivalCheckpoint.profileHash()
                : artistArchivalCoverage.POSSESSION_PROFILE(),
            checkpoint,
            safeVm.addr(key),
            uint64(block.timestamp),
            0,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = artistArchivalCoverage.possessionHash(
                A.Possession(envelope, family, r.storageIdentifierHash, r.writer, r.observedAt)
            );
        }
        return artistArchivalCoverage.recordReceipt(
            r, identifier, _estateSign(key, artistArchivalCoverage.receiptDigest(r))
        );
    }

    function _estateFixity(bytes32 receipt, A.Envelope memory e, uint256 nonce) private {
        (A.ReceiptTerms memory r,,) = artistArchivalCoverage.receipt(receipt);
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
        artistArchivalCoverage.recordFixity(
            f, _estateSign(FIXITY, artistArchivalCoverage.fixityDigest(f))
        );
    }

    function _estateSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _estateGrantFixity() private {
        _setRole(keccak256("ROLE_FIXITY_OPERATOR"), safeVm.addr(FIXITY), true);
    }
}
