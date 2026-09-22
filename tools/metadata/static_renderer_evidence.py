"""Bounded Paris EVM read-closure analysis and original Registry golden checks.

This module never creates an Analysis(passed=true) document. CLOSED applies only
to the opcode/read/copy properties and entry inputs named in the result, not to
deployment provenance, semantic determinism, ABI failure handling or admission.
"""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass, field
import json
from pathlib import Path
import re
import sys

from Crypto.Hash import keccak

MASK = (1 << 256) - 1
MAX_OUTPUT = 16_777_216
TOKEN_URI_SIGNATURE = "tokenURI((address,uint256,uint256,uint256,bytes32,uint8,uint8,uint8,uint8,bytes32,bytes32,bytes32))"
FORBIDDEN = {
    0x31: "BALANCE", 0x32: "ORIGIN", 0x3A: "GASPRICE", 0x40: "BLOCKHASH",
    0x41: "COINBASE", 0x42: "TIMESTAMP", 0x43: "NUMBER", 0x44: "PREVRANDAO",
    0x45: "GASLIMIT", 0x47: "SELFBALANCE", 0x48: "BASEFEE", 0x49: "BLOBHASH",
    0x4A: "BLOBBASEFEE", 0x55: "SSTORE", 0xF0: "CREATE", 0xF1: "CALL",
    0xF2: "CALLCODE", 0xF4: "DELEGATECALL", 0xF5: "CREATE2", 0xFF: "SELFDESTRUCT",
    **{op: f"LOG{op - 0xA0}" for op in range(0xA0, 0xA5)},
}


class EvidenceError(ValueError):
    pass


def digest(raw: bytes) -> bytes:
    return keccak.new(digest_bits=256, data=raw).digest()


def word(value: int) -> bytes:
    return value.to_bytes(32, "big")


def _uint(value: object, bits: int, label: str) -> int:
    if type(value) is not int or not 0 <= value < 1 << bits:
        raise EvidenceError(f"{label}: expected uint{bits}")
    return value


def _hex(value: object, label: str, size: int | None = None) -> bytes:
    if not isinstance(value, str) or re.fullmatch(r"0x(?:[0-9a-f]{2})*", value) is None:
        raise EvidenceError(f"{label}: expected lowercase byte hex")
    raw = bytes.fromhex(value[2:])
    if size is not None and len(raw) != size:
        raise EvidenceError(f"{label}: expected {size} bytes")
    return raw


def _address(value: object) -> str:
    if not any(_hex(value, "address", 20)):
        raise EvidenceError("zero address")
    return value


def _keys(value: object, names: str, label: str) -> dict:
    if not isinstance(value, dict) or set(value) != set(names.split()):
        raise EvidenceError(f"{label}: unexpected/missing fields")
    return value


def _list(value: object, maximum: int, label: str) -> list:
    if not isinstance(value, list) or len(value) > maximum:
        raise EvidenceError(f"{label}: expected array, maximum {maximum}")
    return value


def _json_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def load_packet(path: Path) -> dict:
    # Local input bound; not a new protocol maximum.
    if path.stat().st_size > 128 * 1024 * 1024:
        raise EvidenceError("packet exceeds local 128 MiB input bound")
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_json_pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(EvidenceError("non-finite JSON")))
    except (UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        raise EvidenceError("invalid JSON packet") from exc


def instructions(code: bytes) -> dict[int, tuple[int, int, int]]:
    """PUSH data is never decoded as instructions. Truncated PUSH is zero padded."""
    result = {}
    pc = 0
    while pc < len(code):
        op = code[pc]
        width = op - 0x5F if 0x60 <= op <= 0x7F else 0
        value = int.from_bytes(code[pc + 1:pc + 1 + width].ljust(width, b"\0"), "big")
        result[pc] = (op, value, pc + width + 1)
        pc += width + 1
    return result


class _Incomplete(Exception):
    pass


class _ExceptionalHalt(Exception):
    pass


@dataclass(frozen=True)
class _Bits:
    value: int
    known: int


def _partial(value, known):
    known &= MASK
    value &= known
    return value if known == MASK else None if known == 0 else _Bits(value, known)


def _bits(value):
    if isinstance(value, _Bits): return value.value, value.known
    return (0, 0) if value is None else (value, MASK)


def _constant(value):
    return value if type(value) is int else None


@dataclass
class _State:
    pc: int = 0
    stack: list[int | _Bits | None] = field(default_factory=list)
    memory: dict[int, int | None] = field(default_factory=dict)
    memory_size: int = 0
    return_cap: int | None = None  # None means no preceding STATICCALL.
    copied: int = 0

    def clone(self):
        return _State(self.pc, self.stack.copy(), self.memory.copy(), self.memory_size,
                      self.return_cap, self.copied)

    def key(self):
        return (self.pc, tuple(self.stack), tuple(sorted(self.memory.items())),
                self.memory_size, self.return_cap, self.copied)

    def pop(self):
        if not self.stack:
            raise _ExceptionalHalt()
        return self.stack.pop()

    def scalar(self):
        return _constant(self.pop())

    def push(self, value):
        if len(self.stack) == 1024:
            raise _ExceptionalHalt()
        self.stack.append(value if value is None or isinstance(value, _Bits) else value & MASK)

    def span(self, offset, size, limit):
        if size == 0:
            return range(0)
        if offset is None or size is None:
            raise _Incomplete("unresolved memory range")
        if offset + size > limit:
            raise _Incomplete("local memory exploration bound")
        self.memory_size = max(self.memory_size, (offset + size + 31) // 32 * 32)
        return range(offset, offset + size)

    def read(self, offset, size, limit):
        return tuple(self.memory.get(i, 0) for i in self.span(offset, size, limit))

    def write(self, offset, values, limit):
        for i, value in zip(self.span(offset, len(values), limit), values):
            # Missing bytes represent zero, not unknown.
            if value == 0:
                self.memory.pop(i, None)
            else:
                self.memory[i] = value


def _number(values):
    value, known = 0, 0
    for byte in values:
        value = (value << 8) | (byte or 0)
        known = (known << 8) | (0 if byte is None else 255)
    return _partial(value, known)


def _signed(value):
    return value - (1 << 256) if value >= 1 << 255 else value


def _arithmetic(op, values):
    # Keep known selector bits through CALLDATALOAD/SHR and memory roundtrips.
    # Other arithmetic may safely widen a partial value to TOP.
    av, ak = _bits(values[0])
    bv, bk = _bits(values[1]) if len(values) > 1 else (0, MASK)
    if op == 0x14 and ((av ^ bv) & ak & bk): return 0
    if op == 0x15 and av: return 0
    if op == 0x16:
        return _partial(av & bv, (ak & bk) | (ak & ~av) | (bk & ~bv))
    if op == 0x17:
        return _partial(av | bv, (ak & bk) | (ak & av) | (bk & bv))
    if op == 0x18: return _partial(av ^ bv, ak & bk)
    if op == 0x19: return _partial(~av, ak)
    if op in (0x1A, 0x1B, 0x1C, 0x1D) and type(values[0]) is int:
        shift = values[0]
        if op == 0x1A:
            if shift >= 32: return 0
            shift = 248 - shift * 8
            return _partial((bv >> shift) & 255, ((bk >> shift) & 255) | (MASK ^ 255))
        if op == 0x1B:
            if shift >= 256: return 0
            return _partial(bv << shift, (bk << shift) | ((1 << shift) - 1))
        if op == 0x1C:
            if shift >= 256: return 0
            return _partial(bv >> shift, (bk >> shift) | (MASK ^ (MASK >> shift)))
        if op == 0x1D:
            shift = min(shift, 256)
            high = MASK ^ (MASK >> shift)
            sign_known = bk & (1 << 255)
            return _partial((bv >> shift) | (high if bv & (1 << 255) else 0),
                            (bk >> shift) | (high if sign_known else 0))
    if any(type(value) is not int for value in values): return None
    a = values[0]
    b = values[1] if len(values) > 1 else 0
    if op == 0x01: return a + b
    if op == 0x02: return a * b
    if op == 0x03: return a - b
    if op == 0x04: return 0 if b == 0 else a // b
    if op == 0x05:
        a, b = _signed(a), _signed(b)
        return 0 if b == 0 else (abs(a) // abs(b)) * (-1 if (a < 0) != (b < 0) else 1)
    if op == 0x06: return 0 if b == 0 else a % b
    if op == 0x07:
        a, b = _signed(a), _signed(b)
        return 0 if b == 0 else (abs(a) % abs(b)) * (-1 if a < 0 else 1)
    if op == 0x08: return 0 if values[2] == 0 else (a + b) % values[2]
    if op == 0x09: return 0 if values[2] == 0 else (a * b) % values[2]
    if op == 0x0A: return pow(a, b, 1 << 256)
    if op == 0x0B:
        if a >= 32: return b
        low = (1 << (8 * a + 8)) - 1
        return b | (MASK ^ low) if b & (1 << (8 * a + 7)) else b & low
    if op == 0x10: return int(a < b)
    if op == 0x11: return int(a > b)
    if op == 0x12: return int(_signed(a) < _signed(b))
    if op == 0x13: return int(_signed(a) > _signed(b))
    if op == 0x14: return int(a == b)
    if op == 0x15: return int(a == 0)
    if op == 0x16: return a & b
    if op == 0x17: return a | b
    if op == 0x18: return a ^ b
    if op == 0x19: return MASK ^ a
    if op == 0x1A: return 0 if a >= 32 else (b >> (248 - a * 8)) & 255
    if op == 0x1B: return 0 if a >= 256 else b << a
    if op == 0x1C: return 0 if a >= 256 else b >> a
    if op == 0x1D: return _signed(b) >> min(a, 256)
    raise AssertionError(op)


def analyze(runtimes: dict[str, bytes], entries: list[dict], reads: list[dict], *,
            max_states: int = 20_000, max_contexts: int = 128, memory_limit: int = 65_536,
            max_memory_cells: int = 1_000_000) -> dict:
    """Conservative interpreter: unknown values are TOP, never guessed constants.

    Every unknown conditional branch is explored; unknown jump/call destinations
    refuse closure. Callee output/success/storage are always unknown. No sampled
    trace or caller-supplied reachable-PC list is used to prune paths.
    """
    for bound in (max_states, max_contexts, memory_limit, max_memory_cells):
        if type(bound) is not int or not 1 <= bound <= 1_000_000:
            raise EvidenceError("invalid local exploration bound")
    if not runtimes or not entries:
        raise EvidenceError("runtime set and entries required")
    for address, code in runtimes.items():
        _address(address)
        if not isinstance(code, bytes) or not code or len(code) > 24_576:
            raise EvidenceError("runtime must be concrete deployed bytes within EIP-170")
    declared = {}
    for row in reads:
        _keys(row, "target selector maxReturnBytes exact", "read")
        target = _address(row["target"])
        selector = _hex(row["selector"], "selector", 4)
        maximum = _uint(row["maxReturnBytes"], 32, "maxReturnBytes")
        if not any(selector) or not 0 < maximum <= MAX_OUTPUT or type(row["exact"]) is not bool:
            raise EvidenceError("invalid read declaration")
        if row["exact"] and maximum % 32:
            raise EvidenceError("exact read width")
        if target not in runtimes or (target, selector) in declared:
            raise EvidenceError("missing read runtime or duplicate declaration")
        declared[target, selector] = maximum
    work = deque()
    for entry in entries:
        _keys(entry, "address selector calldataBytes", "entry")
        address = _address(entry["address"])
        selector = _hex(entry["selector"], "entry selector", 4)
        length = _uint(entry["calldataBytes"], 32, "calldataBytes")
        if address not in runtimes or not 4 <= length <= memory_limit:
            raise EvidenceError("entry runtime/length unavailable")
        work.append((address, None, tuple(selector) + (None,) * (length - 4)))
    decoded = {address: instructions(code) for address, code in runtimes.items()}
    contexts = set()
    issues = set()
    edges = set()
    visited_pcs = set()
    count = 0
    memory_cells = 0

    def issue(kind, address, pc, reason):
        issues.add((kind, address, pc, reason))

    while work:
        address, caller, calldata = work.popleft()
        context = (address, caller, calldata)
        if context in contexts:
            continue
        if len(contexts) >= max_contexts:
            issue("incomplete", address, 0, "local transitive context bound")
            break
        contexts.add(context)
        queue = deque([_State()])
        seen = set()
        while queue:
            state = queue.popleft()
            memory_cells += len(state.memory)
            if memory_cells > max_memory_cells:
                issue("incomplete", address, state.pc, "local cumulative memory exploration bound")
                work.clear()
                queue.clear()
                break
            key = state.key()
            if key in seen:
                continue
            seen.add(key)
            count += 1
            pc = state.pc
            if count > max_states:
                issue("incomplete", address, pc, "local state exploration bound")
                work.clear()
                queue.clear()
                break
            if pc >= len(runtimes[address]):
                continue  # EVM STOP beyond code.
            op, immediate, next_pc = decoded[address][pc]
            visited_pcs.add((address, pc))
            state.pc = next_pc
            try:
                if op in FORBIDDEN:
                    issue("forbidden", address, pc, FORBIDDEN[op])
                    continue
                if op in (0x00, 0xFE):
                    continue
                if op in (0xF3, 0xFD):
                    state.pop(); state.pop()
                    continue
                if 0x60 <= op <= 0x7F:
                    state.push(immediate)
                elif 0x80 <= op <= 0x8F:
                    depth = op - 0x7F
                    if len(state.stack) < depth: raise _ExceptionalHalt()
                    state.push(state.stack[-depth])
                elif 0x90 <= op <= 0x9F:
                    depth = op - 0x8F
                    if len(state.stack) <= depth: raise _ExceptionalHalt()
                    state.stack[-1], state.stack[-1 - depth] = state.stack[-1 - depth], state.stack[-1]
                elif op in (*range(0x01, 0x0C), *range(0x10, 0x1E)):
                    arity = 1 if op in (0x15, 0x19) else 3 if op in (0x08, 0x09) else 2
                    state.push(_arithmetic(op, [state.pop() for _ in range(arity)]))
                elif op == 0x20:
                    offset, size = state.scalar(), state.scalar()
                    data = state.read(offset, size, memory_limit)
                    state.push(None if None in data else int.from_bytes(digest(bytes(data)), "big"))
                elif op == 0x30: state.push(int(address, 16))
                elif op == 0x33: state.push(None if caller is None else int(caller, 16))
                elif op == 0x34: state.push(0)  # STATIC serving entry/callee.
                elif op == 0x35:
                    offset = state.scalar()
                    state.push(None if offset is None else _number(tuple(
                        calldata[i] if i < len(calldata) else 0 for i in range(offset, offset + 32))))
                elif op == 0x36: state.push(len(calldata))
                elif op in (0x37, 0x39):
                    dest, offset, size = state.scalar(), state.scalar(), state.scalar()
                    state.span(dest, size, memory_limit)
                    source = calldata if op == 0x37 else runtimes[address]
                    if size is None: raise _Incomplete("unresolved copy length")
                    data = (None,) * size if offset is None else tuple(
                        source[i] if i < len(source) else 0 for i in range(offset, offset + size))
                    state.write(dest, data, memory_limit)
                elif op == 0x38: state.push(len(runtimes[address]))
                elif op in (0x3B, 0x3F):
                    target = state.scalar()
                    if target is None: raise _Incomplete("unresolved code observation target")
                    target = f"0x{target & ((1 << 160) - 1):040x}"
                    if target not in runtimes:
                        raise _Incomplete("code observation outside pinned runtime set")
                    state.push(len(runtimes[target]) if op == 0x3B else int.from_bytes(digest(runtimes[target]), "big"))
                elif op == 0x3D: state.push(0 if state.return_cap is None else None)
                elif op == 0x3E:
                    dest, offset, size = state.scalar(), state.scalar(), state.scalar()
                    if state.return_cap is None:
                        if offset is None or size is None: raise _Incomplete("unresolved initial returndata copy")
                        if offset + size != 0: raise _ExceptionalHalt()
                    else:
                        if size is None or offset is None: raise _Incomplete("unresolved returndata copy bound")
                        if state.copied + size > state.return_cap:
                            issue("incomplete", address, pc, "returndata copy may exceed declared cap")
                            continue
                        state.copied += size
                    state.span(dest, size, memory_limit)
                    state.write(dest, (None,) * size, memory_limit)
                elif op == 0x46: state.push(None)  # CHAINID is not in the original opcode ban.
                elif op == 0x50: state.pop()
                elif op == 0x51: state.push(_number(state.read(state.scalar(), 32, memory_limit)))
                elif op in (0x52, 0x53):
                    offset, value = state.scalar(), state.pop()
                    width = 32 if op == 0x52 else 1
                    bits, known = _bits(value)
                    values = tuple((bits >> (8 * i)) & 255 if (known >> (8 * i)) & 255 == 255 else None
                                   for i in reversed(range(width)))
                    state.write(offset, values, memory_limit)
                elif op == 0x54: state.pop(); state.push(None)
                elif op in (0x56, 0x57):
                    target = state.scalar()
                    condition = 1 if op == 0x56 else state.pop()
                    if isinstance(condition, _Bits): condition = 1 if condition.value else None
                    if condition != 0:
                        if target is None: raise _Incomplete("unresolved jump destination")
                        if target not in decoded[address] or decoded[address][target][0] != 0x5B:
                            if condition is not None: continue  # Exceptional taken path only.
                        else:
                            branch = state.clone(); branch.pc = target; queue.append(branch)
                    if condition is not None and condition != 0: continue
                elif op == 0x58: state.push(pc)
                elif op == 0x59: state.push(state.memory_size)
                elif op == 0x5A:
                    raise _Incomplete("GAS requires bounded-call precheck proof; pattern unsupported")
                elif op == 0x5B: pass
                elif op == 0xFA:
                    gas, target, start, size, out, out_size = [state.scalar() for _ in range(6)]
                    if gas is None: raise _Incomplete("unresolved STATICCALL gas")
                    if target is None: raise _Incomplete("unresolved STATICCALL target")
                    target = f"0x{target & ((1 << 160) - 1):040x}"
                    data = state.read(start, size, memory_limit)
                    if len(data) < 4 or None in data[:4]:
                        raise _Incomplete("unresolved STATICCALL selector")
                    selector = bytes(data[:4])
                    maximum = declared.get((target, selector))
                    if maximum is None:
                        issue("forbidden", address, pc, f"undeclared read {target}/{selector.hex()}")
                        continue
                    if out_size is None or out_size > maximum:
                        raise _Incomplete("STATICCALL output copy may exceed declared cap")
                    state.span(out, out_size, memory_limit)
                    state.write(out, (None,) * out_size, memory_limit)
                    edges.add((address, pc, target, selector.hex(), maximum))
                    work.append((target, address, data))
                    state.return_cap, state.copied = maximum, out_size
                    state.push(None)  # Success/failure both explored; no assumed callee result.
                else:
                    raise _Incomplete(f"unsupported Paris opcode 0x{op:02x}")
                queue.append(state)
            except _ExceptionalHalt:
                pass  # Stack underflow/overflow terminates this path, like the EVM.
            except _Incomplete as exc:
                issue("incomplete", address, pc, str(exc))
    return {
        "status": "REFUSED" if any(i[0] == "forbidden" for i in issues) else "INCOMPLETE" if issues else "CLOSED",
        "property": "specified-entry reachable opcode/read closure and bounded returndata copies",
        "entries": entries,
        "runtimeHashes": {a: "0x" + digest(c).hex() for a, c in sorted(runtimes.items())},
        "issues": [dict(zip(("kind", "address", "pc", "reason"), i)) for i in sorted(issues)],
        "reads": [dict(zip(("caller", "pc", "target", "selector", "maxReturnBytes"), e)) for e in sorted(edges)],
        "contexts": len(contexts), "states": count, "reachableInstructions": len(visited_pcs),
        "limits": {"states": max_states, "contexts": max_contexts, "memoryBytes": memory_limit,
                   "cumulativeMemoryCells": max_memory_cells},
        "deploymentVerified": False, "semanticDeterminismVerified": False,
        "abiFailureHandlingVerified": False, "registrationApproved": False, "admissionReady": False,
    }


def golden_vectors(payload: bytes) -> list[tuple[bytes, bytes]]:
    """Decode exactly abi.encode(IStreamRendererRegistry.GoldenVector[])."""
    if len(payload) < 64 or len(payload) > 8192 or payload[:32] != word(32):
        raise EvidenceError("golden array offset/size")
    count = int.from_bytes(payload[32:64], "big")
    if not 1 <= count <= 16 or len(payload) != 64 + count * 416:
        raise EvidenceError("golden array length")
    result = []
    selector = digest(TOKEN_URI_SIGNATURE.encode())[:4]
    for i in range(count):
        row = payload[64 + 416 * i:64 + 416 * (i + 1)]
        values = [int.from_bytes(row[j:j + 32], "big") for j in range(0, 384, 32)]
        if values[0] >= 1 << 160 or values[5] > 3 or values[6] > 2 or values[7] > 255 or values[8] > 255:
            raise EvidenceError("noncanonical RenderRequest field")
        if not any(row[384:]):
            raise EvidenceError("zero golden output hash")
        result.append((selector + row[:384], row[384:]))
    return result


def string_result(raw: bytes, maximum: int) -> bytes:
    if len(raw) < 64 or raw[:32] != word(32):
        raise EvidenceError("noncanonical string offset")
    length = int.from_bytes(raw[32:64], "big")
    end = 64 + length
    if length > maximum or len(raw) != 64 + ((length + 31) // 32) * 32 or any(raw[end:]):
        raise EvidenceError("noncanonical/oversized string result")
    return raw[64:end]


def check_packet(packet: dict) -> dict:
    """Bind original ABI documents, pinned runtimes, and supplied recomputations.

    The packet is a local transport, not a new schema or governance declaration.
    Supplied recomputations are not authenticated RPC/trace/deployment evidence.
    """
    _keys(packet, "version renderer rendererRuntime rendererVersion contextVersion schemaHash maxJSONBytes targets reads analysisPayload goldenPayload recomputations", "packet")
    if type(packet["version"]) is not int or packet["version"] != 1:
        raise EvidenceError("packet version")
    renderer = _address(packet["renderer"])
    runtimes = {renderer: _hex(packet["rendererRuntime"], "rendererRuntime")}
    maximum = _uint(packet["maxJSONBytes"], 32, "maxJSONBytes")
    if not 0 < maximum <= MAX_OUTPUT: raise EvidenceError("maxJSONBytes bound")
    versions = [_hex(packet[k], k, 32) for k in ("rendererVersion", "contextVersion", "schemaHash")]
    if any(not any(v) for v in versions): raise EvidenceError("zero version/schema")
    targets = _list(packet["targets"], 64, "targets")
    if not targets: raise EvidenceError("empty targets")
    target_bytes = word(32) + word(len(targets))
    previous = 0
    for target in targets:
        _keys(target, "address runtime role", "target")
        address = _address(target["address"])
        code = _hex(target["runtime"], "runtime")
        role = _hex(target["role"], "role", 32)
        if int(address, 16) <= previous or (address in runtimes and runtimes[address] != code):
            raise EvidenceError("target order/runtime conflict")
        previous = int(address, 16)
        runtimes[address] = code
        target_bytes += word(previous) + digest(code) + role
    target_hash = digest(target_bytes)
    reads = _list(packet["reads"], 128, "reads")
    read_bytes = word(len(reads))
    expanded = []
    previous = -1
    for row in reads:
        _keys(row, "targetIndex selector maxReturnBytes exact", "read")
        index = _uint(row["targetIndex"], 16, "targetIndex")
        selector = _hex(row["selector"], "selector", 4)
        cap = _uint(row["maxReturnBytes"], 32, "maxReturnBytes")
        if index >= len(targets) or type(row["exact"]) is not bool:
            raise EvidenceError("read target/exact")
        order = (index << 32) | int.from_bytes(selector, "big")
        if order <= previous: raise EvidenceError("read order")
        previous = order
        read_bytes += word(index) + selector.ljust(32, b"\0") + word(cap) + word(int(row["exact"]))
        expanded.append({"target": targets[index]["address"], "selector": row["selector"], "maxReturnBytes": cap, "exact": row["exact"]})
    set_hash = digest(digest(b"6529STREAM_RENDERER_READ_SET_V1") + target_hash + word(96) + read_bytes)
    analysis = _hex(packet["analysisPayload"], "analysisPayload", 320)
    expected_prefix = digest(b"6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1") + word(int(renderer, 16)) + digest(runtimes[renderer]) + set_hash + b"".join(versions)
    if analysis[:224] != expected_prefix or not any(analysis[224:256]) or not any(analysis[256:288]) or analysis[288:] != word(1):
        raise EvidenceError("Analysis binding/canonical boolean")
    golden = _hex(packet["goldenPayload"], "goldenPayload")
    vectors = golden_vectors(golden)
    runs = _list(packet["recomputations"], 64, "recomputations")
    if not runs: raise EvidenceError("missing golden recomputation")
    labels = set()
    for run in runs:
        _keys(run, "label stateHash results", "recomputation")
        label = run["label"]
        if not isinstance(label, str) or not label or len(label) > 128 or label in labels:
            raise EvidenceError("recomputation label")
        labels.add(label)
        if not any(_hex(run["stateHash"], "stateHash", 32)):
            raise EvidenceError("missing supplied read-state identity")
        results = _list(run["results"], 16, "results")
        if len(results) != len(vectors): raise EvidenceError("missing/extra golden result")
        for row, (calldata, output_hash) in zip(results, vectors):
            _keys(row, "calldata returnData", "result")
            if _hex(row["calldata"], "calldata") != calldata:
                raise EvidenceError("golden request/order mismatch")
            uri = string_result(_hex(row["returnData"], "returnData"), 29 + 4 * ((maximum + 2) // 3))
            if digest(uri) != output_hash: raise EvidenceError("golden output drift")
    result = analyze(runtimes, [{"address": renderer, "selector": "0x" + digest(TOKEN_URI_SIGNATURE.encode())[:4].hex(), "calldataBytes": 388}], expanded)
    return {"analysis": result, "golden": {"vectors": len(vectors), "suppliedRecomputations": len(runs), "allBytesMatch": True, "executionVerified": False},
            "targetSetHash": "0x" + target_hash.hex(), "readSetHash": "0x" + set_hash.hex(),
            "analysisDocumentHash": "0x" + digest(analysis).hex(), "goldenDocumentHash": "0x" + digest(golden).hex(),
            "registeredAnalysisClaimVerified": False, "routerPathsAnalyzed": False, "admissionReady": False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packet", type=Path)
    parser.add_argument("--analyze-only", action="store_true",
                        help="Analyze runtimes/entries/reads without any external Analysis or goldens")
    args = parser.parse_args(argv)
    try:
        packet = load_packet(args.packet)
        if args.analyze_only:
            _keys(packet, "runtimes entries reads", "analysis input")
            if not isinstance(packet["runtimes"], dict) or len(packet["runtimes"]) > 65:
                raise EvidenceError("analysis runtime set")
            result = analyze({address: _hex(raw, "runtime") for address, raw in packet["runtimes"].items()},
                             _list(packet["entries"], 128, "entries"), _list(packet["reads"], 128, "reads"))
            status = result["status"]
        else:
            result = check_packet(packet)
            status = result["analysis"]["status"]
    except (EvidenceError, OSError) as exc:
        print(f"renderer evidence refused: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if status == "CLOSED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
