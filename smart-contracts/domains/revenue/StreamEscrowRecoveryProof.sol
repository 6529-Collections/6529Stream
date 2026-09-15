// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEscrowRecoveryState as S } from "./StreamEscrowRecoveryState.sol";
import { StreamRevenueRuntimeBinding as B } from "./StreamRevenueRuntimeBinding.sol";
import {
    IStreamRevenueEscrow as E
} from "../../interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import {
    IStreamRevenueEscrowRecoveryManifest as M
} from "../../interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";
import { IStreamSplitFactory as F } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import { IStreamSplitWallet as W } from "../../interfaces/stream/revenue/IStreamSplitWallet.sol";
import {
    IStreamRevenueRuntimeRegistry as L
} from "../../interfaces/stream/revenue/IStreamRevenueRuntimeRegistry.sol";
import {
    IStreamGasParameterHost as G
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Exact immutable terms, captured credit and current incident/successor proof.
/// @dev Canonical original profile preimages remain checkable if the old factory is unavailable.
library StreamEscrowRecoveryProof {
    bytes32 private constant POLICY_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");

    function validate(S.Context memory c, M.ManifestDocument memory d)
        public
        view
        returns (bytes32 oldHash, bytes32 newHash, address[] memory affected)
    {
        return _validate(c, d, d.expectedAmount);
    }

    function validateAfter(S.Context memory c, M.ManifestDocument memory d) public view {
        _validate(c, d, 0);
    }

    function _validate(S.Context memory c, M.ManifestDocument memory d, uint256 expectedOwed)
        private
        view
        returns (bytes32 oldHash, bytes32 newHash, address[] memory affected)
    {
        if (c.authority.codehash != S.state().origin.authorityCodeHash) {
            revert S.InvalidEscrowRecoveryAction();
        }
        if (
            d.creditKey.revenueClass == 0 || d.creditKey.profileId == 0 || d.expectedAmount == 0
                || d.successorWallet == address(0) || d.successorWallet == d.creditKey.wallet
                || d.successorProfileId == 0 || d.successorRuntimeCodeHash == 0
                || d.incidentEvidenceHash == 0 || d.route > 2
        ) revert S.InvalidEscrowRecoveryManifest();
        uint256 cap = budget();
        if (
            word(
                    address(this),
                    abi.encodeCall(
                        E.escrowOwed,
                        (
                            d.creditKey.revenueClass,
                            d.creditKey.profileId,
                            d.creditKey.wallet,
                            d.creditKey.asset
                        )
                    ),
                    cap
                ) != expectedOwed
        ) revert S.InvalidEscrowRecoveryManifest();
        bytes memory identity = read(
            address(this),
            abi.encodeCall(
                E.escrowCreditIdentity,
                (
                    d.creditKey.revenueClass,
                    d.creditKey.profileId,
                    d.creditKey.wallet,
                    d.creditKey.asset
                )
            ),
            96,
            cap
        );
        (address factory, bytes32 factoryHash, bytes32 runtime) =
            abi.decode(identity, (address, bytes32, bytes32));
        if (factory != c.factory || factoryHash != c.factoryCodeHash || runtime != c.walletCodeHash)
        {
            revert S.InvalidEscrowRecoveryManifest();
        }
        oldHash = canonicalEntriesHash(d.oldEntries);
        newHash = canonicalEntriesHash(d.successorEntries);
        _original(c, d, oldHash, cap);
        _incident(c, d, cap);
        _successor(c, d, newHash, cap);
        affected = affectedAccounts(d.oldEntries, d.successorEntries);
        if ((d.route == 0) != (oldHash == newHash)) revert S.InvalidEscrowRecoveryManifest();
    }

    function canonicalEntriesHash(W.SplitEntry[] memory entries) public pure returns (bytes32) {
        if (entries.length == 0 || entries.length > 64) revert S.InvalidEscrowRecoveryManifest();
        uint256 total;
        for (uint256 i; i < entries.length; ++i) {
            W.SplitEntry memory e = entries[i];
            if (e.account == address(0) || e.sharePpm == 0 || e.sharePpm > 1_000_000) {
                revert S.InvalidEscrowRecoveryManifest();
            }
            if (i != 0) {
                W.SplitEntry memory p = entries[i - 1];
                if (
                    uint160(p.account) > uint160(e.account)
                        || (p.account == e.account && uint256(p.labelId) >= uint256(e.labelId))
                ) {
                    revert S.InvalidEscrowRecoveryManifest();
                }
            }
            total += e.sharePpm;
        }
        if (total != 1_000_000) revert S.InvalidEscrowRecoveryManifest();
        return keccak256(abi.encode(entries));
    }

    function affectedAccounts(W.SplitEntry[] memory oldEntries, W.SplitEntry[] memory nextEntries)
        public
        pure
        returns (address[] memory accounts)
    {
        accounts = new address[](oldEntries.length);
        uint256 count;
        uint256 i;
        while (i < oldEntries.length) {
            address account = oldEntries[i].account;
            uint256 oldShare;
            while (i < oldEntries.length && oldEntries[i].account == account) {
                oldShare += oldEntries[i++].sharePpm;
            }
            uint256 nextShare;
            for (uint256 j; j < nextEntries.length; ++j) {
                if (nextEntries[j].account == account) nextShare += nextEntries[j].sharePpm;
            }
            if (nextShare < oldShare) accounts[count++] = account;
        }
        assembly ("memory-safe") { mstore(accounts, count) }
    }

    function _original(
        S.Context memory c,
        M.ManifestDocument memory d,
        bytes32 entriesHash,
        uint256 cap
    ) private view {
        if (
            c.originalProfileDomain == 0 || c.originalInitCodeHash == 0
                || c.originalSchemaVersion == 0 || c.originalWalletVersion == 0
                || d.creditKey.profileId
                    != keccak256(
                        abi.encode(
                            c.originalProfileDomain,
                            uint256(block.chainid),
                            c.factory,
                            c.originalSchemaVersion,
                            c.originalWalletVersion,
                            c.originalInitCodeHash,
                            c.walletCodeHash,
                            c.assetRegistry,
                            entriesHash,
                            d.oldMetadataURIHash
                        )
                    )
        ) revert S.InvalidEscrowRecoveryManifest();
        // Captured factory code authenticated the original profile at credit creation. When
        // still available, require its stored hash too; a code-loss incident cannot rewrite
        // the immutable original profile-ID preimage supplied above.
        if (c.factory.codehash == c.factoryCodeHash) {
            if (
                bytes32(
                        word(
                            c.factory,
                            abi.encodeCall(F.profileEntriesHash, (d.creditKey.profileId)),
                            cap
                        )
                    ) != entriesHash
            ) {
                revert S.InvalidEscrowRecoveryManifest();
            }
        }
    }

    function _incident(S.Context memory c, M.ManifestDocument memory d, uint256 cap) private view {
        if (c.runtimeRegistry.codehash != c.runtimeRegistryCodeHash) {
            revert S.InvalidEscrowRecoveryManifest();
        }
        L.FactoryRecord memory f = abi.decode(
            read(c.runtimeRegistry, abi.encodeCall(L.factoryRecord, (c.factory)), 192, cap),
            (L.FactoryRecord)
        );
        L.RuntimeRecord memory r = abi.decode(
            read(c.runtimeRegistry, abi.encodeCall(L.runtimeRecord, (c.walletCodeHash)), 128, cap),
            (L.RuntimeRecord)
        );
        if (
            f.codeHash != c.factoryCodeHash || f.runtimeCodeHash != c.walletCodeHash
                || f.revision == 0 || r.revision == 0
        ) revert S.InvalidEscrowRecoveryManifest();
        bool poisoned =
            d.creditKey.wallet.code.length != 0 && d.creditKey.wallet.codehash != c.walletCodeHash;
        if (!poisoned && f.status != 3 && r.status != 3) revert S.EscrowRecoveryIncidentRequired();
        if (poisoned && d.successorProfileId == d.creditKey.profileId) {
            revert S.InvalidEscrowRecoveryManifest();
        }
        if (r.status == 3 && d.incidentEvidenceHash != r.incidentManifestHash) {
            revert S.InvalidEscrowRecoveryManifest();
        }
        if (r.status != 3 && f.status == 3 && d.incidentEvidenceHash != f.incidentManifestHash) {
            revert S.InvalidEscrowRecoveryManifest();
        }
    }

    function _successor(
        S.Context memory c,
        M.ManifestDocument memory d,
        bytes32 entriesHash,
        uint256 cap
    ) private view {
        B.requireState(d.successorFactory, c.runtimeRegistry, c.runtimeRegistryCodeHash, true);
        (address registry, bytes32 codeHash) = B.factoryBinding(d.successorFactory);
        if (registry != c.runtimeRegistry || codeHash != c.runtimeRegistryCodeHash) {
            revert S.InvalidEscrowRecoveryManifest();
        }
        if (
            word(d.successorFactory, abi.encodeCall(F.profileExists, (d.successorProfileId)), cap)
                    != 1
                || word(
                        d.successorFactory, abi.encodeCall(F.walletFor, (d.successorProfileId)), cap
                    ) != uint256(uint160(d.successorWallet))
                || bytes32(
                        word(
                            d.successorFactory,
                            abi.encodeCall(F.profileEntriesHash, (d.successorProfileId)),
                            cap
                        )
                    ) != entriesHash
                || bytes32(
                        word(
                            d.successorFactory,
                            abi.encodeCall(F.splitWalletRuntimeCodeHash, ()),
                            cap
                        )
                    ) != d.successorRuntimeCodeHash
        ) revert S.InvalidEscrowRecoveryManifest();
        if (d.successorWallet.code.length != 0) {
            if (
                d.successorWallet.codehash != d.successorRuntimeCodeHash
                    || word(
                            d.successorFactory,
                            abi.encodeCall(F.splitWalletExists, (d.successorProfileId)),
                            cap
                        ) != 1
                    || word(d.successorWallet, abi.encodeCall(W.factory, ()), cap)
                        != uint256(uint160(d.successorFactory))
                    || bytes32(word(d.successorWallet, abi.encodeCall(W.profileId, ()), cap))
                        != d.successorProfileId
            ) revert S.InvalidEscrowRecoveryManifest();
        }
    }

    function budget() public view returns (uint256) {
        return G(address(this)).gasParameter(POLICY_GAS);
    }

    function word(address target, bytes memory data, uint256 cap) public view returns (uint256) {
        return abi.decode(read(target, data, 32, cap), (uint256));
    }

    function read(address target, bytes memory data, uint256 length, uint256 cap)
        public
        view
        returns (bytes memory output)
    {
        uint256 available = gasleft();
        if (cap == 0 || cap > available || available - cap < cap / 63 + 1 + 30_000) {
            revert S.EscrowRecoveryReadFailed(target, bytes4(data));
        }
        output = new bytes(length);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(output, 32), length)
            ok := and(ok, eq(returndatasize(), length))
        }
        if (!ok) revert S.EscrowRecoveryReadFailed(target, bytes4(data));
    }
}
