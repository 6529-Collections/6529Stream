# VIEW retrieval transaction-bound tests

The added cold-budget host is a separate acceptance target. It retains the actual
VIEW fixture and its original token setup, checkpoint 6,000,000 / witness 7,000,000 /
bundle 8,000,000 read budgets. The original two diagnostic methods and their fixture
remain unchanged. A successful tooling test is not evidence that this large host
has run, and neither host establishes browser-reference, sanction or finality acceptance.

## Execution model

`StreamViewRetrievalTransactionProbe` signs a zero-value, zero-gas-price EIP-155
transaction using an explicitly public test relayer key. Its exact destination and
complete calldata are passed to the pinned Foundry 1.7.1 `executeTransaction` primitive
(commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`). The primitive starts a fresh nested EVM
from the genuine fixture journal. It does not install fabricated contracts or storage.
The sender, destination and Paris precompiles retain their normal warm treatment;
other reached accounts and storage start cold, including dynamically reached paths.
There is no finite cooling list that could omit an unexpected dependency.

Each read transaction has an explicit gross limit equal to its original leaf allowance
plus intrinsic calldata gas. Publication and revocation use the original 16,777,216
gross limit. Intrinsic gas is calculated from the complete **outer Safe** calldata,
including its threshold signature and the enclosed witness signature. It is never
calculated solely from the inner witness payload. A read is executed as a genuine
transaction to its view entry point; all protocol-internal static-read rules remain.
The test relayer transaction nonce changes while protocol read state remains subject
to the original view implementation and pinned runtime checks.

The helper records the signed transaction hash, exact input/output hashes, sender,
nonce, intrinsic gas and gas ceiling. The ceiling is a successful-execution bound,
not an exact gas-used receipt. The pinned primitive sets gas price/base fee to zero
for its nested transaction and restores the parent environment; these tests therefore
do not measure fees or claim to be RPC receipts. All production runtime/full-init
and real constructor checks still belong to the independently authenticated native
artifact and fixture gates. The large aggregate test-harness allowance is unchanged.

## Oracle boundaries

Six small native controls exercise the primitive: cold account and slot prices after
parent-state warming, warm destination/sender/precompile exceptions, actual callback
caller/origin, nonce/state snapshot rollback followed by the identical signed request,
long full calldata and intrinsic accounting, and original ceiling/insufficient-gas refusal.
The actual host has three separate authored cases for current/historical full bytes,
threshold-Safe publication plus full correspondence, and revocation with retained history.
Their actual graph runtime remains pending the shared physical-owner execution view.

Full source/output parity uses the original retained publication bytes and complete
canonical return tuples. Safe cases independently assert exact nonce consumption,
original receipt/source domains, full observation/signature bytes, revocation epoch and
current refusal. The genuine graph's runtime/currentness checks remain mandatory;
this harness supplies no cached evidence shortcut and promotes no finality status.

## Rejected cooling approach

The preserved preliminary controls showed that this pinned build's state-diff recorder
warms SLOAD/account reads before charging their opcode gas. Its nominal stop method
clears its record buffer but leaves the hook enabled. A separate control showed
`vm.cool(address)` marks storage cold without making an already loaded account cold:
BALANCE plus EXTCODEHASH remained warm. Those prototype measurements must not be used
as full cold acceptance. They were replaced by fresh signed transactions; neither
Foundry nor any protocol contract was patched to change the outcome.

The relevant pinned implementation is
[Foundry evm.rs](https://github.com/foundry-rs/foundry/blob/4072e48705af9d93e3c0f6e29e93b5e9a40caed8/crates/cheatcodes/src/evm.rs)
and its
[pre-op recorder](https://github.com/foundry-rs/foundry/blob/4072e48705af9d93e3c0f6e29e93b5e9a40caed8/crates/cheatcodes/src/inspector.rs).
