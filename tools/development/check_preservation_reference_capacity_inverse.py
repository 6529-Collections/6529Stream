"""Token-exact source inverse for two fixed preservation reader extractions.

This read-only check is bounded to five named Solidity files at PIN. It proves
source relocation against authenticated Git blobs; it does not compile Solidity,
prove runtime/ABI equality, establish gas behavior, or approve contract size.
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
REFERENCE = DIRECTORY + "StreamPreservationPolicyReferenceSourceReadsV1.sol"
TOKENS = DIRECTORY + "StreamPreservationPolicyRenderCriticalTokenReadsV1.sol"
SNAPSHOT = DIRECTORY + "StreamPreservationPolicyReferenceSnapshotPayloadReadsV1.sol"
ORIGINAL = DIRECTORY + "StreamPreservationPolicyTokenOriginalReadsV1.sol"
DEPENDENCIES = DIRECTORY + "StreamPreservationPolicyReferenceDependencyReadsV1.sol"
FILES = (REFERENCE, TOKENS, SNAPSHOT, ORIGINAL, DEPENDENCIES)
BASE_BLOBS = {
    REFERENCE: "6e32f00de7e41cfdef5ca3f0846284b232f6658a",
    TOKENS: "882a183ce9b422e85d43ce1ae5539c2e72edea51",
}
REFERENCE_IMPORT = (
    'import { StreamPreservationPolicyReferenceSnapshotPayloadReadsV1 as SnapshotPayloadReads } '
    'from "./StreamPreservationPolicyReferenceSnapshotPayloadReadsV1.sol";'
)
TOKEN_IMPORT = (
    'import { StreamPreservationPolicyTokenOriginalReadsV1 as OriginalReads } '
    'from "./StreamPreservationPolicyTokenOriginalReadsV1.sol";'
)
ORIGINAL_TYPE_IMPORT = (
    'import { StreamPreservationPolicyRenderCriticalTokenReadsV1 as Tokens } '
    'from "./StreamPreservationPolicyRenderCriticalTokenReadsV1.sol";'
)
DEPENDENCY_IMPORT = (
    'import { StreamPreservationPolicyReferenceDependencyReadsV1 as DependencyReads } '
    'from "./StreamPreservationPolicyReferenceDependencyReadsV1.sol";'
)
REFERENCE_PROPAGATED_ERRORS = (
    "error InvalidPreservationReferenceFamily();",
    "error PolicyReferenceDependency(address target);",
)
PROPAGATED_ERRORS = (
    "error InvalidPreservationBinding();",
    "error InventorySourceChanged();",
    "error PreservationDependencyChanged(address target);",
    "error PreservationParentGas(uint256 available, uint256 required);",
    "error PreservationReadFailed(address target, bytes4 selector);",
)
# Longest operators remain indivisible: changing <= to < = must not pass.
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
    output = []
    for match in LEXER.finditer(source):
        kind = match.lastgroup
        require(kind != "invalid", "unsupported Solidity token at character " + str(match.start()))
        if kind not in ("space", "comment"):
            output.append(match.group())
    return tuple(output)


def equal(actual, expected, label):
    if actual != expected:
        at = next((i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]),
                  min(len(actual), len(expected)))
        raise InverseError(
            label + ": token " + str(at) + " differs; actual=" + repr(actual[at:at + 8])
            + ", expected=" + repr(expected[at:at + 8])
        )


def close_brace(tokens, start):
    require(tokens[start] == "{", "missing opening brace")
    depth = 0
    for at in range(start, len(tokens)):
        depth += (tokens[at] == "{") - (tokens[at] == "}")
        if depth == 0:
            return at
    raise InverseError("unclosed Solidity body")


@dataclass(frozen=True)
class Member:
    kind: str
    name: str
    tokens: tuple


@dataclass(frozen=True)
class Library:
    prefix: tuple
    name: str
    members: tuple

    def tokens(self):
        return self.prefix + ("library", self.name, "{") + tuple(
            token for member in self.members for token in member.tokens
        ) + ("}",)


def parse_library(source):
    tokens = lex(source)
    positions = [i for i, token in enumerate(tokens) if token == "library"]
    require(len(positions) == 1, "exactly one library declaration required")
    at = positions[0]
    require(at + 2 < len(tokens) and tokens[at + 2] == "{", "unexpected library header")
    end = close_brace(tokens, at + 2)
    require(end == len(tokens) - 1, "unaccounted code after library")
    cursor, members = at + 3, []
    while cursor < end:
        require(tokens[cursor] in ("function", "struct", "error"), "unaccounted library member")
        kind, name = tokens[cursor:cursor + 2]
        if kind == "error":
            last = cursor + 2
            while last < end and tokens[last] != ";":
                require(tokens[last] not in ("{", "}"), "unexpected error body")
                last += 1
            require(last < end, "unterminated error declaration")
            members.append(Member(kind, name, tokens[cursor:last + 1]))
            cursor = last + 1
            continue
        opening = cursor + 2
        while opening < end and tokens[opening] != "{":
            require(tokens[opening] != ";", "declaration without body")
            opening += 1
        require(opening < end, "missing member body")
        last = close_brace(tokens, opening)
        members.append(Member(kind, name, tokens[cursor:last + 1]))
        cursor = last + 1
    return Library(tokens[:at], tokens[at + 1], tuple(members))


def one(library, kind, name):
    found = [m for m in library.members if (m.kind, m.name) == (kind, name)]
    require(len(found) == 1, "expected one " + kind + " " + name)
    return found[0]


def replace_member(library, name, replacement):
    require(sum(m.kind == "function" and m.name == name for m in library.members) == 1,
            "ambiguous inverse replacement " + name)
    members = []
    for member in library.members:
        members.extend(replacement if member.kind == "function" and member.name == name else (member,))
    return Library(library.prefix, library.name, tuple(members))


def remove_import(prefix, statement):
    added = lex(statement)
    matches = [i for i in range(len(prefix) - len(added) + 1) if prefix[i:i + len(added)] == added]
    require(len(matches) == 1, "missing/duplicate exact linked helper import")
    at = matches[0]
    return prefix[:at] + prefix[at + len(added):]


def signature(member):
    at = member.tokens.index("{")
    return member.tokens[:at]


def wrapper(original, body):
    return signature(original) + lex(body)


def inverse_function(member, new_name, original_name, qualify=False, make_private=False):
    """Only the approved signature tokens change; body tokens are untouched."""
    head = list(signature(member))
    require(head[:2] == ["function", new_name], "wrong linked helper function name")
    head[1] = original_name
    if make_private:
        require(head.count("public") == 1 and "private" not in head, "worker must be public")
        head[head.index("public")] = "private"
    if qualify:
        span = ("Tokens", ".", "Original")
        matches = [i for i in range(len(head) - 2) if tuple(head[i:i + 3]) == span]
        require(len(matches) == 1, "expected one exact host Original type qualification")
        at = matches[0]
        head[at:at + 3] = ["Original"]
    return Member("function", original_name, tuple(head) + member.tokens[len(signature(member)):])


def replace_sequence(tokens, before, after, label, count=1):
    before, after = tuple(before), tuple(after)
    found = [i for i in range(len(tokens) - len(before) + 1) if tokens[i:i + len(before)] == before]
    require(len(found) == count, label + ": exact occurrence count differs")
    for at in reversed(found):
        tokens = tokens[:at] + after + tokens[at + len(before):]
    return tokens


def family_member(library, name):
    found = [m for m in library.members if m.kind == "function" and m.name == name
             and any(signature(m)[i:i + 2] == ("bytes32", "family")
                     for i in range(len(signature(m)) - 1))]
    require(len(found) == 1, "expected one family overload: " + name)
    return found[0]


def replace_exact_member(library, before, after):
    require(library.members.count(before) == 1, "exact inverse member missing")
    return Library(library.prefix, library.name, tuple(after if m == before else m for m in library.members))


def inverse_read_facts(member):
    equal(signature(member), lex("""function readFacts(
        T.Dependencies memory d, S.Dependencies memory source, StreamFinalityScope memory scope,
        bytes32 recordHash, uint64 revision, bytes32 family
    ) public view returns (
        S.Receipt memory savedReceipt, S.Source memory sourceFacts, bytes32 contentRootRecord
    )"""), "readFacts exact typed boundary")
    body = member.tokens[len(signature(member)) + 1:-1]
    substitutions = (
        ("scope", "p.scope", 1),
        ("recordHash", "p.observation.snapshotRecordHash", 2),
        ("revision", "p.observation.snapshotRevision", 1),
        ("currentSnapshot", "snapshot", 2),
        ("savedReceipt", "f.snapshot", 1),
        ("sourceFacts", "f.snapshotSource", 1),
        ("contentRootRecord =", "f.contentRootRecordHash =", 1),
        ("snapshot(d, source, original, receipt, family)",
         "_snapshot(d, source, original, receipt, family)", 1),
    )
    for before, after, count in substitutions:
        body = replace_sequence(body, lex(before), lex(after), "readFacts inverse " + before, count)
    return body


def validate(sources, baseline):
    require(set(sources) == set(FILES), "exact five-file working source inventory required")
    require(set(baseline) == set(BASE_BLOBS), "exact two-file baseline inventory required")
    old_reference, old_tokens = (parse_library(baseline[p]) for p in (REFERENCE, TOKENS))
    reference, tokens, snapshot, original, dependencies = (parse_library(sources[p]) for p in FILES)

    # Whole helper shape includes all imports and every member, so hidden code,
    # redirected aliases, overloads, and altered canonical checks cannot escape.
    require(snapshot.name == "StreamPreservationPolicyReferenceSnapshotPayloadReadsV1",
            "snapshot helper identity changed")
    equal(snapshot.prefix, old_reference.prefix, "snapshot helper imports/pragma")
    require([(m.kind, m.name) for m in snapshot.members] ==
            [("function", "readFacts"), ("function", "snapshot"), ("function", "_canonical")],
            "snapshot helper members changed")
    moved_snapshot = inverse_function(one(snapshot, "function", "snapshot"), "snapshot", "_snapshot",
                                      make_private=True)
    equal(moved_snapshot.tokens, one(old_reference, "function", "_snapshot").tokens, "snapshot moved function")
    equal(one(snapshot, "function", "_canonical").tokens,
          one(old_reference, "function", "_canonical").tokens, "snapshot canonical guard")
    equal(one(reference, "function", "_snapshot").tokens,
          wrapper(one(old_reference, "function", "_snapshot"), """{
              f = SnapshotPayloadReads.snapshot(d, source, original, receipt, family);
              original.expectedSourceHash = 0;
          }"""), "snapshot wrapper and post-call caller-memory normalization")
    # Recover the exact contiguous host block from the new linked reader.
    old_source = family_member(old_reference, "requireSource")
    moved_facts = inverse_read_facts(one(snapshot, "function", "readFacts"))
    start = lex("SnapRead.Dependencies memory reader =")
    finish = lex("f.contentRootRecordHash = original.contentRootRecord;")
    starts = [i for i in range(len(old_source.tokens)) if old_source.tokens[i:i + len(start)] == start]
    ends = [i + len(finish) for i in range(len(old_source.tokens))
            if old_source.tokens[i:i + len(finish)] == finish]
    require(len(starts) == len(ends) == 1 and starts[0] < ends[0], "pinned source block bounds")
    equal(moved_facts, old_source.tokens[starts[0]:ends[0]], "readFacts moved contiguous body")
    current_source = family_member(reference, "requireSource")
    call = lex("""(f.snapshot, f.snapshotSource, f.contentRootRecordHash) = SnapshotPayloadReads.readFacts(
        d, source, p.scope, p.observation.snapshotRecordHash, p.observation.snapshotRevision, family
    );""")
    restored_source = replace_sequence(current_source.tokens, call, moved_facts, "readFacts host tuple/arguments")
    # The original local now lives in the helper; its exact returned word feeds
    # the same later root-head comparison. No other operand substitution is allowed.
    restored_source = replace_sequence(restored_source, lex(") != f.contentRootRecordHash"),
                                       lex(") != original.contentRootRecord"), "returned root-head operand")
    equal(restored_source, old_source.tokens, "requireSource complete inverse/read order")
    reconstructed_reference = replace_exact_member(
        reference, current_source, Member("function", "requireSource", restored_source))
    reconstructed_reference = replace_member(reconstructed_reference, "_snapshot", (moved_snapshot,))

    require(dependencies.name == "StreamPreservationPolicyReferenceDependencyReadsV1",
            "dependency helper identity changed")
    equal(dependencies.prefix, old_reference.prefix, "dependency helper imports/pragma")
    require([(m.kind, m.name) for m in dependencies.members] ==
            [("function", "bindings"), ("function", "requireRuntime"), ("function", "_canonical")],
            "dependency helper members changed")
    moved_bindings = one(dependencies, "function", "bindings")
    old_bindings = family_member(old_reference, "bindings")
    equal(moved_bindings.tokens, old_bindings.tokens, "dependency bindings moved function")
    current_bindings = family_member(reference, "bindings")
    equal(current_bindings.tokens, wrapper(old_bindings, "{ return DependencyReads.bindings(d, family); }"),
          "dependency bindings host forwarder")
    moved_runtime = inverse_function(one(dependencies, "function", "requireRuntime"),
                                     "requireRuntime", "_runtime", make_private=True)
    equal(moved_runtime.tokens, one(old_reference, "function", "_runtime").tokens, "runtime moved function")
    equal(one(reference, "function", "_runtime").tokens,
          wrapper(one(old_reference, "function", "_runtime"), "{ DependencyReads.requireRuntime(d, e); }"),
          "runtime host forwarder")
    equal(one(dependencies, "function", "_canonical").tokens,
          one(old_reference, "function", "_canonical").tokens, "dependency canonical guard")
    reconstructed_reference = replace_exact_member(reconstructed_reference, current_bindings, moved_bindings)
    reconstructed_reference = replace_member(reconstructed_reference, "_runtime", (moved_runtime,))
    prefix = remove_import(reconstructed_reference.prefix, REFERENCE_IMPORT)
    prefix = remove_import(prefix, DEPENDENCY_IMPORT)
    reference_errors = tuple(m for m in reference.members if m.kind == "error")
    equal(tuple(m.tokens for m in reference_errors), tuple(lex(e) for e in REFERENCE_PROPAGATED_ERRORS),
          "exact reference propagated error ABI declarations")
    require(reference.members[:len(reference_errors)] == reference_errors,
            "reference propagated errors must remain first host members")
    reconstructed_reference = Library(prefix, reconstructed_reference.name,
                                      tuple(m for m in reconstructed_reference.members if m.kind != "error"))
    equal(reconstructed_reference.tokens(), lex(baseline[REFERENCE]), "reference full-host inverse")

    require(original.name == "StreamPreservationPolicyTokenOriginalReadsV1", "original helper identity changed")
    equal(original.prefix, old_tokens.prefix + lex(ORIGINAL_TYPE_IMPORT), "original helper imports/pragma")
    require([(m.kind, m.name) for m in original.members] ==
            [("function", "original"), ("function", "_preservation")], "original helper members changed")
    moved_original = inverse_function(one(original, "function", "original"), "original", "_original",
                                      qualify=True, make_private=True)
    moved_preservation = inverse_function(one(original, "function", "_preservation"),
                                          "_preservation", "_preservation", qualify=True)
    equal(moved_original.tokens, one(old_tokens, "function", "_original").tokens, "original moved function")
    equal(moved_preservation.tokens, one(old_tokens, "function", "_preservation").tokens,
          "preservation moved function")
    equal(one(tokens, "struct", "Original").tokens, one(old_tokens, "struct", "Original").tokens,
          "host Original tuple")
    equal(one(tokens, "function", "_original").tokens,
          wrapper(one(old_tokens, "function", "_original"),
                  "{ return OriginalReads.original(d, c, sd, index, token); }"), "original wrapper")
    errors = tuple(m for m in tokens.members if m.kind == "error")
    equal(tuple(m.tokens for m in errors), tuple(lex(e) for e in PROPAGATED_ERRORS),
          "exact propagated error ABI declarations")
    require(tokens.members[:len(errors)] == errors, "propagated errors must remain first host members")
    reconstructed_tokens = replace_member(tokens, "_original", (moved_original, moved_preservation))
    reconstructed_tokens = Library(reconstructed_tokens.prefix, reconstructed_tokens.name,
                                   tuple(m for m in reconstructed_tokens.members if m.kind != "error"))
    reconstructed_tokens = Library(remove_import(reconstructed_tokens.prefix, TOKEN_IMPORT),
                                   reconstructed_tokens.name, reconstructed_tokens.members)
    equal(reconstructed_tokens.tokens(), lex(baseline[TOKENS]), "token full-host inverse")
    return {
        "status": "PASS_PRESERVATION_REFERENCE_CAPACITY_SOURCE_INVERSE_ONLY",
        "base": PIN,
        "baselineBlobs": BASE_BLOBS,
        "preservedErrorDeclarations": list(PROPAGATED_ERRORS),
        "preservedReferenceErrorDeclarations": list(REFERENCE_PROPAGATED_ERRORS),
        "files": {p: hashlib.sha256(sources[p].encode("utf-8")).hexdigest() for p in FILES},
        "reconstructedTokenCounts": {
            REFERENCE: len(reconstructed_reference.tokens()), TOKENS: len(reconstructed_tokens.tokens())
        },
        "scope": "Source relocation only; no ABI, bytecode, runtime, size, or gas acceptance.",
    }


def load(root):
    baseline = {}
    for path, expected in BASE_BLOBS.items():
        raw = subprocess.check_output(["git", "-C", str(root), "show", PIN + ":" + path])
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()
        require(blob == expected, "pinned baseline blob differs: " + path)
        baseline[path] = raw.decode("utf-8")
    # read_bytes keeps file hashes honest on Windows; lexical comparison alone
    # ignores only whitespace/comments, never string literal contents.
    sources = {path: (root / path).read_bytes().decode("utf-8") for path in FILES}
    return sources, baseline


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    sources, baseline = load(args.root.resolve())
    print(json.dumps(validate(sources, baseline), indent=2))


if __name__ == "__main__":
    main()
