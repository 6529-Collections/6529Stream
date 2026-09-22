// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentOwnerCaptureFixture.sol";
import {
    IStreamCurrentTestOwnerStackDeployment
} from "../helpers/StreamCurrentTestOwnerStackDeployment.sol";
import {
    StreamDirectPrimarySaleTypes as OwnerDirect
} from "../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";
import {
    IStreamDirectPrimarySaleReceipt
} from "../../smart-contracts/interfaces/stream/revenue/IStreamDirectPrimarySaleReceipt.sol";
import "../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

/// @notice Authored current Core/Artist/Executor/Schema/OwnerRecords/Safe capture recipe.
/// @dev Randomness remains the inherited upstream double. Foundry logs are test oracles,
/// not canonical RPC receipts; Python capture needs a separately coordinated local chain.
/// The paid setup uses an explicit WAIVED DIRECT floor, not documentary MUSEUM/LITE evidence.
contract StreamCurrentOwnerMuseumCaptureTest is StreamCurrentOwnerCaptureFixture {
    OfficialSafe private ownerSafe;
    OfficialSafe private nextOwner;
    uint256[] private ownerKeys;
    uint256 private tokenId;
    address private expectedRelayOwner;
    uint64 private expectedRelayDeadline;
    bytes32 private expectedRelayDigest;
    bytes private expectedRelayBundle;
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
        _enableOwnerCaptureCommerce(components);
        _mint();
    }

    function _enableOwnerCaptureCommerce(SafeComponents memory components) private {
        OfficialSafe governor =
            createOfficialSafe(components, safeOwnerAddresses(ownerKeys), 2, 803);
        _installGovernorSafe(governor, ownerKeys);
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = StreamModuleRegistration(
            address(sale),
            OwnerDirect.MODULE_TYPE,
            OwnerDirect.MODULE_VERSION,
            type(IStreamDirectPrimarySaleReceipt).interfaceId,
            500_000,
            address(sale).codehash,
            DEPLOYMENT_HASH,
            keccak256("owner capture actual DIRECT product"),
            "urn:fixture:owner-capture-direct"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, rows);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector, action, ready
            )
        );
        executor.executeGovernanceBatch(action, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED
                && executor.governanceAction(action).proposer == address(governorSafe)
                && registry.isModuleEligible(
                    address(sale),
                    OwnerDirect.MODULE_TYPE,
                    type(IStreamDirectPrimarySaleReceipt).interfaceId
                ),
            "actual Safe admits the original DIRECT paid product"
        );
        _enableWaivedCommerceFloor();
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
        StreamConservationFloorTypes.FirstSaleReceipt memory first = commerceFloor.firstSale(1);
        OwnerDirect.Receipt memory paid =
            sale.directPrimarySaleReceipt(sale.authorizationId(p.artist, p.nonce));
        require(
            first.receiptHash != 0 && first.collectionId == 1 && first.recorder == address(sale)
                && first.effectiveTier == COMMERCE_WAIVED && paid.amount == p.price
                && paid.asset == address(0) && paid.payer == address(this)
                && paid.beneficiary == address(ownerSafe) && paid.tokenId == tokenId,
            "original paid mint retains its explicit WAIVED DIRECT receipt"
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
        return _directFor(ownerSafe, r);
    }

    function _directFor(OfficialSafe account, IStreamOwnerRecords.OwnerRecord memory r)
        private
        returns (bytes32 hash)
    {
        (bytes32 previous, uint64 index) = ownerRecords.recordChainHash(tokenId, r.recordType);
        vm.recordLogs();
        require(
            executeSafe(
                account,
                ownerKeys,
                address(ownerRecords),
                0,
                abi.encodeCall(ownerRecords.recordOwnerRecord, (tokenId, r)),
                0
            ),
            "actual owner Safe CALL"
        );
        hash = ownerRecords.recordHashAt(tokenId, r.recordType, index);
        _assertRecord(hash, r, false, vm.getRecordedLogs(), address(account), index, previous);
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
        return _relayDataFor(r, ownerSafe);
    }

    function _relayDataFor(IStreamOwnerRecords.OwnerRecord memory r, OfficialSafe account)
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
        words[1] = bytes32(uint256(uint160(address(account))));
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
            ownerRecords.ownerRecordDigest(tokenId, r, address(account), 771, deadline) == digest,
            "independent fourteen-word authorization"
        );
        bytes memory sig =
            safeThresholdSignature(ownerKeys, safeMessageDigest(account, abi.encode(digest)));
        expectedRelayOwner = address(account);
        expectedRelayDeadline = deadline;
        expectedRelayDigest = digest;
        expectedRelayBundle = abi.encode(domain, words, sig);
        return abi.encodeCall(
            ownerRecords.recordOwnerRecordFor, (tokenId, r, address(account), 771, deadline, sig)
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
        Vm.Log[] memory logs,
        address expectedOwner,
        uint64 expectedIndex,
        bytes32 previous
    ) private view {
        bytes32 subject = keccak256(
            abi.encode(
                bytes32(0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e),
                block.chainid,
                address(core),
                tokenId
            )
        );
        require(
            r.subjectId == subject && ownerRecords.deriveOwnerSubject(tokenId) == subject,
            "literal original TOKEN subject"
        );
        (IStreamOwnerRecords.OwnerRecord memory saved, IStreamOwnerRecords.Receipt memory receipt) =
            ownerRecords.ownerRecord(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && receipt.owner == expectedOwner && receipt.tokenId == tokenId
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
                    && ownerRecords.isOwnerRecordNonceUsed(expectedOwner, 771)
                    && expectedRelayOwner == expectedOwner
                    && receipt.deadline == expectedRelayDeadline
                    && receipt.authorizationDigest == expectedRelayDigest
                    && keccak256(bundle) == keccak256(expectedRelayBundle),
                "actual relayed Safe nonce and scheme"
            );
        } else {
            require(
                receipt.authorizationDigest == 0 && receipt.signatureScheme == keccak256("DIRECT")
                    && receipt.nonce == 0 && receipt.deadline == 0
                    && keccak256(bundle)
                        == keccak256(
                            abi.encode(keccak256("DIRECT"), expectedOwner, keccak256(r.payload))
                        ),
                "original direct bundle"
            );
        }
        bytes memory expectedBundle;
        if (relayed) {
            expectedBundle = expectedRelayBundle;
        } else {
            expectedBundle = abi.encode(keccak256("DIRECT"), expectedOwner, keccak256(r.payload));
        }
        require(
            pointer.codehash == keccak256(bytes.concat(hex"00", expectedBundle))
                && receipt.signatureBundleHash == keccak256(expectedBundle),
            "exact original signature carrier bytes"
        );
        require(
            hash == _literalRecordHash(r, expectedOwner, relayed, keccak256(expectedBundle)),
            "independent fourteen-word original record hash"
        );
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_CHAIN_V1"),
                block.chainid,
                address(ownerRecords),
                tokenId,
                r.recordType,
                previous,
                hash,
                expectedIndex
            )
        );
        (bytes32 head, uint64 count) = ownerRecords.recordChainHash(tokenId, r.recordType);
        require(
            receipt.recordIndex == expectedIndex && receipt.recordChainHash == chain
                && head == chain && count == expectedIndex + 1
                && ownerRecords.recordHashAt(tokenId, r.recordType, expectedIndex) == hash
                && ownerRecords.latestOwnerRecordHashFor(tokenId, r.recordType, expectedOwner)
                    == hash,
            "literal lane fold and original author history"
        );
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
                    && log.topics[3] == bytes32(uint256(uint160(expectedOwner)))
                    && keccak256(log.data)
                        == keccak256(
                            abi.encode(r, hash, receipt.recordChainHash, relayed, uint16(1))
                        ),
                "complete event oracle"
            );
        }
        require(found == 1, "one original owner event");
    }

    function _literalRecordHash(
        IStreamOwnerRecords.OwnerRecord memory r,
        address author,
        bool relayed,
        bytes32 bundleHash
    ) private view returns (bytes32) {
        bytes32[14] memory words;
        words[0] = keccak256("6529stream.preservation-record.v2");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(ownerRecords))));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(uint160(author)));
        words[5] = bytes32(tokenId);
        words[6] = r.recordType;
        words[7] = r.subjectId;
        words[8] = keccak256(
            abi.encode(
                r.contentHash.algorithm,
                keccak256(r.contentHash.digest),
                r.contentHash.canonicalizationId
            )
        );
        words[9] = keccak256(bytes(r.uri));
        words[10] = r.schemaId;
        words[11] = relayed ? keccak256("ERC1271") : keccak256("DIRECT");
        words[12] = keccak256(
            abi.encode(uint16(1), keccak256(abi.encode(bundleHash)), keccak256("RAW_BYTES"))
        );
        words[13] = bytes32(uint256(r.effectiveAt));
        return keccak256(abi.encode(words));
    }

    function _historicalBytes(bytes32 hash) private view returns (bytes32) {
        (
            IStreamOwnerRecords.OwnerRecord memory record,
            IStreamOwnerRecords.Receipt memory receipt
        ) = ownerRecords.ownerRecord(hash);
        (address pointer, bytes memory bundle) = ownerRecords.ownerRecordSignatureBundle(hash);
        return keccak256(abi.encode(record, receipt, pointer, pointer.codehash, bundle));
    }

    function executeNextOwnerSafe(bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "test-only Safe boundary");
        return executeSafe(nextOwner, ownerKeys, address(ownerRecords), 0, data, 0);
    }

    function testActualMintSafeLoanValuationAndSeparateBookValue() external {
        IStreamOwnerRecords.OwnerRecord memory loan = _loan();
        bytes memory data = _relayData(loan);
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(ownerRecords).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        bytes32 loanHash = ownerRecords.recordHashAt(tokenId, LOAN, 0);
        _assertRecord(loanHash, loan, true, vm.getRecordedLogs(), address(ownerSafe), 0, 0);
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
        _assertRecord(
            ownerRecords.recordHashAt(tokenId, LOAN, 0),
            loan,
            true,
            vm.getRecordedLogs(),
            address(ownerSafe),
            0,
            0
        );
    }

    function testRelayedOwnerNonceCannotAppendDuplicateLoan() external {
        IStreamOwnerRecords.OwnerRecord memory loan = _loan();
        bytes memory data = _relayData(loan);
        vm.recordLogs();
        require(this.executeOwnerSafe(data), "first actual owner relay");
        _assertRecord(
            ownerRecords.recordHashAt(tokenId, LOAN, 0),
            loan,
            true,
            vm.getRecordedLogs(),
            address(ownerSafe),
            0,
            0
        );
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

    function testActualSafeCustodyAppendAndBurnPreserveBothOriginalOwnerHistories() external {
        bytes32 first = _direct(_record(CONDITION, CONDITION_SCHEMA, _file("outbound.json")));
        bytes32 firstBytes = _historicalBytes(first);
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
            ) && core.ownerOf(tokenId) == address(nextOwner),
            "actual transfer to second Safe"
        );
        bytes32 second =
            _directFor(nextOwner, _record(CONDITION, CONDITION_SCHEMA, _file("return.json")));
        bytes32 secondBytes = _historicalBytes(second);
        (bytes32 head, uint64 count) = ownerRecords.recordChainHash(tokenId, CONDITION);
        require(
            count == 2 && first != second && _historicalBytes(first) == firstBytes
                && ownerRecords.recordHashAt(tokenId, CONDITION, 0) == first
                && ownerRecords.recordHashAt(tokenId, CONDITION, 1) == second
                && ownerRecords.latestOwnerRecordHashFor(tokenId, CONDITION, address(ownerSafe))
                    == first
                && ownerRecords.latestOwnerRecordHashFor(tokenId, CONDITION, address(nextOwner))
                == second,
            "distinct Safe authors retain original lane and latest heads"
        );
        IStreamOwnerRecords.OwnerRecord memory fresh =
            _record(CONDITION, CONDITION_SCHEMA, bytes("{\"fixture\":\"post-burn refusal\"}"));
        bytes memory relay = _relayDataFor(fresh, nextOwner);
        require(
            !ownerRecords.isOwnerRecordNonceUsed(address(nextOwner), 771),
            "fresh second-owner authorization"
        );
        require(
            executeSafe(
                nextOwner, ownerKeys, address(core), 0, abi.encodeCall(core.burn, (tokenId)), 0
            ),
            "actual current owner Safe burn"
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 1,
            "burn removes live supply without erasing mint history"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "ERC721: invalid token ID"));
        core.ownerOf(tokenId);
        uint256 safeNonce = nextOwner.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeNextOwnerSafe(abi.encodeCall(ownerRecords.recordOwnerRecord, (tokenId, fresh)));
        (bool ok, bytes memory reason) = address(ownerRecords).call(relay);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamOwnerRecords.OwnerRecordReadFailed.selector, address(core)
                        )
                    ),
            "fresh valid signature reaches burned actual Core refusal"
        );
        (bytes32 afterHead, uint64 afterCount) = ownerRecords.recordChainHash(tokenId, CONDITION);
        require(
            nextOwner.nonce() == safeNonce
                && !ownerRecords.isOwnerRecordNonceUsed(address(nextOwner), 771)
                && afterHead == head && afterCount == count
                && ownerRecords.recordHashAt(tokenId, CONDITION, 0) == first
                && ownerRecords.recordHashAt(tokenId, CONDITION, 1) == second
                && _historicalBytes(first) == firstBytes && _historicalBytes(second) == secondBytes
                && ownerRecords.latestOwnerRecordHashFor(tokenId, CONDITION, address(ownerSafe))
                    == first
                && ownerRecords.latestOwnerRecordHashFor(tokenId, CONDITION, address(nextOwner))
                == second,
            "burn and failed appends preserve exact receipts carriers nonces and author histories"
        );
    }

    /// @dev The genuine helper CREATE consumes one host nonce before the original stack sequence.
    /// Original product CREATEs retain their order and host context; addresses are freshly derived.
    function _deployCurrentStack(address artist_, address platform) internal override {
        address deployment = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestOwnerStackDeployment.sol:StreamCurrentTestOwnerStackDeployment",
            abi.encode()
        );
        (bool ok, bytes memory result) = deployment.delegatecall(
            abi.encodeCall(
                IStreamCurrentTestOwnerStackDeployment.deployCurrentStack, (artist_, platform)
            )
        );
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
