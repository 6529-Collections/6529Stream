# Release Signatures

6529Stream treats release signatures as public release evidence. The committed
local evidence proves the repository has a deterministic format for retaining
that evidence, but it does not claim production signing has happened.

Validate the committed local evidence with:

```sh
python scripts/test_release_signatures.py
python scripts/check_release_signatures.py
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
```

The signed release tag gate defaults to non-release mode. That default mode is
used by PRs, `main` pushes, `make check`, and CI; it exits successfully while
printing that no signed release status is claimed. Public release ceremonies
must run strict release mode against the intended tag and post-bundle signature
evidence:

```sh
python scripts/check_signed_release_tag.py --mode release --tag vX.Y.Z --evidence path/to/post-bundle-release-signature-evidence.json
```

Strict release mode depends on the runner's trusted keyring for the actual Git
tag signature trust decision. The retained release evidence must also include a
non-empty public-key fingerprint, and `git tag -v` output must contain the same
fingerprint as a discrete token together with an explicit good-signature marker.

Production releases must retain:

- the exact `release-artifacts/latest/SHA256SUMS` file that was signed;
- a detached signature artifact, such as `SHA256SUMS.asc` or an equivalent
  Sigstore/cosign bundle;
- the signed Git tag and verification output;
- the public signing-key fingerprint or certificate identity;
- verification commands that a fresh contributor can run;
- signed Git tag verification output that includes the same public-key
  fingerprint recorded in release-signature evidence;
- signer rotation, revocation, and custody notes;
- redaction proof that no private keys, mnemonics, API keys, or RPC credentials
  are committed.

The detached checksum signature and its retained release-signature evidence are
post-bundle proof. They must not be listed inside the `SHA256SUMS` file they
are proving; otherwise the signature would self-invalidate the checksum bundle.
The release-mode checker rejects signature evidence that is already covered by
the checksum bundle. Keep the generated checksum bundle stable first, sign it
outside the covered file set, then retain the signature evidence and
verification output as separate release ceremony evidence.

The signature evidence file references `release-manifest.json` and `SHA256SUMS`
by path with `not_available_self_referential` digest status. That is intentional:
the release manifest records signature evidence, and the checksum bundle covers
the signature evidence file, so embedding those generated hashes in the evidence
file would create a hash cycle.
