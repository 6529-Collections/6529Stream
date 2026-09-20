import type { Address, Hex } from "../src/generated/contracts.js";
import { normalizeMintPhaseFreezeCoordinates, normalizeMintPhaseFreezeRecord, normalizeMintPhaseFreezeSnapshot,
  mintPhaseFreezeTransition, mintPhaseFreezeSelectorStateHash, normalizeMintPhaseFreezeClassifierSnapshot,
  prepareMintPhaseFreeze, prepareMintPhaseFreezeClassifier, normalizeMintPhaseFreezePlan, normalizeMintPhaseFreezeRoyaltyPolicy,
  normalizeMintPhaseFreezeConfigurationInput, mintPhaseFreezeRoyaltyConfigHash, mintPhaseFreezeConfigurationHash,
  normalizeMintPhaseFreezeGovernanceWindow, assertMintPhaseFreezeGovernanceWindow, mintPhaseFreezeGovernanceBatch,
  normalizeMintPhaseFreezeGovernanceBatch, prepareMintPhaseFreezeImport, normalizeMintPhaseFreezeImport,
  type MintPhaseFreezeSnapshot, type MintPhaseFreezeClassifierSnapshot, type MintPhaseFreezeConfigurationInput,
  type MintPhaseFreezeGovernanceWindow, type MintPhaseFreezePlan, type MintPhaseFreezeGovernanceBatch } from "../src/current-mint-phase-freeze.js";
declare const snapshot: MintPhaseFreezeSnapshot, classifier: MintPhaseFreezeClassifierSnapshot, configuration: MintPhaseFreezeConfigurationInput;
declare const window: MintPhaseFreezeGovernanceWindow, actor: Address, hash: Hex;
normalizeMintPhaseFreezeCoordinates({ chainId: snapshot.chainId, core: snapshot.core, manager: snapshot.manager, ledger: snapshot.ledger,
  governanceExecutor: snapshot.governanceExecutor, collectionId: snapshot.collectionId, phaseId: snapshot.phaseId });
normalizeMintPhaseFreezeRecord(snapshot.record); normalizeMintPhaseFreezeSnapshot(snapshot); mintPhaseFreezeTransition(snapshot);
mintPhaseFreezeSelectorStateHash(classifier.chainId, classifier.governanceExecutor, classifier.manager,
  { enabled: classifier.config.enabled, targetCodeHash: classifier.config.targetCodeHash, revision: classifier.config.revision });
normalizeMintPhaseFreezeClassifierSnapshot(classifier); prepareMintPhaseFreezeClassifier(classifier);
const plan: MintPhaseFreezePlan = prepareMintPhaseFreeze(snapshot);
normalizeMintPhaseFreezePlan(plan); normalizeMintPhaseFreezeRoyaltyPolicy(configuration.royalty);
normalizeMintPhaseFreezeConfigurationInput(configuration);
const wrapper: Hex = mintPhaseFreezeRoyaltyConfigHash(configuration), constraint: Hex = mintPhaseFreezeConfigurationHash(configuration);
normalizeMintPhaseFreezeGovernanceWindow(window, 2n); assertMintPhaseFreezeGovernanceWindow(2n, window, 1n);
const batch: MintPhaseFreezeGovernanceBatch = mintPhaseFreezeGovernanceBatch(plan, 0n, window);
normalizeMintPhaseFreezeGovernanceBatch(batch);
normalizeMintPhaseFreezeImport(prepareMintPhaseFreezeImport(snapshot.ledger, actor, hash, 32n));
void wrapper; void constraint;

// @ts-expect-error uint256 chain coordinates preserve exact bigint
normalizeMintPhaseFreezeSnapshot({ ...snapshot, chainId: 1 });
// @ts-expect-error current policy must remain distinct from a record provenance field
prepareMintPhaseFreeze({ ...snapshot, currentPolicyHash: undefined });
// @ts-expect-error no direct Safe authority flag exists
prepareMintPhaseFreeze({ ...snapshot, safeAuthorized: true });
// @ts-expect-error classifier registration requires the complete actual selector config
prepareMintPhaseFreezeClassifier({ ...classifier, config: { enabled: false } });
// @ts-expect-error uint64 revision is bigint
prepareMintPhaseFreezeClassifier({ ...classifier, config: { ...classifier.config, revision: 1 } });
// @ts-expect-error phase terms are original uint64 fields
normalizeMintPhaseFreezeConfigurationInput({ ...configuration, config: { ...configuration.config, startTime: 1 } });
// @ts-expect-error defined flags are actual booleans
normalizeMintPhaseFreezeConfigurationInput({ ...configuration, defined: [1] });
// @ts-expect-error complete definition selections are required
normalizeMintPhaseFreezeConfigurationInput({ ...configuration, definitions: [{ scope: 2n }] });
// @ts-expect-error executors are not an input to the canonical configuration hash
mintPhaseFreezeConfigurationHash({ ...configuration, executors: [actor] });
// @ts-expect-error no declared configuration hash is substituted for original tuples
mintPhaseFreezeConfigurationHash(hash);
// @ts-expect-error nonce is exact uint256 bigint
mintPhaseFreezeGovernanceBatch(plan, 0, window);
// @ts-expect-error only original class0 and class2 belong to these plans
assertMintPhaseFreezeGovernanceWindow(1n, window, 1n);
// @ts-expect-error timestamp is explicit bigint
assertMintPhaseFreezeGovernanceWindow(2n, window, 1);
// @ts-expect-error import maxCount preserves uint256 type
prepareMintPhaseFreezeImport(snapshot.ledger, actor, hash, 32);
// @ts-expect-error actor remains explicit for the permissionless import route
prepareMintPhaseFreezeImport(snapshot.ledger, hash, 32n);
// @ts-expect-error no unfreeze operation in the plan union
normalizeMintPhaseFreezePlan({ ...plan, kind: "unfreeze" });
// @ts-expect-error nested retained definition is immutable
configuration.definitions[0]!.metadataHash = hash;
// @ts-expect-error ordered counters cannot mutate after review
configuration.counterIds.push(hash);
// @ts-expect-error target calldata is immutable
plan.targetCall.data = hash;
// @ts-expect-error computed action labels cannot be replaced
batch.actionId = hash;
