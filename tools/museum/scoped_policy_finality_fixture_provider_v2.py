"""Explicit synthetic provider catalogue for the scoped factory-policy fixture.

These helpers manufacture test vectors, not deployment or execution evidence.
The original three catalogues retain roles six/seven and their separate
COLLECTION output host; only the selected configuration uses factory children.
"""
from . import native_finality_wire as neutral
from . import native_scoped_policy_finality_wire_v2 as wire
from . import scoped_policy_factory_v2 as factory_wire
from .canonical import keccak256, schema_id, uint
from .chain_abi import encode
from .independent_wire import json_values, require


def _address(number):
    return '0x' + format(number, '040x')


def _runtime(number):
    return ('synthetic e0b4 original provider dependency ' + str(number)).encode('ascii')


def _extra(number, graph, fixture=None):
    address, raw = _address(number), _runtime(number)
    require(address not in {r['address'] for r in graph.values()}, 'synthetic provider address collision')
    digest = keccak256(raw)
    if fixture is not None:
        require(address not in fixture.codes or fixture.codes[address] == raw,
            'synthetic provider existing runtime collision')
        require(address not in fixture.pins or fixture.pins[address] == digest,
            'synthetic provider existing pin collision')
        fixture.codes[address], fixture.pins[address] = raw, digest
    return address, digest


def provider_evidence(context, graph, factory_value, *, fixture=None):
    """Build JSON-ready original catalogues and factory-selected source routes."""
    chain = uint(context['chainId'])
    recipe = neutral.from_json(factory_wire.RECIPE, factory_value['recipe'])
    fg = neutral.from_json(factory_wire.GRAPH, factory_value['graph'])
    addresses = [graph[k]['address'] for k in wire.PROVIDER_TARGETS]
    pins = [graph[k]['runtimeHash'] for k in wire.PROVIDER_TARGETS]
    for index in (6, 7, 8, 9, 10, 18, 19):
        addresses[index], pins[index] = _extra(69000 + index, graph, fixture)
    budgets = (chain, 100000, 8000000, 4000000)

    def configuration(targets, hashes):
        # The old inventory's immutable tuple is retained as its own hash; it
        # must not be replaced by the selected factory inventory's dependency.
        d = list(recipe[0]); dt, dh = list(d[0]), list(d[1])
        for left, right in ((5, 8), (6, 9)):
            dt[left], dh[left] = targets[right], hashes[right]
        d[0], d[1] = tuple(dt), tuple(dh)
        return (tuple(targets), tuple(hashes), *budgets,
            keccak256(encode((wire.INVENTORY_DEPENDENCIES,), (tuple(d),))))

    original = configuration(addresses, pins)
    catalogues = [original]
    for n, changed in ((1, (8, 9, 18, 19)), (2, (8, 9, 10, 18, 19))):
        current, hashes = list(addresses), list(pins)
        for index in changed:
            current[index], hashes[index] = _extra(69000 + n * 100 + index, graph, fixture)
        catalogues.append(configuration(current, hashes))
    output_address, output_hash = _extra(69300, graph, fixture)
    output = {'address': output_address, 'runtimeHash': output_hash}
    binding = (graph['publicationFactory']['address'], graph['publicationFactory']['runtimeHash'],
        factory_value['recipeHash'], factory_value['sourceFactoryDependenciesHash'], 1000000,
        '0x' + '00' * 32)
    profiles, binding, digest = wire.provider_hashes(*catalogues, output, binding,
        chain, graph['provider']['address'])
    selected = wire.selected_configuration(original, recipe, fg)
    configuration_value = {
        'originalConfiguration': json_values(catalogues[0]),
        'scopedConfiguration': json_values(catalogues[1]),
        'policyConfiguration': json_values(catalogues[2]),
        'collectionPolicyOutput': output, 'profiles': json_values(profiles),
        'factoryBinding': json_values(binding), 'selectedConfiguration': json_values(selected),
        'sourceConfigurationHash': digest,
        'inventoryDependencies': json_values(factory_wire.inventory_dependencies(recipe, fg))}
    wire.validate_provider(configuration_value, context, graph, factory_value)
    adapters = []
    for index, family in enumerate(wire.ADAPTER_FAMILIES):
        address, digest_ = _extra(69400 + index, graph, fixture)
        host = 'router' if index < 6 else 'metadata'
        row = {'family': family, 'address': address, 'runtimeHash': digest_}
        for field, role in (('core', 'core'), ('host', host), ('evidenceProvider', 'provider'),
                ('metadataHost', 'metadata')):
            row[field], row[field + 'CodeHash'] = graph[role]['address'], graph[role]['runtimeHash']
        adapters.append(row)
    discovery = (graph['core']['address'], graph['metadata']['address'], graph['router']['address'],
        graph['provider']['address'], graph['scopeMembership']['address'], original[0][10],
        adapters[6]['address'], original[0][9], graph['artist']['address'], graph['finality']['address'],
        graph['finality']['runtimeHash'], tuple(row['address'] for row in adapters[:6]),
        100000, 3000000, 2000000)
    modules = {role: [schema_id('synthetic scoped policy ' + role + ' module version'),
        schema_id('synthetic scoped policy ' + role + ' module manifest')] for role in ('router', 'metadata')}
    return {'configuration': configuration_value, 'discoveryConfiguration': json_values(discovery),
        'discoverySourceConfigurationHash': digest, 'adapters': adapters, 'moduleIdentities': modules}


def install_provider_reads(fixture, provider, context, graph):
    """Install exact ABI getters into a TitleV5Fixture-compatible response map."""
    from . import public_scoped_policy_finality_source_v2 as source
    a = {key: row['address'] for key, row in graph.items()}
    def put(role, signature, outputs, values, inputs=(), arguments=()):
        fixture.add(a.get(role, role), signature, inputs, arguments, outputs, values)
    config = provider['configuration']
    # Only the helper's declared extra addresses receive synthetic code.
    extra_rows = [(address, digest) for key in ('originalConfiguration', 'scopedConfiguration', 'policyConfiguration')
        for address, digest in zip(config[key][0], config[key][1]) if address not in set(a.values())]
    extra_rows += [(config['collectionPolicyOutput']['address'], config['collectionPolicyOutput']['runtimeHash'])]
    extra_rows += [(row['address'], row['runtimeHash']) for row in provider['adapters']]
    for address, digest in extra_rows:
        observed = _extra(int(address, 16), graph, fixture)
        require(observed == (address, digest), 'synthetic provider supplied runtime differs')
    for owner, signature, target in source.ADDRESS_BINDINGS:
        put(owner, signature, ('address',), (a[target],))
    for owner, signature, target in source.HASH_BINDINGS:
        put(owner, signature, ('bytes32',), (graph[target]['runtimeHash'],))
    for role in ('scopeMembership', 'tokenInventory', 'staticSelection', 'policyContent', 'outputManifest', 'coordinatorInventory'):
        put(role, 'deploymentChainId()', ('uint256',), (uint(context['chainId']),))
    for signature, key in (('configuration()', 'originalConfiguration'),
            ('scopedConfiguration()', 'scopedConfiguration'), ('policyConfiguration()', 'policyConfiguration')):
        put('provider', signature, (wire.PROVIDER_CONFIG,), (neutral.from_json(wire.PROVIDER_CONFIG, config[key]),))
    for i, row in enumerate(config['profiles']):
        put('provider', 'finalitySourceProfile(uint8)', (wire.PROFILE,),
            (neutral.from_json(wire.PROFILE, row),), ('uint8',), (i,))
    put('provider', 'finalitySourceConfigurationHash()', ('bytes32',), (config['sourceConfigurationHash'],))
    put('provider', 'scopedPolicyPublicationBinding()', (wire.FACTORY_BINDING,),
        (neutral.from_json(wire.FACTORY_BINDING, config['factoryBinding']),))
    for getter, row in (('policyOutputManifestV2', config['collectionPolicyOutput']),
            ('policySnapshotPublicationV2', {'address': config['policyConfiguration'][0][8], 'runtimeHash': config['policyConfiguration'][1][8]}),
            ('policyReferencePublicationV2', {'address': config['policyConfiguration'][0][9], 'runtimeHash': config['policyConfiguration'][1][9]}),
            ('contentLeafManifest', {'address': config['originalConfiguration'][0][6], 'runtimeHash': config['originalConfiguration'][1][6]})):
        put('provider', getter + '()', ('address',), (row['address'],))
        put('provider', getter + 'CodeHash()', ('bytes32',), (row['runtimeHash'],))
    put('renderCriticalInventory', 'dependencies()', (wire.INVENTORY_DEPENDENCIES,),
        (neutral.from_json(wire.INVENTORY_DEPENDENCIES, config['inventoryDependencies']),))
    put('renderCriticalInventory', 'dependencyHash()', ('bytes32',), (config['selectedConfiguration'][6],))
    d = neutral.from_json(wire.DISCOVERY_CONFIG, provider['discoveryConfiguration'])
    put('discovery', 'configuration()', (wire.DISCOVERY_CONFIG,), (d,))
    put('discovery', 'sourceConfigurationHash()', ('bytes32',), (provider['discoverySourceConfigurationHash'],))
    for address in (*d[:9], *d[11], a['sourceFactory']):
        put('discovery', 'dependencyCodeHash(address)', ('bytes32',), (fixture.pins[address],), ('address',), (address,))
    for row in provider['adapters']:
        put(row['address'], 'componentType()', ('bytes32',), (row['family'],))
        for field in ('core', 'host', 'evidenceProvider', 'metadataHost'):
            put(row['address'], field + '()', ('address',), (row[field],))
            put(row['address'], field + 'CodeHash()', ('bytes32',), (row[field + 'CodeHash'],))
    for role, values in provider['moduleIdentities'].items():
        put('provider', role + 'ModuleVersion()', ('bytes32',), (values[0],))
        put('provider', role + 'ModuleManifestHash()', ('bytes32',), (values[1],))
    original = (a['finality'], graph['finality']['runtimeHash'])
    put('router', 'servingOriginalFinalityAnchor()', ('address', 'bytes32'), original)
    put('router', 'originalFinalityAnchor(uint256)', ('address', 'bytes32'), original,
        ('uint256',), (uint(context['collectionId']),))
    return provider
