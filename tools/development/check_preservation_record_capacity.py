"""Bounded source inverse for the fixed preservation Records reader extraction.

Authenticates the exact Git baseline blob and compares Solidity tokens, ignoring
only whitespace and comments. This is source-fidelity evidence, not compilation,
ABI/storage equivalence, runtime size, caller/gas equivalence, or EVM validation.
The checker is read-only and prints its report to stdout.
"""
from dataclasses import dataclass
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PIN = "ea4cf6b0a2cfa7bba529284a3cfe46bb19b6604b"
DIRECTORY = "smart-contracts/domains/preservation/"
RECORDS = DIRECTORY + "StreamPreservationPolicyReferenceRecordsV1.sol"
READS = DIRECTORY + "StreamPreservationPolicyReferenceRecordReadsV1.sol"
PREPARATION = DIRECTORY + "StreamPreservationPolicyReferencePreparationV1.sol"
FILES = (RECORDS, READS, PREPARATION)
BASE_BLOB = "c9868cf13d837e5a76d0e6b28cd09fec8f8fa945"
MAX_SOURCE_BYTES = 524288
PROPAGATED_ERROR = "error InvalidPolicyReference();"
ADDED_IMPORT = '''
import { StreamPreservationPolicyReferenceRecordReadsV1 as RecordReads }
    from "./StreamPreservationPolicyReferenceRecordReadsV1.sol";
'''
PREPARATION_IMPORT = '''
import { StreamPreservationPolicyReferencePreparationV1 as Preparation }
    from "./StreamPreservationPolicyReferencePreparationV1.sol";
'''
HELPER_PREFIX = '''
pragma solidity ^0.8.19;
import { StreamPreservationPolicyReferenceFamiliesV2 as F }
    from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import { StreamPreservationPolicyReferenceTypesV1 as T }
    from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import { StreamPreservationPolicyReferenceSourceReadsV1 as Sources }
    from "./StreamPreservationPolicyReferenceSourceReadsV1.sol";
import { StreamSnapshotManifestBytes as Bytes }
    from "../records/StreamSnapshotManifestBytes.sol";
'''
READ_WRAPPERS = {
    "requireCurrent": "{ definitions(d, family); RecordReads.requireCurrent(original, payload, receipt, d, family); }",
    "recordBytes": "{ return RecordReads.recordBytes(original, receipt); }",
    "source": "{ return RecordReads.source(payload, family); }",
}
WRAPPERS = {**READ_WRAPPERS, "prepare": '''{
    (hash, canonical) = Preparation.prepare(inventories, d, p, receipt, current, family);
    receipt.observation.sourcesHash = hash;
    p.observation.expectedSourcesHash = 0;
    receipt.observation.recordHash = 0;
    receipt.observation.recordChainHash = 0;
    receipt.observation.payloadHash = 0;
    receipt.observation.payloadBytes = 0;
    receipt.observation.recordedAt = 0;
}'''}
# Preserve quoted literals and compound operators as indivisible tokens. In
# particular, comments cannot turn <= into < = or hide a string-content change.
LEXER = re.compile(
    r"(?P<space>\s+)|(?P<comment>//[^\r\n]*|/\*[\s\S]*?\*/)"
    r'|(?P<string>(?:unicode|hex)?(?:"(?:\\[^\r\n]|[^"\\\r\n])*"|\'(?:\\[^\r\n]|[^\'\\\r\n])*\'))'
    r"|(?P<identifier>[A-Za-z_$][A-Za-z0-9_$]*)"
    r"|(?P<number>0[xX][0-9a-fA-F_]+|[0-9][0-9_]*(?:\.[0-9_]+)?(?:[eE][+-]?[0-9_]+)?)"
    r"|(?P<operator>>>=|<<=|>>=|\*\*=|=>|->|\+\+|--|\*\*|&&|\|\||==|!=|<=|>=|<<|>>"
    r"|\+=|-=|\*=|/=|%=|&=|\|=|\^=|[{}\[\]();,.:?~+\-*/%&|^!<>=])"
    r"|(?P<invalid>[\s\S])"
)


class InverseError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InverseError(message)


def lex(source):
    require(len(source.encode("utf-8")) <= MAX_SOURCE_BYTES, "source exceeds bounded input size")
    tokens = []
    for match in LEXER.finditer(source):
        require(match.lastgroup != "invalid", "unsupported Solidity token at " + str(match.start()))
        if match.lastgroup not in ("space", "comment"):
            tokens.append(match.group())
    return tuple(tokens)


def equal(actual, expected, label):
    if actual != expected:
        at = next((i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]),
                  min(len(actual), len(expected)))
        raise InverseError(label + ": differs at item " + str(at))


def closing(tokens, start):
    require(start < len(tokens) and tokens[start] == "{", "missing opening brace")
    depth = 0
    for at in range(start, len(tokens)):
        depth += (tokens[at] == "{") - (tokens[at] == "}")
        if depth == 0:
            return at
    raise InverseError("unclosed Solidity body")


@dataclass(frozen=True)
class Function:
    name: str
    signature: tuple
    body: tuple

    @property
    def tokens(self):
        return self.signature + self.body


@dataclass(frozen=True)
class Library:
    prefix: tuple
    name: str
    functions: tuple
    errors: tuple = ()

    @property
    def tokens(self):
        return self.prefix + ("library", self.name, "{") + tuple(
            token for error in self.errors for token in error
        ) + tuple(
            token for function in self.functions for token in function.tokens
        ) + ("}",)


def parse_library(source):
    tokens = lex(source)
    positions = [i for i, token in enumerate(tokens) if token == "library"]
    require(len(positions) == 1, "exactly one library declaration required")
    at = positions[0]
    require(at + 2 < len(tokens) and tokens[at + 2] == "{", "unexpected library header")
    end = closing(tokens, at + 2)
    require(end == len(tokens) - 1, "unaccounted code after library")
    cursor, functions, errors = at + 3, [], []
    while cursor < end:
        if tokens[cursor] == "error":
            require(not functions, "ABI-only errors must precede all functions")
            last = cursor + 1
            while last < end and tokens[last] != ";":
                require(tokens[last] not in ("{", "}"), "unexpected error body")
                last += 1
            require(last < end, "unterminated error declaration")
            errors.append(tokens[cursor:last + 1])
            cursor = last + 1
            continue
        require(tokens[cursor] == "function", "unaccounted library member")
        require(cursor + 2 < end, "incomplete function")
        opening = cursor + 2
        while opening < end and tokens[opening] != "{":
            require(tokens[opening] not in (";", "}"), "function without body")
            opening += 1
        require(opening < end, "missing function body")
        last = closing(tokens, opening)
        require(last < end, "function consumes library boundary")
        functions.append(Function(tokens[cursor + 1], tokens[cursor:opening], tokens[opening:last + 1]))
        cursor = last + 1
    return Library(tokens[:at], tokens[at + 1], tuple(functions), tuple(errors))


def original_function(library, name, family=False):
    suffix = lex("bytes32 family")
    found = [f for f in library.functions if f.name == name and (
        any(f.signature[i:i + len(suffix)] == suffix for i in range(len(f.signature))) == family
    )]
    require(len(found) == 1, "ambiguous/missing baseline function " + name)
    return found[0]


def git_blob(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()


def validate(sources, baseline):
    require(set(sources) == set(FILES), "exact three-file working source inventory required")
    require(set(baseline) == {RECORDS}, "exact one-file baseline inventory required")
    require(git_blob(baseline[RECORDS].encode("utf-8")) == BASE_BLOB, "pinned baseline blob differs")
    old = parse_library(baseline[RECORDS])
    records, reads, preparation = (parse_library(sources[path]) for path in FILES)
    require(records.name == old.name, "Records library identity changed")
    require(reads.name == "StreamPreservationPolicyReferenceRecordReadsV1", "helper identity changed")
    pragma = lex("pragma solidity ^0.8.19;")
    equal(old.prefix[:len(pragma)], pragma, "baseline pragma")
    equal(records.prefix, pragma + lex(ADDED_IMPORT) + lex(PREPARATION_IMPORT) + old.prefix[len(pragma):], "Records imports/pragma")
    equal(reads.prefix, lex(HELPER_PREFIX), "helper imports/pragma")

    # The only added declaration restores the propagated error in the original
    # Records ABI. Helpers must not acquire any extra declarations.
    equal(records.errors, (lex(PROPAGATED_ERROR),), "exact propagated Records error declaration")
    for library in (old, reads, preparation):
        equal(library.errors, (), "unexpected baseline/helper error declaration")

    # Signature and position distinguish overloads and forbid hidden members.
    equal(tuple(f.signature for f in records.functions), tuple(f.signature for f in old.functions),
          "complete Records function roster/signatures")
    moved = {
        name: original_function(old, name, family=name != "recordBytes") for name in READ_WRAPPERS
    }
    publication = original_function(old, "publication")
    expected_helper = tuple(moved.values()) + (publication,)
    equal(tuple(f.signature for f in reads.functions), tuple(f.signature for f in expected_helper),
          "complete helper function roster/signatures")
    for actual, expected in zip(reads.functions, expected_helper):
        body = expected.body
        if expected.name == "requireCurrent":
            first = lex("{ definitions(d, family);")
            equal(body[:len(first)], first, "baseline current definition-read order")
            body = ("{",) + body[len(first):]
        equal(actual.body, body, "helper moved/copied body " + expected.name)

    # The preparation worker has a literal family-aware body and a private
    # literal definitions copy. No Records import/call can introduce a link cycle.
    require(preparation.name == "StreamPreservationPolicyReferencePreparationV1", "preparation helper identity changed")
    equal(preparation.prefix, old.prefix, "preparation helper imports/pragma")
    original_prepare = original_function(old, "prepare", family=True)
    original_definitions = original_function(old, "definitions", family=True)
    private_signature = tuple("private" if token == "public" else token for token in original_definitions.signature)
    equal(tuple(f.signature for f in preparation.functions),
          (original_prepare.signature, private_signature), "complete preparation helper roster/signatures")
    equal(preparation.functions[0].tokens, original_prepare.tokens, "literal complete preparation body")
    equal(preparation.functions[1].body, original_definitions.body, "literal private definitions copy")
    moved["prepare"] = original_prepare

    # Reinsert exactly four authenticated bodies. The prepare wrapper restores
    # every original caller-owned memory write after the ABI-copy boundary.
    # Both definitions overloads and the original-profile prepare stay exact.
    reconstructed = []
    for current, original in zip(records.functions, old.functions):
        if original.signature in {f.signature for f in moved.values()}:
            equal(current.body, lex(WRAPPERS[original.name]), "exact wrapper " + original.name)
            reconstructed.append(original)
        else:
            equal(current.tokens, original.tokens, "unchanged Records member " + original.name)
            reconstructed.append(current)
    # Omit only the exact ABI-only declaration authenticated above.
    inverse = Library(old.prefix, records.name, tuple(reconstructed))
    equal(inverse.tokens, lex(baseline[RECORDS]), "complete Records source inverse")
    return {
        "status": "PASS_PRESERVATION_RECORD_CAPACITY_SOURCE_INVERSE_ONLY",
        "base": PIN,
        "baselineBlobs": {RECORDS: BASE_BLOB},
        "sourceSha256": {path: hashlib.sha256(sources[path].encode("utf-8")).hexdigest() for path in FILES},
        "comparison": "Solidity tokens; ignores whitespace/comments only; source hashes use exact file bytes.",
        "wrapperFunctions": list(WRAPPERS),
        "preservedErrorDeclaration": PROPAGATED_ERROR,
        "helperFunctionRoster": [f.name for f in reads.functions],
        "preparationFunctionRoster": [f.name for f in preparation.functions],
        "preparationVisibilityException": "definitions public to private; signature otherwise exact",
        "originalFunctionCount": len(old.functions),
        "reconstructedTokenCount": len(inverse.tokens),
        "scope": "Source inverse only; ABI/storage layout, runtime/creation size, execution and gas remain separate checks.",
    }


def load(root):
    root = root.resolve()
    command = ["git", "-C", str(root), "-c", "safe.directory=" + root.as_posix(),
               "show", PIN + ":" + RECORDS]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, "cannot read pinned Git baseline: " + result.stderr.decode("utf-8", errors="replace"))
    require(git_blob(result.stdout) == BASE_BLOB, "pinned baseline Git blob differs")
    sources = {}
    for path in FILES:
        require((root / path).stat().st_size <= MAX_SOURCE_BYTES, "source exceeds bounded input size")
        sources[path] = (root / path).read_bytes().decode("utf-8")
    return sources, {RECORDS: result.stdout.decode("utf-8")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        sources, baseline = load(args.root)
        print(json.dumps(validate(sources, baseline), indent=2))
    except (InverseError, OSError, UnicodeError) as error:
        parser.exit(1, "FAIL_PRESERVATION_RECORD_CAPACITY_SOURCE_INVERSE: " + str(error) + "\n")


if __name__ == "__main__":
    main()
