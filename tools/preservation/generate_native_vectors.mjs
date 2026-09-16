/* Offline oracle: execute the pinned upstream functions with Node SHA256/concat. */
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
const fs = require('node:fs');
const path = require('node:path');
const __dirname=path.dirname(fileURLToPath(import.meta.url));
const crypto = require('node:crypto');
const {stripTypeScriptTypes} = require('node:module');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(__dirname, 'standards/arweave-js/merkle.ts.txt'), 'utf8');
const hash = raw => crypto.createHash('sha256').update(raw).digest('hex');
if (hash(source) !== '19c033264b8bf29c000ae98a90a5d09b46579aaca0a460a8ca70ee73e2ed80cd') throw Error('source pin');
const shim = `import crypto from 'node:crypto';
const nativeHash=async b=>new Uint8Array(crypto.createHash('sha256').update(b).digest());
const concatBuffers=items=>new Uint8Array(Buffer.concat(items.map(x=>Buffer.from(x))));
const Arweave={crypto:{hash:nativeHash},utils:{concatBuffers}};\n`;
const executable = shim + stripTypeScriptTypes(source
  .replace('import Arweave from "../common";', '')
  .replace('import { concatBuffers } from "./utils";', ''), {mode:'strip'});
(async () => {
  const api = await import('data:text/javascript;base64,'+Buffer.from(executable).toString('base64'));
  const vectors=[];
  for (const size of [1,4,262143,262144,262145,294911,294912,294913,524288,524289,786439]) {
    const bytes=Uint8Array.from({length:size},(_,i)=>(i*17+29)%256);
    const result=await api.generateTransactionChunks(bytes);
    vectors.push({size,sha256:hash(bytes),dataRoot:Buffer.from(result.data_root).toString('hex'),
      chunks:result.chunks.map((c,i)=>({start:c.minByteRange,end:c.maxByteRange,
        sha256:Buffer.from(c.dataHash).toString('hex'),path:Buffer.from(result.proofs[i].proof).toString('hex')}))});
  }
  const output={qualification:'Offline exact upstream function-body oracle; deterministic byte[i]=(i*17+29)%256. No network inclusion.',
    sourceCommit:'af2073ae0025c6d68535f1dcea3d7d94962ace4f',sourceSha256:hash(source),vectors};
  const target=path.join(root,'test/fixtures/preservation/arweave-external-native-v1.json');
  const bytes=JSON.stringify(output,null,2)+'\n';
  if(process.argv.includes('--check')) {
    if(fs.readFileSync(target,'utf8')!==bytes) throw Error('native vector drift');
  } else fs.writeFileSync(target,bytes);
  console.log(JSON.stringify({vectors:vectors.length,sha256:hash(bytes),sourceSha256:hash(source)}));
})();
