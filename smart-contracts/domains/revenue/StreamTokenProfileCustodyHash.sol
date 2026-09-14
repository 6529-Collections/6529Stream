// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/auctions/IStreamTokenProfileCustodyAuction.sol";
import "../../interfaces/stream/revenue/StreamNativeCustodySettlementTypes.sol";
import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice New domains retain the full append-only activation; old custody preimages are unchanged.
library StreamTokenProfileCustodyHash {
    function digest(address house, StreamTokenProfileCustodyTypes.Authorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamTokenProfileCustodyAllowCurrent"),
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
                            "TokenProfileCustodyActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function configuration(address house, StreamTokenProfileCustodyTypes.Activation memory a)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_ALLOW_CURRENT_CONFIG_V1"),
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
        returns (StreamTokenProfileCustodyTypes.Activation memory a)
    {
        if (IERC165(house).supportsInterface(type(IStreamTokenProfileCustodyAuction).interfaceId)) {
            return IStreamTokenProfileCustodyAuction(house).tokenProfileCustodyActivation(id);
        }
    }

    function requireLegacy(address house, bytes32 id) public view {
        if (readOptional(house, id).authorizationDigest != 0) {
            revert IStreamTokenProfileCustodyAuction.TokenProfileCustodyEntryRequired(id);
        }
    }

    function execution(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamTokenProfileCustodyTypes.Activation memory a
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_EXECUTION_V1"),
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
        StreamTokenProfileCustodyTypes.Activation memory a
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_FACTS_V1"),
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
        StreamTokenProfileCustodyTypes.Activation memory a,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_CANDIDATE_V1"),
                block.chainid,
                recorder,
                house,
                f,
                a,
                c
            )
        );
    }
}
