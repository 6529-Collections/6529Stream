// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";

/// @dev Test-only original body from 9dd5aeaa4f0620a3684e5431dbac7cd37a2c9d19.
/// The copied getter observes the actual Manager configuration, and the same Ledger holds definitions
/// registered before first use. Thus both hosts select the same definitions without fake Ledger writes.
contract MintSubjectOriginalReference {
    IStreamMintManager private immutable source;
    IStreamMintLedger public immutable mintLedger;

    constructor(IStreamMintManager manager_, IStreamMintLedger ledger_) {
        source = manager_;
        mintLedger = ledger_;
    }

    function counterConfig(uint256 collectionId, bytes32 phaseId, bytes32 counterId)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory)
    {
        return source.counterConfig(collectionId, phaseId, counterId);
    }

    function previewSubjectKey(
        IStreamMintManager.CounterKeyMode keyMode,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        address payer,
        address recipient,
        address executor,
        address authorizer,
        bytes32 contextHash
    ) external view returns (bytes32) {
        StreamMintOperationIdentity.SubjectContext memory context =
            StreamMintOperationIdentity.SubjectContext({
                chainId: block.chainid,
                ledger: address(mintLedger),
                collectionId: collectionId,
                phaseId: phaseId,
                counterId: counterId,
                payer: payer,
                recipient: recipient,
                executor: executor,
                authorizer: authorizer,
                contextHash: contextHash
            });
        return StreamMintManagerAccounting.previewSubject(keyMode, context);
    }
}

/// @dev An external caller deliberately advertises a different config. Preview must read the Manager.
contract MintSubjectPoisonReader {
    function counterConfig(uint256, bytes32, bytes32)
        external
        pure
        returns (IStreamMintManager.MintCounterConfig memory c)
    {
        c.counterConfigHash = keccak256("unknown caller definition defaults to PHASE");
    }

    function read(address target, bytes calldata data) external view returns (bytes32) {
        (bool ok, bytes memory result) = target.staticcall(data);
        require(ok && result.length == 32, "target preview failed");
        return abi.decode(result, (bytes32));
    }
}

/// @dev Actual Manager, Ledger and Registry; explicit typed Core/Artist/governance dependencies.
/// These read-only vectors do not claim mint admission or actual Artist/Safe acceptance coverage.
contract StreamMintSubjectPreviewTest is MintEngineTestBase {
    bytes32 private constant COUNTER = keccak256("subject preview counter");
    bytes32 private constant GLOBAL_PHASE = keccak256("subject global phase");
    bytes32 private constant COLLECTION_PHASE = keccak256("subject collection phase");
    bytes32 private constant LOCAL_PHASE = keccak256("subject local phase");
    bytes32 private constant SUBJECT_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1");
    MintSubjectOriginalReference private original;

    struct Inputs {
        IStreamMintManager.CounterKeyMode mode;
        uint256 collection;
        bytes32 phase;
        bytes32 counter;
        address payer;
        address recipient;
        address executor;
        address authorizer;
        bytes32 contextHash;
    }

    function setUp() public override {
        super.setUp();
        _configure(GLOBAL_PHASE, IStreamMintCounterPolicy.CounterScope.GLOBAL);
        _configure(COLLECTION_PHASE, IStreamMintCounterPolicy.CounterScope.COLLECTION);
        _configure(LOCAL_PHASE, IStreamMintCounterPolicy.CounterScope.PHASE);
        original = new MintSubjectOriginalReference(manager, ledger);
    }

    function _configure(bytes32 phase, IStreamMintCounterPolicy.CounterScope scope) private {
        bytes32 definition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                scope, IStreamMintManager.CounterKeyMode.CONSTANT, 0, keccak256(abi.encode(phase))
            )
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            definition
        );
        IStreamMintManager.MintGateConfig memory gate;
        // Preview is available even though this phase is paused, not yet started and has no executor.
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(
                true,
                uint64(block.timestamp + 100),
                uint64(block.timestamp + 200),
                1,
                keccak256("subject terms"),
                0
            ),
            gate,
            ids,
            configs
        );
    }

    function _inputs() private pure returns (Inputs memory) {
        return Inputs(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            1,
            GLOBAL_PHASE,
            COUNTER,
            address(0xA101),
            address(0xA202),
            address(0xA303),
            address(0xA404),
            keccak256("subject context")
        );
    }

    function _encoded(Inputs memory p) private pure returns (bytes memory) {
        // The static nine-field tuple has the same layout as the original nine ABI arguments.
        return abi.encodePacked(IStreamMintManager.previewSubjectKey.selector, abi.encode(p));
    }

    function _compare(bytes memory data) private view returns (bool ok, bytes memory result) {
        (bool oldOk, bytes memory oldResult) = address(original).staticcall(data);
        (ok, result) = address(manager).staticcall(data);
        require(
            ok == oldOk && keccak256(result) == keccak256(oldResult),
            "original/new exact returndata"
        );
    }

    function _assertValue(Inputs memory p, bytes32 expected) private view returns (bytes32 actual) {
        (bool ok, bytes memory result) = _compare(_encoded(p));
        require(ok && result.length == 32, "canonical bytes32 preview");
        actual = abi.decode(result, (bytes32));
        require(actual == expected, "independent literal subject preimage");
    }

    function _constant(address selectedLedger, uint256 collection, bytes32 phase, bytes32 counter)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                SUBJECT_DOMAIN,
                block.chainid,
                selectedLedger,
                IStreamMintManager.CounterKeyMode.CONSTANT,
                collection,
                phase,
                counter
            )
        );
    }

    function _missing(Inputs memory p) private view {
        (bool ok, bytes memory result) = _compare(_encoded(p));
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamMintManager.MintCounterSubjectMissing.selector, p.counter, p.mode
                        )
                    ),
            "same original missing-subject error"
        );
    }

    function _word(bytes memory data, uint256 index, uint256 value) private pure {
        require(index < 9, "static argument index");
        assembly ("memory-safe") { mstore(add(add(data, 36), mul(index, 32)), value) }
    }

    function testAllSubjectModesMatchOriginalAndIndependentPreimages() public view {
        Inputs memory p = _inputs();
        _assertValue(p, _constant(address(ledger), 0, 0, COUNTER));
        // The original preview accepts a requested mode distinct from the configured CONSTANT mode.
        for (uint256 mode = 2; mode <= 5; ++mode) {
            p.mode = IStreamMintManager.CounterKeyMode(mode);
            address account = mode == 2
                ? p.payer
                : mode == 3 ? p.recipient : mode == 4 ? p.executor : p.authorizer;
            _assertValue(
                p,
                keccak256(
                    abi.encode(SUBJECT_DOMAIN, block.chainid, address(ledger), p.mode, account)
                )
            );
        }
        p.mode = IStreamMintManager.CounterKeyMode.CONTEXT;
        _assertValue(
            p,
            keccak256(
                abi.encode(SUBJECT_DOMAIN, block.chainid, address(ledger), p.mode, p.contextHash)
            )
        );
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0, "preview never executes mint"
        );
    }

    function testActualCounterSelectionRetainsAllThreeScopeNormalizations() public view {
        Inputs memory p = _inputs();
        bytes32 global = _assertValue(p, _constant(address(ledger), 0, 0, COUNTER));
        p.phase = COLLECTION_PHASE;
        bytes32 collection = _assertValue(p, _constant(address(ledger), 1, 0, COUNTER));
        p.phase = LOCAL_PHASE;
        bytes32 local = _assertValue(p, _constant(address(ledger), 1, LOCAL_PHASE, COUNTER));
        require(
            global != collection && collection != local && global != local,
            "scope distinctions survive extraction"
        );
    }

    function testUnknownPhaseCounterCollectionAndZeroIdentityRemainObservational() public view {
        Inputs memory p = _inputs();
        p.phase = keccak256("unconfigured phase");
        _assertValue(p, _constant(address(ledger), 1, p.phase, COUNTER));
        p.phase = GLOBAL_PHASE;
        p.counter = keccak256("unknown counter");
        _assertValue(p, _constant(address(ledger), 1, p.phase, p.counter));
        p.counter = COUNTER;
        p.collection = 2;
        _assertValue(p, _constant(address(ledger), 2, p.phase, COUNTER));
        p.collection = 0;
        p.phase = 0;
        p.counter = 0;
        _assertValue(p, _constant(address(ledger), 0, 0, 0));
    }

    function testCanonicalUnknownModeAndAbsentSubjectsKeepExactOriginalErrors() public view {
        Inputs memory p = _inputs();
        p.mode = IStreamMintManager.CounterKeyMode.UNKNOWN;
        _missing(p);
        for (uint256 mode = 2; mode <= 5; ++mode) {
            p = _inputs();
            p.mode = IStreamMintManager.CounterKeyMode(mode);
            if (mode == 2) p.payer = address(0);
            else if (mode == 3) p.recipient = address(0);
            else if (mode == 4) p.executor = address(0);
            else p.authorizer = address(0);
            _missing(p);
        }
        p = _inputs();
        p.mode = IStreamMintManager.CounterKeyMode.CONTEXT;
        p.contextHash = 0;
        _missing(p);
    }

    function testInvalidEnumAndNoncanonicalAddressWordsRejectLikeOriginal() public view {
        bytes memory data = _encoded(_inputs());
        _word(data, 0, 7);
        (bool ok,) = _compare(data);
        require(!ok, "out of range enum rejected");
        _word(data, 0, uint256(1) << 200);
        (ok,) = _compare(data);
        require(!ok, "enum high bits rejected");
        for (uint256 index = 4; index <= 7; ++index) {
            data = _encoded(_inputs());
            _word(data, index, (uint256(1) << 160) | uint256(uint160(address(0xA101))));
            (ok,) = _compare(data);
            require(!ok, "address high bits rejected even for unused CONSTANT subject fields");
        }
    }

    function testTruncatedStaticTupleRejectsAndOriginalTrailingBytesRemainAccepted() public view {
        bytes memory complete = _encoded(_inputs());
        uint256[4] memory lengths = [uint256(4), uint256(35), uint256(260), uint256(291)];
        for (uint256 n; n < lengths.length; ++n) {
            bytes memory shortData = new bytes(lengths[n]);
            for (uint256 j; j < shortData.length; ++j) {
                shortData[j] = complete[j];
            }
            (bool ok,) = _compare(shortData);
            require(!ok, "incomplete original static tuple rejected");
        }
        (bool originalOk, bytes memory canonical) = _compare(complete);
        (bool trailingOk, bytes memory trailing) = _compare(bytes.concat(complete, hex"1234567890"));
        require(
            originalOk && trailingOk && keccak256(canonical) == keccak256(trailing),
            "trailing bytes do not alter subject"
        );
    }

    function testActualHostGetterImmutableLedgerAndCurrentChainRemainTheIdentity() public {
        Inputs memory p = _inputs();
        MintSubjectPoisonReader caller = new MintSubjectPoisonReader();
        bytes32 expected = _constant(address(ledger), 0, 0, COUNTER);
        require(
            caller.read(address(manager), _encoded(p)) == expected,
            "reads actual Manager configuration, not caller"
        );
        StreamMintLedger otherLedger = new StreamMintLedger();
        StreamMintManager otherManager = _manager(address(otherLedger));
        // This changes only the explicit typed Core seam. Subject identity uses the immutable Ledger.
        MintEngineCoreFixture(address(core)).setMintLedger(address(otherLedger));
        _assertValue(p, expected);
        require(
            caller.read(address(otherManager), _encoded(p))
                == _constant(address(otherLedger), 1, GLOBAL_PHASE, COUNTER),
            "other actual host observes its own immutable Ledger and absent config"
        );
        vm.chainId(block.chainid + 1);
        bytes32 otherChain = _assertValue(p, _constant(address(ledger), 0, 0, COUNTER));
        require(otherChain != expected, "original current-chain binding preserved");
    }
}
