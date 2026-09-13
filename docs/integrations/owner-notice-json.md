# Steward designation and recovery response JSON

The two serializers preserve complete owner-notice statements under
`STREAM_STEWARD_DESIGNATION_V1` and `STREAM_RECOVERY_RESPONSE_V1`. Their
separate `*_JSON_PROFILE_V1` documents define the supported interpretation.
The schema/profile files and worked examples are prospective registration
bytes. This pure slice establishes no actual record, owner, institution,
registered steward, current designation, recovery schedule or veto.

`StreamStewardDesignationJson.serialize` encodes an explicitly named institution
or registrar contact, a committed identity reference and nonempty ordered notice
endpoints. `predecessor` is explicitly null for no predecessor or a nonzero
record hash. The actual owner-record consumer must join the subject, owner
receipt, predecessor and authoritative designation order. A later accepted
designation replaces the notice target. It never gives the steward write,
relay-signing or veto authority.

`StreamRecoveryResponseJson.serialize` encodes the canonical scheduled action
ID used by the recovery host, the scheduled manifest hash, `acknowledged` or
`objected`, authored grounds and an explicit evidence array. The action ID is
not a later executed-record hash. Every response retains its grounds, even an
acknowledgment; evidence may explicitly be empty. The consumer must separately
join the scheduled action and manifest, affected token, notice window and
authenticated carrier before treating a statement as an owner response.

The same response bytes can appear under an owner record or an independent
attestor record. The carrier determines who spoke and under what authority.
A steward submitting the owner's authorized payload is a relayer. A steward
speaking independently is the attestor of its own statement. No payload field
allows it to claim owner standing, and an objection informs the recovery
evaluation without itself executing a veto.

Both libraries expose `serialize(witness)` and `requireExact(witness, stored)`.
The latter checks the entire original byte sequence, including its length.
Subjects and profile hashes must be nonzero; matching them to an admitted schema,
profile and actual token is the caller's responsibility. Nothing here replaces
original receipts or author verification. The structs are untrusted input.

All six existing preservation `HashRef` algorithms are represented with their
original numeric IDs: keccak256=1, SHA256=2, BLAKE3=3, multihash=4, IPFS CID=5
and Arweave transaction=6. Algorithms1/2/3/6 require exactly32 digest bytes;
4/5 retain1..128 opaque bytes. The canonicalization ID is nonzero. Correctly
shaped all-zero digest bytes remain representable. Neither serialization nor
the reference proves identity, file fixity, retrieval or an inner CID/multihash
codec. Registration and recognized canonicalization meanings are external.

References use the existing nonempty Renderer content-URI policy for exact
`https://`, `ipfs://` and `ar://` values. They are commitments and source locators;
no URI fetch occurs. HTTPS notice endpoints use the same lexical rule.
Mailto endpoints support a single ASCII mailbox: dot-separated local segments
with letters, digits, underscore, plus or hyphen, followed by alphanumeric and
hyphen host labels. Leading/trailing hyphens and empty labels reject. Quoted
mailboxes, percent escapes, headers and internationalized mailboxes are outside
this interpretation. A syntactically accepted endpoint is not a DNS, SMTP or
delivery claim.

An EIP155 endpoint carries a positive full-width uint256 chain ID as a canonical
decimal string and a nonzero lowercase20-byte account. Account identity does
not imply a Person, Group, institution or controller. HTTPS/mailto structs
require zero chain/account fields; EIP155 requires an empty URI. Unknown enum
values and inactive union fields reject.

Contact uniqueness means equality of the exact canonical endpoint tuple.
HTTPS/mailto spelling and mailbox case remain unchanged; no URI equivalence,
recipient deduplication or delivery proof is inferred. Contact order is retained.
Evidence order and duplicate evidence entries remain retained and observable.
No separate item-count limit narrows either array: every complete entry that
fits the encoded payload is supported.

The supported payload limit is8192 complete encoded bytes. Per-field decoded
UTF8 limits are512 for the steward name and2048 for grounds and URI strings.
These interpretation limits do not change the generic record carrier. All
JSON keys are fixed and sorted, version/algorithm tags are small integers,
protocol quantities are decimal strings, and digests are exact lowercase hex
bytes. Valid UTF8 is escaped without normalization, trimming or inferred
language. There is no automatic absent designation or default response.

Generate or verify the prospective documents from the repository's existing
metadata Python environment:

```powershell
python -m tools.metadata.owner_notice_profile --check
python -m unittest tools.metadata.test_owner_notice_profile -v
```

The generator uses the existing jsonschema, rfc8785 and pycryptodome dependency
boundary. It also emits the literal `StreamOwnerNoticeDefinitions` pins for
callers to bind complete registered schema/profile bytes. These pins do not
register their own definitions. The JSON Schema documents carry explicit
annotations for additional byte, digest-shape and URI rules; generic JSON
Schema validation alone is insufficient. The Python validator executes those
rules and checks canonical input bytes before validating complete meaning.
