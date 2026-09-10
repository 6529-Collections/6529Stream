#!/usr/bin/env node
import { mkdtempSync, readFileSync, writeFileSync, copyFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
const here=dirname(fileURLToPath(import.meta.url));
const root=mkdtempSync(join(tmpdir(),'stream-collector-test-'));
let count=0;
try {
  const script=readFileSync(join(here,'collector/field-studies.js'),'utf8').replace(/[\r\n]+$/,'');
  writeFileSync(join(root,'field-studies.js'),script);
  copyFileSync(join(here,'verify_current_stack_collector.mjs'),join(root,'verify.mjs'));
  const collection={schema:'6529stream.collector-field-studies.v1',collectionStatus:'2',collectionFreezeStatus:true,collectionBurnsBlocked:true,royalty:['wallet','690',true,true],metadata:['Field Studies','Test metadata','','',script,true],collectionId:'2',artist:'0x0000000000000000000000000000000000000001',attribution:['nominated','artist','0x'+'11'.repeat(32),'nomination','0x'+'22'.repeat(32)],blockNumber:'375',blockHash:'0x'+'33'.repeat(32),core:'0x0000000000000000000000000000000000000002',tokens:[]};
  for(let n=2;n<=4;n++) {
    const t={tokenId:String(n),collectionId:'2',serial:String(n-1),seed:'0x'+String(n).repeat(64),tokenData:'0x616263'};
    collection.tokens.push(t);
    const body=`const tokenId=${t.tokenId};const tokenHash='${t.seed}';const tokenDataBase64='YWJj';${script}`;
    const html=`<html><head></head><body><script>${body}</script></body></html>`;
    const m={name:`Field Studies #${t.serial}`,description:'Test metadata',image:'',metadata_schema_version:'6529stream-v1',metadata_state:'final',token_id:n,collection_id:2,collection_serial:n-1,hash:t.seed,token_data_location:'animation_url:tokenDataBase64',attributes:[],artist:collection.artist,artist_identity_hash:collection.attribution[2],artist_acceptance_hash:collection.attribution[4],animation_url:`data:text/html;base64,${Buffer.from(html).toString('base64')}`};
    writeFileSync(join(root,`token-${n}.html`),html);writeFileSync(join(root,`token-${n}.metadata.json`),JSON.stringify(m));
  }
  writeFileSync(join(root,'collection.json'),JSON.stringify(collection));
  const run=(args=[])=>execFileSync(process.execPath,[join(root,'verify.mjs'),root,...args],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
  assert.equal(JSON.parse(run(['--materialize'])).result,'PASS');count++;
  const expected=createHash('sha256').update(readFileSync(join(root,'manifest.json'))).digest('hex');
  assert.equal(JSON.parse(run(['--expected-manifest-sha256',expected])).result,'PASS');count++;
  function rejects(action,pattern) {assert.throws(action,e=>pattern.test(e.stderr?.toString()??e.message));count++;}
  rejects(()=>run(['--materialize']),/Refusing to replace/);
  for(const [file,mutate,pattern] of [
    ['token-2.metadata.json',b=>Buffer.from(b.toString().replace('Field Studies #1','Changed')),/metadata differs/],
    ['token-2.html',b=>Buffer.concat([b,Buffer.from(' ')]),/HTML differs/],
    ['field-studies.js',b=>Buffer.concat([b,Buffer.from(' ')]),/Unsupported renderer/],
    ['token-2.svg',b=>Buffer.concat([b,Buffer.from(' ')]),/SVG differs/],
    ['collection.json',b=>Buffer.from(b.toString().replace('"collectionFreezeStatus":true','"collectionFreezeStatus":false')),/not recorded frozen/],
    ['collection.json',b=>Buffer.from(b.toString().replace('"tokenData":"0x616263"','"tokenData":"0x616264"')),/HTML differs/],
    ['collection.json',b=>Buffer.from(b.toString().replace('\"collectionFreezeStatus\":true','\"collectionFreezeStatus\":\"false\"')),/not recorded frozen/],
    ['collection.json',b=>Buffer.from(b.toString().replace('\"blockNumber\":\"375\"','\"blockNumber\":\"<script>alert(1)</script>\"')),/canonical decimal blockNumber/],
    ['collection.json',b=>Buffer.from(b.toString().replace('\"serial\":\"1\"','\"serial\":\"01\"')),/canonical decimal serial/],
    ['manifest.json',b=>Buffer.concat([b,Buffer.from(' ')]),/manifest membership/]
  ]) {
    const path=join(root,file),before=readFileSync(path);writeFileSync(path,mutate(before));rejects(()=>run(),pattern);writeFileSync(path,before);
  }
  rejects(()=>run(['--expected-manifest-sha256']),/exactly64 lowercase hex/);
  rejects(()=>run(['--expected-manifest-sha256','00'.repeat(32)]),/independently retained expected hash/);

  const verifierPath=join(root,'verify.mjs'), verifierBytes=readFileSync(verifierPath), marker=join(root,'UNTRUSTED-EXECUTED');
  writeFileSync(verifierPath,`import{writeFileSync}from'node:fs';writeFileSync(${JSON.stringify(marker)},'executed');`);
  rejects(()=>execFileSync(process.execPath,[join(here,'verify_current_stack_collector.mjs'),root],{stdio:['ignore','pipe','pipe']}),/manifest membership/);
  assert.equal(existsSync(marker),false);count++;writeFileSync(verifierPath,verifierBytes);
  assert.equal(JSON.parse(run()).result,'PASS');count++;
  console.log(`PASS: ${count} portable collector checks; no RPC or transactions.`);
} finally {rmSync(root,{recursive:true,force:true});}
