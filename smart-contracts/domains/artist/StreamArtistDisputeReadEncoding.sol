// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeAdmission.sol";

interface IStreamDisputeSuite {
    function suiteConfiguration() external view returns (T.SuiteConfiguration memory);
}

/// @notice Fixed stateless facade read codec. Every owner/authority stays in the immutable suite.
library StreamArtistDisputeReadEncoding {
    function read(address host, address coordinator, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        T.SuiteConfiguration memory s = IStreamDisputeSuite(coordinator).suiteConfiguration();
        if (s.registry != host) revert T.InvalidBinding();
        bytes4 sel = bytes4(data[:4]);
        if (sel == IStreamArtistAttributionDisputes.attributionDispute.selector) {
            (uint256 id, uint64 gen) = abi.decode(data[4:], (uint256, uint64));
            return abi.encode(
                IStreamArtistAttributionDisputesOwner(s.owners[4]).attributionDispute(id, gen)
            );
        }
        if (sel == IStreamArtistAttributionDisputes.attributionDisputeRecord.selector) {
            return abi.encode(
                IStreamArtistAttributionDisputesOwner(s.owners[4])
                    .attributionDisputeRecord(abi.decode(data[4:], (bytes32)))
            );
        }
        if (sel == IStreamArtistAttributionDisputes.attributionDisputeResolution.selector) {
            return abi.encode(
                IStreamArtistAttributionDisputesOwner(s.owners[4])
                    .attributionDisputeResolution(abi.decode(data[4:], (bytes32)))
            );
        }
        if (sel == IStreamArtistAttributionDisputes.attributionDisputeDigest.selector) {
            (AD.Filing memory p, T.Authorization memory a) =
                abi.decode(data[4:], (AD.Filing, T.Authorization));
            return abi.encode(
                StreamArtistDisputeHashes.digest(
                    StreamArtistHashes.Environment(block.chainid, host, s.core, s.mintManager), p, a
                )
            );
        }
        if (sel == IStreamArtistAttributionDisputes.attributionDisputeOpeningContext.selector) {
            return abi.encode(
                StreamArtistDisputeAdmission.openingContext(s, abi.decode(data[4:], (AD.Filing)))
            );
        }
        if (sel == IStreamArtistAttributionDisputes.attributionDisputeResolutionContext.selector) {
            return abi.encode(
                StreamArtistDisputeAdmission.resolutionContext(
                    s, abi.decode(data[4:], (AD.ResolutionRequest))
                )
            );
        }
        revert T.InvalidRecord();
    }
}
