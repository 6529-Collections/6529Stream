import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, id, keccak256, toBeHex, zeroPadValue } from 'ethers';
import { CURRENT_ARTIST_OPERATION_ABI, currentArtistOperationTypedData, normalizeCurrentArtistAction,
  normalizeCurrentArtistOperationRequest, prepareCurrentArtistAction } from '../dist/current-artist-operation.js';
import { buildSigningPayload } from '../dist/signing-payload.js';
import { currentArtistTypedData } from '../dist/current-artist.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-artist-operation-current-abi.json', import.meta.url)));
const compiled = new Interface(fixture.abis.registry), coder = AbiCoder.defaultAbiCoder();
const a = n => toBeHex(BigInt(n), 20), h = n => toBeHex(BigInt(n), 32);
const chainId = (1n << 200n) + 9n, registry = a(101), core = a(102), signer = a(103), caller = a(104), artistId = h(105);
const collectionId = (1n << 150n) + 3n, nonce = (1n << 180n) + 5n, deadline = (1n << 63n) + 7n;
const dated = { nonce, deadline };
const messages = {
  bindingRefusal: { core, collectionId, bindingGeneration: (1n << 63n) + 2n, bindingHash: h(201), reasonHash: h(202), ...dated },
  saleConsent: { core, saleAdapter: a(106), collectionId, saleId: h(203), saleConfigHash: h(204), ...dated },
  royaltyFreeze: { core, resolver: a(107), collectionId, revenueClass: id('ROYALTY_ERC2981'), expectedAssignmentHash: h(205), ...dated },
  contentFreeze: { core, metadataContract: a(108), collectionId, lockClasses: [h(2), h(3), h(1000)], expectedStateHash: h(206), ...dated },
  authorizationRevocation: { artistId, revokedDigest: h(207), revokedNonce: 0n, ...dated },
};
function request(kind, changes = {}) {
  return { kind, chainId, registry, caller, signer, artistId, mode: 'signature', signature: '0x1234',
    message: structuredClone(messages[kind]), details: kind === 'bindingRefusal' ? { reasonURI: 'ipfs://unsigned-refusal-🖼' } : {}, ...changes };
}
function typed(structHash, chain = chainId, verifier = registry) {
  const domain = keccak256(coder.encode(['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
    [id('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'), id('6529StreamArtistRegistry'), id('1'), chain, verifier]));
  return keccak256(concat(['0x1901', domain, structHash]));
}
function body(declaration, types, values, typeHash = id(declaration)) {
  return keccak256(coder.encode(['bytes32', ...types], [typeHash, ...values]));
}

test('all five original Artist schemas retain full-width coordinates and actual facade domain', () => {
  const b = messages.bindingRefusal, s = messages.saleConsent, r = messages.royaltyFreeze, c = messages.contentFreeze, v = messages.authorizationRevocation;
  const expected = {
    bindingRefusal: body('StreamArtistBindingRefusal(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)',
      ['address','uint256','uint64','bytes32','bytes32','uint256','uint64'], [core,collectionId,b.bindingGeneration,b.bindingHash,b.reasonHash,nonce,deadline], '0xc893b08f32a42da1625fa6427599c670031a4718906493412194962b8605a4bc'),
    saleConsent: body('StreamArtistSaleConsent(address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline)',
      ['address','address','uint256','bytes32','bytes32','uint256','uint64'], [core,s.saleAdapter,collectionId,s.saleId,s.saleConfigHash,nonce,deadline]),
    royaltyFreeze: body('StreamArtistRoyaltyFreeze(address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline)',
      ['address','address','uint256','bytes32','bytes32','uint256','uint64'], [core,r.resolver,collectionId,r.revenueClass,r.expectedAssignmentHash,nonce,deadline]),
    contentFreeze: body('StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)',
      ['address','address','uint256','bytes32','bytes32','uint256','uint64'], [core,c.metadataContract,collectionId,keccak256(concat(c.lockClasses)),c.expectedStateHash,nonce,deadline]),
    authorizationRevocation: body('StreamArtistAuthorizationRevocation(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline)',
      ['bytes32','bytes32','uint256','uint256','uint64'], [artistId,v.revokedDigest,0n,nonce,deadline]),
  };
  for (const [kind, structHash] of Object.entries(expected)) {
    const payload = currentArtistOperationTypedData(kind, chainId, registry, messages[kind]);
    assert.equal(payload.digest, typed(structHash));
    assert.notEqual(payload.digest, typed(structHash, chainId + 1n));
    assert.notEqual(payload.digest, typed(structHash, chainId, core));
    assert.equal(payload.message.nonce, nonce);
    assert.equal(payload.message.deadline, deadline);
  }
});

test('five writes and getters use exact compiler tuples and zero-value facade calls', () => {
  const expected = {
    bindingRefusal: [3n, 'refuseArtistBinding', 'bindingRefusalDigest', m => [m.collectionId,m.bindingGeneration,m.bindingHash,m.reasonHash,request('bindingRefusal').details.reasonURI]],
    saleConsent: [16n, 'recordSaleConsent', 'saleConsentDigest', m => [m.collectionId,m.saleAdapter,m.saleId,m.saleConfigHash]],
    royaltyFreeze: [20n, 'authorizeArtistRoyaltyFreeze', 'royaltyFreezeDigest', m => [m.resolver,m.collectionId,m.revenueClass,m.expectedAssignmentHash]],
    contentFreeze: [21n, 'authorizeArtistContentFreeze', 'contentFreezeDigest', m => [m.collectionId,m.metadataContract,m.lockClasses,m.expectedStateHash]],
    authorizationRevocation: [54n, 'revokeArtistAuthorization', 'authorizationRevocationDigest', m => [m.artistId,m.revokedDigest,m.revokedNonce]],
  };
  const local = new Interface(CURRENT_ARTIST_OPERATION_ABI);
  for (const [kind, [operationId, method, getter, terms]] of Object.entries(expected)) {
    const plan = prepareCurrentArtistAction(request(kind));
    assert.equal(plan.operationId, operationId);
    assert.equal(plan.method, method); assert.equal(plan.digestMethod, getter);
    assert.deepEqual(plan.call, { to: registry, value: 0n, data: compiled.encodeFunctionData(method, [terms(messages[kind]), [nonce, deadline, '0x1234']]) });
    assert.deepEqual(plan.digestCall, { to: registry, value: 0n, data: compiled.encodeFunctionData(getter, [terms(messages[kind]), [nonce, deadline, '0x']]) });
    for (const name of [method, getter]) assert.equal(local.getFunction(name).format('minimal'), compiled.getFunction(name).format('minimal'));
  }
});

test('refusal supplemental URI changes reviewed calldata but cannot change the original signed digest', () => {
  const first = prepareCurrentArtistAction(request('bindingRefusal'));
  const second = prepareCurrentArtistAction(request('bindingRefusal', { details: { reasonURI: '' } }));
  assert.equal(first.payload.digest, second.payload.digest);
  assert.notEqual(first.call.data, second.call.data);
  assert.notEqual(first.digestCall.data, second.digestCall.data);
  const bound = request('bindingRefusal', { details: { reasonURI: 'é'.repeat(1024) } });
  prepareCurrentArtistAction(bound);
  assert.throws(() => prepareCurrentArtistAction({ ...bound, details: { reasonURI: 'é'.repeat(1025) } }), /2048/);
  assert.throws(() => prepareCurrentArtistAction({ ...bound, details: { reasonURI: '\ud800' } }));
  assert.throws(() => prepareCurrentArtistAction({ ...bound, details: { reasonURI: '\udc00' } }));
  assert.throws(() => prepareCurrentArtistAction({ ...bound, details: { reasonURI: '', reasonURIHash: h(3) } }), /unexpected fields/);
});

test('actual caller determines direct route, including empty ERC-1271 proof for a distinct caller', () => {
  for (const kind of Object.keys(messages)) {
    const direct = prepareCurrentArtistAction(request(kind, { caller: signer, mode: 'direct', signature: '0x' }));
    assert.equal(direct.request.caller, direct.request.signer);
    assert.equal(compiled.decodeFunctionData(direct.method, direct.call.data)[1].signature, '0x');
    const empty1271 = prepareCurrentArtistAction(request(kind, { signature: '0x' }));
    assert.equal(empty1271.request.mode, 'signature');
    prepareCurrentArtistAction(request(kind, { caller: signer, signature: '0x123456' }));
    assert.throws(() => prepareCurrentArtistAction(request(kind, { mode: 'direct', signature: '0x' })), /predicate/);
    assert.throws(() => prepareCurrentArtistAction(request(kind, { caller: signer, signature: '0x' })), /predicate/);
    assert.throws(() => prepareCurrentArtistAction(request(kind, { caller: signer, mode: 'direct', signature: '0x1234' })), /predicate/);
  }
});

test('signature proofs are opaque bounded bytes without wallet-class or EOA-length guesses', () => {
  for (const length of [0, 1, 64, 65, 4096]) prepareCurrentArtistAction(request('saleConsent', { signature: `0x${'ab'.repeat(length)}` }));
  for (const signature of ['0x1', '0xzz', `0x${'ab'.repeat(4097)}`, null]) assert.throws(() => prepareCurrentArtistAction(request('saleConsent', { signature })), /Signature/);
  assert.throws(() => prepareCurrentArtistAction(request('saleConsent', { walletClass: 'eoa' })), /unexpected fields/);
});

test('content classes preserve exact 1..16 nonzero strict ordering with no implicit sorting', () => {
  const payload = values => currentArtistOperationTypedData('contentFreeze', chainId, registry, { ...messages.contentFreeze, lockClasses: values });
  payload([h(1)]); payload(Array.from({ length: 16 }, (_, i) => h(i + 1)));
  for (const classes of [[], Array.from({ length: 17 }, (_, i) => h(i + 1)), [ZeroHash], [h(3),h(2)], [h(2),h(2)], ['0x12'], new Array(2)]) assert.throws(() => payload(classes));
  const extra = [h(1)]; extra.authority = signer;
  assert.throws(() => payload(extra), /extra properties/);
  const m = messages.contentFreeze;
  const wrongArrayHash = keccak256(coder.encode(['bytes32[]'], [m.lockClasses]));
  const wrong = body('StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)',
    ['address','address','uint256','bytes32','bytes32','uint256','uint64'], [core,m.metadataContract,collectionId,wrongArrayHash,m.expectedStateHash,nonce,deadline]);
  assert.notEqual(payload(m.lockClasses).digest, typed(wrong));
});

test('revocations distinguish digest target, nonce target, own authorization nonce and authority locator', () => {
  const revocation = values => prepareCurrentArtistAction(request('authorizationRevocation', { message: { ...messages.authorizationRevocation, ...values } }));
  revocation({ nonce: 0n }); // An authorization with nonce zero is valid; target nonce zero is the sentinel.
  revocation({ revokedDigest: ZeroHash, revokedNonce: nonce + 1n });
  assert.throws(() => revocation({ revokedDigest: ZeroHash, revokedNonce: 0n }), /exactly one/);
  assert.throws(() => revocation({ revokedNonce: 1n }), /exactly one/);
  assert.throws(() => revocation({ revokedDigest: ZeroHash, revokedNonce: nonce }), /itself/);
  assert.throws(() => revocation({ artistId: h(99) }), /locator/);
  assert.throws(() => revocation({ artistId: ZeroHash }), /nonzero/);
});

test('live-assignment royalty class is fixed and original integer widths never accept JS numbers', () => {
  const payload = (kind, overrides) => currentArtistOperationTypedData(kind, chainId, registry, { ...messages[kind], ...overrides });
  assert.throws(() => payload('royaltyFreeze', { revenueClass: id('PRIMARY_SALE') }), /ROYALTY_ERC2981/);
  assert.throws(() => payload('royaltyFreeze', { expectedAssignmentHash: ZeroHash }), /nonzero/);
  for (const kind of Object.keys(messages)) {
    payload(kind, { nonce: (1n << 256n) - 1n, deadline: (1n << 64n) - 1n });
    payload(kind, { nonce: 0n, deadline: 0n }); // Expiry is a live execution check.
    for (const overrides of [{ nonce: 1 }, { nonce: -1n }, { nonce: 1n << 256n }, { deadline: 1 }, { deadline: 1n << 64n }]) assert.throws(() => payload(kind, overrides));
  }
  assert.throws(() => payload('bindingRefusal', { bindingGeneration: 1n << 64n }));
  assert.throws(() => payload('bindingRefusal', { bindingGeneration: 0n }));
  assert.throws(() => payload('saleConsent', { collectionId: 0n }));
  for (const verifier of [ZeroAddress, '0x12']) assert.throws(() => currentArtistOperationTypedData('saleConsent', chainId, verifier, messages.saleConsent));
  for (const chain of [0n, -1n, 1n << 256n, 1]) assert.throws(() => currentArtistOperationTypedData('saleConsent', chain, registry, messages.saleConsent));
});

test('requests and reconstructed actions reject extra fields, forged derived values and unknown variants', () => {
  const plan = prepareCurrentArtistAction(request('saleConsent'));
  assert.deepEqual(normalizeCurrentArtistAction(plan), plan);
  const mutations = [
    { ...plan, operationId: 20n }, { ...plan, method: 'authorizeArtistRoyaltyFreeze' },
    { ...plan, call: { ...plan.call, to: core } }, { ...plan, digestCall: { ...plan.digestCall, value: 1n } },
    { ...plan, payload: { ...plan.payload, digest: h(1) } }, { ...plan, payload: { ...plan.payload, domain: { ...plan.payload.domain, verifyingContract: core } } },
    { ...plan, fabricatedState: 'authorized' },
  ];
  for (const changed of mutations) assert.throws(() => normalizeCurrentArtistAction(changed));
  assert.throws(() => prepareCurrentArtistAction(request('saleConsent', { kind: 'unsupportedArtistOperation' })), /Unknown/);
  assert.throws(() => prepareCurrentArtistAction(request('saleConsent', { message: { ...messages.saleConsent, artistId } })), /unexpected/);
  assert.throws(() => prepareCurrentArtistAction(request('saleConsent', { details: { nonce } })), /unexpected/);
  const hidden = request('saleConsent'); Object.defineProperty(hidden.message, 'hidden', { value: 1 });
  assert.throws(() => prepareCurrentArtistAction(hidden), /unexpected/);
});

test('copied messages, arrays, details, payload fields and calls cannot mutate after preparation', () => {
  const input = request('contentFreeze'), plan = prepareCurrentArtistAction(input), original = plan.call.data;
  input.message.lockClasses.reverse(); input.message.nonce = 0n; input.caller = a(999);
  assert.equal(plan.call.data, original); assert.equal(plan.request.message.nonce, nonce);
  assert.deepEqual(plan.request.message.lockClasses, messages.contentFreeze.lockClasses);
  for (const mutate of [() => plan.request.message.lockClasses.push(h(9999)), () => { plan.call.value = 1n; },
    () => { plan.payload.types[plan.payload.primaryType][0].name = 'intruder'; }, () => { plan.request.caller = a(999); }]) assert.throws(mutate, TypeError);
  const uriInput = request('bindingRefusal'), uriPlan = prepareCurrentArtistAction(uriInput);
  uriInput.details.reasonURI = 'changed'; assert.notEqual(uriPlan.request.details.reasonURI, uriInput.details.reasonURI);
  const escaped = structuredClone(uriPlan), rebuilt = normalizeCurrentArtistAction(escaped);
  escaped.request.details.reasonURI = 'later'; assert.equal(rebuilt.request.details.reasonURI, uriPlan.request.details.reasonURI);
  const normalized = normalizeCurrentArtistOperationRequest(request('saleConsent'));
  assert.ok(Object.isFrozen(normalized.details)); assert.ok(Object.isFrozen(normalized.message));
});

test('bounded shared address arrays hash padded words and snapshot empty or nonempty arrays', () => {
  const guardians = [a(3), a(4)];
  const fields = [{ name: 'guardians', type: 'address[]' }];
  const make = (value, bounds = { guardians: { minimum: 0, maximum: 8 } }) => buildSigningPayload(chainId, registry, '6529StreamArtistRegistry', 'ArrayProbe', fields, { guardians: value }, bounds);
  const result = make(guardians);
  const structHash = body('ArrayProbe(address[] guardians)', ['bytes32'], [keccak256(concat(guardians.map(value => zeroPadValue(value, 32))))]);
  assert.equal(result.digest, typed(structHash));
  assert.notEqual(result.digest, typed(body('ArrayProbe(address[] guardians)', ['bytes32'], [keccak256(concat(guardians))])));
  guardians.reverse(); assert.deepEqual(result.message.guardians, [a(3), a(4)]); assert.ok(Object.isFrozen(result.message.guardians));
  assert.equal(make([]).digest, typed(body('ArrayProbe(address[] guardians)', ['bytes32'], [keccak256('0x')])));
  assert.throws(() => make(Array(9).fill(a(1))), /bounds/);
  assert.throws(() => make([a(1)], {}), /bounds/);
  assert.throws(() => make([a(1)], { guardians: { minimum: 0, maximum: Infinity } }), /bounds/);
  assert.throws(() => make([a(1)], { guardians: { minimum: 0, maximum: 8 }, other: { minimum: 0, maximum: 8 } }), /Unexpected/);
  assert.throws(() => make(['0x12']));
  assert.throws(() => buildSigningPayload(chainId, registry, 'Test', 'Nested', [{ name: 'rows', type: 'address[][]' }], { rows: [[a(1)]] }), /Unsupported/);
});

test('existing scalar Artist acceptance payload retains its independent original digest', () => {
  const message = { core, collectionId, bindingGeneration: 2n, bindingHash: h(201), identityRecordHash: h(300), nonce, deadline };
  const structHash = body('StreamArtistAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)',
    ['address','uint256','uint64','bytes32','bytes32','uint256','uint64'], [core,collectionId,2n,h(201),h(300),nonce,deadline]);
  assert.equal(currentArtistTypedData('artistAcceptance', chainId, registry, message).digest, typed(structHash));
});

const identityDocument = '0x7b226e616d65223a22417274697374227d';
const identityMessages = {
  identityRevision: { artistId, previousRecordHash: h(401), revisedRecordHash: keccak256(identityDocument), nonce, signedAt: (1n << 63n) + 1n },
  delegationGrant: { core, delegate: a(405), collectionId: 0n, capabilities: 117n, notBefore: 0n,
    expiresAt: (1n << 64n) - 1n, maxUses: 0n, constraintsHash: ZeroHash, nonce },
  delegationRevocation: { artistId, delegate: a(405), delegationRecordHash: h(406), reasonHash: ZeroHash, nonce, deadline },
};
function identityRequest(kind, changes = {}) {
  return { kind, chainId, registry, caller, signer, artistId, mode: 'signature', signature: '0x4321',
    message: structuredClone(identityMessages[kind]), details: kind === 'identityRevision'
      ? { identityRecordURI: 'ipfs://identity-🖼', document: identityDocument, displayName: 'Artist' } : {}, ...changes };
}

test('identity revision, grant and revocation reproduce the original scalar preimages independently', () => {
  const revision = identityMessages.identityRevision, grant = identityMessages.delegationGrant, revoke = identityMessages.delegationRevocation;
  const expected = {
    identityRevision: body('StreamArtistIdentityRevision(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt)',
      ['bytes32','bytes32','bytes32','uint256','uint64'], [artistId,revision.previousRecordHash,revision.revisedRecordHash,nonce,revision.signedAt],
      '0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603'),
    delegationGrant: body('StreamArtistDelegation(address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce)',
      ['address','address','uint256','uint32','uint64','uint64','uint64','bytes32','uint256'],
      [core,grant.delegate,0n,117n,0n,grant.expiresAt,0n,ZeroHash,nonce],
      '0x259b01d4bf9aa04d6f900a2f85548eebdbb07661fdf1eac68031895cadae6d0d'),
    delegationRevocation: body('StreamArtistDelegationRevocation(bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)',
      ['bytes32','address','bytes32','bytes32','uint256','uint64'], [artistId,revoke.delegate,revoke.delegationRecordHash,ZeroHash,nonce,deadline]),
  };
  for (const [kind, structHash] of Object.entries(expected)) {
    const payload = currentArtistOperationTypedData(kind, chainId, registry, identityMessages[kind]);
    assert.equal(payload.digest, typed(structHash));
    assert.notEqual(payload.digest, typed(structHash, chainId + 1n));
    assert.notEqual(payload.digest, typed(structHash, chainId, signer));
    assert.equal(payload.domain.name, '6529StreamArtistRegistry');
    assert.equal(payload.domain.version, '1');
  }
});

test('three identity calls retain compiler tuples, grant time zero and supplemental revision arguments', () => {
  const revision = identityMessages.identityRevision, grant = identityMessages.delegationGrant, revoke = identityMessages.delegationRevocation;
  const details = identityRequest('identityRevision').details;
  const rows = [
    ['identityRevision', 25n, 'recordIdentityRevision', 'identityRevisionDigest', [artistId,revision.previousRecordHash,revision.revisedRecordHash,details.identityRecordURI], revision.signedAt, [identityDocument,details.displayName]],
    ['delegationGrant', 26n, 'grantArtistDelegation', 'delegationGrantDigest', [artistId,grant.delegate,0n,117n,0n,grant.expiresAt,0n,ZeroHash], 0n, []],
    ['delegationRevocation', 27n, 'revokeArtistDelegation', 'delegationRevocationDigest', [artistId,revoke.delegate,revoke.delegationRecordHash,ZeroHash], deadline, []],
  ];
  const local = new Interface(CURRENT_ARTIST_OPERATION_ABI);
  for (const [kind, operationId, method, digestMethod, terms, time, tail] of rows) {
    const plan = prepareCurrentArtistAction(identityRequest(kind));
    assert.equal(plan.operationId, operationId); assert.equal(plan.method, method); assert.equal(plan.digestMethod, digestMethod);
    assert.deepEqual(plan.call, { to: registry, value: 0n, data: compiled.encodeFunctionData(method, [terms,[nonce,time,'0x4321'],...tail]) });
    assert.deepEqual(plan.digestCall, { to: registry, value: 0n, data: compiled.encodeFunctionData(digestMethod, [terms,[nonce,time,'0x']]) });
    assert.equal(local.getFunction(method).format('minimal'), compiled.getFunction(method).format('minimal'));
    assert.equal(local.getFunction(digestMethod).format('minimal'), compiled.getFunction(digestMethod).format('minimal'));
  }
});

test('direct revision zero stays a submitted sentinel and never claims an observed execution digest', () => {
  const message = { ...identityMessages.identityRevision, signedAt: 0n };
  const direct = prepareCurrentArtistAction(identityRequest('identityRevision', { caller: signer, mode: 'direct', signature: '0x', message }));
  assert.equal(direct.payload.message.signedAt, 0n);
  assert.equal(compiled.decodeFunctionData(direct.method, direct.call.data)[1].time, 0n);
  assert.equal(compiled.decodeFunctionData(direct.digestMethod, direct.digestCall.data)[1].time, 0n);
  const observed = currentArtistOperationTypedData('identityRevision', chainId, registry, { ...message, signedAt: 123n });
  assert.notEqual(observed.digest, direct.payload.digest);
  assert.throws(() => prepareCurrentArtistAction(identityRequest('identityRevision', { message })), /positive signedAt/);
  assert.throws(() => prepareCurrentArtistAction(identityRequest('identityRevision', { message, signature: '0x' })), /positive signedAt/);
  const explicitDirect = prepareCurrentArtistAction(identityRequest('identityRevision', { caller: signer, mode: 'direct', signature: '0x', message: { ...message, signedAt: 123n } }));
  assert.equal(explicitDirect.payload.digest, observed.digest); // Actual block-time equality belongs to workflow/simulation.
  const empty1271 = prepareCurrentArtistAction(identityRequest('identityRevision', { signature: '0x' }));
  assert.equal(empty1271.request.mode, 'signature');
});

test('revision document is committed while URI and display name remain original supplemental text', () => {
  const first = prepareCurrentArtistAction(identityRequest('identityRevision'));
  const changed = prepareCurrentArtistAction(identityRequest('identityRevision', {
    details: { identityRecordURI: '', document: identityDocument, displayName: 'Other display' },
  }));
  assert.equal(first.payload.digest, changed.payload.digest); assert.notEqual(first.call.data, changed.call.data);
  const changedNameOnly = prepareCurrentArtistAction(identityRequest('identityRevision', {
    details: { ...first.request.details, displayName: 'Other display' },
  }));
  assert.equal(first.digestCall.data, changedNameOnly.digestCall.data);
  assert.notEqual(first.call.data, changedNameOnly.call.data);
  const make = (document, details = {}) => prepareCurrentArtistAction(identityRequest('identityRevision', {
    message: { ...identityMessages.identityRevision, revisedRecordHash: keccak256(document) },
    details: { identityRecordURI: '', document, displayName: 'x', ...details },
  }));
  make('0xff'); make(`0x${'01'.repeat(8192)}`, { identityRecordURI: 'é'.repeat(1024), displayName: 'é'.repeat(128) });
  for (const document of ['0x', `0x${'01'.repeat(8193)}`]) assert.throws(() => make(document), /1\.\.8192/);
  assert.throws(() => prepareCurrentArtistAction(identityRequest('identityRevision', { details: { ...first.request.details, document: '0xff' } })), /revisedRecordHash/);
  for (const details of [{ identityRecordURI: 'é'.repeat(1025) }, { displayName: '' }, { displayName: 'é'.repeat(129) }, { displayName: '\udc00' }, { identityRecordURI: '\ud800' }]) assert.throws(() => make('0xff', details));
  assert.throws(() => currentArtistOperationTypedData('identityRevision', chainId, registry, {
    ...identityMessages.identityRevision, previousRecordHash: identityMessages.identityRevision.revisedRecordHash,
  }), /change the document/);
});

test('grant artist locator is call-bound outside the permanent digest and cannot smuggle a deadline', () => {
  const first = prepareCurrentArtistAction(identityRequest('delegationGrant'));
  const other = prepareCurrentArtistAction(identityRequest('delegationGrant', { artistId: h(499) }));
  assert.equal(first.payload.digest, other.payload.digest);
  assert.notEqual(first.call.data, other.call.data);
  assert.notEqual(first.digestCall.data, other.digestCall.data);
  assert.equal(compiled.decodeFunctionData(other.method, other.call.data)[0].artistId, h(499));
  assert.equal(compiled.decodeFunctionData(first.method, first.call.data)[1].time, 0n);
  for (const field of ['artistId','deadline','signedAt','time']) assert.throws(() => currentArtistOperationTypedData('delegationGrant', chainId, registry, {
    ...identityMessages.delegationGrant, [field]: field === 'artistId' ? artistId : 1n,
  }), /unexpected fields/);
  assert.throws(() => prepareCurrentArtistAction(identityRequest('delegationGrant', { details: { deadline: 1n } })), /unexpected fields/);
});

test('grant accepts original global, unlimited and zero constraints cases while enforcing capability and window widths', () => {
  const make = overrides => prepareCurrentArtistAction(identityRequest('delegationGrant', { message: { ...identityMessages.delegationGrant, ...overrides } }));
  for (const capabilities of [1n,4n,16n,32n,64n,117n]) make({ capabilities });
  make({ collectionId: (1n << 256n) - 1n, maxUses: (1n << 64n) - 1n, nonce: (1n << 256n) - 1n });
  make({ collectionId: 0n, maxUses: 0n, constraintsHash: ZeroHash, nonce: 0n });
  for (const capabilities of [0n,8n,128n,512n,1n << 32n,117]) assert.throws(() => make({ capabilities }));
  for (const changes of [{ notBefore: 10n, expiresAt: 10n }, { notBefore: 11n, expiresAt: 10n }, { maxUses: 1n << 64n },
    { notBefore: 1n << 64n }, { expiresAt: 1n << 64n }, { expiresAt: 4 }, { collectionId: 1 }, { delegate: ZeroAddress }, { delegate: signer }]) assert.throws(() => make(changes));
  make({ notBefore: 0n, expiresAt: 1n }); // Expiry relative to now is a live guard, not a local clock guess.
});

test('delegation revocation retains stored-grantor execution claim and admits a zero reason hash', () => {
  const formerGrantor = a(900), direct = prepareCurrentArtistAction(identityRequest('delegationRevocation', {
    signer: formerGrantor, caller: formerGrantor, mode: 'direct', signature: '0x',
  }));
  assert.equal(direct.request.signer, formerGrantor); assert.equal(direct.payload.message.reasonHash, ZeroHash);
  assert.equal(compiled.decodeFunctionData(direct.method, direct.call.data)[0].delegationRecordHash, h(406));
  assert.equal(compiled.decodeFunctionData(direct.method, direct.call.data)[1].time, deadline);
  // The pure packet does not replace the stored grantor with an assumed current authority.
  prepareCurrentArtistAction(identityRequest('delegationRevocation', { signer: formerGrantor, signature: '0x' }));
  assert.throws(() => prepareCurrentArtistAction(identityRequest('delegationRevocation', { artistId: h(499) })), /locator/);
  assert.throws(() => prepareCurrentArtistAction(identityRequest('identityRevision', { artistId: h(499) })), /locator/);
  for (const key of ['artistId','delegationRecordHash']) assert.throws(() => currentArtistOperationTypedData('delegationRevocation', chainId, registry, { ...identityMessages.delegationRevocation, [key]: ZeroHash }), /nonzero/);
});

test('three identity families snapshot all inputs and reject altered plans or lossy integer coercion', () => {
  for (const kind of Object.keys(identityMessages)) {
    const input = identityRequest(kind), plan = prepareCurrentArtistAction(input);
    assert.deepEqual(normalizeCurrentArtistAction(plan), plan);
    input.message.nonce = 0n; input.signer = a(901);
    assert.equal(plan.request.message.nonce, nonce);
    assert.throws(() => { plan.request.message.nonce = 0n; }, TypeError);
    assert.throws(() => normalizeCurrentArtistAction({ ...plan, operationId: 54n }), /reconstruction/);
    assert.throws(() => normalizeCurrentArtistAction({ ...plan, call: { ...plan.call, data: plan.digestCall.data } }), /reconstruction/);
    for (const value of [1,-1n,1n << 256n]) assert.throws(() => currentArtistOperationTypedData(kind, chainId, registry, { ...identityMessages[kind], nonce: value }));
  }
  for (const signedAt of [1,-1n,1n << 64n]) assert.throws(() => currentArtistOperationTypedData('identityRevision', chainId, registry, { ...identityMessages.identityRevision, signedAt }));
  for (const value of [1,-1n,1n << 64n]) assert.throws(() => currentArtistOperationTypedData('delegationRevocation', chainId, registry, { ...identityMessages.delegationRevocation, deadline: value }));
  const input = identityRequest('identityRevision'), plan = prepareCurrentArtistAction(input);
  input.details.displayName = 'mutated'; input.details.document = '0xff';
  assert.equal(plan.request.details.document, identityDocument); assert.equal(plan.request.details.displayName, 'Artist');
  assert.throws(() => { plan.request.details.displayName = 'mutated'; }, TypeError);
  const detached = structuredClone(plan), fresh = normalizeCurrentArtistAction(detached);
  detached.request.details.identityRecordURI = 'changed'; assert.notEqual(fresh.request.details.identityRecordURI, detached.request.details.identityRecordURI);
});

// Exact IStreamArtistDelegatedConsent source at 6d333842a3e827514702afa1d5e91415e5b21317.
// The parent compiler oracle separately binds these projections to the retained joined capture.
const delegatedSource = new Interface([
  'function recordDelegatedPolicyConsent((uint256 collectionId,bytes32 phaseId,bytes32 policyHash),bytes32 grant,(uint256 nonce,uint64 time,bytes signature)) returns(bytes32)',
  'function recordDelegatedSaleConsent((uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash),bytes32 grant,(uint256 nonce,uint64 time,bytes signature)) returns(bytes32)',
  'function policyConsentDigest((uint256 collectionId,bytes32 phaseId,bytes32 policyHash),(uint256 nonce,uint64 time,bytes signature)) view returns(bytes32)',
  'function saleConsentDigest((uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash),(uint256 nonce,uint64 time,bytes signature)) view returns(bytes32)',
]);
const delegatedMessages = {
  delegatedPolicyConsent: { core, mintManager: a(602), collectionId, phaseId: h(603), policyHash: h(604), nonce, deadline },
  delegatedSaleConsent: structuredClone(messages.saleConsent),
};
function delegatedRequest(kind, changes = {}) {
  return { kind, chainId, registry, caller, signer: a(601), artistId, mode: 'signature', signature: '0x6789',
    message: structuredClone(delegatedMessages[kind]), details: { grant: h(605) }, ...changes };
}

test('delegated consent reuses original policy and sale domains, schemas and full-width preimages', () => {
  const policy = delegatedMessages.delegatedPolicyConsent, sale = delegatedMessages.delegatedSaleConsent;
  const expected = {
    delegatedPolicyConsent: body('StreamArtistPolicyConsent(address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline)',
      ['address','address','uint256','bytes32','bytes32','uint256','uint64'], [core,policy.mintManager,collectionId,policy.phaseId,policy.policyHash,nonce,deadline]),
    delegatedSaleConsent: body('StreamArtistSaleConsent(address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline)',
      ['address','address','uint256','bytes32','bytes32','uint256','uint64'], [core,sale.saleAdapter,collectionId,sale.saleId,sale.saleConfigHash,nonce,deadline]),
  };
  for (const [kind, structHash] of Object.entries(expected)) {
    const payload = currentArtistOperationTypedData(kind, chainId, registry, delegatedMessages[kind]);
    assert.equal(payload.digest, typed(structHash));
    assert.notEqual(payload.digest, typed(structHash, chainId + 1n));
    assert.notEqual(payload.digest, typed(structHash, chainId, a(601)));
  }
  assert.deepEqual(currentArtistOperationTypedData('delegatedPolicyConsent', chainId, registry, policy), currentArtistTypedData('artistPolicyConsent', chainId, registry, policy));
  assert.deepEqual(currentArtistOperationTypedData('delegatedSaleConsent', chainId, registry, sale), currentArtistOperationTypedData('saleConsent', chainId, registry, sale));
});

test('delegated writes insert the grant before authorization while original getter calls omit it', () => {
  const local = new Interface(CURRENT_ARTIST_OPERATION_ABI), policy = delegatedMessages.delegatedPolicyConsent, sale = delegatedMessages.delegatedSaleConsent;
  const rows = [
    ['delegatedPolicyConsent', 14n, 'recordDelegatedPolicyConsent', 'policyConsentDigest', [collectionId,policy.phaseId,policy.policyHash], '0xeff0fffe'],
    ['delegatedSaleConsent', 16n, 'recordDelegatedSaleConsent', 'saleConsentDigest', [collectionId,sale.saleAdapter,sale.saleId,sale.saleConfigHash], '0x2cee8313'],
  ];
  for (const [kind, operationId, method, getter, terms, selector] of rows) {
    const plan = prepareCurrentArtistAction(delegatedRequest(kind));
    assert.equal(plan.operationId, operationId); assert.equal(plan.method, method); assert.equal(plan.digestMethod, getter);
    assert.equal(local.getFunction(method).selector, selector);
    assert.deepEqual(plan.call, { to: registry, value: 0n, data: delegatedSource.encodeFunctionData(method, [terms,h(605),[nonce,deadline,'0x6789']]) });
    assert.deepEqual(plan.digestCall, { to: registry, value: 0n, data: delegatedSource.encodeFunctionData(getter, [terms,[nonce,deadline,'0x']]) });
    assert.equal(local.getFunction(method).format('minimal'), delegatedSource.getFunction(method).format('minimal'));
  }
  assert.equal(CURRENT_ARTIST_OPERATION_ABI.filter(item => item.startsWith('function saleConsentDigest(')).length, 1);
});

test('grant selection changes reviewed calldata without creating an invented delegated signed field', () => {
  for (const kind of Object.keys(delegatedMessages)) {
    const first = prepareCurrentArtistAction(delegatedRequest(kind));
    const replacement = prepareCurrentArtistAction(delegatedRequest(kind, { details: { grant: h(606) } }));
    assert.equal(first.payload.digest, replacement.payload.digest);
    assert.equal(first.digestCall.data, replacement.digestCall.data);
    assert.notEqual(first.call.data, replacement.call.data);
    assert.throws(() => normalizeCurrentArtistAction({ ...first, request: replacement.request }), /reconstruction/);
    for (const key of ['grant','artistId','delegate','consentMode']) assert.throws(() => currentArtistOperationTypedData(kind, chainId, registry, {
      ...delegatedMessages[kind], [key]: key === 'consentMode' ? 2n : h(606),
    }), /unexpected fields/);
  }
});

test('delegated direct calls require the actual claimed delegate caller and preserve empty ERC-1271 relays', () => {
  for (const kind of Object.keys(delegatedMessages)) {
    const direct = prepareCurrentArtistAction(delegatedRequest(kind, { caller: a(601), mode: 'direct', signature: '0x' }));
    assert.equal(delegatedSource.decodeFunctionData(direct.method, direct.call.data)[2].signature, '0x');
    const relay = prepareCurrentArtistAction(delegatedRequest(kind, { signature: '0x' }));
    assert.equal(relay.request.caller, caller); assert.equal(relay.request.signer, a(601));
    assert.equal(relay.request.mode, 'signature');
    assert.throws(() => prepareCurrentArtistAction(delegatedRequest(kind, { mode: 'direct', signature: '0x' })), /predicate/);
    assert.throws(() => prepareCurrentArtistAction(delegatedRequest(kind, { caller: a(601), signature: '0x' })), /predicate/);
    assert.throws(() => prepareCurrentArtistAction(delegatedRequest(kind, { caller: a(601), mode: 'direct' })), /predicate/);
  }
});

test('new policy and sale grant capability bits extend the original mask without admitting other powers', () => {
  const make = capabilities => prepareCurrentArtistAction(identityRequest('delegationGrant', {
    message: { ...identityMessages.delegationGrant, capabilities },
  }));
  for (const capabilities of [2n,1024n,1026n,1143n,117n,1n,4n,16n,32n,64n]) {
    const plan = make(capabilities);
    assert.equal(plan.payload.message.capabilities, capabilities);
    assert.equal(compiled.decodeFunctionData(plan.method, plan.call.data)[1].time, 0n);
  }
  assert.notEqual(make(2n).payload.digest, make(1024n).payload.digest);
  for (const capabilities of [0n,8n,128n,256n,512n,2048n,1143n | 8n,1n << 32n,1143]) assert.throws(() => make(capabilities));
});

test('delegated requests reject missing grants, extra authorities, lossy widths and mutable derived packets', () => {
  for (const kind of Object.keys(delegatedMessages)) {
    for (const details of [{}, { grant: ZeroHash }, { grant: '0x12' }, { grant: h(605), capabilities: 2n }]) assert.throws(() => prepareCurrentArtistAction(delegatedRequest(kind, { details })));
    for (const changes of [{ collectionId: 0n }, { nonce: 1 }, { nonce: 1n << 256n }, { deadline: 1 }, { deadline: 1n << 64n }, { core: ZeroAddress }]) assert.throws(() => prepareCurrentArtistAction(delegatedRequest(kind, { message: { ...delegatedMessages[kind], ...changes } })));
    const input = delegatedRequest(kind), plan = prepareCurrentArtistAction(input);
    assert.deepEqual(normalizeCurrentArtistAction(plan), plan);
    input.message.nonce = 0n; input.details.grant = h(699); input.signer = signer;
    assert.equal(plan.request.message.nonce, nonce); assert.equal(plan.request.details.grant, h(605));
    assert.throws(() => { plan.request.details.grant = h(699); }, TypeError);
    assert.throws(() => normalizeCurrentArtistAction({ ...plan, operationId: 26n }), /reconstruction/);
    assert.throws(() => normalizeCurrentArtistAction({ ...plan, call: { ...plan.call, value: 1n } }), /reconstruction/);
  }
  for (const key of ['phaseId','policyHash']) assert.throws(() => currentArtistOperationTypedData('delegatedPolicyConsent', chainId, registry, { ...delegatedMessages.delegatedPolicyConsent, [key]: ZeroHash }), /nonzero/);
  assert.throws(() => currentArtistOperationTypedData('delegatedPolicyConsent', chainId, registry, { ...delegatedMessages.delegatedPolicyConsent, mintManager: ZeroAddress }), /nonzero/);
});

const economicsMessage = { core, resolver: a(701), revenueClass: id('PRIMARY_SALE'), scope: 1n,
  scopeId: collectionId, assignmentHash: h(702), nonce, deadline };
const fixedCandidate = { profileHash: h(703), policyHash: ZeroHash, royaltyBps: 0n, frozen: false };
const economicMessages = {
  delegatedEconomicsConsent: economicsMessage,
  delegatedProspectiveEconomicsConsent: economicsMessage,
  delegatedRoyaltyFreeze: messages.royaltyFreeze,
};
function economicRequest(kind, changes = {}) {
  return { kind, chainId, registry, caller, signer: a(704), artistId, mode: 'signature', signature: '0x5678',
    message: structuredClone(economicMessages[kind]),
    details: kind === 'delegatedRoyaltyFreeze' ? { grant: h(705) }
      : { collectionId, grant: h(705), ...(kind === 'delegatedProspectiveEconomicsConsent' ? { candidate: { ...fixedCandidate } } : {}) },
    ...changes };
}

test('delegated current and prospective economics preserve the same original digest and facade domain', () => {
  const m = economicsMessage;
  const expected = typed(body('StreamArtistEconomicsConsent(address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline)',
    ['address','address','bytes32','uint8','uint256','bytes32','uint256','uint64'],
    [core,m.resolver,m.revenueClass,1n,collectionId,m.assignmentHash,nonce,deadline]));
  for (const kind of ['delegatedEconomicsConsent','delegatedProspectiveEconomicsConsent']) {
    const payload = currentArtistOperationTypedData(kind, chainId, registry, m);
    assert.equal(payload.digest, expected);
    assert.deepEqual(payload, currentArtistTypedData('artistEconomicsConsent', chainId, registry, m));
    assert.notEqual(payload.digest, currentArtistOperationTypedData(kind, chainId + 1n, registry, m).digest);
    assert.notEqual(payload.digest, currentArtistOperationTypedData(kind, chainId, a(704), m).digest);
    for (const key of ['collectionId','grant','candidate','payoutDesignationHash','artistId','delegate']) {
      assert.throws(() => currentArtistOperationTypedData(kind, chainId, registry, { ...m, [key]: h(706) }), /unexpected fields/);
    }
  }
  assert.deepEqual(currentArtistOperationTypedData('delegatedRoyaltyFreeze', chainId, registry, messages.royaltyFreeze),
    currentArtistOperationTypedData('royaltyFreeze', chainId, registry, messages.royaltyFreeze));
});

test('three delegated economic transports match compiled argument order and original digest getter calls', () => {
  const local = new Interface(CURRENT_ARTIST_OPERATION_ABI), m = economicsMessage, r = messages.royaltyFreeze;
  const terms = [collectionId,m.resolver,m.revenueClass,1n,collectionId,m.assignmentHash];
  const rows = [
    ['delegatedEconomicsConsent',15n,'recordDelegatedEconomicsConsent','economicsConsentDigest',terms,[], '0x23a38d6d'],
    ['delegatedProspectiveEconomicsConsent',15n,'recordDelegatedProspectiveEconomicsConsent','economicsConsentDigest',terms,[fixedCandidate], '0x09eed2fe'],
    ['delegatedRoyaltyFreeze',20n,'authorizeDelegatedRoyaltyFreeze','royaltyFreezeDigest',[r.resolver,collectionId,r.revenueClass,r.expectedAssignmentHash],[], '0x04005067'],
  ];
  for (const [kind,operationId,method,getter,terms,candidate,selector] of rows) {
    const plan = prepareCurrentArtistAction(economicRequest(kind));
    assert.equal(plan.operationId, operationId); assert.equal(plan.method, method); assert.equal(plan.digestMethod, getter);
    assert.equal(local.getFunction(method).selector, selector);
    assert.deepEqual(plan.call, { to: registry, value: 0n, data: compiled.encodeFunctionData(method, [terms,...candidate,h(705),[nonce,deadline,'0x5678']]) });
    assert.deepEqual(plan.digestCall, { to: registry, value: 0n, data: compiled.encodeFunctionData(getter, [terms,[nonce,deadline,'0x']]) });
    for (const name of [method,getter]) assert.equal(local.getFunction(name).format('minimal'), compiled.getFunction(name).format('minimal'));
  }
  for (const getter of ['economicsConsentDigest','royaltyFreezeDigest']) {
    assert.equal(CURRENT_ARTIST_OPERATION_ABI.filter(item => item.startsWith(`function ${getter}(`)).length, 1);
  }
});

test('economics collection, grant and candidate remain separate from signed fields and each other', () => {
  const input = economicRequest('delegatedProspectiveEconomicsConsent', { message: { ...economicsMessage, scope: 2n, scopeId: (1n << 255n) + 3n } });
  const original = prepareCurrentArtistAction(input);
  const otherCollection = prepareCurrentArtistAction({ ...input, details: { ...input.details, collectionId: collectionId + 1n } });
  assert.equal(original.payload.digest, otherCollection.payload.digest);
  assert.notEqual(original.call.data, otherCollection.call.data);
  assert.notEqual(original.digestCall.data, otherCollection.digestCall.data); // The getter's original tuple still contains collectionId.
  for (const details of [{ ...input.details, grant: h(706) }, { ...input.details, candidate: { ...fixedCandidate, profileHash: h(707), frozen: true } }]) {
    const other = prepareCurrentArtistAction({ ...input, details });
    assert.equal(original.payload.digest, other.payload.digest);
    assert.equal(original.digestCall.data, other.digestCall.data);
    assert.notEqual(original.call.data, other.call.data);
  }
  assert.throws(() => prepareCurrentArtistAction(economicRequest('delegatedEconomicsConsent', { details: { collectionId: collectionId + 1n, grant: h(705) } })), /collection context/);
  const currentDefault = prepareCurrentArtistAction(economicRequest('delegatedEconomicsConsent', { message: { ...economicsMessage, scope: 0n, scopeId: 0n } }));
  assert.equal(currentDefault.payload.message.scopeId, 0n);
  assert.throws(() => prepareCurrentArtistAction(economicRequest('delegatedProspectiveEconomicsConsent', { message: { ...economicsMessage, scope: 0n, scopeId: 0n } })), /collection or token scope/);
  for (const changes of [{ scope: 0n, scopeId: 1n }, { scope: 1n, scopeId: 0n }, { scope: 2n, scopeId: 0n }, { scope: 3n }, { scope: 256n }, { scope: 1 }]) {
    assert.throws(() => currentArtistOperationTypedData('delegatedEconomicsConsent', chainId, registry, { ...economicsMessage, ...changes }));
  }
});

test('only prospective clearing accepts a zero assignment with the exact original zero candidate', () => {
  const candidate = { profileHash: ZeroHash, policyHash: ZeroHash, royaltyBps: 0n, frozen: false };
  const input = economicRequest('delegatedProspectiveEconomicsConsent', { message: { ...economicsMessage, assignmentHash: ZeroHash }, details: { collectionId, grant: h(705), candidate } });
  const plan = prepareCurrentArtistAction(input);
  assert.equal(plan.payload.message.assignmentHash, ZeroHash);
  assert.equal(compiled.decodeFunctionData(plan.method, plan.call.data)[0].assignmentHash, ZeroHash);
  assert.equal(compiled.decodeFunctionData(plan.method, plan.call.data)[1].profileHash, ZeroHash);
  assert.throws(() => prepareCurrentArtistAction({ ...input, kind: 'delegatedEconomicsConsent', details: { collectionId, grant: h(705) } }), /nonzero/);
  for (const change of [{ profileHash: h(703) }, { policyHash: h(704) }, { profileHash: h(703), royaltyBps: 1n }, { frozen: true }]) {
    assert.throws(() => prepareCurrentArtistAction({ ...input, details: { ...input.details, candidate: { ...candidate, ...change } } }));
  }
  const configuredZeroRoyalty = prepareCurrentArtistAction({ ...input, message: { ...input.message, revenueClass: id('ROYALTY_ERC2981'), assignmentHash: h(708) } });
  assert.notEqual(configuredZeroRoyalty.payload.digest, plan.payload.digest);
  assert.equal(configuredZeroRoyalty.request.details.candidate.profileHash, ZeroHash);
  // This is a candidate packet: only the pinned original resolver preview proves its clear/current assignment relationship.
});

test('fixed economics candidate validates original widths and bounds without guessing the resolver role', () => {
  const make = candidate => prepareCurrentArtistAction(economicRequest('delegatedProspectiveEconomicsConsent', {
    details: { collectionId, grant: h(705), candidate },
  }));
  make({ ...fixedCandidate, frozen: true });
  make({ ...fixedCandidate, royaltyBps: 1000n });
  make({ ...fixedCandidate, profileHash: ZeroHash });
  for (const changes of [{ policyHash: h(703) }, { royaltyBps: 1001n }, { royaltyBps: 1n << 16n }, { royaltyBps: -1n },
    { royaltyBps: 1 }, { profileHash: ZeroHash, royaltyBps: 1n }, { profileHash: '0x' }, { frozen: 0 }, { templateId: h(703) }]) {
    assert.throws(() => make({ ...fixedCandidate, ...changes }));
  }
  assert.throws(() => make({ profileHash: h(703), policyHash: ZeroHash, royaltyBps: 0n }), /unexpected fields/);
  for (const kind of ['delegatedEconomicsConsent','delegatedProspectiveEconomicsConsent']) {
    for (const value of [0n,1,-1n,1n << 256n]) assert.throws(() => prepareCurrentArtistAction(economicRequest(kind, {
      message: { ...economicsMessage, scope: 2n, scopeId: 1n },
      details: { ...economicRequest(kind).details, collectionId: value },
    })));
  }
  assert.throws(() => prepareCurrentArtistAction(economicRequest('delegatedRoyaltyFreeze', { message: { ...messages.royaltyFreeze, revenueClass: id('PRIMARY_SALE') } })), /ROYALTY_ERC2981/);
});

test('economic delegated transports preserve actual delegate direct calls and empty contract-wallet relays', () => {
  for (const kind of Object.keys(economicMessages)) {
    const direct = prepareCurrentArtistAction(economicRequest(kind, { caller: a(704), mode: 'direct', signature: '0x' }));
    const authorization = compiled.decodeFunctionData(direct.method, direct.call.data)[kind === 'delegatedProspectiveEconomicsConsent' ? 3 : 2];
    assert.equal(authorization.signature, '0x'); assert.equal(authorization.time, deadline);
    const relay = prepareCurrentArtistAction(economicRequest(kind, { signature: '0x' }));
    assert.equal(relay.request.mode, 'signature'); assert.notEqual(relay.request.caller, relay.request.signer);
    assert.equal(direct.payload.digest, relay.payload.digest);
    assert.throws(() => prepareCurrentArtistAction(economicRequest(kind, { mode: 'direct', signature: '0x' })), /predicate/);
    assert.throws(() => prepareCurrentArtistAction(economicRequest(kind, { caller: a(704), signature: '0x' })), /predicate/);
    const maximum = prepareCurrentArtistAction(economicRequest(kind, { signature: `0x${'12'.repeat(4096)}` }));
    assert.equal(maximum.request.signature.length, 8194);
    assert.throws(() => prepareCurrentArtistAction(economicRequest(kind, { signature: `0x${'12'.repeat(4097)}` })), /4096/);
  }
});

test('economic requests freeze nested candidates and reconstruct every unsigned supplement', () => {
  for (const kind of Object.keys(economicMessages)) {
    const input = economicRequest(kind), plan = prepareCurrentArtistAction(input);
    assert.deepEqual(normalizeCurrentArtistAction(plan), plan);
    input.message.nonce = 0n; input.details.grant = h(799);
    assert.equal(plan.request.message.nonce, nonce); assert.equal(plan.request.details.grant, h(705));
    assert.throws(() => { plan.request.details.grant = h(799); }, TypeError);
    for (const details of [{}, { ...plan.request.details, grant: ZeroHash }, { ...plan.request.details, grant: h(705), authorityClass: 2n }]) {
      assert.throws(() => prepareCurrentArtistAction({ ...plan.request, details }));
    }
    assert.throws(() => normalizeCurrentArtistAction({ ...plan, call: { ...plan.call, data: plan.digestCall.data } }), /reconstruction/);
    assert.throws(() => normalizeCurrentArtistAction({ ...plan, request: { ...plan.request, details: { ...plan.request.details, grant: h(799) } } }), /reconstruction/);
  }
  const input = economicRequest('delegatedProspectiveEconomicsConsent'), plan = prepareCurrentArtistAction(input);
  input.details.candidate.profileHash = h(799); input.details.candidate.frozen = true;
  assert.deepEqual(plan.request.details.candidate, fixedCandidate);
  assert.throws(() => { plan.request.details.candidate.frozen = true; }, TypeError);
  const detached = structuredClone(plan), normalized = normalizeCurrentArtistAction(detached);
  detached.request.details.candidate.profileHash = h(799);
  assert.deepEqual(normalized.request.details.candidate, fixedCandidate);
  assert.throws(() => normalizeCurrentArtistAction(detached), /reconstruction/);
  assert.throws(() => prepareCurrentArtistAction(economicRequest('delegatedEconomicsConsent', { details: { collectionId, grant: h(705), candidate: fixedCandidate } })), /unexpected fields/);
});
