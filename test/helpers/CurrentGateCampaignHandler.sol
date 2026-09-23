// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "./OfficialSafeFixture.sol";

library GateCampaign {
    struct Configuration {
        StreamCore core;
        StreamMintManager manager;
        StreamMintLedger ledger;
        OfficialSafe mintSafe;
        OfficialSafe vaultSafe;
        address[2] beneficiaries;
        bytes32[3] phases;
        address payer;
    }

    struct Request {
        uint8 kind;
        uint8 subject;
        uint8 quantity;
        bool prepared;
        uint256 sequence;
        bytes32 gateNonce;
    }

    struct Packet {
        Request request;
        IStreamMintManager.MintBatch batch;
        bytes proof;
        bytes envelope;
        bytes32 nullifier;
    }

    struct Outcome {
        bool success;
        bytes32 root;
        uint256 completed;
        uint256 firstCompletedId;
    }
}

interface ICurrentGateCampaignDriver {
    function campaignConfiguration() external view returns (GateCampaign.Configuration memory);
    function campaignBuild(GateCampaign.Request calldata request)
        external
        returns (GateCampaign.Packet memory);
    function campaignSubmit(GateCampaign.Packet calldata packet, bool exactEnvelope)
        external
        returns (GateCampaign.Outcome memory);
    function campaignGrant(uint8 subject, bool enabled) external;
    function campaignReceiverRejectAt(uint256 ordinal) external;
    function campaignReceiverCallbacks() external view returns (uint256);
    function campaignDelegated(uint8 subject) external view returns (bool);
}

/// @notice Stateful request-accounting oracle: six independent beneficiary buckets, cap three each.
/// @dev Expected outcomes come from this model, not Manager previews or returned counter values.
contract CurrentGateCampaignHandler {
    uint256 public constant OPENING_STEPS = 14;
    uint256 public constant MAX_STEPS = 128;
    bytes32 private constant COUNTER = keccak256("current gate beneficiary allocation");
    ICurrentGateCampaignDriver private immutable driver;
    GateCampaign.Configuration private c;
    uint256[2][3] private allowances;
    bool[2] private delegated;
    bytes[3] private lastSuccess;
    bytes32[] private authorizations;
    bytes32[] private nullifiers;
    bytes32[] private roots;
    mapping(bytes32 => bool) private knownAuth;
    mapping(bytes32 => bool) private knownNullifier;
    mapping(bytes32 => bool) private knownRoot;
    mapping(bytes32 => bool) private usedAuth;
    mapping(bytes32 => bool) private usedNullifier;
    mapping(bytes32 => bool) private usedRoot;
    address[] private owners;
    bytes32[] private contentHashes;
    uint256 private sequence;
    uint256 private receiverCallbacks;
    uint256 private vaultTransactions;
    uint256 public steps;
    uint256 public attempts;
    uint256 public successes;
    uint256 public failures;
    uint256 public authorizationReplays;
    uint256 public nullifierReplays;
    uint256 public invalidProofs;
    uint256 public invalidWallets;
    uint256 public invalidPhases;
    uint256 public capDenials;
    uint256 public revocationRetries;
    uint256[2] public callbackRetries;
    uint256[3] public gateSuccesses;
    bytes32 public campaignDigest;

    constructor(ICurrentGateCampaignDriver driver_) {
        driver = driver_;
        c = driver_.campaignConfiguration();
        require(
            c.core.totalSupply() == 0 && c.mintSafe.nonce() == 0 && c.vaultSafe.nonce() == 0,
            "fresh campaign principals"
        );
    }

    function step(uint256 seed) external {
        require(steps < MAX_STEPS, "bounded campaign depth");
        assertInvariants();
        bool opening = steps < OPENING_STEPS;
        uint256 action = opening ? steps : seed % OPENING_STEPS;
        ++steps;
        uint8 kind = opening ? 0 : uint8((seed >> 8) % 3);
        uint8 subject = opening ? 0 : uint8((seed >> 16) % 2);
        uint8 quantity = opening ? 1 : uint8(1 + (seed >> 24) % 3);
        if (action == 0) _mint(kind, subject, quantity, (seed & 1) != 0);
        else if (action == 1) _replay(opening ? 0 : kind, false);
        else if (action == 2) _replay(opening ? 0 : kind % 2, true);
        else if (action == 3) _invalid(2, subject, 0);
        else if (action == 4) _grant(0, true);
        else if (action == 5) _mint(1, subject, quantity, false);
        else if (action == 6) _revokeAndRetry();
        else if (action == 7) _invalid(kind, subject, 1);
        else if (action == 8) _callbackRetry(0);
        else if (action == 9) _callbackRetry(1);
        else if (action == 10) _capBoundary(opening ? 0 : kind, subject);
        else if (action == 11) _mint(2, subject, quantity, false);
        else if (action == 12) _invalid(kind, subject, 2);
        else _grant(0, false);
        campaignDigest = keccak256(
            abi.encode(
                campaignDigest,
                action,
                seed,
                attempts,
                successes,
                failures,
                owners.length,
                allowances
            )
        );
        assertInvariants();
    }

    function _packet(uint8 kind, uint8 subject, uint8 quantity, bool prepared, bytes32 nonce)
        private
        returns (GateCampaign.Packet memory)
    {
        ++sequence;
        if (nonce == 0) nonce = bytes32(sequence);
        return driver.campaignBuild(
            GateCampaign.Request(kind, subject, quantity, prepared, sequence, nonce)
        );
    }

    function _eligible(GateCampaign.Packet memory p) private view returns (bool) {
        GateCampaign.Request memory r = p.request;
        return allowances[r.kind][r.subject] + r.quantity <= 3
            && (r.kind != 1 || delegated[r.subject]) && !usedAuth[p.batch.authorizationId]
            && (p.nullifier == 0 || !usedNullifier[p.nullifier]);
    }

    function _mint(uint8 kind, uint8 subject, uint8 quantity, bool prepared) private {
        GateCampaign.Packet memory p = _packet(kind, subject, quantity, prepared, 0);
        _attempt(p, _eligible(p), false);
    }

    function _grant(uint8 subject, bool enabled) private {
        require(subject == 0 || enabled, "fault vault only grants in this campaign");
        driver.campaignGrant(subject, enabled);
        delegated[subject] = enabled;
        if (subject == 0) ++vaultTransactions;
        require(
            driver.campaignDelegated(subject) == enabled,
            "actual live delegation matches intended grant"
        );
    }

    function _replay(uint8 kind, bool nonceReplay) private {
        require(lastSuccess[kind].length != 0, "opening establishes each replay source");
        GateCampaign.Packet memory p = abi.decode(lastSuccess[kind], (GateCampaign.Packet));
        if (nonceReplay) {
            bytes32 oldAuthorization = p.batch.authorizationId;
            bytes32 oldNullifier = p.nullifier;
            p = _packet(kind, p.request.subject, 1, p.request.prepared, p.request.gateNonce);
            require(
                p.batch.authorizationId != oldAuthorization && p.nullifier == oldNullifier
                    && usedNullifier[oldNullifier],
                "different request retains consumed gate nonce"
            );
            ++nullifierReplays;
        } else {
            require(usedAuth[p.batch.authorizationId], "original authorization already committed");
            ++authorizationReplays;
        }
        // Fresh outer Safe envelope reaches the protocol again instead of replaying a stale Safe nonce.
        _attempt(p, false, false);
    }

    function _invalid(uint8 kind, uint8 subject, uint8 fault) private {
        GateCampaign.Packet memory p = _packet(kind, subject, 1, false, 0);
        if (fault == 0) {
            IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
                abi.decode(p.batch.resolverData, (IStreamMintCounterPolicy.AllowlistProof[][]));
            proofs[0][0].proof[0] = bytes32(uint256(proofs[0][0].proof[0]) ^ 1);
            p.batch.resolverData = abi.encode(proofs);
            ++invalidProofs;
        } else if (fault == 1) {
            p.batch.beneficiaries[0] = c.payer;
            ++invalidWallets;
        } else {
            p.batch.phaseId = keccak256("unconfigured stateful gate phase");
            ++invalidPhases;
        }
        _attempt(p, false, false);
    }

    function _revokeAndRetry() private {
        _grant(0, false);
        GateCampaign.Packet memory p = _packet(1, 0, 1, false, 0);
        _attempt(p, false, true);
        _grant(0, true);
        bool canMint = _eligible(p);
        _attempt(p, canMint, true);
        if (canMint) ++revocationRetries;
    }

    function _callbackRetry(uint8 kind) private {
        if (kind == 1 && !delegated[1]) _grant(1, true);
        GateCampaign.Packet memory p = _packet(kind, 1, 2, true, 0);
        if (!_eligible(p)) {
            _attempt(p, false, false);
            ++capDenials;
            return;
        }
        uint256 firstId = owners.length + 1;
        driver.campaignReceiverRejectAt(receiverCallbacks + 2);
        GateCampaign.Outcome memory failed = _attempt(p, false, true);
        require(
            failed.root != 0 && failed.completed == 1 && failed.firstCompletedId == firstId,
            "late callback follows a completed original prepared token"
        );
        driver.campaignReceiverRejectAt(0);
        GateCampaign.Outcome memory retry = _attempt(p, true, true);
        require(
            retry.root == failed.root && retry.completed == 2 && retry.firstCompletedId == firstId,
            "identical Safe envelope retries same root and allocations"
        );
        ++callbackRetries[kind];
    }

    function _capBoundary(uint8 kind, uint8 subject) private {
        if (kind == 1 && !delegated[subject]) _grant(subject, true);
        uint8 remaining = uint8(3 - allowances[kind][subject]);
        if (remaining != 0) _mint(kind, subject, remaining, false);
        GateCampaign.Packet memory p = _packet(kind, subject, 1, false, 0);
        require(allowances[kind][subject] == 3, "model reaches exact cap");
        _attempt(p, false, false);
        ++capDenials;
    }

    function _attempt(GateCampaign.Packet memory p, bool expected, bool exact)
        private
        returns (GateCampaign.Outcome memory out)
    {
        bytes32 auth = p.batch.authorizationId;
        _observe(auth, p.nullifier);
        out = driver.campaignSubmit(p, exact);
        ++attempts;
        require(out.success == expected, "independent campaign outcome");
        if (out.root != 0 && !knownRoot[out.root]) {
            roots.push(out.root);
            knownRoot[out.root] = true;
        }
        if (!expected) {
            ++failures;
            // Reverted trace roots are retained as identifiers only; they are not committed receipts.
            assertInvariants();
            return out;
        }
        require(
            out.root != 0 && !usedRoot[out.root] && !usedAuth[auth]
                && (p.nullifier == 0 || !usedNullifier[p.nullifier]),
            "new successful receipt identities"
        );
        usedRoot[out.root] = true;
        usedAuth[auth] = true;
        if (p.nullifier != 0) usedNullifier[p.nullifier] = true;
        ++successes;
        ++gateSuccesses[p.request.kind];
        allowances[p.request.kind][p.request.subject] += p.request.quantity;
        for (uint256 i; i < p.request.quantity; ++i) {
            require(
                p.batch.initialRecipients[i] == c.beneficiaries[p.request.subject]
                    && p.batch.beneficiaries[i] == c.beneficiaries[p.request.subject],
                "intended beneficiary and delivery"
            );
            owners.push(c.beneficiaries[p.request.subject]);
            contentHashes.push(keccak256(p.batch.tokenData[i]));
        }
        if (p.request.subject == 1) receiverCallbacks += p.request.quantity;
        lastSuccess[p.request.kind] = abi.encode(p);
        assertInvariants();
    }

    function _observe(bytes32 auth, bytes32 nullifier) private {
        if (!knownAuth[auth]) {
            authorizations.push(auth);
            knownAuth[auth] = true;
        }
        if (nullifier != 0 && !knownNullifier[nullifier]) {
            nullifiers.push(nullifier);
            knownNullifier[nullifier] = true;
        }
    }

    function assertInvariants() public view {
        uint256 minted = owners.length;
        require(attempts == successes + failures, "every attempt is classified");
        require(
            c.core.totalSupply() == minted && c.core.collectionMintedEver(1) == minted
                && c.core.lastAllocatedTokenId() == minted
                && c.core.collectionNextSerial(1) == minted + 1
                && c.manager.nextOperationNonce() == minted
                && c.core.pendingPreparedMintTokenId() == 0,
            "independent supply serial and nonce ledger"
        );
        require(
            c.mintSafe.nonce() == successes && c.vaultSafe.nonce() == vaultTransactions
                && driver.campaignReceiverCallbacks() == receiverCallbacks,
            "successful calls alone advance principals and callbacks"
        );
        uint256 counted;
        for (uint8 kind; kind < 3; ++kind) {
            for (uint8 subject; subject < 2; ++subject) {
                require(
                    allowances[kind][subject] <= 3
                        && c.ledger.counterValue(_counterKey(kind, c.beneficiaries[subject]))
                            == allowances[kind][subject],
                    "independent beneficiary allowance"
                );
                counted += allowances[kind][subject];
            }
            require(
                c.ledger.counterValue(_counterKey(kind, c.payer)) == 0
                    && c.ledger.counterValue(_counterKey(kind, address(c.mintSafe))) == 0,
                "payer and caller never inherit beneficiary allowance"
            );
        }
        require(counted == minted && minted <= 18, "six bounded buckets conserve supply");
        for (uint256 i; i < minted; ++i) {
            (bool exists, uint256 collection, uint256 serial, bool burned) =
                c.core.tokenCollectionIdentity(i + 1);
            require(
                exists && !burned && collection == 1 && serial == i + 1
                    && c.core.ownerOf(i + 1) == owners[i]
                    && keccak256(c.core.tokenData(i + 1)) == contentHashes[i]
                    && !c.core.preparedMint(i + 1).exists,
                "independent token ownership content and serial"
            );
        }
        for (uint256 i = minted + 1; i <= minted + 3; ++i) {
            (bool exists,,,) = c.core.tokenCollectionIdentity(i);
            require(
                !exists && !c.core.preparedMint(i).exists && c.core.tokenData(i).length == 0
                    && c.core.coordinatorAtMint(i) == address(0),
                "no reverted allocation or entropy anchor"
            );
        }
        for (uint256 i; i < authorizations.length; ++i) {
            bytes32 id = authorizations[i];
            require(
                c.manager.isAuthorizationUsed(id) == usedAuth[id]
                    && c.ledger.isManagerAuthorizationUsed(address(c.manager), id) == usedAuth[id],
                "independent authorization history"
            );
        }
        for (uint256 i; i < nullifiers.length; ++i) {
            bytes32 id = nullifiers[i];
            require(
                c.manager.isNullifierUsed(id) == usedNullifier[id]
                    && c.ledger.isManagerNullifierUsed(address(c.manager), id) == usedNullifier[id],
                "independent gate nonce history"
            );
        }
        for (uint256 i; i < roots.length; ++i) {
            bytes32 id = roots[i];
            require(
                c.manager.isOperationRootUsed(id) == usedRoot[id]
                    && c.ledger.isManagerOperationRootUsed(address(c.manager), id) == usedRoot[id],
                "independent operation root history"
            );
        }
        require(
            driver.campaignDelegated(0) == delegated[0]
                && driver.campaignDelegated(1) == delegated[1],
            "independent grant state"
        );
    }

    function _counterKey(uint8 kind, address subject) private view returns (bytes32) {
        bytes32 identity = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(c.ledger),
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                subject
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(c.manager),
                uint256(1),
                c.phases[kind],
                COUNTER,
                identity
            )
        );
    }

    function assertCampaignActivity() external view {
        require(
            steps >= OPENING_STEPS && gateSuccesses[0] != 0 && gateSuccesses[1] != 0
                && gateSuccesses[2] != 0 && successes != 0 && failures != 0
                && authorizationReplays != 0 && nullifierReplays != 0 && invalidProofs != 0
                && invalidWallets != 0 && invalidPhases != 0 && capDenials != 0
                && revocationRetries != 0 && callbackRetries[0] != 0 && callbackRetries[1] != 0,
            "campaign lacks required opening activity"
        );
    }

    /// @dev Meta-regressions deliberately perturb only the ghost model; the enclosing revert restores it.
    function probeWrongBeneficiaryOracle() external {
        require(msg.sender == address(driver) && allowances[0][0] != 0, "oracle probe controller");
        --allowances[0][0];
        ++allowances[0][1];
        assertInvariants();
    }

    function probeMissingAuthorizationOracle() external {
        require(
            msg.sender == address(driver) && authorizations.length != 0, "oracle probe controller"
        );
        usedAuth[authorizations[0]] = false;
        assertInvariants();
    }

    function probeWrongOwnerOracle() external {
        require(msg.sender == address(driver) && owners.length != 0, "oracle probe controller");
        owners[0] = address(c.mintSafe);
        assertInvariants();
    }
}
