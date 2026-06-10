// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./IStreamCore.sol";

abstract contract StreamRandomizerLifecycle {
    enum RandomnessRequestState {
        None,
        Pending,
        Fulfilled,
        Stale,
        FailedPostProcessing
    }

    struct RandomnessRequest {
        uint256 collectionId;
        uint256 tokenId;
        address provider;
        uint256 providerRequestId;
        uint256 randomizerEpoch;
        RandomnessRequestState state;
        uint256 requestedBlock;
        uint256 requestedTimestamp;
        uint256 fulfilledBlock;
        uint256 fulfilledTimestamp;
        bytes32 derivedSeed;
        bytes32 failureDataHash;
    }

    error UnknownRandomnessRequest(uint256 requestId);
    error RandomnessRequestAlreadyExists(uint256 requestId);
    error TokenRandomnessRequestAlreadyExists(uint256 tokenId, uint256 requestId);
    error RandomnessRequestNotPending(uint256 requestId, RandomnessRequestState state);
    error WrongRandomnessProvider(
        uint256 requestId, address expectedProvider, address actualProvider
    );
    error WrongRandomnessTokenCollection(
        uint256 requestId, uint256 tokenId, uint256 expectedCollectionId, uint256 actualCollectionId
    );
    error StaleRandomnessRequest(
        uint256 requestId,
        uint256 expectedEpoch,
        uint256 actualEpoch,
        address expectedProvider,
        address actualProvider
    );
    error EmptyRandomWords(uint256 requestId);
    error ZeroDerivedSeed(uint256 requestId);
    error RandomnessRequestNotFulfilled(uint256 requestId, RandomnessRequestState state);

    mapping(uint256 => RandomnessRequest) private randomnessRequests;
    mapping(uint256 => uint256) public requestToToken;
    mapping(uint256 => uint256) public tokenToRequest;
    mapping(uint256 => uint256) public tokenIdToCollection;
    mapping(uint256 => uint256) private pendingRandomnessRequestsByCollection;
    uint256 private pendingRandomnessRequestCount;

    event RandomnessRequested(
        uint256 indexed requestId,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address provider,
        uint256 randomizerEpoch
    );
    event RandomnessFulfilled(
        uint256 indexed requestId,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 derivedSeed
    );
    event RandomnessRequestMarkedStale(
        uint256 indexed requestId,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address provider,
        uint256 randomizerEpoch
    );
    event RandomnessPostProcessingFailed(
        uint256 indexed requestId,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 derivedSeed,
        bytes32 failureDataHash
    );

    function retrieveRandomnessRequest(uint256 _requestId)
        public
        view
        returns (RandomnessRequest memory)
    {
        return randomnessRequests[_requestId];
    }

    function randomnessRequestState(uint256 _requestId)
        public
        view
        returns (RandomnessRequestState)
    {
        return randomnessRequests[_requestId].state;
    }

    function retrieveRandomnessRequestForToken(uint256 tokenId)
        public
        view
        returns (RandomnessRequest memory)
    {
        return randomnessRequests[tokenToRequest[tokenId]];
    }

    function randomnessRequestStateForToken(uint256 tokenId)
        public
        view
        returns (RandomnessRequestState)
    {
        return randomnessRequests[tokenToRequest[tokenId]].state;
    }

    function supportsRandomizerLifecycle() external pure returns (bool) {
        return true;
    }

    function pendingRandomnessRequests(uint256 collectionId) public view returns (uint256) {
        return pendingRandomnessRequestsByCollection[collectionId];
    }

    function totalPendingRandomnessRequests() public view returns (uint256) {
        return pendingRandomnessRequestCount;
    }

    function _recordRandomnessRequest(
        uint256 _requestId,
        uint256 _collectionId,
        uint256 _tokenId,
        uint256 _randomizerEpoch
    ) internal {
        if (_requestId == 0) {
            revert UnknownRandomnessRequest(_requestId);
        }
        if (randomnessRequests[_requestId].state != RandomnessRequestState.None) {
            revert RandomnessRequestAlreadyExists(_requestId);
        }
        // Keep tokenToRequest after fulfillment or stale marking: a token may only
        // receive randomness once. Burn/remint redraw policy is tracked separately.
        if (tokenToRequest[_tokenId] != 0) {
            revert TokenRandomnessRequestAlreadyExists(_tokenId, tokenToRequest[_tokenId]);
        }

        requestToToken[_requestId] = _tokenId;
        tokenToRequest[_tokenId] = _requestId;
        tokenIdToCollection[_tokenId] = _collectionId;
        pendingRandomnessRequestsByCollection[_collectionId] =
            pendingRandomnessRequestsByCollection[_collectionId] + 1;
        pendingRandomnessRequestCount = pendingRandomnessRequestCount + 1;
        randomnessRequests[_requestId] = RandomnessRequest({
            collectionId: _collectionId,
            tokenId: _tokenId,
            provider: address(this),
            providerRequestId: _requestId,
            randomizerEpoch: _randomizerEpoch,
            state: RandomnessRequestState.Pending,
            requestedBlock: block.number,
            requestedTimestamp: block.timestamp,
            fulfilledBlock: 0,
            fulfilledTimestamp: 0,
            derivedSeed: bytes32(0),
            failureDataHash: bytes32(0)
        });

        emit RandomnessRequested(
            _requestId, _collectionId, _tokenId, address(this), _randomizerEpoch
        );
    }

    function _fulfillRandomnessRequest(
        IStreamCore _core,
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal returns (uint256 collectionId, uint256 tokenId, bytes32 derivedSeed) {
        RandomnessRequest storage request = randomnessRequests[_requestId];
        if (request.state == RandomnessRequestState.None) {
            revert UnknownRandomnessRequest(_requestId);
        }
        if (request.state != RandomnessRequestState.Pending) {
            revert RandomnessRequestNotPending(_requestId, request.state);
        }
        // Defense-in-depth for future shared-storage or adapter migration paths.
        if (request.provider != address(this)) {
            revert WrongRandomnessProvider(_requestId, request.provider, address(this));
        }
        if (_randomWords.length == 0) {
            revert EmptyRandomWords(_requestId);
        }

        collectionId = request.collectionId;
        tokenId = request.tokenId;
        uint256 tokenCollectionId = _core.viewColIDforTokenID(tokenId);
        if (tokenCollectionId != collectionId) {
            revert WrongRandomnessTokenCollection(
                _requestId, tokenId, collectionId, tokenCollectionId
            );
        }
        uint256 currentEpoch = _core.viewRandomizerEpoch(collectionId);
        address currentProvider = _core.viewCollectionRandomizerContract(collectionId);
        if (currentEpoch != request.randomizerEpoch || currentProvider != address(this)) {
            revert StaleRandomnessRequest(
                _requestId, request.randomizerEpoch, currentEpoch, address(this), currentProvider
            );
        }

        derivedSeed = keccak256(
            abi.encode(
                address(this),
                _requestId,
                collectionId,
                tokenId,
                request.randomizerEpoch,
                _randomWords
            )
        );
        if (derivedSeed == bytes32(0)) {
            revert ZeroDerivedSeed(_requestId);
        }

        request.state = RandomnessRequestState.Fulfilled;
        _decrementPendingRandomnessRequest(collectionId);
        request.fulfilledBlock = block.number;
        request.fulfilledTimestamp = block.timestamp;
        request.derivedSeed = derivedSeed;
        request.failureDataHash = bytes32(0);
    }

    function _confirmRandomnessFulfillment(uint256 _requestId) internal {
        RandomnessRequest storage request = randomnessRequests[_requestId];
        if (request.state == RandomnessRequestState.None) {
            revert UnknownRandomnessRequest(_requestId);
        }
        if (request.state != RandomnessRequestState.Fulfilled) {
            revert RandomnessRequestNotFulfilled(_requestId, request.state);
        }

        emit RandomnessFulfilled(
            _requestId, request.collectionId, request.tokenId, request.derivedSeed
        );
    }

    function _markRandomnessPostProcessingFailed(uint256 _requestId, bytes memory failureData)
        internal
    {
        RandomnessRequest storage request = randomnessRequests[_requestId];
        if (request.state == RandomnessRequestState.None) {
            revert UnknownRandomnessRequest(_requestId);
        }
        if (request.state != RandomnessRequestState.Fulfilled) {
            revert RandomnessRequestNotFulfilled(_requestId, request.state);
        }

        bytes32 failureDataHash = keccak256(failureData);
        request.state = RandomnessRequestState.FailedPostProcessing;
        request.failureDataHash = failureDataHash;

        emit RandomnessPostProcessingFailed(
            _requestId, request.collectionId, request.tokenId, request.derivedSeed, failureDataHash
        );
    }

    function _markRandomnessRequestStale(uint256 _requestId) internal {
        RandomnessRequest storage request = randomnessRequests[_requestId];
        if (request.state == RandomnessRequestState.None) {
            revert UnknownRandomnessRequest(_requestId);
        }
        if (request.state != RandomnessRequestState.Pending) {
            revert RandomnessRequestNotPending(_requestId, request.state);
        }

        request.state = RandomnessRequestState.Stale;
        _decrementPendingRandomnessRequest(request.collectionId);
        emit RandomnessRequestMarkedStale(
            _requestId,
            request.collectionId,
            request.tokenId,
            request.provider,
            request.randomizerEpoch
        );
    }

    function _decrementPendingRandomnessRequest(uint256 collectionId) private {
        pendingRandomnessRequestsByCollection[collectionId] =
            pendingRandomnessRequestsByCollection[collectionId] - 1;
        pendingRandomnessRequestCount = pendingRandomnessRequestCount - 1;
    }
}
