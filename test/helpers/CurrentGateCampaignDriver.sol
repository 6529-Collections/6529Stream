// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentStandardGateFixture.sol";
import {
    CurrentGateCampaignHandler,
    ICurrentGateCampaignDriver,
    GateCampaign
} from "./CurrentGateCampaignHandler.sol";

/// @notice Only test orchestration: every protocol mutation still uses the original Safe envelope.
abstract contract CurrentGateCampaignDriver is
    CurrentStandardGateFixture,
    ICurrentGateCampaignDriver
{
    CurrentGateCampaignHandler internal campaignHandler;

    modifier onlyCampaign() {
        require(msg.sender == address(campaignHandler), "fixed campaign driver caller");
        _;
    }

    function _constructGateCampaign() internal {
        _constructStandardGates();
        // All callback rejections are explicit actions relative to the independent callback count.
        faultyRecipient.setRejectAt(0);
        campaignHandler = new CurrentGateCampaignHandler(ICurrentGateCampaignDriver(address(this)));
    }

    /// @dev Six fixture allowances of three; this changes the test collection configuration only.
    function _fixtureSupplyLimit() internal pure override returns (uint64) {
        return 18;
    }

    function campaignConfiguration()
        external
        view
        override
        returns (GateCampaign.Configuration memory c)
    {
        c.core = core;
        c.manager = manager;
        c.ledger = ledger;
        c.mintSafe = gateCaller;
        c.vaultSafe = gateVault;
        c.beneficiaries[0] = address(gateVault);
        c.beneficiaries[1] = address(faultyRecipient);
        for (uint8 i; i < 3; ++i) {
            c.phases[i] = _gatePhase(i);
        }
        c.payer = BUYER;
    }

    function campaignBuild(GateCampaign.Request calldata r)
        external
        override
        onlyCampaign
        returns (GateCampaign.Packet memory p)
    {
        require(
            r.kind < 3 && r.subject < 2 && r.quantity > 0 && r.quantity <= 3,
            "bounded campaign request"
        );
        address recipient = r.subject == 0 ? address(gateVault) : address(faultyRecipient);
        p.request = r;
        p.batch = _gateBatch(r.kind, r.sequence, recipient, recipient, r.quantity);
        (p.proof, p.nullifier) = _authorizeGate(r.kind, p.batch, r.gateNonce);
        p.envelope = _gateEnvelope(gateCaller, _mintGateCall(p.batch, p.proof, r.prepared));
    }

    function campaignSubmit(GateCampaign.Packet calldata p, bool exactEnvelope)
        external
        override
        onlyCampaign
        returns (GateCampaign.Outcome memory outcome)
    {
        OfficialSafe principal = gateCaller;
        bytes memory envelope = exactEnvelope
            ? p.envelope
            : _gateEnvelope(principal, _mintGateCall(p.batch, p.proof, p.request.prepared));
        vm.recordLogs();
        (bool ok, bytes memory returned) = address(principal).call(envelope);
        outcome.success = ok && abi.decode(returned, (bool));
        if (!outcome.success) {
            require(
                !ok
                    && keccak256(returned)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "original Safe target failure"
            );
        }
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 receipts;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 4) continue;
            if (
                logs[i].emitter == address(ledger)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == p.batch.authorizationId
                        && address(uint160(uint256(logs[i].topics[3]))) == address(manager),
                    "original Manager authorization identity"
                );
                outcome.root = logs[i].topics[2];
                ++receipts;
            }
            if (
                logs[i].emitter == address(manager)
                    && logs[i].topics[0]
                        == keccak256(
                            "PreparedMintCompleted(uint16,bytes32,uint256,uint256,bytes32,address)"
                        )
            ) {
                (uint16 version, bytes32 root,) =
                    abi.decode(logs[i].data, (uint16, bytes32, address));
                require(
                    version == 1 && root == outcome.root && uint256(logs[i].topics[3]) == 1,
                    "original prepared completion trace"
                );
                uint256 id = uint256(logs[i].topics[2]);
                if (outcome.completed == 0) outcome.firstCompletedId = id;
                require(
                    id == outcome.firstCompletedId + outcome.completed,
                    "ordered original completion identities"
                );
                ++outcome.completed;
            }
        }
        require(
            receipts <= 1 && (!outcome.success || receipts == 1),
            "bounded original authorization receipt"
        );
    }

    function campaignGrant(uint8 subject, bool enabled) external override onlyCampaign {
        require(subject < 2, "bounded grant subject");
        bytes32 rights = delegateGate.collectionDelegationRights(1);
        if (subject == 0) {
            _vaultGrant(BUYER, rights, enabled);
        } else {
            require(enabled, "fault fixture grant only");
            faultyRecipient.grant(delegationService, BUYER, address(core), rights);
        }
    }

    function campaignReceiverRejectAt(uint256 ordinal) external override onlyCampaign {
        faultyRecipient.setRejectAt(ordinal);
    }

    function campaignReceiverCallbacks() external view override returns (uint256) {
        return faultyRecipient.callbacks();
    }

    function campaignDelegated(uint8 subject) external view override returns (bool) {
        require(subject < 2, "bounded delegated subject");
        return delegateGate.isDelegated(
            subject == 0 ? address(gateVault) : address(faultyRecipient), BUYER, 1
        );
    }
}
