# Retained release evidence

This directory contains both historical captures and unfinished templates.
Read each record's `review_status`, source commit and environment before using
it. A filename ending in `template` does not mean its contents are editable:
the fork metadata browser file with that suffix is a reviewed historical
capture, hash-bound by its evidence record.

The reviewed fork metadata browser and marketplace/indexer captures retain
their exact original bytes and command spellings. Their checkers permit those
spellings only at the recorded SHA-256; altered or new packets must use the
current module commands. Their historical success does not validate today's
contracts or complete the remaining release requirements.

The fork deployment, ceremony and randomizer packets remain `pending_review`. Their
receipts and command describe the original `a35c24a4` fork run. They reference
exact copies of the deployment manifest and address book retained at
`330ac1d4`, under
`fork-deployment-rehearsal/snapshots/pre-reorganization-330ac1d4/`.
Those copies preserve the previously recorded hashes while current examples
under `deployments/` can be regenerated. The pending packet metadata was
updated to identify this retention location; no new run or review is claimed.

For current packet validation, run from the repository root:

```sh
python -m tools.deployment.check_fork_deployment_rehearsal_evidence
python -m tools.deployment.check_fork_randomizer_operations_evidence
python -m tools.release.check_fork_metadata_browser_evidence
python -m tools.release.check_marketplace_indexer_evidence
python -m tools.release.generate_release_evidence_packet_index --check
```

Use the [maintainer release instructions](../../docs/reference/tooling/release-artifacts.md)
to prepare a new packet. Do not rewrite a reviewed capture to make its old
commands look current or replace its hashes with new artifacts.
