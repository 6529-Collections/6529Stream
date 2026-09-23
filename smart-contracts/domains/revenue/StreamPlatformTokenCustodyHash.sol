// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/auctions/IStreamPlatformTokenCustodyAuction.sol";
import "../../interfaces/stream/auctions/IStreamPlatformNativeRightsAuction.sol";
import "../../interfaces/stream/auctions/IStreamNativeRightsAuction.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/revenue/StreamNativeCustodySettlementTypes.sol";

library StreamPlatformTokenCustodyHash {
    function digest(address house, StreamPlatformTokenCustodyTypes.Authorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPlatformTokenCustodyRights"),
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
                            "PlatformTokenCustodyRights(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 declarationHash,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function configuration(address house, StreamPlatformTokenCustodyTypes.Activation memory a)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_ALLOW_CURRENT_CONFIG_V1"),
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
        returns (StreamPlatformTokenCustodyTypes.Activation memory a)
    {
        if (IERC165(house).supportsInterface(type(IStreamPlatformTokenCustodyAuction).interfaceId)) return IStreamPlatformTokenCustodyAuction(
                house
            ).platformTokenCustodyActivation(id);
    }

    function requireLegacy(address house, bytes32 id) public view {
        if (readOptional(house, id).authorizationDigest != 0) {
            revert IStreamPlatformTokenCustodyAuction.PlatformTokenCustodyEntryRequired(id);
        }
    }

    function facts(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamPlatformTokenCustodyTypes.Activation memory activation,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_FACTS_V1"),
                block.chainid,
                recorder,
                house,
                f,
                activation,
                original
            )
        );
    }

    function candidate(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamPlatformTokenCustodyTypes.Activation memory activation,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes32 beneficiaries
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_CANDIDATE_V1"),
                block.chainid,
                recorder,
                house,
                f,
                activation,
                original,
                c,
                beneficiaries
            )
        );
    }
}
