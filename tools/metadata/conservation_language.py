"""RFC5646 grammar and dated registry validity, without rewriting original tags.

Validity is RFC5646 section2.2.9, not extension-specific validity, recommended
Prefix suitability, canonical preferred-value substitution or language identity.
"""
import gzip
import hashlib
import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STANDARDS = ROOT / 'schemas/records/standards/conservation'
REGISTRY_SHA = 'be21e91b6851f750a7b1a687f11209d46ad5a8471d6b10a1efc8d1dac4c8a926'
RFC_SHA = '5d9515f053163c80e7294a84d18217dc83471acc7caa9773da2ac40deeec8228'
REGISTRY_DATE = '2026-08-08'
GRANDFATHERED = frozenset(('en-GB-oed i-ami i-bnn i-default i-enochian i-hak i-klingon i-lux '
    'i-mingo i-navajo i-pwn i-tao i-tay i-tsu sgn-BE-FR sgn-BE-NL sgn-CH-DE art-lojban '
    'cel-gaulish no-bok no-nyn zh-guoyu zh-hakka zh-min zh-min-nan zh-xiang').lower().split())
# Separate regex productions provide an implementation independent of the Solidity scanner.
LANGTAG = re.compile(r'(?P<language>[a-z]{2,3}(?:-[a-z]{3}){0,3}|[a-z]{4}|[a-z]{5,8})'
    r'(?P<script>-[a-z]{4})?(?P<region>-(?:[a-z]{2}|[0-9]{3}))?'
    r'(?P<variants>(?:-(?:[a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*)'
    r'(?P<extensions>(?:-[0-9a-wy-z](?:-[a-z0-9]{2,8})+)*)'
    r'(?P<private>-x(?:-[a-z0-9]{1,8})+)?')


class LanguageError(ValueError):
    pass


def parse(tag):
    if not isinstance(tag, str) or not tag.isascii() or not 0 < len(tag) <= 8192:
        raise LanguageError('language tag bytes')
    lower = tag.lower()
    if lower in GRANDFATHERED:
        return {'grandfathered': lower}
    if re.fullmatch(r'x(?:-[a-z0-9]{1,8})+', lower):
        return {'private': lower}
    match = LANGTAG.fullmatch(lower)
    if match is None:
        raise LanguageError('RFC5646 grammar')
    parts = match.groupdict()
    variants = parts['variants'].strip('-').split('-') if parts['variants'] else []
    extensions = parts['extensions'].strip('-').split('-') if parts['extensions'] else []
    singletons = [x for x in extensions if len(x) == 1]
    if len(variants) != len(set(variants)) or len(singletons) != len(set(singletons)):
        raise LanguageError('case-insensitive variant or singleton duplicate')
    language, *extlang = parts['language'].split('-')
    return {'language': language, 'extlang': extlang, 'script': (parts['script'] or '').lstrip('-'),
            'region': (parts['region'] or '').lstrip('-'), 'variant': variants,
            'extensions': parts['extensions'], 'private': parts['private']}


def original(name, expected):
    raw = gzip.decompress((STANDARDS / (name + '.gz')).read_bytes())
    if hashlib.sha256(raw).hexdigest() != expected:
        raise LanguageError('original standard bytes changed: ' + name)
    return raw


@lru_cache(maxsize=1)
def registry():
    original('rfc5646.txt', RFC_SHA)
    raw = original('language-subtag-registry.txt', REGISTRY_SHA)
    blocks = raw.decode('utf8').split('%%')
    if blocks[0].strip() != 'File-Date: ' + REGISTRY_DATE:
        raise LanguageError('registry date')
    records = {}
    for block in blocks[1:]:
        fields = {}
        last = None
        for line in block.strip().splitlines():
            if line.startswith(' '):
                if last is None:
                    raise LanguageError('registry continuation')
                fields[last][-1] += '\n' + line
            else:
                key, value = line.split(': ', 1)
                fields.setdefault(key, []).append(value)
                last = key
        kind = fields['Type'][0]
        identity = fields.get('Subtag', fields.get('Tag'))[0].lower()
        if (kind, identity) in records:
            raise LanguageError('registry duplicate')
        records[kind, identity] = fields
    if {key for kind, key in records if kind == 'grandfathered'} != GRANDFATHERED:
        raise LanguageError('permanent grandfathered set mismatch')
    return records


def registered(kind, value, records):
    if (kind, value) in records:
        return True
    for (category, identity) in records:
        if category == kind and '..' in identity:
            lo, hi = identity.split('..')
            if len(lo) == len(value) == len(hi) and lo <= value <= hi:
                return True
    return False


def require_valid(tag):
    parsed = parse(tag)
    records = registry()
    if 'grandfathered' in parsed or 'language' not in parsed:
        return tag
    for kind in ('language', 'extlang', 'script', 'region', 'variant'):
        values = parsed[kind] if isinstance(parsed[kind], list) else [parsed[kind]]
        for value in values:
            if value and not registered(kind, value, records):
                raise LanguageError('unregistered ' + kind + ' at ' + REGISTRY_DATE + ': ' + value)
    return tag
