// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamConservationFloor.sol";
import "../../interfaces/stream/metadata/IStreamConservationFloorProvider.sol";
import "../../interfaces/stream/metadata/IStreamConservationFloorPreparation.sol";
import "../../interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../interfaces/stream/core/IStreamCoreConservationTier.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamMetadataGovernance.sol";
import "./StreamConservationTiers.sol";
import "./StreamConservationFloorReads.sol";
import "./StreamConservationFloorSupplemental.sol";
import "./StreamConservationDirectReads.sol";
import "./StreamConservationDirectHistory.sol";

/// @notice Permanent owner of successful first-sale and release-floor receipts.
/// @dev The current native source graph is admitted by exact delayed governance, never selected by
/// a payer or recorder. Historical source rows/receipts remain readable after every replacement.
contract StreamConservationFloor is
    StreamGasParameterHost,
    IStreamConservationFloor,
    IStreamConservationFloorPreparation,
    IStreamDirectPrimaryConservationFloor
{
    address public immutable override core;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override executorCodeHash;
    uint256 public immutable override deploymentChainId;
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_CONSERVATION_FLOOR_READ_GAS");
    bytes32 public constant PRODUCER_GAS =
        keccak256("6529STREAM_GGP_CONSERVATION_FLOOR_PRODUCER_GAS");
    bytes32 public constant CALL_GAS = keccak256("6529STREAM_GGP_CONSERVATION_FLOOR_CALL_GAS");
    bytes32 private constant SOURCE_DOMAIN = keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1");
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");
    bytes32 private constant FULL = keccak256("MUSEUM_GRADE");
    uint8 private constant UNIVERSAL = 1;
    uint8 private constant DIRECT = 2;

    StreamConservationFloorTypes.Source[] private _sources;
    bytes32[] private _heads;

    struct CollectionPreparation {
        bool exists;
        uint256 collectionId;
        bytes32 tier;
        uint64 sourceId;
        bytes32 sourceSetHash;
        StreamConservationFloorTypes.CollectionFacts facts;
    }

    struct ReleasePreparation {
        bool exists;
        uint256 collectionId;
        bytes32 tier;
        uint64 sourceId;
        bytes32 sourceSetHash;
        bytes32 releaseKey;
        StreamConservationFloorTypes.ReleaseContext context;
        StreamConservationFloorTypes.ReleaseFacts facts;
    }

    struct SalePreparation {
        bool exists;
        StreamConservationFloorTypes.SettlementReceipt seed;
        bytes32 collectionEvidence;
        bytes32 releaseEvidence;
    }

    struct SaleLink {
        bytes32 preparation;
        uint64 recordedAt;
        uint8 family;
    }

    mapping(bytes32 => CollectionPreparation) private _collectionPreparations;
    mapping(bytes32 => ReleasePreparation) private _releasePreparations;
    mapping(bytes32 => SalePreparation) private _salePreparations;
    mapping(bytes32 => SaleLink) private _saleLinks;
    mapping(uint256 => bytes32) private _first;
    mapping(bytes32 => bytes32) private _release;
    bool private _entered;
    mapping(bytes32 => StreamConservationDirectHistory.Preparation) private _directPreparations;

    constructor(
        address core_,
        address executor_,
        GasParameterConfig memory readGas,
        GasParameterConfig memory producerGas,
        GasParameterConfig memory settlementCallGas
    ) StreamGasParameterHost(executor_) {
        if (
            !StreamSettlementAdmission.isContract(core_)
                || !StreamSettlementAdmission.isContract(executor_) || readGas.failureClass != 2
                || producerGas.failureClass != 2 || settlementCallGas.failureClass != 2
                || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(producerGas) != PRODUCER_GAS
                || _registerGasParameter(settlementCallGas) != CALL_GAS
        ) {
            revert InvalidConservationFloorConfiguration();
        }
        core = core_;
        coreCodeHash = core_.codehash;
        executorCodeHash = executor_.codehash;
        deploymentChainId = block.chainid;
        _heads.push(keccak256(abi.encode(SOURCE_DOMAIN, block.chainid, core_, address(this))));
    }

    modifier guarded() {
        if (_entered) revert ConservationFloorReentrant();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamConservationFloor).interfaceId
            || id == type(IStreamConservationFloorPreparation).interfaceId
            || id == type(IStreamDirectPrimaryConservationFloor).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == 0x01ffc9a7;
    }

    function sourceCount() public view override returns (uint64) {
        return uint64(_sources.length);
    }

    function sourceAt(uint64 id)
        external
        view
        override
        returns (StreamConservationFloorTypes.Source memory)
    {
        if (id == 0 || id > _sources.length) revert ConservationFloorSourceUnavailable();
        return _sources[id - 1];
    }

    function sourceSetHashAt(uint64 count) external view override returns (bytes32) {
        if (count > _sources.length) revert ConservationFloorSourceUnavailable();
        return _heads[count];
    }

    function sourceSetHead() public view override returns (uint64 count, bytes32 head) {
        count = sourceCount();
        head = _heads[count];
    }

    function sourceTransition(address metadata_, address provider, uint64 predecessor)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        StreamConservationFloorTypes.Source memory s =
            _validateSource(metadata_, provider, predecessor);
        scope = StreamMetadataGovernance.configurationScope(
            governanceAuthority, executorCodeHash, _gasParameterValue(READ_GAS), SOURCE_DOMAIN
        );
        (uint64 count, bytes32 head) = sourceSetHead();
        oldHash = _sourceState(count, head);
        newHash = _sourceState(count + 1, _nextSource(head, count + 1, s));
    }

    function appendSource(address metadata_, address provider, uint64 predecessor)
        external
        override
        guarded
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            sourceTransition(metadata_, provider, predecessor);
        bytes32 actionId = StreamMetadataGovernance.requireTransition(
            governanceAuthority,
            executorCodeHash,
            _gasParameterValue(READ_GAS),
            scope,
            oldHash,
            newHash
        );
        StreamConservationFloorTypes.Source memory s =
            _validateSource(metadata_, provider, predecessor);
        uint64 id = sourceCount() + 1;
        bytes32 head = _nextSource(_heads[id - 1], id, s);
        s.admittedAt = uint64(block.timestamp);
        s.actionId = actionId;
        _sources.push(s);
        _heads.push(head);
        emit ConservationFloorSourceAdded(id, metadata_, provider, head, s, 1);
    }

    function firstSale(uint256 cid)
        external
        view
        override
        returns (StreamConservationFloorTypes.FirstSaleReceipt memory)
    {
        return _firstReceipt(cid);
    }

    function releaseFloorReceipt(bytes32 key)
        external
        view
        override
        returns (StreamConservationFloorTypes.ReleaseFloorReceipt memory)
    {
        return _releaseReceipt(key);
    }

    function settlementReceipt(bytes32 key)
        external
        view
        override
        returns (StreamConservationFloorTypes.SettlementReceipt memory)
    {
        return _settlementReceipt(key);
    }

    function directPrimarySaleFloorReceipt(bytes32 key)
        external
        view
        override
        returns (StreamDirectPrimaryConservationTypes.Receipt memory)
    {
        return _directReceipt(key);
    }

    function primarySalePrepared(bytes32 key) external view override returns (bool) {
        return _salePreparations[key].exists;
    }

    function preparePrimarySale(
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.PrimarySettlementResult calldata expectedResult
    ) external override guarded returns (bytes32 key) {
        StreamConservationFloorReads.Context memory x = _context();
        StreamConservationFloorReads.requireRecorder(x, recorder);
        // This deliberately does not require payment, consumed state, or an allocated future
        // prepared-mint token. Preparation is evidence storage, never a successful sale.
        StreamConservationFloorReads.requireProjection(
            x, recorder, candidate, expectedResult, false
        );
        (CollectionPreparation memory collection_, ReleasePreparation memory release_) =
            _universalEvidence(candidate, _tier(candidate.sale.collectionId), false);
        bytes32 collectionKey = keccak256(abi.encode(collection_));
        bytes32 releaseKey = release_.exists ? keccak256(abi.encode(release_)) : bytes32(0);
        SalePreparation memory p =
            _salePreparation(recorder, candidate, expectedResult, collectionKey, releaseKey);
        return _persistPreparation(p, collection_, release_);
    }

    function recordPrimarySale(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.PrimarySettlementResult calldata result
    ) external override guarded returns (bytes32 receiptHash) {
        StreamConservationFloorReads.Context memory x = _context();
        StreamConservationFloorReads.requireRecorder(x, msg.sender);
        StreamConservationFloorReads.requireCandidate(x, msg.sender, candidate, result);
        if (_saleLinks[result.settlementKey].preparation != 0) {
            revert ConservationFloorAlreadyRecorded(result.settlementKey);
        }
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert ConservationFloorInvalidEvidence();
        }
        (CollectionPreparation memory collection_, ReleasePreparation memory release_) =
            _universalEvidence(candidate, _tier(candidate.sale.collectionId), true);
        SalePreparation memory p = _salePreparation(
            msg.sender,
            candidate,
            result,
            keccak256(abi.encode(collection_)),
            release_.exists ? keccak256(abi.encode(release_)) : bytes32(0)
        );
        // Preparation is an optimization. The original one-transaction purchase persists the
        // same genuine immutable evidence inline when absent, after all paid authentication.
        // Current source head and complete first/new-release facts determine the exact key;
        // an older preparation neither authorizes a sale nor substitutes its old evidence.
        bytes32 key = _persistPreparation(p, collection_, release_);
        _linkSale(result.settlementKey, key, UNIVERSAL, candidate.sale.collectionId, release_);
        StreamConservationFloorTypes.SettlementReceipt memory s =
            _settlementReceipt(result.settlementKey);
        emit ConservationSettlementRecorded(s.settlementKey, s.receiptHash, s, 1);
        return s.receiptHash;
    }

    function recordDirectPrimarySale(bytes32 authorizationId)
        external
        override
        guarded
        returns (bytes32 receiptHash)
    {
        (
            StreamDirectPrimarySaleTypes.Bindings memory bindings,
            StreamDirectPrimarySaleTypes.Receipt memory sale,
            bytes32 directKey,
            bytes32 originalHash
        ) = StreamConservationDirectReads.requireReceipt(_context(), msg.sender, authorizationId);
        if (_saleLinks[directKey].preparation != 0) {
            revert ConservationFloorAlreadyRecorded(directKey);
        }
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert ConservationFloorInvalidEvidence();
        }
        bytes32 tier = _tier(sale.collectionId);
        (CollectionPreparation memory collection_, ReleasePreparation memory release_) = _evidence(
            StreamConservationFloorTypes.SaleContext(
                sale.collectionId,
                sale.tokenId,
                msg.sender,
                authorizationId,
                sale.operationRoot,
                sale.operationId,
                sale.boundMintPolicyHash
            ),
            tier
        );
        StreamConservationDirectHistory.Preparation memory p;
        p.exists = true;
        p.collectionEvidence = keccak256(abi.encode(collection_));
        p.releaseEvidence = release_.exists ? keccak256(abi.encode(release_)) : bytes32(0);
        p.seed.adapter = msg.sender;
        p.seed.adapterCodeHash = msg.sender.codehash;
        p.seed.directKey = directKey;
        p.seed.authorizationId = authorizationId;
        p.seed.originalReceiptHash = originalHash;
        p.seed.bindings = bindings;
        p.seed.sale = sale;
        p.seed.effectiveTier = tier;
        _persistEvidence(p.collectionEvidence, p.releaseEvidence, collection_, release_);
        bytes32 preparation = StreamConservationDirectHistory.persist(
            _directPreparations, p, deploymentChainId, core
        );
        _linkSale(directKey, preparation, DIRECT, sale.collectionId, release_);
        StreamDirectPrimaryConservationTypes.Receipt memory r = _directReceipt(directKey);
        emit ConservationDirectPrimarySaleRecorded(directKey, r.receiptHash, r, 1);
        return r.receiptHash;
    }

    function _linkSale(
        bytes32 saleKey,
        bytes32 preparation,
        uint8 family,
        uint256 cid,
        ReleasePreparation memory release_
    ) private {
        _saleLinks[saleKey] = SaleLink(preparation, uint64(block.timestamp), family);
        if (_first[cid] == 0) {
            _first[cid] = saleKey;
            StreamConservationFloorTypes.FirstSaleReceipt memory f = _firstReceipt(cid);
            emit ConservationFirstSaleRecorded(cid, f.receiptHash, f, 1);
        }
        if (release_.exists && _release[release_.releaseKey] == 0) {
            _release[release_.releaseKey] = saleKey;
            StreamConservationFloorTypes.ReleaseFloorReceipt memory releaseReceipt =
                _releaseReceipt(release_.releaseKey);
            emit ConservationReleaseFloorRecorded(
                release_.releaseKey, releaseReceipt.receiptHash, releaseReceipt, 1
            );
        }
    }

    function requireSupplemental(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate calldata candidate,
        StreamNativeSupplementalTypes.NativeSupplementalResult calldata result
    ) external view override returns (bytes32 originalReceiptHash) {
        StreamConservationFloorReads.Context memory x = _context();
        StreamConservationFloorReads.requireRecorder(x, msg.sender);
        StreamConservationFloorTypes.SettlementReceipt memory original =
            _settlementReceipt(candidate.purchase.floorSettlementKey);
        if (original.receiptHash == 0) {
            revert ConservationFloorOriginalReceiptMissing(candidate.purchase.floorSettlementKey);
        }
        if (
            _firstReceipt(original.collectionId).receiptHash != original.firstSaleReceiptHash
                || (original.effectiveTier != WAIVED && original.releaseReceiptHash == 0)
        ) revert ConservationFloorInvalidEvidence();
        StreamConservationFloorSupplemental.requireOriginal(x, original, candidate, result);
        return original.receiptHash;
    }

    function _salePreparation(
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        StreamPrimarySettlementTypes.PrimarySettlementResult calldata r,
        bytes32 collectionKey,
        bytes32 releaseKey
    ) private view returns (SalePreparation memory p) {
        p.exists = true;
        p.collectionEvidence = collectionKey;
        p.releaseEvidence = releaseKey;
        p.seed.recorder = recorder;
        p.seed.recorderCodeHash = recorder.codehash;
        p.seed.settlementKey = r.settlementKey;
        p.seed.candidatePayloadHash = keccak256(abi.encode(c));
        p.seed.candidateCommitment = r.candidateCommitment;
        p.seed.resultHash = keccak256(abi.encode(r));
        p.seed.collectionId = c.sale.collectionId;
        p.seed.tokenId = c.sale.tokenId;
        p.seed.effectiveTier = _tier(c.sale.collectionId);
    }

    function _preparationHash(SalePreparation memory p) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_PREPARED_SALE_V1"),
                deploymentChainId,
                core,
                address(this),
                p
            )
        );
    }

    function _persistPreparation(
        SalePreparation memory p,
        CollectionPreparation memory collection_,
        ReleasePreparation memory release_
    ) private returns (bytes32 key) {
        key = _preparationHash(p);
        if (_salePreparations[key].exists) return key;
        _persistEvidence(p.collectionEvidence, p.releaseEvidence, collection_, release_);
        // This key has never been persisted: preparations are append-only and the
        // sole producer leaves computed receipt links/hash/time at their zero defaults.
        // Preserve the same stored seed without touching those empty slots.
        SalePreparation storage saved = _salePreparations[key];
        saved.exists = true;
        saved.seed.recorder = p.seed.recorder;
        saved.seed.recorderCodeHash = p.seed.recorderCodeHash;
        saved.seed.settlementKey = p.seed.settlementKey;
        saved.seed.candidatePayloadHash = p.seed.candidatePayloadHash;
        saved.seed.candidateCommitment = p.seed.candidateCommitment;
        saved.seed.resultHash = p.seed.resultHash;
        saved.seed.collectionId = p.seed.collectionId;
        if (p.seed.tokenId != 0) saved.seed.tokenId = p.seed.tokenId;
        saved.seed.effectiveTier = p.seed.effectiveTier;
        saved.collectionEvidence = p.collectionEvidence;
        if (p.releaseEvidence != 0) saved.releaseEvidence = p.releaseEvidence;
        emit ConservationPrimarySalePrepared(
            key, p.seed.recorder, p.seed.settlementKey, p.collectionEvidence, p.releaseEvidence, 1
        );
    }

    function _persistEvidence(
        bytes32 collectionKey,
        bytes32 releaseKey,
        CollectionPreparation memory collection_,
        ReleasePreparation memory release_
    ) private {
        if (!_collectionPreparations[collectionKey].exists) {
            CollectionPreparation storage saved = _collectionPreparations[collectionKey];
            saved.exists = true;
            saved.collectionId = collection_.collectionId;
            saved.tier = collection_.tier;
            saved.sourceSetHash = collection_.sourceSetHash;
            // _evidence returns before selecting a source for genuine WAIVED facts.
            // This fresh row therefore already has their exact zero source/fact words.
            if (collection_.tier != WAIVED) {
                saved.sourceId = collection_.sourceId;
                saved.facts = collection_.facts;
            }
        }
        if (release_.exists && !_releasePreparations[releaseKey].exists) {
            _releasePreparations[releaseKey] = release_;
        }
    }

    function _universalEvidence(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        bytes32 tier,
        bool paid
    )
        private
        view
        returns (CollectionPreparation memory collection_, ReleasePreparation memory release_)
    {
        StreamConservationFloorTypes.SaleContext memory
            sale = StreamConservationFloorTypes.SaleContext(
            c.sale.collectionId,
            c.sale.tokenId,
            c.saleAdapter,
            c.sale.settlementId,
            c.operationIdentityCommitment,
            c.operationId,
            c.boundPolicyHash
        );
        if (
            tier != WAIVED && !paid && c.orchestrationOrder == 2 && c.sale.tokenId != 0
                && StreamConservationFloorReads.word(
                        core,
                        abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (c.sale.tokenId)),
                        _gasParameterValue(READ_GAS)
                    ) == 0
        ) {
            // Only optional prospective preparation uses collection scope before allocation.
            // The exact original candidate remains seed-bound and paid entry uses its real token.
            sale.tokenId = 0;
        }
        return _evidence(sale, tier);
    }

    function _evidence(StreamConservationFloorTypes.SaleContext memory sale, bytes32 tier)
        private
        view
        returns (CollectionPreparation memory collection_, ReleasePreparation memory release_)
    {
        uint256 cid = sale.collectionId;
        bytes32 firstKey = _first[cid];
        if (firstKey != 0) {
            collection_ = _collectionPreparations[_collectionEvidenceFor(firstKey)];
            if (collection_.tier != tier) revert ConservationFloorInvalidEvidence();
        } else {
            collection_.exists = true;
            collection_.collectionId = cid;
            collection_.tier = tier;
            // Includes the actual paid source head, even when tier is WAIVED. A source append
            // selects fresh immutable evidence and never rewrites the prior preparation.
            collection_.sourceSetHash = _heads[sourceCount()];
        }
        if (tier == WAIVED) return (collection_, release_);
        (uint64 sourceId, StreamConservationFloorTypes.Source memory source) = _currentSource();
        if (firstKey == 0) {
            collection_.sourceId = sourceId;
            collection_.facts = _collection(source, cid, tier);
        }
        release_ = _releaseEvidence(sourceId, source, sale, tier);
    }

    function _releaseEvidence(
        uint64 sourceId,
        StreamConservationFloorTypes.Source memory source,
        StreamConservationFloorTypes.SaleContext memory sale,
        bytes32 tier
    ) private view returns (ReleasePreparation memory p) {
        bytes memory raw = _producer(
            source, abi.encodeCall(IStreamConservationFloorProvider.saleRelease, (sale)), 192
        );
        StreamConservationFloorTypes.ReleaseContext memory release =
            abi.decode(raw, (StreamConservationFloorTypes.ReleaseContext));
        if (
            keccak256(raw) != keccak256(abi.encode(release)) || release.scopeSubject == 0
                || release.membershipHash == 0 || release.mediaInventoryHash == 0
                || release.sourceContextHash == 0
                || release.scriptWork != (release.scriptSourceHash != 0)
        ) revert ConservationFloorInvalidEvidence();
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_RELEASE_V1"),
                deploymentChainId,
                core,
                sale.collectionId,
                release.scopeSubject,
                release.membershipHash,
                release.mediaInventoryHash,
                release.scriptSourceHash,
                release.scriptWork
            )
        );
        bytes32 previous = _release[key];
        if (previous != 0) {
            // Current sale-to-release mapping was just re-proved. Historical successful
            // evidence for identical semantic content remains the immutable denominator.
            p = _releasePreparations[_releaseEvidenceFor(previous)];
            if (p.tier != tier || p.collectionId != sale.collectionId) {
                revert ConservationFloorInvalidEvidence();
            }
            return p;
        }
        raw = _producer(
            source,
            abi.encodeCall(
                IStreamConservationFloorProvider.requireReleaseFloor, (sale, release, tier)
            ),
            96
        );
        p.facts = abi.decode(raw, (StreamConservationFloorTypes.ReleaseFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(p.facts))
                || p.facts.sourceContextHash != release.sourceContextHash
                || p.facts.mediaEvidenceHash == 0
                || (tier == FULL && release.scriptWork && p.facts.referenceEvidenceHash == 0)
                || (!release.scriptWork && p.facts.referenceEvidenceHash != 0)
        ) revert ConservationFloorInvalidEvidence();
        p.exists = true;
        p.collectionId = sale.collectionId;
        p.tier = tier;
        p.sourceId = sourceId;
        p.sourceSetHash = _heads[sourceId];
        p.releaseKey = key;
        p.context = release;
    }

    function _firstReceipt(uint256 cid)
        private
        view
        returns (StreamConservationFloorTypes.FirstSaleReceipt memory f)
    {
        bytes32 key = _first[cid];
        if (key == 0) return f;
        SaleLink memory link = _saleLinks[key];
        CollectionPreparation storage p = _collectionPreparations[_collectionEvidenceFor(key)];
        f.collectionId = p.collectionId;
        f.effectiveTier = p.tier;
        f.recorder = _originFor(key);
        f.settlementKey = key;
        f.recordedAt = link.recordedAt;
        f.sourceId = p.sourceId;
        f.sourceSetHash = p.sourceSetHash;
        f.facts = p.facts;
        f.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_FIRST_SALE_V1"),
                deploymentChainId,
                core,
                address(this),
                f
            )
        );
    }

    function _releaseReceipt(bytes32 semanticKey)
        private
        view
        returns (StreamConservationFloorTypes.ReleaseFloorReceipt memory r)
    {
        bytes32 key = _release[semanticKey];
        if (key == 0) return r;
        SaleLink memory link = _saleLinks[key];
        ReleasePreparation storage p = _releasePreparations[_releaseEvidenceFor(key)];
        r.releaseKey = p.releaseKey;
        r.collectionId = p.collectionId;
        r.effectiveTier = p.tier;
        r.recorder = _originFor(key);
        r.settlementKey = key;
        r.recordedAt = link.recordedAt;
        r.sourceId = p.sourceId;
        r.sourceSetHash = p.sourceSetHash;
        r.context = p.context;
        r.facts = p.facts;
        r.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_RELEASE_RECEIPT_V1"),
                deploymentChainId,
                core,
                address(this),
                r
            )
        );
    }

    function _settlementReceipt(bytes32 key)
        private
        view
        returns (StreamConservationFloorTypes.SettlementReceipt memory s)
    {
        SaleLink memory link = _saleLinks[key];
        if (link.preparation == 0 || link.family != UNIVERSAL) return s;
        SalePreparation storage p = _salePreparations[link.preparation];
        s = p.seed;
        s.recordedAt = link.recordedAt;
        s.firstSaleReceiptHash = _firstReceipt(s.collectionId).receiptHash;
        if (p.releaseEvidence != 0) {
            s.releaseReceiptHash =
            _releaseReceipt(_releasePreparations[p.releaseEvidence].releaseKey).receiptHash;
        }
        s.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_SETTLEMENT_RECEIPT_V1"),
                deploymentChainId,
                core,
                address(this),
                s
            )
        );
    }

    function _directReceipt(bytes32 key)
        private
        view
        returns (StreamDirectPrimaryConservationTypes.Receipt memory r)
    {
        SaleLink memory link = _saleLinks[key];
        if (link.preparation == 0 || link.family != DIRECT) return r;
        StreamConservationDirectHistory.Preparation storage p =
            _directPreparations[link.preparation];
        bytes32 releaseReceiptHash;
        if (p.releaseEvidence != 0) {
            releaseReceiptHash =
            _releaseReceipt(_releasePreparations[p.releaseEvidence].releaseKey).receiptHash;
        }
        return StreamConservationDirectHistory.receipt(
            p,
            link.recordedAt,
            _firstReceipt(p.seed.sale.collectionId).receiptHash,
            releaseReceiptHash,
            deploymentChainId,
            core
        );
    }

    function _collectionEvidenceFor(bytes32 key) private view returns (bytes32) {
        SaleLink memory link = _saleLinks[key];
        if (link.family == UNIVERSAL) {
            return _salePreparations[link.preparation].collectionEvidence;
        }
        if (link.family == DIRECT) return _directPreparations[link.preparation].collectionEvidence;
        revert ConservationFloorInvalidEvidence();
    }

    function _releaseEvidenceFor(bytes32 key) private view returns (bytes32) {
        SaleLink memory link = _saleLinks[key];
        if (link.family == UNIVERSAL) return _salePreparations[link.preparation].releaseEvidence;
        if (link.family == DIRECT) return _directPreparations[link.preparation].releaseEvidence;
        revert ConservationFloorInvalidEvidence();
    }

    function _originFor(bytes32 key) private view returns (address) {
        SaleLink memory link = _saleLinks[key];
        if (link.family == UNIVERSAL) return _salePreparations[link.preparation].seed.recorder;
        if (link.family == DIRECT) return _directPreparations[link.preparation].seed.adapter;
        revert ConservationFloorInvalidEvidence();
    }

    function _collection(
        StreamConservationFloorTypes.Source memory source,
        uint256 cid,
        bytes32 tier
    ) private view returns (StreamConservationFloorTypes.CollectionFacts memory f) {
        bytes memory raw = _producer(
            source,
            abi.encodeCall(IStreamConservationFloorProvider.requireCollectionFloor, (cid, tier)),
            256
        );
        f = abi.decode(raw, (StreamConservationFloorTypes.CollectionFacts));
        if (keccak256(raw) != keccak256(abi.encode(f)) || f.rightsRecordHash == 0) {
            revert ConservationFloorInvalidEvidence();
        }
        if (f.platformWorks) {
            if (
                f.artistId != 0 || f.identityRecordHash != 0 || f.intentRecordHash != 0
                    || f.intentWaiverRecordHash != 0 || f.interviewEvidenceHash != 0
                    || f.personhoodEvidenceHash != 0
            ) revert ConservationFloorInvalidEvidence();
        } else if (
            f.artistId == 0 || f.identityRecordHash == 0
                || (f.intentRecordHash == 0) == (f.intentWaiverRecordHash == 0)
                || f.interviewEvidenceHash == 0 || f.personhoodEvidenceHash == 0
        ) {
            revert ConservationFloorInvalidEvidence();
        }
    }

    function _tier(uint256 cid) private view returns (bytes32 declared) {
        declared = bytes32(
            StreamConservationFloorReads.word(
                core,
                abi.encodeCall(IStreamCoreConservationTier.declaredConservationTier, (cid)),
                _gasParameterValue(READ_GAS)
            )
        );
        // Sale payment may precede completed minting. Absence prospectively bears the lite floor.
        if (declared == 0) return keccak256("MUSEUM_GRADE_LITE");
        StreamConservationTiers.requireKnown(declared);
    }

    function _currentSource()
        private
        view
        returns (uint64 id, StreamConservationFloorTypes.Source memory s)
    {
        id = sourceCount();
        if (id == 0) revert ConservationFloorSourceUnavailable();
        s = _sources[id - 1];
        _providerIdentity(s);
    }

    function _validateSource(address metadata_, address provider, uint64 predecessor)
        private
        view
        returns (StreamConservationFloorTypes.Source memory s)
    {
        _context();
        if (
            predecessor != _sources.length || _sources.length == type(uint64).max
                || block.timestamp == 0 || block.timestamp > type(uint64).max
                || !StreamSettlementAdmission.isContract(metadata_)
                || !StreamSettlementAdmission.isContract(provider)
        ) revert ConservationFloorSourceUnavailable();
        s.metadata = metadata_;
        s.metadataCodeHash = metadata_.codehash;
        s.provider = provider;
        s.providerCodeHash = provider.codehash;
        s.predecessor = predecessor;
        s.configurationHash = bytes32(
            StreamConservationFloorReads.word(
                provider,
                abi.encodeCall(IStreamConservationFloorProvider.configurationHash, ()),
                _gasParameterValue(READ_GAS)
            )
        );
        _providerIdentity(s);
        if (_sources.length != 0) {
            StreamConservationFloorTypes.Source memory previous = _sources[_sources.length - 1];
            if (previous.metadata == metadata_ && previous.provider == provider) {
                revert ConservationFloorSourceUnavailable();
            }
        }
    }

    function _providerIdentity(StreamConservationFloorTypes.Source memory s) private view {
        uint256 cap = _gasParameterValue(READ_GAS);
        (address metadata_, bytes32 metadataHash) = StreamConservationFloorReads.selected(
            _readContext(), keccak256("COLLECTION_METADATA")
        );
        if (
            s.metadata != metadata_ || s.metadataCodeHash != metadataHash
                || s.provider.code.length == 0 || s.provider.codehash != s.providerCodeHash
                || s.configurationHash == 0
                || StreamConservationFloorReads.word(
                        s.provider, abi.encodeCall(IStreamConservationFloorProvider.core, ()), cap
                    ) != uint160(core)
                || bytes32(
                        StreamConservationFloorReads.word(
                            s.provider,
                            abi.encodeCall(IStreamConservationFloorProvider.coreCodeHash, ()),
                            cap
                        )
                    ) != coreCodeHash
                || StreamConservationFloorReads.word(
                        s.provider,
                        abi.encodeCall(IStreamConservationFloorProvider.metadata, ()),
                        cap
                    ) != uint160(s.metadata)
                || bytes32(
                        StreamConservationFloorReads.word(
                            s.provider,
                            abi.encodeCall(IStreamConservationFloorProvider.metadataCodeHash, ()),
                            cap
                        )
                    ) != s.metadataCodeHash
                || bytes32(
                        StreamConservationFloorReads.word(
                            s.provider,
                            abi.encodeCall(IStreamConservationFloorProvider.configurationHash, ()),
                            cap
                        )
                    ) != s.configurationHash
                || StreamConservationFloorReads.word(
                        s.provider,
                        abi.encodeCall(IStreamConservationFloorProvider.deploymentChainId, ()),
                        cap
                    ) != deploymentChainId
                || StreamConservationFloorReads.word(
                        s.provider,
                        abi.encodeCall(
                            IERC165.supportsInterface,
                            (type(IStreamConservationFloorProvider).interfaceId)
                        ),
                        cap
                    ) != 1
                || StreamConservationFloorReads.word(
                        s.provider,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                        cap
                    ) != 0
        ) revert ConservationFloorSourceUnavailable();
    }

    function _producer(
        StreamConservationFloorTypes.Source memory s,
        bytes memory input,
        uint256 size
    ) private view returns (bytes memory) {
        return StreamConservationFloorReads.read(
            s.provider, input, size, _gasParameterValue(PRODUCER_GAS)
        );
    }

    function _sourceState(uint64 count, bytes32 head) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(SOURCE_DOMAIN, deploymentChainId, core, address(this), count, head)
            );
    }

    function _nextSource(bytes32 head, uint64 id, StreamConservationFloorTypes.Source memory s)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                SOURCE_DOMAIN,
                head,
                id,
                s.metadata,
                s.metadataCodeHash,
                s.provider,
                s.providerCodeHash,
                s.configurationHash,
                s.predecessor
            )
        );
    }

    function _readContext() private view returns (StreamConservationFloorReads.Context memory) {
        return StreamConservationFloorReads.Context(
            core, coreCodeHash, deploymentChainId, _gasParameterValue(READ_GAS)
        );
    }

    function _context() private view returns (StreamConservationFloorReads.Context memory x) {
        x = _readContext();
        StreamConservationFloorReads.requireBound(x);
    }
}
