// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationFacts.sol";
import "./StreamArtistDisputeReadEncoding.sol";

library StreamArtistRepudiationReadEncoding {
    function read(address host, address coordinator, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        T.SuiteConfiguration memory s = IStreamDisputeSuite(coordinator).suiteConfiguration();
        if (s.registry != host) revert T.InvalidBinding();
        bytes4 sel = bytes4(data[:4]);
        if (sel == IStreamArtistAttributionRepudiation.pendingRepudiation.selector) {
            (uint64 g, uint64 t, bytes32 h) =
                StreamArtistRepudiationFacts.pending(s, abi.decode(data[4:], (uint256)));
            return abi.encode(g, t, h);
        }
        if (sel == IStreamArtistAttributionRepudiation.activeRepudiationCount.selector) {
            return
                abi.encode(
                    StreamArtistRepudiationFacts.activeCount(s, abi.decode(data[4:], (bytes32)))
                );
        }
        if (sel == IStreamArtistAttributionRepudiation.attributionRepudiationRecord.selector) {
            return abi.encode(
                IStreamArtistRepudiationOwner(s.owners[4])
                    .attributionRepudiationRecord(abi.decode(data[4:], (bytes32)))
            );
        }
        if (sel == IStreamArtistAttributionRepudiation.attributionRepudiationTerminal.selector) {
            return abi.encode(
                IStreamArtistRepudiationOwner(s.owners[4])
                    .attributionRepudiationTerminal(abi.decode(data[4:], (bytes32)))
            );
        }
        if (sel == IStreamArtistAttributionRepudiation.attributionRepudiationDigest.selector) {
            (AD.Filing memory p, T.Authorization memory a) =
                abi.decode(data[4:], (AD.Filing, T.Authorization));
            return abi.encode(
                StreamArtistRepudiationHashes.digest(
                    StreamArtistHashes.Environment(block.chainid, host, s.core, s.mintManager), p, a
                )
            );
        }
        revert T.InvalidRecord();
    }
}
