// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Bounded historical route diagnostics over the calling registry's exact stored component list.
/// @dev The host supplies only its immutable discovery and current governed cap. No current Core selection gate is added.
library StreamFinalityDiagnostics {
    function matches(
        StreamFinalityComponentExpectation[] storage stored,
        StreamFinalityScope memory scope,
        bytes32 componentsHash,
        address discovery,
        uint256 cap
    ) public view returns (bool result) {
        (result,,) = _diagnoseSlice(_sliceComponents(stored, 0, stored.length), scope, cap);
        if (result) {
            result = _diagnosticDiscoveryMatches(scope, stored, componentsHash, discovery, cap);
        }
    }

    function range(
        StreamFinalityComponentExpectation[] storage stored,
        StreamFinalityScope memory scope,
        uint256 start,
        uint256 limit,
        uint256 cap
    )
        public
        view
        returns (
            bool rangeMatches,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        uint256 count = stored.length;
        uint256 from = start > count ? count : start;
        nextStart = limit >= count - from ? count : from + limit;
        (rangeMatches, expectedRangeHash, observedRangeHash) =
            _diagnoseSlice(_sliceComponents(stored, from, nextStart - from), scope, cap);
    }

    function _diagnosticDiscoveryMatches(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] storage expected,
        bytes32 expectedHash,
        address discovery,
        uint256 cap
    ) private view returns (bool) {
        bytes memory countCallData;
        bytes memory hashCallData;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            countCallData = abi.encodeWithSelector(
                IStreamArtworkFinalityDiscovery.finalityComponentCount.selector, scope.collectionId
            );
            hashCallData = abi.encodeWithSelector(
                IStreamArtworkFinalityDiscovery.finalityDiscoveryHash.selector, scope.collectionId
            );
        } else {
            countCallData = abi.encodeWithSelector(
                IStreamArtworkScopedFinalityDiscovery.finalityComponentCountForScope.selector, scope
            );
            hashCallData = abi.encodeWithSelector(
                IStreamArtworkScopedFinalityDiscovery.finalityDiscoveryHashForScope.selector, scope
            );
        }

        (bool countReadable, bytes32 discoveredCount) =
            _readDiscoveryWord(discovery, countCallData, cap);
        uint256 expectedCount = expected.length;
        if (!countReadable || uint256(discoveredCount) != expectedCount) {
            return false;
        }
        (bool hashReadable, bytes32 discoveredHash) =
            _readDiscoveryWord(discovery, hashCallData, cap);
        if (!hashReadable || discoveredHash != expectedHash) {
            return false;
        }
        for (uint256 i = 0; i < expectedCount; i++) {
            bytes memory componentCallData;
            if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
                componentCallData = abi.encodeWithSelector(
                    IStreamArtworkFinalityDiscovery.finalityComponentAt.selector,
                    scope.collectionId,
                    i
                );
            } else {
                componentCallData = abi.encodeWithSelector(
                    IStreamArtworkScopedFinalityDiscovery.finalityComponentAtForScope.selector,
                    scope,
                    i
                );
            }
            (
                bool componentReadable,
                StreamFinalityComponentExpectation memory discoveredComponent
            ) = _readDiscoveryComponent(discovery, componentCallData, cap);
            if (
                !componentReadable
                    || keccak256(abi.encode(discoveredComponent))
                        != keccak256(abi.encode(expected[i]))
            ) {
                return false;
            }
        }
        return true;
    }

    function _readDiscoveryWord(address discovery, bytes memory callData, uint256 gasCap)
        private
        view
        returns (bool readable, bytes32 value)
    {
        return StreamFinalityComponentSet.observeDiscoveryWord(discovery, callData, gasCap);
    }

    function _readDiscoveryComponent(address discovery, bytes memory callData, uint256 gasCap)
        private
        view
        returns (bool readable, StreamFinalityComponentExpectation memory component)
    {
        return StreamFinalityComponentSet.observeDiscoveryComponent(discovery, callData, gasCap);
    }

    function _componentCallData(StreamFinalityScope memory scope)
        private
        pure
        returns (bytes memory)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return abi.encodeWithSelector(
                IStreamArtworkFinalityComponent.finalityState.selector, scope.collectionId
            );
        }
        return abi.encodeWithSelector(
            IStreamArtworkScopedFinalityComponent.finalityStateForScope.selector, scope
        );
    }

    function _diagnoseSlice(
        StreamFinalityComponentExpectation[] memory slice,
        StreamFinalityScope memory scope,
        uint256 cap
    ) private view returns (bool matches, bytes32 expectedHash, bytes32 observedHash) {
        return StreamFinalityComponentSet.diagnoseRange(
            slice,
            _componentCallData(scope),
            cap,
            StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1
        );
    }

    function _sliceComponents(
        StreamFinalityComponentExpectation[] storage stored,
        uint256 start,
        uint256 limit
    ) private view returns (StreamFinalityComponentExpectation[] memory out) {
        uint256 count = stored.length;
        if (start >= count || limit == 0) {
            return new StreamFinalityComponentExpectation[](0);
        }
        uint256 end = limit >= count - start ? count : start + limit;
        out = new StreamFinalityComponentExpectation[](end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = stored[i];
        }
    }
}
