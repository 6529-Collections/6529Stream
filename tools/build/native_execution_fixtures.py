"""Build a sealed, execution-only project from an exact Git source commit."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
import tomllib


READ_SCOPES = (
    'test/fixtures', 'deployments', 'schemas',
    'docs/schemas/finality', 'docs/schemas/preservation',
)


def _require(value, message):
    if not value:
        raise ValueError(message)


def _safe(name: str) -> str:
    path = Path(name)
    _require(name and not path.is_absolute() and '..' not in path.parts
             and '\\' not in name and ':' not in name and path.as_posix() == name,
             f'Unsafe source path: {name!r}')
    for part in name.split('/'):
        _require(part and part not in ('.', '..') and part == part.rstrip(' .')
                 and not re.fullmatch(r'(?:con|prn|aux|nul|conin\$|conout\$|com[1-9]|lpt[1-9])(?:\..*)?',
                                      part, re.IGNORECASE),
                 f'Unsafe Windows source component: {name!r}')
    return name


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _blob_oid(raw: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def _git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(['git', '-c', f'safe.directory={repo.as_posix()}', '-C', str(repo), *args],
                            capture_output=True, check=True)
    return result.stdout


def _tree(repo: Path, commit: str) -> dict[str, str]:
    _require(re.fullmatch(r'[0-9a-f]{40}', commit) is not None, 'Exact source commit SHA required')
    _require(_git(repo, 'cat-file', '-t', commit).strip() == b'commit', 'Git source object is not a commit')
    _require(_git(repo, 'rev-parse', commit).strip().decode() == commit, 'Source commit differs')
    entries = {}
    for row in _git(repo, 'ls-tree', '-r', '-z', commit).split(b'\0'):
        if not row:
            continue
        metadata, name = row.split(b'\t', 1)
        mode, kind, oid = metadata.decode().split()
        path = _safe(name.decode('utf-8'))
        _require(kind == 'blob' and mode in ('100644', '100755'), f'Non-regular source entry: {path}')
        entries[path] = oid
    return entries


def _profile_read_scopes(raw: bytes, profile: str) -> list[str]:
    config = tomllib.loads(raw.decode('utf-8'))
    profiles = config.get('profile', {})
    selected = profiles.get(profile, profiles.get('default', {}))
    permissions = selected.get('fs_permissions', profiles.get('default', {}).get('fs_permissions', []))
    _require(isinstance(permissions, list), 'Source filesystem permissions are not a list')
    scopes = []
    for row in permissions:
        _require(isinstance(row, dict) and set(row) == {'access', 'path'}, 'Unknown source permission')
        if row['access'] != 'read':
            continue
        path = row['path']
        _require(isinstance(path, str) and path.startswith('./'), 'Source permission path differs')
        if path[2:]:
            _safe(path[2:])
        if path[2:] in READ_SCOPES:
            scopes.append(path[2:])
    return sorted(set(scopes))


def _overlay_config(raw: bytes, profile: str, scopes: list[str]) -> bytes:
    _require(re.fullmatch(r'[A-Za-z0-9_-]+', profile) is not None, 'Invalid execution profile')
    text = raw.decode('utf-8')
    line_end = '\r\n' if '\r\n' in text else '\n'
    original = tomllib.loads(text)
    head = f'[profile.{profile}]'
    sections = list(re.finditer(r'(?m)^\[[^\]\r\n]+\][ \t]*$', text))
    start = next((match.end() for match in sections if match.group().strip() == head), None)
    entry = 'fs_permissions = [' + ', '.join(
        '{ access = "read", path = "./' + scope + '" }' for scope in scopes) + ']'
    if start is None:
        modified = text.rstrip('\r\n') + line_end + line_end + head + line_end + entry + line_end
    else:
        end = next((match.start() for match in sections if match.start() > start), len(text))
        section = text[start:end]
        assignment = re.search(r'(?m)^fs_permissions[ \t]*=[ \t]*\[', section)
        if assignment:
            begin = assignment.start()
            opening = assignment.end() - 1
            depth = 0
            close = None
            for index in range(opening, len(section)):
                if section[index] == '[':
                    depth += 1
                elif section[index] == ']':
                    depth -= 1
                    if depth == 0:
                        close = index + 1
                        break
            _require(close is not None, 'Unclosed filesystem permissions')
            section = section[:begin] + entry + section[close:]
        else:
            section = line_end + entry + section
        modified = text[:start] + section + text[end:]
    updated = tomllib.loads(modified)
    original_has_profile = profile in original.get('profile', {})
    for value in (original, updated):
        value.setdefault('profile', {}).setdefault(profile, {}).pop('fs_permissions', None)
    if not original_has_profile:
        for value in (original, updated):
            if not value['profile'][profile]:
                value['profile'].pop(profile)
    _require(original == updated, 'Execution config changed non-filesystem settings')
    _require(_profile_read_scopes(modified.encode(), profile) == scopes,
             'Execution read permissions differ from exact source')
    return modified.encode('utf-8')


def stage_execution_project(project: Path, destination: Path, sources: dict[str, str],
                            repo: Path, commit: str, *, profile: str = 'current') -> dict:
    """Copy only authenticated Solidity sources and scoped non-Solidity Git fixtures."""
    project = project.resolve(); destination = destination.resolve(); repo = repo.resolve()
    _require(not destination.exists() and repo.is_dir(), 'Execution project destination/source differs')
    _require(not destination.is_relative_to(project) and not project.is_relative_to(destination),
             'Execution project overlaps native project')
    tree = _tree(repo, commit)
    for name in tree:
        _safe(name)
    original_config = (project / 'foundry.toml').read_bytes()
    _require('foundry.toml' in tree, 'Source commit lacks Foundry configuration')
    source_config = _git(repo, 'cat-file', 'blob', tree['foundry.toml'])
    _require(_blob_oid(source_config) == tree['foundry.toml'], 'Source configuration blob differs')
    scopes = _profile_read_scopes(source_config, profile)
    _require(scopes, 'No authenticated scoped read permissions')
    materialized = {}
    for name, expected in sorted(sources.items()):
        _safe(name)
        original = project / name
        _require(original.resolve().is_relative_to(project)
                 and not original.is_symlink() and not original.is_junction(),
                 f'Execution source escapes native project: {name}')
        raw = original.read_bytes()
        _require(_sha(raw) == expected and tree.get(name) == _blob_oid(raw),
                 f'Execution source differs from exact Git commit: {name}')
        materialized[name] = raw
    fixtures = {}
    for name, oid in sorted(tree.items()):
        if not any(name.startswith(scope + '/') for scope in scopes):
            continue
        if name.lower().endswith('.sol'):
            continue
        raw = _git(repo, 'cat-file', 'blob', oid)
        _require(_blob_oid(raw) == oid, f'Fixture Git blob differs: {name}')
        if name in materialized:
            _require(materialized[name] == raw, f'Fixture/source collision: {name}')
        else:
            fixtures[name] = raw
    materialized.update(fixtures)
    remappings = project / 'remappings.txt'
    if remappings.is_file():
        materialized['remappings.txt'] = remappings.read_bytes()
    materialized['foundry.toml'] = _overlay_config(original_config, profile, scopes)
    aliases = {}
    for name in materialized:
        folded = name.casefold()
        _require(folded not in aliases, f'Windows-staged path alias: {aliases.get(folded)} / {name}')
        aliases[folded] = name
    destination.mkdir(parents=True)
    for name, raw in materialized.items():
        target = destination / _safe(name)
        _require(target.resolve().is_relative_to(destination), 'Staged file escapes execution project')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    observed = {path.relative_to(destination).as_posix(): _sha(path.read_bytes())
                for path in destination.rglob('*') if path.is_file()}
    expected = {name: _sha(raw) for name, raw in materialized.items()}
    _require(observed == expected, 'Staged execution project differs from intended file inventory')
    return {'sourceCommit': commit, 'sourceFoundrySha256': _sha(source_config),
            'nativeFoundrySha256': _sha(original_config), 'profile': profile,
            'readScopes': scopes, 'fixtureHashes': {name: _sha(raw) for name, raw in fixtures.items()},
            'projectHashes': expected}
