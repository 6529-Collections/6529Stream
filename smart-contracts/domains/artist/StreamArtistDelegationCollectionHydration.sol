// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDelegationHydrationCodec.sol";
import "./StreamArtistSaleHashes.sol";
import "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";

library StreamArtistDelegationCollectionHydration {
    function bindingState(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        AH.Query memory q
    ) public view returns (bytes memory) {
        AH.Binding memory b = AH.Binding(bindings[q.collectionId], terms[q.collectionId][1]);
        _binding(b, q);
        if (terminals[q.collectionId][1].kind != 0) revert T.UnsupportedProfile();
        return abi.encode(DH.BINDING, b);
    }

    function importBinding(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        AH.Query memory q,
        bytes memory raw
    ) public {
        AH.Binding memory b = StreamArtistDelegationHydrationCodec.binding(raw);
        _binding(b, q);
        if (bindings[q.collectionId].generation != 0) revert T.InvalidRecord();
        bindings[q.collectionId] = b.item;
        history[q.collectionId][1] = b.item;
        terms[q.collectionId][1] = b.terms;
    }

    function _binding(AH.Binding memory b, AH.Query memory q) private pure {
        if (
            b.item.artistId != q.artistId || b.item.bindingHash != q.bindingHash
                || b.item.generation != 1 || !b.item.accepted
                || (b.item.consentMode != 1 && b.item.consentMode != 2) || b.terms.count != 0
                || b.terms.mode != 0 || b.terms.threshold != 0
        ) revert T.UnsupportedProfile();
    }

    function consentState(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage records,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q
    ) public view returns (bytes memory) {
        DH.Consent memory b;
        b.policies = new DH.Policy[](q.policies.length);
        for (uint256 i; i < q.policies.length; ++i) {
            bytes32 record = policies[
                keccak256(
                    abi.encode(q.collectionId, q.policies[i].phaseId, q.policies[i].policyHash)
                )
            ];
            if (record == 0) revert T.InvalidRecord();
            b.policies[i] = DH.Policy(record, delegations[record]);
        }
        uint256 count = IStreamArtistNativeReceipts(address(this)).artistNativeReceiptCount();
        if (count > 128) revert T.UnsupportedProfile();
        uint256 n;
        for (uint256 i; i < count; ++i) {
            if (IStreamArtistNativeReceipts(address(this)).artistNativeReceiptAt(i).operation == 16)
            ++n;
        }
        b.sales = new DH.Sale[](n);
        n = 0;
        for (uint256 i; i < count; ++i) {
            H.Receipt memory r = IStreamArtistNativeReceipts(address(this)).artistNativeReceiptAt(i);
            if (r.operation != 16) continue;
            Sale.Record memory item = records[r.recordHash];
            bytes32 lookup = StreamArtistSaleHashes.lookup(
                item.terms.collectionId, item.terms.saleId, item.terms.saleConfigHash
            );
            b.sales[n++] = DH.Sale(item, delegations[r.recordHash], latest[lookup]);
        }
        return abi.encode(DH.CONSENT, b);
    }

    function importConsent(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage records,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q,
        bytes memory raw
    ) public {
        DH.Consent memory b = StreamArtistDelegationHydrationCodec.consent(raw);
        if (b.policies.length != q.policies.length) revert T.InvalidRecord();
        for (uint256 i; i < b.policies.length; ++i) {
            bytes32 key = keccak256(
                abi.encode(q.collectionId, q.policies[i].phaseId, q.policies[i].policyHash)
            );
            DH.Policy memory row = b.policies[i];
            if (row.recordHash == 0 || policies[key] != 0 || delegations[row.recordHash] != 0) {
                revert T.InvalidRecord();
            }
            policies[key] = row.recordHash;
            delegations[row.recordHash] = row.grant;
        }
        for (uint256 i; i < b.sales.length; ++i) {
            DH.Sale memory row = b.sales[i];
            bytes32 hash = row.item.recordHash;
            if (hash == 0 || records[hash].recordHash != 0 || delegations[hash] != 0) {
                revert T.InvalidRecord();
            }
            records[hash] = row.item;
            delegations[hash] = row.grant;
            bytes32 lookup = StreamArtistSaleHashes.lookup(
                row.item.terms.collectionId, row.item.terms.saleId, row.item.terms.saleConfigHash
            );
            if (latest[lookup] != 0 && latest[lookup] != row.current) revert T.InvalidRecord();
            latest[lookup] = row.current;
        }
    }
}
