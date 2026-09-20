import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-artist-operation.js';
import * as flow from '../dist/current-artist-workflow.js';
const f = JSON.parse(readFileSync(new URL('./fixtures/current-artist-operation-current-abi.json', import.meta.url), 'utf8'));
const attestationFixture = JSON.parse(readFileSync(new URL('./fixtures/current-artist-attestation-abi.json', import.meta.url), 'utf8'));
const abi = new Interface([...Object.values(f.abis).flat(), ...Object.values(attestationFixture.abis).flat()]);
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
const code = n => '0x60' + n.toString(16).padStart(2, '0');
const pin = n => ({
  address: A(n), codeHash: keccak256(code(n))
});
const d = {
  chainId: 31337n, registry: pin(8), coordinator: pin(20), components: Array.from({ length: 16 }, (_, n) => pin(n + 1))
};
const economicsDeployment = { ...d, reads: pin(30) };
const payout = { account: A(150), recordHash: id('payout-designation') };
const economicKinds = ['delegatedEconomicsConsent', 'delegatedProspectiveEconomicsConsent', 'delegatedRoyaltyFreeze'];
const artist = id('artist');
const signer = A(100);
const cfg = id('configuration');
const bh = n => id('block' + n);
const domains = ['binding_lifecycle', 'collaborator_lifecycle', 'identity_authority', 'acceptance_lifecycle', 'attribution_lifecycle', 'payout_lifecycle', 'consent_finality'].map(n => id('domain:' + n));
const kinds = ['bindingRefusal', 'saleConsent', 'royaltyFreeze', 'contentFreeze', 'authorizationRevocation'];
function request(kind, change = {}) {
  const base = {
    core: A(10), collectionId: 7n, nonce: 1n, deadline: 9999n
  };
  const document = '0x7b22617274697374223a226e6577227d';
  const messages = {
    delegatedEconomicsConsent: { core: A(10), resolver: A(14), revenueClass: id('primary'), scope: 1n, scopeId: 7n, assignmentHash: id('assignment'), nonce: 1n, deadline: 9999n },
    delegatedProspectiveEconomicsConsent: { core: A(10), resolver: A(14), revenueClass: id('primary'), scope: 1n, scopeId: 7n, assignmentHash: id('assignment'), nonce: 1n, deadline: 9999n },
    delegatedRoyaltyFreeze: { ...base, resolver: A(15), revenueClass: id('ROYALTY_ERC2981'), expectedAssignmentHash: id('assignment') },
    delegatedPolicyConsent: { ...base, mintManager: A(11), phaseId: id('phase'), policyHash: id('policy') },
    delegatedSaleConsent: { ...base, saleAdapter: A(90), saleId: id('sale'), saleConfigHash: id('config') },
    identityRevision: {
      artistId: artist, previousRecordHash: id('identity'), revisedRecordHash: keccak256(document), nonce: 1n, signedAt: 0n
    },
    delegationGrant: {
      core: A(10), delegate: A(111), collectionId: 0n, capabilities: 117n, notBefore: 1100n, expiresAt: 2000n, maxUses: 0n, constraintsHash: ZeroHash, nonce: 1n
    },
    delegationRevocation: {
      artistId: artist, delegate: A(111), delegationRecordHash: grantHash(defaultGrant()), reasonHash: ZeroHash, nonce: 1n, deadline: 9999n
    },
    bindingRefusal: {
      ...base, bindingGeneration: 2n, bindingHash: id('binding'), reasonHash: id('reason')
    }, saleConsent: {
      ...base, saleAdapter: A(90), saleId: id('sale'), saleConfigHash: id('config')
    }, royaltyFreeze: {
      ...base, resolver: A(15), revenueClass: id('ROYALTY_ERC2981'), expectedAssignmentHash: id('assignment')
    }, contentFreeze: {
      ...base, metadataContract: A(13), lockClasses: [id('a'), id('b')].sort(), expectedStateHash: id('content')
    }, authorizationRevocation: {
      artistId: artist, revokedDigest: ZeroHash, revokedNonce: 9n, nonce: 1n, deadline: 9999n
    }
  };
  return {
    kind, chainId: d.chainId, registry: d.registry.address, caller: signer, signer, artistId: artist, mode: 'direct', signature: '0x', message: messages[kind], details: kind === 'bindingRefusal' ? { reasonURI: 'ipfs://reviewed-but-not-signed' } : kind === 'identityRevision' ? {
      identityRecordURI: 'ipfs://unsigned-revision-uri', document, displayName: 'Updated Artist'
    } : kind.startsWith("delegated") ? {
      grant: grantHash(creationGrant({ kind, artistId: artist, signer })),
      ...(kind.includes('Economics') ? { collectionId: 7n } : {}),
      ...(kind === 'delegatedProspectiveEconomicsConsent' ? { candidate: { profileHash: id('profile'), policyHash: ZeroHash, royaltyBps: 0n, frozen: false } } : {})
    } : {}, ...change
  };
}
function binding(q) {
  return [q.artistId, A(101), id('identity'), id('binding'), 2n, isDelegated(q) ? 2n : 1n, 1n, 0n, A(102), q.kind !== 'bindingRefusal'];
}
function isDelegated(q) {
  return q.kind === 'delegatedPolicyConsent' || q.kind === 'delegatedSaleConsent' || economicKinds.includes(q.kind) || isAttestation(q);
}
function isAttestation(q) {
  return q.kind === 'delegatedAttestation' || q.kind === 'delegatedScopedAttestation';
}
function isEconomics(q) {
  return q.kind === 'delegatedEconomicsConsent' || q.kind === 'delegatedProspectiveEconomicsConsent';
}
function prospectiveFact(q) {
  const m = q.message;
  return [m.resolver, m.revenueClass, m.scope, m.scopeId, m.assignmentHash];
}
function candidateEvidence(q) {
  if (q.kind !== 'delegatedProspectiveEconomicsConsent') return '0x';
  const outputs = abi.getFunction('requireProspectiveEconomicsWithEvidence').outputs;
  return coder.encode([abi.getFunction('requireProspectiveEconomicsWithEvidence').inputs[1], ...outputs],
    [q.details.candidate, prospectiveFact(q), q.message.assignmentHash === ZeroHash ? id('previous-assignment') : ZeroHash]);
}
function creationGrant(q) {
  return {
    grant: { artistId: q.artistId, delegate: q.signer, collectionId: 7n,
      capabilities: q.kind === 'delegatedPolicyConsent' ? 2n : q.kind === 'delegatedSaleConsent' ? 1024n : q.kind === 'delegatedRoyaltyFreeze' ? 32n : isAttestation(q) ? (q.message.subjectKind === 7n ? 64n : 1n) : 4n,
      notBefore: 1000n, expiresAt: 2000n, maxUses: 5n, constraintsHash: id('uninterpreted-constraints') },
    grantor: A(201), nonce: 6n, uses: 1n, revoked: false, revocationRecordHash: ZeroHash
  };
}
function grantState(record, timestamp, valid = true) {
  const g = record.grant;
  const active = valid && !record.revoked && timestamp >= g.notBefore && timestamp < g.expiresAt
    && (g.maxUses === 0n || record.uses < g.maxUses);
  return [active, g.delegate, g.collectionId, g.capabilities, g.notBefore, g.expiresAt,
    valid ? g.maxUses === 0n ? (1n << 64n) - 1n : g.maxUses - record.uses : 0n];
}
function defaultGrant() {
  return {
    grant: {
      artistId: artist, delegate: A(111), collectionId: 7n, capabilities: 117n,
      notBefore: 100n, expiresAt: 900n, maxUses: 2n, constraintsHash: ZeroHash
    },
    grantor: signer, nonce: 6n, uses: 2n, revoked: false, revocationRecordHash: ZeroHash
  };
}
function grantHash(record) {
  const g = record.grant;
  return keccak256(coder.encode(['bytes32', 'uint256', 'address', 'bytes32', 'address', 'uint256', 'uint32', 'uint64', 'uint64', 'uint64', 'bytes32', 'uint256'], [id('6529STREAM_ARTIST_DELEGATION_RECORD_V1'), d.chainId, A(8), g.artistId, g.delegate, g.collectionId,
    g.capabilities, g.notBefore, g.expiresAt, g.maxUses, g.constraintsHash, record.nonce]));
}
function effectiveDigest(q, time) {
  if ((q.kind !== 'identityRevision' && !isAttestation(q)) || q.message.signedAt !== 0n) {
    return pure.prepareCurrentArtistAction(q).payload.digest;
  }
  return pure.currentArtistOperationTypedData(q.kind, q.chainId, q.registry, {
    ...q.message, signedAt: time
  }).digest;
}
function provider(q, opt = {}) {
  const action = pure.prepareCurrentArtistAction(q);
  const calls = [];
  const reads = new Map();
  return {
    calls, async getNetwork() {
      opt.mutate?.();
      return { chainId: opt.chainId ?? d.chainId };
    }, async getBlock(n) {
      reads.set(n, (reads.get(n) ?? 0) + 1);
      return {
        number: n, hash: opt.reorg && reads.get(n) > 1 ? id('reorg') : bh(n), timestamp: 1000 + n
      };
    }, async getCode(target) {
      if (opt.code) {
        const result = opt.code(target);
        if (result !== undefined) {
          return result;
        }
      }
      return [A(20), A(30), A(40), A(41), A(42), A(43), A(44)].includes(target) || d.components.some(x => x.address === target) ? code(Number(BigInt(target))) : '0xef0100' + A(200).slice(2);
    }, async call(tx) {
      calls.push(tx);
      const desc = abi.parseTransaction({ data: tx.data });
      const name = desc.name;
      const args = desc.args;
      const tag = tx.blockTag;
      const replacement = opt.read?.(name, args, tx, action);
      if (replacement?.raw !== undefined) {
        return replacement.raw;
      }
      if (replacement !== undefined) {
        return abi.encodeFunctionResult(name, replacement);
      }
      const subjectResult = isAttestation(q) ? attestationRead(q, name, args, tx) : undefined;
      if (subjectResult !== undefined) return abi.encodeFunctionResult(name, subjectResult);
      let value;
      switch (name) {
        case 'reads': value = [A(30)]; break;
        case 'acceptedBinding':
        case 'defensiveBinding': value = [binding(q)]; break;
        case 'artistPayoutAccount': value = [payout.account, payout.recordHash]; break;
        case 'requireCurrentEconomics': value = ['0x']; break;
        case 'requireProspectiveEconomicsWithEvidence':
          value = [prospectiveFact(q), q.message.assignmentHash === ZeroHash ? id('previous-assignment') : ZeroHash];
          break;
        case 'requireRoyaltyFreezeProposal': value = []; break;
        case 'suiteConfiguration':
          value = [[A(8), A(9), Array.from({ length: 7 }, (_, i) => A(i + 1)), A(10), A(11), A(12), A(13), A(14), A(15), id('primary'), A(16)]];
          break;
        case 'deploymentChainId':
          value = [d.chainId];
          break;
        case 'core':
          value = [A(10)];
          break;
        case 'mintManager':
          value = [A(11)];
          break;
        case 'artistRegistry':
          value = [A(8)];
          break;
        case 'operationCoordinator':
          value = [A(20)];
          break;
        case 'archiveV2':
          value = [A(9)];
          break;
        case 'domainId':
          value = [domains[Number(BigInt(tx.to)) - 1]];
          break;
        case 'configurationHash':
          value = [cfg];
          break;
        case 'getSatellitePointer':
          value = args[0] === id('ROYALTY_RESOLVER')
            ? [A(15), pin(15).codeHash, false, id('ROYALTY_RESOLVER'), '0x12345678', A(80), 1, id('manifest'), id('deployment'), 1]
            : [A(8), pin(8).codeHash, false, id('ARTIST_REGISTRY'), '0x12345678', A(80), 1, id('manifest'), id('deployment'), 1];
          break;
        case 'artistRegistryCutover':
          value = [false, ZeroAddress, 0];
          break;
        case 'collectionExists':
          value = [true];
          break;
        case 'binding':
          value = [binding(q)];
          break;
        case 'attributionState':
          value = [q.kind === 'bindingRefusal' ? 1 : 2, 2];
          break;
        case 'bindingTerms':
          value = [[id('collaborators'), id('caps'), 0, 0, 0]];
          break;
        case 'acceptedCount':
          value = [0];
          break;
        case 'operativeIdentityRecord':
          value = [id('identity')];
          break;
        case 'delegationRecord':
          value = [isDelegated(q) ? creationGrant(q) : defaultGrant()];
          break;
        case 'delegationEpochState':
          value = [true, 2n, 2n];
          break;
        case 'delegationState':
          value = grantState(creationGrant(q), BigInt(1000 + tag));
          break;
        case 'delegatedNonceState':
          value = [false, 1n];
          break;
        case 'replayCell':
          value = [[ZeroHash, 0n, 0n, 0n]];
          break;
        case 'authorityState':
          value = [isDelegated(q) ? A(200) : q.signer, 1, 1, id('identity')];
          break;
        case 'gasParameterInfo':
          value = [90000, 90000, 2, 1];
          break;
        case 'artistAuthorizationState':
          value = [[false, false, false, false, 1]];
          break;
        default: if (name === action.digestMethod) {
          value = [q.kind === 'identityRevision' || isAttestation(q)
              ? pure.currentArtistOperationTypedData(q.kind, q.chainId, q.registry, {
                ...q.message, signedAt: args[1].time
              }).digest
              : action.payload.digest];
        }
        else {
          if (name === action.method) {
            value = [record({
                action, authority: { authorityClass: opt.authorityClass ?? 1n }, economics: { payout }
              }, BigInt(1000 + tag))];
          }
          else {
            throw Error('Unexpected RPC ' + name);
          }
        }
      }
      return abi.encodeFunctionResult(name, value);
    }
  };
}
const B = abi.getFunction('binding').outputs[0];
const S = '(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)';
const F = '(bytes32 artistId,address authorityAddress,uint8 authorityClass,uint8 status)';
const P = '(address signer,bytes32 digest,bool direct)';
function record(c, time, executedPayout = c.economics?.payout ?? payout) {
  const q = c.action.request;
  const m = q.message;
  const core = A(10);
  const cl = isDelegated(q) ? 2n : c.authority.authorityClass;
  const n = m.nonce;
  const common = [d.chainId, A(8)];
  if (isAttestation(q)) {
    return keccak256(coder.encode(
      ['bytes32', 'uint256', 'address', 'address', 'uint256', 'uint8', 'bytes32', 'bytes32', 'bytes32', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'],
      [id('6529STREAM_ARTIST_ATTESTATION_RECORD_V1'), ...common, core, m.collectionId, m.subjectKind,
        m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash, m.statementURIHash,
        q.artistId, q.signer, 2n, n, m.signedAt === 0n ? time : m.signedAt]
    ));
  }
  if (q.kind === 'delegationGrant') {
    const [grant] = abi.decodeFunctionData(c.action.method, c.action.call.data);
    return grantHash({
      grant, nonce: n
    });
  }
  if (isEconomics(q)) {
    return keccak256(coder.encode(
      ['bytes32', 'uint256', 'address', 'address', 'bytes32', 'uint8', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'],
      [id('6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1'), ...common, m.resolver, m.revenueClass,
        m.scope, m.scopeId, m.assignmentHash, executedPayout.recordHash, q.artistId, q.signer, 2, n, time]
    ));
  }
  const maps = {
    delegatedPolicyConsent: [['bytes32','uint256','address','address','uint256','bytes32','bytes32','bytes32','address','uint8','uint256','uint64'],
      [id('6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1'),...common,A(11),m.collectionId,m.phaseId,m.policyHash,q.artistId,q.signer,2,n,time]],
    delegatedSaleConsent: [['bytes32','uint256','address','address','address','uint256','bytes32','bytes32','bytes32','address','uint8','uint256','uint64'],
      [id('6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1'),...common,m.saleAdapter,core,m.collectionId,m.saleId,m.saleConfigHash,q.artistId,q.signer,2,n,time]],
    identityRevision: [
      ['bytes32', 'uint256', 'address', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'],
      ['0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4', ...common,
        q.artistId, m.previousRecordHash, m.revisedRecordHash, q.signer, cl, n, m.signedAt === 0n ? time : m.signedAt]
    ],
    delegationRevocation: [
      ['bytes32', 'uint256', 'address', 'bytes32', 'address', 'bytes32', 'address', 'uint8', 'bytes32', 'uint256', 'uint64'],
      [id('6529STREAM_ARTIST_DELEGATION_REVOCATION_RECORD_V1'), ...common, q.artistId, m.delegate, m.delegationRecordHash, q.signer, 1, m.reasonHash, n, time]
    ],
    bindingRefusal: [['bytes32', 'uint256', 'address', 'address', 'uint256', 'uint64', 'bytes32', 'bytes32', 'address', 'uint8', 'bytes32', 'uint256', 'uint64'], ['0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed', ...common, core, m.collectionId, m.bindingGeneration, m.bindingHash, artist, q.signer, cl, m.reasonHash, n, time]],
    saleConsent: [['bytes32', 'uint256', 'address', 'address', 'address', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1'), ...common, m.saleAdapter, core, m.collectionId, m.saleId, m.saleConfigHash, artist, q.signer, cl, n, time]],
    royaltyFreeze: [['bytes32', 'uint256', 'address', 'address', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1'), ...common, m.resolver, m.collectionId, m.revenueClass, m.expectedAssignmentHash, artist, q.signer, cl, n, time]],
    contentFreeze: [['bytes32', 'uint256', 'address', 'address', 'address', 'uint256', 'bytes32[]', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1'), ...common, m.metadataContract, core, m.collectionId, m.lockClasses, m.expectedStateHash, artist, q.signer, cl, n, time]],
    authorizationRevocation: [['bytes32', 'uint256', 'address', 'bytes32', 'bytes32', 'uint256', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1'), ...common, artist, m.revokedDigest, m.revokedNonce, n, time]]
  };
  return keccak256(coder.encode(...maps[q.kind === 'delegatedRoyaltyFreeze' ? 'royaltyFreeze' : q.kind]));
}
function mined(c, { safe = false, indexed = false, mutateArchive, afterRead, executedPayout = c.economics?.payout ?? payout, executedCandidateEvidence = c.economics?.candidateEvidence, originalRecord } = {}) {
  const q = c.action.request;
  const m = q.message;
  const tag = 11;
  const time = 1011n;
  const cl = isDelegated(q) ? 2n : c.authority.authorityClass;
  const rh = record(c, time, executedPayout);
  const fn = abi.getFunction(c.action.method);
  const decodedCall = abi.decodeFunctionData(fn, c.action.call.data);
  const t = decodedCall[0];
  const authIndex = q.kind === 'delegatedProspectiveEconomicsConsent' || q.kind === 'delegatedScopedAttestation' ? 3 : isDelegated(q) ? 2 : 1;
  const auth = decodedCall[authIndex];
  const economicsAssociation = isEconomics(q) ? [q.artistId, 2n, id('binding'), keccak256(coder.encode([fn.inputs[0]], [t])), originalRecord ?? rh] : null;
  let types = q.kind === 'authorizationRevocation' ? [fn.inputs[0], fn.inputs[1], P] : [B, fn.inputs[0], fn.inputs[1], P];
  let values = q.kind === 'authorizationRevocation' ? [t, auth, [q.signer, c.action.payload.digest, q.mode === 'direct']] : [binding(q), t, auth, [q.signer, c.action.payload.digest, q.mode === 'direct']];
  const effectiveTime = q.kind === 'identityRevision' || isAttestation(q) ? (m.signedAt === 0n ? time : m.signedAt) : time;
  const digest = effectiveDigest(q, time);
  const proof = [q.signer, digest, q.mode === 'direct'];
  if (q.kind === 'identityRevision') {
    types = [fn.inputs[0], fn.inputs[1], 'bytes', 'string', P, fn.inputs[1]];
    values = [t, auth, q.details.document, q.details.displayName, proof, [auth.nonce, effectiveTime, auth.signature]];
  }
  else {
    if (q.kind === 'delegationGrant') {
      types = [fn.inputs[0], fn.inputs[1], P];
      values = [t, auth, proof];
    }
    else {
      if (q.kind === 'delegationRevocation') {
        types = [abi.getFunction('delegationRecord').outputs[0], fn.inputs[0], fn.inputs[1], P];
        values = [c.delegation, t, auth, proof];
      }
    }
  }
  if (isAttestation(q)) {
    types = [B, fn.inputs[0], fn.inputs[authIndex], fn.inputs[authIndex], P, 'bytes', pure.CURRENT_ARTIST_ATTESTATION_SUBJECT_TUPLE,
      'bool', abi.getFunction('recordAuthenticatedAttestation').inputs[3], abi.getFunction('delegationRecord').outputs[0], 'bytes'];
    const admission = [[q.artistId, c.authority.address, 1n, c.authority.status], q.signer, m.nonce,
      effectiveTime, q.details.grant, c.attestation.operativeIdentity, c.attestation.fact];
    values = [binding(q), t, auth, [auth.nonce, effectiveTime, auth.signature], proof, q.details.statement,
      attestationDescriptor(q), q.kind === 'delegatedScopedAttestation', admission, c.delegation, c.attestation.subjectEvidence];
  }
  else if (economicKinds.includes(q.kind)) {
    const innerTypes = isEconomics(q)
      ? [B, fn.inputs[0], '(address account,bytes32 recordHash)', fn.inputs[authIndex], P, 'bytes', abi.getFunction('economicsRecordAssociation').outputs[0]]
      : [B, fn.inputs[0], fn.inputs[authIndex], P];
    const innerValues = isEconomics(q)
      ? [binding(q), t, executedPayout, auth, proof, executedCandidateEvidence, economicsAssociation]
      : [binding(q), t, auth, proof];
    types = ['bytes', 'bytes32', abi.getFunction('delegationRecord').outputs[0]];
    values = [coder.encode(innerTypes, innerValues), q.details.grant, c.delegation];
  }
  else if (isDelegated(q)) {
    types = [B,fn.inputs[0],fn.inputs[2],P,'bytes32',abi.getFunction('delegationRecord').outputs[0],'bytes'];
    const facts = q.kind === 'delegatedPolicyConsent' ? '0x'
      : coder.encode(['address','bytes32','bytes32','bytes32','bytes4','uint256','bytes32'],
        [A(80),id('registrycode'),id('adaptercode'),id('kind'),'0x12345678',m.collectionId,m.saleConfigHash]);
    values = [binding(q),t,auth,proof,q.details.grant,c.delegation,facts];
  }
  if (['bindingRefusal', 'saleConsent'].includes(q.kind)) {
    types.push(F);
    values.push([artist, q.signer, cl, c.authority.status]);
  }
  if (q.kind === 'saleConsent') {
    types.push('bytes');
    values.push(coder.encode(['address', 'bytes32', 'bytes32', 'bytes32', 'bytes4', 'uint256', 'bytes32'], [A(80), id('registrycode'), id('adaptercode'), id('kind'), '0x12345678', m.collectionId, m.saleConfigHash]));
  }
  const identityOnly = ['authorizationRevocation', 'identityRevision', 'delegationGrant', 'delegationRevocation'].includes(q.kind);
  const mask = identityOnly ? 4 : q.kind === 'bindingRefusal' ? 21 : isAttestation(q) ? 23 : isEconomics(q) ? 119 : 87;
  const writeMask = identityOnly ? 4 : q.kind === 'bindingRefusal' ? 21 : isAttestation(q) ? 20 : 68;
  const snap = after => domains.map((domain, i) => {
    const written = Boolean(after && (writeMask & (1 << i)));
    return mask & (1 << i) ? [domain, written ? 2 : 1, id('state' + i + written), id('tip' + i + written)] : [ZeroHash, 0, ZeroHash, ZeroHash];
  });
  const envelope = [1, c.configurationHash, c.action.operationId, q.caller, rh, snap(false), snap(true), coder.encode(types, values)];
  mutateArchive?.(envelope);
  const raw = coder.encode(['uint16', 'bytes32', 'uint16', 'address', 'bytes32', S + '[7]', S + '[7]', 'bytes'], envelope);
  const eid = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address', 'uint16', 'address', 'bytes32'], [id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'), d.chainId, A(8), A(20), c.action.operationId, q.caller, rh]));
  const specs = [];
  switch (q.kind) {
    case 'delegatedAttestation':
    case 'delegatedScopedAttestation':
      specs.push([A(5), 'ArtistAttestationRecorded', [1, m.collectionId, m.subjectKind, q.signer,
        m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash, m.statementURIHash, 2, m.nonce, effectiveTime, rh]],
      [A(5), 'ArtistAttestationDelegation', [1, rh, q.details.grant, q.artistId, q.signer]]);
      break;
    case 'identityRevision':
      specs.push([A(3), 'ArtistIdentityRevisionRecorded', [1, q.artistId, q.signer, m.previousRecordHash, m.revisedRecordHash, q.details.identityRecordURI, cl, m.nonce, effectiveTime, rh]], [A(3), 'ArtistIdentityDisplayNameStored', [q.artistId, m.revisedRecordHash, q.details.displayName]]);
      break;
    case 'delegationGrant':
      specs.push([A(3), 'ArtistDelegationGranted', [1, q.artistId, m.delegate, m.collectionId, m.capabilities, m.notBefore, m.expiresAt, m.maxUses, m.constraintsHash, m.nonce, rh]]);
      break;
    case 'delegationRevocation':
      specs.push([A(3), 'ArtistDelegationRevoked', [1, q.artistId, m.delegate, m.delegationRecordHash, m.reasonHash, q.signer, 1, m.nonce, time]]);
      break;
    case 'bindingRefusal':
      specs.push([A(5), 'ArtistAttributionStateChanged', [1, m.collectionId, 5, 2, 1, q.caller, cl, rh, m.reasonHash, q.details.reasonURI]], [A(5), 'ArtistBindingTerminationContext', [1, m.collectionId, 2, rh, m.bindingHash, artist, q.signer, m.nonce, time]]);
      break;
    case 'delegatedSaleConsent':
    case 'saleConsent':
      specs.push([A(7), 'ArtistSaleConsentRecorded', [1, m.collectionId, m.saleConfigHash, q.signer, m.saleId, cl, m.nonce, time, rh]]);
      break;
    case 'delegatedPolicyConsent':
      specs.push([A(7),'ArtistPolicyConsentRecorded',[1,m.collectionId,m.policyHash,q.signer,m.phaseId,2,m.nonce,time,rh]]);
      break;
    case 'delegatedEconomicsConsent':
    case 'delegatedProspectiveEconomicsConsent':
      specs.push([A(7), 'ArtistEconomicsConsentRecorded', [1, t.collectionId, t.assignmentHash, q.signer,
        t.revenueClass, t.scope, t.scopeId, executedPayout.recordHash, 2, m.nonce, time, rh]],
      [A(7), 'ArtistRecordDelegation', [1, rh, q.details.grant, q.artistId, t.resolver, t.revenueClass, 2]],
      [A(7), 'ArtistEconomicsConsentAssociated', [1, rh, q.artistId, id('binding'), 2, economicsAssociation[3], economicsAssociation[4]]]);
      break;
    case 'delegatedRoyaltyFreeze':
    case 'royaltyFreeze':
      specs.push([A(7), 'ArtistRoyaltyFreezeAuthorized', [1, m.collectionId, m.expectedAssignmentHash, q.signer, cl, m.nonce, time, rh]]);
      break;
    case 'contentFreeze':
      specs.push([A(7), 'ArtistContentFreezeAuthorized', [1, m.collectionId, q.signer, m.lockClasses, m.expectedStateHash, cl, m.nonce, time, rh]], [A(7), 'ArtistContentRecordContext', [1, rh, m.metadataContract, artist]]);
      break;
    case 'authorizationRevocation': specs.push([A(3), 'ArtistAuthorizationRevoked', [1, artist, m.revokedDigest, m.revokedNonce, m.nonce, time, rh]]);
  }
  if (q.kind === 'delegatedRoyaltyFreeze') {
    specs.push([A(7), 'ArtistRecordDelegation', [1, rh, q.details.grant, q.artistId, t.resolver, t.revenueClass, 2]]);
  }
  else if (isDelegated(q) && !isEconomics(q) && !isAttestation(q)) {
    specs.push([A(7),'ArtistConsentDelegationRecorded',[1,rh,q.details.grant,q.artistId,c.action.operationId]]);
  }
  specs.push([A(9), 'ArtistArchiveEvidenceAppendedV2', [eid, 1, keccak256(raw), A(201), (raw.length - 2) / 2]]);
  const txHash = id('tx' + q.kind);
  const logs = specs.map(([address, event, args], index) => ({
    ...abi.encodeEventLog(abi.getEvent(event), args), address, index, blockNumber: tag, blockHash: bh(tag), transactionHash: txHash, removed: false
  }));
  const safeAbi = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)', `event ExecutionSuccess(bytes32 ${indexed ? 'indexed ' : ''}txHash,uint256 payment)`]);
  if (safe) {
    logs.push({
      ...safeAbi.encodeEventLog(safeAbi.getEvent('ExecutionSuccess'), [id('safetx'), 0]), address: q.caller, index: logs.length, blockNumber: tag, blockHash: bh(tag), transactionHash: txHash, removed: false
    });
  }
  const tx = {
    hash: txHash, from: safe ? A(99) : q.caller, to: safe ? q.caller : A(8), data: safe ? safeAbi.encodeFunctionData('execTransaction', [A(8), 0, c.action.call.data, 0, 0, 0, 0, ZeroAddress, ZeroAddress, '0x']) : c.action.call.data, value: 0n, chainId: d.chainId, blockNumber: tag, blockHash: bh(tag)
  };
  const receipt = {
    hash: txHash, from: tx.from, to: tx.to, status: 1, blockNumber: tag, blockHash: bh(tag), logs
  };
  const rpc = provider(q, {
    authorityClass: c.authority.authorityClass, read(name, args, call) {
      if (call.blockTag !== tag) {
        if (name === 'requireCurrentEconomics' && c.economics) return [c.economics.candidateEvidence];
        if (name === 'artistPayoutAccount' && c.economics) return [c.economics.payout.account, c.economics.payout.recordHash];
        if (name === 'delegationRecord' && c.delegation) {
          return [c.delegation];
        }
        if (name === 'operativeIdentityRecord' && c.revision) {
          return [c.revision.operativeDocumentHash];
        }
        if (name === 'authorityState') {
          return [c.authority.address, c.authority.authorityClass, c.authority.status, c.authority.identityRecordHash];
        }
        if (name === 'currentAuthorityCapabilities') {
          return [[c.authority.address, c.authority.authorityClass, c.authority.status, 2047, id('activation')]];
        }
        return;
      }
      const replacement = afterRead?.(name, args, call);
      if (replacement !== undefined) {
        return replacement;
      }
      switch (name) {
        case 'attestationRecord': return [[rh, m.subjectStateHash, m.schemaId, m.statementHash, 2n, effectiveTime, q.signer]];
        case 'attestationAuthorityClass': return [2n];
        case 'statementBytes': return [q.details.statement];
        case 'attestationAssociation': return [[q.artistId, id('binding'), 2n, q.details.grant, c.attestation.fact]];
        case 'publicationAttestation': {
          const [, publication] = coder.decode(['uint16', pure.CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE], q.details.statement);
          return [[publication, [rh, q.artistId, id('binding'), 2n, q.signer, 2n, m.subjectKind === 7n ? 64n : 1n,
            effectiveTime, keccak256(coder.encode([pure.CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE], [publication]))], c.attestation.fact.ownerCodeHash]];
        }
        case 'designationRecord': return [[q.artistId, executedPayout.account, ZeroHash]];
        case 'economicsRecord': return [originalRecord ?? rh];
        case 'economicsRecordForBinding': return [rh];
        case 'economicsRecordAssociation':
          return [args[0] === rh ? economicsAssociation : [id('earlier-artist'), 1n, id('earlier-binding'), economicsAssociation[3], originalRecord]];
        case 'identityRevisionRecord':
          return [[rh, q.artistId, m.previousRecordHash, m.revisedRecordHash, ZeroHash, q.signer, 1, m.nonce, effectiveTime, q.details.identityRecordURI, q.details.displayName]];
        case 'identityDocumentBytes':
          return [q.details.document];
        case 'delegationRecord':
          if (isDelegated(q)) return [{ ...c.delegation, uses: c.delegation.uses + 1n }];
          return q.kind === 'delegationGrant' ? [{
              grant: t, grantor: q.signer, nonce: m.nonce, uses: 0n, revoked: false, revocationRecordHash: ZeroHash
            }]
            : [{
                ...c.delegation, revoked: true, revocationRecordHash: rh
              }];
        case 'delegatedNonceState': return [true, 2n];
        case 'recordDelegation': return [q.details.grant];
        case 'policyRecord': return [rh];
        case 'artistEvidenceMetadataV2': return [keccak256(raw), A(201), BigInt((raw.length - 2) / 2), 11n];
        case 'artistEvidenceBytesV2': return [raw];
        case 'artistAuthorizationState': return [[args[1] === digest, args[1] === m.revokedDigest && m.revokedDigest !== ZeroHash, true, args[2] === m.revokedNonce, 10n]];
        case 'bindingTermination': return [[1, m.reasonHash, rh]];
        case 'royaltyFreezeRecord': return [[rh, artist, 2]];
        case 'saleConsentRecord': return [[rh, t, artist, q.signer, cl, m.nonce, time, 2, id('binding')]];
        case 'contentFreezeAuthorization': return [[rh, artist, 2, m.metadataContract, m.lockClasses, m.expectedStateHash, cl]];
      }
    }
  });
  rpc.getTransaction = async () => tx;
  rpc.getTransactionReceipt = async () => receipt;
  return {
    rpc, tx, receipt, rh, eid, txHash
  };
}
test('all five compiled calls capture exact current authority and replay, then simulate from the actual caller', async () => {
  for (const kind of kinds) {
    const q = request(kind);
    const rpc = provider(q);
    const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    assert.equal(c.authority.address, signer);
    assert.equal(c.simulationRequired, true);
    assert.equal(c.action.operationId, {
      bindingRefusal: 3n, saleConsent: 16n, royaltyFreeze: 20n, contentFreeze: 21n, authorizationRevocation: 54n
    }[kind]);
    const result = await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
    assert.equal(result.recordHash, record(c, 1010n));
    assert.equal(rpc.calls.at(-1).from, signer);
    assert(Object.isFrozen(c.action.request.message));
  }
});
test('empty relayed ERC1271 and EIP7702 signer are accepted, while actor-authority drift and nonce reuse reject', async () => {
  const q = request('saleConsent', {
    caller: A(110), mode: 'signature'
  });
  q.message.nonce = 44n;
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  await flow.simulateCurrentArtistCall(provider(q), c, { blockTag: 10 });
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'authorityState' ? [A(111), 1, 1, id('identity')] : undefined }), d, q, { blockTag: 10 }), /authority/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'artistAuthorizationState' ? [[false, false, true, false, 1]] : undefined }), d, q, { blockTag: 10 }), /consumed/);
});
test('defensive frozen permissions remain available during contest, ordinary sale/refusal do not', async () => {
  for (const kind of kinds) {
    const q = request(kind);
    const rpc = provider(q, { read: n => n === 'authorityState' ? [signer, 1, 4, id('identity')] : n === 'attributionState' && kind !== 'bindingRefusal' ? [4, 2] : undefined });
    if (['royaltyFreeze', 'contentFreeze', 'authorizationRevocation'].includes(kind)) {
      await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    }
    else {
      await assert.rejects(flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 }), /eligible|authority/);
    }
  }
});
test('successor capabilities, exact pending generation, collaborator completion and revocation target are separate guards', async () => {
  const q = request('contentFreeze');
  const base = n => n === 'authorityState' ? [signer, 3, 3, id('identity')] : n === 'currentAuthorityCapabilities' ? [[signer, 3, 3, 0, id('activation')]] : undefined;
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: base }), d, q, { blockTag: 10 }), /capability/);
  const refusal = request('bindingRefusal');
  refusal.message.bindingGeneration = 3n;
  await assert.rejects(flow.captureCurrentArtistOperation(provider(refusal), d, refusal, { blockTag: 10 }), /pending/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'acceptedCount' ? [1] : undefined }), d, q, { blockTag: 10 }), /Collaborator/);
  const revoke = request('authorizationRevocation');
  await assert.rejects(flow.captureCurrentArtistOperation(provider(revoke, { read: (n, args) => n === 'artistAuthorizationState' && args[2] === 9n ? [[false, false, true, false, 1]] : undefined }), d, revoke, { blockTag: 10 }), /target/);
});
test('pins, exact canonical ABI, block hashes and mutable request boundaries fail closed', async () => {
  const q = request('saleConsent');
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { code: a => a === A(8) ? '0x00' : undefined }), d, q, { blockTag: 10 }), /runtime/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'collectionExists' ? { raw: '0x' + '00'.repeat(31) + '02' } : undefined }), d, q, { blockTag: 10 }), /Noncanonical/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { reorg: true }), d, q, { blockTag: 10 }), /Pinned block/);
  const mutable = structuredClone(q);
  const opts = { blockTag: 10 };
  const c = await flow.captureCurrentArtistOperation(provider(q, { mutate: () => {
      mutable.message.saleId = id('changed');
      opts.blockTag = 99;
    } }), d, mutable, opts);
  assert.equal(c.action.request.message.saleId, q.message.saleId);
  assert.equal(c.blockNumber, 10);
  const fake = structuredClone(c);
  fake.authority.address = A(99);
  await assert.rejects(flow.simulateCurrentArtistCall(provider(q), fake, { blockTag: 10 }), /facts changed/);
});
test('ordinary Safe plans preserve independent identity calls and reject unsupported metadata', async () => {
  const captures = [];
  for (const [index, kind] of kinds.entries()) {
    const q = request(kind, { artistId: id('independent-artist-' + index) });
    if (kind === 'authorizationRevocation') {
      q.message.artistId = q.artistId;
    }
    else {
      q.message.collectionId = BigInt(100 + index);
    }
    captures.push(await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 }));
  }
  const safe = flow.createCurrentArtistSafePlan(captures, 'Five independent Artist calls');
  assert.equal(safe.steps.length, 5);
  assert(safe.steps.every(x => x.transaction.operation === 0 && x.transaction.value === '0'));
  const wrong = structuredClone(captures[0]);
  wrong.action.operationId = 60n;
  assert.throws(() => flow.createCurrentArtistSafePlan([wrong], 'forged'), /differs/);
});
test('all five direct receipts join original timestamp-based record, owner events, Archive and durable readback', async () => {
  for (const kind of kinds) {
    const q = request(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    const r = mined(c);
    const out = await flow.inspectCurrentArtistReceipt(r.rpc, c, {
      transactionHash: r.txHash, execution: 'direct'
    });
    assert.equal(out.recordHash, r.rh);
    assert.equal(out.evidenceId, r.eid);
    assert.equal(out.observedReplay.nonceConsumed, true);
    assert.notEqual(record(c, q.message.deadline), out.recordHash);
  }
});
test('both Safe success layouts follow owner and Archive evidence; missing success, wrong CALL and wrong emitter reject', async () => {
  const q = request('contentFreeze');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const indexed of [false, true]) {
    const r = mined(c, {
      safe: true, indexed
    });
    await flow.inspectCurrentArtistReceipt(r.rpc, c, {
      transactionHash: r.txHash, execution: 'safe'
    });
  }
  let r = mined(c, { safe: true });
  r.receipt.logs.pop();
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'safe'
  }), /Safe success/);
  r = mined(c);
  r.receipt.logs[0].address = A(8);
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /Expected one/);
  r = mined(c);
  r.tx.data += '00';
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /CALL differs/);
});
test('receipt does not reapply new-operation readiness but rejects changed Archive and historical record facts', async () => {
  const q = request('bindingRefusal');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  let r = mined(c, { afterRead: n => n === 'artistRegistryCutover' ? [true, A(300), 11n] : n === 'authorityState' ? [A(301), 1, 1, id('new')] : undefined });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  });
  r = mined(c, { mutateArchive: v => {
      v[3] = A(300);
    } });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /envelope/);
  r = mined(c, { afterRead: n => n === 'bindingTermination' ? [[1, id('reason'), id('wrong')]] : undefined });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /Historical/);
});
test('receipt order, canonical event bytes, same-block capture and later simulation bounds reject', async () => {
  const q = request('authorizationRevocation');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  let r = mined(c, { safe: true });
  r.receipt.logs.reverse().forEach((x, i) => x.index = i);
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'safe'
  }), /precedes|follow/);
  r = mined(c);
  r.receipt.logs[0].data += '00';
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /differs/);
  r = mined(c);
  r.tx.blockNumber = 10;
  r.receipt.blockNumber = 10;
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /follow/);
  await assert.rejects(flow.simulateCurrentArtistCall(provider(q), c, { blockTag: 9 }), /predates/);
});
test('simulation binds the exact original record at the pinned timestamp', async () => {
  const q = request('royaltyFreeze');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const rpc = provider(q, { read: n => n === c.action.method ? [id('wrong-simulation-record')] : undefined });
  await assert.rejects(flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 }), /Simulated original record/);
});
test('both successor authority classes survive royalty record and receipt reconstruction', async () => {
  for (const authorityClass of [3n, 4n]) {
    const q = request('royaltyFreeze');
    const rpc = provider(q, {
      authorityClass, read: n => n === 'authorityState'
        ? [q.signer, authorityClass, 3, id('identity')]
        : n === 'currentAuthorityCapabilities' ? [[q.signer, authorityClass, 3, 2047, id('activation')]] : undefined
    });
    const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
    const r = mined(c);
    const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, {
      transactionHash: r.txHash, execution: 'direct'
    });
    assert.equal(result.recordHash, record(c, 1011n));
    assert.notEqual(result.recordHash, record({
      ...c, authority: {
        ...c.authority, authorityClass: 1n
      }
    }, 1011n));
  }
});
test('Archive snapshots enforce exact writes and unchanged read-only owners', async () => {
  const q = request('saleConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const mutateArchive of [
    v => {
      v[6][2][1] = 3n;
    },
    v => {
      v[6][0][2] = id('changed-read-only-root');
    },
    v => {
      v[6][6][3] = ZeroHash;
    },
  ]) {
    const r = mined(c, { mutateArchive });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
      transactionHash: r.txHash, execution: 'direct'
    }), /snapshot|commit|owner/i);
  }
});
test('receipt deadlines include equality and reject execution after expiry', async () => {
  for (const deadline of [1010n, 1011n]) {
    const q = request('contentFreeze');
    q.message.deadline = deadline;
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    const r = mined(c);
    const result = flow.inspectCurrentArtistReceipt(r.rpc, c, {
      transactionHash: r.txHash, execution: 'direct'
    });
    if (deadline === 1011n) {
      await result;
    }
    else {
      await assert.rejects(result, /deadline/);
    }
  }
});
test('receipt replay flags reject impossible authorization and revoked-target contradictions', async () => {
  const q = request('authorizationRevocation');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const value of [[true, true, true, false, 10n], [true, false, true, true, 10n]]) {
    const r = mined(c, { afterRead: (n, args) => n === 'artistAuthorizationState' && args[1] === c.action.payload.digest ? [value] : undefined });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
      transactionHash: r.txHash, execution: 'direct'
    }), /authorization/i);
  }
  let r = mined(c, { afterRead: (n, args) => n === 'artistAuthorizationState' && args[2] === 9n ? [[false, false, false, true, 10n]] : undefined });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /revocation/i);
  const dq = request('authorizationRevocation');
  dq.message.revokedDigest = id('target-digest');
  dq.message.revokedNonce = 0n;
  const dc = await flow.captureCurrentArtistOperation(provider(dq), d, dq, { blockTag: 10 });
  r = mined(dc);
  await flow.inspectCurrentArtistReceipt(r.rpc, dc, {
    transactionHash: r.txHash, execution: 'direct'
  });
  r = mined(dc, { afterRead: (n, args) => n === 'artistAuthorizationState' && args[1] === dq.message.revokedDigest ? [[true, true, false, false, 10n]] : undefined });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, dc, {
    transactionHash: r.txHash, execution: 'direct'
  }), /revocation/i);
});
test('Safe receipt accepts unrelated LOG0 and rejects success before the Archive append', async () => {
  const q = request('saleConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  let r = mined(c, { safe: true });
  r.receipt.logs.push({
    ...r.receipt.logs[0], address: A(400), index: r.receipt.logs.length, topics: [], data: '0x1234'
  });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'safe'
  });
  r = mined(c, { safe: true });
  const success = r.receipt.logs.pop();
  r.receipt.logs.unshift(success);
  r.receipt.logs.forEach((log, index) => {
    log.index = index;
  });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'safe'
  }), /Safe success/);
});
test('deployment code policy rejects delegated components, while public inputs have exact bounded keys', async () => {
  const q = request('saleConsent');
  const delegated = '0xef0100' + A(200).slice(2);
  const changed = structuredClone(d);
  changed.components[0].codeHash = keccak256(delegated);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { code: a => a === A(1) ? delegated : undefined }), changed, q, { blockTag: 10 }), /runtime/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q), {
    ...d, extra: true
  }, q, { blockTag: 10 }), /properties/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q), {
    ...d, registry: {
      ...d.registry, extra: true
    }
  }, q, { blockTag: 10 }), /properties/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q), {
    ...d, components: [...d.components, null]
  }, q, { blockTag: 10 }), /exactly16/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q), d, q, {
    blockTag: 10, extra: true
  }), /properties/);
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  await assert.rejects(flow.simulateCurrentArtistCall(provider(q), c, {
    blockTag: 10, extra: true
  }), /properties/);
  const r = mined(c);
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct', extra: true
  }), /properties/);
});
test('capture reconstruction preserves scalar types instead of string-coercing bigint evidence', async () => {
  const q = request('royaltyFreeze');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const forged = structuredClone(c);
  forged.authority.authorityClass = '1n';
  assert.throws(() => flow.createCurrentArtistSafePlan([forged], 'Forged evidence'), /facts changed/);
  await assert.rejects(flow.simulateCurrentArtistCall(provider(q), forged, { blockTag: 10 }), /facts changed/);
});
test('Safe plans reject shared authorization nonces and deterministic revocation conflicts', async () => {
  const captured = q => flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const sale = request('saleConsent');
  const royalty = request('royaltyFreeze');
  const first = await captured(sale);
  const second = await captured(royalty);
  assert.throws(() => flow.createCurrentArtistSafePlan([first, second], 'Same identity lane'), /Duplicate.*nonce/);
  const revoke = nonce => {
    const q = request('authorizationRevocation', {
      caller: A(110), mode: 'signature'
    });
    q.message.nonce = nonce;
    return q;
  };
  for (const digestTarget of [false, true]) {
    const a = revoke(2n);
    const b = revoke(3n);
    if (digestTarget) {
      a.message.revokedDigest = b.message.revokedDigest = id('same-target');
      a.message.revokedNonce = b.message.revokedNonce = 0n;
    }
    const ac = await captured(a);
    const bc = await captured(b);
    assert.throws(() => flow.createCurrentArtistSafePlan([ac, bc], 'Repeated revocation'), /Conflicting.*revocation/);
    const conflict = revoke(4n);
    if (digestTarget) {
      conflict.message.revokedDigest = first.action.payload.digest;
      conflict.message.revokedNonce = 0n;
    }
    else {
      conflict.message.revokedNonce = first.action.request.message.nonce;
    }
    const cc = await captured(conflict);
    for (const order of [[first, cc], [cc, first]]) {
      assert.throws(() => flow.createCurrentArtistSafePlan(order, 'Revoked listed authorization'), /Conflicting.*revocation/);
    }
  }
});
test('identity revision and grant/revocation capture their original time and replay semantics', async () => {
  for (const kind of ['identityRevision', 'delegationGrant', 'delegationRevocation']) {
    const q = request(kind);
    const rpc = provider(q);
    const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    assert.equal(c.action.operationId, {
      identityRevision: 25n, delegationGrant: 26n, delegationRevocation: 27n
    }[kind]);
    const simulation = await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
    assert.equal(simulation.recordHash, record(c, 1010n));
    assert.equal(rpc.calls.at(-1).from, q.caller);
    assert.equal(c.timing.kind, kind === 'identityRevision' ? 'dated' : kind === 'delegationGrant' ? 'nonce-only' : 'deadline');
    if (kind === 'delegationGrant') {
      assert.equal(abi.decodeFunctionData(c.action.method, c.action.call.data)[1].time, 0n);
    }
  }
});
test('direct revision zero keeps submitted payload while replay and mined proof use effective timestamps', async () => {
  const q = request('identityRevision');
  const rpc = provider(q);
  const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
  assert.equal(c.action.request.message.signedAt, 0n);
  assert.equal(c.timing.effectiveTime, 1010n);
  assert.notEqual(c.timing.effectiveDigest, c.action.payload.digest);
  const digestTimes = rpc.calls.filter(x => abi.parseTransaction({ data: x.data }).name === 'identityRevisionDigest')
    .map(x => abi.decodeFunctionData('identityRevisionDigest', x.data)[1].time);
  assert.deepEqual(digestTimes, [0n, 1010n]);
  const replayCalls = rpc.calls.filter(x => abi.parseTransaction({ data: x.data }).name === 'artistAuthorizationState');
  assert.equal(abi.decodeFunctionData('artistAuthorizationState', replayCalls[0].data)[1], c.timing.effectiveDigest);
  const simulated = await flow.simulateCurrentArtistCall(provider(q), c, { blockTag: 11 });
  assert.equal(simulated.observation.timing.effectiveTime, 1011n);
  assert.notEqual(simulated.observation.timing.effectiveDigest, c.timing.effectiveDigest);
  const r = mined(c);
  const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  });
  assert.equal(result.effectiveDigest, effectiveDigest(q, 1011n));
  assert.notEqual(result.effectiveDigest, c.action.payload.digest);
  assert.notEqual(result.effectiveDigest, c.timing.effectiveDigest);
  const revokedZero = provider(q, { read: (name, args) => name === 'artistAuthorizationState' && args[1] === c.action.payload.digest
      ? [[false, true, false, false, 1n]] : undefined });
  await flow.captureCurrentArtistOperation(revokedZero, d, q, { blockTag: 10 });
  const revokedEffective = provider(q, { read: (name, args) => name === 'artistAuthorizationState' && args[1] === c.timing.effectiveDigest
      ? [[false, true, false, false, 1n]] : undefined });
  await assert.rejects(flow.captureCurrentArtistOperation(revokedEffective, d, q, { blockTag: 10 }), /revoked/);
});
test('revision relays preserve signedAt and explicit direct dates require the exact execution time', async () => {
  const q = request('identityRevision', {
    caller: A(110), mode: 'signature'
  });
  q.message.signedAt = 900n;
  q.message.nonce = 88n;
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  assert.equal(c.timing.effectiveTime, 900n);
  const r = mined(c, { safe: true });
  const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'safe'
  });
  assert.equal(result.recordHash, record(c, 900n));
  const future = structuredClone(q);
  future.message.signedAt = 1011n;
  await assert.rejects(flow.captureCurrentArtistOperation(provider(future), d, future, { blockTag: 10 }), /timing/);
  const direct = request('identityRevision');
  direct.message.signedAt = 1010n;
  const dc = await flow.captureCurrentArtistOperation(provider(direct), d, direct, { blockTag: 10 });
  await flow.simulateCurrentArtistCall(provider(direct), dc, { blockTag: 10 });
  await assert.rejects(flow.simulateCurrentArtistCall(provider(direct), dc, { blockTag: 11 }), /timing/);
  const dr = mined(dc);
  await assert.rejects(flow.inspectCurrentArtistReceipt(dr.rpc, dc, {
    transactionHash: dr.txHash, execution: 'direct'
  }), /timing/);
});
test('revision current document and successor capability are separate from signature validity', async () => {
  const q = request('identityRevision');
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: name => name === 'operativeIdentityRecord' ? [id('changed')] : undefined }), d, q, { blockTag: 10 }), /Operative/);
  const policy = capability => ({
    authorityClass: 3n, read: name => name === 'authorityState'
      ? [signer, 3, 3, id('identity')]
      : name === 'currentAuthorityCapabilities' ? [[signer, 3, 3, capability, id('activation')]] : undefined
  });
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, policy(0n)), d, q, { blockTag: 10 }), /capability/);
  const rpc = provider(q, policy(512n));
  const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
  const r = mined(c);
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  });
  assert.equal(c.authority.authorityClass, 3n);
});
test('grant admission supports global and future scopes, strict expiry, and original living-artist class only', async () => {
  const q = request('delegationGrant');
  const rpc = provider(q);
  await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
  assert(!rpc.calls.some(x => abi.parseTransaction({ data: x.data }).name === 'binding'));
  const scoped = structuredClone(q);
  scoped.message.collectionId = 7n;
  const c = await flow.captureCurrentArtistOperation(provider(scoped), d, scoped, { blockTag: 10 });
  assert(c.binding);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(scoped, { read: name => name === 'attributionState' ? [4, 2] : undefined }), d, scoped, { blockTag: 10 }), /eligible/);
  const expired = structuredClone(q);
  expired.message.notBefore = 900n;
  expired.message.expiresAt = 1010n;
  await assert.rejects(flow.captureCurrentArtistOperation(provider(expired), d, expired, { blockTag: 10 }), /expired/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: name => name === 'authorityState' ? [signer, 3, 3, id('identity')] : undefined }), d, q, { blockTag: 10 }), /authority/);
  const global = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const rejected = provider(q, { read(name) {
      if (name === 'grantArtistDelegation') {
        throw Error('onchain conflicting delegation or forbidden capability');
      }
    } });
  await assert.rejects(flow.simulateCurrentArtistCall(rejected, global, { blockTag: 10 }), /onchain conflicting/);
});
test('revocation signs with the stored grantor after rotation while checking current defensive authority separately', async () => {
  const q = request('delegationRevocation');
  const opt = {
    authorityClass: 4n, read: name => name === 'authorityState'
      ? [A(300), 4, 4, id('identity')]
      : name === 'currentAuthorityCapabilities' ? [[A(300), 4, 4, 0, id('activation')]] : undefined
  };
  const rpc = provider(q, opt);
  const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
  assert.equal(c.authority.address, A(300));
  assert.equal(c.delegation.grantor, q.signer);
  assert(c.delegation.grant.expiresAt < c.timestamp);
  assert.equal(c.delegation.uses, c.delegation.grant.maxUses);
  await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
  const r = mined(c, {
    safe: true, indexed: true
  });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'safe'
  });
  const wrong = {
    ...q, signer: A(300), caller: A(300)
  };
  await assert.rejects(flow.captureCurrentArtistOperation(provider(wrong, opt), d, wrong, { blockTag: 10 }), /grantor/);
  const revoked = {
    ...defaultGrant(), revoked: true, revocationRecordHash: id('previous-revocation')
  };
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: name => name === 'delegationRecord' ? [revoked] : undefined }), d, q, { blockTag: 10 }), /grantor|target/);
  const contradictory = {
    ...defaultGrant(), nonce: 100n
  };
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: name => name === 'delegationRecord' ? [contradictory] : undefined }), d, q, { blockTag: 10 }), /record differs/);
});
test('all three new receipt families join exact Identity events, Archive payloads, and immutable records for direct and Safe calls', async () => {
  for (const kind of ['identityRevision', 'delegationGrant', 'delegationRevocation']) {
    const q = request(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    for (const mode of ['direct', 'safe0', 'safe1']) {
      const r = mined(c, {
        safe: mode !== 'direct', indexed: mode === 'safe1'
      });
      const out = await flow.inspectCurrentArtistReceipt(r.rpc, c, {
        transactionHash: r.txHash, execution: mode === 'direct' ? 'direct' : 'safe'
      });
      assert.equal(out.recordHash, r.rh);
      assert.equal(out.events[0].address, A(3));
      assert.equal(out.effectiveDigest, effectiveDigest(q, 1011n));
    }
  }
});
test('revision receipts tolerate later operative changes but bind original document, URI and predecessor facts', async () => {
  const q = request('identityRevision');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  let r = mined(c, { afterRead: name => name === 'operativeIdentityRecord' ? [id('later-operative')] : undefined });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  });
  r = mined(c, { afterRead: name => name === 'identityDocumentBytes' ? ['0x01'] : undefined });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  }), /document/);
  const later = structuredClone(q);
  later.message.previousRecordHash = id('prior-revised-document');
  const lc = await flow.captureCurrentArtistOperation(provider(later, { read: name => name === 'operativeIdentityRecord' ? [later.message.previousRecordHash] : undefined }), d, later, { blockTag: 10 });
  r = mined(lc);
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, lc, {
    transactionHash: r.txHash, execution: 'direct'
  }), /Zero revision predecessor/);
  const predecessor = id('prior-revision');
  const readback = (name, args) => name !== 'identityRevisionRecord' ? undefined : args[0] === predecessor
    ? [[predecessor, artist, id('identity'), later.message.previousRecordHash, ZeroHash, signer, 1, 99, 900, '', 'prior']]
    : [[record(lc, 1011n), artist, later.message.previousRecordHash, later.message.revisedRecordHash, predecessor, signer, 1, 1, 1011, later.details.identityRecordURI, later.details.displayName]];
  r = mined(lc, { afterRead: readback });
  await flow.inspectCurrentArtistReceipt(r.rpc, lc, {
    transactionHash: r.txHash, execution: 'direct'
  });
  r = mined(lc, { afterRead: (name, args) => {
      const result = readback(name, args);
      if (result && args[0] === predecessor) {
        result[0][3] = id('wrong-predecessor-document');
      }
      return result;
    } });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, lc, {
    transactionHash: r.txHash, execution: 'direct'
  }), /predecessor/);
});
test('grant receipts allow later same-block use and revocation without changing the original grant evidence', async () => {
  const q = request('delegationGrant');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const [grant] = abi.decodeFunctionData(c.action.method, c.action.call.data);
  const r = mined(c, { afterRead: name => name === 'delegationRecord' ? [{
        grant, grantor: signer, nonce: 1n, uses: 55n, revoked: true, revocationRecordHash: id('later-revocation')
      }] : undefined });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  });
  const bad = mined(c, { afterRead: name => name === 'delegationRecord' ? [{
        grant, grantor: A(400), nonce: 1n, uses: 0n, revoked: false, revocationRecordHash: ZeroHash
      }] : undefined });
  await assert.rejects(flow.inspectCurrentArtistReceipt(bad.rpc, c, {
    transactionHash: bad.txHash, execution: 'direct'
  }), /grant differs/);
});
test('Safe replay checks distinguish the direct-zero submitted digest from its unknown future effective digest', async () => {
  const q = request('identityRevision');
  const revision = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const rq = request('authorizationRevocation', {
    caller: A(110), mode: 'signature'
  });
  rq.message.nonce = 2n;
  rq.message.revokedNonce = 0n;
  rq.message.revokedDigest = revision.action.payload.digest;
  const revoke = await flow.captureCurrentArtistOperation(provider(rq), d, rq, { blockTag: 10 });
  assert.equal(flow.createCurrentArtistSafePlan([revision, revoke], 'Distinct nonce lanes').steps.length, 2);
  const grant = request('delegationGrant');
  const grantCapture = await flow.captureCurrentArtistOperation(provider(grant), d, grant, { blockTag: 10 });
  assert.throws(() => flow.createCurrentArtistSafePlan([revision, grantCapture], 'Same nonce lane'), /Duplicate/);
});
test('Safe plans reject duplicate permanent delegation revocation targets across distinct authorization nonces', async () => {
  const first = request('delegationRevocation', {
    caller: A(110), mode: 'signature'
  });
  const second = structuredClone(first);
  second.message.nonce = 2n;
  const captures = await Promise.all([first, second].map(q => flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 })));
  assert.throws(() => flow.createCurrentArtistSafePlan(captures, 'Duplicate grant revocation'), /Repeated delegation/);
});
test('revocation receipt joins actual pre-revocation uses without attributing prior same-block uses to this call', async () => {
  const prior = defaultGrant();
  prior.grant.maxUses = 0n;
  prior.uses = 1n;
  const q = request('delegationRevocation');
  q.message.delegationRecordHash = grantHash(prior);
  const c = await flow.captureCurrentArtistOperation(provider(q, { read: name => name === 'delegationRecord' ? [prior] : undefined }), d, q, { blockTag: 10 });
  const type = abi.getFunction('delegationRecord').outputs[0];
  const fn = abi.getFunction('revokeArtistDelegation');
  const layout = [type, fn.inputs[0], fn.inputs[1], P];
  const modify = v => {
    const decoded = coder.decode(layout, v[7]);
    v[7] = coder.encode(layout, [{
        ...prior, uses: 2n
      }, decoded[1], decoded[2], decoded[3]]);
  };
  const r = mined(c, {
    mutateArchive: modify, afterRead: name => name === 'delegationRecord'
      ? [{
          ...prior, uses: 2n, revoked: true, revocationRecordHash: record(c, 1011n)
        }] : undefined
  });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, {
    transactionHash: r.txHash, execution: 'direct'
  });
  const bad = mined(c, { mutateArchive: modify });
  await assert.rejects(flow.inspectCurrentArtistReceipt(bad.rpc, c, {
    transactionHash: bad.txHash, execution: 'direct'
  }), /prior delegation/);
  const changed = provider(q, { read: (name, args, tx) => name === 'delegationRecord'
      ? [{
          ...prior, uses: tx.blockTag === 10 ? 1n : 2n
        }] : undefined });
  await assert.rejects(flow.simulateCurrentArtistCall(changed, c, { blockTag: 11 }), /Delegation state changed/);
});
test('new timing and delegation snapshots are copied before awaits and reject contradictory RPC or forged capture labels', async () => {
  const original = request('identityRevision');
  const mutable = structuredClone(original);
  const c = await flow.captureCurrentArtistOperation(provider(original, { mutate: () => {
      mutable.message.signedAt = 123n;
      mutable.details.displayName = 'changed after entry';
    } }), d, mutable, { blockTag: 10 });
  assert.equal(c.action.request.message.signedAt, 0n);
  assert.equal(c.action.request.details.displayName, original.details.displayName);
  assert(Object.isFrozen(c.timing));
  assert(Object.isFrozen(c.revision));
  const forged = structuredClone(c);
  forged.timing.effectiveTime = '1010n';
  await assert.rejects(flow.simulateCurrentArtistCall(provider(original), forged, { blockTag: 10 }), /facts changed/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(original, { read: (name, args) => name === 'identityRevisionDigest' && args[1].time === 1010n ? [id('wrong-effective')] : undefined }), d, original, { blockTag: 10 }), /Effective.*digest/);
  const revoke = request('delegationRevocation');
  const encoded = abi.encodeFunctionResult('delegationRecord', [defaultGrant()]);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(revoke, { read: name => name === 'delegationRecord' ? { raw: encoded + '00' } : undefined }), d, revoke, { blockTag: 10 }), /Noncanonical|invalid length/);
});

test('delegated policy and sale use mode2, the living principal and the independent delegate nonce lane', async () => {
  for (const kind of ['delegatedPolicyConsent', 'delegatedSaleConsent']) {
    const q = request(kind);
    const rpc = provider(q, { read: name => name === 'artistAuthorizationState' ? [[true, false, true, true, 999n]] : undefined });
    const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    assert.equal(c.authority.address, A(200));
    assert.equal(c.authority.authorityClass, 1n);
    assert.equal(c.delegation.grantor, A(201));
    assert.equal(c.delegation.grant.delegate, q.signer);
    assert.equal(c.binding.consentMode, 2n);
    assert.equal(c.delegated.nextUnusedNonce, 1n);
    assert.equal(c.replay.nextUnusedNonce, 999n);
    assert.equal(c.action.operationId, kind === 'delegatedPolicyConsent' ? 14n : 16n);
    const result = await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
    assert.equal(result.recordHash, record(c, 1010n));
    assert.equal(rpc.calls.at(-1).from, q.caller);
  }
});

test('delegated class2 receipts bind the original record, Consent association, Archive, and consumed delegate lane', async () => {
  for (const kind of ['delegatedPolicyConsent', 'delegatedSaleConsent']) {
    const q = request(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    for (const mode of ['direct', 'safe0', 'safe1']) {
      const r = mined(c, { safe: mode !== 'direct', indexed: mode === 'safe1', afterRead: name => name === 'artistAuthorizationState'
        ? [[true, false, false, true, 999n]] : undefined });
      const out = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: mode === 'direct' ? 'direct' : 'safe' });
      assert.equal(out.recordHash, r.rh);
      assert.equal(out.observedDelegated.nonceUsed, true);
      assert.equal(out.observedReplay.nonceConsumed, false);
      assert.equal(out.events[1].event, 'ArtistConsentDelegationRecorded');
      assert.equal(out.events[1].address, A(7));
    }
  }
});

function grantProvider(q, grant, extra) {
  return provider(q, { read(name, args, tx) {
    const value = extra?.(name, args, tx);
    if (value !== undefined) return value;
    if (name === 'delegationRecord') return [grant];
    if (name === 'delegationState') return grantState(grant, BigInt(1000 + tx.blockTag));
  } });
}

test('delegated creation independently rejects grant window, scope, capability, epoch, and persistent lane failures', async () => {
  for (const kind of ['delegatedPolicyConsent', 'delegatedSaleConsent']) {
    for (const mutate of [
      g => { g.grant.notBefore = 1011n; },
      g => { g.grant.expiresAt = 1010n; },
      g => { g.uses = g.grant.maxUses; },
      g => { g.revoked = true; g.revocationRecordHash = id('revoked'); },
      g => { g.grant.collectionId = 99n; },
      g => { g.grant.capabilities = kind === 'delegatedPolicyConsent' ? 1024n : 2n; },
    ]) {
      const q = request(kind);
      const grant = creationGrant(q);
      mutate(grant);
      q.details.grant = grantHash(grant);
      await assert.rejects(flow.captureCurrentArtistOperation(grantProvider(q, grant), d, q, { blockTag: 10 }), /scope, capability or live window/);
    }
    const q = request(kind);
    for (const [name, output, error] of [
      ['delegationEpochState', [false, 2n, 3n], /epoch/],
      ['delegationState', [true, signer, 7n, kind === 'delegatedPolicyConsent' ? 2n : 1024n, 1000n, 2000n, 999n], /state differs/],
      ['delegatedNonceState', [true, 2n], /Delegate authorization/],
      ['delegatedNonceState', [false, 2n], /direct nonce/],
      ['replayCell', [[id('deny'), 1n, 1n, 2n]], /revoked/],
      ['artistAuthorizationState', [[true, true, false, false, 1n]], /Artist authorization/],
      ['authorityState', [A(200), 1n, 4n, id('identity')], /authority/],
      ['authorityState', [A(200), 3n, 3n, id('identity')], /authority/],
    ]) {
      await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === name ? output : undefined }), d, q, { blockTag: 10 }), error);
    }
  }
});

test('delegate replay derives the exact owner denial key and permits unused arbitrary relay nonce with empty ERC1271 proof', async () => {
  const q = request('delegatedSaleConsent', { caller: A(110), mode: 'signature' });
  q.message.nonce = 777n;
  const rpc = provider(q);
  const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
  await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
  const lane = keccak256(coder.encode(['bytes32','bytes32','address'], [id('6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1'), artist, q.signer]));
  const scope = keccak256(coder.encode(['bytes32','bytes32'], [lane, c.action.payload.digest]));
  const expected = keccak256(coder.encode(['bytes32','uint256','address','address','address','address','bytes32','bytes32','bytes32'],
    [id('6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2'), d.chainId, A(8), A(20), A(9), A(3), domains[2], id('identity_authority.replay.delegated_digest_revocation'), scope]));
  const reads = rpc.calls.filter(tx => abi.parseTransaction({ data: tx.data }).name === 'replayCell');
  assert(reads.every(tx => tx.to === A(3) && abi.decodeFunctionData('replayCell', tx.data)[0] === expected));
  assert(c.replay.digestObserved === false);
  assert.equal(c.delegated.nextUnusedNonce, 1n);
});

test('policy creation omits sale-only collaborator requirements, while principal sale/content accept modes1or2', async () => {
  const policy = request('delegatedPolicyConsent');
  const rpc = provider(policy, { read(name) {
    if (name === 'bindingTerms' || name === 'acceptedCount') throw Error('Policy must not read collaborator terms');
  } });
  await flow.captureCurrentArtistOperation(rpc, d, policy, { blockTag: 10 });
  const sale = request('delegatedSaleConsent');
  await assert.rejects(flow.captureCurrentArtistOperation(provider(sale, { read: name => name === 'bindingTerms' ? [[id('collaborators'), id('caps'), 1, 1, 1]] : undefined }), d, sale, { blockTag: 10 }), /Collaborator/);
  for (const kind of ['saleConsent', 'contentFreeze']) {
    const q = request(kind);
    const b = binding(q);
    b[5] = 2n;
    const rpc = provider(q, { read: name => name === 'binding' ? [b] : undefined });
    const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
  }
  const b = binding(policy);
  b[5] = 1n;
  await assert.rejects(flow.captureCurrentArtistOperation(provider(policy, { read: name => name === 'binding' ? [b] : undefined }), d, policy, { blockTag: 10 }), /mode 2/);
});

test('delegated receipts reject wrong association, unused nonce, insufficient use increment and nonempty policy facts', async () => {
  const q = request('delegatedPolicyConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const [name, output, error] of [
    ['recordDelegation', [id('other-grant')], /association/],
    ['delegatedNonceState', [false, 1n], /delegate authorization/],
    ['delegationRecord', [c.delegation], /consumption readback/],
    ['policyRecord', [id('wrong-record')], /Historical policy/],
  ]) {
    const r = mined(c, { afterRead: n => n === name ? output : undefined });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), error);
  }
  let r = mined(c);
  r.receipt.logs = r.receipt.logs.filter(log => log.topics[0] !== abi.getEvent('ArtistConsentDelegationRecorded').topicHash);
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), /Expected one ArtistConsentDelegationRecorded/);
  const fn = abi.getFunction(c.action.method);
  const layout = [B, fn.inputs[0], fn.inputs[2], P, 'bytes32', abi.getFunction('delegationRecord').outputs[0], 'bytes'];
  r = mined(c, { mutateArchive(v) {
    const decoded = Array.from(coder.decode(layout, v[7]));
    decoded[6] = '0x01';
    v[7] = coder.encode(layout, decoded);
  } });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), /facts must be empty/);
});

test('delegated receipt permits later uses/revocation and rejects swapped or nonlive original Archive grant', async () => {
  const q = request('delegatedSaleConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const later = { ...c.delegation, uses: 5n, revoked: true, revocationRecordHash: id('later-revocation') };
  const r = mined(c, { afterRead: name => name === 'delegationRecord' ? [later] : name === 'delegationEpochState'
    ? [false, 2, 3] : undefined });
  await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' });
  const fn = abi.getFunction(c.action.method);
  const layout = [B, fn.inputs[0], fn.inputs[2], P, 'bytes32', abi.getFunction('delegationRecord').outputs[0], 'bytes'];
  for (const changed of [{ ...c.delegation, uses: 5n }, { ...c.delegation, grantor: A(444) }]) {
    const bad = mined(c, { mutateArchive(v) {
      const decoded = Array.from(coder.decode(layout, v[7]));
      decoded[5] = changed;
      v[7] = coder.encode(layout, decoded);
    } });
    await assert.rejects(flow.inspectCurrentArtistReceipt(bad.rpc, c, { transactionHash: bad.txHash, execution: 'direct' }), /Archive delegated consent grant/);
  }
});

test('Safe plans distinguish Artist and delegate nonce lanes, retain digest denial across lanes and persist delegate lanes across grants', async () => {
  const policy = request('delegatedPolicyConsent');
  const pc = await flow.captureCurrentArtistOperation(provider(policy), d, policy, { blockTag: 10 });
  const principal = request('authorizationRevocation');
  const ac = await flow.captureCurrentArtistOperation(provider(principal), d, principal, { blockTag: 10 });
  assert.equal(flow.createCurrentArtistSafePlan([pc, ac], 'Separate nonce lanes').steps.length, 2);
  const sale = request('delegatedSaleConsent');
  const sc = await flow.captureCurrentArtistOperation(provider(sale), d, sale, { blockTag: 10 });
  assert.throws(() => flow.createCurrentArtistSafePlan([pc, sc], 'Same delegate lane'), /Duplicate/);
  const other = request('delegatedSaleConsent', { caller: A(222), signer: A(222) });
  other.details.grant = grantHash(creationGrant(other));
  const oc = await flow.captureCurrentArtistOperation(provider(other), d, other, { blockTag: 10 });
  assert.equal(flow.createCurrentArtistSafePlan([pc, oc], 'Different delegate lanes').steps.length, 2);
  const deny = request('authorizationRevocation');
  deny.message.revokedNonce = 0n;
  deny.message.revokedDigest = pc.action.payload.digest;
  const dc = await flow.captureCurrentArtistOperation(provider(deny), d, deny, { blockTag: 10 });
  assert.throws(() => flow.createCurrentArtistSafePlan([pc, dc], 'Artist digest denial'), /Conflicting/);
});

test('Safe plans allow durable consent before grant revocation and reject the opposite order', async () => {
  const q = request('delegatedPolicyConsent');
  const grant = creationGrant(q);
  const consent = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const revoke = request('delegationRevocation', { caller: grant.grantor, signer: grant.grantor });
  revoke.message.delegate = q.signer;
  revoke.message.delegationRecordHash = q.details.grant;
  const revoked = await flow.captureCurrentArtistOperation(grantProvider(revoke, grant), d, revoke, { blockTag: 10 });
  assert.equal(flow.createCurrentArtistSafePlan([consent, revoked], 'Consent remains durable').steps.length, 2);
  assert.throws(() => flow.createCurrentArtistSafePlan([revoked, consent], 'Revoked before use'), /follows its grant revocation/);
});

function recordedRequest(c) {
  const q = c.action.request;
  const m = q.message;
  return q.kind === 'delegatedPolicyConsent'
    ? { kind: 'policy', collectionId: m.collectionId, phaseId: m.phaseId, policyHash: m.policyHash, recordHash: record(c, 1011n) }
    : { kind: 'sale', collectionId: m.collectionId, saleAdapter: m.saleAdapter, saleId: m.saleId, saleConfigHash: m.saleConfigHash, recordHash: record(c, 1011n) };
}
function recordedProvider(c, override, mutate) {
  const q = c.action.request;
  const wanted = recordedRequest(c);
  const terms = abi.decodeFunctionData(c.action.method, c.action.call.data)[0];
  return provider(q, { mutate, read(name, args, tx) {
    const value = override?.(name, args, tx);
    if (value !== undefined) return value;
    if (['delegationRecord','delegationState','delegationEpochState','delegatedNonceState','artistAuthorizationState'].includes(name)) {
      throw Error('Recorded consent must not revalidate creation grant/replay');
    }
    if (name === 'policyRecord' || name === 'saleConsentAt') return [wanted.recordHash];
    if (name === 'recordDelegation') return [isDelegated(q) ? q.details.grant : ZeroHash];
    if (name === 'saleConsentRecord') return [[wanted.recordHash, terms, q.artistId, q.signer,
      isDelegated(q) ? 2n : c.authority.authorityClass, q.message.nonce, 1011, 2, id('binding')]];
    if (name === 'requireSaleConsent') {
      assert.equal(tx.from, q.message.saleAdapter);
      assert.equal(tx.to, A(8));
      return [];
    }
  } });
}

test('recorded policy observation is explicitly record-only and recorded sale checks exact adapter caller without live grant reads', async () => {
  for (const kind of ['delegatedPolicyConsent','delegatedSaleConsent']) {
    const q = request(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    const rpc = recordedProvider(c);
    const result = await flow.inspectCurrentArtistRecordedConsent(rpc, d, recordedRequest(c), { blockTag: 3000 });
    assert.equal(result.delegationRecordHash, q.details.grant);
    assert.equal(result.applicability, kind === 'delegatedPolicyConsent' ? 'policy-record-only' : 'sale-consent-checked-for-adapter');
    if (kind === 'delegatedSaleConsent') assert.equal(result.checkedCall.from, q.message.saleAdapter);
    else assert.equal(result.checkedCall, null);
    assert(Object.isFrozen(result.request));
    assert.equal(result.timestamp, 4000n);
  }
});

test('recorded consent checks malformed void returns, missing association, mismatched identity and underlying current-admission failure', async () => {
  const q = request('delegatedSaleConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const req = recordedRequest(c);
  for (const [name, output, pattern] of [
    ['saleConsentAt', [id('wrong-consent')], /identity differs/],
    ['recordDelegation', [ZeroHash], /delegation differ/],
    ['requireSaleConsent', { raw: '0x00' }, /Noncanonical/],
  ]) {
    await assert.rejects(flow.inspectCurrentArtistRecordedConsent(recordedProvider(c, n => n === name ? output : undefined), d, req, { blockTag: 3000 }), pattern);
  }
  await assert.rejects(flow.inspectCurrentArtistRecordedConsent(recordedProvider(c, name => {
    if (name === 'requireSaleConsent') throw Error('Original adapter admission rejects changed facts');
  }), d, req, { blockTag: 3000 }), /Original adapter admission/);
  const mutable = structuredClone(req);
  const options = { blockTag: 3000 };
  const result = await flow.inspectCurrentArtistRecordedConsent(recordedProvider(c, undefined, () => {
    mutable.saleAdapter = A(444);
    options.blockTag = 9000;
  }), d, mutable, options);
  assert.equal(result.request.saleAdapter, q.message.saleAdapter);
  assert.equal(result.blockNumber, 3000);
  await assert.rejects(flow.inspectCurrentArtistRecordedConsent(recordedProvider(c), d, { ...req, grant: q.details.grant }, { blockTag: 3000 }), /properties/);
});

test('recorded sale hashes bind every retained signer, class, nonce and time field', async () => {
  const q = request('delegatedSaleConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const req = recordedRequest(c);
  const terms = abi.decodeFunctionData(c.action.method, c.action.call.data)[0];
  const valid = [req.recordHash, terms, q.artistId, q.signer, 2n, q.message.nonce, 1011n, 2n, id('binding')];
  for (const [index, value] of [[2, id('another-artist')], [3, A(777)], [4, 1n], [5, 999n], [6, 1012n]]) {
    const forged = [...valid];
    forged[index] = value;
    const rpc = recordedProvider(c, name => name === 'saleConsentRecord' ? [forged] : undefined);
    await assert.rejects(flow.inspectCurrentArtistRecordedConsent(rpc, d, req, { blockTag: 3000 }), /terms or delegation differ/);
  }
});

test('recorded sale format supports principal classes with zero association; class4 scope0 read is not creation evidence', async () => {
  const q = request('saleConsent');
  const base = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const authorityClass of [1n, 3n, 4n]) {
    // This supplies historical record-format fixtures, not reachable native creation evidence.
    const c = { ...base, authority: { ...base.authority, authorityClass } };
    const req = recordedRequest(c);
    const checked = await flow.inspectCurrentArtistRecordedConsent(recordedProvider(c), d, req, { blockTag: 3000 });
    assert.equal(checked.delegationRecordHash, ZeroHash);
    const associated = recordedProvider(c, name => name === 'recordDelegation' ? [id('spurious-grant')] : undefined);
    await assert.rejects(flow.inspectCurrentArtistRecordedConsent(associated, d, req, { blockTag: 3000 }), /delegation differ/);
    if (authorityClass === 4n) {
      const scope1 = recordedProvider(c, name => {
        if (name === 'requireSaleConsent') throw Error('Original scope1 rejects class4');
      });
      await assert.rejects(flow.inspectCurrentArtistRecordedConsent(scope1, d, req, { blockTag: 3000 }), /scope1 rejects class4/);
    }
  }
  for (const authorityClass of [0n, 5n]) {
    const malformed = { ...base, authority: { ...base.authority, authorityClass } };
    await assert.rejects(flow.inspectCurrentArtistRecordedConsent(recordedProvider(malformed), d,
      recordedRequest(malformed), { blockTag: 3000 }), /delegation differ/);
  }
});

test('delegated economics and freeze capture pinned Reads evidence and simulate the exact actual caller', async () => {
  for (const kind of economicKinds) {
    const q = request(kind);
    const rpc = provider(q);
    const c = await flow.captureCurrentArtistOperation(rpc, economicsDeployment, q, { blockTag: 10 });
    assert.equal(c.action.operationId, kind === 'delegatedRoyaltyFreeze' ? 20n : 15n);
    assert.equal(c.authority.address, A(200));
    assert.notEqual(c.delegation.grantor, c.authority.address);
    assert.equal(c.delegation.grant.capabilities, kind === 'delegatedRoyaltyFreeze' ? 32n : 4n);
    assert.equal(c.economics?.payout.recordHash ?? null, isEconomics(q) ? payout.recordHash : null);
    assert.equal(c.economics?.candidateEvidence, isEconomics(q) ? candidateEvidence(q) : undefined);
    const result = await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
    assert.equal(result.recordHash, record(c, 1010n));
    assert.equal(rpc.calls.at(-1).from, q.caller);
    assert.equal(rpc.calls.at(-1).blockTag, 10);
    assert(Object.isFrozen(c.deployment.reads));
    if (c.economics) assert(Object.isFrozen(c.economics.payout));
    if (kind === 'delegatedRoyaltyFreeze') {
      assert(!rpc.calls.some(tx => abi.parseTransaction(tx).name === 'artistPayoutAccount'));
    }
  }
});

test('Reads runtime, Coordinator binding, selected royalty resolver and exact canonical returns fail closed', async () => {
  const q = request('delegatedRoyaltyFreeze');
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 }), /Reads runtime pin/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'reads' ? [A(31)] : undefined }), economicsDeployment, q, { blockTag: 10 }), /Reads binding/);
  const delegatedCode = '0xef0100' + A(31).slice(2);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { code: a => a === A(30) ? delegatedCode : undefined }), {
    ...economicsDeployment, reads: { address: A(30), codeHash: keccak256(delegatedCode) }
  }, q, { blockTag: 10 }), /runtime/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: (n, args) => n === 'getSatellitePointer' && args[0] === id('ROYALTY_RESOLVER')
    ? [A(31), pin(31).codeHash, false, id('ROYALTY_RESOLVER'), '0x12345678', A(80), 1, id('manifest'), id('deployment'), 1] : undefined
  }), economicsDeployment, q, { blockTag: 10 }), /not selected/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'requireRoyaltyFreezeProposal' ? { raw: ZeroHash } : undefined }), economicsDeployment, q, { blockTag: 10 }), /Noncanonical/);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'defensiveBinding' ? [[...binding(q).slice(0, 3), id('different-binding'), ...binding(q).slice(4)]] : undefined }), economicsDeployment, q, { blockTag: 10 }), /Reads binding/);
  const wrongResolver = request('delegatedEconomicsConsent');
  wrongResolver.message.resolver = A(90);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(wrongResolver), economicsDeployment, wrongResolver, { blockTag: 10 }), /resolver differs/);
});

test('new delegated routes admit modes1or2, freeze grant32 and defensive status4 without widening economics authority', async () => {
  for (const kind of economicKinds) {
    const q = request(kind);
    for (const mode of [1n, 2n]) {
      const b = binding(q); b[5] = mode;
      const rpc = provider(q, { read: n => ['binding', 'acceptedBinding', 'defensiveBinding'].includes(n) ? [b] : undefined });
      await flow.captureCurrentArtistOperation(rpc, economicsDeployment, q, { blockTag: 10 });
    }
    for (const mode of [0n, 3n]) {
      const b = binding(q); b[5] = mode;
      await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'binding' ? [b] : undefined }), economicsDeployment, q, { blockTag: 10 }), /mode 1 or 2/);
    }
    const contested = provider(q, { read: n => n === 'authorityState' ? [A(200), 1n, 4n, id('identity')] : n === 'attributionState' ? [4n, 2n] : undefined });
    if (kind === 'delegatedRoyaltyFreeze') {
      await flow.captureCurrentArtistOperation(contested, economicsDeployment, q, { blockTag: 10 });
    } else {
      await assert.rejects(flow.captureCurrentArtistOperation(contested, economicsDeployment, q, { blockTag: 10 }), /eligible/);
    }
  }
  const q = request('delegatedRoyaltyFreeze');
  const wrongGrant = creationGrant(q); wrongGrant.grant.capabilities = 16n;
  q.details.grant = grantHash(wrongGrant);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'delegationRecord' ? [wrongGrant] : undefined }), economicsDeployment, q, { blockTag: 10 }), /capability/);
});

test('current economics retains opaque provider evidence while exact write simulation remains authoritative', async () => {
  for (const [resolver, revenueClass, scope, evidence] of [
    [A(14), id('primary'), 0n, '0x'],
    [A(14), id('primary'), 1n, coder.encode(['bytes32', 'bytes'], [id('template-test-evidence'), '0x1234'])],
    [A(15), id('ROYALTY_ERC2981'), 1n, coder.encode(['bytes32', 'bytes'], [id('snapshot-test-evidence'), '0x5678'])]
  ]) {
    const q = request('delegatedEconomicsConsent');
    Object.assign(q.message, { resolver, revenueClass, scope, scopeId: scope === 0n ? 0n : 7n });
    const rpc = provider(q, { read: n => n === 'requireCurrentEconomics' ? [evidence] : undefined });
    const c = await flow.captureCurrentArtistOperation(rpc, economicsDeployment, q, { blockTag: 10 });
    assert.equal(c.economics.candidateEvidence, evidence);
    assert.equal(c.simulationRequired, true);
    const rejected = provider(q, { read: n => {
      if (n === 'requireCurrentEconomics') return [evidence];
      if (n === c.action.method) throw Error('Original producer rejects replay/admission');
    } });
    await assert.rejects(flow.simulateCurrentArtistCall(rejected, c, { blockTag: 10 }), /producer rejects/);
  }
});

test('prospective clear preserves zero assignment and exact candidate/fact/previousHash evidence', async () => {
  const q = request('delegatedProspectiveEconomicsConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
  assert.equal(c.economics.candidateEvidence, candidateEvidence(q));
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'requireProspectiveEconomicsWithEvidence' ? [prospectiveFact(q), id('impossible-previous')] : undefined }), economicsDeployment, q, { blockTag: 10 }), /Prospective economics evidence/);
  q.message.assignmentHash = ZeroHash;
  q.details.candidate = { profileHash: ZeroHash, policyHash: ZeroHash, royaltyBps: 0n, frozen: false };
  const cleared = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
  await flow.simulateCurrentArtistCall(provider(q), cleared, { blockTag: 10 });
  const r = mined(cleared);
  const out = await flow.inspectCurrentArtistReceipt(r.rpc, cleared, { transactionHash: r.txHash, execution: 'direct' });
  assert.equal(out.economics.candidateEvidence, candidateEvidence(q));
  for (const returned of [[prospectiveFact(q), ZeroHash], [[A(90), ...prospectiveFact(q).slice(1)], id('old')]]) {
    await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: n => n === 'requireProspectiveEconomicsWithEvidence' ? returned : undefined }), economicsDeployment, q, { blockTag: 10 }), /Prospective economics evidence/);
  }
});

test('economics admission snapshots inputs before awaits and rejects payout/evidence drift during refresh', async () => {
  const q = request('delegatedProspectiveEconomicsConsent');
  const mutable = structuredClone(q);
  const pins = structuredClone(economicsDeployment);
  const c = await flow.captureCurrentArtistOperation(provider(q, { mutate: () => {
    mutable.details.candidate.profileHash = id('changed');
    pins.reads.address = A(99);
  } }), pins, mutable, { blockTag: 10 });
  assert.equal(c.action.request.details.candidate.profileHash, q.details.candidate.profileHash);
  assert.equal(c.deployment.reads.address, A(30));
  const drift = provider(q, { read: (n, args, tx) => n === 'artistPayoutAccount' && tx.blockTag === 11 ? [A(151), id('new-payout')] : undefined });
  await assert.rejects(flow.simulateCurrentArtistCall(drift, c, { blockTag: 11 }), /Economics admission facts changed/);
  const forged = structuredClone(c); forged.economics.payout.recordHash = id('forged');
  assert.throws(() => flow.createCurrentArtistSafePlan([forged], 'forged'), /facts changed/);
  const current = request('delegatedEconomicsConsent');
  for (const result of [[ZeroAddress, payout.recordHash], [payout.account, ZeroHash]]) {
    await assert.rejects(flow.captureCurrentArtistOperation(provider(current, { read: n => n === 'artistPayoutAccount' ? result : undefined }), economicsDeployment, current, { blockTag: 10 }), /Zero address|bytes32/);
  }
});

test('all three economics/freeze routes join direct and both Safe event layouts with nested original Archive', async () => {
  for (const kind of economicKinds) {
    const q = request(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
    for (const options of [{}, { safe: true }, { safe: true, indexed: true }]) {
      const r = mined(c, options);
      const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: options.safe ? 'safe' : 'direct' });
      assert.equal(result.recordHash, r.rh);
      assert.equal(result.observedDelegated.nonceUsed, true);
      assert(result.events.some(e => e.event === 'ArtistRecordDelegation'));
      assert(!result.events.some(e => e.event === 'ArtistConsentDelegationRecorded'));
      if (isEconomics(q)) assert.equal(result.economics.association.originalRecord, r.rh);
      else assert.equal(result.economics, null);
    }
  }
});

test('economics receipts use actual historical payout and permit later current state and grant changes', async () => {
  const q = request('delegatedEconomicsConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
  const actualPayout = { account: A(152), recordHash: id('executed-payout') };
  const actualEvidence = coder.encode(['bytes32', 'bytes'], [id('actual-provider-evidence'), '0xaabb']);
  const r = mined(c, { executedPayout: actualPayout, executedCandidateEvidence: actualEvidence, afterRead: n => {
    if (['artistPayoutAccount', 'requireCurrentEconomics', 'delegationState', 'delegationEpochState'].includes(n)) throw Error('Current readiness must not run at receipt');
    if (n === 'delegationRecord') return [{ ...c.delegation, uses: 5n, revoked: true, revocationRecordHash: id('later-revocation') }];
    if (n === 'artistAuthorizationState') return [[true, false, true, true, 900n]];
  } });
  const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' });
  assert.deepEqual(result.economics.payout, actualPayout);
  assert.equal(result.economics.candidateEvidence, actualEvidence);
  assert.notEqual(result.recordHash, record(c, 1011n));
  assert(Object.isFrozen(result.economics.association));
});

test('economics continuations retain the first raw record and join the new binding association', async () => {
  const q = request('delegatedEconomicsConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
  const first = id('first-economics-record');
  const r = mined(c, { originalRecord: first });
  const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' });
  assert.equal(result.economics.association.originalRecord, first);
  assert.notEqual(result.recordHash, first);
  for (const read of [
    n => n === 'economicsRecord' ? [id('other-original')] : undefined,
    n => n === 'economicsRecordForBinding' ? [first] : undefined,
    (n, args) => n === 'economicsRecordAssociation' && args[0] === first
      ? [[artist, 2n, id('prior-binding'), result.economics.association.payloadHash, first]] : undefined
  ]) {
    const bad = mined(c, { originalRecord: first, afterRead: read });
    await assert.rejects(flow.inspectCurrentArtistReceipt(bad.rpc, c, { transactionHash: bad.txHash, execution: 'direct' }), /association differs/);
  }
});

function mutateNestedArchive(envelope, q, change) {
  const outerTypes = ['bytes', 'bytes32', abi.getFunction('delegationRecord').outputs[0]];
  const outer = Array.from(coder.decode(outerTypes, envelope[7]));
  const fn = abi.getFunction(pure.prepareCurrentArtistAction(q).method);
  const authIndex = q.kind === 'delegatedProspectiveEconomicsConsent' ? 3 : 2;
  const innerTypes = isEconomics(q)
    ? [B, fn.inputs[0], '(address account,bytes32 recordHash)', fn.inputs[authIndex], P, 'bytes', abi.getFunction('economicsRecordAssociation').outputs[0]]
    : [B, fn.inputs[0], fn.inputs[authIndex], P];
  const inner = Array.from(coder.decode(innerTypes, outer[0]));
  change(inner, outer);
  outer[0] = coder.encode(innerTypes, inner);
  envelope[7] = coder.encode(outerTypes, outer);
}

test('nested economics Archive rejects swapped payout, association, candidate, prior grant, and read-only owner mutations', async () => {
  const q = request('delegatedProspectiveEconomicsConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
  const modifications = [
    e => mutateNestedArchive(e, q, inner => { inner[2] = [A(153), payout.recordHash]; }),
    e => mutateNestedArchive(e, q, inner => { const assoc = Array.from(inner[6]); assoc[1] = 9n; inner[6] = assoc; }),
    e => mutateNestedArchive(e, q, inner => {
      const types = [abi.getFunction('requireProspectiveEconomicsWithEvidence').inputs[1], ...abi.getFunction('requireProspectiveEconomicsWithEvidence').outputs];
      inner[5] = coder.encode(types, [q.details.candidate, prospectiveFact(q), id('nonclear-previous')]);
    }),
    e => mutateNestedArchive(e, q, (inner, outer) => { outer[1] = id('wrong-grant'); }),
    e => { e[6][5][1] = 2n; }
  ];
  for (const mutateArchive of modifications) {
    const r = mined(c, { mutateArchive });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), /payout designation|Archive request|Prospective economics|read-only owner/);
  }
  const badDesignation = mined(c, { afterRead: n => n === 'designationRecord' ? [[id('wrong-artist'), payout.account, ZeroHash]] : undefined });
  await assert.rejects(flow.inspectCurrentArtistReceipt(badDesignation.rpc, c, { transactionHash: badDesignation.txHash, execution: 'direct' }), /payout designation/);
});

test('economics and freeze Safe plans retain delegate lanes and reject grant revocation before use', async () => {
  for (const kind of economicKinds) {
    const q = request(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
    const revoke = request('delegationRevocation', { signer: c.delegation.grantor, caller: c.delegation.grantor });
    revoke.message.delegate = q.signer;
    revoke.message.delegationRecordHash = q.details.grant;
    const revocation = await flow.captureCurrentArtistOperation(provider(revoke, { read: n => n === 'delegationRecord' ? [c.delegation] : undefined }), d, revoke, { blockTag: 10 });
    const plan = flow.createCurrentArtistSafePlan([c, revocation], 'Use then revoke');
    assert(plan.steps.every(s => s.transaction.operation === 0 && s.transaction.value === '0'));
    assert.throws(() => flow.createCurrentArtistSafePlan([revocation, c], 'Revoke then use'), /follows its grant revocation/);
    assert.throws(() => flow.createCurrentArtistSafePlan([c, c], 'Duplicate'), /Duplicate Artist authorization nonce/);
  }
});

test('economics receipts reject wrong delegation transport and source/Safe event order', async () => {
  const q = request('delegatedEconomicsConsent');
  const c = await flow.captureCurrentArtistOperation(provider(q), economicsDeployment, q, { blockTag: 10 });
  let r = mined(c, { safe: true });
  const delegationLog = r.receipt.logs[1];
  Object.assign(delegationLog, abi.encodeEventLog(abi.getEvent('ArtistConsentDelegationRecorded'), [1, r.rh, q.details.grant, q.artistId, 15]));
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'safe' }), /Expected one ArtistRecordDelegation/);
  r = mined(c, { safe: true });
  [r.receipt.logs[0], r.receipt.logs[1]] = [r.receipt.logs[1], r.receipt.logs[0]];
  r.receipt.logs.forEach((l, index) => { l.index = index; });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'safe' }), /event order/);
  r = mined(c, { safe: true });
  r.receipt.logs.unshift(r.receipt.logs.pop());
  r.receipt.logs.forEach((l, index) => { l.index = index; });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'safe' }), /Safe success must follow/);
});

function attestationDescriptor(q) {
  return q.details.subject ?? { scopeType: 0n, tokenId: 0n, scopeId: ZeroHash, resolver: ZeroAddress };
}
function attestationRequest(subjectKind = 9n, subject) {
  const uri = 'ipfs://original-attestation-statement';
  let statement = '0x123456';
  let subjectId = coder.encode(['uint256'], [7n]);
  let subjectStateHash = id('subject-state-' + subjectKind);
  let schemaId = id('subject-schema');
  if (subjectKind === 1n) {
    subjectId = id('snapshot-id'); subjectStateHash = id('snapshot-manifest');
  }
  if (subjectKind === 4n && subject) {
    subjectId = keccak256(coder.encode(['bytes32', '(uint8,uint256,uint256,bytes32)'],
      [id('6529STREAM_ARTIST_FINALITY_ATTESTATION_SUBJECT_V1'), [subject.scopeType, 7n, subject.tokenId, subject.scopeId]]));
  }
  if (subjectKind === 5n) subjectId = id('phase');
  if (subjectKind === 6n) {
    const resolver = subject?.resolver ?? A(14);
    subjectId = subject ? keccak256(coder.encode(['bytes32', 'uint256', 'address', 'bytes32', 'uint8', 'uint256'],
      [id('6529STREAM_ARTIST_ECONOMICS_ATTESTATION_SUBJECT_V1'), 7n, resolver, resolver === A(14) ? id('primary') : id('ROYALTY_ERC2981'), subject.scopeType, BigInt(subject.scopeId)]))
      : coder.encode(['address'], [resolver]);
  }
  if (subjectKind === 7n || subjectKind === 8n) {
    subjectId = id('publication-subject'); schemaId = id('6529STREAM_ARTIST_RECORD_PUBLICATION_V1');
    subjectStateHash = subjectKind === 7n ? id('candidate') : ZeroHash;
    const publication = [A(43), signer, 7n, subjectId,
      id(subjectKind === 7n ? 'ARTIST_INTENT' : 'WORK_DESCRIPTION'),
      id(subjectKind === 7n ? 'STREAM_ARTIST_INTENT_V1' : 'STREAM_WORK_DESCRIPTION_V1'),
      id('canonicalization'), 1n, id('payload'), keccak256(new TextEncoder().encode(uri)), 0n, id('candidate')];
    statement = coder.encode(['uint16', pure.CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE], [1n, publication]);
  }
  if (subjectKind === 9n) {
    subjectId = coder.encode(['address'], [A(10)]);
    subjectStateHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'uint256', 'bytes32', 'uint64', 'bytes32'],
      [id('6529STREAM_ARTIST_DEPLOYMENT_FACTS_V1'), d.chainId, A(10), 7n, artist, 2n, id('binding')]));
    schemaId = id('6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1');
  }
  if (subjectKind === 10n) {
    subjectId = artist; subjectStateHash = id('identity'); schemaId = id('6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1');
  }
  const q = {
    kind: subject ? 'delegatedScopedAttestation' : 'delegatedAttestation', chainId: d.chainId,
    registry: A(8), caller: signer, signer, artistId: artist, mode: 'direct', signature: '0x',
    message: { core: A(10), collectionId: 7n, subjectKind, subjectId, subjectStateHash, schemaId,
      statementHash: keccak256(statement), statementURIHash: keccak256(new TextEncoder().encode(uri)), nonce: 1n, signedAt: 0n },
    details: { grant: ZeroHash, statementURI: uri, statement, ...(subject ? { subject } : {}) }
  };
  q.details.grant = grantHash(creationGrant(q));
  return q;
}
function attestationRead(q, name, args) {
  const descriptor = attestationDescriptor(q), kind = q.message.subjectKind;
  switch (name) {
    case 'finalityRegistry': return [A(40)];
    case 'finalityRegistryCodeHash': return [pin(40).codeHash];
    case 'scopeEvidenceProvider': return [A(41)];
    case 'scopeEvidenceProviderCodeHash': return [pin(41).codeHash];
    case 'snapshotHost': return [A(42)];
    case 'metadataRouter': return [A(13)];
    case 'nativeConfiguration': {
      const targets = Array(22).fill(ZeroAddress), hashes = Array(22).fill(ZeroHash);
      for (const [index, target] of [[0, 10], [2, 13], [8, 42], [11, 8], [12, 40]]) {
        targets[index] = A(target); hashes[index] = pin(target).codeHash;
      }
      return [[targets, hashes, d.chainId, 500000n, 1000000n, 200000n, id('inventory')]];
    }
    case 'currentSnapshot': return [[id('snapshot-record'), 7n, id('snapshot-id'), ZeroHash, 1n, id('chain'), id('snapshot-manifest'), 5n,
      id('source'), id('inventory'), A(80), 1n, 0n, 1n, 0n, 900n, 900n, ZeroHash, id('schema'), id('profile'), id('canonical')]];
    case 'latestSnapshotHash':
    case 'snapshotHash': return [id('snapshot-manifest')];
    case 'scriptManifestHash': return [id('subject-state-2')];
    case 'mediaManifestHash': return [id('subject-state-3')];
    case 'collectionFinalityRecord': return [[true, id('subject-state-4'), id('manifest'), id('uri'), '', id('components'), A(40), 900n]];
    case 'artworkScopeFinalityRecord': return [[true, args[0], id('subject-state-4'), id('manifest'), id('uri'), id('components'), '', A(40), 900n]];
    case 'phase': return [true, [false, 0n, 0n, 10n, id('config'), id('metadata')]];
    case 'phasePolicyHash': return [id('subject-state-5')];
    case 'primaryEconomicsFacts':
    case 'resolvePrimaryAssignment': return [[true, q.details.subject ? descriptor.scopeType : 1n,
      q.details.subject ? BigInt(descriptor.scopeId) : 7n, 1n, id('profile'), ZeroHash, ZeroHash, id('subject-state-6'), false]];
    case 'royaltyEconomicsFacts':
    case 'resolveRoyaltyAssignment': {
      const result = [[A(15), id('ROYALTY_ERC2981'), q.details.subject ? descriptor.scopeType : 1n,
        q.details.subject ? BigInt(descriptor.scopeId) : 7n, id('subject-state-6')], [A(70), 500n, true, false, 1n, id('profile')]];
      return name === 'resolveRoyaltyAssignment' ? [...result, id('royalty-policy')] : result;
    }
    case 'streamModuleType': return [id('COLLECTION_METADATA')];
    case 'streamModuleInterfaceId': return ['0x12345678'];
    case 'supportsInterface':
    case 'isModuleEligible': return [true];
    case 'requireArtistRecordCandidate': return [id('candidate'), kind];
    case 'getSatellitePointer': {
      const selected = args[0] === id('COLLECTION_METADATA') ? 43 : args[0] === id('MODULE_REGISTRY') ? 44 : undefined;
      if (selected) return [A(selected), pin(selected).codeHash, false, args[0], '0x12345678', A(44), 1n, id('manifest'), id('deployment'), 1n];
      break;
    }
  }
}

test('delegated attestation captures all ten original subject profiles through exact owner reads', async () => {
  for (let kind = 1n; kind <= 10n; kind++) {
    const q = attestationRequest(kind), rpc = provider(q);
    const c = await flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 });
    assert.equal(c.action.operationId, 24n);
    assert.equal(c.attestation.fact.subjectId, q.message.subjectId);
    assert.equal(c.attestation.fact.stateHash, q.message.subjectStateHash);
    assert(c.attestation.dependencies.length >= 1 && c.attestation.dependencies.length <= 3);
    assert(Object.isFrozen(c.attestation.dependencies));
    assert.equal(c.delegation.grant.capabilities, kind === 7n ? 64n : 1n);
    const simulated = await flow.simulateCurrentArtistCall(rpc, c, { blockTag: 10 });
    assert.equal(simulated.recordHash, record(c, 1010n));
    assert.equal(rpc.calls.at(-1).from, q.caller);
  }
});

test('all ten delegated attestation receipts retain exact records, subject associations and flat Archive payloads', async () => {
  for (let kind = 1n; kind <= 10n; kind++) {
    const q = attestationRequest(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    const r = mined(c, { safe: kind % 2n === 0n, indexed: kind % 3n === 0n });
    const result = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: kind % 2n === 0n ? 'safe' : 'direct' });
    assert.equal(result.recordHash, record(c, 1011n));
    assert.equal(result.effectiveDigest, effectiveDigest(q, 1011n));
    assert.deepEqual(result.attestation.fact, c.attestation.fact);
    assert.equal(result.attestation.subjectEvidence, c.attestation.subjectEvidence);
    assert(result.events.some(e => e.event === 'ArtistAttestationDelegation'));
  }
});

test('scoped finality and economics retain exact scope identities across supported owners', async () => {
  const cases = [
    ...[0n, 1n, 2n, 3n, 4n].map(scopeType => [4n, { scopeType, tokenId: scopeType === 1n ? 99n : 0n,
      scopeId: scopeType >= 2n ? id('scope-' + scopeType) : ZeroHash, resolver: ZeroAddress }]),
    ...[A(14), A(15)].flatMap(resolver => [0n, 1n, 2n].map(scopeType => [6n, { scopeType, tokenId: 0n,
      scopeId: coder.encode(['uint256'], [scopeType === 0n ? 0n : scopeType === 1n ? 7n : 99n]), resolver }]))
  ];
  for (const [kind, descriptor] of cases) {
    const q = attestationRequest(kind, descriptor);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    const r = mined(c, { safe: true, indexed: true });
    const out = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'safe' });
    assert.equal(out.attestation.fact.subjectId, q.message.subjectId);
  }
});

test('delegated attestation direct past dates remain valid while direct zero is block-specific and future/relayzero reject', async () => {
  const q = attestationRequest();
  q.message.signedAt = 900n;
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const r = mined(c);
  const out = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' });
  assert.equal(out.effectiveDigest, c.action.payload.digest);
  assert.equal(out.recordHash, record(c, 900n));
  q.message.signedAt = 1011n;
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 }), /signedAt/);
  q.message.signedAt = 0n; q.caller = A(110); q.mode = 'signature';
  assert.throws(() => pure.prepareCurrentArtistAction(q), /signedAt|zero|time/i);
  q.message.signedAt = 900n;
  const relay = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  await flow.simulateCurrentArtistCall(provider(q), relay, { blockTag: 10 });
});

test('attestation subject reads reject contradictory native facts, scope, metadata admission and gas policy', async () => {
  const cases = [
    [1n, 'nativeConfiguration', (q, args) => {
      const result = attestationRead(q, 'nativeConfiguration', args);
      result[0][2]++;
      return result;
    }, /configuration differs/],
    [1n, 'latestSnapshotHash', () => [id('different-snapshot')], /snapshot identity/],
    [2n, 'scriptManifestHash', () => [id('different-script')], /subject.*differ/i],
    [3n, 'core', () => [A(999)], /Core|binding/],
    [4n, 'collectionFinalityRecord', (q, args) => {
      const result = attestationRead(q, 'collectionFinalityRecord', args);
      result[0][0] = false;
      return result;
    }, /not finalized/],
    [4n, 'collectionFinalityRecord', (q, args) => {
      const result = attestationRead(q, 'collectionFinalityRecord', args);
      result[0][7] = 1011n;
      return result;
    }, /not finalized/],
    [5n, 'phase', (q, args) => {
      const result = attestationRead(q, 'phase', args);
      result[0] = false;
      return result;
    }, /phase differs/],
    [6n, 'resolvePrimaryAssignment', (q, args) => {
      const result = attestationRead(q, 'resolvePrimaryAssignment', args);
      result[0][0] = false;
      return result;
    }, /Missing primary/],
    [7n, 'requireArtistRecordCandidate', () => [id('other-candidate'), 7n], /candidate differs/],
    [8n, 'isModuleEligible', () => [false], /not eligible/],
    [10n, 'operativeIdentityRecord', () => [id('later-identity')], /subject.*differ/i]
  ];
  for (const [kind, method, replacement, expected] of cases) {
    const q = attestationRequest(kind);
    const rpc = provider(q, { read: (name, args) => name === method ? replacement(q, args) : undefined });
    await assert.rejects(flow.captureCurrentArtistOperation(rpc, d, q, { blockTag: 10 }), expected);
  }
  const q = attestationRequest();
  for (const gas of [[0n, 0n, 2n, 1n], [1n << 255n, 0n, 2n, 1n], [90000n, 90000n, 1n, 1n], [90000n, 90000n, 2n, 0n]]) {
    await assert.rejects(flow.captureCurrentArtistOperation(provider(q, {
      read: name => name === 'gasParameterInfo' ? gas : undefined
    }), d, q, { blockTag: 10 }), /gas policy/);
  }
  const scoped = attestationRequest(6n, { scopeType: 2n, scopeId: coder.encode(['uint256'], [99n]), tokenId: 0n, resolver: A(15) });
  await assert.rejects(flow.captureCurrentArtistOperation(provider(scoped, { read: (name, args) => {
    if (name !== 'royaltyEconomicsFacts') return;
    const result = attestationRead(scoped, name, args);
    result[0][3] = 98n;
    return result;
  } }), d, scoped, { blockTag: 10 }), /scope differs/);
});

test('attestation captures enforce canonical dynamic reads, runtime pins, immutable inputs and original schema bounds', async () => {
  const q = attestationRequest(1n);
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { read: (name, args) => name === 'nativeConfiguration'
    ? { raw: abi.encodeFunctionResult(name, attestationRead(q, name, args)) + '00' } : undefined
  }), d, q, { blockTag: 10 }), /Noncanonical|invalid length/);
  for (const runtime of ['0x', '0xef0100' + A(200).slice(2)]) {
    await assert.rejects(flow.captureCurrentArtistOperation(provider(q, {
      code: target => target === A(41) ? runtime : undefined,
      read: name => name === 'scopeEvidenceProviderCodeHash' ? [keccak256(runtime)] : undefined
    }), d, q, { blockTag: 10 }), /owner runtime/);
  }
  await assert.rejects(flow.captureCurrentArtistOperation(provider(q, { reorg: true }), d, q, { blockTag: 10 }), /Pinned block/);
  const submitted = attestationRequest(4n, { scopeType: 1n, tokenId: 99n, scopeId: ZeroHash, resolver: ZeroAddress });
  const mutable = structuredClone(submitted);
  const capture = await flow.captureCurrentArtistOperation(provider(submitted, { mutate() {
    mutable.details.subject.tokenId = 100n;
    mutable.details.statement = '0x00';
  } }), d, mutable, { blockTag: 10 });
  assert.equal(capture.action.request.details.subject.tokenId, 99n);
  assert.equal(capture.action.request.details.statement, submitted.details.statement);
  const forged = structuredClone(capture);
  forged.attestation.fact.stateHash = id('forged');
  assert.throws(() => flow.createCurrentArtistSafePlan([forged], 'Forged subject'), /facts changed/);
  await assert.rejects(flow.simulateCurrentArtistCall(provider(submitted), forged, { blockTag: 10 }), /facts changed/);
  const c2pa = attestationRequest(10n);
  c2pa.message.schemaId = id('deferred-C2PA-schema');
  assert.throws(() => pure.prepareCurrentArtistAction(c2pa), /C2PA.*deferred/);
});

test('historical attestation receipts retain original facts after latest subjects and grant eligibility change', async () => {
  const liveReads = new Set(['currentSnapshot', 'latestSnapshotHash', 'snapshotHash', 'scriptManifestHash',
    'mediaManifestHash', 'collectionFinalityRecord', 'artworkScopeFinalityRecord', 'phase', 'phasePolicyHash',
    'primaryEconomicsFacts', 'resolvePrimaryAssignment', 'royaltyEconomicsFacts', 'resolveRoyaltyAssignment',
    'requireArtistRecordCandidate', 'operativeIdentityRecord', 'attestation', 'delegationState',
    'delegationEpochState', 'requireRecordPublication']);
  for (let kind = 1n; kind <= 10n; kind++) {
    const q = attestationRequest(kind);
    const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
    const r = mined(c, { afterRead(name) {
      if (liveReads.has(name)) throw Error('Receipt consulted mutable latest state: ' + name);
      if (name === 'delegationRecord') return [{ ...c.delegation, uses: c.delegation.uses + 2n,
        revoked: true, revocationRecordHash: id('later-revocation') }];
    } });
    const out = await flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' });
    assert.equal(out.attestation.fact.stateHash, q.message.subjectStateHash);
    assert.equal(out.effectiveDigest, effectiveDigest(q, 1011n));
  }
});

function mutateAttestationArchive(envelope, q, change) {
  const fn = abi.getFunction(pure.prepareCurrentArtistAction(q).method);
  const auth = fn.inputs[q.kind === 'delegatedScopedAttestation' ? 3 : 2];
  const types = [B, fn.inputs[0], auth, auth, P, 'bytes', pure.CURRENT_ARTIST_ATTESTATION_SUBJECT_TUPLE,
    'bool', abi.getFunction('recordAuthenticatedAttestation').inputs[3], abi.getFunction('delegationRecord').outputs[0], 'bytes'];
  const values = Array.from(coder.decode(types, envelope[7]));
  change(values);
  envelope[7] = coder.encode(types, values);
}

test('attestation flat Archive rejects changed effective proof, statement, scope, grant and owner snapshots', async () => {
  const q = attestationRequest(4n, { scopeType: 1n, tokenId: 99n, scopeId: ZeroHash, resolver: ZeroAddress });
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  const changes = [
    values => { values[3] = [q.message.nonce, 1010n, '0x']; },
    values => { values[4] = [q.signer, c.action.payload.digest, true]; },
    values => { values[5] = '0x00'; },
    values => { values[6] = [1n, 100n, ZeroHash, ZeroAddress]; },
    values => { values[7] = false; },
    values => { const admission = Array.from(values[8]); admission[4] = id('other-grant'); values[8] = admission; },
    values => { const prior = Array.from(values[9]); prior[3] = prior[3] + 1n; values[9] = prior; },
    values => { values[10] += '00'; }
  ];
  for (const change of changes) {
    const r = mined(c, { mutateArchive: e => mutateAttestationArchive(e, q, change) });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), /Archive|attestation|Noncanonical|delegation/i);
  }
  const r = mined(c, { mutateArchive: e => { e[6][1][1] = 2n; } });
  await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), /read-only owner/);
});

test('attestation durable record, publication envelope and immutable finality lineage reject contradictory readback', async () => {
  const q = attestationRequest(7n);
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const afterRead of [
    name => name === 'attestationAuthorityClass' ? [1n] : undefined,
    name => name === 'statementBytes' ? ['0x00'] : undefined,
    name => name === 'attestationRecord' ? [[id('wrong-record'), q.message.subjectStateHash, q.message.schemaId,
      q.message.statementHash, 2n, 1011n, q.signer]] : undefined,
    name => name === 'attestationAssociation' ? [[q.artistId, id('wrong-binding'), 2n, q.details.grant, c.attestation.fact]] : undefined,
    name => {
      if (name !== 'publicationAttestation') return;
      const [, publication] = coder.decode(['uint16', pure.CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE], q.details.statement);
      return [[publication, [record(c, 1011n), q.artistId, id('binding'), 2n, q.signer, 2n, 1n,
        1011n, keccak256(coder.encode([pure.CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE], [publication]))], c.attestation.fact.ownerCodeHash]];
    }
  ]) {
    const r = mined(c, { afterRead });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'direct' }), /attestation|Attestation|publication|Publication/);
  }
  for (const kind of [1n, 4n]) {
    const subject = attestationRequest(kind);
    const captured = await flow.captureCurrentArtistOperation(provider(subject), d, subject, { blockTag: 10 });
    const wrong = mined(captured, { afterRead: name => name === 'finalityRegistry' ? [A(43)]
      : name === 'finalityRegistryCodeHash' ? [pin(43).codeHash] : undefined });
    await assert.rejects(flow.inspectCurrentArtistReceipt(wrong.rpc, captured, { transactionHash: wrong.txHash, execution: 'direct' }), /finality|lineage/i);
    const empty = mined(captured, { afterRead: name => name === 'finalityRegistryCodeHash' ? [keccak256('0x')] : undefined });
    const getCode = empty.rpc.getCode;
    empty.rpc.getCode = (target, tag) => target === A(40) && tag === 11 ? '0x' : getCode(target, tag);
    await assert.rejects(flow.inspectCurrentArtistReceipt(empty.rpc, captured, { transactionHash: empty.txHash, execution: 'direct' }), /finality runtime|owner runtime/i);
  }
  const snapshot = attestationRequest(1n);
  const captured = await flow.captureCurrentArtistOperation(provider(snapshot), d, snapshot, { blockTag: 10 });
  const delegatedRuntime = '0xef0100' + A(222).slice(2);
  const runtimeHash = keccak256(delegatedRuntime);
  const result = mined(captured, {
    afterRead: name => name === 'scopeEvidenceProviderCodeHash' ? [runtimeHash] : undefined,
    mutateArchive: envelope => mutateAttestationArchive(envelope, snapshot, values => {
      const evidenceTypes = ['address', 'address', 'bytes32', abi.getFunction('currentSnapshot').outputs[0]];
      const evidence = Array.from(coder.decode(evidenceTypes, values[10]));
      evidence[2] = runtimeHash;
      values[10] = coder.encode(evidenceTypes, evidence);
    })
  });
  const getCode = result.rpc.getCode;
  result.rpc.getCode = (target, tag) => target === A(41) && tag === 11 ? delegatedRuntime : getCode(target, tag);
  await assert.rejects(flow.inspectCurrentArtistReceipt(result.rpc, captured, { transactionHash: result.txHash, execution: 'direct' }), /lineage/i);
});

test('attestation Safe plans share delegate nonce lanes and preserve order-aware grant and known digest conflicts', async () => {
  const q = attestationRequest();
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const kind of ['delegatedPolicyConsent', 'delegatedSaleConsent', 'delegatedEconomicsConsent', 'delegatedRoyaltyFreeze']) {
    const other = request(kind);
    const captured = await flow.captureCurrentArtistOperation(provider(other), economicKinds.includes(kind) ? economicsDeployment : d, other, { blockTag: 10 });
    assert.throws(() => flow.createCurrentArtistSafePlan([c, captured], 'Shared delegate nonce'), /Duplicate Artist authorization nonce/);
  }
  const revokeGrant = request('delegationRevocation', { signer: c.delegation.grantor, caller: c.delegation.grantor });
  revokeGrant.message.delegate = q.signer;
  revokeGrant.message.delegationRecordHash = q.details.grant;
  const revocation = await flow.captureCurrentArtistOperation(provider(revokeGrant, {
    read: name => name === 'delegationRecord' ? [c.delegation] : undefined
  }), d, revokeGrant, { blockTag: 10 });
  assert.equal(flow.createCurrentArtistSafePlan([c, revocation], 'Record then revoke').steps.length, 2);
  assert.throws(() => flow.createCurrentArtistSafePlan([revocation, c], 'Revoke then record'), /follows its grant revocation/);
  const revokeDigest = request('authorizationRevocation');
  revokeDigest.message.revokedNonce = 0n;
  revokeDigest.message.revokedDigest = c.action.payload.digest;
  const zeroDigest = await flow.captureCurrentArtistOperation(provider(revokeDigest), d, revokeDigest, { blockTag: 10 });
  assert.equal(flow.createCurrentArtistSafePlan([c, zeroDigest], 'Unknown future effective digest').steps.length, 2);
  q.message.signedAt = 900n;
  const dated = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  revokeDigest.message.revokedDigest = dated.action.payload.digest;
  const knownDigest = await flow.captureCurrentArtistOperation(provider(revokeDigest), d, revokeDigest, { blockTag: 10 });
  assert.throws(() => flow.createCurrentArtistSafePlan([dated, knownDigest], 'Known digest conflict'), /Conflicting Artist revocation target/);
});

test('attestation receipt enforces Attribution to Archive to Safe event order for both Safe layouts', async () => {
  const q = attestationRequest();
  const c = await flow.captureCurrentArtistOperation(provider(q), d, q, { blockTag: 10 });
  for (const indexed of [false, true]) {
    const r = mined(c, { safe: true, indexed });
    [r.receipt.logs[0], r.receipt.logs[1]] = [r.receipt.logs[1], r.receipt.logs[0]];
    r.receipt.logs.forEach((log, index) => { log.index = index; });
    await assert.rejects(flow.inspectCurrentArtistReceipt(r.rpc, c, { transactionHash: r.txHash, execution: 'safe' }), /event order/i);
    const earlySuccess = mined(c, { safe: true, indexed });
    earlySuccess.receipt.logs.unshift(earlySuccess.receipt.logs.pop());
    earlySuccess.receipt.logs.forEach((log, index) => { log.index = index; });
    await assert.rejects(flow.inspectCurrentArtistReceipt(earlySuccess.rpc, c, { transactionHash: earlySuccess.txHash, execution: 'safe' }), /Safe success must follow/);
  }
});
