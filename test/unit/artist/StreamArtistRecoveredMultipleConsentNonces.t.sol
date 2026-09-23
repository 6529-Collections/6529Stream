// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleConsentNonces as Nonces
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistRecoveredMultipleIdentityNonces as Base
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleIdentityNonces.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @notice Focused nonce-membership/bijection oracles; synthetic trees test byte preservation,
/// not authentic source admission or the separate nonce-tree importer.
contract StreamArtistRecoveredMultipleConsentNoncesTest {
    address private constant DELEGATE = address(0xD311);

    function testMultipleConsentGenuineDelegateLaneDomainAndOldBaseRemainStrict() external view {
        IH.Bundle memory b = _bundle(bytes32(uint256(1)), address(0xA1));
        Nonces.validateLocal(b);
        (bool old,) =
            address(Base).staticcall(abi.encodeWithSelector(Base.validateLocal.selector, b));
        require(!old, "old singleton aggregate rejects retained grants");
        b.nonces[0].key = keccak256(abi.encode(b.artistId, DELEGATE));
        _badLocal(b);
        b.nonces[0].key = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), b.artistId, DELEGATE)
        );
        Nonces.validateLocal(b);
    }

    function testMultipleConsentTwoArtistsSameDelegateIndependentLanesAndOriginalOrder()
        external
        pure
    {
        (M.State memory s, RH.NonceInventory[] memory inventory) = _fixture();
        IH.NonceLane[] memory lanes = Nonces.ordered(s, inventory);
        require(
            lanes.length == 2 && lanes[0].key != lanes[1].key,
            "same delegate, distinct original Artist lanes"
        );
        require(
            keccak256(abi.encode(lanes[0].words)) == keccak256(abi.encode(inventory[0].words)),
            "global order need not equal Artist order"
        );
    }

    function testMultipleConsentUnionRejectsWrongArtistDuplicateOmittedAndExtraLane()
        external
        view
    {
        (M.State memory s, RH.NonceInventory[] memory inventory) = _fixture();
        bytes memory pristine = abi.encode(s);
        IH.Bundle memory b = abi.decode(s.rows[0], (IH.Bundle));
        b.nonces[0].key = inventory[0].index.key;
        s.rows[0] = abi.encode(b);
        _badUnion(s, inventory);
        s = abi.decode(pristine, (M.State));
        s.rows[1] = s.rows[0];
        _badUnion(s, inventory);
        s = abi.decode(pristine, (M.State));
        b = abi.decode(s.rows[0], (IH.Bundle));
        b.nonces = new IH.NonceLane[](0);
        s.rows[0] = abi.encode(b);
        _badUnion(s, inventory);
        s = abi.decode(pristine, (M.State));
        RH.NonceInventory[] memory extra = new RH.NonceInventory[](3);
        extra[0] = inventory[0];
        extra[1] = inventory[1];
        extra[2] = inventory[1];
        _badUnion(s, extra);
    }

    function testMultipleConsentUnionComparesEveryTreeWordAndExhaustionFlag() external view {
        (M.State memory s, RH.NonceInventory[] memory inventory) = _fixture();
        bytes memory pristine = abi.encode(s);
        for (uint256 i; i < 32; ++i) {
            IH.Bundle memory b = abi.decode(s.rows[0], (IH.Bundle));
            b.nonces[0].words[0].words[i] ^= 1;
            s.rows[0] = abi.encode(b);
            _badUnion(s, inventory);
            s = abi.decode(pristine, (M.State));
        }
        IH.Bundle memory b = abi.decode(s.rows[0], (IH.Bundle));
        b.nonces[0].words[0].exhausted = true;
        s.rows[0] = abi.encode(b);
        _badUnion(s, inventory);
        s = abi.decode(pristine, (M.State));
        Nonces.ordered(s, inventory);
    }

    function testMultipleConsentUnionRequiresGlobalRegistrationTimingAndUniqueAuthority()
        external
        view
    {
        (M.State memory s, RH.NonceInventory[] memory inventory) = _fixture();
        bytes memory pristine = abi.encode(s);
        IH.Bundle memory b = abi.decode(s.rows[0], (IH.Bundle));
        b.nextRegistrationNonce = 1;
        s.rows[0] = abi.encode(b);
        _badUnion(s, inventory);
        s = abi.decode(pristine, (M.State));
        b = abi.decode(s.rows[0], (IH.Bundle));
        b.timing.checkpoint.root = keccak256("not global timing");
        s.rows[0] = abi.encode(b);
        _badUnion(s, inventory);
        s = abi.decode(pristine, (M.State));
        b = abi.decode(s.rows[0], (IH.Bundle));
        b.identity.authorityAddress = address(0xA2);
        s.rows[0] = abi.encode(b);
        _badUnion(s, inventory);
    }

    function testMultipleConsentLocalRejectsDuplicatePrefixAndInconsistentExhaustion()
        external
        view
    {
        IH.Bundle memory b = _bundle(bytes32(uint256(1)), address(0xA1));
        bytes memory pristine = abi.encode(b);
        AH.NonceWord[] memory words = new AH.NonceWord[](2);
        words[0] = b.nonces[0].words[0];
        words[1] = b.nonces[0].words[0];
        b.nonces[0].words = words;
        _badLocal(b);
        b = abi.decode(pristine, (IH.Bundle));
        words = new AH.NonceWord[](2);
        words[0] = b.nonces[0].words[0];
        words[1].prefix = 99;
        words[1].words[0] = 1;
        words[1].exhausted = true;
        b.nonces[0].words = words;
        _badLocal(b);
    }

    function _fixture()
        private
        pure
        returns (M.State memory s, RH.NonceInventory[] memory inventory)
    {
        s.artists = new AH.Query[](2);
        s.rows = new bytes[](2);
        inventory = new RH.NonceInventory[](2);
        for (uint256 i; i < 2; ++i) {
            IH.Bundle memory b = _bundle(bytes32(i + 1), address(uint160(0xA1 + i)));
            s.artists[i].artistId = b.artistId;
            s.rows[i] = abi.encode(b);
            inventory[1 - i].index = CP.NonceIndex(2, b.nonces[0].key, 1);
            inventory[1 - i].words = b.nonces[0].words;
        }
    }

    function _bundle(bytes32 id, address authority) private pure returns (IH.Bundle memory b) {
        b.artistId = id;
        b.identity.authorityAddress = authority;
        b.nextRegistrationNonce = 2;
        b.delegations = new IH.DelegationRow[](1);
        b.delegations[0].record.grant.delegate = DELEGATE;
        b.delegations[0].record.grant.artistId = id;
        b.nonces = new IH.NonceLane[](1);
        b.nonces[0].kind = 2;
        b.nonces[0].key = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), id, DELEGATE)
        );
        b.nonces[0].words = new AH.NonceWord[](1);
        b.nonces[0].words[0].prefix = 7;
        for (uint256 i; i < 32; ++i) {
            b.nonces[0].words[0].words[i] =
                uint256(keccak256(abi.encode("opaque original tree word", id, i)));
        }
    }

    function _badLocal(IH.Bundle memory b) private view {
        (bool ok,) =
            address(Nonces).staticcall(abi.encodeWithSelector(Nonces.validateLocal.selector, b));
        require(!ok, "invalid local membership");
    }

    function _badUnion(M.State memory s, RH.NonceInventory[] memory n) private view {
        (bool ok,) =
            address(Nonces).staticcall(abi.encodeWithSelector(Nonces.ordered.selector, s, n));
        require(!ok, "invalid complete global union");
    }
}
