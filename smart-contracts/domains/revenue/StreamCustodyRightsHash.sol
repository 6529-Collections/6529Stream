// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/auctions/IStreamCustodyRightsAuction.sol";
import "../../interfaces/stream/revenue/StreamNativeCustodySettlementTypes.sol";
import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice New domains retain the full append-only activation; old custody preimages are unchanged.
library StreamCustodyRightsHash {
    function digest(address house, StreamCustodyRightsTypes.Authorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamCustodyRightsAllowCurrent"),
                keccak256("1"),
                block.chainid,
                house
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "CustodyRightsActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function configuration(address house, StreamCustodyRightsTypes.Activation memory a)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CUSTODY_RIGHTS_ALLOW_CURRENT_CONFIG_V1"),
                block.chainid,
                house,
                a.authorization,
                a.authorizationDigest
            )
        );
    }

    function readOptional(address house, bytes32 id)
        public
        view
        returns (StreamCustodyRightsTypes.Activation memory a)
    {
        if (IERC165(house).supportsInterface(type(IStreamCustodyRightsAuction).interfaceId)) {
            return IStreamCustodyRightsAuction(house).custodyRightsActivation(id);
        }
    }

    function requireLegacy(address house, bytes32 id) public view {
        if (readOptional(house, id).authorizationDigest != 0) {
            revert IStreamCustodyRightsAuction.CustodyRightsEntryRequired(id);
        }
    }

    function execution(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamCustodyRightsTypes.Activation memory a
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CUSTODY_RIGHTS_EXECUTION_V1"),
                block.chainid,
                recorder,
                house,
                f,
                a
            )
        );
    }

    function facts(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamCustodyRightsTypes.Activation memory a
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CUSTODY_RIGHTS_FACTS_V1"),
                block.chainid,
                recorder,
                house,
                f,
                a
            )
        );
    }

    function candidate(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamCustodyRightsTypes.Activation memory a,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes32 beneficiaryHash
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CUSTODY_RIGHTS_CANDIDATE_V1"),
                block.chainid,
                recorder,
                house,
                f,
                a,
                c,
                beneficiaryHash
            )
        );
    }
}
