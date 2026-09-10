#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';
import { runInNewContext } from 'node:vm';

const RENDERER_SHA256 = 'c7326548be89feac50df10ea0dfc36e309d8d9e36d60ef448fb8d43510052ad3';
const sha = data => createHash('sha256').update(data).digest('hex');
const fail = message => { throw new Error(message); };
const directory = resolve(process.argv[2] ?? '.');
const materialize = process.argv.includes('--materialize');
const expectedIndex = process.argv.indexOf('--expected-manifest-sha256');
const expectedHash = expectedIndex < 0 ? undefined : process.argv[expectedIndex + 1];
const read = name => readFileSync(join(directory, name));
if (materialize && existsSync(join(directory,'manifest.json'))) fail('Refusing to replace an existing collector manifest.');
const renderer = read('field-studies.js');
if (sha(renderer) !== RENDERER_SHA256) fail('Unsupported renderer: this verifier executes only its exact reviewed Field Studies bytes.');
const collection = JSON.parse(read('collection.json'));
const positiveDecimal = (value, label) => {
  if (typeof value !== 'string' || !/^[1-9][0-9]*$/.test(value) || BigInt(value) >= 1n << 256n) fail(`Invalid canonical decimal ${label}.`);
};
const hex = (value, bytes, label) => {
  if (typeof value !== 'string' || !new RegExp(`^0x[0-9a-fA-F]{${bytes*2}}$`).test(value)) fail(`Invalid ${label}.`);
};
positiveDecimal(collection.collectionId,'collectionId'); positiveDecimal(collection.blockNumber,'blockNumber');
hex(collection.blockHash,32,'blockHash'); hex(collection.core,20,'Core address'); hex(collection.artist,20,'artist address');
hex(collection.attribution?.[2],32,'artist identity hash'); hex(collection.attribution?.[4],32,'artist acceptance hash');
if (expectedIndex >= 0 && (typeof expectedHash !== 'string' || !/^[0-9a-f]{64}$/.test(expectedHash))) fail('Expected manifest SHA-256 must be exactly64 lowercase hex characters.');

if (collection.schema !== '6529stream.collector-field-studies.v1' || collection.collectionStatus !== '2' || collection.collectionFreezeStatus !== true || collection.collectionBurnsBlocked !== true || collection.royalty[3] !== true) fail('Collection or royalty is not recorded frozen.');
if (!Array.isArray(collection.tokens) || collection.tokens.length !== 3 || new Set(collection.tokens.map(t => t.tokenId)).size !== 3) fail('Expected three distinct selected artworks.');
if (collection.metadata[4] !== renderer.toString('utf8')) fail('Renderer differs from recorded collection input.');
const files = ['collection.json','field-studies.js','verify.mjs'];
const names = [];
for (const token of collection.tokens) {
  positiveDecimal(token.tokenId,'tokenId'); positiveDecimal(token.collectionId,'token.collectionId'); positiveDecimal(token.serial,'serial');
  if (!/^[1-9][0-9]*$/.test(token.tokenId) || !/^0x[0-9a-f]{64}$/.test(token.seed) || !/^0x(?:[0-9a-fA-F]{2})*$/.test(token.tokenData) || token.collectionId !== collection.collectionId) fail('Invalid retained rendering input.');
  const prefix = `token-${token.tokenId}`;
  const body = `const tokenId=${token.tokenId};const tokenHash='${token.seed}';const tokenDataBase64='${Buffer.from(token.tokenData.slice(2), 'hex').toString('base64')}';${renderer.toString('utf8')}`;
  const html = `<html><head></head><body><script>${body}</script></body></html>`;
  if (!read(`${prefix}.html`).equals(Buffer.from(html))) fail(`Onchain HTML differs from reconstructed inputs for ${prefix}.`);
  const expected = {
    name: `${collection.metadata[0]} #${token.serial}`, description: collection.metadata[1], image: collection.metadata[2],
    metadata_schema_version: '6529stream-v1', metadata_state: 'final', token_id: Number(token.tokenId), collection_id: Number(token.collectionId), collection_serial: Number(token.serial),
    hash: token.seed, token_data_location: 'animation_url:tokenDataBase64', attributes: [], artist: collection.artist.toLowerCase(),
    artist_identity_hash: collection.attribution[2], artist_acceptance_hash: collection.attribution[4], animation_url: `data:text/html;base64,${Buffer.from(html).toString('base64')}`
  };
  if (![token.tokenId,token.collectionId,token.serial].every(v => Number.isSafeInteger(Number(v)))) fail('This scoped example only accepts safely represented token numbers.');
  if (read(`${prefix}.metadata.json`).toString('utf8') !== JSON.stringify(expected)) fail(`Onchain metadata differs from independently assembled inputs for ${prefix}.`);
  // Exact authored renderer allowlist above, not a sandbox for arbitrary artwork.
  const document = { body: { style: {}, innerHTML: '' } };
  runInNewContext(body, { document }, { timeout: 1000 });
  const svg = document.body.innerHTML;
  if (!svg.startsWith('<svg ') || !svg.endsWith('</svg>')) fail('Renderer did not produce SVG.');
  if (materialize) writeFileSync(join(directory, `${prefix}.svg`), svg);
  else if (!read(`${prefix}.svg`).equals(Buffer.from(svg))) fail(`Portable SVG differs for ${prefix}.`);
  files.push(`${prefix}.metadata.json`,`${prefix}.html`,`${prefix}.svg`);
  names.push(prefix);
}
const preview = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Stream Field Studies</title><style>body{margin:32px;background:#111820;color:#f4efe5;font:16px system-ui}main{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}img{width:100%}a{color:inherit}@media(max-width:700px){main{grid-template-columns:1fr}}</style><h1>Stream Field Studies</h1><p>Collection ${collection.collectionId} &middot; retained at block ${collection.blockNumber}. Reconstructed locally from committed rendering inputs.</p><main>${names.map(n=>`<article><img src="${n}.svg" alt="${n}"><p><a href="${n}.metadata.json">${n} metadata</a> &middot; <a href="${n}.html">original HTML</a></p></article>`).join('')}</main><p><a href="README.txt">Read the collector guide</a>: collection-local freeze does not freeze global pointer authority. This local demo uses controller-supplied entropy.</p></html>`;
if (materialize) writeFileSync(join(directory,'index.html'),preview);
else if (!read('index.html').equals(Buffer.from(preview))) fail('Collector preview differs.');
files.push('index.html');
const readme = `STREAM FIELD STUDIES - PORTABLE COLLECTOR PACKAGE

Collection ${collection.collectionId}; Core ${collection.core}; block ${collection.blockNumber} (${collection.blockHash}).

Open index.html for the static SVG gallery. Metadata JSON and original HTML are included. The verifier rebuilds the exact metadata and HTML from retained token bytes, finalized seed, stored script and artist inputs, then regenerates SVG without RPC access.

Use a trusted verifier: node verify.mjs . --expected-manifest-sha256 <independently-retained-sha256>. A supplied verifier is executable code; trust its source/hash first, or use the repository-owned scripts/verify_current_stack_collector.mjs with this directory as data. Hash integrity alone is not chain authenticity.

Collection closure prevents mints, burn blocking prevents burns, and collection freeze blocks the current router's collection edits. The selected royalty resolver's record is separately frozen. Token identity/data were immutable at mint. Transfers remain possible. Global metadata, entropy, artist and royalty pointers remain governed; future Core tokenURI and royaltyInfo can change through pointer replacement. The package pins the observed addresses/code/input/output instead of claiming global pointer freeze. No separate token freeze or complete artwork-finality registry is installed.

This is local Anvil evidence with controller-supplied entropy, not secure randomness or production-readiness proof.
`;
if (materialize) writeFileSync(join(directory,'README.txt'),readme);
else if (!read('README.txt').equals(Buffer.from(readme))) fail('Collector scope guide differs.');
files.push('README.txt');
const manifest = {schema:'6529stream.collector-package.v1',blockNumber:collection.blockNumber,blockHash:collection.blockHash,core:collection.core,collectionId:collection.collectionId,files:files.sort().map(path=>({path,bytes:read(path).length,sha256:sha(read(path))})),scope:'Exact retained inputs and deterministic Field Studies metadata/HTML/SVG; no consensus or universal artwork-finality proof.'};
const manifestBytes = Buffer.from(JSON.stringify(manifest,null,2)+'\n');
if (materialize) {
  writeFileSync(join(directory,'manifest.json'),manifestBytes);
} else if (!read('manifest.json').equals(manifestBytes)) fail('Collector manifest membership, byte lengths or hashes differ.');
if (expectedHash && expectedHash !== sha(manifestBytes)) fail('Manifest differs from the independently retained expected hash.');
console.log(JSON.stringify({result:'PASS',artworks:3,files:files.length,manifestSha256:sha(manifestBytes),verification:'Offline: exact metadata/HTML reconstruction and deterministic SVG; no RPC.'}));
