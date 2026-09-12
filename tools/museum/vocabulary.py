"""Read the pinned RDFS declarations needed for a closed projection profile.

This is explicit class/domain/range checking, not an OWL reasoner or JSON-LD
processor. It preserves source-document attribution for every selected term.
"""

from dataclasses import dataclass
from hashlib import sha256
from types import MappingProxyType
from urllib.parse import urljoin
from xml.etree import ElementTree

from .canonical import MuseumError
from .dependencies import OfflineDocuments

RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
RDFS = "http://www.w3.org/2000/01/rdf-schema#"
OWL = "http://www.w3.org/2002/07/owl#"
XML = "http://www.w3.org/XML/1998/namespace"


@dataclass(frozen=True)
class Declaration:
    identifier: str
    category: str
    parents: tuple[str, ...]
    domains: tuple[str, ...]
    ranges: tuple[str, ...]
    source_uri: str


@dataclass(frozen=True)
class Term:
    identifier: str
    category: str
    parents: tuple[str, ...]
    domains: tuple[str, ...]
    ranges: tuple[str, ...]
    declarations: tuple[Declaration, ...]


class Vocabulary:
    def __init__(self, documents: OfflineDocuments, policy: dict):
        if policy.get("mode") != "candidate_pinned_vocabulary" or policy.get("version") != "1":
            raise MuseumError("unsupported vocabulary policy")
        sources = policy["documents"]
        uris = [row["sourceUri"] for row in sources]
        if not uris or len(uris) != len(set(uris)):
            raise MuseumError("duplicate or absent vocabulary source")
        declarations = {}
        for source in sources:
            uri = source["sourceUri"]
            raw = documents.load(uri)
            if "0x" + sha256(raw).hexdigest() != source["sha256"]:
                raise MuseumError("vocabulary policy source hash mismatch")
            try:
                text = raw.decode("utf-8")
            except UnicodeError as exc:
                raise MuseumError("ontology must use captured UTF-8") from exc
            if "<!DOCTYPE" in text.upper() or "<!ENTITY" in text.upper():
                raise MuseumError("XML entity declarations prohibited")
            try:
                root = ElementTree.fromstring(raw)
            except ElementTree.ParseError as exc:
                raise MuseumError("invalid ontology XML") from exc
            if root.tag != "{" + RDF + "}RDF":
                raise MuseumError("ontology must be RDF/XML")
            base = root.get("{" + XML + "}base")
            if not base:
                raise MuseumError("ontology base must be explicit")
            stack = [(root, 0)]
            count = 0
            while stack:
                node, depth = stack.pop()
                count += 1
                if depth > 64 or count > 100000:
                    raise MuseumError("ontology structure limit")
                stack.extend((child, depth + 1) for child in node)
            for node in root:
                if node.tag in ("{" + RDFS + "}Class", "{" + OWL + "}Class"):
                    category, parent_tag = "class", "subClassOf"
                elif node.tag == "{" + RDF + "}Property":
                    category, parent_tag = "property", "subPropertyOf"
                else:
                    continue
                identifier = urljoin(base, node.get("{" + RDF + "}about", ""))
                if identifier == base:
                    raise MuseumError("missing ontology term identity")
                if node.get("{" + XML + "}base"):
                    raise MuseumError("term-local base is outside this vocabulary parser")

                def refs(name):
                    values = []
                    for child in node.findall("{" + RDFS + "}" + name):
                        target = child.get("{" + RDF + "}resource")
                        if not target or len(child) or child.get("{" + XML + "}base"):
                            raise MuseumError("unsupported nested ontology reference")
                        values.append(urljoin(base, target))
                    return tuple(sorted(set(values)))

                term = Declaration(identifier, category, refs(parent_tag), refs("domain"), refs("range"), uri)
                declarations.setdefault(identifier, []).append(term)

        rules = {}
        for rule in policy["classAugmentations"]:
            if rule["identifier"] in rules or not rule.get("reason"):
                raise MuseumError("ambiguous class augmentation rule")
            rules[rule["identifier"]] = rule
        used, terms = set(), {}
        for identifier, rows in declarations.items():
            rows = tuple(sorted(rows, key=lambda row: row.source_uri))
            if len(rows) > 1:
                rule = rules.get(identifier)
                if rule is None or any(r.category != "class" or r.domains or r.ranges for r in rows):
                    raise MuseumError("ambiguous ontology declaration")
                actual = [{"sourceUri": r.source_uri, "parents": list(r.parents)} for r in rows]
                expected = sorted(rule["declarations"], key=lambda row: row["sourceUri"])
                if actual != expected or len({r.source_uri for r in rows}) != len(rows):
                    raise MuseumError("class augmentation declaration mismatch")
                used.add(identifier)
            row = rows[0]
            terms[identifier] = Term(identifier, row.category,
                                     tuple(sorted({p for r in rows for p in r.parents})),
                                     row.domains, row.ranges, rows)
        if used != set(rules):
            raise MuseumError("unused class augmentation rule")
        self.terms = MappingProxyType(terms)

    def is_subclass(self, actual: str, expected: str) -> bool:
        if actual not in self.terms or self.terms[actual].category != "class":
            raise MuseumError("unknown class")
        if expected not in self.terms or self.terms[expected].category != "class":
            raise MuseumError("unknown expected class")
        visited, queue = set(), [actual]
        while queue:
            current = queue.pop()
            if current == expected:
                return True
            if current in visited:
                continue
            visited.add(current)
            term = self.terms.get(current)
            if term is None or term.category != "class":
                raise MuseumError("class hierarchy dependency missing")
            queue.extend(term.parents)
        return False

    def require_relation(self, subject_class: str, predicate: str, object_class: str):
        term = self.terms.get(predicate)
        if term is None or term.category != "property" or not term.domains or not term.ranges:
            raise MuseumError("property requires explicit domain and range")
        if not all(self.is_subclass(subject_class, domain) for domain in term.domains):
            raise MuseumError("property domain mismatch")
        if not all(self.is_subclass(object_class, range_) for range_ in term.ranges):
            raise MuseumError("property range mismatch")
        return term
