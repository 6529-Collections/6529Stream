// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol";

/// @notice Native URI regression for future local owner captures; no hosted fixture claim.
contract StreamOwnerFixtureUriRegressionTest {
    function testEmbeddedFixtureAllowsEmptyOptionalUri() public pure {
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", "", 2048, true);
        require(StreamMetadataRenderer.isSafeContentUri("", true), "empty optional URI");
    }

    function testFormerFixtureUrnIsNotAnAllowedContentUri() public pure {
        require(
            !StreamMetadataRenderer.isSafeContentUri("urn:stream:public-local-owner-fixture", true),
            "fixture URN must not be published"
        );
    }
}

/// @notice Authored current Core/Artist/Executor/Schema/OwnerRecords/Safe capture recipe.
/// @dev Randomness remains the inherited upstream double. Foundry logs are test oracles,
/// not canonical RPC receipts; Python capture needs a separately coordinated local chain.
contract StreamCurrentOwnerMuseumCaptureTest is StreamCurrentStackFixture, OfficialSafeFixture {
    StreamSchemaRegistry private ownerSchemas;
    StreamOwnerRecords private ownerRecords;
    OfficialSafe private ownerSafe;
    OfficialSafe private nextOwner;
    uint256[] private ownerKeys;
    uint256 private tokenId;
    bytes32 private constant JCS = keccak256("RFC8785_JCS");
    bytes32 private constant LOAN = keccak256("LOAN");
    bytes32 private constant VALUATION = keccak256("VALUATION");
    bytes32 private constant CONDITION = keccak256("CONDITION_REPORT");
    string private constant FIXTURES = "test/fixtures/metadata/current-owner-museum/";
    string private constant CONDITION_SCHEMA = "CURRENT_OWNER_MUSEUM_CONDITION_FIXTURE_V1";

    function setUp() public {
        vm.deal(address(this), 100 ether);
        ownerKeys.push(0xA11CE);
        ownerKeys.push(0xB0B);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        ownerSafe = createOfficialSafe(components, safeOwnerAddresses(ownerKeys), 2, 801);
        nextOwner = createOfficialSafe(components, safeOwnerAddresses(ownerKeys), 2, 802);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(ownerSchemas.RAW_BYTES_DEFINITION()),
            ownerSchemas.RAW_BYTES()
        );
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json")),
            ownerSchemas.RAW_BYTES()
        );
        _register(
            "STREAM_LOAN_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/museum/loan/STREAM_LOAN_V1.json")),
            JCS
        );
        _register(
            "STREAM_VALUATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/museum/valuation/STREAM_VALUATION_V1.json")),
            JCS
        );
        _register(
            CONDITION_SCHEMA,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            _file("condition-schema.json"),
            JCS
        );
        _mint();
    }

    function _deployAdditionalProducts() internal override {
        ownerSchemas = StreamSchemaRegistry(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry",
                abi.encode(address(executor))
            )
        );
        StreamOwnerRecords.Configuration memory c;
        c.core = address(core);
        c.schemas = address(ownerSchemas);
        c.executor = address(executor);
        c.deploymentManifestHash = DEPLOYMENT_HASH;
        // Raw CID of the exact manifest bytes below; publication/availability is not asserted.
        c.manifestURI = "ipfs://bafkreihrgxci5bintrod4j2fsvklcrs2pibs6h6detr2jgseg3f4emrdpq";
        c.manifestHash = keccak256("public local owner dossier recipe");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2
        );
        ownerRecords = StreamOwnerRecords(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/metadata/StreamOwnerRecords.sol:StreamOwnerRecords",
                    abi.encode(c)
                ))
        );
        _assertDeployableProductionInstance(address(ownerSchemas));
        _assertDeployableProductionInstance(address(ownerRecords));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(ownerSchemas),
            ownerSchemas.registerDocument.selector,
            address(ownerSchemas).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(ownerSchemas))),
            1,
            0,
            0,
            0
        );
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw,
        bytes32 canonical
    ) private {
        uint256 count = (raw.length + 8191) / 8192;
        bytes32[] memory chunks = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 n = raw.length - i * 8192;
            if (n > 8192) n = 8192;
            bytes memory chunk = new bytes(n);
            for (uint256 j; j < n; ++j) {
                chunk[j] = raw[i * 8192 + j];
            }
            chunks[i] = keccak256(chunk);
            StreamSchemaDocumentStore(ownerSchemas.chunkStore()).publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(raw), canonical, 0, "", uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ownerSchemas.registrationTransition(spec, chunks);
        bytes memory data = abi.encodeCall(ownerSchemas.registerDocument, (spec, chunks));
        GovernanceActionRequest memory request = GovernanceActionRequest(
            1,
            address(ownerSchemas),
            0,
            ownerSchemas.registerDocument.selector,
            data,
            scope,
            oldHash,
            newHash,
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("exact public owner schema registration"),
            "urn:stream:local-owner:schema",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        require(
            keccak256(ownerSchemas.documentBytes(keccak256(bytes(name)))) == keccak256(raw),
            "registered original bytes"
        );
    }

    function _mint() private {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory p =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(this),
                recipient: address(ownerSafe),
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("local owner capture actual mint"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("local owner capture sale"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(p);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformProof = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        (tokenId,) =
            sale.buy{ value: p.price }(p, TOKEN_DATA, platformProof, abi.encodePacked(r, s, v));
        require(
            tokenId == 1 && core.ownerOf(tokenId) == address(ownerSafe)
                && core.collectionMintedEver(1) == 1,
            "actual current mint owner"
        );
    }

    function _file(string memory name) private view returns (bytes memory) {
        return bytes(vm.readFile(string.concat(FIXTURES, name)));
    }

    function _record(bytes32 family, string memory schema, bytes memory raw)
        private
        view
        returns (IStreamOwnerRecords.OwnerRecord memory)
    {
        return IStreamOwnerRecords.OwnerRecord(
            family,
            ownerRecords.deriveOwnerSubject(tokenId),
            keccak256(bytes(schema)),
            IStreamPreservationRecords.HashRef(1, abi.encode(keccak256(raw)), JCS),
            "",
            raw,
            uint64(block.timestamp)
        );
    }

    function _direct(IStreamOwnerRecords.OwnerRecord memory r) private returns (bytes32 hash) {
        (, uint64 index) = ownerRecords.recordChainHash(tokenId, r.recordType);
        vm.recordLogs();
        require(
            executeSafe(
                ownerSafe,
                ownerKeys,
                address(ownerRecords),
                0,
                abi.encodeCall(ownerRecords.recordOwnerRecord, (tokenId, r)),
                0
            ),
            "actual owner Safe CALL"
        );
        hash = ownerRecords.recordHashAt(tokenId, r.recordType, index);
        _assertRecord(hash, r, false, vm.getRecordedLogs());
    }

    function _hex(bytes32 value) private pure returns (bytes memory out) {
        out = new bytes(66);
        out[0] = "0";
        out[1] = "x";
        bytes16 alphabet = "0123456789abcdef";
        for (uint256 i; i < 32; ++i) {
            out[2 + i * 2] = alphabet[uint8(value[i]) >> 4];
            out[3 + i * 2] = alphabet[uint8(value[i]) & 15];
        }
    }

    function _replace(bytes memory raw, bytes32 marker, bytes32 value)
        private
        pure
        returns (bytes memory)
    {
        bytes memory needle = _hex(marker);
        bytes memory replacement = _hex(value);
        uint256 found;
        for (uint256 i; i + needle.length <= raw.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < needle.length; ++j) {
                if (raw[i + j] != needle[j]) {
                    match_ = false;
                    break;
                }
            }
            if (!match_) continue;
            ++found;
            for (uint256 j; j < needle.length; ++j) {
                raw[i + j] = replacement[j];
            }
        }
        require(found == 1, "one explicit loan reference placeholder");
        return raw;
    }

    function _loan() private returns (IStreamOwnerRecords.OwnerRecord memory r) {
        bytes memory insurance = _file("valuation.json");
        bytes memory outbound = _file("outbound.json");
        bytes memory returned = _file("return.json");
        bytes32 a = _direct(_record(VALUATION, "STREAM_VALUATION_V1", insurance));
        bytes32 b = _direct(_record(CONDITION, CONDITION_SCHEMA, outbound));
        bytes32 c = _direct(_record(CONDITION, CONDITION_SCHEMA, returned));
        bytes memory raw = _file("loan-template.json");
        raw = _replace(raw, 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, a);
        raw = _replace(raw, 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb, b);
        raw = _replace(raw, 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc, c);
        raw = _replace(
            raw,
            0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,
            keccak256(insurance)
        );
        raw = _replace(
            raw,
            0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,
            keccak256(outbound)
        );
        raw = _replace(
            raw,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            keccak256(returned)
        );
        return _record(LOAN, "STREAM_LOAN_V1", raw);
    }

    function _relayData(IStreamOwnerRecords.OwnerRecord memory r)
        private
        returns (bytes memory data)
    {
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamOwnerRecords"),
                keccak256("1"),
                block.chainid,
                address(ownerRecords)
            )
        );
        bytes32[14] memory words;
        words[0] = keccak256(
            "StreamOwnerRecord(address owner,uint256 tokenId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)"
        );
        words[1] = bytes32(uint256(uint160(address(ownerSafe))));
        words[2] = bytes32(tokenId);
        words[3] = r.subjectId;
        words[4] = r.recordType;
        words[5] = r.schemaId;
        words[6] = bytes32(uint256(1));
        words[7] = keccak256(r.contentHash.digest);
        words[8] = JCS;
        words[9] = keccak256(bytes(r.uri));
        words[10] = keccak256(r.payload);
        words[11] = bytes32(uint256(r.effectiveAt));
        words[12] = bytes32(uint256(771));
        words[13] = bytes32(uint256(deadline));
        bytes32 digest =
            keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(words))));
        require(
            ownerRecords.ownerRecordDigest(tokenId, r, address(ownerSafe), 771, deadline) == digest,
            "independent fourteen-word authorization"
        );
        bytes memory sig =
            safeThresholdSignature(ownerKeys, safeMessageDigest(ownerSafe, abi.encode(digest)));
        return abi.encodeCall(
            ownerRecords.recordOwnerRecordFor, (tokenId, r, address(ownerSafe), 771, deadline, sig)
        );
    }

    function executeOwnerSafe(bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test-only Safe boundary");
        return executeSafe(ownerSafe, ownerKeys, address(ownerRecords), 0, data, 0);
    }

    function _assertRecord(
        bytes32 hash,
        IStreamOwnerRecords.OwnerRecord memory r,
        bool relayed,
        Vm.Log[] memory logs
    ) private view {
        (IStreamOwnerRecords.OwnerRecord memory saved, IStreamOwnerRecords.Receipt memory receipt) =
            ownerRecords.ownerRecord(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && receipt.owner == address(ownerSafe) && receipt.tokenId == tokenId
                && receipt.relayed == relayed && receipt.recordedAt == block.timestamp
                && receipt.schemaDefinitionHash == keccak256(ownerSchemas.documentBytes(r.schemaId))
                && receipt.canonicalizationDefinitionHash
                    == keccak256(ownerSchemas.documentBytes(JCS)),
            "full original owner/schema/payload receipt"
        );
        (address pointer, bytes memory bundle) = ownerRecords.ownerRecordSignatureBundle(hash);
        require(
            pointer.code.length != 0 && keccak256(bundle) == receipt.signatureBundleHash,
            "actual immutable signature carrier"
        );
        if (relayed) {
            require(
                receipt.nonce == 771 && receipt.signatureScheme == keccak256("ERC1271")
                    && ownerRecords.isOwnerRecordNonceUsed(address(ownerSafe), 771),
                "actual relayed Safe nonce and scheme"
            );
        } else {
            require(
                receipt.authorizationDigest == 0 && receipt.signatureScheme == keccak256("DIRECT")
                    && keccak256(bundle)
                        == keccak256(
                            abi.encode(
                                keccak256("DIRECT"), address(ownerSafe), keccak256(r.payload)
                            )
                        ),
                "original direct bundle"
            );
        }
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (
                log.emitter != address(ownerRecords) || log.topics.length == 0
                    || log.topics[0]
                        != keccak256(
                            "OwnerRecordRecorded(uint256,bytes32,address,(bytes32,bytes32,bytes32,(uint16,bytes,bytes32),string,bytes,uint64),bytes32,bytes32,bool,uint16)"
                        )
            ) continue;
            ++found;
            require(
                log.topics.length == 4 && log.topics[1] == bytes32(tokenId)
                    && log.topics[2] == r.recordType
                    && log.topics[3] == bytes32(uint256(uint160(address(ownerSafe))))
                    && keccak256(log.data)
                        == keccak256(
                            abi.encode(r, hash, receipt.recordChainHash, relayed, uint16(1))
                        ),
                "complete event oracle"
            );
        }
        require(found == 1, "one original owner event");
    }

    function testActualMintSafeLoanValuationAndSeparateBookValue() external {
        IStreamOwnerRecords.OwnerRecord memory loan = _loan();
        bytes memory data = _relayData(loan);
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(ownerRecords).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        bytes32 loanHash = ownerRecords.recordHashAt(tokenId, LOAN, 0);
        _assertRecord(loanHash, loan, true, vm.getRecordedLogs());
        bytes32 book = _direct(_record(VALUATION, "STREAM_VALUATION_V1", _file("book-value.json")));
        (bytes32 head, uint64 count) = ownerRecords.recordChainHash(tokenId, VALUATION);
        (, IStreamOwnerRecords.Receipt memory receipt) = ownerRecords.ownerRecord(book);
        require(
            count == 2 && head == receipt.recordChainHash
                && core.ownerOf(tokenId) == address(ownerSafe),
            "separate valuation lane and unchanged ownership"
        );
        require(
            core.collectionMintedEver(1) == 1 && core.totalSupply() == 1, "owner records never mint"
        );
    }

    function testOwnerTransferRejectsThenRestoresIdenticalRelayedSafeCall() external {
        IStreamOwnerRecords.OwnerRecord memory loan = _loan();
        bytes memory data = _relayData(loan);
        require(
            executeSafe(
                ownerSafe,
                ownerKeys,
                address(core),
                0,
                abi.encodeCall(
                    core.transferFrom, (address(ownerSafe), address(nextOwner), tokenId)
                ),
                0
            ),
            "actual transfer out"
        );
        uint256 nonce = ownerSafe.nonce();
        (bytes32 head, uint64 count) = ownerRecords.recordChainHash(tokenId, LOAN);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeOwnerSafe(data);
        require(
            ownerSafe.nonce() == nonce
                && !ownerRecords.isOwnerRecordNonceUsed(address(ownerSafe), 771),
            "failed owner and Safe nonce unchanged"
        );
        (bytes32 afterHead, uint64 afterCount) = ownerRecords.recordChainHash(tokenId, LOAN);
        require(head == afterHead && count == afterCount, "failed append restored");
        require(
            executeSafe(
                nextOwner,
                ownerKeys,
                address(core),
                0,
                abi.encodeCall(
                    core.transferFrom, (address(nextOwner), address(ownerSafe), tokenId)
                ),
                0
            ),
            "actual transfer back"
        );
        vm.recordLogs();
        require(this.executeOwnerSafe(data), "identical authorized Safe retry");
        _assertRecord(ownerRecords.recordHashAt(tokenId, LOAN, 0), loan, true, vm.getRecordedLogs());
    }

    function testRelayedOwnerNonceCannotAppendDuplicateLoan() external {
        IStreamOwnerRecords.OwnerRecord memory loan = _loan();
        bytes memory data = _relayData(loan);
        require(this.executeOwnerSafe(data), "first actual owner relay");
        uint256 nonce = ownerSafe.nonce();
        (bytes32 head, uint64 count) = ownerRecords.recordChainHash(tokenId, LOAN);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeOwnerSafe(data);
        (bytes32 afterHead, uint64 afterCount) = ownerRecords.recordChainHash(tokenId, LOAN);
        require(
            ownerSafe.nonce() == nonce && head == afterHead && count == 1 && afterCount == count
                && ownerRecords.isOwnerRecordNonceUsed(address(ownerSafe), 771),
            "original replay cell/chain/Safe nonce preserved"
        );
    }
}
