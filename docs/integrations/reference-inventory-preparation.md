# Reference environment inventory preparation

The inventory serializer preserves the original canonical JSON, row ordering,
path validation and errors. It writes each row into one final output buffer;
relative paths use the original printable-ASCII restrictions, while absolute
paths retain the original UTF-8 and JSON quoting routine. Decimal quantities
remain strings and SHA-256 digests remain lowercase, fixed-width hex strings.

The isolated 26-source Solidity 0.8.19 capture passes eight tests, including
three sets of 256 differential fuzz cases against the frozen prior serializer,
every possible relative-path byte, zero/max quantities, duplicate and unordered
rows, and original size/error boundaries. The final closing bracket convention
is preserved, including the original maximum-length edge case.

The retained actual corpus contains 1,048 package members and 102 explicit
platform prerequisites. Their exact JSON lengths remain 162,109 and 15,583 bytes.
Measured direct-call package gas falls from 33,479,092 to 18,145,166; platform gas
falls from 4,084,702 to 3,102,427. These measurements include the test caller's
call overhead, not transaction calldata intrinsic gas. The package call alone
still exceeds the 16,777,216 transaction envelope, before host preparation and
retention. This optimization does not establish a usable complete preparation
transaction. A separate authenticated staged preparation flow is required.

No inventory identity, schema, hash domain, storage layout, writer authority,
gas cap or current-source check changes in this serializer batch. These tests
do not demonstrate a completed mode publication or a full current-stack flow.
