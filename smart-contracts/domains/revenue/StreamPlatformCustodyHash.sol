// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/auctions/IStreamPlatformCustodyAuction.sol";
import "../../interfaces/stream/auctions/IStreamPlatformNativeRightsAuction.sol";
import "../../interfaces/stream/auctions/IStreamNativeRightsAuction.sol";

library StreamPlatformCustodyHash {
    function acquisitionFromCalldata(bytes calldata input) public view returns (bytes32) {
        require(
            bytes4(input[:4])
                == IStreamPlatformCustodyAuction.platformCustodyAcquisitionDigest.selector
        );
        return acquisition(
            abi.decode(input[4:], (IStreamPlatformCustodyAuction.PlatformCustodyAuthorization))
        );
    }

    function acquisition(IStreamPlatformCustodyAuction.PlatformCustodyAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPlatformPreparedCustodyAuction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PlatformPreparedCustodyAcquisition(bytes32 configHash,bytes32 declarationHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function facts(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        bytes32 declaration,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_CUSTODY_FACTS_V1"),
                block.chainid,
                recorder,
                house,
                f,
                declaration,
                original
            )
        );
    }

    function candidate(
        address recorder,
        address house,
        StreamNativeCustodySettlementTypes.Facts memory f,
        bytes32 declaration,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes32 beneficiaries
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_CUSTODY_CANDIDATE_V1"),
                block.chainid,
                recorder,
                house,
                f,
                declaration,
                original,
                c,
                beneficiaries
            )
        );
    }
}
