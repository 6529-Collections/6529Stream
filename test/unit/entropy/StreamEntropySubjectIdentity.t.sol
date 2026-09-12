// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";

/// @notice Minimal Core surface for testing coordinator subject identity without a full stack.
contract EntropySubjectCoreFixture {
    StreamEntropyCoordinator private _coordinator;
    mapping(uint256 => bool) private _minted;
    mapping(uint256 => uint256) private _collections;
    mapping(uint256 => address) private _coordinatorsAtMint;
    mapping(uint256 => bool) private _burned;
    mapping(uint256 => bool) private _frozen;
    uint256 public metadataNotifications;
    address private _moduleRegistry;

    function setModuleRegistry(address registry) external {
        _moduleRegistry = registry;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        require(kind == keccak256("MODULE_REGISTRY"), "only module registry");
        return (
            _moduleRegistry,
            _moduleRegistry.codehash,
            false,
            kind,
            type(IStreamModuleRegistry).interfaceId,
            _moduleRegistry,
            1,
            bytes32(0),
            bytes32(0),
            1
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function collectionExists(uint256 collectionId) external pure returns (bool) {
        return collectionId == 1 || collectionId == 2;
    }

    function collectionFreezeStatus(uint256 collectionId) external view returns (bool) {
        return _frozen[collectionId];
    }

    function freezeCollection(uint256 collectionId) external {
        _frozen[collectionId] = true;
    }

    function burnToken(uint256 tokenId) external {
        _burned[tokenId] = true;
    }

    function setCoordinator(StreamEntropyCoordinator coordinator) external {
        _coordinator = coordinator;
    }

    function registerToken(uint256 tokenId, bytes32 mintCommitment) external {
        _register(1, tokenId, mintCommitment);
    }

    function registerTokenInCollection(
        uint256 collectionId,
        uint256 tokenId,
        bytes32 mintCommitment
    ) external {
        _register(collectionId, tokenId, mintCommitment);
    }

    function _register(uint256 collectionId, uint256 tokenId, bytes32 mintCommitment) private {
        _minted[tokenId] = true;
        _collections[tokenId] = collectionId;
        _coordinatorsAtMint[tokenId] = address(_coordinator);
        _coordinator.onTokenMinted(collectionId, tokenId, address(0xbeef), mintCommitment);
    }

    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (_minted[tokenId], _collections[tokenId], tokenId, _burned[tokenId]);
    }

    function coordinatorAtMint(uint256 tokenId) external view returns (address) {
        return _coordinatorsAtMint[tokenId];
    }

    function tokenLifecycle(uint256 tokenId) external view returns (uint8) {
        return uint8(
            _burned[tokenId]
                ? StreamTokenLifecycle.BURNED
                : (_minted[tokenId] ? StreamTokenLifecycle.MINTED : StreamTokenLifecycle.UNKNOWN)
        );
    }

    function emitMetadataUpdate(uint256 tokenId, bytes32 reasonHash) external {
        require(msg.sender == _coordinatorsAtMint[tokenId] && _minted[tokenId] && reasonHash != 0);
        ++metadataNotifications;
    }
}

contract StreamEntropySubjectIdentityTest is CharacterizationTestBase {
    bytes32 private constant MANIFEST = keccak256("subject-identity-test");
    bytes32 private constant MINT_COMMITMENT = keccak256("signed mint commitment");
    address private constant REQUESTER = address(0x1234);
    uint256 private constant TOKEN_ID = 1;

    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    bytes32 private tokenKey;
    MockEntropyRoleRegistry public roleRegistry;

    function setUp() public {
        core = new EntropySubjectCoreFixture();
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        entropy = new StreamEntropyCoordinator(
            address(core),
            address(this),
            address(roleRegistry),
            MANIFEST,
            "urn:test:subject-identity",
            MANIFEST
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        entropy.configureCollection(1, address(provider), keccak256("collection salt"), true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        entropy.setRequester(REQUESTER, true);
        core.registerToken(TOKEN_ID, MINT_COMMITMENT);
        tokenKey = keccak256(abi.encode("TOKEN", TOKEN_ID));
    }

    function testRequesterCannotUseTokenKeyAsScopeAndTokenStillFinalizes() public {
        _expectTokenSubstitutionRejected(REQUESTER);
        require(provider.nextRequestId() == 1, "rejection cannot request provider output");
        require(entropy.pendingRequestCount() == 0, "rejection cannot add pending request");
        require(core.metadataNotifications() == 0, "rejection cannot notify metadata");

        vm.prank(REQUESTER);
        (, uint256 requestId) = entropy.requestEntropy(TOKEN_ID);
        provider.fulfill(requestId, bytes32(uint256(17)));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(TOKEN_ID);
        require(seed != 0 && finalized, "ordinary token request still finalizes");
        require(entropy.scopeEntropy(tokenKey).inputsHash == MINT_COMMITMENT, "commitment retained");
        require(provider.nextRequestId() == 2 && entropy.pendingRequestCount() == 0);
        require(core.metadataNotifications() == 1, "token fulfillment notifies metadata once");
    }

    function testAuthorityCannotUseTokenKeyAsScope() public {
        _expectTokenSubstitutionRejected(address(this));
        require(provider.nextRequestId() == 1 && entropy.pendingRequestCount() == 0);
    }

    function testRequestedAndFinalizedTokenKeysRemainOutsideScopeNamespace() public {
        (, uint256 requestId) = entropy.requestEntropy(TOKEN_ID);
        _expectTokenSubstitutionRejected(REQUESTER);
        require(provider.nextRequestId() == 2 && entropy.pendingRequestCount() == 1);
        provider.fulfill(requestId, bytes32(uint256(19)));
        _expectTokenSubstitutionRejected(REQUESTER);
        require(provider.nextRequestId() == 2 && entropy.pendingRequestCount() == 0);
        require(core.metadataNotifications() == 1);
    }

    function testRegisteredScopeFinalizesWithoutChangingTokenSubject() public {
        bytes32 tokenBefore = keccak256(abi.encode(entropy.scopeEntropy(tokenKey)));
        vm.prank(REQUESTER);
        bytes32 scopeId = entropy.registerEntropyScope(1, 0, keccak256("sale scope"));
        bytes32 inputsHash = keccak256("scope inputs");
        vm.prank(REQUESTER);
        (, uint256 requestId) = entropy.requestScopeEntropy(scopeId, inputsHash);
        require(entropy.scopeEntropy(scopeId).status == StreamEntropyStatus.REQUESTED);
        require(entropy.pendingRequestCount() == 1);
        provider.fulfill(requestId, bytes32(uint256(23)));
        (bytes32 seed, bool finalized) = entropy.scopeSeed(scopeId);
        require(seed != 0 && finalized, "registered scope still finalizes");
        require(entropy.scopeEntropy(scopeId).inputsHash == inputsHash, "scope inputs retained");
        require(keccak256(abi.encode(entropy.scopeEntropy(tokenKey))) == tokenBefore);
        require(provider.nextRequestId() == 2 && entropy.pendingRequestCount() == 0);
        require(core.metadataNotifications() == 0, "scope fulfillment cannot notify a token");

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FINALIZED
            )
        );
        entropy.requestScopeEntropy(scopeId, keccak256("replacement scope inputs"));
        require(entropy.scopeEntropy(scopeId).inputsHash == inputsHash, "replay keeps inputs");
    }

    function testUnknownScopeIsRejectedWithoutCreatingSubject() public {
        bytes32 unknownScope = keccak256("unregistered scope");
        vm.prank(REQUESTER);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidSubject.selector, unknownScope)
        );
        entropy.requestScopeEntropy(unknownScope, keccak256("inputs"));
        require(entropy.scopeEntropy(unknownScope).status == StreamEntropyStatus.NONE);
        require(entropy.scopeEntropy(unknownScope).inputsHash == 0);
        require(provider.nextRequestId() == 1 && entropy.pendingRequestCount() == 0);
    }

    function _expectTokenSubstitutionRejected(address caller) private {
        bytes32 beforeSubject = keccak256(abi.encode(entropy.scopeEntropy(tokenKey)));
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidSubject.selector, tokenKey)
        );
        entropy.requestScopeEntropy(tokenKey, keccak256("replacement commitment"));
        require(
            keccak256(abi.encode(entropy.scopeEntropy(tokenKey))) == beforeSubject,
            "scope substitution cannot change token commitment, state, request, or seed"
        );
    }
}
