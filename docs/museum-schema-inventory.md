# Museum schema-derived inventory

`tools.museum.schema_inventory` computes the source coverage denominator from
an exact canonical schema, exact canonical payload and independently pinned
evaluation profile. It supports the three candidate Museum schemas and retains
the eight fixture denominators from the earlier closed-schema engine. This is
an additive engine; `export-fixture` still uses its earlier diagnostic format.
Neither command authenticates a source, registers a profile or produces a
complete Museum export.

The evaluation profile supports JSON Schema 2020-12 closed objects, homogeneous
arrays, typed scalars, local JSON-pointer references, and `allOf`, `oneOf` and
`anyOf`. Before validating the instance it checks all schema locations, including
unused definitions. Unknown keywords or formats, missing references, external
references, nested schema identities, percent-encoded reference fragments and
unsupported constructs reject. The current format policy is the same explicit
URI/date-time policy as the Linked Art validator, including its leap-second
limitation. Unsupported source families remain work to implement; rejection is
never permission to remove their fields from the denominator.

The complete instance must validate before an inventory can be returned. Every
valid `anyOf` branch contributes; `oneOf` requires exactly one; `allOf` requires
all. Branch evidence records the original schema hash, exact schema location,
instance pointer and every applicable branch location. Repeated references in
independent branches are valid. An active schema-location/instance-pointer pair
detects non-advancing cycles during inventory traversal, while recursive data
may advance to another child instance.

For each applicable shape, the inventory includes every actual object, array,
scalar and array index, plus absent optional properties from applicable branches.
Null, empty containers and absence have different rows. Inapplicable branch
properties do not enter the denominator. Exact string contents, decimal lexical
values and protocol integer strings are retained; tests include `40.00`, the
maximum uint64 and the maximum uint256. The complete original schema and payload
hashes remain independent inputs. This profile requires canonical bytes and
rejects existing unsupported numeric representations; it never rewrites an
existing source into typed strings to make it pass.

The evaluator enforces the existing 24,576-byte payload and 64-level JSON bounds,
a 524,288-byte schema bound, 20,000 schema nodes, 100,000 validation-keyword steps
and 100,000 inventory traversal steps. The latter includes property expansion,
so many absent optional fields cannot evade it. These are deterministic profile
limits, not a wall-clock guarantee: regex and unique-item operations can take
more work than one step. A larger or different source profile requires its own
explicit evaluation policy.

The pinned `jsonschema` package selects a validator from an encountered `$schema`
declaration when following references. After checking that every declaration is
2020-12, this engine omits those declarations only from its private parsed
evaluation tree. This keeps the custom unsigned-width validator and work budget
active through root references. Original bytes remain unchanged. A recursive
child overflow test verifies that a root reference cannot silently revert to the
ordinary validator and ignore the unsigned constraint.

Run the following with the isolated environment described in
[the tooling README](../tools/museum/README.md):

```text
python -m tools.museum.schema_inventory schemas/museum/fixtures/source.schema.json schemas/museum/fixtures/photograph.json --schema-hash 0xe4383494ba6f0fc60c0ab7adf0168749780771083b72b10848a6a4d0afec375e --source-hash 0x2cf78099cd8fe05ea3bd76d8d718185cee5381dfdef02d16ce25b497a3059923 --evaluation-hash 0x26067083167b9f6a7b170c3b371e7ce153858cd4dd75e5d992b20d280543ed7e
```

The stdout report contains exact field bytes in hex, branch evidence and explicit
false authority/registration/conformance claims. A missing or wrong pin rejects.
An exporter must retain original source bytes, require a disposition for every
row, and join those rows to authenticated selected records and reviewed mapping
rules. That composition, additional source-family profiles, faithful numeric
adapters and all twelve Museum gates/eight complete scenarios remain required.
