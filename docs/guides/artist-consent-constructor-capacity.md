# Consent owner constructor capacity

The Consent owner keeps its constructor, CREATE of the fixed writer, public ABI,
storage and authorization flow. Its static sanction getter now calls the existing
fixed read-encoding library with the original two storage mappings. The library
reads the same latest hash and record, then returns the exact encoded tuple through
the owner’s existing return helper. It adds no record-presence or current-binding
check and does not select operative authority.

The preceding native build had 49,115 bytes of owner creation code. Its five
address constructor arguments add 160 bytes, exceeding the 49,152-byte limit by
123 bytes. The repaired owner has 48,735 bytes of creation code, or 48,895 with
those arguments, leaving 257 bytes. Runtime is 22,379 bytes. The constructor-created
writer remains 24,911 creation / 23,441 runtime bytes; the existing read library is
2,702 creation / 2,670 runtime bytes. These are exact-source measurements with
Solidity 0.8.19, via IR, Paris, optimizer 200 and no metadata CBOR/hash.

All existing ABI entries, selectors and recursive storage layouts remain unchanged;
the read library gains one typed method. Independent source review checked the
whole owner inverse and unchanged constructor. Five focused tests passed using
genuine native Forge artifacts and a compiler-disabled execution view, including
256 fuzz cases. They compare the literal original getter’s complete return bytes,
all record fields, empty and zero-key lookups, historical records without new
admission, and repeat-read state preservation.

Those five tests use typed storage. Actual owner/Safe deployment and aggregate
generation import scenarios remain a separate runtime campaign. The added library
call also remains subject to that campaign’s transaction-budget checks. These
measurements do not establish deployment or release readiness.
