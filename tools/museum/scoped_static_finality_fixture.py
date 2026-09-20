"""Coherent synthetic scoped STATIC evidence; no EVM or chain acceptance claim.

All additional state, original transactions and events are installed before any
of the eleven preserved title inputs or the scoped source is captured.
"""
from copy import deepcopy

from . import native_finality_wire as neutral
from . import native_scoped_finality_wire as wire
from . import public_scoped_finality_source as source
from . import scoped_static_types as t
from . import scoped_static_content_wire as content_wire
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, decode, encode
from .current_rights_source import DOCUMENT_FACTS
from .finality_v6_fixture import FinalityV6Fixture
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values
from .test_current_rights_source import A, H
from .test_scoped_static_snapshot_wire import supplied as snapshot_supplied, jsonify
from .test_scoped_static_content_wire import joined_supplied
from .title_v5_fixture import TitleV5Fixture, TOKEN, COLLECTION


class ScopedStaticFinalityFixture(TitleV5Fixture):
    """TOKEN, odd RELEASE or multi-chunk SEASON over one synthetic RPC map."""

    preservation_inputs = FinalityV6Fixture.preservation_inputs

    def __init__(self, *, scope_type=1, count=None, burned=False):
        if scope_type not in (1, 2, 3): raise ValueError('unsupported synthetic STATIC scope')
        count = (1 if scope_type == 1 else 3 if scope_type == 2 else 30) if count is None else count
        if not 1 <= count <= 1818 or (scope_type == 1 and count != 1): raise ValueError('member count')
        super().__init__(burned=burned)
        self.scoped_transactions = {}
        addresses = {key: A(45000+i) for i,key in enumerate(wire.GRAPH_KEYS)}
        addresses.update(core=self.core, artist=self.registry, router=self.configuration[0][7],
            finality=A(6), provider=A(7), metadata=self.a['host'], schemas=A(3), store=A(4),
            executor=self.floor_executor)
        for key,address in addresses.items():
            if address not in self.codes:
                self.codes[address] = ('synthetic 896 scoped '+key).encode('ascii')
                self.pins[address] = keccak256(self.codes[address])
        self.scoped_addresses = addresses
        self.scoped_graph = {key:{'address':address,'runtimeHash':self.pins[address]} for key,address in addresses.items()}
        self.scoped_context = {key:self.a[key] for key in source.COMMON} | {'tokenId':str(TOKEN)}
        stamp = int(self.blocks[H(203)]['timestamp'],16)
        artist = (True,self.registry,self.pins[self.registry],self.artist_id,1,
            schema_id('synthetic scoped accepted binding'),A(93),schema_id('synthetic scoped identity'),
            schema_id('synthetic scoped acceptance'),stamp-2,stamp-1,schema_id('synthetic original Artist snapshot'))
        b,x,g,s = snapshot_supplied(scope_type,count,context=self.scoped_context,graph=self.scoped_graph,
            artist=artist,recorded_at=stamp,locked_at=stamp)
        for i,identity in enumerate(b['membership']['identities']): identity[2] = str(i+3)
        b['membership']['identities'][0][3] = burned
        b['membership']['lifecycles'][0] = '3' if burned else '2'
        if b['membership']['publication'] is not None:
            b['membership']['publication'][7][3] = str(stamp)
        self._additional_members(count)
        b,x,g,s = joined_supplied(scope_type,count,snapshot_inputs=(b,x,g,s),root_timestamp=stamp)
        self.scoped_bundle, self.scoped_statement = b,s
        self._relocate_carriers()
        self._finality_execution()
        self._bindings()
        self._definitions()
        self._getters()
        self._events()
        common = {key:self.a[key] for key in source.COMMON}
        self.scoped_anchor = {**common, **addresses, 'profile':source.PROFILE,'tokenId':str(TOKEN),
            'scope':deepcopy(b['scope']), 'codePins':[{'address':address,'runtimeHash':self.pins[address]}
                for address in dict.fromkeys(addresses.values())],
            'runtimeAdmission':{'sourceCommit':source.SOURCE_REVISION,'kind':'synthetic_fixture',
                'artifactHash':schema_id('synthetic 896 scoped runtime artifact')}}

    def _additional_members(self,count):
        from .mint_entropy_source import REGISTERED, TRANSFER
        for i in range(1,count):
            token,serial = TOKEN+i,3+i
            self.event(3,self.core,[REGISTERED,self.topic('uint256',token),self.topic('uint256',COLLECTION)],
                ('uint16','uint256'),(1,serial))
            self.event(3,self.core,[TRANSFER,ZERO,self.topic('address',A(90)),self.topic('uint256',token)],(),())
            self.add(self.core,'tokenCollectionIdentity(uint256)',('uint256',),(token,),
                ('bool','uint256','uint256','bool'),(True,COLLECTION,serial,False))
            self.add(self.core,'tokenLifecycle(uint256)',('uint256',),(token,),('uint8',),(2,))
        self.add(self.core,'collectionMintedEver(uint256)',('uint256',),(COLLECTION,),('uint256',),(count,))
        self.add(self.core,'collectionNextSerial(uint256)',('uint256',),(COLLECTION,),('uint256',),(count+3,))

    def _stored(self,raw):
        digest = self.chunk(raw)
        pointer,length = decode(('address','uint32'),hex_bytes(self.responses[(A(4),calldata('chunk(bytes32)',('bytes32',),(digest,)))]))
        assert length == len(raw)
        return pointer

    def _relocate_carriers(self):
        b = self.scoped_bundle
        for row in (*b['membership']['parts'],*b['content']['manifest']['chunks']):
            row['pointer'] = self._stored(hex_bytes(row['runtime'])[1:])
        m = b['membership']
        if m['publication'] is not None: m['publication'][4] = self._stored(hex_bytes(m['manifestBytes']))

    def _finality_execution(self):
        from .test_governance_transaction_wire import _hashes, _inputs, _events
        b,s,x,g = self.scoped_bundle,self.scoped_statement,self.scoped_context,self.scoped_graph
        a = self.scoped_addresses; chain = int(x['chainId']); scope = neutral.from_json(t.SCOPE,s[0])
        statement = neutral.from_json(t.STATEMENT,s)
        proof = tuple(schema_id('synthetic scoped archive '+str(i)) for i in range(3))
        archive = (neutral.archive_evidence_hash(chain,a['core'],a['finality'],a['artifacts'],proof),proof)
        sanction = (neutral.SANCTION,a['artist'],'0x12345678',self.pins[a['artist']],
            schema_id('synthetic sanction version'),schema_id('synthetic sanction manifest'),proof[0])
        components = tuple(sorted((*statement[8],sanction)))
        raw = encode(wire.INPUT_ENVELOPE,(wire.INPUT_SCHEMA,wire.INPUT_CANON,chain,a['core'],a['metadata'],a['finality'],statement))
        uri = 'ipfs://synthetic-original-scoped-finality'
        manifest = (uri,keccak256(uri.encode()),keccak256(raw),wire.INPUT_SCHEMA,wire.INPUT_CANON)
        digest = neutral.components_hash(components)
        record_hash = wire.finality_hash(chain,a['core'],scope,statement[1],digest,manifest)
        stamp = int(self.blocks[H(204)]['timestamp'],16)
        record = (True,scope,record_hash,manifest[2],manifest[1],digest,uri,a['finality'],stamp)
        witness = [schema_id('pending synthetic action'),A(55001),schema_id('synthetic governance reason'),schema_id('synthetic role witness'),1]
        ec = neutral.execution_context(chain,a['finality'],a['core'],a['metadata'],statement,record_hash,digest,archive[0])
        raw_call = hex_bytes(calldata(wire.FINALIZE_SIGNATURE,wire.FINALIZE_TYPES,(scope,components,record_hash,manifest,proof)))
        calls = ((a['finality'],0,'0x'+raw_call[:4].hex(),keccak256(raw_call),ec['scopeHash'],ec['oldValueHash'],ec['newValueHash']),)
        action = [3,2,a['finality'],0,calls[0][2],ZERO,ZERO,ZERO,ZERO,stamp-1,stamp+100,
            witness[1],A(55002),ZERO_ADDRESS,ZERO_ADDRESS,witness[2],'synthetic original reason',schema_id('synthetic action manifest')]
        calls_hash,folds,action_id = _hashes(calls,chain,a['executor'],action,17)
        action[5:9] = [calls_hash,*folds]; witness[0] = action_id
        runtime = b'\0'+encode((Array('bytes',64),),((raw_call,),))
        pointer = A(55003); self.codes[pointer] = runtime
        b['scope'] = json_values(scope)
        b['finality'] = jsonify({'record':record,'components':components,'manifestRef':manifest,'manifestBytes':'0x'+raw.hex(),
            'executionWitness':witness,'archiveWitness':archive,'inputsHash':ec['inputsHash']})
        b['execution'] = jsonify({'action':action,'callDataPointer':pointer,'callDatas':(raw_call,),'runtime':runtime})
        self.scoped_normalized_transactions = _inputs(calls,(raw_call,),action,action_id,a['executor'],'schedule_batch','execute_batch')
        self.scoped_governance_events = _events(action,action_id,a['executor'],17)
        wire.validate_bundle(b,x,g)

    def _bindings(self):
        a = self.scoped_addresses
        for owner,getter,target in source.ADDRESS_BINDINGS:
            self.add(a[owner],getter,(),(),('address',),(a[target],))
        for owner,getter,target in source.HASH_BINDINGS:
            self.add(a[owner],getter,(),(),('bytes32',),(self.pins[a[target]],))
        for owner in source.CHAIN_BINDINGS:
            self.add(a[owner],'deploymentChainId()',(),(),('uint256',),(int(self.a['chainId']),))
        self.add(a['finality'],'scopeEvidenceProviderCodeHash()',(),(),('bytes32',),(self.pins[a['provider']],))
        targets = tuple(a[k] for k in wire.PROVIDER_TARGETS); pins = tuple(self.pins[v] for v in targets)
        indices = (0,1,4,5,2,8,9,15,16,17,20,21)
        deps = (tuple(targets[i] for i in indices),tuple(pins[i] for i in indices),
            (a['artist'],ZERO_ADDRESS,ZERO_ADDRESS,ZERO_ADDRESS,ZERO_ADDRESS),
            (self.pins[a['artist']],ZERO,ZERO,ZERO,ZERO),ZERO_ADDRESS,ZERO,int(self.a['chainId']),100000,10000000,1000000,1000000,1000000)
        dh = keccak256(encode((source.INVENTORY_DEPENDENCIES,),(deps,)))
        config = (targets,pins,int(self.a['chainId']),100000,10000000,1000000,dh)
        self.add(a['provider'],'scopedConfiguration()',(),(),(wire.PROVIDER_CONFIG,),(config,))
        self.add(a['renderCriticalInventory'],'dependencies()',(),(),(source.INVENTORY_DEPENDENCIES,),(deps,))
        self.add(a['renderCriticalInventory'],'dependencyHash()',(),(),('bytes32',),(dh,))
        self.add(a['router'],'servingOriginalFinalityAnchor()',(),(),('address','bytes32'),(a['finality'],self.pins[a['finality']]))
        # Preserve the existing, reciprocal saved-anchor observation used by all
        # eleven original readers; zero is a legitimate not-yet-saved slot.

    def _definitions(self):
        for d in wire.definitions():
            raw = d['bytes']; digest = self.chunk(raw)
            facts = (True,d['kind'],0,d['hash'],RAW_BYTES,ZERO,len(raw),1,schema_id('synthetic definition '+d['name']))
            self.add(A(3),'documentFacts(bytes32)',('bytes32',),(d['id'],),(DOCUMENT_FACTS,),(facts,))
            self.add(A(3),'documentChunkHashAt(bytes32,uint256)',('bytes32','uint256'),(d['id'],0),('bytes32',),(digest,))

    def _getters(self):
        b,a = self.scoped_bundle,self.scoped_addresses
        scope = neutral.from_json(t.SCOPE,b['scope']); suffix = '((uint8,uint256,uint256,bytes32))'
        def put(role,signature,types,values,inputs=(),arguments=()): self.add(a[role],signature,inputs,arguments,types,values)
        def typed(role,signature,kind,value,key): put(role,signature,(kind,),(neutral.from_json(kind,value),),('bytes32',),(key,))
        f = b['finality']; r = neutral.from_json(wire.SCOPED_RECORD,f['record'])
        put('finality','artworkScopeFinalityRecord'+suffix,(wire.SCOPED_RECORD,),(r,),(t.SCOPE,),(scope,))
        put('finality','finalityComponentCountForScope'+suffix,('uint256',),(10,),(t.SCOPE,),(scope,))
        put('finality','finalityComponentsForScope((uint8,uint256,uint256,bytes32),uint256,uint256)',
            (Array(wire.COMPONENT,32),),(neutral.from_json(Array(wire.COMPONENT,32),f['components']),),(t.SCOPE,'uint256','uint256'),(scope,0,10))
        put('finality','finalityManifestStored(bytes32)',('bool',),(True,),('bytes32',),(r[3],))
        raw = hex_bytes(f['manifestBytes']); self.chunk(raw)
        put('finality','finalityManifestBytes(bytes32)',('bytes',),(raw,),('bytes32',),(r[3],))
        typed('finality','finalityExecutionWitness(bytes32)',wire.EXECUTION_WITNESS,f['executionWitness'],r[2])
        typed('finality','finalitySanctionArchiveWitness(bytes32)',wire.ARCHIVE_WITNESS,f['archiveWitness'],r[2])
        c = b['content']; m = c['manifest']; cp = c['checkpoint']
        put('router','scopedContentRootAggregate(uint256)',(t.ROOT_AGGREGATE,),
            (neutral.from_json(t.ROOT_AGGREGATE,c['roots']['collectionAggregate']),),('uint256',),(COLLECTION,))
        put('router','scopedContentRootHead'+suffix,('bytes32',),(c['roots']['scopeHead'],),(t.SCOPE,),(scope,))
        for row in c['roots']['history']: typed('router','scopedContentRootRecord(bytes32)',t.ROOT_RECORD,row['record'],row['recordHash'])
        for role,sig,kind,value,key in (
            ('outputManifest','manifestRecord(bytes32)',t.OUTPUT_MANIFEST,m['record'],m['recordHash']),
            ('outputManifest','manifestPlan(bytes32)',t.OUTPUT_PLAN,m['plan'],m['planHash']),
            ('staticContent','checkpoint(bytes32)',t.CONTENT_PLAN,cp['plan'],cp['id']),
            ('artifacts','artifact(bytes32)',t.ARTIFACT,m['artifact'],m['artifactHash']),
            ('artifacts','coverage(bytes32)',t.COVERAGE,m['coverage'],m['record'][3])): typed(role,sig,kind,value,key)
        for i,row in enumerate(cp['outputs']): put('staticContent','outputAt(bytes32,uint256)',(t.OUTPUT,),
            (neutral.from_json(t.OUTPUT,row),),('bytes32','uint256'),(cp['id'],i))
        for i,row in enumerate(m['chunks']): put('artifacts','artifactChunk(bytes32,uint32)',('address','bytes32'),
            (row['pointer'],row['codeHash']),('bytes32','uint32'),(m['artifactHash'],i))
        snap = b['snapshot']; selected = b['selection']; member = b['membership']
        put('scopedSnapshot','dependencies()',(t.SNAPSHOT_DEPS,),(neutral.from_json(t.SNAPSHOT_DEPS,snap['dependencies']),))
        put('scopedSnapshot','snapshotCount'+suffix,('uint256',),(len(snap['history']),),(t.SCOPE,),(scope,))
        for i,row in enumerate(snap['history']):
            key = row['receipt'][0]
            put('scopedSnapshot','snapshotAt((uint8,uint256,uint256,bytes32),uint256)',('bytes32',),(key,),(t.SCOPE,'uint256'),(scope,i))
            put('scopedSnapshot','snapshotRecord(bytes32)',(t.SNAPSHOT_PUBLICATION,t.SNAPSHOT_RECEIPT),
                (neutral.from_json(t.SNAPSHOT_PUBLICATION,row['publication']),neutral.from_json(t.SNAPSHOT_RECEIPT,row['receipt'])),('bytes32',),(key,))
            put('scopedSnapshot','snapshotPayload(bytes32)',('bytes',),(hex_bytes(row['payload']),),('bytes32',),(key,))
        put('scopedSnapshot','currentSnapshot'+suffix,(t.SNAPSHOT_RECEIPT,),
            (neutral.from_json(t.SNAPSHOT_RECEIPT,snap['history'][-1]['receipt']),),(t.SCOPE,),(scope,))
        put('scopedSnapshot','snapshotLock'+suffix,(t.SNAPSHOT_LOCK,),(neutral.from_json(t.SNAPSHOT_LOCK,snap['lock']),),(t.SCOPE,),(scope,))
        typed('staticSelection','checkpoint(bytes32)',t.SELECTION_PLAN,selected['plan'],selected['id'])
        for i,row in enumerate(selected['rows']): put('staticSelection','selectionAt(bytes32,uint256)',(t.SELECTION_ROW,),
            (neutral.from_json(t.SELECTION_ROW,row),),('bytes32','uint256'),(selected['id'],i))
        if member['publication'] is not None:
            p = neutral.from_json(t.MEMBERSHIP_PUBLICATION,member['publication']); rec = neutral.from_json(t.METADATA_RECORD,member['metadataRecord'])
            put('scopeMembership','scopeMembershipPublication'+suffix,(t.MEMBERSHIP_PUBLICATION,),(p,),(t.SCOPE,),(scope,))
            put('scopeMembership','scopeMembershipProgress'+suffix,(t.MEMBERSHIP_PROGRESS,),
                (neutral.from_json(t.MEMBERSHIP_PROGRESS,member['progress']),),(t.SCOPE,),(scope,))
            put('metadata','collectionRecord(bytes32)',(t.METADATA_RECORD,t.METADATA_RECEIPT),(rec,p[7]),('bytes32',),(p[0],))
            put('metadata','recordHashAt(uint256,bytes32,uint256)',('bytes32',),(p[0],),('uint256','bytes32','uint256'),(COLLECTION,rec[0],p[7][4]))
            put('metadata','recordPayload(bytes32)',('address','bytes'),(p[4],hex_bytes(member['manifestBytes'])),('bytes32',),(p[0],))
        for i,token in enumerate(member['tokens']):
            put('scopeMembership','scopeTokenAt((uint8,uint256,uint256,bytes32),uint256)',('uint256',),(int(token),),(t.SCOPE,'uint256'),(scope,i))
            put('tokenInventory','collectionTokenBySerial(uint256,uint256)',('uint256',),(int(token),),('uint256','uint256'),(COLLECTION,int(member['identities'][i][2])))
        e = b['execution']; action_id = f['executionWitness'][0]
        typed('executor','governanceAction(bytes32)',neutral.GOVERNANCE_ACTION,e['action'],action_id)
        data = tuple(hex_bytes(v) for v in e['callDatas']); key = keccak256(b''.join(hex_bytes(keccak256(v)) for v in data))
        put('executor','scheduledCallDataPointer(bytes32)',('address',),(e['callDataPointer'],),('bytes32',),(action_id,))
        put('executor','scheduledCallData(bytes32)',(Array('bytes',64),),(data,),('bytes32',),(action_id,))
        put('executor','publishedCallData(bytes32)',('address',),(e['callDataPointer'],),('bytes32',),(key,))

    def _raw_event(self,block,row,transaction=None):
        tx = transaction or H(400+block); receipt = self.receipts[tx]
        header = self.blocks[receipt['blockHash']]
        offset = sum(len(self.receipts[value]['logs']) for value in header['transactions'][:int(receipt['transactionIndex'],16)])
        log = {key:receipt[key] for key in ('transactionHash','blockHash','blockNumber','transactionIndex')}
        log.update(address=row['address'],topics=[schema_id('synthetic coverage plan') if v is None else v for v in row['topics']],
            data=row['data'],logIndex=hex(offset+len(receipt['logs'])),removed=False)
        receipt['logs'].append(log); return log

    def _transaction(self,block,side):
        header = self.blocks[H(200+block)]; tx = schema_id('synthetic scoped '+side+' transaction')
        normalized = self.scoped_normalized_transactions[side]
        receipt = {'transactionHash':tx,'blockHash':header['hash'],'blockNumber':header['number'],
            'transactionIndex':hex(len(header['transactions'])),'status':'0x1','logs':[],
            'from':normalized['from'],'to':normalized['to']}
        header['transactions'].append(tx); self.receipts[tx] = receipt
        self.scoped_transactions[tx] = {key:receipt[key] for key in ('blockHash','blockNumber','transactionIndex','from','to')}
        self.scoped_transactions[tx].update(hash=tx,input=normalized['input'],value=hex(int(normalized['value'])),chainId=hex(int(self.a['chainId'])))
        return tx

    def _events(self):
        b,x,g = self.scoped_bundle,self.scoped_context,self.scoped_graph
        descriptors = list(wire.expected_events(b,x,g)); observed = []
        kinds = ('membership_recorded','membership_admitted','membership_progressed','membership_sealed',
            'selection_started','selection_appended','selection_completed','content_started','content_appended','content_completed',
            'artifact_recorded','coverage_completed','manifest_started','manifest_verified','snapshot_published','snapshot_locked','root_published')
        for kind in kinds:
            if kind == 'manifest_verified':
                count = len(b['membership']['tokens'])
                for start in range(0,count,16):
                    row = {'address':g['outputManifest']['address'],'topics':[content_wire.EVENTS['manifestAdvanced'],b['content']['manifest']['planHash']],
                        'data':'0x'+encode(('uint16','uint64','uint64'),(1,start,min(start+16,count))).hex()}
                    observed.append(self._raw_event(3,row))
            for row in descriptors:
                if row['kind'] == kind: observed.append(self._raw_event(3,row))
        e = wire.validate_execution(b['execution'],x,g,wire.validate_finality(b['finality'],x,g,b['scope']))
        publication = {'address':g['executor']['address'],'topics':[wire.EVENTS['governanceCalldataPublished'],e['callDataKey']],
            'data':'0x'+encode(neutral.GOVERNANCE_CALLDATA_DATA,(1,b['execution']['callDataPointer'],A(55004))).hex()}
        observed.append(self._raw_event(3,publication))
        schedule = self._transaction(3,'schedule'); execution = self._transaction(4,'execution')
        observed.append(self._raw_event(3,self.scoped_governance_events[0],schedule))
        for row in descriptors:
            if row['kind'] not in kinds: observed.append(self._raw_event(4,row,execution))
        observed.append(self._raw_event(4,self.scoped_governance_events[1],execution))
        from .chain_history import LOG_FIELDS
        self.scoped_events = [{'log':{k:log[k] for k in LOG_FIELDS},'timestamp':str(int(self.blocks[log['blockHash']]['timestamp'],16))} for log in observed]
        wire.validate_event_join(b,x,g,self.scoped_events)
        wire.validate_governance(b,x,g,self.scoped_normalized_transactions,self.scoped_events)

    def request(self,method,params):
        if method == 'eth_getTransactionByHash':
            self.requested.append((method,params)); return deepcopy(self.scoped_transactions.get(params[0]))
        return super().request(method,params)

    def scoped_source(self): return source.PublicScopedFinalitySource(dumps(self.scoped_anchor),self)
    def scoped_result(self): return loads(self.scoped_source().snapshot(),maximum=source.MAX_OUTPUT)
    def scoped_capture(self):
        from . import public_scoped_finality_capture as capture
        adapter = self.scoped_source()
        return capture._assemble(adapter,keccak256(adapter.anchor_bytes),source.PROFILE_HASH)
    def scoped_inputs(self):
        from . import acquisition_title_v5 as title
        prior,accession = self.title_inputs()
        return title.compose(prior.files,prior.manifest_hash,accession.files,accession.manifest_hash,
            disclosure='public'),self.scoped_capture()
