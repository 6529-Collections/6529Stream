"""Keep the test ordinal bridge aligned with the real script catalogs; no compiler."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
LIGHTWEIGHT = "test/helpers/StreamCurrentCreationCatalogTypes.sol"
NATIVE = "test/helpers/StreamNativeAssemblyCreation.sol"
CATALOGS = (
    ("StreamCurrentGraphCreation", "script/current/StreamCurrentGraphCreation.sol", 64),
    ("StreamCurrentAuthorityGraphCreation", "script/current/StreamCurrentAuthorityGraphCreation.sol", 10),
)
TOKEN = re.compile(
    r"(?P<space>\s+)|(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)"
    r"|(?P<string>\"(?:\\[\s\S]|[^\"\\])*\"|'(?:\\[\s\S]|[^'\\])*')"
    r"|(?P<word>[A-Za-z_$][A-Za-z0-9_$]*|0x[0-9a-fA-F]+|[0-9]+)"
    r"|(?P<operator><<=|>>=|\*\*=|==|!=|<=|>=|&&|\|\||\+\+|--|<<|>>|\*\*|=>|[+*/%&|^!-]=)"
    r"|(?P<punct>[{}()\[\].,;:+*/%&|^!~<>=?-])"
)


def tokens(text):
    """Ignore comments/spacing, preserving string bytes and operator boundaries."""
    result = []
    position = 0
    while position < len(text):
        match = TOKEN.match(text, position)
        if match is None:
            raise ValueError(f"Unrecognized Solidity token at character {position}")
        if match.lastgroup not in ("space", "comment"):
            result.append(match.group())
        position = match.end()
    return result


def block(items, opening):
    if items[opening] != "{":
        raise ValueError("Expected declaration body")
    depth = 0
    for end in range(opening, len(items)):
        if items[end] == "{":
            depth += 1
        elif items[end] == "}":
            depth -= 1
            if depth == 0:
                return items[opening + 1:end], end
    raise ValueError("Unterminated declaration body")


def declaration(items, prefix):
    matches = [i for i in range(len(items)) if items[i:i + len(prefix)] == prefix]
    if len(matches) != 1:
        raise ValueError(f"Expected one declaration: {prefix}")
    start = matches[0]
    opening = items.index("{", start)
    body, end = block(items, opening)
    return items[start:opening], body, end


def catalog(text, name):
    _, library, _ = declaration(tokens(text), ["library", name, "{"])
    _, enum, _ = declaration(library, ["enum", "Kind", "{"])
    members = enum[::2]
    if not members or enum[1::2] != [","] * (len(enum) // 2):
        raise ValueError("Expected a plain ordered Kind enum")
    if any(re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", member) is None for member in members):
        raise ValueError("Unexpected enum member")
    if len(set(members)) != len(members):
        raise ValueError("Duplicate enum member")
    header, body, _ = declaration(library, ["function", "name", "("])
    return tuple(enumerate(members)), header + ["{"] + body + ["}"]


def imports(items):
    result = []
    for index, token in enumerate(items):
        if token == "import":
            end = items.index(";", index)
            result.append(items[index:end + 1])
    return result


class CreationCatalogTypesTests(unittest.TestCase):
    def test_complete_kind_ordinals_and_name_bodies_match_script_catalogs(self):
        lightweight = (ROOT / LIGHTWEIGHT).read_text(encoding="utf-8")
        for name, path, count in CATALOGS:
            with self.subTest(catalog=name):
                original = catalog((ROOT / path).read_text(encoding="utf-8"), name)
                copied = catalog(lightweight, name)
                self.assertEqual(len(original[0]), count)
                self.assertEqual(len(copied[0]), count)
                self.assertEqual(copied[0], original[0], "Kind ordinal bridge drifted")
                self.assertEqual(copied[1], original[1], "name() signature or behavior drifted")

    def test_lightweight_catalog_has_no_imports(self):
        self.assertEqual(imports(tokens((ROOT / LIGHTWEIGHT).read_text(encoding="utf-8"))), [])

    def test_native_helper_imports_both_lightweight_nominal_types(self):
        clauses = imports(tokens((ROOT / NATIVE).read_text(encoding="utf-8")))
        light = [clause for clause in clauses
                 if '"./StreamCurrentCreationCatalogTypes.sol"' in clause]
        self.assertEqual(len(light), 1)
        for name, path, _ in CATALOGS:
            self.assertIn(name, light[0])
            self.assertFalse(any('"../../' + path + '"' in clause for clause in clauses))

    def test_comparison_ignores_comments_and_whitespace_but_retains_string_contents(self):
        original = 'library C { enum Kind { A, B } function name(Kind k) internal pure returns(string memory) { return "// { /* literal */"; } }'
        spaced = original.replace("A, B", "A /* ordinal zero */,\n B")
        self.assertEqual(catalog(original, "C"), catalog(spaced, "C"))
        self.assertNotEqual(catalog(original, "C"), catalog(original.replace("literal", "changed"), "C"))

    def test_reordered_member_or_changed_branch_is_detected(self):
        original = 'library C { enum Kind { A, B } function name(Kind k) internal pure returns(string memory) { if (k == Kind.A) return "A"; return "B"; } }'
        self.assertNotEqual(catalog(original, "C"), catalog(original.replace("A, B", "B, A"), "C"))
        self.assertNotEqual(catalog(original, "C"), catalog(original.replace("==", "!="), "C"))


if __name__ == "__main__":
    unittest.main()
