// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import "../../../smart-contracts/domains/artist/StreamArtistCollaboratorIdentityState.sol";
import "../../../smart-contracts/domains/artist/StreamArtistIdentityRevisionState.sol";

interface ExtensionPrototypeVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function prank(address) external;
    function warp(uint256) external;
}

/// @dev Exact Identity storage declaration order; the prototype tests real guardian/Identity mechanics.
abstract contract ArtistExtensionPrototypeStorage is StreamArtistOwner {
    StreamArtistIdentityState.State internal _identity;
    StreamArtistDelegationState.State internal _delegations;
    StreamArtistCollaboratorIdentityState.State internal _collaboratorAccounts;
    StreamArtistIdentityRevisionState.State internal _identityRevisions;
    StreamArtistRotationState.State internal _rotations;

    constructor(address coordinator)
        StreamArtistOwner(
            address(0x101),
            coordinator,
            address(0x102),
            keccak256("domain:identity_authority"),
            address(0x103),
            address(0x104)
        )
    { }

    function _context() internal view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function register(address artist) external returns (bytes32) {
        T.ActionContext memory c = T.ActionContext(1, artist, ownerStateSnapshotV2());
        if (msg.sender != operationCoordinator) revert T.Unauthorized(msg.sender);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.register(
            _identity,
            _replay,
            _context(),
            artist,
            keccak256("prototype"),
            "",
            bytes("prototype"),
            "Prototype"
        );
        // Registration bootstrap is test-only; guardian writes below use the actual owner's calldata guard/commit.
        _bootstrapCommit(m);
        c;
        return m.record;
    }

    function _bootstrapCommit(StreamArtistIdentityState.Mutation memory m) private {
        _stateRoot = keccak256(abi.encode(_stateRoot, m.state));
        ++_revision;
    }

    function guardian(bytes32 artistId) external view returns (bytes32) {
        return StreamArtistRotationState.operativeGuardian(_rotations, artistId);
    }

    function guardianDigest(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRotationHashes.guardianDigest(_environment(), p, a);
    }
}

contract ArtistExtensionPrototypeImplementation is ArtistExtensionPrototypeStorage {
    address public immutable host;
    error ExtensionWrongHost(address actual);

    constructor(address host_, address coordinator) ArtistExtensionPrototypeStorage(coordinator) {
        host = host_;
    }

    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        if (address(this) != host) {
            revert ExtensionWrongHost(address(this));
        }
        _check(c, 28);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.setGuardians(
            _rotations, _identity, _replay, _context(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }
}

contract ArtistExtensionPrototypeInline is ArtistExtensionPrototypeStorage {
    constructor(address coordinator) ArtistExtensionPrototypeStorage(coordinator) { }

    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _check(c, 28);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.setGuardians(
            _rotations, _identity, _replay, _context(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }
}

contract ArtistExtensionPrototypeHost is ArtistExtensionPrototypeStorage {
    address public immutable extension;

    constructor(address coordinator) ArtistExtensionPrototypeStorage(coordinator) {
        extension = address(new ArtistExtensionPrototypeImplementation(address(this), coordinator));
    }

    function setGuardians(
        T.ActionContext calldata,
        R.GuardianSet calldata,
        T.Authorization calldata,
        T.SignerApproval calldata
    ) external returns (bytes32) {
        address target = extension;
        assembly ("memory-safe") {
            let p := mload(0x40)
            calldatacopy(p, 0, calldatasize())
            let ok := delegatecall(gas(), target, p, calldatasize(), 0, 0)
            returndatacopy(p, 0, returndatasize())
            if iszero(ok) { revert(p, returndatasize()) }
            return(p, returndatasize())
        }
    }
}

contract StreamArtistTypedExtensionPrototypeTest {
    ExtensionPrototypeVm constant vm =
        ExtensionPrototypeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testTypedExtensionWriteReadReplayAndOwnerEvent() external {
        vm.warp(100);
        ArtistExtensionPrototypeHost host = new ArtistExtensionPrototypeHost(address(this));
        bytes32 artistId = host.register(address(0xA11CE));
        address[] memory guardians = new address[](2);
        guardians[0] = address(0x201);
        guardians[1] = address(0x202);
        R.GuardianSet memory p = R.GuardianSet(artistId, guardians, 2, 10 days);
        T.Authorization memory a = T.Authorization(0, 100, "");
        T.SignerApproval memory proof =
            T.SignerApproval(address(0xA11CE), host.guardianDigest(p, a), true);
        T.Snapshot memory before_ = host.ownerStateSnapshotV2();
        T.ActionContext memory c = T.ActionContext(28, address(0xA11CE), before_);
        vm.recordLogs();
        bytes32 record = host.setGuardians(c, p, a, proof);
        ExtensionPrototypeVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(host), "owner emitter");
        require(
            logs[0].topics[0]
                == keccak256(
                    "ArtistGuardianSetUpdated(uint16,bytes32,address[],uint32,uint64,uint8,uint256,uint64,bytes32)"
                ),
            "event ABI"
        );
        require(logs[0].topics[1] == artistId && host.guardian(artistId) == record, "record read");
        T.Snapshot memory after_ = host.ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip != before_.recordChainTip,
            "one owner commit"
        );
        c.expected = after_;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        host.setGuardians(c, p, a, proof);
        require(
            keccak256(abi.encode(host.ownerStateSnapshotV2())) == keccak256(abi.encode(after_)),
            "replay rollback"
        );
        bytes32 nonceKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(0x101),
                address(this),
                address(0x102),
                address(host),
                keccak256("domain:identity_authority"),
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, uint256(0)))
            )
        );
        T.ReplayCell memory cell = host.replayCell(nonceKey);
        require(cell.status != 0, "authoritative nonce cell");
        // Explicit unit Coordinator boundary: this proof was supplied as already authenticated.
        // Fresh guardian terms avoid the record-uniqueness guard and reach exact nonce replay.
        p.minContestSeconds = 11 days;
        a.signature = hex"01";
        proof.direct = false;
        proof.digest = host.guardianDigest(p, a);
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, nonceKey));
        host.setGuardians(c, p, a, proof);
        address extension = host.extension();
        vm.expectRevert(
            abi.encodeWithSelector(
                ArtistExtensionPrototypeImplementation.ExtensionWrongHost.selector, extension
            )
        );
        ArtistExtensionPrototypeImplementation(extension).setGuardians(c, p, a, proof);
        require(host.guardian(artistId) == record, "direct extension isolation");
    }

    function testTypedExtensionCalldataUsesHostVerifyingContractAndOriginalActor() external {
        vm.warp(100);
        ArtistExtensionPrototypeHost host = new ArtistExtensionPrototypeHost(address(this));
        bytes32 artistId = host.register(address(0xA11CE));
        address[] memory guardians = new address[](0);
        R.GuardianSet memory p = R.GuardianSet(artistId, guardians, 0, 0);
        T.Authorization memory a = T.Authorization(0, 100, "");
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(0x101)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)"
                ),
                artistId,
                keccak256(bytes("")),
                uint32(0),
                uint64(0),
                uint256(0),
                uint64(100)
            )
        );
        require(
            host.guardianDigest(p, a) == keccak256(abi.encodePacked(hex"1901", domain, structHash)),
            "independent facade domain"
        );
        T.SignerApproval memory proof =
            T.SignerApproval(address(0xA11CE), host.guardianDigest(p, a), true);
        T.ActionContext memory c = T.ActionContext(28, address(0xBAD), host.ownerStateSnapshotV2());
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        host.setGuardians(c, p, a, proof);
        c.actor = address(0xA11CE);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0xBAD)));
        vm.prank(address(0xBAD));
        host.setGuardians(c, p, a, proof);
        bytes32 record = host.setGuardians(c, p, a, proof);
        require(record != bytes32(0), "valid original actor");
    }
}
