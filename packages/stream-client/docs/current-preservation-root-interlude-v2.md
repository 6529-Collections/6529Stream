# Repaired-source consent and root transport

The separate v2 adapters accept the reviewed `eda052c7` packet-tool profile.
The original `61d0efc5` adapters and their evidence remain unchanged.

```js
import { preparePreservationRootInterludePacket } from
  "../examples/current-preservation-root-interlude-packet-v2.mjs";
import { createPreservationRootInterludeTransport } from
  "../examples/current-preservation-root-interlude-transport-v2.mjs";
```

The APIs, three permitted inner selectors, ten ordered Safe fields, direct CALL
route and verification boundaries are the same as the
[original transport](current-preservation-root-interlude.md). Use unchanged
canonical UTF-8 packet text and an independently reviewed packet SHA-256.

## Exact version identity

| Identity | V2 value |
| --- | --- |
| Source commit | `eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e` |
| Source tree | `1a71ae4ee9806c601237129d81e494058c547ee0` |
| Source report SHA-256 | `66f66b99a6cb5af3c8997ab27c67ece208257eac6a337b78096cea8ff07af706` |
| Original tool SHA-256 | `065f5ee0748ab75f143c5bee600646e3da6e3e6225a91654a0c1f300f72837d7` |
| Tool manifest SHA-256 | `cd955be78e90fe333276c3731581cb71799586d96bcba7d1c27fe4abe3dc1a55` |
| Source/ABI review SHA-256 | `2e195215ce94bfc626a10c638aa104da70e35aeee9d6a19161256edbdf10c35e` |

Both versions enforce exact source, report and tool equality. Neither selects
a source from an allowlist or infers compatibility from a helper-only change.
Packets, admissions and manifests from the two versions cannot be mixed. A
later source needs a separately reviewed rejoin and version; modifying a
manifest string does not transfer evidence.

## Reproducible derivation

The [adapter generator](../scripts/generate-current-preservation-root-interlude-v2-adapters.mjs)
reads the exact v1 modules at commit
`439aedbe8d81569b44d3e0eea98fa35211cfcdd5`, verifies their byte lengths and
SHA-256 hashes, then changes only three packet identity constants and the
transport's packet-module import. Every other byte is identical. Run from
`packages/stream-client`:

```sh
node scripts/generate-current-preservation-root-interlude-v2-adapters.mjs --check
```

The [portable source witness](../test/fixtures/current-preservation-root-interlude-v2-source.json)
retains the source report, original tool, manifest, reviewed rejoin evidence,
59 exact source files, 35 selected ordinary compiler ABI entries and four
explicitly synthetic input examples. Its
[generator](../scripts/generate-current-preservation-root-interlude-v2-fixture.mjs)
verifies all 27 manifest file pins and joins all 4,119 ABI164 input literals to
the committed Git source with the capture's CRLF-to-LF normalization. Raw Git
hashes are retained separately.

```sh
node scripts/generate-current-preservation-root-interlude-v2-fixture.mjs \
  TOOL_DIRECTORY ABI164_INPUT ABI164_OUTPUT ABI164_BRIDGE --check
```

The 59 reviewed source files match ABI164 literally. The compiler Safe entries
come from the genuine-Safe fixture interface; this does not authenticate an
actual deployed Safe implementation. The Python tool's sole code change is
its pinned source-report hash, named `SOURCE_SHA` in that tool.

## Required campaign evidence

The source rejoin does not admit a deployment or imported graph. A real run
still requires reviewed runtime/link pins, actual bootstrap and state-import
evidence, Safe owner evidence, and the completed output/snapshot prerequisites.
Synthetic fixture addresses and hashes cannot provide that admission.

Safe transport observations retain the original false protocol-verification
flags. Use the v2 producer's `prepare-root` and `verify-root` operations for
original consent/root record and binding checks. Owner signatures remain
external; no signature validity is claimed by saving their bytes.

The client tests use mocked Providers and synthetic packets. They do not
establish native execution, actual RPC/Safe success, capacity, gas fit or
release readiness, and they do not relabel the v1 test evidence.
