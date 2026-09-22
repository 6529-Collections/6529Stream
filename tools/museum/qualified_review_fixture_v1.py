"""Bounded retention and offline replay of actual qualified-account originals."""
import gzip
import hashlib
import io
from pathlib import Path

from .account_profile import account_iri
from .canonical import dumps, hex_bytes, keccak256, loads
from .chain_rpc import ReplayTransport
from .independent_publication import IndependentPublicationAdapter
from .independent_source import IndependentSourceAdapter
from .independent_wire import require
from .qualified_review_capture_v1 import FILES, MAX_BYTES, QUALIFICATION, profile_for_hash
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource
from .review import BODY_SCHEMA_BYTES, REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION, _validate


def verify_deployment(files, anchor, evidence, audit):
    """Join execution observations; compiler/build provenance stays externally admitted."""
    native = loads(files['native-inputs.json'], maximum=MAX_BYTES)
    require(type(native) is dict and set(native) == {'mode', 'products', 'safeFixture'}
        and native['mode'] == 'current_museum_native_products_v1', 'qualified native manifest shape')
    products = native['products']; artifacts = evidence['artifacts']
    require(type(products) is dict and type(artifacts) is dict
        and len(products) == 19 and set(products) == set(artifacts), 'qualified native product set differs')
    audited = {row['name']: row for row in audit['products']}
    require(len(audited) == len(audit['products']) and set(audited) == set(products),
        'qualified native audited product set differs')
    pins = {row['address']: row['runtimeHash'] for row in anchor['codePins']}
    transactions = evidence['transactions']
    require(type(transactions) is list and 0 < len(transactions) <= 4096,
        'qualified native transaction journal bound')
    journal = {row['transactionHash']: row for row in transactions}
    require(len(journal) == len(transactions), 'qualified native duplicate journal transaction')
    creations = {}
    for tx in transactions:
        receipt = tx['receipt']
        require(receipt['transactionHash'] == tx['transactionHash'] and receipt['status'] == '0x1'
            and receipt['from'] == tx['transaction']['from'], 'qualified journal receipt differs')
        if receipt['contractAddress'] is not None:
            address = receipt['contractAddress']
            require(address not in creations and 'to' not in tx['transaction'] and receipt['to'] is None,
                'qualified native duplicate/noncreation deployment')
            creations[address] = keccak256(hex_bytes(tx['transaction']['data']))
        else:
            require(receipt['to'] == tx['transaction'].get('to'), 'qualified journal call target differs')
    deployed = set()
    for name, product in products.items():
        row = artifacts[name]; prior = audited[name]
        require(type(product) is dict and set(product) == {'artifact', 'sha256', 'source'}
            and all(row[key] == product[key] == prior[key] for key in product)
            and prior['compilationTarget'] == {product['source']: name},
            'qualified artifact identity/source binding differs')
        require(row['address'] not in deployed and pins.get(row['address']) == row['runtimeHash']
            and creations.get(row['address']) == row['creationHash'],
            'qualified artifact deployment/runtime binding differs')
        deployed.add(row['address'])
    for key, name in (('host', 'StreamCollectionAttestations'), ('core', 'StreamCore'),
            ('schemas', 'StreamSchemaRegistry')):
        require(anchor[key] == artifacts[name]['address'], 'qualified anchor product address differs')
    require(evidence['hostGovernanceAuthority'] == artifacts['StreamGovernanceExecutor']['address']
        and evidence['safeFixture'] == native['safeFixture']
        and all(audit['safe'][key] == value for key, value in native['safeFixture'].items()),
        'qualified native governance/Safe identity differs')
    require(set(evidence['safeComponents']) == {'singleton', 'factory', 'handler'},
        'qualified native Safe component set differs')
    for key, address in evidence['safeComponents'].items():
        component = audit['safe']['components'][key]
        require(pins.get(address) == component['runtimeKeccak256']
            and creations.get(address) == component['creationKeccak256'],
            'qualified native Safe deployment/runtime binding differs')
    require(evidence['governanceRoot'] in evidence['safeAccounts']
        and all(address in pins and len(set(owners)) == len(owners) == 2
            for address, owners in evidence['safeAccounts'].items()), 'qualified Safe account evidence differs')
    publications = loads(files['publications.json'], maximum=MAX_BYTES, canonical=True)
    for receipt in publications['receipts']:
        tx = journal.get(receipt['transactionHash'])
        require(tx is not None and tx['receipt'] == receipt
            and tx['transaction']['to'] == receipt['to'] == anchor['host'],
            'qualified original publication/journal binding differs')


def verify_capture(files, profile):
    """Verify native captured facts; export reviewer selection belongs elsewhere."""
    require(type(files) is dict and set(files) == set(FILES)
        and all(type(raw) is bytes for raw in files.values())
        and sum(map(len, files.values())) <= MAX_BYTES, 'qualified capture closed files/bound')
    pins = loads(files['capture-pins.json'], maximum=MAX_BYTES, canonical=True)
    require(pins == {'profileHash': profile.profile_hash,
        'files': {name: keccak256(files[name]) for name in FILES if name != 'capture-pins.json'}},
        'qualified capture file/profile pins differ')
    original = IndependentSourceAdapter(files['anchor.json'],
        ReplayTransport(files['transcript.json'], pins['files']['transcript.json']), provenance='trusted_rpc')
    require(original.snapshot() == files['source-capture.json'], 'qualified capture native source differs')
    publication = IndependentPublicationAdapter(original, files['publication-hints.json'],
        ReplayTransport(files['publication-transcript.json'], pins['files']['publication-transcript.json']),
        provenance='trusted_rpc')
    require(publication.snapshot() == files['publications.json'], 'qualified capture publication differs')
    interpreted = RegisteredInterpretationCapture(publication, profile,
        ReplayTransport(files['interpretation-transcript.json'], pins['files']['interpretation-transcript.json']))
    require(interpreted.snapshot() == files['interpretation.json'], 'qualified capture interpretation differs')
    source = RecordedSemanticSource(interpreted, profile_hash=profile.profile_hash)
    cases = loads(files['qualified-cases.json'], maximum=65536, canonical=True)
    require(set(cases) == {'version', 'profileHash', 'sourceStateHash', 'publisher', 'reviewer',
        'selectors', 'qualification'} and cases['version'] == '1'
        and cases['profileHash'] == profile.profile_hash
        and cases['sourceStateHash'] == source.state.commitment
        and cases['qualification'] == QUALIFICATION, 'qualified capture case state differs')
    require(cases['publisher'] != cases['reviewer'], 'qualified capture reviewer account is not distinct')
    choices = cases['selectors']
    require(set(choices) == {'mapping', 'approved', 'rejected', 'self_review'},
        'qualified capture exact case selectors required')
    target = source.record(choices['mapping'])
    assertion, issuer, position = source.assertion(choices['mapping'])
    require(issuer == account_iri(source.anchor['chainId'], cases['publisher'])
        and assertion['origin'] == 'human_mapping' and assertion['reviewStatus'] == 'unreviewed',
        'qualified capture original mapping attribution differs')
    expected_rule = profile.assertion_rules()[target.selector.schema_id]
    require(expected_rule[2] == profile.profile_hash, 'qualified capture original did not opt in')
    positions = [position]
    for name, disposition, account in (('approved', 'reviewed', cases['reviewer']),
            ('rejected', 'rejected', cases['reviewer']),
            ('self_review', 'reviewed', cases['publisher'])):
        row = source.record(choices[name]); review, reviewer, later = source.assertion(choices[name])
        require(row.selector.schema_id == target.selector.schema_id
            and row.selector.subject_id == target.selector.subject_id
            and row.selector.host == target.selector.host
            and row.selector.record_type == target.selector.record_type,
            'qualified capture original/review native scope differs')
        require(reviewer == account_iri(source.anchor['chainId'], account)
            and review['subject'] == assertion['id'] and review['relation'] == REVIEW_RELATION
            and review['mappingRule'] == REVIEW_MAPPING_RULE
            and review['origin'] == 'direct_statement' and review['reviewStatus'] == 'unreviewed'
            and review['createdAt'] == assertion['createdAt'],
            'qualified capture attributed review differs')
        literal = review['object']['literal']
        require(literal['datatype'] == REVIEW_DATATYPE
            and all(literal[key] is None for key in ('language', 'unit', 'precision')),
            'qualified capture original review datatype differs')
        body = _validate(BODY_SCHEMA_BYTES, literal['lexicalValue'].encode('utf-8'))
        require(body == {'assertionRecord': choices['mapping'],
            'assertionRevisionHash': keccak256(dumps(assertion)),
            'profileHash': profile.profile_hash, 'mappingRule': assertion['mappingRule'],
            'disposition': disposition}, 'qualified capture exact review target differs')
        positions.append(later)
    require(all(a < b for a, b in zip(positions, positions[1:])),
        'qualified capture native publication order differs')
    anchor = loads(files['anchor.json'], maximum=MAX_BYTES, canonical=True)
    evidence = loads(files['deployment-evidence.json'], maximum=MAX_BYTES, canonical=True)
    audit = loads(files['native-reuse-audit.json'], maximum=MAX_BYTES, canonical=True)
    require(anchor['environment'] == 'local_evm_fixture'
        and anchor['deploymentEvidenceHash'] == keccak256(files['deployment-evidence.json'])
        and evidence['kind'] == 'local_evm_fixture'
        and evidence['workflow'] == 'actual_registered_qualified_account_review_v1'
        and evidence['publisher'] == cases['publisher'] and evidence['reviewer'] == cases['reviewer']
        and evidence['qualification'] == QUALIFICATION
        and evidence['nativeReuseAuditHash'] == keccak256(files['native-reuse-audit.json'])
        and audit['nativeManifest']['sha256'] == evidence['nativeInputManifestSha256']
        and evidence['nativeInputManifestSha256'] == hashlib.sha256(files['native-inputs.json']).hexdigest(),
        'qualified capture local execution evidence differs')
    verify_deployment(files, anchor, evidence, audit)
    return source


def retain(capture, destination, expected_pins_hash):
    capture, destination = Path(capture).resolve(), Path(destination).resolve()
    require(not destination.exists() and destination != capture and capture not in destination.parents,
        'qualified retention destination must be new and outside capture')
    files, total = {}, 0
    for name in FILES:
        path = capture / name
        require(path.is_file() and not path.is_symlink(), 'qualified capture regular file required')
        size = path.stat().st_size; total += size
        require(size <= MAX_BYTES and total <= MAX_BYTES, 'qualified capture retention byte bound')
        files[name] = path.read_bytes()
        require(len(files[name]) == size, 'qualified capture changed during retention')
    require(keccak256(files['capture-pins.json']) == expected_pins_hash,
        'qualified capture external pins hash differs')
    profile = profile_for_hash(loads(files['capture-pins.json'], canonical=True)['profileHash'])
    verify_capture(files, profile)
    raw = dumps({'files': {name: content.hex() for name, content in sorted(files.items())}})
    packed = gzip.compress(raw, compresslevel=9, mtime=0)
    manifest = dumps({'version': '1', 'mode': 'retained_actual_qualified_account_review_v1',
        'archiveSha256': hashlib.sha256(packed).hexdigest(), 'expandedBytes': str(len(raw)),
        'capturePinsHash': expected_pins_hash, 'profileHash': profile.profile_hash,
        'files': [{'path': name, 'byteLength': str(len(content)), 'keccak256': keccak256(content)}
            for name, content in sorted(files.items())],
        'accountDistinctionOnly': True, 'humanIndependenceEstablished': False,
        'selectionPolicyExecuted': False, 'qualification': QUALIFICATION})
    destination.mkdir(parents=True)
    (destination / 'inputs.json.gz').write_bytes(packed)
    (destination / 'manifest.json').write_bytes(manifest)
    return keccak256(manifest)


def read(directory, manifest_hash):
    directory = Path(directory)
    path, archive = directory / 'manifest.json', directory / 'inputs.json.gz'
    require(path.stat().st_size <= 65536 and archive.stat().st_size <= MAX_BYTES,
        'qualified retained file bound')
    raw = path.read_bytes()
    require(keccak256(raw) == manifest_hash, 'qualified retained external manifest pin differs')
    manifest = loads(raw, maximum=65536, canonical=True)
    require(manifest['version'] == '1' and manifest['mode'] == 'retained_actual_qualified_account_review_v1'
        and manifest['accountDistinctionOnly'] is True and manifest['humanIndependenceEstablished'] is False
        and manifest['selectionPolicyExecuted'] is False and manifest['qualification'] == QUALIFICATION,
        'qualified retained manifest claims differ')
    packed = archive.read_bytes()
    require(hashlib.sha256(packed).hexdigest() == manifest['archiveSha256'],
        'qualified retained archive pin differs')
    maximum = MAX_BYTES * 2 + 1048576
    with gzip.GzipFile(fileobj=io.BytesIO(packed)) as stream:
        expanded = stream.read(maximum + 1)
    require(len(expanded) <= maximum and str(len(expanded)) == manifest['expandedBytes'],
        'qualified retained expanded byte bound')
    encoded = loads(expanded, maximum=maximum, canonical=True)
    require(set(encoded) == {'files'} and set(encoded['files']) == set(FILES),
        'qualified retained exact file set differs')
    files = {name: bytes.fromhex(value) for name, value in encoded['files'].items()}
    require(sum(map(len, files.values())) <= MAX_BYTES, 'qualified retained decoded byte bound')
    require(manifest['files'] == [{'path': name, 'byteLength': str(len(content)),
        'keccak256': keccak256(content)} for name, content in sorted(files.items())],
        'qualified retained file commitments differ')
    require(keccak256(files['capture-pins.json']) == manifest['capturePinsHash'],
        'qualified retained capture pin differs')
    return files, manifest


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    pack = commands.add_parser('retain'); pack.add_argument('capture', type=Path)
    pack.add_argument('destination', type=Path); pack.add_argument('--capture-pins-hash', required=True)
    check = commands.add_parser('verify'); check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args()
    if args.command == 'retain': print(retain(args.capture, args.destination, args.capture_pins_hash))
    else:
        files, manifest = read(args.directory, args.manifest_hash)
        source = verify_capture(files, profile_for_hash(manifest['profileHash']))
        print(source.state.commitment)


if __name__ == '__main__': main()
