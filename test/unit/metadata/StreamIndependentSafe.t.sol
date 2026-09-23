// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionAttestations.t.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract StreamIndependentSafeTest is IndependentAttestationTestBase, OfficialSafeFixture {
    function _safe() private returns (OfficialSafe account, uint256[] memory keys) {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 301;
        owners[1] = 302;
        owners[2] = 303;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 721);
        keys = new uint256[](2);
        keys[0] = owners[0];
        keys[1] = owners[1];
    }

    function testActualSafeDirectWriteAll48ReadsAndNonceRevocation() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(account), 12);
        require(
            executeSafe(
                account,
                keys,
                address(host),
                0,
                abi.encodeCall(host.recordIndependentPreservation, (subject, r, bytes(""))),
                0
            ),
            "Safe direct write"
        );
        bytes32 hash =
            host.latestCollectionRecordHashFor(1, r.recordType, r.subjectId, address(account));
        (, IStreamCollectionAttestations.Receipt memory receipt) = host.collectionRecord(hash);
        require(hash != 0 && receipt.attestor == address(account), "Safe attributed");
        bytes[] memory reads = _reads(subject, r, hash);
        uint256 safeNonce = account.nonce();
        for (uint256 i; i < reads.length; ++i) {
            vm.prank(address(account));
            (bool ok, bytes memory result) = address(host).staticcall(reads[i]);
            require(ok && result.length != 0, "Safe caller result");
            require(
                executeSafe(account, keys, address(host), 0, reads[i], 0), "actual threshold read"
            );
        }
        require(
            account.nonce() == safeNonce + 48 && host.payloadPointerCount(1) == 2,
            "all reads no record mutation"
        );
        require(
            executeSafe(
                account,
                keys,
                address(host),
                0,
                abi.encodeCall(host.revokeIndependentAttestorNonce, (uint256(13))),
                0
            ),
            "Safe direct revoke"
        );
        require(host.isIndependentAttestorNonceUsed(address(account), 13), "Safe nonce void");
        bytes32 id = host.GGP_METADATA_ERC1271_VERIFY_GAS();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.rejectDirectSafeRaise(account, keys, id);
        require(host.gasParameter(id) == 150000, "Safe does not impersonate Executor");
    }

    function rejectDirectSafeRaise(OfficialSafe account, uint256[] calldata keys, bytes32 id)
        external
    {
        require(msg.sender == address(this), "test wrapper only");
        executeSafe(
            account,
            keys,
            address(host),
            0,
            abi.encodeCall(host.raiseGasParameter, (id, uint256(300000))),
            0
        );
    }

    function testActualSafeRelayedRecordAndRevocationUse150kCapOwnerCannotImpersonateSafe() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(address(account), 21);
        vm.prank(vm.addr(keys[0]));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.InvalidIndependentSignature.selector, address(account)
            )
        );
        host.recordIndependentPreservation(subject, r, "");
        bytes32 digest = host.independentRecordDigest(r);
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
        safeVm.cool(address(account));
        bytes32 hash = host.recordIndependentPreservation(subject, r, signature);
        (IStreamPreservationRecords.CollectionRecord memory record,) = host.collectionRecord(hash);
        require(
            record.signatureScheme == keccak256("ERC1271") && account.nonce() == 0,
            "relayed signature no Safe transaction"
        );
        r.nonce = 22;
        digest = host.independentRevocationDigest(address(account), r.nonce, r.deadline);
        signature = safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
        host.revokeIndependentAttestorNonceFor(address(account), r.nonce, r.deadline, signature);
        require(
            host.isIndependentAttestorNonceUsed(address(account), 22), "Safe signed nonce revoke"
        );
    }

    function testDelegatedEOAOwnKeyStillWritesAndRevokesWithExactOriginalDomain() public {
        vm.etch(signer, abi.encodePacked(hex"ef0100", address(0x123456)));
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(signer, 91);
        host.recordIndependentPreservation(subject, r, _sign(host.independentRecordDigest(r)));
        host.revokeIndependentAttestorNonceFor(
            signer, 92, r.deadline, _sign(host.independentRevocationDigest(signer, 92, r.deadline))
        );
        require(
            host.isIndependentAttestorNonceUsed(signer, 91)
                && host.isIndependentAttestorNonceUsed(signer, 92),
            "own key continuity"
        );
    }

    function _reads(
        IStreamCollectionAttestations.Subject memory subject,
        IStreamCollectionAttestations.IndependentRecord memory r,
        bytes32 hash
    ) private view returns (bytes[] memory calls) {
        string[30] memory noArgs = [
            "DEPENDENCY_READ_GAS()",
            "FAILURE_CLASS_FAIL_CLOSED_PRECHECK()",
            "FAILURE_CLASS_FORWARDING_CAP()",
            "FAILURE_CLASS_MIN_GAS_GATE()",
            "FAILURE_CLASS_NONE()",
            "GAS_PARAMETER_SCHEMA_VERSION()",
            "GGP_METADATA_ERC1271_VERIFY_GAS()",
            "MAX_RECORD_PAYLOAD_BYTES()",
            "MAX_SIGNATURE_BUNDLE_BYTES()",
            "MAX_SIGNATURE_BYTES()",
            "METADATA_ERC1271_VERIFY_GAS_FLOOR()",
            "STREAM_INDEPENDENT_PRESERVATION_REVOCATION_TYPEHASH()",
            "STREAM_INDEPENDENT_PRESERVATION_TYPEHASH()",
            "chunkStore()",
            "chunkStoreCodeHash()",
            "core()",
            "coreCodeHash()",
            "eip712Domain()",
            "gasParameterIds()",
            "governanceAuthority()",
            "schemaRegistry()",
            "schemaRegistryCodeHash()",
            "streamModuleCodeHash()",
            "streamModuleDeploymentManifestHash()",
            "streamModuleInterfaceId()",
            "streamModuleManifest()",
            "streamModuleSchemaHash()",
            "streamModuleSupersedes()",
            "streamModuleType()",
            "streamModuleVersion()"
        ];
        calls = new bytes[](48);
        uint256 i;
        for (; i < noArgs.length; ++i) {
            calls[i] = abi.encodeWithSignature(noArgs[i]);
        }
        calls[i++] = abi.encodeCall(host.collectionRecord, (hash));
        calls[i++] = abi.encodeCall(host.collectionRecordPayload, (1, r.recordType, r.subjectId));
        calls[i++] = abi.encodeCall(host.deriveSubject, (subject));
        calls[i++] = abi.encodeCall(host.gasParameter, (host.DEPENDENCY_READ_GAS()));
        calls[i++] = abi.encodeCall(host.gasParameterInfo, (host.GGP_METADATA_ERC1271_VERIFY_GAS()));
        calls[i++] = abi.encodeCall(host.independentRecordDigest, (r));
        calls[i++] =
            abi.encodeCall(host.independentRevocationDigest, (r.attestor, r.nonce, r.deadline));
        calls[i++] = abi.encodeCall(host.isIndependentAttestorNonceUsed, (r.attestor, r.nonce));
        calls[i++] = abi.encodeCall(host.isIndependentRecordType, (r.recordType));
        calls[i++] = abi.encodeCall(
            host.latestCollectionRecordHashFor, (1, r.recordType, r.subjectId, r.attestor)
        );
        calls[i++] = abi.encodeCall(host.payloadPointerAt, (1, 0));
        calls[i++] = abi.encodeCall(host.payloadPointerCount, (1));
        calls[i++] = abi.encodeCall(host.recordChainHash, (1, r.recordType));
        calls[i++] = abi.encodeCall(host.recordHashAt, (1, r.recordType, 0));
        calls[i++] = abi.encodeCall(host.recordPayload, (hash));
        calls[i++] = abi.encodeCall(host.recordSignatureBundle, (hash));
        calls[i++] = abi.encodeCall(host.recordSubject, (hash));
        calls[i++] = abi.encodeCall(
            host.supportsInterface, (type(IStreamCollectionAttestations).interfaceId)
        );
        require(i == 48, "complete read inventory");
    }
}
