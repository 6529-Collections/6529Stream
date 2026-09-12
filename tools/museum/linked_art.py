"""Pinned offline shape validation and real JSON-LD expansion, not authority."""

from dataclasses import dataclass
from importlib.metadata import version
from pathlib import Path
from types import MappingProxyType
from urllib.parse import unquote, urldefrag, urljoin

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import SchemaError
from pyld import jsonld
from pyld.context_resolver import ContextResolver
from referencing import Registry, Resource
from referencing.exceptions import NoSuchResource, Unresolvable
import rfc8785
from rfc3986_validator import validate_rfc3986
from rfc3339_validator import validate_rfc3339

from .canonical import MuseumError, dumps, keccak256, loads
from .dependencies import OfflineDocuments
from .schema_interpretation import conjoin_duplicate_schema


@dataclass(frozen=True)
class Expansion:
    source_bytes: bytes
    expanded_bytes: bytes
    policy_hash: str


def format_checker():
    """Do not inherit optional formats from whatever packages the host has."""
    checker = FormatChecker(formats=())

    @checker.checks("uri")
    def uri(value):
        if not isinstance(value, str):
            return True
        match = validate_rfc3986(value, rule="URI")
        return bool(match) and match.end() == len(value)

    @checker.checks("date-time")
    def datetime_(value):
        # The pinned validator's '$' permits a terminal newline. Reject it
        # explicitly, retaining the exact input rather than trimming it.
        return (not isinstance(value, str)
                or ("\n" not in value and bool(validate_rfc3339(value.upper()))))

    return checker


def _contexts(value, root=True):
    if isinstance(value, dict):
        if not root and "@context" in value:
            raise MuseumError("document-local context changes are outside this fixed profile")
        for item in value.values():
            _contexts(item, False)
    elif isinstance(value, list):
        for item in value:
            _contexts(item, False)


def _pointer(schema, pointer):
    if not isinstance(pointer, str) or (pointer and not pointer.startswith("/")):
        raise MuseumError("schema JSON pointer required")
    node = schema
    try:
        for part in pointer[1:].split("/") if pointer else ():
            if "~" in part.replace("~1", "").replace("~0", ""):
                raise MuseumError("invalid schema JSON pointer escape")
            key = part.replace("~1", "/").replace("~0", "~")
            if isinstance(node, list):
                if not key.isascii() or not key.isdecimal() or key != str(int(key)):
                    raise MuseumError("noncanonical schema array pointer")
                node = node[int(key)]
            else:
                node = node[key]
    except (KeyError, IndexError, TypeError) as exc:
        raise MuseumError("schema JSON pointer unavailable") from exc
    return node


def _repair(schema, rule):
    """Apply only explicit, preimage-guarded translations of pinned sources."""
    pointer = rule["pointer"]
    node = _pointer(schema, pointer)
    if rule.get("operation") == "legacy_tuple_items_to_prefixItems":
        if (not isinstance(node, dict) or "prefixItems" in node
                or not isinstance(node.get("items"), list) or node["items"] != rule["expectedItems"]):
            raise MuseumError("schema repair preimage mismatch")
        node["prefixItems"] = node.pop("items")
    elif rule.get("operation") == "replace_exact_reference":
        if (not pointer.endswith("/$ref") or not isinstance(node, str)
                or node != rule["expectedValue"] or not isinstance(rule["replacementValue"], str)):
            raise MuseumError("schema reference repair preimage mismatch")
        _pointer(schema, pointer.rsplit("/", 1)[0])["$ref"] = rule["replacementValue"]
    elif rule.get("operation") == "append_exact_schema_reference":
        item = rule.get("appendItem")
        if (pointer != "/anyOf" or not isinstance(node, list) or node != rule.get("expectedItems")
                or not isinstance(item, dict) or set(item) != {"$ref"}
                or not isinstance(item["$ref"], str) or item in node):
            raise MuseumError("schema root append preimage mismatch")
        node.append(dict(item))
    else:
        raise MuseumError("unsupported schema interpretation repair")


def _reference_closure(schemas):
    """Check every retained reference, including definitions unused by examples.

    This pinned profile has root IDs and JSON-pointer references only. Semantic
    recursion is allowed: each source tree is walked once, without following
    target references recursively. Hash-dependency DAG admission is separate.
    """
    references = []
    for uri, schema in sorted(schemas.items()):
        pending = [("", schema)]
        while pending:
            pointer, node = pending.pop()
            if isinstance(node, dict):
                if ((pointer and "$id" in node)
                        or any(k in node for k in ("$anchor", "$dynamicAnchor", "$dynamicRef", "$recursiveRef"))):
                    raise MuseumError("unsupported schema reference scope")
                if "$ref" in node:
                    ref = node["$ref"]
                    if not isinstance(ref, str):
                        raise MuseumError("schema reference must be a string")
                    match = validate_rfc3986(ref, rule="URI_reference")
                    if not match or match.end() != len(ref):
                        raise MuseumError("invalid schema URI reference")
                    target_uri, fragment = urldefrag(urljoin(uri, ref))
                    if target_uri not in schemas:
                        raise MuseumError("offline schema reference document unavailable")
                    try:
                        target_pointer = unquote(fragment, errors="strict")
                    except UnicodeError as exc:
                        raise MuseumError("invalid schema reference fragment") from exc
                    target = _pointer(schemas[target_uri], target_pointer)
                    if not isinstance(target, (dict, bool)):
                        raise MuseumError("schema reference target is not a schema")
                    references.append((uri, pointer + "/$ref", target_uri, target_pointer))
                for key, value in node.items():
                    escaped = key.replace("~", "~0").replace("/", "~1")
                    pending.append((pointer + "/" + escaped, value))
            elif isinstance(node, list):
                pending.extend((pointer + "/" + str(i), value) for i, value in enumerate(node))
    return tuple(sorted(references))


class PinnedLinkedArt:
    def __init__(self, documents: OfflineDocuments, policy_bytes: bytes, expected_policy_hash: str):
        if keccak256(policy_bytes) != expected_policy_hash:
            raise MuseumError("validation policy hash mismatch")
        policy = loads(policy_bytes, canonical=True)
        if (policy.get("mode") != "candidate_pinned_linked_art_validation" or policy.get("version") not in ("1", "2")
                or policy.get("processor") != "PyLD3.3.0" or version("PyLD") != "3.3.0"
                or policy.get("formatProfile") != "exact-uri-rfc3339-no-leap-seconds-v1"):
            raise MuseumError("unsupported validation processor profile")
        if keccak256(documents.load(policy["contextUri"])) != policy["contextHash"]:
            raise MuseumError("validation context hash mismatch")
        if policy["version"] == "2":
            supporting = policy.get("supportingDocuments")
            if (not isinstance(supporting, list) or not supporting or len(supporting) > 64
                    or any(not isinstance(row, dict) or set(row) != {"sourceUri", "contentHash"}
                           or not isinstance(row["sourceUri"], str) for row in supporting)
                    or len({row["sourceUri"] for row in supporting}) != len(supporting)):
                raise MuseumError("invalid supporting interpretation documents")
            for row in supporting:
                if keccak256(documents.load(row["sourceUri"])) != row["contentHash"]:
                    raise MuseumError("supporting interpretation document mismatch")
        resources, derived_hashes, derived_bytes, applied = {}, {}, {}, set()
        repairs = policy["schemaRepairs"]
        duplicate_rules = policy.get("duplicateSchemaInterpretations", [])
        if (not isinstance(duplicate_rules, list) or len(duplicate_rules) > 1
                or any(not isinstance(rule, dict) for rule in duplicate_rules)
                or (duplicate_rules and policy["version"] != "2")):
            raise MuseumError("unsupported duplicate schema interpretation profile")
        duplicate_applied = set()
        if policy["version"] == "1" and any(r.get("operation") == "append_exact_schema_reference" for r in repairs):
            raise MuseumError("root schema append requires a v2 interpretation")
        if len({(r["schemaUri"], r["pointer"]) for r in repairs}) != len(repairs):
            raise MuseumError("duplicate schema interpretation repair")
        for row in policy["schemaDocuments"]:
            uri = row["sourceUri"]
            if uri in resources or keccak256(documents.load(uri)) != row["contentHash"]:
                raise MuseumError("validation schema identity mismatch")
            matches = [(i, rule) for i, rule in enumerate(duplicate_rules) if rule.get("schemaUri") == uri]
            if matches:
                i, rule = matches[0]
                schema = conjoin_duplicate_schema(documents.load(uri), rule)
                duplicate_applied.add(i)
            else:
                schema = documents.jsonld_loader(uri)["document"]
            if schema.get("$id") != uri or schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
                raise MuseumError("validation schema dialect or URI mismatch")
            for index, rule in enumerate(repairs):
                if rule["schemaUri"] == uri:
                    _repair(schema, rule)
                    applied.add(index)
            try:
                Draft202012Validator.check_schema(schema)
            except SchemaError as exc:
                raise MuseumError("derived JSON schema has invalid dialect") from exc
            derived_bytes[uri] = rfc8785.dumps(schema)
            derived_hashes[uri] = keccak256(derived_bytes[uri])
            resources[uri] = Resource.from_contents(schema)
        if applied != set(range(len(repairs))):
            raise MuseumError("unapplied schema interpretation repair")
        if duplicate_applied != set(range(len(duplicate_rules))):
            raise MuseumError("unapplied duplicate schema interpretation")
        if policy["rootSchemaUri"] not in resources:
            raise MuseumError("root validation schema unavailable")
        self.schema_references = _reference_closure({uri: resource.contents for uri, resource in resources.items()})

        def retrieve(uri):
            if uri not in resources:
                raise NoSuchResource(ref=uri)
            return resources[uri]

        registry = Registry(retrieve=retrieve).with_resources(resources.items())
        self._validator = Draft202012Validator(resources[policy["rootSchemaUri"]].contents,
                                               registry=registry, format_checker=format_checker())
        self._documents = documents
        self._context_uri = policy["contextUri"]
        self._policy_hash = expected_policy_hash
        self._derived_schemas = MappingProxyType(derived_bytes)
        self.derived_schema_hashes = MappingProxyType(derived_hashes)

    def derived_schema_bytes(self, uri):
        try:
            return self._derived_schemas[uri]
        except KeyError as exc:
            raise MuseumError("derived schema unavailable") from exc

    def validate_and_expand(self, raw: bytes) -> Expansion:
        # This first derived-document profile has no float/unsafe-integer adapter.
        # Existing source numeric bytes are retained separately and never converted here.
        document = loads(raw)
        if not isinstance(document, dict) or document.get("@context") != self._context_uri:
            raise MuseumError("document must use the exact pinned context URI")
        _contexts(document)
        try:
            error = next(self._validator.iter_errors(document), None)
        except Unresolvable as exc:
            raise MuseumError("offline schema dependency unavailable") from exc
        if error:
            raise MuseumError("Linked Art schema rejection at " + error.json_path)

        def loader(uri, options=None):
            if uri != self._context_uri:
                raise MuseumError("unapproved JSON-LD context dependency")
            return self._documents.jsonld_loader(uri, options)

        try:
            # Pin PyLD3.3's resolver API and isolate its cache per operation/profile.
            # No process-global URL cache can substitute another profile's bytes.
            expanded = jsonld.expand(document, {
                "processingMode": "json-ld-1.1", "base": "", "documentLoader": loader,
                "contextResolver": ContextResolver({}, loader, max_context_urls=8),
            })
        except jsonld.JsonLdError as exc:
            raise MuseumError("offline JSON-LD expansion failed") from exc
        if len(expanded) != 1 or expanded[0].get("@id") != document["id"]:
            raise MuseumError("expansion lost root entity identity")
        return Expansion(raw, dumps(expanded), self._policy_hash)


def main():
    import argparse
    import sys
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--policy-hash", required=True)
    parser.add_argument("--dependency-root", type=Path,
                        default=Path(__file__).resolve().parents[2] / "schemas/museum")
    args = parser.parse_args()
    root = args.dependency_root
    index = loads((root / "linked-art/validation-index.json").read_bytes(), maximum=65536)
    profile = PinnedLinkedArt(OfflineDocuments(root, index),
                             (root / "linked-art/validation-policy.json").read_bytes(), args.policy_hash)
    with args.source.open("rb") as file:
        raw = file.read(24577)
    result = profile.validate_and_expand(raw)
    sys.stdout.buffer.write(dumps({
        "mode": "candidate_unregistered_validation", "sourceHash": keccak256(result.source_bytes),
        "expandedHash": keccak256(result.expanded_bytes), "policyHash": result.policy_hash,
        "derivedSchemaHashes": dict(profile.derived_schema_hashes),
        "expanded": loads(result.expanded_bytes, maximum=16 * 1024 * 1024),
        "claims": {"sourceAuthority": False, "registeredProfile": False, "completeMuseumConformance": False},
    }) + b"\n")


if __name__ == "__main__":
    main()
