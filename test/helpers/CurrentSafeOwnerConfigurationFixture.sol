// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackFixture.sol";
import "./OfficialSafeFixture.sol";

/// @notice Real upstream Safe owner changes joined to the original current paid mint and Artist owners.
/// @dev No Safe signer/handler substitutes; only inherited upstream entropy remains a service boundary.
abstract contract CurrentSafeOwnerConfigurationFixture is
    StreamCurrentStackFixture,
    OfficialSafeFixture
{
    OfficialSafe internal configurationArtist;
    OfficialSafe internal configurationBuyer;
    OfficialSafe internal contractOwner;
    uint256[] internal artistOwners;
    uint256[] internal buyerOwners;
    uint256[] internal innerOwners;
    bool internal nestedBuyer;
    bool internal safe150;
    bool internal safe130;
    uint256 internal constant CONFIGURATION_PRICE = 0.01 ether;
    uint256 internal constant REPLACEMENT_KEY = 0x5AFE999;

    struct SignedCall {
        address target;
        uint256 value;
        bytes data;
        uint8 operation;
        uint256 nonce;
        bytes32 hash;
        bytes signatures;
    }

    function _constructConfiguration(string memory version, bool nested) internal {
        safe150 = keccak256(bytes(version)) == keccak256("1.5.0");
        safe130 = keccak256(bytes(version)) == keccak256("1.3.0");
        nestedBuyer = nested;
        artistOwners.push(0x5AFE101);
        artistOwners.push(0x5AFE102);
        artistOwners.push(0x5AFE103);
        buyerOwners.push(0x5AFE201);
        buyerOwners.push(0x5AFE202);
        buyerOwners.push(0x5AFE203);
        innerOwners.push(0x5AFE301);
        innerOwners.push(0x5AFE302);
        innerOwners.push(0x5AFE303);
        SafeComponents memory components = deploySafeComponents(version);
        configurationArtist =
            createOfficialSafe(components, safeOwnerAddresses(artistOwners), 2, 652901);
        if (nested) {
            contractOwner =
                createOfficialSafe(components, safeOwnerAddresses(innerOwners), 2, 652903);
            address[] memory owners = new address[](2);
            owners[0] = address(contractOwner);
            owners[1] = vm.addr(buyerOwners[0]);
            configurationBuyer = createOfficialSafe(components, owners, 2, 652902);
        } else {
            configurationBuyer =
                createOfficialSafe(components, safeOwnerAddresses(buyerOwners), 2, 652902);
        }
        require(
            keccak256(bytes(configurationArtist.VERSION())) == keccak256(bytes(version))
                && keccak256(bytes(configurationBuyer.VERSION())) == keccak256(bytes(version)),
            "exact actual upstream versions"
        );
        if (nested) {
            require(
                keccak256(bytes(contractOwner.VERSION())) == keccak256(bytes(version)),
                "actual nested version"
            );
        }
        _deployCurrentStack(address(configurationArtist), vm.addr(PLATFORM_KEY));
        vm.deal(address(configurationBuyer), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(
            _first(artistOwners, 2), _messageHash(configurationArtist, abi.encode(digest))
        );
    }

    function _thresholdConfiguration(string memory version) internal {
        _constructConfiguration(version, false);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _configurationAuthorization();
        bytes memory data = _purchaseData(a, _first(artistOwners, 2));
        SignedCall memory oldNonce =
            _flatCall(configurationBuyer, buyerOwners, address(sale), a.price, data);
        require(
            oldNonce.signatures.length == 195, "stale nonce retains sufficient three-owner quorum"
        );
        _threshold(configurationBuyer, _first(buyerOwners, 2), 3);
        _refuse(configurationBuyer, oldNonce);
        _unminted(a);
        SignedCall memory oldQuorum =
            _flatCall(configurationBuyer, _first(buyerOwners, 2), address(sale), a.price, data);
        require(
            oldQuorum.nonce == configurationBuyer.nonce(),
            "fresh nonce isolates insufficient threshold"
        );
        _refuse(configurationBuyer, oldQuorum);
        _unminted(a);

        _threshold(configurationArtist, _first(artistOwners, 2), 3);
        SignedCall memory exact =
            _flatCall(configurationBuyer, buyerOwners, address(sale), a.price, data);
        bytes32 saved = keccak256(_envelope(exact));
        _refuse(configurationBuyer, exact);
        _unminted(a);
        // This is a real, threshold-authorized Artist Safe self-CALL. The buyer nonce is untouched.
        _threshold(configurationArtist, artistOwners, 2);
        require(
            keccak256(_envelope(exact)) == saved && configurationBuyer.nonce() == exact.nonce,
            "byte-identical buyer retry"
        );
        _fieldDenials(exact, a);
        _purchaseSuccess(exact, a);
        require(
            configurationBuyer.getThreshold() == 3 && configurationArtist.getThreshold() == 2,
            "final actual thresholds"
        );
        _zeroValueTransfer();
    }

    function _replacementConfiguration(string memory version) internal {
        _constructConfiguration(version, false);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _configurationAuthorization();
        bytes memory staleData = _purchaseData(a, _first(artistOwners, 2));
        SignedCall memory oldNonce = _flatCall(
            configurationBuyer, _first(buyerOwners, 2), address(sale), a.price, staleData
        );
        (T.PayoutDesignation memory payout, T.Authorization memory authorization) = _payoutProof();
        uint256[] memory staleBuyerKeys = _first(buyerOwners, 2);
        _replace(
            configurationArtist,
            _first(artistOwners, 2),
            vm.addr(artistOwners[0]),
            vm.addr(REPLACEMENT_KEY)
        );
        _replace(
            configurationBuyer, staleBuyerKeys, vm.addr(buyerOwners[0]), vm.addr(REPLACEMENT_KEY)
        );
        artistOwners[0] = REPLACEMENT_KEY;
        buyerOwners[0] = REPLACEMENT_KEY;
        _refuse(configurationBuyer, oldNonce);
        _refuse(
            configurationBuyer,
            _flatCall(configurationBuyer, staleBuyerKeys, address(sale), a.price, staleData)
        );
        _refuse(configurationBuyer, _buyerCall(address(sale), a.price, staleData));
        _unminted(a);
        bytes memory data = _purchaseData(a, _first(artistOwners, 2));
        SignedCall memory current = _buyerCall(address(sale), a.price, data);
        _fieldDenials(current, a);
        _purchaseSuccess(current, a);
        _zeroValueTransfer();
        _payoutRotation(payout, authorization);
    }

    function _nestedConfiguration(string memory version) internal {
        _constructConfiguration(version, true);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _configurationAuthorization();
        bytes memory data = _purchaseData(a, _first(artistOwners, 2));
        SignedCall memory exact = _buyerCall(address(sale), a.price, data);
        SignedCall memory wrong = _nestedCall(address(sale), a.price, data, true);
        _refuse(configurationBuyer, wrong);
        _unminted(a);
        bytes32 saved = keccak256(_envelope(exact));
        address removed = vm.addr(innerOwners[0]);
        uint256[] memory original = _first(innerOwners, 2);
        _success(
            contractOwner,
            _flatCall(
                contractOwner,
                original,
                address(contractOwner),
                0,
                abi.encodeWithSignature(
                    "removeOwner(address,address,uint256)",
                    _previousOwner(contractOwner, removed),
                    removed,
                    2
                )
            )
        );
        require(
            !_owner(contractOwner, removed) && contractOwner.getOwners().length == 2
                && contractOwner.getThreshold() == 2,
            "actual nested signer revoked"
        );
        _refuse(configurationBuyer, exact);
        _unminted(a);
        uint256[] memory remaining = new uint256[](2);
        remaining[0] = innerOwners[1];
        remaining[1] = innerOwners[2];
        _success(
            contractOwner,
            _flatCall(
                contractOwner,
                remaining,
                address(contractOwner),
                0,
                abi.encodeWithSignature("addOwnerWithThreshold(address,uint256)", removed, 2)
            )
        );
        require(
            _owner(contractOwner, removed) && contractOwner.getOwners().length == 3
                && contractOwner.nonce() == 2,
            "actual nested owner restored"
        );
        require(
            configurationBuyer.nonce() == 0 && keccak256(_envelope(exact)) == saved,
            "inner changes do not consume outer nonce"
        );
        _fieldDenials(exact, a);
        _purchaseSuccess(exact, a);
        _zeroValueTransfer();
        require(
            contractOwner.nonce() == 2,
            "contract signature validation consumes no inner transaction nonce"
        );
    }

    function _configurationAuthorization()
        internal
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamFixedPriceSaleAdapter.SaleAuthorization(
            1,
            PHASE,
            address(configurationBuyer),
            address(configurationBuyer),
            address(configurationArtist),
            profile,
            _nativePrimaryPolicyHash(),
            keccak256(TOKEN_DATA),
            keccak256("Safe configuration artwork"),
            manager.phasePolicyHash(1, PHASE),
            CONFIGURATION_PRICE,
            keccak256("Safe configuration paid nonce"),
            uint64(block.timestamp + 1 days),
            sale.signerEpoch()
        );
    }

    function _purchaseData(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a,
        uint256[] memory signers
    ) internal returns (bytes memory) {
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        return abi.encodeCall(
            sale.buy,
            (
                a,
                TOKEN_DATA,
                abi.encodePacked(r, s, v),
                safeThresholdSignature(
                    signers, _messageHash(configurationArtist, abi.encode(digest))
                )
            )
        );
    }

    function _threshold(OfficialSafe account, uint256[] memory signers, uint256 next) internal {
        bytes32 owners = keccak256(abi.encode(account.getOwners()));
        _success(
            account,
            _flatCall(
                account,
                signers,
                address(account),
                0,
                abi.encodeWithSignature("changeThreshold(uint256)", next)
            )
        );
        require(
            account.getThreshold() == next && keccak256(abi.encode(account.getOwners())) == owners,
            "real threshold-only transition"
        );
    }

    function _replace(OfficialSafe account, uint256[] memory signers, address prior, address next)
        internal
    {
        _success(
            account,
            _flatCall(
                account,
                signers,
                address(account),
                0,
                abi.encodeWithSignature(
                    "swapOwner(address,address,address)",
                    _previousOwner(account, prior),
                    prior,
                    next
                )
            )
        );
        require(
            !_owner(account, prior) && _owner(account, next) && account.getOwners().length == 3
                && account.getThreshold() == 2,
            "real owner replacement and old-owner revocation"
        );
    }

    function _owner(OfficialSafe account, address who) private view returns (bool) {
        address[] memory owners = account.getOwners();
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == who) return true;
        }
        return false;
    }

    function _previousOwner(OfficialSafe account, address who) private view returns (address) {
        address[] memory owners = account.getOwners();
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == who) return i == 0 ? address(1) : owners[i - 1];
        }
        revert("actual owner absent");
    }

    function _first(uint256[] memory all, uint256 count)
        private
        pure
        returns (uint256[] memory selected)
    {
        selected = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            selected[i] = all[i];
        }
    }

    function _domain(OfficialSafe account) private view returns (bytes32 domain) {
        domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
                block.chainid,
                address(account)
            )
        );
        require(account.domainSeparator() == domain, "literal original Safe domain");
    }

    function _messageHash(OfficialSafe account, bytes memory message)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                _domain(account),
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(message)))
            )
        );
    }

    function _transactionPreimage(OfficialSafe account, SignedCall memory c)
        private
        view
        returns (bytes memory preimage)
    {
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
                ),
                c.target,
                c.value,
                keccak256(c.data),
                c.operation,
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                address(0),
                c.nonce
            )
        );
        preimage = abi.encodePacked(hex"1901", _domain(account), body);
        require(
            keccak256(preimage)
                == account.getTransactionHash(
                    c.target, c.value, c.data, c.operation, 0, 0, 0, address(0), address(0), c.nonce
                ),
            "literal SafeTx field and nonce binding"
        );
    }

    function _flatCall(
        OfficialSafe account,
        uint256[] memory signers,
        address target,
        uint256 value,
        bytes memory data
    ) private returns (SignedCall memory c) {
        c.target = target;
        c.value = value;
        c.data = data;
        c.nonce = account.nonce();
        c.hash = keccak256(_transactionPreimage(account, c));
        c.signatures = safeThresholdSignature(signers, c.hash);
    }

    function _buyerCall(address target, uint256 value, bytes memory data)
        private
        returns (SignedCall memory)
    {
        return nestedBuyer
            ? _nestedCall(target, value, data, false)
            : _flatCall(
                configurationBuyer,
                _first(buyerOwners, configurationBuyer.getThreshold()),
                target,
                value,
                data
            );
    }

    function _nestedCall(address target, uint256 value, bytes memory data, bool wrongScheme)
        private
        returns (SignedCall memory c)
    {
        c.target = target;
        c.value = value;
        c.data = data;
        c.nonce = configurationBuyer.nonce();
        bytes memory preimage = _transactionPreimage(configurationBuyer, c);
        c.hash = keccak256(preimage);
        // Actual 1.3/1.4 validators pass the full preimage; 1.5 passes its bytes32 hash.
        bool hashValidator = wrongScheme ? !safe150 : safe150;
        bytes memory inner = safeThresholdSignature(
            _first(innerOwners, 2),
            _messageHash(contractOwner, hashValidator ? abi.encode(c.hash) : preimage)
        );
        bytes memory eoa = safeThresholdSignature(_first(buyerOwners, 1), c.hash);
        bytes memory header = abi.encodePacked(
            bytes32(uint256(uint160(address(contractOwner)))), bytes32(uint256(130)), uint8(0)
        );
        c.signatures = address(contractOwner) < vm.addr(buyerOwners[0])
            ? bytes.concat(header, eoa)
            : bytes.concat(eoa, header);
        c.signatures = bytes.concat(c.signatures, abi.encode(inner.length), inner);
    }

    function _envelope(SignedCall memory c) private pure returns (bytes memory) {
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                c.target,
                c.value,
                c.data,
                c.operation,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                c.signatures
            )
        );
    }

    function _refuse(OfficialSafe account, SignedCall memory c) private {
        uint256 nonce = account.nonce();
        uint256 balance = address(account).balance;
        bytes32 owners = keccak256(abi.encode(account.getOwners(), account.getThreshold()));
        bytes32 artistState = _artistOwnerState();
        (bool ok,) = address(account).call(_envelope(c));
        require(
            !ok && account.nonce() == nonce && address(account).balance == balance,
            "failed original Safe restores nonce and value"
        );
        require(
            owners == keccak256(abi.encode(account.getOwners(), account.getThreshold()))
                && artistState == _artistOwnerState(),
            "failure preserves actual owner configurations and all Artist states"
        );
    }

    function _success(OfficialSafe account, SignedCall memory c)
        private
        returns (Vm.Log[] memory logs)
    {
        require(
            account.nonce() == c.nonce && c.operation == 0, "original exact operation-zero nonce"
        );
        vm.recordLogs();
        (bool ok, bytes memory out) = address(account).call(_envelope(c));
        require(
            ok && out.length == 32 && abi.decode(out, (bool)) && account.nonce() == c.nonce + 1,
            "one exact official Safe execution"
        );
        logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(account) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) {
                if (safe130) {
                    require(
                        logs[i].topics.length == 1
                            && keccak256(logs[i].data) == keccak256(abi.encode(c.hash, uint256(0))),
                        "original Safe 1.3 unindexed transaction hash and zero refund"
                    );
                } else {
                    require(
                        logs[i].topics.length == 2 && logs[i].topics[1] == c.hash
                            && keccak256(logs[i].data) == keccak256(abi.encode(uint256(0))),
                        "original Safe 1.4/1.5 indexed transaction hash and zero refund"
                    );
                }
                ++count;
            }
        }
        require(count == 1, "one actual Safe success receipt");
    }

    function _fieldDenials(
        SignedCall memory original,
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a
    ) private {
        SignedCall memory changed = abi.decode(abi.encode(original), (SignedCall));
        changed.value = 0;
        _refuse(configurationBuyer, changed);
        _unminted(a);
        changed = abi.decode(abi.encode(original), (SignedCall));
        changed.operation = 1;
        _refuse(configurationBuyer, changed);
        _unminted(a);
        changed = abi.decode(abi.encode(original), (SignedCall));
        changed.data = bytes.concat(changed.data, hex"00");
        _refuse(configurationBuyer, changed);
        _unminted(a);
    }

    function _authorizationKey(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SALE_NONCE_V1"),
                block.chainid,
                address(sale),
                a.artist,
                a.nonce
            )
        );
    }

    function _counterKey() private view returns (bytes32) {
        bytes32 counter = keccak256("supply");
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                uint8(1),
                uint256(1),
                PHASE,
                counter
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                PHASE,
                counter,
                subject
            )
        );
    }

    function _unminted(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a) private view {
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.collectionMintedEver(1) == 0 && core.collectionNextSerial(1) == 1,
            "denied mint leaves original identity unallocated"
        );
        require(
            manager.nextOperationNonce() == 0 && ledger.counterValue(_counterKey()) == 0
                && !ledger.isManagerAuthorizationUsed(address(manager), _authorizationKey(a))
                && !sale.authorizationUsed(a.artist, a.nonce),
            "original mint and sale nonces unconsumed"
        );
        require(
            address(configurationBuyer).balance == 1 ether && wallet.balance == 0
                && sale.totalNativeProceeds() == 0 && revenueEscrow.totalOwed(address(0)) == 0
                && address(sale).balance == 0,
            "no retained payment or liability"
        );
        require(
            core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(1).exists
                && core.tokenData(1).length == 0 && core.coordinatorAtMint(1) == address(0)
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
                && entropy.pendingRequestCount() == 0 && provider.nextRequestId() == 1,
            "denied authorization leaves no prepared or entropy state"
        );
    }

    function _purchaseSuccess(
        SignedCall memory c,
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a
    ) private {
        Vm.Log[] memory logs = _success(configurationBuyer, c);
        _transferReceipt(logs, address(0), address(configurationBuyer));
        require(
            core.totalSupply() == 1 && core.lastAllocatedTokenId() == 1
                && core.collectionMintedEver(1) == 1 && core.collectionNextSerial(1) == 2
                && core.ownerOf(1) == address(configurationBuyer)
                && keccak256(core.tokenData(1)) == keccak256(TOKEN_DATA),
            "one actual current token at original buyer"
        );
        require(
            manager.nextOperationNonce() == 1 && ledger.counterValue(_counterKey()) == 1
                && ledger.isManagerAuthorizationUsed(address(manager), _authorizationKey(a))
                && sale.authorizationUsed(a.artist, a.nonce),
            "original independent authorization and counter consumed once"
        );
        require(
            wallet.balance == a.price && sale.totalNativeProceeds() == a.price
                && address(configurationBuyer).balance == 1 ether - a.price
                && address(sale).balance == 0 && revenueEscrow.totalOwed(address(0)) == 0,
            "exact payable CALL settled to original split"
        );
        require(
            core.coordinatorAtMint(1) == address(entropy)
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED
                && entropy.pendingRequestCount() == 0 && provider.nextRequestId() == 1,
            "actual deferred entropy registered without request"
        );
        _refuse(configurationBuyer, c);
        require(
            core.totalSupply() == 1 && wallet.balance == a.price
                && manager.nextOperationNonce() == 1,
            "successful exact payload cannot replay"
        );
    }

    function _zeroValueTransfer() private {
        uint256 balance = address(configurationBuyer).balance;
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,bytes)",
            address(configurationBuyer),
            address(configurationArtist),
            uint256(1),
            bytes("same operation-zero custody")
        );
        SignedCall memory c = _buyerCall(address(core), 0, data);
        _transferReceipt(
            _success(configurationBuyer, c),
            address(configurationBuyer),
            address(configurationArtist)
        );
        require(
            core.ownerOf(1) == address(configurationArtist)
                && address(configurationBuyer).balance == balance
                && wallet.balance == CONFIGURATION_PRICE,
            "zero-value CALL changes custody without changing settled payment"
        );
        _refuse(configurationBuyer, c);
    }

    function _transferReceipt(Vm.Log[] memory logs, address from, address to) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(core) && logs[i].topics.length == 4
                    && logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(uint160(from)))
                        && logs[i].topics[2] == bytes32(uint256(uint160(to)))
                        && logs[i].topics[3] == bytes32(uint256(1)) && logs[i].data.length == 0,
                    "exact original custody receipt"
                );
                ++count;
            }
        }
        require(count == 1, "one original token Transfer");
    }

    function _artistOwnerState() private view returns (bytes32) {
        T.Snapshot[7] memory states;
        for (uint256 i; i < 7; ++i) {
            states[i] = IStreamArtistOwner(artistSuite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(states));
    }

    function _payoutProof()
        private
        returns (T.PayoutDesignation memory p, T.Authorization memory a)
    {
        (, bytes32 prior) = IStreamArtistPayoutOwner(artistSuite.owners[5])
            .artistPayoutAccount(fixtureArtistId);
        p = T.PayoutDesignation(fixtureArtistId, address(configurationBuyer), prior);
        a.nonce =
        IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        a.time = uint64(block.timestamp);
        a.signature = _artistProof(_payoutDigest(p, a));
    }

    function _payoutDigest(T.PayoutDesignation memory p, T.Authorization memory a)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(artists)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistPayoutDesignation(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt)"
                ),
                p.artistId,
                p.payoutAccount,
                p.previousDesignationRecordHash,
                a.nonce,
                a.time
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _payoutRotation(T.PayoutDesignation memory p, T.Authorization memory a) private {
        bytes32 before_ = _artistOwnerState();
        (bool ok,) = address(artists).call(abi.encodeCall(artists.recordPayoutDesignation, (p, a)));
        require(
            !ok && _artistOwnerState() == before_
                && !IStreamArtistIdentityOwner(artistSuite.owners[2])
                    .nonceUsed(fixtureArtistId, a.nonce),
            "revoked old Artist proof preserves every owner and original nonce"
        );
        a.signature = _artistProof(_payoutDigest(p, a));
        uint256 safeNonce = configurationArtist.nonce();
        vm.recordLogs();
        artists.recordPayoutDesignation(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1"),
                block.chainid,
                address(artists),
                p.artistId,
                p.payoutAccount,
                p.previousDesignationRecordHash,
                address(configurationArtist),
                uint8(1),
                a.nonce,
                a.time
            )
        );
        IStreamArtistPayoutOwner owner = IStreamArtistPayoutOwner(artistSuite.owners[5]);
        (address account, bytes32 record) = owner.artistPayoutAccount(fixtureArtistId);
        require(
            account == p.payoutAccount && record == expected
                && keccak256(abi.encode(owner.designationRecord(record)))
                    == keccak256(abi.encode(p))
                && IStreamArtistIdentityOwner(artistSuite.owners[2])
                    .nonceUsed(fixtureArtistId, a.nonce)
                && configurationArtist.nonce() == safeNonce,
            "exact original Artist record and separate unordered nonce, no Safe transaction"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(owner) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistPayoutDesignationRecorded(uint16,bytes32,address,address,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == p.artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(p.payoutAccount)))
                        && logs[i].topics[3]
                            == bytes32(uint256(uint160(address(configurationArtist))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    p.previousDesignationRecordHash,
                                    uint8(1),
                                    a.nonce,
                                    a.time,
                                    expected
                                )
                            ),
                    "exact original payout receipt"
                );
                ++count;
            }
        }
        require(count == 1, "one actual payout owner receipt");
        before_ = _artistOwnerState();
        (ok,) = address(artists).call(abi.encodeCall(artists.recordPayoutDesignation, (p, a)));
        require(
            !ok && _artistOwnerState() == before_, "payout replay preserves all retained history"
        );
    }
}
