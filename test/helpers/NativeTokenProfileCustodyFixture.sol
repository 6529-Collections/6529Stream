// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NativeCustodyAuctionFixture.sol";

/// @dev Only the Artist semantics are typed; token identity, rights, payment and custody are real.
contract TokenProfileCustodyArtist is NativeAuctionArtist {
    mapping(bytes32 => bool) public approvals;
    address public fundingTrigger;
    bool public rejectAfterFunding;
    constructor(address c, address m) NativeAuctionArtist(c, m) { }

    function approveToken(uint256 collection, uint256 token, bytes32 hash, bool yes) external {
        approvals[keccak256(abi.encode(collection, token, hash))] = yes;
    }

    function fundingFault(address target, bool enabled) external {
        fundingTrigger = target;
        rejectAfterFunding = enabled;
    }

    function requireEconomicsConsent(
        uint256 collection,
        bytes32 class_,
        uint8 scope,
        uint256 id,
        bytes32 hash
    ) external view override {
        require(consent, "artist economics");
        if (scope == 2) {
            require(
                class_ == keccak256("PRIMARY_SALE")
                    && approvals[keccak256(abi.encode(collection, id, hash))],
                "exact token consent"
            );
            require(!rejectAfterFunding || fundingTrigger.balance == 0, "late token consent");
        }
    }
}

abstract contract NativeTokenProfileCustodyFixture is NativeCustodyAuctionFixture {
    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        return new TokenProfileCustodyArtist(address(core), address(manager));
    }

    function _tokenArtist() internal view returns (TokenProfileCustodyArtist) {
        return TokenProfileCustodyArtist(address(artists));
    }

    function _tokenProfile(address recipient)
        internal
        returns (bytes32 selected, address destination)
    {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(recipient, 1000000, keccak256("artist"));
        return factory.createProfile(entries, keccak256(abi.encode("token profile", recipient)));
    }

    function _tokenAssignment(uint256 token, bytes32 selected) internal returns (bytes32 hash) {
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            resolver.previewArtistPrimaryAssignmentForScope(1, 2, token, selected, 0, false);
        hash = fact.assignmentHash;
        _tokenArtist().approveToken(1, token, hash, true);
        require(
            resolver.setPrimaryProfileAssignment(CLASS, 2, token, selected, 0) == hash,
            "actual scope2 assignment"
        );
    }

    function _tokenPolicy(uint256 token, bytes32 selected, address destination, bytes32 hash)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                token,
                bytes32(0),
                selected,
                destination,
                hash
            )
        );
    }

    function _tokenAuthorization(bytes32 id, bytes32 nonce)
        internal
        view
        returns (StreamTokenProfileCustodyTypes.Authorization memory a)
    {
        IStreamNativeEnglishAuction.Auction memory sale = house.auction(id);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory selected =
            resolver.resolvePrimaryAssignment(1, sale.tokenId, CLASS);
        a = StreamTokenProfileCustodyTypes.Authorization(
            id,
            sale.configHash,
            keccak256(abi.encode(house.custodyOrigin(id))),
            sale.tokenId,
            selected.assignmentHash,
            _tokenPolicy(
                sale.tokenId,
                selected.profileId,
                factory.walletFor(selected.profileId),
                selected.assignmentHash
            ),
            1,
            artists.artist(),
            nonce,
            this.custodyFixtureTime() + 1000
        );
    }

    function _literalActivationDigest(
        address host,
        StreamTokenProfileCustodyTypes.Authorization memory a
    ) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamTokenProfileCustodyAllowCurrent"),
                keccak256("1"),
                block.chainid,
                host
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "TokenProfileCustodyActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)"
                ),
                a.auctionId,
                a.baseConfigHash,
                a.originHash,
                a.tokenId,
                a.assignmentHash,
                a.primaryPolicyHash,
                a.primaryPolicyMode,
                a.artist,
                a.nonce,
                a.deadline
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, structHash));
    }

    function _activationCall(StreamTokenProfileCustodyTypes.Authorization memory a)
        internal
        returns (bytes memory)
    {
        bytes32 digest = _literalActivationDigest(address(house), a);
        require(digest == house.tokenProfileCustodyDigest(a), "independent typed activation");
        return abi.encodeCall(
            house.activateTokenProfileCustody,
            (a, _custodyProof(AUCTION_PLATFORM_KEY, digest), _custodyProof(SIGNER_KEY, digest))
        );
    }

    function _activateToken(bytes32 id, bytes32 nonce)
        internal
        returns (StreamTokenProfileCustodyTypes.Activation memory a)
    {
        bytes memory data = _activationCall(_tokenAuthorization(id, nonce));
        (bool ok,) = address(house).call(data);
        require(ok, "token activation");
        a = house.tokenProfileCustodyActivation(id);
        require(
            a.authorizationDigest != 0
                && a.effectiveConfigHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_ALLOW_CURRENT_CONFIG_V1"),
                            block.chainid,
                            address(house),
                            a.authorization,
                            a.authorizationDigest
                        )
                    ),
            "full effective configuration"
        );
    }

    function _bidToken(bytes32 id, address who, uint256 amount) internal {
        vm.deal(who, 1 ether);
        vm.prank(who);
        house.bidTokenProfileCustody{ value: amount }(id, address(0));
        IStreamNativeEnglishAuction.WinningBid memory w = house.auction(id).winner;
        require(
            w.payer == who && w.executor == who && w.deliverTo == who && w.amount == amount
                && w.revealFee == 0,
            "actual token-profile zero-fee bid"
        );
    }

    function _tokenSafeCall(
        OfficialSafe safe,
        uint256[] memory keys,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        bytes32 hash = safe.getTransactionHash(
            address(house), value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                value,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, hash)
            )
        );
    }
}
