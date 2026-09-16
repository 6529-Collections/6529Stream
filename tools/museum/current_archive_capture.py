"""Actual isolated current-stack ARCHIVE_SEMANTIC_EXPORT fixture runner.

The source remains the independently recorded typed-account capture.  The
later archive publication is retained as evidence about the derived export and
is never added back to that source state.
"""

from pathlib import Path

from .archive_publication import (
    AUTHORITY_NAMES, JCS, configure_archive_lane, evidence_bytes,
    publish_archive_export,
)
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array
from .current_authority_capture import (
    CurrentAuthorityFixture, configure_fixture, configure_parser,
    prepare_arguments,
)
from .current_museum_capture import (
    CurrentMuseumFixture, capture as capture_current, main as run_main,
)
from .current_rights_capture import CurrentRightsFixture
from .independent_wire import ZERO, ZERO_ADDRESS, require
from .package import write_package
from .semantic_export import (
    MANIFEST_PATH, NAME, POLICY_BYTES, POLICY_NAME, SCHEMA_BYTES, SCHEMA_HASH,
    build_export, verify_export,
)
from .typed_authority_profile import NAMES as TYPED_NAMES


ARCHIVE_WRITER_SALT = 766
ARCHIVE_CLASS = 6
SCHEMA_PREDECESSOR = schema_id(TYPED_NAMES[2])
QUALIFICATION = (
    "Actual isolated local EVM class-6 Safe publication on the selected current Metadata "
    "host. It authenticates the archivist account and retained derived manifest only; it "
    "does not transfer authorship of source claims, publish a collection snapshot, prove "
    "consensus finality, authenticate a named human, or use the independent-attestor lane."
)


class CurrentArchiveFixture(CurrentAuthorityFixture, CurrentRightsFixture):
    def _advance_next_block_timestamp(self):
        latest = self.rpc("eth_getBlockByNumber", ["latest", False])
        require(isinstance(latest, dict) and isinstance(latest.get("timestamp"), str),
                "latest block timestamp")
        self.rpc("evm_setNextBlockTimestamp", [int(latest["timestamp"], 16) + 1])

    def safe_call(self, safe, target, data):
        """Execute a real two-owner Safe call with strictly ordered local block times."""
        nonce = self.read(safe, "nonce()", outputs=("uint256",))[0]
        kinds = (
            "address", "uint256", "bytes", "uint8", "uint256", "uint256", "uint256",
            "address", "address", "uint256",
        )
        values = (
            target, 0, hex_bytes(data), 0, 0, 0, 0, ZERO_ADDRESS, ZERO_ADDRESS, nonce,
        )
        digest = self.read(
            safe,
            "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)",
            kinds,
            values,
            ("bytes32",),
        )[0]
        signatures = b""
        for owner in self.safe_accounts[safe]:
            self._advance_next_block_timestamp()
            self.invoke(safe, "approveHash(bytes32)", ("bytes32",), (digest,), sender=owner)
            signatures += bytes(12) + hex_bytes(owner, 20) + bytes(32) + b"\x01"
        self._advance_next_block_timestamp()
        result = self.invoke(
            safe,
            "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
            kinds[:-1] + ("bytes",),
            values[:-1] + (signatures,),
        )
        require(self.read(safe, "nonce()", outputs=("uint256",))[0] == nonce + 1,
                "actual Safe nonce did not advance once")
        return result

    def capture_lanes(self):
        # C3 inheritance otherwise exposes CurrentPreservationFixture's three-lane inventory.
        # The archive record is later output evidence and cannot enter this source selection.
        return CurrentMuseumFixture.capture_lanes(self)

    def after_media_publications(self):
        # Publish only the typed authority source extension. Rights/preservation subclasses
        # are used solely for their current Metadata deployment/governance helpers.
        CurrentAuthorityFixture.after_media_publications(self)
        CurrentRightsFixture.deploy_metadata_dependencies(self)
        CurrentRightsFixture.select_metadata(self)
        CurrentRightsFixture.extend_actions(
            self, "StreamCollectionMetadataV1", ["admitRecordType", "setFamilyWriter"]
        )
        self.register_document(NAME, 0, SCHEMA_BYTES, JCS, SCHEMA_PREDECESSOR)
        self.register_document(POLICY_NAME, 2, POLICY_BYTES, JCS, ZERO)
        self.archive_writer = self.safe(ARCHIVE_WRITER_SALT)
        self.archive_configuration = configure_archive_lane(
            self, self.archive_writer, ARCHIVE_CLASS, collection_id=1
        )

    def extra_capture_evidence(self):
        return CurrentAuthorityFixture.extra_capture_evidence(self) | {
            "archivePreparation": {
                "host": self.addresses["StreamCollectionMetadataV1"],
                "writer": self.archive_writer,
                "authorizationClass": str(ARCHIVE_CLASS),
                "authorizationClassName": AUTHORITY_NAMES[ARCHIVE_CLASS],
                "schemaName": NAME,
                "schemaHash": SCHEMA_HASH,
                "schemaPredecessor": SCHEMA_PREDECESSOR,
                "policyName": POLICY_NAME,
                "policyHash": keccak256(POLICY_BYTES),
                "sourceLaneIncludesArchivePublication": False,
                "qualification": QUALIFICATION,
            }
        }

    def export_capture(self, source, output):
        output = Path(output)
        authority_hash = CurrentAuthorityFixture.export_capture(self, source, output)
        result = build_export(output / "authority-package", authority_hash, disclosure="public")
        destination = output / "semantic-export-package"
        write_package(result, destination)
        verified = verify_export(destination, result.manifest_hash)
        require(verified.manifest_hash == result.manifest_hash,
                "semantic export offline verification differs")
        manifest_bytes = dict(result.files)[MANIFEST_PATH]
        manifest = loads(manifest_bytes, maximum=8192, canonical=True)
        scope = manifest["sourceState"]
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        publication = publish_archive_export(
            self,
            manifest_bytes,
            SCHEMA_BYTES,
            schema_name=NAME,
            schema_hash=SCHEMA_HASH,
            source_block_number=scope["blockNumber"],
            source_block_hash=scope["blockHash"],
            subject_id=scope["anchorSubject"]["subjectId"],
            writer=self.archive_writer,
            authorization_class=ARCHIVE_CLASS,
            collection_id=scope["collectionId"],
            # No content location is claimed. The current metadata host explicitly allows
            # an empty URI, while a made-up URN is rejected by its URI safety policy.
            uri="",
            effective_at=str(int(block["timestamp"], 16)),
        )
        final_block = self.rpc("eth_getBlockByNumber", ["latest", False])
        pins = []
        for address in self.capture_code_addresses():
            code = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
            pins.append({"address": address, "runtimeHash": keccak256(code)})
        pins.sort(key=lambda row: row["address"])
        publication_raw = evidence_bytes(publication)
        output.joinpath("archive-publication.json").write_bytes(publication_raw)
        output.joinpath("archive-grant.json").write_bytes(dumps(self.archive_configuration))
        output.joinpath("archive-result.json").write_bytes(dumps({
            "mode": "actual_current_archive_semantic_export",
            "authorityPackageManifestHash": authority_hash,
            "exportManifestHash": result.manifest_hash,
            "semanticManifestHash": keccak256(manifest_bytes),
            "publicationEvidenceHash": keccak256(publication_raw),
            "archiveRecordHash": publication["recordHash"],
            "semanticManifestByteLength": str(len(manifest_bytes)),
            "authorizationClass": publication["authorizationClass"],
            "authorizationClassName": publication["authorizationClassName"],
            "publicationBlock": final_block,
            "runtimePins": pins,
            "offlinePackageVerifiedBeforePublication": True,
            "sourceLaneIncludesArchivePublication": False,
            "qualification": QUALIFICATION,
        }))
        return publication["recordHash"]


def capture(fixture, output):
    return capture_current(fixture, output)


def main():
    run_main(
        fixture_type=CurrentArchiveFixture,
        capture_function=capture,
        configure_parser=configure_parser,
        prepare_arguments=prepare_arguments,
        configure_fixture=configure_fixture,
    )


if __name__ == "__main__":
    main()
