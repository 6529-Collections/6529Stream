import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-artist-operation.js';
import * as flow from '../dist/current-artist-workflow.js';
const f = JSON.parse(readFileSync(new URL('./fixtures/current-artist-operation-current-abi.json', import.meta.url), 'utf8'));
const abi = new Interface(Object.values(f.abis).flat());
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
const code = n => '0x60' + n.toString(16).padStart(2, '0');
const pin = n => ({
  address: A(n), codeHash: keccak256(code(n))
});
const d = {
  chainId: 31337n, registry: pin(8), coordinator: pin(20), components: Array.from({ length: 16 }, (_, n) => pin(n + 1))
};
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
  const messages = {
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
    kind, chainId: d.chainId, registry: d.registry.address, caller: signer, signer, artistId: artist, mode: 'direct', signature: '0x', message: messages[kind], details: kind === 'bindingRefusal' ? { reasonURI: 'ipfs://reviewed-but-not-signed' } : {}, ...change
  };
}
function binding(q) {
  return [q.artistId, A(101), id('identity'), id('binding'), 2n, 1n, 1n, 0n, A(102), q.kind !== 'bindingRefusal'];
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
      return target === A(20) ? code(20) : d.components.some(x => x.address === target) ? code(Number(BigInt(target))) : '0xef0100' + A(200).slice(2);
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
      let value;
      switch (name) {
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
          value = [A(8), pin(8).codeHash, false, id('ARTIST_REGISTRY'), '0x12345678', A(80), 1, id('manifest'), id('deployment'), 1];
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
        case 'authorityState':
          value = [q.signer, 1, 1, id('identity')];
          break;
        case 'gasParameterInfo':
          value = [90000, 90000, 2, 1];
          break;
        case 'artistAuthorizationState':
          value = [[false, false, false, false, 1]];
          break;
        default: if (name === action.digestMethod) {
          value = [action.payload.digest];
        }
        else {
          if (name === action.method) {
            value = [record({
                action, authority: { authorityClass: opt.authorityClass ?? 1n }
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
function record(c, time) {
  const q = c.action.request;
  const m = q.message;
  const core = A(10);
  const cl = c.authority.authorityClass;
  const n = m.nonce;
  const common = [d.chainId, A(8)];
  const maps = {
    bindingRefusal: [['bytes32', 'uint256', 'address', 'address', 'uint256', 'uint64', 'bytes32', 'bytes32', 'address', 'uint8', 'bytes32', 'uint256', 'uint64'], ['0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed', ...common, core, m.collectionId, m.bindingGeneration, m.bindingHash, artist, q.signer, cl, m.reasonHash, n, time]],
    saleConsent: [['bytes32', 'uint256', 'address', 'address', 'address', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1'), ...common, m.saleAdapter, core, m.collectionId, m.saleId, m.saleConfigHash, artist, q.signer, cl, n, time]],
    royaltyFreeze: [['bytes32', 'uint256', 'address', 'address', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1'), ...common, m.resolver, m.collectionId, m.revenueClass, m.expectedAssignmentHash, artist, q.signer, cl, n, time]],
    contentFreeze: [['bytes32', 'uint256', 'address', 'address', 'address', 'uint256', 'bytes32[]', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1'), ...common, m.metadataContract, core, m.collectionId, m.lockClasses, m.expectedStateHash, artist, q.signer, cl, n, time]],
    authorizationRevocation: [['bytes32', 'uint256', 'address', 'bytes32', 'bytes32', 'uint256', 'uint256', 'uint64'], [id('6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1'), ...common, artist, m.revokedDigest, m.revokedNonce, n, time]]
  };
  return keccak256(coder.encode(...maps[q.kind]));
}
function mined(c, { safe = false, indexed = false, mutateArchive, afterRead } = {}) {
  const q = c.action.request;
  const m = q.message;
  const tag = 11;
  const time = 1011n;
  const cl = c.authority.authorityClass;
  const rh = record(c, time);
  const fn = abi.getFunction(c.action.method);
  const [t, auth] = abi.decodeFunctionData(fn, c.action.call.data);
  const types = q.kind === 'authorizationRevocation' ? [fn.inputs[0], fn.inputs[1], P] : [B, fn.inputs[0], fn.inputs[1], P];
  const values = q.kind === 'authorizationRevocation' ? [t, auth, [q.signer, c.action.payload.digest, q.mode === 'direct']] : [binding(q), t, auth, [q.signer, c.action.payload.digest, q.mode === 'direct']];
  if (['bindingRefusal', 'saleConsent'].includes(q.kind)) {
    types.push(F);
    values.push([artist, q.signer, cl, c.authority.status]);
  }
  if (q.kind === 'saleConsent') {
    types.push('bytes');
    values.push(coder.encode(['address', 'bytes32', 'bytes32', 'bytes32', 'bytes4', 'uint256', 'bytes32'], [A(80), id('registrycode'), id('adaptercode'), id('kind'), '0x12345678', m.collectionId, m.saleConfigHash]));
  }
  const mask = q.kind === 'authorizationRevocation' ? 4 : q.kind === 'bindingRefusal' ? 21 : 87;
  const writeMask = q.kind === 'authorizationRevocation' ? 4 : q.kind === 'bindingRefusal' ? 21 : 68;
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
    case 'bindingRefusal':
      specs.push([A(5), 'ArtistAttributionStateChanged', [1, m.collectionId, 5, 2, 1, q.caller, cl, rh, m.reasonHash, q.details.reasonURI]], [A(5), 'ArtistBindingTerminationContext', [1, m.collectionId, 2, rh, m.bindingHash, artist, q.signer, m.nonce, time]]);
      break;
    case 'saleConsent':
      specs.push([A(7), 'ArtistSaleConsentRecorded', [1, m.collectionId, m.saleConfigHash, q.signer, m.saleId, cl, m.nonce, time, rh]]);
      break;
    case 'royaltyFreeze':
      specs.push([A(7), 'ArtistRoyaltyFreezeAuthorized', [1, m.collectionId, m.expectedAssignmentHash, q.signer, cl, m.nonce, time, rh]]);
      break;
    case 'contentFreeze':
      specs.push([A(7), 'ArtistContentFreezeAuthorized', [1, m.collectionId, q.signer, m.lockClasses, m.expectedStateHash, cl, m.nonce, time, rh]], [A(7), 'ArtistContentRecordContext', [1, rh, m.metadataContract, artist]]);
      break;
    case 'authorizationRevocation': specs.push([A(3), 'ArtistAuthorizationRevoked', [1, artist, m.revokedDigest, m.revokedNonce, m.nonce, time, rh]]);
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
    authorityClass: cl, read(name, args, call) {
      if (call.blockTag !== tag) {
        if (name === 'authorityState') {
          return [q.signer, cl, c.authority.status, c.authority.identityRecordHash];
        }
        if (name === 'currentAuthorityCapabilities') {
          return [[q.signer, cl, c.authority.status, 2047, id('activation')]];
        }
        return;
      }
      const replacement = afterRead?.(name, args, call);
      if (replacement !== undefined) {
        return replacement;
      }
      switch (name) {
        case 'artistEvidenceMetadataV2': return [keccak256(raw), A(201), BigInt((raw.length - 2) / 2), 11n];
        case 'artistEvidenceBytesV2': return [raw];
        case 'artistAuthorizationState': return [[args[1] === c.action.payload.digest, args[1] === m.revokedDigest && m.revokedDigest !== ZeroHash, true, args[2] === m.revokedNonce, 10n]];
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
    if (kind === 'authorizationRevocation') q.message.artistId = q.artistId;
    else q.message.collectionId = BigInt(100 + index);
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
    const q = request('authorizationRevocation', { caller: A(110), mode: 'signature' });
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
    } else {
      conflict.message.revokedNonce = first.action.request.message.nonce;
    }
    const cc = await captured(conflict);
    for (const order of [[first, cc], [cc, first]]) {
      assert.throws(() => flow.createCurrentArtistSafePlan(order, 'Revoked listed authorization'), /Conflicting.*revocation/);
    }
  }
});
