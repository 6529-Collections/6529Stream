# Current-stack Sepolia deployment and native demonstration

This package records **45 successful deployment transactions** and **9 successful activation/demo transactions**, including the oracle fulfillment. The current stack is deployed on Sepolia (chain 11155111). A signed 0.000001 ETH purchase minted collection 1/token 1; the actual Sepolia Chainlink coordinator fulfilled the request in a later block; Core emitted `MetadataUpdate`; final metadata contains the nonzero seed; both 90/10 shares were withdrawn; and the NFT was transferred to the nominated artist.

| Evidence | Pinned block | Purpose |
| --- | --- | --- |
| [Deployment](deployment/README.md) | 11,678,063 | Exact receipts, 177-source compiler input, 86 selected artifacts, 40 runtime addresses and 81 named configuration checks |
| [Demonstration](demonstration/README.md) | 11,678,119 | Paid mint, actual oracle delivery, metadata, withdrawals and transfer; 9 canonical receipts and 18 complete ABI readbacks |
| [Independent verification](verification-summary.json) | Both blocks | Separate public RPC readbacks and source/artifact/event checks |

Use [deployment/addresses.json](deployment/addresses.json) for the address inventory and [demonstration/client-config.json](demonstration/client-config.json) for the strict TypeScript client's public configuration. Source commit `d636056b835c9c3ed0b1c4fe7951609429a5789c` is retained by the non-release Git tag `evidence/sepolia-deployment-2026-09-10`. The exact compiler input SHA-256 is `5d3fe6538a8dd16675c8a5f5d87675c99bdbaf14516514cdfe8c7a46b9ad2a1f`.

`SHA256SUMS` covers every other package file. These hashes establish internal consistency, not author trust or chain consensus. Transaction inputs remain publicly retrievable by hash. The verification records distinguish direct creation proof, supplied internal-creation information, immutable-byte observations and runtime-only checks. Core's private governance authority has a separate semantic binding proof.

The token's HTML contains executable on-chain example JavaScript. It is a protocol demonstration, not a finished artist artwork. The collection and global pointers were not frozen. ERC20 purchases, auctions, state-export publication and collection completion have separate local evidence and are **not** claimed as completed on Sepolia here. No audit completion, public-beta readiness or production readiness is implied.

The two historical blocks are intentional: the deployment configuration precedes activation and shows no minted token; the later demonstration captures the completed native flow. Current owners, balances and other mutable state can change after those blocks. No signing secrets, account configuration, raw signed transaction bytes or private operational checkpoint is included.

## Public source verification

[Sourcify records for all 34 named contract and library instances](source-verification.json) report creation and runtime `match`: 25 fresh submissions and 9 already-verified deterministic library records. The earlier library records retain their original source layout and timestamps; the current submission did not replace them. Independent comparison of all 68 creation/runtime templates against the retained current compiler output passed after zeroing only equal declared library link spans. No opcodes, immutable spans or metadata were masked. The six SSTORE2 data addresses are covered by the separate bytecode proof.

Direct public records: [Core](https://sourcify.dev/server/v2/contract/11155111/0x05914c6f62c819c861f01c5edd4b6b17e935e75b), [Governance Executor](https://sourcify.dev/server/v2/contract/11155111/0x09e676013be9ac977a4ac41fe5fe4aab269d8f35), and the per-contract links in the report. These are Sourcify `match` results, not `exact_match`, an audit, or a protocol-correctness claim.
