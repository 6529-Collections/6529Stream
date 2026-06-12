# Release Signatures

6529Stream treats release signatures as public release evidence. The committed
local evidence proves the repository has a deterministic format for retaining
that evidence, but it does not claim production signing has happened.

Validate the committed local evidence with:

```sh
python scripts/test_release_signatures.py
python scripts/check_release_signatures.py
```

Production releases must retain:

- the exact `release-artifacts/latest/SHA256SUMS` file that was signed;
- a detached signature artifact, such as `SHA256SUMS.asc` or an equivalent
  Sigstore/cosign bundle;
- the signed Git tag and verification output;
- the public signing-key fingerprint or certificate identity;
- verification commands that a fresh contributor can run;
- signer rotation, revocation, and custody notes;
- redaction proof that no private keys, mnemonics, API keys, or RPC credentials
  are committed.

The signature evidence file references `release-manifest.json` and `SHA256SUMS`
by path with `not_available_self_referential` digest status. That is intentional:
the release manifest records signature evidence, and the checksum bundle covers
the signature evidence file, so embedding those generated hashes in the evidence
file would create a hash cycle.
