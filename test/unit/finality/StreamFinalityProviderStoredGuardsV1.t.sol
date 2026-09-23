// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityProviderStoredGuardsV1 as NewGuards
} from "../../../smart-contracts/domains/finality/StreamFinalityProviderStoredGuardsV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";

interface ProviderGuardVm {
    function etch(address, bytes calldata) external;
    function chainId(uint256) external;
}

contract ProviderGuardPin { }

/// @dev Typed membership boundary makes the smaller original component frame observable.
contract ProviderGuardMembership {
    address private immutable _core;
    bool public wrongSubject;
    bool public emptyMembership;
    error WrongMembershipFrame();

    constructor(address core_) {
        _core = core_;
    }

    function set(bool wrong, bool empty) external {
        wrongSubject = wrong;
        emptyMembership = empty;
    }

    function requireScopeMembership(StreamFinalityScope calldata s)
        external
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        if (gasleft() > 200000) revert WrongMembershipFrame();
        f.scopeSubject =
            wrongSubject ? bytes32(uint256(1)) : Subjects.scopeSubject(block.chainid, _core, s);
        f.membershipHash =
            emptyMembership ? bytes32(0) : keccak256("independent authoritative membership");
    }
}

/// @dev Both routes execute in this same caller/storage domain. The old side spells the frozen
/// Router provider guards; only the new side calls the extracted storage projection.
contract ProviderStoredGuardHarness {
    Native.Config private _saved;
    address public immutable core;
    bytes32 private immutable coreCodeHash;
    address public immutable metadataHost;
    bytes32 private immutable metadataHostCodeHash;
    address public immutable metadataRouter;
    bytes32 private immutable metadataRouterCodeHash;
    address public immutable scopeMembershipHost;
    bytes32 private immutable scopeMembershipHostCodeHash;
    uint256 public immutable deploymentChainId;
    uint32 private immutable sourceGas;
    bytes32 public canaryBefore = keccak256("before");
    bytes32 public canaryAfter = keccak256("after");
    error RouterProviderConfiguration();
    error RouterProviderDependency(address target);
    error RouterProviderScope();

    constructor(address[4] memory targets) {
        core = targets[0];
        coreCodeHash = targets[0].codehash;
        metadataHost = targets[1];
        metadataHostCodeHash = targets[1].codehash;
        metadataRouter = targets[2];
        metadataRouterCodeHash = targets[2].codehash;
        scopeMembershipHost = targets[3];
        scopeMembershipHostCodeHash = targets[3].codehash;
        deploymentChainId = block.chainid;
        // The original Native constructor passes componentSourceGas to Router.sourceGas.
        sourceGas = 80000;
        _saved.chainId = block.chainid;
        _saved.componentSourceGas = 80000;
        _saved.sourceGas = 9000000;
        for (uint256 i; i < 4; ++i) {
            _saved.targets[i] = targets[i];
            _saved.codeHashes[i] = targets[i].codehash;
        }
    }

    function check(bool original, StreamFinalityScope calldata s) external view returns (bytes32) {
        if (original) {
            _pins();
            _scope(s);
        } else {
            NewGuards.pins(_saved);
            NewGuards.scope(_saved, s);
        }
        return keccak256(abi.encode(canaryBefore, canaryAfter));
    }

    function _scope(StreamFinalityScope memory scope) private view {
        if (
            scope.collectionId == 0
                || (scope.scopeType == StreamFinalityScopeType.COLLECTION
                        ? scope.tokenId != 0 || scope.scopeId != 0
                        : scope.scopeType == StreamFinalityScopeType.TOKEN
                            ? scope.tokenId == 0 || scope.scopeId != 0
                            : scope.tokenId != 0 || scope.scopeId == 0)
        ) revert RouterProviderScope();
        StreamScopeMembershipFacts memory f = abi.decode(
            Reads.read(
                scopeMembershipHost,
                abi.encodeWithSignature(
                    "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
                ),
                256,
                sourceGas
            ),
            (StreamScopeMembershipFacts)
        );
        if (
            f.scopeSubject != Subjects.scopeSubject(deploymentChainId, core, scope)
                || f.membershipHash == 0
        ) revert RouterProviderScope();
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) revert RouterProviderConfiguration();
        _pin(core, coreCodeHash);
        _pin(metadataHost, metadataHostCodeHash);
        _pin(metadataRouter, metadataRouterCodeHash);
        _pin(scopeMembershipHost, scopeMembershipHostCodeHash);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert RouterProviderDependency(target);
        }
    }
}

contract StreamFinalityProviderStoredGuardsV1Test {
    ProviderGuardVm private constant vm =
        ProviderGuardVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ProviderStoredGuardHarness private h;
    ProviderGuardMembership private membership;
    address[4] private targets;

    function setUp() public {
        for (uint256 i; i < 3; ++i) {
            targets[i] = address(new ProviderGuardPin());
        }
        membership = new ProviderGuardMembership(targets[0]);
        targets[3] = address(membership);
        h = new ProviderStoredGuardHarness(targets);
    }

    function _token() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.TOKEN, 9, 77, 0);
    }

    function _pair(StreamFinalityScope memory s, bool success, bytes memory failure) private view {
        (bool a, bytes memory x) = address(h).staticcall(abi.encodeCall(h.check, (true, s)));
        (bool b, bytes memory y) = address(h).staticcall(abi.encodeCall(h.check, (false, s)));
        require(
            a == success && b == success && keccak256(x) == keccak256(y), "frozen original parity"
        );
        if (!success) {
            require(keccak256(x) == keccak256(failure), "literal error");
        } else {
            require(
                keccak256(x)
                    == keccak256(
                        abi.encode(keccak256(abi.encode(keccak256("before"), keccak256("after"))))
                    ),
                "literal canaries"
            );
        }
    }

    function testOriginalComponentBudgetAndStorageCanaries() public view {
        _pair(_token(), true, "");
    }

    function testEveryOriginalRuntimePinAndExactRestoration() public {
        for (uint256 i; i < 4; ++i) {
            bytes memory old = targets[i].code;
            vm.etch(targets[i], hex"60006000fd");
            _pair(
                _token(),
                false,
                abi.encodeWithSignature("RouterProviderDependency(address)", targets[i])
            );
            vm.etch(targets[i], old);
            _pair(_token(), true, "");
        }
    }

    function testOriginalChainBeforeRuntimeBeforeScopeOrder() public {
        uint256 saved = h.deploymentChainId();
        bytes memory code = targets[0].code;
        vm.etch(targets[0], hex"60006000fd");
        vm.chainId(saved + 1);
        StreamFinalityScope memory s;
        _pair(s, false, abi.encodeWithSignature("RouterProviderConfiguration()"));
        vm.chainId(saved);
        _pair(s, false, abi.encodeWithSignature("RouterProviderDependency(address)", targets[0]));
        vm.etch(targets[0], code);
        _pair(s, false, abi.encodeWithSignature("RouterProviderScope()"));
        _pair(_token(), true, "");
    }

    function testOriginalSubjectAndMembershipRefusalsRestore() public {
        membership.set(true, false);
        _pair(_token(), false, abi.encodeWithSignature("RouterProviderScope()"));
        membership.set(false, true);
        _pair(_token(), false, abi.encodeWithSignature("RouterProviderScope()"));
        membership.set(false, false);
        _pair(_token(), true, "");
    }

    function testFuzzCanonicalScopeParity(uint256 cid, uint256 token, bytes32 key, uint8 kind)
        public
        view
    {
        cid = cid == 0 ? 1 : cid;
        token = token == 0 ? 1 : token;
        key = key == 0 ? bytes32(uint256(1)) : key;
        kind %= 5;
        StreamFinalityScope memory s = StreamFinalityScope(
            StreamFinalityScopeType(kind), cid, kind == 1 ? token : 0, kind >= 2 ? key : bytes32(0)
        );
        _pair(s, true, "");
    }

    function testViewRequiresZeroTokenAndNonzeroKeyThenRestores() public view {
        StreamFinalityScope memory s = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 9, 0, keccak256("complete view membership")
        );
        _pair(s, true, "");
        s.tokenId = 77;
        _pair(s, false, abi.encodeWithSignature("RouterProviderScope()"));
        s.tokenId = 0;
        bytes32 key = s.scopeId;
        s.scopeId = 0;
        _pair(s, false, abi.encodeWithSignature("RouterProviderScope()"));
        s.scopeId = key;
        _pair(s, true, "");
    }
}
