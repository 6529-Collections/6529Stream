# Archival proof fixtures

`arweave-single-chunk-v1.json` contains synthetic native-path vectors derived
from the pinned Arweave implementation. They exercise padding and tree shapes
without claiming that their transaction identifiers were published on a network.

`arweave-mainnet-899979.json` contains the four-byte payload `test` and the
native transaction/data paths returned for an actual historical Arweave-mainnet
transaction. Its source URLs, retrieval times and response hashes are included.
The network-proof test verifies the padded transaction range, data root and
payload digest, and rejects altered data, range and transaction root.

The network fixture was retrieved through one public gateway using the
[Arweave HTTP API](https://docs.arweave.org/developers/arweave-node-server/http-api).
The block response lists its transaction ID, and SHA256 of the returned
transaction signature matches that ID. This fixture does not verify the RSA
signature, native consensus, an independent observer quorum or storage-family
independence. Those are distinct from the native inclusion proof tested here.

Run the proof regression with:

```text
python scripts/dev.py test --suite unit --match-contract StreamArweaveNetworkProofTest
```
