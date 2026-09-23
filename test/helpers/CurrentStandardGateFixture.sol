// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/mint/StreamMintAllowlistGate.sol";
import "../../smart-contracts/domains/mint/StreamDelegateRegistryGate.sol";
import "../../smart-contracts/domains/mint/StreamMintTicketGate.sol";

/// @dev External delegate-v2 ABI response fixture, not upstream registry bytecode or authority evidence.
contract CurrentGateDelegationService {
    mapping(bytes32 => bool) private grants;

    function delegateContract(address delegate, address target, bytes32 rights, bool enabled)
        external
    {
        grants[keccak256(abi.encode(msg.sender, delegate, target, rights))] = enabled;
    }

    function checkDelegateForContract(
        address delegate,
        address vault,
        address target,
        bytes32 rights
    ) external view returns (bool) {
        return grants[keccak256(abi.encode(vault, delegate, target, rights))];
    }
}

/// @dev External recipient fault. A failed batch rolls back even the first successful callback.
contract CurrentGateRecipient {
    uint256 public callbacks;
    uint256 public rejectAt = 2;

    function setRejectAt(uint256 value) external {
        rejectAt = value;
    }

    function grant(
        CurrentGateDelegationService service,
        address delegate,
        address target,
        bytes32 rights
    ) external {
        service.delegateContract(delegate, target, rights, true);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        ++callbacks;
        require(rejectAt == 0 || callbacks != rejectAt, "late gate recipient fault");
        return this.onERC721Received.selector;
    }
}

/// @notice Real current Core/Artist/Manager/Ledger, original gates and threshold Safe principals.
/// @dev Counter proofs use the original inline StreamMintCounterPreparation path and Ledger
/// definition registry. The external delegation service and entropy service are explicit doubles.
abstract contract CurrentStandardGateFixture is StreamCurrentSafeGovernanceFixture {
    uint8 internal constant ALLOW = 0;
    uint8 internal constant DELEGATE = 1;
    uint8 internal constant TICKET = 2;
    bytes32 internal constant ALLOCATION = keccak256("current gate beneficiary allocation");
    bytes32 internal constant USECASE = keccak256("current gate mint eligibility");
    uint32 internal constant GATE_GAS = 600000;
    OfficialSafe internal gateArtist;
    OfficialSafe internal gateCaller;
    OfficialSafe internal gateVault;
    OfficialSafe internal gateSigner;
    uint256[] internal gateKeys;
    StreamMintAllowlistGate internal allowGate;
    StreamDelegateRegistryGate internal delegateGate;
    StreamMintTicketGate internal signedGate;
    CurrentGateDelegationService internal delegationService;
    CurrentGateRecipient internal faultyRecipient;
    bytes32[2][3] internal gateLeaves;
    bytes32[3] internal definitionHashes;

    function _constructStandardGates() internal {
        gateKeys.push(0x65294701);
        gateKeys.push(0x65294702);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        address[] memory owners = safeOwnerAddresses(gateKeys);
        gateArtist = createOfficialSafe(safe, owners, 2, 94701);
        gateCaller = createOfficialSafe(safe, owners, 2, 94702);
        gateVault = createOfficialSafe(safe, owners, 2, 94703);
        gateSigner = createOfficialSafe(safe, owners, 2, 94704);
        OfficialSafe root = createOfficialSafe(safe, owners, 2, 94705);
        _deployCurrentStack(address(gateArtist), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(root, gateKeys);
        _admitStandardGates();
        for (uint8 i; i < 3; ++i) {
            _configureGatePhase(i);
        }
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(gateKeys, safeMessageDigest(gateArtist, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        delegationService = new CurrentGateDelegationService();
        faultyRecipient = new CurrentGateRecipient();
        IStreamMintCounterPolicy.AllowlistProof memory proof;
        proof.maxCount = 3;
        for (uint8 i; i < 3; ++i) {
            gateLeaves[i][0] = StreamMintCounterPolicy.allowlistLeaf(
                address(manager), 1, _gatePhase(i), ALLOCATION, address(gateVault), proof
            );
            gateLeaves[i][1] = StreamMintCounterPolicy.allowlistLeaf(
                address(manager), 1, _gatePhase(i), ALLOCATION, address(faultyRecipient), proof
            );
        }
        allowGate = StreamMintAllowlistGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintAllowlistGate.sol:StreamMintAllowlistGate",
                abi.encode(_root(ALLOW), ALLOCATION)
            )
        );
        delegateGate = StreamDelegateRegistryGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamDelegateRegistryGate.sol:StreamDelegateRegistryGate",
                abi.encode(address(core), address(delegationService), USECASE, address(executor))
            )
        );
        signedGate = StreamMintTicketGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate",
                abi.encode(address(executor), address(gateSigner), uint8(2))
            )
        );
        _assertDeployableProductionInstance(address(allowGate));
        _assertDeployableProductionInstance(address(delegateGate));
        _assertDeployableProductionInstance(address(signedGate));
    }

    function _gatePhase(uint8 kind) internal pure returns (bytes32) {
        return keccak256(abi.encode("current original gate join phase", kind));
    }

    function _root(uint8 kind) internal view returns (bytes32) {
        bytes32 a = gateLeaves[kind][0];
        bytes32 b = gateLeaves[kind][1];
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _gate(uint8 kind) internal view returns (address) {
        return kind == ALLOW
            ? address(allowGate)
            : kind == DELEGATE ? address(delegateGate) : address(signedGate);
    }

    function _gateVersion(uint8 kind) internal view returns (bytes32) {
        return kind == DELEGATE
            ? delegateGate.MODULE_VERSION()
            : keccak256(abi.encode("current original gate join version", kind));
    }

    function _gateManifest(uint8 kind) internal view returns (bytes32) {
        return kind == DELEGATE
            ? delegateGate.moduleManifestHash()
            : keccak256(abi.encode("current original gate join manifest", kind));
    }

    function _gateConfiguration(uint8 kind)
        internal
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        address target = _gate(kind);
        bytes32 configHash = kind == ALLOW
            ? allowGate.gateConfigHash()
            : kind == DELEGATE ? delegateGate.gateConfigHash() : signedGate.gateConfigHash();
        return IStreamMintManager.MintGateConfig(
            target,
            configHash,
            target.codehash,
            keccak256(abi.encode(_gateVersion(kind), _gateManifest(kind))),
            0,
            GATE_GAS
        );
    }

    function _admitStandardGates() private {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](3);
        for (uint8 i; i < 3; ++i) {
            rows[i] = StreamModuleRegistration(
                _gate(i),
                keccak256("6529STREAM_MINT_GATE_V1"),
                _gateVersion(i),
                type(IStreamMintGate).interfaceId,
                GATE_GAS,
                _gate(i).codehash,
                DEPLOYMENT_HASH,
                _gateManifest(i),
                "urn:fixture:original-standard-gate"
            );
        }
        (GovernanceCall[] memory calls, bytes[] memory datas) =
            StreamCurrentStackPlan.registrationCalls(registry, rows);
        GovernanceCall[] memory stagedCalls = new GovernanceCall[](4);
        bytes[] memory stagedDatas = new bytes[](4);
        for (uint256 i; i < 3; ++i) {
            stagedCalls[i] = calls[i];
            stagedDatas[i] = datas[i];
        }
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"fixture\":true,\"scope\":\"original gate admissions\"}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:original-gates",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (stagedCalls[3], stagedDatas[3]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
        (bytes32 id, uint64 ready) = _scheduleBatchAsGovernor(1, stagedCalls, stagedDatas);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (id, stagedCalls, stagedDatas))
        );
        for (uint8 i; i < 3; ++i) {
            require(
                registry.moduleRecord(_gate(i)).status == ModuleRegistryStatus.ACTIVE,
                "original gate admitted by Safe"
            );
        }
    }

    function _configureGatePhase(uint8 kind) private {
        bytes32 phase = _gatePhase(kind);
        definitionHashes[kind] = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.PHASE,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                _root(kind),
                keccak256("current gate proof metadata")
            )
        );
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            definitionHashes[kind]
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = ALLOCATION;
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            3,
            keccak256(abi.encode("current gate terms", kind)),
            keccak256("current gate metadata")
        );
        IStreamMintManager.MintGateConfig memory gate = _gateConfiguration(kind);
        address[] memory enabled = new address[](0);
        _recordFixturePolicy(
            phase, manager.previewPhasePolicyHash(1, phase, config, gate, ids, counters, enabled)
        );
        _gateOwnerCall(
            abi.encodeCall(manager.configurePhase, (1, phase, config, gate, ids, counters))
        );
        enabled = new address[](1);
        enabled[0] = address(gateCaller);
        _recordFixturePolicy(
            phase, manager.previewPhasePolicyHash(1, phase, config, gate, ids, counters, enabled)
        );
        _gateOwnerCall(
            abi.encodeCall(manager.setPhaseExecutor, (1, phase, address(gateCaller), true))
        );
        artists.requireMintConsent(1, phase, manager.phasePolicyHash(1, phase));
    }

    function _gateOwnerCall(bytes memory data) private {
        _govern(
            _governanceRequest(
                1,
                address(manager),
                data,
                keccak256(abi.encode(address(manager), data)),
                0,
                keccak256(data)
            )
        );
    }

    function _gateBatch(
        uint8 kind,
        uint256 nonce,
        address delivery,
        address beneficiary,
        uint256 quantity
    ) internal view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = 1;
        b.phaseId = _gatePhase(kind);
        b.payer = BUYER;
        b.authorizer = kind == TICKET ? address(gateSigner) : address(0);
        b.initialRecipients = new address[](quantity);
        b.beneficiaries = new address[](quantity);
        b.tokenData = new bytes[](quantity);
        b.mintCommitments = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            b.initialRecipients[i] = delivery;
            b.beneficiaries[i] = beneficiary;
            b.tokenData[i] = abi.encode("original gate token", kind, nonce, i);
            b.mintCommitments[i] = keccak256(abi.encode("original gate commitment", kind, nonce, i));
        }
        b.contextHash = keccak256(abi.encode("original gate context", nonce));
        b.expectedPolicyHash = manager.phasePolicyHash(1, b.phaseId);
        b.resolverData = _resolver(kind, b.beneficiaries);
    }

    function _resolver(uint8 kind, address[] memory beneficiaries)
        internal
        view
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](beneficiaries.length);
        for (uint256 i; i < beneficiaries.length; ++i) {
            require(
                beneficiaries[i] == address(gateVault)
                    || beneficiaries[i] == address(faultyRecipient),
                "known proof subject"
            );
            groups[0][i].maxCount = 3;
            groups[0][i].proof = new bytes32[](1);
            groups[0][i].proof[0] = gateLeaves[kind][beneficiaries[i] == address(gateVault) ? 1 : 0];
        }
        return abi.encode(groups);
    }

    function _authorizeGate(uint8 kind, IStreamMintManager.MintBatch memory b, bytes32 nonce)
        internal
        returns (bytes memory proof, bytes32 nullifier)
    {
        if (kind == ALLOW) {
            proof = abi.encode(nonce);
            b.authorizationId =
                allowGate.previewAuthorizationId(address(manager), address(gateCaller), b, nonce);
            nullifier = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_ALLOWLIST_GATE_NONCE_V1"),
                    block.chainid,
                    address(allowGate),
                    address(manager),
                    address(ledger),
                    b.collectionId,
                    b.phaseId,
                    b.payer,
                    nonce
                )
            );
        } else if (kind == DELEGATE) {
            proof = abi.encode(b.beneficiaries[0], nonce);
            StreamDelegateRegistryGate.MintRequest memory r = StreamDelegateRegistryGate.MintRequest(
                address(manager),
                address(gateCaller),
                b.collectionId,
                b.phaseId,
                b.payer,
                b.authorizer,
                b.initialRecipients,
                b.beneficiaries,
                b.contextHash,
                b.expectedPolicyHash,
                proof
            );
            b.authorizationId = keccak256(
                abi.encode(
                    keccak256("6529STREAM_DELEGATE_MINT_AUTHORIZATION_V1"),
                    block.chainid,
                    address(delegateGate),
                    delegateGate.gateConfigHash(),
                    r
                )
            );
            nullifier = keccak256(
                abi.encode(
                    keccak256("6529STREAM_DELEGATE_MINT_NONCE_V1"),
                    block.chainid,
                    address(delegateGate),
                    address(manager),
                    b.collectionId,
                    b.phaseId,
                    b.payer,
                    b.beneficiaries[0],
                    nonce
                )
            );
        } else {
            StreamMintTicketTypes.MintTicket memory t = _gateTicket(b, nonce);
            b.authorizationId = manager.mintTicketAuthorizationId(t, address(signedGate));
            bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(signedGate), t);
            proof = abi.encode(
                t,
                safeThresholdSignature(gateKeys, safeMessageDigest(gateSigner, abi.encode(digest)))
            );
        }
    }

    function _gateTicket(IStreamMintManager.MintBatch memory b, bytes32 nonce)
        private
        view
        returns (StreamMintTicketTypes.MintTicket memory t)
    {
        t.chainId = block.chainid;
        t.manager = address(manager);
        t.ledger = address(ledger);
        t.collectionId = b.collectionId;
        t.phaseId = b.phaseId;
        t.executor = address(gateCaller);
        t.payer = b.payer;
        t.authorizer = b.authorizer;
        t.authorizerKind = 2;
        t.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        t.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        t.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        t.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        t.quantity = b.initialRecipients.length;
        t.contextHash = b.contextHash;
        t.policyHash = b.expectedPolicyHash;
        t.nonce = nonce;
        t.deadline = uint64(block.timestamp + 1 days);
    }

    function _vaultGrant(address delegate, bytes32 rights, bool enabled) internal {
        require(
            executeSafe(
                gateVault,
                gateKeys,
                address(delegationService),
                0,
                abi.encodeCall(
                    delegationService.delegateContract, (delegate, address(core), rights, enabled)
                ),
                0
            ),
            "actual vault Safe grant call"
        );
    }

    function _gateValueKey(IStreamMintManager.MintBatch memory b, address beneficiary)
        internal
        view
        returns (bytes32)
    {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            b.collectionId,
            b.phaseId,
            ALLOCATION,
            b.payer,
            beneficiary,
            address(gateCaller),
            b.authorizer,
            b.contextHash
        );
        return manager.previewCounterValueKey(b.collectionId, b.phaseId, ALLOCATION, subject);
    }

    function _mintGateCall(IStreamMintManager.MintBatch memory b, bytes memory proof, bool prepared)
        internal
        view
        returns (bytes memory)
    {
        return prepared
            ? abi.encodeCall(manager.executePreparedMint, (b, proof))
            : abi.encodeCall(manager.executeSingleStepMint, (b, proof));
    }

    function _gateEnvelope(OfficialSafe caller, bytes memory data) internal returns (bytes memory) {
        bytes32 digest = caller.getTransactionHash(
            address(manager), 0, data, 0, 0, 0, 0, address(0), address(0), caller.nonce()
        );
        return abi.encodeCall(
            caller.execTransaction,
            (
                address(manager),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(gateKeys, digest)
            )
        );
    }

    function _sendGateEnvelope(OfficialSafe caller, bytes memory envelope, bool success) internal {
        (bool ok, bytes memory data) = address(caller).call(envelope);
        if (success) {
            require(ok && abi.decode(data, (bool)), "actual Safe mint committed");
        } else {
            require(
                !ok
                    && keccak256(data)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "actual Safe mint failure"
            );
        }
    }

    function _gateReceipt(IStreamMintManager.MintBatch memory b, Vm.Log[] memory logs)
        internal
        view
        returns (bytes32 root)
    {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(ledger) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) continue;
            require(
                logs[i].topics[1] == b.authorizationId
                    && address(uint160(uint256(logs[i].topics[3]))) == address(manager)
                    && keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), b.expectedPolicyHash)),
                "exact original authorization receipt"
            );
            root = logs[i].topics[2];
            ++found;
        }
        require(found == 1 && root != 0, "one original Ledger authorization trace");
    }

    function _assertGateUnused(IStreamMintManager.MintBatch memory b, bytes32 nullifier)
        internal
        view
    {
        require(
            !manager.isAuthorizationUsed(b.authorizationId)
                && !ledger.isManagerAuthorizationUsed(address(manager), b.authorizationId)
                && (nullifier == 0
                    || (!manager.isNullifierUsed(nullifier)
                        && !ledger.isManagerNullifierUsed(address(manager), nullifier))),
            "original gate replay state unused"
        );
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.collectionMintedEver(1) == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0 && gateCaller.nonce() == 0
                && ledger.counterValue(_gateValueKey(b, b.beneficiaries[0])) == 0,
            "no original token, nonce or beneficiary debit"
        );
    }
}
