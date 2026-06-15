# 1/1 Provenance Retained Artifact Template

This is a no-secret checklist for a future reviewed 1/1 provenance evidence
bundle. It is not completion evidence for any public beta or production drop.

Before a provenance manifest can be treated as reviewed evidence, retain:

- final artwork media or media-package hash evidence;
- artist statement and certificate/authenticity hash evidence;
- release manifest, checksum bundle, deployment manifest, and address book
  references used to bind the token scope;
- contract metadata adapter address and `contractURIHash()` evidence where the
  adapter is used;
- `collectionFreezeManifestHash(collectionId)` evidence if the collection is
  frozen;
- append-only provenance entry evidence for creation, curation, publication,
  exhibition, corrections, or collector notes;
- reviewer approval record and timestamp; and
- redaction confirmation that no private keys, mnemonics, RPC URLs, unreleased
  drop payloads, raw signatures, session cookies, or API tokens are retained.

Provenance is separate from current `tokenURI` metadata and separate from the
current collection freeze manifest unless a future contract or manifest change
explicitly moves those boundaries.
