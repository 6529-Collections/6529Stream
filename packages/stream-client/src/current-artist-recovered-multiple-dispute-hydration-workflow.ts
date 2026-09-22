/** MULTIPLE_DISPUTE_HISTORY operation60 adapter. Original Registry simulation remains semantic admission. */
import { Interface, TypedDataEncoder, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationSuite, ArtistHydrationSnapshot } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_CHECKPOINT_TUPLE, ARTIST_HYDRATION_SUITE_TUPLE } from "./current-artist-authority-hydration.js";
import * as multiple from "./current-artist-recovered-multiple-dispute-hydration.js";
import { ARTIST_ATTRIBUTION_HEAD_TUPLE, ARTIST_ATTRIBUTION_RECORD_TUPLE, ARTIST_ATTRIBUTION_RESOLUTION_TUPLE, ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE, ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE, ARTIST_ATTRIBUTION_TERMINAL_TUPLE, ARTIST_ATTRIBUTION_WITHDRAWAL_TUPLE, artistAttributionAuthorityHeadHash } from "./current-artist-attribution.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import {
  createRecoveredHydrationWorkflow,
  type ArtistRecoveredHydrationCapture,
  type ArtistRecoveredHydrationSimulation,
  type ArtistRecoveredHydrationReader,
  type ArtistRecoveredHydrationReceiptReader,
  type ArtistRecoveredHydrationDeployment,
} from "./internal/artist-recovered-hydration-workflow.js";

export type {
  ArtistRecoveredHydrationCodePin as ArtistRecoveredMultipleDisputeHydrationCodePin,
  ArtistRecoveredHydrationSuitePins as ArtistRecoveredMultipleDisputeHydrationSuitePins,
  ArtistRecoveredHydrationDeployment as ArtistRecoveredMultipleDisputeHydrationDeployment,
  ArtistRecoveredHydrationReader as ArtistRecoveredMultipleDisputeHydrationReader,
  ArtistRecoveredHydrationReceiptReader as ArtistRecoveredMultipleDisputeHydrationReceiptReader,
  ArtistRecoveredHydrationObservation as ArtistRecoveredMultipleDisputeHydrationObservation,
  ArtistRecoveredHydrationOwnerObservation as ArtistRecoveredMultipleDisputeHydrationOwnerObservation,
} from "./internal/artist-recovered-hydration-workflow.js";
export type ArtistRecoveredMultipleDisputeHydrationCapture = ArtistRecoveredHydrationCapture<multiple.ArtistRecoveredMultipleDisputeHydrationCall>;
export type ArtistRecoveredMultipleDisputeHydrationSimulation = ArtistRecoveredHydrationSimulation<multiple.ArtistRecoveredMultipleDisputeHydrationCall>;
export type ArtistRecoveredMultipleDisputeHydrationReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex; nonce: bigint; safeCodeHash: Hex }
>;
const abi = new Interface([
  "function nextRegistrationNonce() view returns(uint256)",
  `function authorityCheckpoint() view returns(${ARTIST_HYDRATION_CHECKPOINT_TUPLE})`,
  "function authorityNonceIndexAt(uint256) view returns((uint8 kind,bytes32 key,uint256 prefixCount))",
]);
const CONTENT_TERMS = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const CONTENT_RECORD = `tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,${CONTENT_TERMS} terms,uint8 authorityClass)`;
const ROYALTY_TERMS = "tuple(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
const ROYALTY_RECORD = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration)";
const FREEZE_RECORD = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass)";
const ECONOMICS_TERMS = "tuple(uint256 collectionId,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)";
const ECONOMICS_ASSOCIATION = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 payloadHash,bytes32 originalRecord)";
const SALE_RECORD = "tuple(bytes32 recordHash,tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash)";
const GRANT = "tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash)";
const DELEGATION_RECORD = `tuple(${GRANT} grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash)`;
const consentAbi = new Interface([
  "function policyRecord(uint256 collectionId,bytes32 phaseId,bytes32 policyHash) view returns(bytes32)",
  `function economicsRecord(${ECONOMICS_TERMS} payload) view returns(bytes32)`,
  `function economicsRecordForBinding(${ECONOMICS_TERMS} payload,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash) view returns(bytes32)`,
  `function economicsRecordAssociation(bytes32 recordHash) view returns(${ECONOMICS_ASSOCIATION})`,
  `function saleConsentRecord(bytes32 recordHash) view returns(${SALE_RECORD})`,
  "function saleConsentAt(uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash) view returns(bytes32)",
  `function contentConsentRecord(bytes32 recordHash) view returns(${CONTENT_RECORD})`,
  `function contentConsentAt(${CONTENT_TERMS} p,uint64 generation) view returns(${CONTENT_RECORD})`,
  `function royaltyFreezeRecord(${ROYALTY_TERMS} p,bytes32 artistId,uint64 bindingGeneration) view returns(${ROYALTY_RECORD})`,
  `function contentFreezeRecord(bytes32 recordHash) view returns(${FREEZE_RECORD})`,
  `function contentFreezeAt(uint256 collectionId,uint64 generation,address metadata,bytes32 lockClass) view returns(${FREEZE_RECORD})`,
  "function recordDelegation(bytes32 recordHash) view returns(bytes32)",
]);
const CONTEST = "tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 subjectRecordHash,bytes32 evidenceHash,bytes32 reasonHash) terms,address contester,uint64 contestedAt,uint8 priorStatus,bytes32 guardianSetRecordHash,bytes32 capturedGuardianSetRecordHash,bytes32 pendingTransitionRecordHash,bytes32 executedTransitionRecordHash,bytes32 governanceWitnessHash)";
const CAUSE = "tuple(bytes32 causeHash,tuple(bytes32 artistId,uint8 kind,bytes32 referenceHash,address actor,bytes32 reasonHash,bytes32 evidenceHash,uint64 enteredAt,address incumbent,uint8 authorityClass,uint8 priorStatus,bytes32 pendingTransitionHash,bytes32 executedTransitionHash,bytes32 previousCauseHash,bytes32 previousResolutionHash,bytes32 actorRetirementHash) facts)";
const GUARDIAN = "tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional)";
const identityAbi = new Interface([
  `function delegationRecord(bytes32 grant) view returns(${DELEGATION_RECORD})`,
  "function identityDocumentBytes(bytes32 documentHash) view returns(bytes)",
  "function signatureBundle(bytes32 recordHash) view returns(bytes)",
  `function identityContestRecord(bytes32 recordHash) view returns(${CONTEST})`,
  `function identityContestCause(bytes32 causeHash) view returns(${CAUSE})`,
  `function guardianSetRecord(bytes32 recordHash) view returns(${GUARDIAN})`,
]);
const ATTESTATION_RECORD = "tuple(bytes32 recordHash,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,uint64 generation,uint64 signedAt,address signer)";
const ATTESTATION_ASSOCIATION = "tuple(bytes32 artistId,bytes32 bindingHash,uint64 generation,bytes32 delegation,tuple(address owner,bytes32 ownerCodeHash,bytes32 subjectId,bytes32 stateHash) fact)";
const PUBLICATION_ATTESTATION = "tuple(tuple(address metadataHost,address recorder,uint256 collectionId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,bytes32 canonicalizationId,uint16 payloadAlgorithm,bytes32 payloadHash,bytes32 uriHash,uint64 effectiveAt,bytes32 candidateRecordHash) publication,tuple(bytes32 attestationRecordHash,bytes32 artistId,bytes32 bindingHash,uint64 bindingGeneration,address signer,uint8 authorityClass,uint32 requiredCapability,uint64 signedAt,bytes32 publicationHash) evidence,bytes32 metadataHostCodeHash)";
const BINDING = "tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const attestationAbi = new Interface([
  "function attributionState(uint256 collectionId) view returns(uint8,uint64)",
  `function attestation(uint256 collectionId,uint8 kind,bytes32 subjectId) view returns(${ATTESTATION_RECORD})`,
  `function attestationRecord(bytes32 record) view returns(${ATTESTATION_RECORD})`,
  "function attestationAuthorityClass(bytes32 record) view returns(uint8)",
  `function attestationAssociation(bytes32 record) view returns(${ATTESTATION_ASSOCIATION})`,
  "function statementBytes(bytes32 hash) view returns(bytes)",
  `function publicationAttestation(bytes32 recordHash) view returns(${PUBLICATION_ATTESTATION})`,
  `function personhoodProofSummary(bytes32 recordHash) view returns(${multiple.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_PERSONHOOD_SUMMARY_TUPLE})`,
  "function personhoodProofSummaryHash(bytes32 recordHash) view returns(bytes32)",
  `function c2paCredentialRecord(bytes32 recordHash) view returns(${multiple.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_CREDENTIAL_HEAD_TUPLE})`,
  `function c2paCredentialHead(bytes32 artistId) view returns(${multiple.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_CREDENTIAL_HEAD_TUPLE})`,
  `function personhoodAttestation(uint256 collectionId,bytes32 artistId) view returns(${ATTESTATION_RECORD})`,
]);
const clockAbi = new Interface([
  `function authorityHydrationSuite() view returns(${ARTIST_HYDRATION_SUITE_TUPLE})`,
  "function configurationHash() view returns(bytes32)",
  "function storedPayloadCount() view returns(uint256)",
  "function storedPayloadAt(uint256 index) view returns(address pointer,bytes32 kind,bytes32 hash)",
  "function artistRegistry() view returns(address)",
  "function operationCoordinator() view returns(address)",
  "function artistArchiveMarkerV2() pure returns(bytes32)",
  "function artistArchiveSchemaV2() pure returns(uint16)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns(uint256)",
  "function artistArchiveBindingHashV2() view returns(bytes32)",
  "function artistEvidenceMetadataV2(bytes32 evidenceId,uint64 evidenceVersion) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32 evidenceId,uint64 evidenceVersion) view returns(bytes evidence)",
  `function bindingAt(uint256 collectionId,uint64 generation) view returns(${BINDING})`,
  "function acceptedAt(bytes32 bindingHash) view returns(uint64)",
  "function acceptanceRecord(bytes32 bindingHash) view returns(bytes32)",
]);
const BINDING_TERMS = "tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count)";
const BINDING_TERMINAL = "tuple(uint8 kind,bytes32 reasonHash,bytes32 recordHash)";
const CORRECTION_APPROVAL = `tuple(${BINDING} previous,uint8 cause,bytes32 causeRecord,bytes causeData,bytes32 proposalHash,bytes32 proposedArtistId,uint256 registrationNonce,${ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE} governance,uint64 approvedAt)`;
const PLATFORM_STATE = "tuple(tuple(bytes32 recordHash,bytes32 statementHash,address actor,uint64 declaredAt) declaration,uint8 contestState,bytes32 contestClaim,bytes32 contestRecord,uint256 claimCount,bytes32 latestClaim,tuple(uint256 collectionId,address proposedArtist,bytes32 claimRecordHash,bytes32 sustainedContestRecordHash,bytes32 evidenceHash,bytes32 reasonHash,bytes32 approvalActionId,uint64 approvedAt,uint64 correctiveGeneration,bool accepted,bytes32 recordHash) correction)";
const generationAbi = new Interface([
  `function binding(uint256 collectionId) view returns(${BINDING})`,
  `function bindingAt(uint256 collectionId,uint64 generation) view returns(${BINDING})`,
  `function bindingTerms(uint256 collectionId,uint64 generation) view returns(${BINDING_TERMS})`,
  `function bindingTermination(uint256 collectionId,uint64 generation) view returns(${BINDING_TERMINAL})`,
  `function bindingCorrection(bytes32 bindingHash) view returns(${CORRECTION_APPROVAL} approval,bytes32 approvalHash)`,
  `function attributionDispute(uint256 collectionId,uint64 generation) view returns(${ARTIST_ATTRIBUTION_HEAD_TUPLE})`,
  `function attributionDisputeRecord(bytes32 recordHash) view returns(${ARTIST_ATTRIBUTION_RECORD_TUPLE})`,
  `function attributionDisputeResolution(bytes32 actionId) view returns(${ARTIST_ATTRIBUTION_RESOLUTION_TUPLE})`,
  `function attributionDisputeWithdrawal(bytes32 disputeRecordHash) view returns(${ARTIST_ATTRIBUTION_WITHDRAWAL_TUPLE})`,
  `function attributionRepudiationRecord(bytes32 recordHash) view returns(${ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE})`,
  `function attributionRepudiationTerminal(bytes32 recordHash) view returns(${ARTIST_ATTRIBUTION_TERMINAL_TUPLE})`,
  "function rawPendingRepudiation(uint256 collectionId) view returns(bytes32)",
  "function repudiationCount(bytes32 artistId,bytes32 authorityHeadHash) view returns(uint256)",
  `function platformWorksState(uint256 collectionId) view returns(${PLATFORM_STATE})`,
]);
// Own methods of the original declared Archive interface, excluding IERC165.
// append is a selector witness only; this workflow never calls it as a writer.
const archiveInterfaceId = (() => {
  const names = ["artistArchiveMarkerV2", "artistArchiveSchemaV2", "artistArchiveMaxEvidenceBytesV2", "artistRegistry", "operationCoordinator", "artistArchiveBindingHashV2", "artistEvidenceMetadataV2", "artistEvidenceBytesV2"];
  let result = BigInt(id("appendArtistEvidenceV2(bytes32,uint64,bytes)").slice(0, 10));
  for (const name of names) result ^= BigInt(clockAbi.getFunction(name)!.selector);
  return `0x${result.toString(16).padStart(8, "0")}` as Hex;
})();
const clockHash = (types: readonly string[], values: readonly unknown[]) => keccak256(io.coder.encode(types, values)) as Hex;
function tupleValue<T>(tuple: string, raw: Hex): T { return io.decode([tuple], raw)[0] as T; }
function emptyTuple<T>(tuple: string): T { return tupleValue<T>(tuple, io.coder.encode([tuple], io.coder.getDefaultValue([tuple])) as Hex); }

/** Immutable record rows and global Artist heads follow the original journal order. */
async function attestationRows(reader: ArtistRecoveredHydrationReader, owner: Address,
  certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number, requireLatest: boolean) {
  const { payload } = multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[4].typedState, 4);
  const state = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(payload.semanticState, 4, payload.provenance);
  const bundles = state.rows.map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationAttribution(raw).records);
  const decoded = multiple.decodeArtistRecoveredMultipleDisputeHydrationAuxiliary(payload.semanticState, 4, payload.provenance);
  const inventory = multiple.decodeArtistRecoveredMultipleDisputeHydrationInventory(decoded.auxiliary);
  type Head = multiple.ArtistRecoveredMultipleDisputeHydrationCredentialHead;
  type Record = multiple.ArtistRecoveredMultipleDisputeHydrationAttestationBundle["records"][number]["attestation"]["record"];
  const zeroHead = emptyTuple<Head>(multiple.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_CREDENTIAL_HEAD_TUPLE);
  const heads = state.artists.map(() => zeroHead), personhood = bundles.map(() => emptyTuple<Record>(ATTESTATION_RECORD));
  const cursors = bundles.map(() => 0);
  const ordered: { k: number; a: number; index: number; entry: typeof payload.provenance.journal[number] }[] = [];
  if (requireLatest) for (const bundle of bundles) io.equal(await io.rpc(reader, owner, attestationAbi, "attributionState", [bundle.collectionId], tag),
    [bundle.item.state, bundle.item.generation], "Original attribution state differs");
  for (const entry of payload.provenance.journal) {
    if ([44n, 45n, 47n, 61n].includes(entry.receipt.operation)) continue;
    const k = bundles.findIndex(b => b.collectionId === entry.receipt.collectionId);
    const a = state.artists.findIndex(q => q.artistId === entry.receipt.artistId);
    if (k < 0 || a < 0 || entry.receipt.operation !== 24n) throw Error("Original op24 journal scope differs");
    const bundle = bundles[k]!, index = cursors[k]!, row = bundle.records[index];
    if (!row) throw Error("Missing complete original op24 row");
    cursors[k] = index + 1;
    const r = row.attestation, terms = r.input.terms;
    const isPersonhood = terms.subjectKind === 10n && [id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"), id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")].includes(terms.schemaId);
    const summary = isPersonhood ? bundle.personhood.find(s => s.recordHash === r.record.recordHash) : {
      summary: emptyTuple<multiple.ArtistRecoveredMultipleDisputeHydrationPersonhoodSummary>(multiple.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_PERSONHOOD_SUMMARY_TUPLE), summaryHash: io.ZERO,
    };
    if (!summary) throw Error("Missing original personhood summary row");
    io.equal(r.record.recordHash, entry.receipt.recordHash, "Original op24 journal record differs");
    io.equal(await io.read(reader, owner, attestationAbi, "attestationRecord", [r.record.recordHash], tag), r.record, "Original attestation record differs");
    io.equal(await io.read(reader, owner, attestationAbi, "attestationAuthorityClass", [r.record.recordHash], tag), r.authorityClass, "Original attestation authority class differs");
    io.equal(await io.read(reader, owner, attestationAbi, "attestationAssociation", [r.record.recordHash], tag), r.association, "Original attestation association differs");
    io.equal(await io.read(reader, owner, attestationAbi, "statementBytes", [r.record.statementHash], tag), r.statement, "Original attestation statement carrier differs");
    io.equal(await io.read(reader, owner, attestationAbi, "publicationAttestation", [r.record.recordHash], tag), row.publication, "Original publication attestation differs");
    io.equal(await io.read(reader, owner, attestationAbi, "personhoodProofSummary", [r.record.recordHash], tag), summary.summary, "Original personhood summary differs");
    io.equal(await io.read(reader, owner, attestationAbi, "personhoodProofSummaryHash", [r.record.recordHash], tag), summary.summaryHash, "Original personhood summary hash differs");
    ordered.push({ k, a, index, entry });
  }
  io.equal(cursors, bundles.map(b => b.records.length), "Incomplete original op24 traversal");
  // Original Source.collect finishes all retained rows before Heads.requireMatches.
  for (const { k, a, index, entry } of ordered) {
    const bundle = bundles[k]!, r = bundle.records[index]!.attestation, terms = r.input.terms;
    let expected = zeroHead;
    if (terms.subjectKind === 10n && terms.schemaId === id("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1")) {
      const credential = tupleValue<multiple.ArtistRecoveredMultipleDisputeHydrationCredentialPayload>(multiple.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE, r.statement);
      const previous = heads[a]!;
      io.equal(credential.previousRecordHash, previous.recordHash, "Original global Artist credential chain differs");
      const era = payload.provenance.eras.findIndex(e => e.originHash === entry.position.point.environmentHash);
      if (era < 0) throw Error("Original credential origin is absent");
      expected = { revision: previous.revision + 1n, recordHash: r.record.recordHash, previousRecordHash: previous.recordHash,
        artistId: bundle.artistId, collectionId: bundle.collectionId, bindingHash: inventory.bindings[k]!.bindings.rows[Number(r.record.generation - 1n)]!.item.bindingHash, generation: r.record.generation,
        identityRecordHash: r.record.subjectStateHash, statementHash: r.record.statementHash, sourceRegistry: payload.provenance.origins[era]!.registry };
      heads[a] = expected;
    }
    io.equal(await io.read(reader, owner, attestationAbi, "c2paCredentialRecord", [r.record.recordHash], tag), expected, "Original credential record differs");
    if (terms.subjectKind === 10n && [id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"), id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")].includes(terms.schemaId)) personhood[k] = r.record;
    const last = !bundle.records.slice(index + 1).some(later => later.attestation.input.terms.subjectKind === terms.subjectKind && later.attestation.input.terms.subjectId === terms.subjectId);
    if (requireLatest && last) io.equal(await io.read(reader, owner, attestationAbi, "attestation", [bundle.collectionId, terms.subjectKind, terms.subjectId], tag), r.record, "Original attestation subject head differs");
  }
  if (!requireLatest) return;
  for (let a = 0; a < state.artists.length; a++) io.equal(await io.read(reader, owner, attestationAbi, "c2paCredentialHead", [state.artists[a]!.artistId], tag), heads[a], "Original Artist credential head differs");
  for (let k = 0; k < bundles.length; k++) io.equal(await io.read(reader, owner, attestationAbi, "personhoodAttestation", [bundles[k]!.collectionId, bundles[k]!.artistId], tag), personhood[k], "Original collection personhood head differs");
}

/** Complete source catalogue at one fixed block, including non-selected rows. */
async function archiveClocks(reader: ArtistRecoveredHydrationReader,
  certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number) {
  const p = certificate.admission.provenance;
  const ownerPayload = (index: 0 | 3 | 4) => multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[index].typedState, index).payload;
  const payload = ownerPayload(4), decoded = multiple.decodeArtistRecoveredMultipleDisputeHydrationAuxiliary(payload.semanticState, 4, payload.provenance);
  const inventory = multiple.decodeArtistRecoveredMultipleDisputeHydrationInventory(decoded.auxiliary);
  const selected: multiple.ArtistRecoveredMultipleDisputeHydrationArchiveOperation[] = [], envelopes: Hex[] = [];
  let rowsRead = 0n, bytesRead = 0;
  for (let era = 0; era < p.origins.length; era++) {
    const origin = p.origins[era]!, expected = inventory.catalogues[era]!;
    io.equal([expected.originHash, expected.lower, expected.upper], [p.eras[era]!.originHash, p.eras[era]!.lowerRevisions, p.eras[era]!.checkpoints.map(row => row.ownerState.revision)], "Complete original seven-owner clock cutoffs differ");
    await io.runtime(reader, { address: origin.archive, codeHash: expected.archiveCodeHash }, tag);
    const suite = await io.read<ArtistHydrationSuite>(reader, origin.coordinator, clockAbi, "authorityHydrationSuite", [], tag);
    io.equal(clockHash([ARTIST_HYDRATION_SUITE_TUPLE], [suite]), origin.suiteConfigurationHash, "Original clock suite hash differs");
    io.equal([suite.registry, suite.archive, suite.core, suite.mintManager, suite.owners], [origin.registry, origin.archive, origin.core, origin.manager, origin.owners], "Original clock suite bindings differ");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistRegistry", [], tag), origin.registry, "Original Archive Registry differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "operationCoordinator", [], tag), origin.coordinator, "Original Archive Coordinator differs");
    const marker = id("6529STREAM_ARTIST_ARCHIVE_V2");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveMarkerV2", [], tag), marker, "Original Archive marker differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveSchemaV2", [], tag), 2n, "Original Archive schema differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveMaxEvidenceBytesV2", [], tag), 24575n, "Original Archive payload bound differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "artistArchiveBindingHashV2", [], tag),
      clockHash(["bytes32", "uint256", "address", "address", "bytes4", "bytes32", "uint16", "uint256"], [id("6529STREAM_ARTIST_ARCHIVE_BINDING_V2"), origin.chainId, origin.registry, origin.coordinator, archiveInterfaceId, marker, 2n, 24575n]), "Original Archive binding differs");
    io.equal(await io.read(reader, origin.coordinator, clockAbi, "configurationHash", [], tag), expected.configurationHash, "Original clock configuration differs");
    const count = await io.read<bigint>(reader, origin.archive, clockAbi, "storedPayloadCount", [], tag);
    rowsRead += count;
    if (count !== expected.count || rowsRead > 16384n) throw Error("Original clock catalogue count differs or exceeds source collector bound");
    let chain = clockHash(["bytes32", "bytes32", "address", "bytes32", "bytes32", "uint256"], [id("6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1"), expected.originHash, origin.archive, expected.archiveCodeHash, expected.configurationHash, count]);
    for (let index = 0n; index < count; index++) {
      const values = await io.rpc(reader, origin.archive, clockAbi, "storedPayloadAt", [index], tag);
      const pointer = io.address(values[0], true), kind = io.hash(values[1], true), contentHash = io.hash(values[2], true);
      chain = clockHash(["bytes32", "uint256", "address", "bytes32", "bytes32"], [chain, index, pointer, kind, contentHash]);
      if (kind !== id("ARTIST_OPERATION_EVIDENCE")) continue;
      const code = io.bytes(await reader.getCode(pointer, tag), 24576);
      if (code.length <= 4 || !code.startsWith("0x00")) throw Error("Original operation carrier must be complete STOP bytes");
      const raw = `0x${code.slice(4)}` as Hex;
      bytesRead += (raw.length - 2) / 2;
      if (bytesRead > 67108864 || raw.length < 194 || keccak256(raw) !== contentHash) throw Error("Original operation carrier hash or byte bound differs");
      const operation = BigInt(`0x${raw.slice(130, 194)}`);
      if (![1n, 2n, 3n, 4n, 44n, 45n, 46n, 47n, 48n, 49n, 50n, 61n].includes(operation)) continue;
      const envelope = multiple.decodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(raw);
      if (envelope.version !== 1n || envelope.configurationHash !== expected.configurationHash || envelope.actor === io.ZERO_ADDRESS || envelope.value === io.ZERO) throw Error("Original operation envelope identity differs");
      const evidenceId = clockHash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), origin.chainId, origin.registry, origin.coordinator, envelope.operation, envelope.actor, envelope.value]);
      const meta = await io.rpc(reader, origin.archive, clockAbi, "artistEvidenceMetadataV2", [evidenceId, 1n], tag);
      io.equal(meta.slice(0, 3), [contentHash, pointer, BigInt((raw.length - 2) / 2)], "Original operation metadata differs");
      if ((meta[3] as bigint) > BigInt(tag)) throw Error("Original operation evidence is from a future block");
      io.equal(await io.read(reader, origin.archive, clockAbi, "artistEvidenceBytesV2", [evidenceId, 1n], tag), raw, "Original operation evidence bytes differ");
      if (envelope.after_[4].revision <= expected.lower[4] || envelope.after_[4].revision > expected.upper[4]) continue;
      selected.push({ originHash: expected.originHash, operation, evidence: { catalogueIndex: index, pointer, payloadHash: contentHash, evidenceId } });
      envelopes.push(raw);
    }
    io.equal(chain, expected.rowsHash, "Complete original clock catalogue commitment differs");
    io.equal(await io.read(reader, origin.archive, clockAbi, "storedPayloadCount", [], tag), count, "Original catalogue changed during readback");
  }
  io.equal(selected, inventory.operations, "Original selected clock evidence differs");
  const bindingPayload = ownerPayload(0), acceptancePayload = ownerPayload(3);
  const bindings = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(bindingPayload.semanticState, 0, bindingPayload.provenance).rows
    .map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationBindingBundle(raw));
  const acceptances = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(acceptancePayload.semanticState, 3, acceptancePayload.provenance).rows
    .map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationAcceptanceBundle(raw));
  io.equal(bindings, inventory.bindings, "Original complete binding inventory differs");
  for (let k = 0; k < bindings.length; k++) {
    const binding = bindings[k]!.bindings, accepted = acceptances[k]!;
    for (const generation of inventory.generations[k]!) {
      const era = p.eras.findIndex(e => e.originHash === generation.proposal.environmentHash);
      if (era < 0) throw Error("Original proposal origin is absent");
      const origin = p.origins[era]!, row = binding.rows[Number(generation.generation - 1n)]!;
      await io.runtimes(reader, [0, 3].map(index => ({ address: origin.owners[index]!, codeHash: origin.ownerCodeHashes[index]! })), tag);
      io.equal(await io.read(reader, origin.owners[0], clockAbi, "bindingAt", [binding.collectionId, generation.generation], tag), row.item, "Original clock binding differs");
      if (!generation.accepted) continue;
      const acceptance = accepted.rows.find(value => value.generation === generation.generation);
      if (!acceptance) throw Error("Original accepted generation is absent");
      io.equal(await io.read(reader, origin.owners[3], clockAbi, "acceptedAt", [generation.bindingHash], tag), acceptance.acceptedAt, "Original clock acceptance time differs");
      io.equal(await io.read(reader, origin.owners[3], clockAbi, "acceptanceRecord", [generation.bindingHash], tag), acceptance.recordHash, "Original clock acceptance record differs");
    }
  }
  const clocks = multiple.validateArtistRecoveredMultipleDisputeHydrationClocks(decoded.state, p, inventory, { envelopes, bindings, acceptances });
  const attribution = decoded.state.rows.map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationAttribution(raw));
  multiple.validateArtistRecoveredMultipleDisputeHydrationDisputes(decoded.state, p, inventory, attribution.map(row => row.history), clocks, { envelopes });
  const { payload: identity } = multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[2].typedState, 2);
  const identities = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(identity.semanticState, 2, identity.provenance).rows
    .map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationIdentity(raw));
  multiple.validateArtistRecoveredMultipleDisputeHydrationIdentityFacts(identities, decoded.state, inventory, acceptances, p, attribution.map(row => row.history));
  multiple.validateArtistRecoveredMultipleDisputeHydrationAttestations(identities, certificate.admission.collections, attribution.map(row => row.records), p, inventory, clocks);
}

/** Original immutable generation rows; mutable current maps are compared only at the source/import revision. */
async function generationRows(reader: ArtistRecoveredHydrationReader, suite: ArtistHydrationSuite,
  certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number, currentBinding: boolean, currentAttribution: boolean) {
  const state = (index: 0 | 3 | 4) => {
    const { payload } = multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[index].typedState, index);
    return multiple.decodeArtistRecoveredMultipleDisputeHydrationState(payload.semanticState, index, payload.provenance);
  };
  const bindings = state(0).rows.map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationBindingBundle(raw));
  const acceptances = state(3).rows.map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationAcceptanceBundle(raw));
  const attribution = state(4).rows.map(raw => multiple.decodeArtistRecoveredMultipleDisputeHydrationAttribution(raw).history);
  for (let k = 0; k < bindings.length; k++) {
    const b = bindings[k]!, cid = b.bindings.collectionId, history = attribution[k]!;
    if (currentBinding) io.equal(await io.read(reader, suite.owners[0], generationAbi, "binding", [cid], tag), b.bindings.current, "Current generation binding differs");
    if (currentAttribution) {
      io.equal(await io.read(reader, suite.owners[4], generationAbi, "platformWorksState", [cid], tag), emptyTuple(PLATFORM_STATE), "Unsupported current Platform history");
      io.equal(await io.rpc(reader, suite.owners[4], attestationAbi, "attributionState", [cid], tag), [history.current.state, history.current.generation], "Current generation attribution differs");
    }
    for (let g = 0; g < b.bindings.rows.length; g++) {
      const row = b.bindings.rows[g]!, generation = BigInt(g + 1), correction = b.corrections[g]!;
      io.equal(await io.read(reader, suite.owners[0], generationAbi, "bindingAt", [cid, generation], tag), row.item, "Retained generation binding differs");
      io.equal(await io.read(reader, suite.owners[0], generationAbi, "bindingTerms", [cid, generation], tag), row.terms, "Retained generation terms differ");
      io.equal(await io.read(reader, suite.owners[0], generationAbi, "bindingTermination", [cid, generation], tag), row.terminal, "Retained generation terminal differs");
      io.equal(await io.rpc(reader, suite.owners[0], generationAbi, "bindingCorrection", [row.item.bindingHash], tag), [correction.approval, correction.recordHash], "Retained generation correction differs");
      if (currentAttribution) io.equal(await io.read(reader, suite.owners[4], generationAbi, "attributionDispute", [cid, generation], tag), history.heads[g], "Current original dispute head differs");
    }
    for (const row of acceptances[k]!.rows) {
      io.equal(await io.read(reader, suite.owners[3], clockAbi, "acceptedAt", [row.bindingHash], tag), row.acceptedAt, "Retained generation acceptance time differs");
      io.equal(await io.read(reader, suite.owners[3], clockAbi, "acceptanceRecord", [row.bindingHash], tag), row.recordHash, "Retained generation acceptance record differs");
    }
    for (const row of history.disputes) {
      io.equal(await io.read(reader, suite.owners[4], generationAbi, "attributionDisputeRecord", [row.record.recordHash], tag), row.record, "Retained complete signed or governed dispute record differs");
      // An absent outcome can be filled by a later withdrawal. A completed
      // outcome is immutable, including its final counterstatement and state.
      if (row.record.terms.disputeAction === 1n && (currentAttribution || row.withdrawal.recordHash !== io.ZERO)) {
        io.equal(await io.read(reader, suite.owners[4], generationAbi, "attributionDisputeWithdrawal", [row.record.recordHash], tag), row.withdrawal, "Retained original withdrawal outcome differs");
      }
    }
    for (const row of history.resolutions) io.equal(await io.read(reader, suite.owners[4], generationAbi, "attributionDisputeResolution", [row.record.actionId], tag), row.record, "Retained original dispute resolution differs");
    for (const row of history.repudiations) {
      io.equal(await io.read(reader, suite.owners[4], generationAbi, "attributionRepudiationRecord", [row.record.recordHash], tag), row.record, "Retained complete repudiation record differs");
      // Pending phase1 may advance. Phases2–5 are permanent terminal bodies;
      // invalidation5 has no invented operation48–50 or terminal point.
      if (currentAttribution || row.terminal.phase >= 2n) io.equal(await io.read(reader, suite.owners[4], generationAbi, "attributionRepudiationTerminal", [row.record.recordHash], tag), row.terminal, "Retained final repudiation terminal differs");
    }
    if (currentAttribution) io.equal(await io.read(reader, suite.owners[4], generationAbi, "rawPendingRepudiation", [cid], tag), history.pending, "Current raw pending repudiation differs");
  }
  if (currentAttribution) {
    const checked = new Set<string>();
    for (const history of attribution) for (const row of history.repudiations) {
      const cohort = artistAttributionAuthorityHeadHash(row.record.authorityHead), key = `${history.artistId}:${cohort}`;
      if (checked.has(key)) continue;
      checked.add(key);
      const count = attribution.filter(other => other.artistId === history.artistId).reduce((sum, other) => sum + BigInt(other.repudiations.filter(r => r.terminal.phase === 1n && artistAttributionAuthorityHeadHash(r.record.authorityHead) === cohort).length), 0n);
      io.equal(await io.read(reader, suite.owners[4], generationAbi, "repudiationCount", [history.artistId, cohort], tag), count, "Original aggregate pending authority-head count differs");
    }
  }
}
const safeABI = new Interface([
  "function nonce() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool)",
]);
const safeTypes = { SafeTx: ["to:address", "value:uint256", "data:bytes", "operation:uint8", "safeTxGas:uint256", "baseGas:uint256", "gasPrice:uint256", "gasToken:address", "refundReceiver:address", "nonce:uint256"].map(entry => {
  const [name, type] = entry.split(":"); return { name: name!, type: type! };
}) };
async function sourceCounter(reader: ArtistRecoveredHydrationReader, source: ArtistHydrationSuite,
  _input: multiple.ArtistRecoveredMultipleDisputeHydrationInput, certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number) {
  io.equal(await io.read(reader, source.owners[2], abi, "nextRegistrationNonce", [], tag),
    BigInt(certificate.admission.artists.length), "Original aggregate registration counter differs");
  await delegationRows(reader, source.owners[2], certificate, tag);
  await identityHistoryRows(reader, source.owners[2], certificate, tag);
  await generationRows(reader, source, certificate, tag, true, true);
  await archiveClocks(reader, certificate, tag);
  await consentRows(reader, source.owners[6], certificate, tag, true);
  await attestationRows(reader, source.owners[4], certificate, tag, true);
}
async function destinationCounter(reader: ArtistRecoveredHydrationReader, capture: ArtistRecoveredMultipleDisputeHydrationCapture,
  snapshots: readonly ArtistHydrationSnapshot[], tag: number) {
  // Later genuine native writes may advance counters. Immutable provenance still proves the import.
  if (snapshots[2]!.revision === capture.after[2]!.revision) {
    const owner = capture.destinationSuite.owners[2], nonces = capture.owners[2]!.payload.nonces;
    io.equal(await io.read(reader, owner, abi, "nextRegistrationNonce", [], tag), BigInt(capture.certificate.admission.artists.length), "Imported aggregate registration counter differs");
    const checkpoint = await io.read<{ nonceIndexCount: bigint }>(reader, owner, abi, "authorityCheckpoint", [], tag);
    io.equal(checkpoint.nonceIndexCount, BigInt(nonces.length), "Imported global nonce index count differs");
    for (let index = 0; index < nonces.length; index++) io.equal(await io.read(reader, owner, abi, "authorityNonceIndexAt", [BigInt(index)], tag), nonces[index]!.index, "Imported global nonce insertion order differs");
  }
  await delegationRows(reader, capture.destinationSuite.owners[2], capture.certificate, tag,
    snapshots[2]!.revision === capture.after[2]!.revision);
  await identityHistoryRows(reader, capture.destinationSuite.owners[2], capture.certificate, tag);
  await generationRows(reader, capture.destinationSuite, capture.certificate, tag,
    snapshots[0]!.revision === capture.after[0]!.revision, snapshots[4]!.revision === capture.after[4]!.revision);
  await consentRows(reader, capture.destinationSuite.owners[6], capture.certificate, tag,
    snapshots[6]!.revision === capture.after[6]!.revision);
  // End-block attribution also rechecks the retained original catalogue. A later
  // same-block append to that original Archive requires separate attribution.
  await archiveClocks(reader, capture.certificate, tag);
  await attestationRows(reader, capture.destinationSuite.owners[4], capture.certificate, tag,
    snapshots[4]!.revision === capture.after[4]!.revision);
}
/** Documentary bytes and veto records remain immutable after later Identity activity. */
async function identityHistoryRows(reader: ArtistRecoveredHydrationReader, owner: Address,
  certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number) {
  const { payload } = multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[2].typedState, 2);
  const state = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(payload.semanticState, 2, payload.provenance);
  for (const raw of state.rows) {
    const identity = multiple.decodeArtistRecoveredMultipleDisputeHydrationIdentity(raw);
    for (const row of identity.documents) io.equal(await io.read(reader, owner, identityAbi, "identityDocumentBytes", [row.documentHash], tag), row.document, "Original retained Identity document differs");
    for (const row of identity.signatures) io.equal(await io.read(reader, owner, identityAbi, "signatureBundle", [row.recordHash], tag), row.signature, "Original retained signature bytes differ");
    for (const row of identity.contests) io.equal(await io.read(reader, owner, identityAbi, "identityContestRecord", [row.record.recordHash], tag), row.record, "Original retained Identity Contest differs");
    for (const row of identity.causes) io.equal(await io.read(reader, owner, identityAbi, "identityContestCause", [row.cause.causeHash], tag), row.cause, "Original retained Identity Cause differs");
    for (const row of identity.guardians) io.equal(await io.read(reader, owner, identityAbi, "guardianSetRecord", [row.record.recordHash], tag), row.record, "Original retained guardian record differs");
  }
}
/** Grant bodies are immutable; only active grants can accumulate uses or a first revocation. No new authorization. */
async function delegationRows(reader: ArtistRecoveredHydrationReader, owner: Address,
  certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number, exact = true) {
  const { payload } = multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[2].typedState, 2);
  const state = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(payload.semanticState, 2, payload.provenance);
  for (const raw of state.rows) {
    const identity = multiple.decodeArtistRecoveredMultipleDisputeHydrationIdentity(raw);
    for (const row of identity.delegations) {
      const actual = await io.read<typeof row.record>(reader, owner, identityAbi, "delegationRecord", [row.recordHash], tag);
      if (exact || row.record.revoked) io.equal(actual, row.record, "Original complete grant version, usage or revocation differs");
      else io.equal({ grant: actual.grant, grantor: actual.grantor, nonce: actual.nonce },
        { grant: row.record.grant, grantor: row.record.grantor, nonce: row.record.nonce },
        "Original immutable grant terms, grantor or nonce differs");
    }
  }
}
/** Reads each collection in selector order; the original producer remains full source admission. */
async function consentRows(reader: ArtistRecoveredHydrationReader, owner: Address,
  certificate: multiple.ArtistRecoveredMultipleDisputeHydrationPrepared, tag: number, requireLatest: boolean) {
  const { payload } = multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(certificate.data[6].typedState, 6);
  const state = multiple.decodeArtistRecoveredMultipleDisputeHydrationState(payload.semanticState, 6, payload.provenance);
  for (const raw of state.rows) {
    const b = multiple.decodeArtistRecoveredMultipleDisputeHydrationConsents(raw).rows;
    const q = b.original;
    for (let i = 0; i < q.policies.length; i++) {
      const row = q.policies[i]!, key = q.keys[i]!;
      if (requireLatest) io.equal(await io.read(reader, owner, consentAbi, "policyRecord", [q.collectionId, key.phaseId, key.policyHash], tag), row.recordHash, "Original policy head differs");
      io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.recordHash], tag), row.grant, "Original policy grant association differs");
    }
    for (const row of q.economics) {
      if (requireLatest) io.equal(await io.read(reader, owner, consentAbi, "economicsRecord", [row.item.terms], tag), row.item.association.originalRecord, "Original first economics terms record differs");
      io.equal(await io.read(reader, owner, consentAbi, "economicsRecordForBinding", [row.item.terms, q.artistId, row.item.association.bindingGeneration, row.item.association.bindingHash], tag), row.item.recordHash, "Original economics binding association differs");
      io.equal(await io.read(reader, owner, consentAbi, "economicsRecordAssociation", [row.item.recordHash], tag), row.item.association, "Original economics record association differs");
      io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.item.recordHash], tag), row.grant, "Original economics grant association differs");
    }
    for (const row of q.sales) {
      io.equal(await io.read(reader, owner, consentAbi, "saleConsentRecord", [row.item.recordHash], tag), row.item, "Original sale record differs");
      io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.item.recordHash], tag), row.grant, "Original sale grant association differs");
      if (requireLatest) io.equal(await io.read(reader, owner, consentAbi, "saleConsentAt", [q.collectionId, row.item.terms.saleId, row.item.terms.saleConfigHash], tag), row.current, "Original sale head differs");
    }
    let consentIndex = 0, royaltyIndex = 0, freezeIndex = 0;
    // Keep the original collectRows journal order across operations 17, 20 and 21.
    for (const entry of payload.provenance.journal) {
      if (entry.receipt.artistId !== q.artistId || entry.receipt.collectionId !== q.collectionId) continue;
      if (entry.receipt.operation === 17n) {
        const row = b.consents[consentIndex++]!;
        io.equal(await io.read(reader, owner, consentAbi, "contentConsentRecord", [entry.receipt.recordHash], tag), row, "Original operation17 record differs");
        io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [entry.receipt.recordHash], tag), io.ZERO, "Original operation17 must remain undelegated");
      } else if (entry.receipt.operation === 20n) {
        const row = b.royalties[royaltyIndex++]!;
        io.equal(await io.read(reader, owner, consentAbi, "royaltyFreezeRecord", [row.terms, q.artistId, row.item.bindingGeneration], tag), row.item, "Original royalty record differs");
        io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [row.item.recordHash], tag), row.grant, "Original royalty grant association differs");
      } else if (entry.receipt.operation === 21n) {
        const row = b.freezes[freezeIndex++]!;
        io.equal(await io.read(reader, owner, consentAbi, "contentFreezeRecord", [entry.receipt.recordHash], tag), row, "Original operation21 record differs");
        io.equal(await io.read(reader, owner, consentAbi, "recordDelegation", [entry.receipt.recordHash], tag), io.ZERO, "Original operation21 must remain undelegated");
      }
    }
    // Original Reads.collectRows authenticates all retained rows before requireHeads.
    if (!requireLatest) continue;
    for (const row of b.consents) {
      const latest = b.consents.filter(value => value.bindingGeneration === row.bindingGeneration && io.stable(value.terms) === io.stable(row.terms)).at(-1)!;
      io.equal(await io.read(reader, owner, consentAbi, "contentConsentAt", [row.terms, row.bindingGeneration], tag), latest, "Original content scope head differs");
    }
    for (const row of b.freezes) for (const lock of row.lockClasses) {
      const latest = b.freezes.filter(value => value.bindingGeneration === row.bindingGeneration && io.same(value.metadataContract, row.metadataContract) && value.lockClasses.includes(lock)).at(-1)!;
      io.equal(await io.read(reader, owner, consentAbi, "contentFreezeAt", [q.collectionId, row.bindingGeneration, row.metadataContract, lock], tag), latest, "Original per-lock freeze head differs");
    }
  }
}
const original = createRecoveredHydrationWorkflow<multiple.ArtistRecoveredMultipleDisputeHydrationInput, multiple.ArtistRecoveredMultipleDisputeHydrationCall>({
  normalizeInputDraft: multiple.normalizeArtistRecoveredMultipleDisputeHydrationInputDraft,
  request: input => input.request,
  finalizeInput: (input, inventory) => multiple.normalizeArtistRecoveredMultipleDisputeHydrationInput({ request: { ...input.request, expectedSemanticInventory: inventory }, royaltyFreezes: input.royaltyFreezes }),
  inputFromCall: call => ({ request: call.request, royaltyFreezes: call.royaltyFreezes }),
  prepareCall: multiple.prepareArtistRecoveredMultipleDisputeHydrationCall,
  normalizeCall: multiple.normalizeArtistRecoveredMultipleDisputeHydrationCall,
  preparationCalldata: multiple.artistRecoveredMultipleDisputeHydrationPreparationCalldata,
  normalizePrepared: multiple.normalizeArtistRecoveredMultipleDisputeHydrationPrepared,
  decodeOwnerPayload: multiple.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload,
  semanticInventory: multiple.artistRecoveredMultipleDisputeHydrationSemanticInventory,
  commitment: multiple.artistRecoveredMultipleDisputeHydrationCommitment,
  ownerAfter: multiple.artistRecoveredMultipleDisputeHydrationOwnerAfter,
  profileEvidence: multiple.encodeArtistRecoveredMultipleDisputeHydrationProfileEvidence,
  validateInput: multiple.validateArtistRecoveredMultipleDisputeHydrationInput,
  freshIdentity: input => {
    const lanes = BigInt(input.request.records.authority.artistIds.length + input.request.records.authority.collections.length);
    return { revision: 1n + lanes, replayCount: 2n + 2n * lanes };
  },
  validateSource: sourceCounter,
  validateReceipt: destinationCounter,
});
const capturedHere = new WeakSet<object>();
export async function captureArtistRecoveredMultipleDisputeHydration(reader: ArtistRecoveredHydrationReader, deployment: ArtistRecoveredHydrationDeployment,
  caller: Address, input: multiple.ArtistRecoveredMultipleDisputeHydrationInput, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const result = await original.capture(reader, deployment, caller, input, options);
  capturedHere.add(result); return result;
}
export async function simulateArtistRecoveredMultipleDisputeHydration(reader: ArtistRecoveredHydrationReader, capture: ArtistRecoveredMultipleDisputeHydrationCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const result = await original.simulate(reader, capture, options);
  capturedHere.add(result.capture); return result;
}

/** Observes the unchanged actual Registry call after source drift; this is not a fresh capture or a prediction check. */
export async function observeArtistRecoveredMultipleDisputeHydrationRefusal(reader: ArtistRecoveredHydrationReader, input: ArtistRecoveredMultipleDisputeHydrationCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  if (!capturedHere.has(input)) throw Error("Refusal requires a capture from this workflow instance");
  io.keys(options, ["blockTag", "gasLimit"]);
  const capture = io.freeze(structuredClone(input)), tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit), d = capture.deployment;
  if (tag < capture.observed.blockNumber) throw Error("Refusal observation precedes capture");
  await io.unchanged(reader, capture.observed);
  const observed = await io.chain(reader, d.chainId, tag);
  await io.runtimes(reader, [d.source.registry, d.source.coordinator, ...d.source.components,
    d.destination.registry, d.destination.coordinator, ...d.destination.components, d.preparationLibrary, ...d.preparationDependencies], tag);
  let result;
  try {
    const raw = io.bytes(await reader.call({ ...capture.prepared.call, from: capture.prepared.caller, blockTag: tag, gasLimit }), 32);
    const returnedCommitment = io.hash(io.decode(["bytes32"], raw)[0]);
    result = { status: "succeeded" as const, returnData: raw, returnedCommitment, capturePredictionChecked: false as const };
  } catch (failure) {
    const e = failure && typeof failure === "object" ? failure as { code?: unknown; data?: unknown } : {};
    const data = typeof e.data === "string" && /^0x[0-9a-fA-F]*$/.test(e.data) && e.data.length % 2 === 0 && e.data.length <= 131074 ? e.data as Hex : null;
    result = { status: e.code === "CALL_EXCEPTION" ? "reverted" as const : "rpc-failed" as const, data, capturePredictionChecked: false as const };
  }
  await io.unchanged(reader, observed); await io.unchanged(reader, capture.observed);
  return io.freeze({ ...result, observed, futureExecutionGuaranteed: false as const });
}

function transportOptions(input: ArtistRecoveredMultipleDisputeHydrationReceiptOptions): ArtistRecoveredMultipleDisputeHydrationReceiptOptions {
  if (input.execution === "direct") { io.keys(input, ["execution"]); return { execution: "direct" }; }
  io.keys(input, ["execution", "expectedSafeTxHash", "nonce", "safeCodeHash"]);
  if (input.execution !== "safe") throw Error("Unsupported hydration transport");
  return io.freeze({ execution: "safe", expectedSafeTxHash: io.hash(input.expectedSafeTxHash), nonce: io.uint(input.nonce), safeCodeHash: io.hash(input.safeCodeHash) });
}
async function retainedTransport(reader: ArtistRecoveredHydrationReceiptReader, capture: ArtistRecoveredMultipleDisputeHydrationCapture,
  hash: Hex, options: ArtistRecoveredMultipleDisputeHydrationReceiptOptions) {
  const m = await io.mined(reader, capture.deployment.chainId, hash), tx = m.transaction;
  if (m.observed.blockNumber <= capture.observed.blockNumber) throw Error("Receipt must follow captured block");
  if (tx.value !== 0n || capture.prepared.call.value !== 0n) throw Error("Original hydration requires zero outer and inner value");
  if (options.execution === "safe") {
    if (!io.same(tx.to, capture.prepared.caller)) throw Error("Safe caller differs");
    const decoded = safeABI.decodeFunctionData("execTransaction", tx.data);
    if (!io.same(safeABI.encodeFunctionData("execTransaction", decoded), tx.data) || !io.same(decoded.to, capture.prepared.registry)
      || decoded.value !== 0n || !io.same(decoded.data, capture.prepared.call.data) || decoded.operation !== 0n) throw Error("Exact recovered ordinary Safe CALL required");
    if (io.bytes(decoded.signatures, 16_384) === "0x") throw Error("Supplied Safe signatures required");
    const prior = m.observed.blockNumber - 1, pin = { address: capture.prepared.caller, codeHash: options.safeCodeHash };
    await io.runtime(reader, pin, prior); await io.runtime(reader, pin, m.observed.blockNumber);
    io.equal(await io.read(reader, pin.address, safeABI, "nonce", [], prior), options.nonce, "Safe prior nonce differs");
    io.equal(await io.read(reader, pin.address, safeABI, "nonce", [], m.observed.blockNumber), options.nonce + 1n, "Safe ending nonce differs");
    const values = [...Array.from(decoded).slice(0, 9), options.nonce];
    const calculated = TypedDataEncoder.hash({ chainId: capture.deployment.chainId, verifyingContract: pin.address }, safeTypes,
      Object.fromEntries(safeTypes.SafeTx.map((field, index) => [field.name, values[index]])));
    io.equal(calculated, options.expectedSafeTxHash, "Independent Safe transaction hash differs");
    io.equal(await io.read(reader, pin.address, safeABI, "getTransactionHash", values, prior), options.expectedSafeTxHash, "Original Safe transaction hash differs");
  }
  // The mined write is attributed to the reviewed whole source/worker closure. No current authorization is repeated.
  const d = capture.deployment;
  await io.runtimes(reader, [d.source.coordinator, ...d.source.components, d.preparationLibrary, ...d.preparationDependencies], m.observed.blockNumber);
  const transaction = io.freeze({ hash, ...tx, chainId: d.chainId, blockNumber: m.observed.blockNumber, blockHash: m.observed.blockHash });
  const receipt = io.freeze({ hash, from: tx.from, to: tx.to, status: 1, blockNumber: m.observed.blockNumber, blockHash: m.observed.blockHash,
    logs: m.logs.map(log => ({ ...log, removed: false, transactionHash: hash, blockNumber: m.observed.blockNumber, blockHash: m.observed.blockHash })) });
  // Both envelopes are detached before further provider reads, including reads inside the shared adapter.
  const proxy: ArtistRecoveredHydrationReceiptReader = {
    getNetwork: reader.getNetwork.bind(reader), getCode: reader.getCode.bind(reader), getBlock: reader.getBlock.bind(reader), call: reader.call.bind(reader),
    getTransaction: (async requested => { if (typeof requested !== "string" || !io.same(requested, hash)) throw Error("Unexpected receipt subject"); return transaction; }) as ArtistRecoveredHydrationReceiptReader["getTransaction"],
    // The shared adapter consumes the detached envelope fields, never ethers receipt methods.
    getTransactionReceipt: (async (requested: string) => { if (!io.same(requested, hash)) throw Error("Unexpected receipt subject"); return receipt; }) as unknown as ArtistRecoveredHydrationReceiptReader["getTransactionReceipt"],
  };
  return { proxy, observed: m.observed };
}
/** Historical import evidence at the mined block; future authority and private activation maps are separate. */
export async function reconcileArtistRecoveredMultipleDisputeHydrationReceipt(reader: ArtistRecoveredHydrationReceiptReader,
  input: ArtistRecoveredMultipleDisputeHydrationCapture, transactionHash: Hex, inputOptions: ArtistRecoveredMultipleDisputeHydrationReceiptOptions) {
  const capture = io.freeze(structuredClone(input)), hash = io.hash(transactionHash), options = transportOptions(inputOptions);
  multiple.normalizeArtistRecoveredMultipleDisputeHydrationCall(capture.prepared);
  const transport = await retainedTransport(reader, capture, hash, options);
  const result = await original.reconcile(transport.proxy, capture, hash, options.execution === "direct" ? options : { execution: "safe", expectedSafeTxHash: options.expectedSafeTxHash });
  await io.unchanged(reader, transport.observed);
  return io.freeze({ ...result, originalArchiveClockReadbackVerifiedAtReceipt: true as const,
    completeGenerationInventoryReadBack: true as const,
    retainedAttestationRowsReadBack: true as const,
    retainedDisputeHistoryReadBack: true as const, retainedIdentityEvidenceReadBack: true as const,
    laneActivationIndependentlyVerified: false as const, privateSemanticInstallationIndependentlyVerified: false as const,
    ownerSignaturesIndependentlyVerified: false as const, safeImplementationIndependentlyVerified: false as const });
}
export const inspectArtistRecoveredMultipleDisputeHydrationHistory = reconcileArtistRecoveredMultipleDisputeHydrationReceipt;
/** Checks eligibility for a fresh import. A completed import is not eligible for replay. */
export async function inspectArtistRecoveredMultipleDisputeHydrationCurrent(reader: ArtistRecoveredHydrationReader, deployment: ArtistRecoveredHydrationDeployment,
  caller: Address, input: multiple.ArtistRecoveredMultipleDisputeHydrationInput, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const capture = await captureArtistRecoveredMultipleDisputeHydration(reader, deployment, caller, input, options);
  return simulateArtistRecoveredMultipleDisputeHydration(reader, capture, { blockTag: capture.observed.blockNumber, gasLimit: capture.preparationGasLimit });
}
