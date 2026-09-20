// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import { StreamBurnRedemption } from "../../smart-contracts/domains/mint/StreamBurnRedemption.sol";
import {
    IStreamBurnRedemption as Redemption
} from "../../smart-contracts/interfaces/stream/mint/IStreamBurnRedemption.sol";

interface CurrentRedemptionCallVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Actual Core/Manager/Ledger/Artist, governed registry admission and threshold Safe redemption.
/// @dev Only the shared fixture's external entropy provider is a service boundary. Fulfillment
/// remains an operator assertion. The terminal case proves Core's burn block, not artwork finality.
contract StreamCurrentBurnRedemptionTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant SEED_PHASE = keccak256("current redemption source mint");
    bytes32 private constant TERMS = keccak256("original physical redemption terms");
    bytes32 private constant REFERENCE = keccak256("redeemer fulfillment reference");
    bytes32 private constant MODULE_MANIFEST = keccak256("current redemption module manifest");
    string private constant URI = "ipfs://original-redemption-reference";
    address private constant HOLDER = address(0xB012);
    address private constant CALLER = address(0xCA113);
    address private constant STRANGER = address(0xBAD);

    StreamBurnRedemption private redemptionHost;
    OfficialSafe private artistSafe;
    OfficialSafe private holderSafe;
    OfficialSafe private operatorSafe;
    uint256[] private artistKeys;
    uint256[] private holderKeys;
    uint256[] private operatorKeys;
    bytes32 private saleId;
    uint256 private seedNonce;
    bytes32 private admissionAction;
    mapping(uint256 => bytes32) private sourceAuthorization;
    mapping(uint256 => bytes32) private sourceOperation;

    function setUp() public {
        artistKeys = _keys(0xAD010);
        holderKeys = _keys(0xAD020);
        operatorKeys = _keys(0xAD030);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(artistKeys), 2, 7101);
        holderSafe = createOfficialSafe(components, safeOwnerAddresses(holderKeys), 2, 7102);
        operatorSafe = createOfficialSafe(components, safeOwnerAddresses(operatorKeys), 2, 7103);
        this.deployRedemptionScenario();
    }

    /// @dev Fixed self-call keeps the large current graph outside individual test frames.
    function deployRedemptionScenario() external {
        require(msg.sender == address(this), "fixture self-call");
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        uint256[] memory keys = _keys(0xAD040);
        OfficialSafe governor =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 7104);
        this.installRedemptionGovernor(governor, keys);
        this.admitRedemption();
        uint64 now_ = uint64(this.redemptionTime());
        saleId = _program(TERMS, now_, now_ + 90 days);
    }

    function redemptionTime() external view returns (uint256) {
        return block.timestamp;
    }

    function installRedemptionGovernor(OfficialSafe governor, uint256[] calldata keys) external {
        require(msg.sender == address(this), "fixture self-call");
        _installGovernorSafe(governor, keys);
    }

    function _keys(uint256 first) private pure returns (uint256[] memory keys) {
        keys = new uint256[](2);
        keys[0] = first;
        keys[1] = first + 1;
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(artistKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        redemptionHost = new StreamBurnRedemption(
            StreamBurnRedemption.Configuration(
                address(core),
                address(registry),
                address(executor),
                address(operatorSafe),
                DEPLOYMENT_HASH,
                MODULE_MANIFEST,
                "ipfs://current-burn-redemption",
                IStreamGasParameterHost.GasParameterConfig(
                    "BURN_DEPENDENCY_READ_GAS", 300_000, 100_000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig(
                    "BURN_EXECUTION_GAS", 2_000_000, 200_000, 2
                )
            )
        );
        _assertDeployableProductionInstance(address(redemptionHost));
    }

    function _configureAdditionalProducts() internal override {
        _configureMintPhase(SEED_PHASE, address(this));
    }

    function admitRedemption() external {
        require(msg.sender == address(this), "fixture self-call");
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(redemptionHost),
            redemptionHost.streamModuleType(),
            redemptionHost.streamModuleVersion(),
            type(Redemption).interfaceId,
            400_000,
            address(redemptionHost).codehash,
            DEPLOYMENT_HASH,
            MODULE_MANIFEST,
            "ipfs://current-burn-redemption"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        admissionAction = action;
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual delayed admission completed"
        );
    }

    function _program(bytes32 terms, uint64 start, uint64 end) private returns (bytes32 id) {
        uint256 nonce = redemptionHost.nextSaleNonce();
        id = _saleId(nonce);
        _operator(
            abi.encodeCall(
                redemptionHost.registerProgram, (Redemption.ProgramConfig(1, start, end, terms))
            )
        );
        require(redemptionHost.program(id).saleNonce == nonce, "Safe registered exact program");
    }

    function _saleId(uint256 nonce) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(redemptionHost),
                uint8(9),
                uint256(1),
                bytes32(0),
                nonce
            )
        );
    }

    function _operator(bytes memory data) private {
        require(
            executeSafe(operatorSafe, operatorKeys, address(redemptionHost), 0, data, 0),
            "operator threshold Safe CALL"
        );
    }

    function _holder(bytes memory data) private {
        require(executeSafe(holderSafe, holderKeys, address(core), 0, data, 0), "holder Safe CALL");
    }

    function _seed(address recipient) private returns (uint256 token) {
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = SEED_PHASE;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = recipient;
        batch.beneficiaries = batch.initialRecipients;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256(abi.encode("redemption source", ++seedNonce));
        batch.expectedPolicyHash = manager.phasePolicyHash(1, SEED_PHASE);
        batch.authorizationId = keccak256(abi.encode("redemption mint", seedNonce));
        (uint256[] memory tokens, bytes32 root,) = manager.executeSingleStepMint(batch, "");
        require(tokens.length == 1 && core.ownerOf(tokens[0]) == recipient, "actual source mint");
        token = tokens[0];
        sourceAuthorization[token] = batch.authorizationId;
        sourceOperation[token] = root;
        _assertSeedReplay(token);
    }

    function _assertSeedReplay(uint256 token) private view {
        require(
            ledger.isManagerAuthorizationUsed(address(manager), sourceAuthorization[token])
                && ledger.isManagerOperationRootUsed(address(manager), sourceOperation[token]),
            "original mint Ledger evidence remains consumed"
        );
    }

    function _approveHost(address owner_) private {
        if (owner_ == address(holderSafe)) {
            _holder(abi.encodeCall(core.setApprovalForAll, (address(redemptionHost), true)));
        } else {
            vm.prank(owner_);
            core.setApprovalForAll(address(redemptionHost), true);
        }
    }

    function _redeem(address actor, bytes32 program, uint256 token) private returns (bytes32 id) {
        bytes memory callData =
            abi.encodeCall(redemptionHost.redeem, (program, token, TERMS, REFERENCE, URI));
        if (actor == address(holderSafe)) {
            require(
                executeSafe(holderSafe, holderKeys, address(redemptionHost), 0, callData, 0),
                "holder redeems"
            );
            return redemptionHost.redemptionIdFor(token);
        }
        vm.prank(actor);
        return redemptionHost.redeem(program, token, TERMS, REFERENCE, URI);
    }

    function _signedSafeCall(OfficialSafe account, uint256[] memory keys, bytes memory data)
        private
        returns (bytes memory)
    {
        bytes32 digest = account.getTransactionHash(
            address(redemptionHost), 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            account.execTransaction,
            (
                address(redemptionHost),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function _assertUntouched(bytes32 program, uint256 token, address owner_, bytes32 before_)
        private
        view
    {
        require(core.ownerOf(token) == owner_, "source ownership unchanged");
        require(_sourceState(program, token) == before_, "identity/supply/program/replay unchanged");
        _assertSeedReplay(token);
    }

    function _sourceState(bytes32 program, uint256 token) private view returns (bytes32) {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(token);
        return keccak256(
            abi.encode(
                exists,
                collection,
                serial,
                burned,
                core.lastAllocatedTokenId(),
                core.collectionNextSerial(1),
                core.collectionMintedEver(1),
                core.totalSupply(),
                core.totalSupplyOfCollection(1),
                redemptionHost.redemptionCount(program),
                redemptionHost.nextSaleNonce(),
                redemptionHost.program(program),
                ledger.isManagerAuthorizationUsed(address(manager), sourceAuthorization[token]),
                ledger.isManagerOperationRootUsed(address(manager), sourceOperation[token])
            )
        );
    }

    function testCurrentRedemptionGovernedAdmissionSafeBurnAndOriginalEvents() public {
        StreamModuleRecord memory module = registry.moduleRecord(address(redemptionHost));
        require(
            module.status == ModuleRegistryStatus.ACTIVE && module.revision == 1
                && module.runtimeCodeHash == address(redemptionHost).codehash
                && module.interfaceId == type(Redemption).interfaceId
                && module.moduleManifestHash == MODULE_MANIFEST,
            "actual admitted runtime"
        );
        require(
            executor.governanceAction(admissionAction).proposer == address(governorSafe),
            "Safe proposed actual admission"
        );
        require(
            redemptionHost.owner() == address(operatorSafe)
                && artists.acceptedArtist(1) == address(artistSafe),
            "distinct real operator and artist"
        );
        Redemption.Program memory program = redemptionHost.program(saleId);
        require(
            saleId == _saleId(1) && program.registryRevision == 1
                && program.config.termsHash == TERMS,
            "original kind9 program"
        );
        require(
            program.saleConfigHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_BURN_REDEMPTION_CONFIG_V1"),
                        block.chainid,
                        address(redemptionHost),
                        address(core),
                        saleId,
                        uint256(1),
                        uint8(9),
                        program.config,
                        bytes32(0),
                        address(0),
                        uint256(0),
                        bytes32(0),
                        uint8(0),
                        bytes32(0)
                    )
                ),
            "original config commitment"
        );
        uint256 token = _seed(address(holderSafe));
        _approveHost(address(holderSafe));
        uint256 allocated = core.lastAllocatedTokenId();
        uint256 nextSerial = core.collectionNextSerial(1);
        uint256 minted = core.collectionMintedEver(1);
        uint256 live = core.totalSupply();
        vm.recordLogs();
        bytes32 id = _redeem(address(holderSafe), saleId, token);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            id
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_REDEMPTION_V1"),
                        block.chainid,
                        address(redemptionHost),
                        address(core),
                        token
                    )
                ),
            "original redemption domain"
        );
        Redemption.Redemption memory item = redemptionHost.redemption(id);
        require(
            item.tokenOwner == address(holderSafe) && item.redeemer == address(holderSafe)
                && item.collectionId == 1 && item.collectionSerial == 1 && item.tokenId == token
                && item.saleId == saleId && item.termsHash == TERMS
                && item.fulfillmentReferenceHash == REFERENCE
                && keccak256(bytes(item.fulfillmentURI)) == keccak256(bytes(URI)),
            "exact original retained record"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(token);
        require(
            exists && burned && collection == 1 && serial == item.collectionSerial,
            "actual retained burned identity"
        );
        require(
            core.totalSupply() == live - 1 && core.totalSupplyOfCollection(1) == minted - 1
                && core.collectionMintedEver(1) == minted
                && core.lastAllocatedTokenId() == allocated
                && core.collectionNextSerial(1) == nextSerial,
            "burn reduces live supply without mint/allocation rewind"
        );
        require(
            redemptionHost.redemptionCount(saleId) == 1
                && redemptionHost.redemptionAt(saleId, 0) == id,
            "exact index"
        );
        _assertSeedReplay(token);
        _assertBurnEvents(logs, id, token, item);
    }

    function testCurrentRedemptionCallerAndHostNeedIndependentApprovals() public {
        uint256 token = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 before_ = _sourceState(saleId, token);
        vm.expectRevert(
            abi.encodeWithSelector(Redemption.RedemptionAuthorityRequired.selector, token)
        );
        vm.prank(STRANGER);
        redemptionHost.redeem(saleId, token, TERMS, REFERENCE, URI);
        _assertUntouched(saleId, token, HOLDER, before_);
        vm.prank(HOLDER);
        core.setApprovalForAll(address(redemptionHost), false);
        vm.prank(HOLDER);
        core.setApprovalForAll(CALLER, true);
        before_ = _sourceState(saleId, token);
        vm.expectRevert(
            abi.encodeWithSelector(Redemption.RedemptionAuthorityRequired.selector, token)
        );
        vm.prank(CALLER);
        redemptionHost.redeem(saleId, token, TERMS, REFERENCE, URI);
        _assertUntouched(saleId, token, HOLDER, before_);
        _approveHost(HOLDER);
        bytes32 id = _redeem(CALLER, saleId, token);
        require(
            redemptionHost.redemption(id).redeemer == CALLER
                && redemptionHost.redemption(id).tokenOwner == HOLDER,
            "separate authorized actor preserved"
        );
    }

    function testCurrentRedemptionTokenApprovalAndOperatorApprovalCompose() public {
        uint256 token = _seed(address(holderSafe));
        _holder(abi.encodeCall(core.approve, (address(redemptionHost), token)));
        _holder(abi.encodeCall(core.setApprovalForAll, (CALLER, true)));
        bytes32 id = _redeem(CALLER, saleId, token);
        require(
            redemptionHost.redemption(id).redeemer == CALLER
                && redemptionHost.redemption(id).tokenOwner == address(holderSafe),
            "token-specific host grant and independent caller grant"
        );
        uint256 second = _seed(HOLDER);
        vm.prank(HOLDER);
        core.approve(CALLER, second);
        _approveHost(HOLDER);
        bytes32 secondId = _redeem(CALLER, saleId, second);
        require(
            redemptionHost.redemption(secondId).collectionSerial == 2,
            "token-specific caller grant and blanket host grant"
        );
    }

    function testCurrentRedemptionTermsAndReferenceChecksNeverConsumeSource() public {
        uint256 token = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 before_ = _sourceState(saleId, token);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionTermsMismatch.selector));
        vm.prank(HOLDER);
        redemptionHost.redeem(saleId, token, bytes32(uint256(77)), REFERENCE, URI);
        _assertUntouched(saleId, token, HOLDER, before_);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionTermsMismatch.selector));
        vm.prank(HOLDER);
        redemptionHost.redeem(saleId, token, TERMS, 0, URI);
        _assertUntouched(saleId, token, HOLDER, before_);
        bytes32 id = _redeem(HOLDER, saleId, token);
        require(
            redemptionHost.redemption(id).termsHash == TERMS,
            "same genuine source can redeem original terms"
        );
    }

    function testCurrentRedemptionIdenticalSignedSafeRetriesAfterHostApprovalRepair() public {
        uint256 token = _seed(HOLDER);
        vm.prank(HOLDER);
        core.setApprovalForAll(address(operatorSafe), true);
        bytes memory signedCall = _signedSafeCall(
            operatorSafe,
            operatorKeys,
            abi.encodeCall(redemptionHost.redeem, (saleId, token, TERMS, REFERENCE, URI))
        );
        uint256 nonce = operatorSafe.nonce();
        bytes32 before_ = _sourceState(saleId, token);
        (bool ok,) = address(operatorSafe).call(signedCall);
        require(!ok && operatorSafe.nonce() == nonce, "Safe preflight failure retains nonce");
        _assertUntouched(saleId, token, HOLDER, before_);
        // The EOA source owner repairs its host grant; it does not advance the executor Safe nonce.
        _approveHost(HOLDER);
        (ok,) = address(operatorSafe).call(signedCall);
        require(
            ok && operatorSafe.nonce() == nonce + 1, "byte-identical threshold transaction succeeds"
        );
        require(
            redemptionHost.redemption(redemptionHost.redemptionIdFor(token)).redeemer
                == address(operatorSafe),
            "Safe itself is recorded executor"
        );
    }

    function testCurrentRedemptionPreburnAndDuplicateCannotCreateAnotherClaim() public {
        uint256 first = _seed(HOLDER);
        _approveHost(HOLDER);
        vm.prank(HOLDER);
        core.burn(first);
        bytes32 before_ = _sourceState(saleId, first);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionTokenInvalid.selector, first));
        vm.prank(HOLDER);
        redemptionHost.redeem(saleId, first, TERMS, REFERENCE, URI);
        require(_sourceState(saleId, first) == before_, "preburn has no attributable claim");
        uint256 second = _seed(HOLDER);
        bytes32 id = _redeem(HOLDER, saleId, second);
        bytes32 original = keccak256(abi.encode(redemptionHost.redemption(id)));
        uint64 now_ = uint64(this.redemptionTime());
        bytes32 other = _program(TERMS, now_, now_ + 90 days);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionTokenInvalid.selector, second));
        vm.prank(HOLDER);
        redemptionHost.redeem(other, second, TERMS, REFERENCE, URI);
        require(
            redemptionHost.redemptionCount(other) == 0
                && redemptionHost.redemptionCount(saleId) == 1
                && keccak256(abi.encode(redemptionHost.redemption(id))) == original,
            "global token identity cannot be replayed through another program"
        );
    }

    function testCurrentRedemptionInclusiveWindowAndExpiredSourceRemainExact() public {
        uint64 start = uint64(this.redemptionTime() + 20);
        uint64 end = start + 100;
        bytes32 program = _program(TERMS, start, end);
        uint256 first = _seed(HOLDER);
        uint256 second = _seed(HOLDER);
        uint256 third = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 before_ = _sourceState(program, first);
        vm.expectRevert(
            abi.encodeWithSelector(Redemption.RedemptionProgramClosed.selector, program)
        );
        vm.prank(HOLDER);
        redemptionHost.redeem(program, first, TERMS, REFERENCE, URI);
        _assertUntouched(program, first, HOLDER, before_);
        vm.warp(start);
        bytes32 id = _redeem(HOLDER, program, first);
        vm.warp(end);
        _redeem(HOLDER, program, second);
        vm.warp(uint256(end) + 1);
        before_ = _sourceState(program, third);
        vm.expectRevert(
            abi.encodeWithSelector(Redemption.RedemptionProgramClosed.selector, program)
        );
        vm.prank(HOLDER);
        redemptionHost.redeem(program, third, TERMS, REFERENCE, URI);
        _assertUntouched(program, third, HOLDER, before_);
        _append(id, keccak256("operator fulfillment after original program expiry"));
        require(redemptionHost.fulfillmentCount(id) == 1, "expiry does not erase fulfillment duty");
    }

    function testCurrentRedemptionCancellationStopsBurnButKeepsAppendOnlyFulfillment() public {
        uint256 first = _seed(HOLDER);
        uint256 second = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 id = _redeem(HOLDER, saleId, first);
        bytes32 original = keccak256(abi.encode(redemptionHost.redemption(id)));
        _operator(abi.encodeCall(redemptionHost.cancelProgram, (saleId)));
        bytes32 before_ = _sourceState(saleId, second);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionProgramClosed.selector, saleId));
        vm.prank(HOLDER);
        redemptionHost.redeem(saleId, second, TERMS, REFERENCE, URI);
        _assertUntouched(saleId, second, HOLDER, before_);
        _append(id, keccak256("operator reports shipment"));
        vm.warp(this.redemptionTime() + 1);
        _append(id, keccak256("operator reports delivery"));
        _assertFulfillments(id);
        require(
            keccak256(abi.encode(redemptionHost.redemption(id))) == original,
            "cancelled program original claim immutable"
        );
    }

    function testCurrentRedemptionDeprecationContinuesOnlyOriginalPrograms() public {
        uint256 token = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 originalProgram = keccak256(abi.encode(redemptionHost.program(saleId)));
        vm.warp(this.redemptionTime() + 1);
        this.setRedemptionModuleStatus(ModuleRegistryStatus.DEPRECATED);
        uint256 nonce = redemptionHost.nextSaleNonce();
        uint64 now_ = uint64(this.redemptionTime());
        bytes memory signedCall = _signedSafeCall(
            operatorSafe,
            operatorKeys,
            abi.encodeCall(
                redemptionHost.registerProgram,
                (Redemption.ProgramConfig(1, now_, now_ + 90 days, TERMS))
            )
        );
        uint256 safeNonce = operatorSafe.nonce();
        (bool ok,) = address(operatorSafe).call(signedCall);
        require(
            !ok && redemptionHost.nextSaleNonce() == nonce && operatorSafe.nonce() == safeNonce,
            "deprecated module cannot create new program"
        );
        bytes32 id = _redeem(HOLDER, saleId, token);
        _append(id, keccak256("deprecated admitted program fulfillment"));
        require(
            keccak256(abi.encode(redemptionHost.program(saleId))) == originalProgram,
            "captured admission is immutable"
        );
    }

    function testCurrentRedemptionIncidentStopsBothWritesButRetainsHistoryAndCancellation() public {
        uint256 first = _seed(HOLDER);
        uint256 second = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 id = _redeem(HOLDER, saleId, first);
        _append(id, keccak256("preincident shipment"));
        bytes32 original = keccak256(
            abi.encode(redemptionHost.redemption(id), redemptionHost.fulfillmentAt(id, 0))
        );
        this.setRedemptionModuleStatus(ModuleRegistryStatus.INCIDENT_REVOKED);
        bytes32 before_ = _sourceState(saleId, second);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionModuleNotAdmitted.selector));
        vm.prank(HOLDER);
        redemptionHost.redeem(saleId, second, TERMS, REFERENCE, URI);
        _assertUntouched(saleId, second, HOLDER, before_);
        uint256 nonce = operatorSafe.nonce();
        bytes memory signedCall = _signedSafeCall(
            operatorSafe,
            operatorKeys,
            abi.encodeCall(
                redemptionHost.recordFulfillment, (id, keccak256("must not append"), URI)
            )
        );
        (bool ok,) = address(operatorSafe).call(signedCall);
        require(
            !ok && operatorSafe.nonce() == nonce && redemptionHost.fulfillmentCount(id) == 1,
            "incident rejects operator mutation"
        );
        require(
            keccak256(
                    abi.encode(redemptionHost.redemption(id), redemptionHost.fulfillmentAt(id, 0))
                ) == original,
            "all original incident history readable"
        );
        _operator(abi.encodeCall(redemptionHost.cancelProgram, (saleId)));
        require(
            redemptionHost.program(saleId).cancelled
                && redemptionHost.redemptionAt(saleId, 0) == id,
            "cancellation remains possible without changing history"
        );
    }

    function testCurrentRedemptionActualBurnBlockRollsBackLateCoreFailure() public {
        uint256 token = _seed(address(holderSafe));
        _approveHost(address(holderSafe));
        this.blockRedemptionBurns();
        bytes memory signedCall = _signedSafeCall(
            holderSafe,
            holderKeys,
            abi.encodeCall(redemptionHost.redeem, (saleId, token, TERMS, REFERENCE, URI))
        );
        uint256 nonce = holderSafe.nonce();
        bytes32 before_ = _sourceState(saleId, token);
        // The host stores its record/index before calling actual Core; Core's permanent block
        // rejects that burn and atomically rolls back both writes. This state cannot be repaired.
        CurrentRedemptionCallVm(address(vm))
            .expectCall(address(core), 0, abi.encodeCall(core.burn, (token)), 2);
        vm.expectRevert(abi.encodeWithSelector(Redemption.RedemptionBurnFailed.selector, token));
        vm.prank(address(holderSafe));
        redemptionHost.redeem(saleId, token, TERMS, REFERENCE, URI);
        _assertUntouched(saleId, token, address(holderSafe), before_);
        (bool ok,) = address(holderSafe).call(signedCall);
        require(
            !ok && holderSafe.nonce() == nonce,
            "late failure rolls back whole threshold Safe transaction"
        );
        _assertUntouched(saleId, token, address(holderSafe), before_);
        bytes32 id = redemptionHost.redemptionIdFor(token);
        vm.expectRevert(abi.encodeWithSelector(Redemption.UnknownRedemption.selector, id));
        redemptionHost.redemption(id);
        require(
            core.collectionStatus(1) == 2 && core.collectionBurnsBlocked(1)
                && core.collectionBurnsBlockedAtBlock(1) != 0 && !core.collectionFreezeStatus(1),
            "actual irreversible block; no fabricated finality/freeze"
        );
    }

    function testCurrentRedemptionOnlyOperatorCanConfigureCancelAndReport() public {
        uint256 nonce = redemptionHost.nextSaleNonce();
        uint64 now_ = uint64(this.redemptionTime());
        Redemption.ProgramConfig memory config =
            Redemption.ProgramConfig(1, now_, now_ + 1 days, TERMS);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        redemptionHost.registerProgram(config);
        require(redemptionHost.nextSaleNonce() == nonce, "unauthorized registration has no nonce");
        uint256 token = _seed(HOLDER);
        _approveHost(HOLDER);
        bytes32 id = _redeem(HOLDER, saleId, token);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        vm.prank(HOLDER);
        redemptionHost.recordFulfillment(id, REFERENCE, URI);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        vm.prank(HOLDER);
        redemptionHost.cancelProgram(saleId);
        require(
            !redemptionHost.program(saleId).cancelled && redemptionHost.fulfillmentCount(id) == 0,
            "holder is not operator"
        );
        _append(id, keccak256("authorized report"));
    }

    function _append(bytes32 id, bytes32 referenceHash) private {
        uint256 index = redemptionHost.fulfillmentCount(id);
        vm.recordLogs();
        _operator(abi.encodeCall(redemptionHost.recordFulfillment, (id, referenceHash, URI)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Redemption.Fulfillment memory item = redemptionHost.fulfillmentAt(id, index);
        require(redemptionHost.fulfillmentCount(id) == index + 1, "one appended fulfillment");
        uint256 originalEvent;
        uint256 contextEvent;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter != address(redemptionHost)) continue;
            if (log.topics[0] == keccak256("RedemptionFulfilled(uint16,bytes32,bytes32,string)")) {
                require(log.topics.length == 2 && log.topics[1] == id, "original fulfillment key");
                (uint16 version, bytes32 actualReference, string memory actualURI) =
                    abi.decode(log.data, (uint16, bytes32, string));
                require(
                    version == 1 && actualReference == referenceHash
                        && keccak256(bytes(actualURI)) == keccak256(bytes(URI)),
                    "original fulfillment event data"
                );
                ++originalEvent;
            } else if (
                log.topics[0]
                    == keccak256(
                        "RedemptionFulfillmentContext(uint16,bytes32,uint256,(bytes32,string,bytes32,bytes32,address,uint64))"
                    )
            ) {
                require(
                    log.topics.length == 3 && log.topics[1] == id
                        && log.topics[2] == bytes32(index),
                    "original appended context position"
                );
                (uint16 version, Redemption.Fulfillment memory actual) =
                    abi.decode(log.data, (uint16, Redemption.Fulfillment));
                require(
                    version == 1 && keccak256(abi.encode(actual)) == keccak256(abi.encode(item)),
                    "complete original fulfillment event"
                );
                ++contextEvent;
            }
        }
        require(originalEvent == 1 && contextEvent == 1, "exact fulfillment event pair");
    }

    function _assertFulfillments(bytes32 id) private view {
        uint256 count = redemptionHost.fulfillmentCount(id);
        require(count == 2, "two retained operator reports");
        bytes32 previous;
        for (uint256 i; i < count; ++i) {
            Redemption.Fulfillment memory item = redemptionHost.fulfillmentAt(id, i);
            require(
                item.recorder == address(operatorSafe) && item.previousUpdateHash == previous,
                "actual operator and prior report"
            );
            require(
                item.updateHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_REDEMPTION_FULFILLMENT_V1"),
                            block.chainid,
                            address(redemptionHost),
                            id,
                            i,
                            previous,
                            item.referenceHash,
                            keccak256(bytes(item.fulfillmentURI)),
                            address(operatorSafe),
                            item.recordedAt
                        )
                    ),
                "original complete fulfillment hash"
            );
            previous = item.updateHash;
        }
    }

    function setRedemptionModuleStatus(ModuleRegistryStatus next) external {
        require(msg.sender == address(this), "fixture self-call");
        StreamModuleRecord memory record = registry.moduleRecord(address(redemptionHost));
        (bytes32 chain, uint64 count) = registry.registrationChainHash();
        bytes32 scope = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(),
                block.chainid,
                address(registry),
                address(redemptionHost)
            )
        );
        bytes32 before_ = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _recordHash(record, record.status, record.revision),
                registry.moduleCount(),
                chain,
                count
            )
        );
        bytes32 after_ = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _recordHash(record, next, record.revision + 1),
                registry.moduleCount(),
                chain,
                count
            )
        );
        bytes[] memory data = new bytes[](2);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        data[0] = abi.encodeCall(
            registry.setModuleStatus,
            (
                address(redemptionHost),
                next,
                keccak256("current redemption lifecycle"),
                "urn:current:redemption:status"
            )
        );
        calls[0] = StreamCurrentStackPlan.call(address(registry), data[0], scope, before_, after_);
        uint64 nextManifestRevision;
        (calls[1], data[1], nextManifestRevision) = _statusPublication(next, after_);
        uint8 class_ = uint8(next) > uint8(record.status) ? 0 : 1;
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(class_, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        StreamModuleRecord memory actual = registry.moduleRecord(address(redemptionHost));
        require(
            actual.status == next && actual.revision == record.revision + 1,
            "actual governed lifecycle write"
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED
                && StreamGenesisManifestPlan.readAggregate(manifest).revision
                    == nextManifestRevision,
            "status and mandatory final manifest publication completed atomically"
        );
    }

    function _statusPublication(ModuleRegistryStatus next, bytes32 commitment)
        private
        returns (GovernanceCall memory call_, bytes memory data, uint64 nextRevision)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                "{\"purpose\":\"current redemption lifecycle\",\"status\":",
                bytes1(uint8(48) + uint8(next)),
                ",\"commitment\":\"",
                Strings.toHexString(uint256(commitment), 32),
                "\"}"
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:current-stack:redemption-lifecycle",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (call_, data) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
        nextRevision = current.revision + 1;
    }

    function _recordHash(
        StreamModuleRecord memory record,
        ModuleRegistryStatus status,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                record.moduleType,
                record.moduleVersion,
                record.interfaceId,
                record.moduleGasLimit,
                record.runtimeCodeHash,
                record.deploymentManifestHash,
                record.moduleManifestHash,
                keccak256(bytes(record.moduleManifestURI)),
                revision
            )
        );
    }

    function blockRedemptionBurns() external {
        require(msg.sender == address(this), "fixture self-call");
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(1)
            )
        );
        bytes32 configDomain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes32 burnsDomain = 0x0a834b49bdbe94b7d08a85a25431e3405b397e5f84bf90a90107edb2a58013ec;
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(core.setCollectionStatus, (uint256(1), uint8(2)));
        calls[0] = StreamCurrentStackPlan.call(
            address(core),
            data[0],
            scope,
            keccak256(
                abi.encode(
                    configDomain,
                    scope,
                    true,
                    core.collectionSupplyMode(1),
                    core.collectionStatus(1),
                    core.collectionHasMaxSupply(1),
                    core.collectionMaxSupply(1)
                )
            ),
            keccak256(
                abi.encode(
                    configDomain,
                    scope,
                    true,
                    core.collectionSupplyMode(1),
                    uint8(2),
                    core.collectionHasMaxSupply(1),
                    core.collectionMaxSupply(1)
                )
            )
        );
        data[1] = abi.encodeCall(core.blockCollectionBurns, (uint256(1)));
        calls[1] = StreamCurrentStackPlan.call(
            address(core),
            data[1],
            scope,
            keccak256(abi.encode(burnsDomain, scope, false)),
            keccak256(abi.encode(burnsDomain, scope, true))
        );
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(2, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "real terminal governance action"
        );
    }

    function _assertBurnEvents(
        Vm.Log[] memory logs,
        bytes32 id,
        uint256 token,
        Redemption.Redemption memory item
    ) private view {
        uint256 recorded;
        uint256 context;
        uint256 transfer;
        uint256 burned;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(redemptionHost)) {
                if (
                    log.topics[0]
                        == keccak256(
                            "RedemptionRecorded(uint16,bytes32,uint256,uint256,address,bytes32,string)"
                        )
                ) {
                    require(
                        log.topics.length == 4 && log.topics[1] == id
                            && log.topics[2] == bytes32(token)
                            && log.topics[3] == bytes32(uint256(1)),
                        "original indexed redemption event"
                    );
                    (uint16 version, address actor, bytes32 referenceHash, string memory uri) =
                        abi.decode(log.data, (uint16, address, bytes32, string));
                    require(
                        version == 1 && actor == item.redeemer && referenceHash == REFERENCE
                            && keccak256(bytes(uri)) == keccak256(bytes(URI)),
                        "original redemption event fields"
                    );
                    ++recorded;
                } else if (
                    log.topics[0]
                        == keccak256(
                            "RedemptionContextRecorded(uint16,bytes32,bytes32,(bytes32,uint256,uint256,uint256,address,address,bytes32,bytes32,string,uint64))"
                        )
                ) {
                    require(
                        log.topics.length == 3 && log.topics[1] == id && log.topics[2] == saleId,
                        "context original keys"
                    );
                    (uint16 version, Redemption.Redemption memory actual) =
                        abi.decode(log.data, (uint16, Redemption.Redemption));
                    require(
                        version == 1
                            && keccak256(abi.encode(actual)) == keccak256(abi.encode(item)),
                        "context original tuple"
                    );
                    ++context;
                }
            } else if (log.emitter == address(core)) {
                if (log.topics[0] == keccak256("Transfer(address,address,uint256)")) {
                    require(
                        log.topics.length == 4
                            && log.topics[1] == bytes32(uint256(uint160(item.tokenOwner)))
                            && log.topics[2] == 0 && log.topics[3] == bytes32(token),
                        "actual ERC721 burn"
                    );
                    ++transfer;
                } else if (
                    log.topics[0] == keccak256("StreamTokenBurned(uint256,uint256,uint256,uint16)")
                ) {
                    (uint256 serial, uint16 version) = abi.decode(log.data, (uint256, uint16));
                    require(
                        log.topics.length == 3 && log.topics[1] == bytes32(token)
                            && log.topics[2] == bytes32(uint256(1))
                            && serial == item.collectionSerial && version == 1,
                        "actual retained identity burn event"
                    );
                    ++burned;
                }
            }
        }
        require(
            recorded == 1 && context == 1 && transfer == 1 && burned == 1,
            "one canonical burn/redemption event set"
        );
    }
}
