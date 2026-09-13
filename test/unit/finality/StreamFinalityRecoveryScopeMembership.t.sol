// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RouterScopeMembershipFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryScopeMembership.sol";

interface RecoveryMembershipVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

contract RecoveryMembershipHarness {
    StreamFinalityRecoveryScopeMembership.Environment private environment;

    constructor(StreamFinalityRecoveryScopeMembership.Environment memory e) {
        environment = e;
    }

    function read(StreamFinalityScope memory scope)
        external
        view
        returns (StreamScopeMembershipFacts memory)
    {
        return StreamFinalityRecoveryScopeMembership.read(environment, scope);
    }
}

/// @dev Actual Metadata/schema/store/inventory/membership/Router/provider. The original registry,
///      Core identities, artist acceptance and governance authorization remain explicit boundaries.
contract StreamFinalityRecoveryScopeMembershipTest is RouterScopeMembershipFixture {
    RecoveryMembershipHarness private reader;
    uint256[] private familyTokens;

    function prepareGraph() external {
        require(msg.sender == address(this), "test-only setup");
        _routerMembership(true);
        reader = _reader(1200000);
        familyTokens = _tokens(3);
        _index(familyTokens, 0, 3);
    }

    function _reader(uint256 cap) private returns (RecoveryMembershipHarness) {
        return new RecoveryMembershipHarness(
            StreamFinalityRecoveryScopeMembership.Environment(
                address(core),
                address(originalBoundary),
                address(originalBoundary).codehash,
                address(scopeRouter),
                cap
            )
        );
    }

    function publishScope(uint8 family) external returns (StreamFinalityScope memory) {
        require(msg.sender == address(this), "test-only publication");
        return _seal(family, familyTokens, "ipfs://inherited-scope");
    }

    function beginScope() external returns (StreamFinalityScope memory) {
        require(msg.sender == address(this), "test-only incomplete publication");
        return
            membership.beginScopeMembership(_publish(_manifest(2, familyTokens), "ipfs://pending"));
    }

    function _reject(StreamFinalityScope memory scope, bytes4 expected) private view {
        (bool ok, bytes memory reason) =
            address(reader).staticcall(abi.encodeCall(reader.read, (scope)));
        require(!ok && bytes4(reason) == expected, "exact membership rejection");
    }

    function testAllInheritedFamiliesUseActualSealedMembershipAndRouterUniverse() public {
        this.prepareGraph();
        uint256[] memory ids = familyTokens;
        for (uint8 family = 2; family <= 4; ++family) {
            StreamFinalityScope memory scope = this.publishScope(family);
            StreamScopeMembershipFacts memory f = reader.read(scope);
            require(
                keccak256(abi.encode(f))
                    == keccak256(abi.encode(membership.requireScopeMembership(scope)))
            );
            for (uint256 i; i < ids.length; ++i) {
                require(scopeRouter.scopeTokenAt(scope, i) == ids[i]);
                require(scopeRouter.scopeCoversToken(scope, ids[i]));
            }
            require(f.tokenCount == 3 && f.sourceRecordHash != 0 && f.membershipHash != 0);
        }
    }

    function testIncompleteActualPublicationCannotEnterAndSealingRestores() public {
        this.prepareGraph();
        StreamFinalityScope memory scope = this.beginScope();
        _reject(scope, StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector);
        membership.continueScopeMembership(scope, 1);
        require(reader.read(scope).tokenCount == 3);
    }

    function testExactCanonicalFamilyAndOriginalRecordIdCannotBeSubstituted() public {
        this.prepareGraph();
        StreamFinalityScope memory scope = this.publishScope(2);
        StreamScopeMembershipFacts memory f = reader.read(scope);
        scope.scopeType = StreamFinalityScopeType.SEASON;
        _reject(scope, StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector);
        scope.scopeType = StreamFinalityScopeType.RELEASE;
        scope.collectionId = 2;
        _reject(scope, StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector);
        scope.collectionId = 1;
        scope.tokenId = 3;
        _reject(
            scope,
            StreamFinalityRecoveryScopeMembership.RecoveryScopeMembershipFactsInvalid.selector
        );
        scope.tokenId = 0;
        f.sourceRecordHash = keccak256("other authorized metadata record");
        RecoveryMembershipVm(address(vm))
            .mockCall(
                address(membership),
                abi.encodeCall(membership.requireScopeMembership, (scope)),
                abi.encode(f)
            );
        _reject(
            scope,
            StreamFinalityRecoveryScopeMembership.RecoveryScopeMembershipFactsInvalid.selector
        );
        RecoveryMembershipVm(address(vm)).clearMockedCalls();
        require(reader.read(scope).sourceRecordHash != f.sourceRecordHash);
    }

    function testPinnedOriginalProviderRouterAndMembershipRuntimeLossRejectsAndRestores() public {
        this.prepareGraph();
        StreamFinalityScope memory scope = this.publishScope(3);
        bytes32 healthy = keccak256(abi.encode(reader.read(scope)));
        address[5] memory targets = [
            address(originalBoundary),
            address(realProvider),
            address(scopeRouter),
            address(metadata),
            address(membership)
        ];
        for (uint256 i; i < targets.length; ++i) {
            this.checkRuntimeLoss(targets[i], scope, healthy);
        }
    }

    function checkRuntimeLoss(address target, StreamFinalityScope memory scope, bytes32 healthy)
        external
    {
        require(msg.sender == address(this), "test-only runtime probe");
        bytes memory runtime = target.code;
        vm.etch(target, hex"00");
        _reject(
            scope,
            StreamFinalityRecoveryScopeMembership.RecoveryScopeMembershipBindingInvalid.selector
        );
        vm.etch(target, runtime);
        require(keccak256(abi.encode(reader.read(scope))) == healthy);
    }

    function testHistoricalOriginalGraphIgnoresNewPointersMintsBurnsAndGrantRevocation() public {
        this.prepareGraph();
        StreamFinalityScope memory scope = this.publishScope(4);
        bytes32 healthy = keccak256(abi.encode(reader.read(scope)));
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), false);
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(0xbeef));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(0xcafe));
        core.setToken(3, 1, 1, 3);
        core.setToken(12, 1, 4, 2);
        require(keccak256(abi.encode(reader.read(scope))) == healthy);
        require(membership.scopeCoversToken(scope, 3) && !membership.scopeCoversToken(scope, 12));
    }

    function testReturnedFactsExactWidthSubjectAndCompleteCommitmentAreAuthenticated() public {
        this.prepareGraph();
        StreamFinalityScope memory scope = this.publishScope(2);
        StreamScopeMembershipFacts memory f = reader.read(scope);
        bytes memory input = abi.encodeCall(membership.requireScopeMembership, (scope));
        bytes memory good = abi.encode(f);
        RecoveryMembershipVm(address(vm))
            .mockCall(address(membership), input, abi.encodePacked(good, bytes32(0)));
        _reject(scope, StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector);
        f.scopeSubject = keccak256("different subject");
        RecoveryMembershipVm(address(vm)).mockCall(address(membership), input, abi.encode(f));
        _reject(
            scope,
            StreamFinalityRecoveryScopeMembership.RecoveryScopeMembershipFactsInvalid.selector
        );
        f = abi.decode(good, (StreamScopeMembershipFacts));
        f.membershipHash = keccak256("different list commitment");
        RecoveryMembershipVm(address(vm)).mockCall(address(membership), input, abi.encode(f));
        _reject(
            scope,
            StreamFinalityRecoveryScopeMembership.RecoveryScopeMembershipFactsInvalid.selector
        );
        RecoveryMembershipVm(address(vm)).clearMockedCalls();
        require(keccak256(abi.encode(reader.read(scope))) == keccak256(good));
    }

    function testCallerSuppliedDependencyBudgetMustCoverActualNestedHostReads() public {
        this.prepareGraph();
        StreamFinalityScope memory scope = this.publishScope(3);
        RecoveryMembershipHarness healthy = reader;
        reader = _reader(150000);
        _reject(scope, StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector);
        reader = healthy;
        require(reader.read(scope).tokenCount == 3);
    }
}
