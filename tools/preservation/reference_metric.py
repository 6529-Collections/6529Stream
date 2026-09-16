"""Bounded, integer-only SSIM profile and the exact onchain perceptual report preimage.

This measures supplied PNG bytes. A supplied context hash is not RPC authentication,
browser-execution evidence, or permission to publish; the mode host recomputes it.
"""
import argparse
import hashlib
import json
from pathlib import Path

from tools.museum.chain_abi import Array, encode
from tools.museum.canonical import hex_bytes, keccak256
from tools.preservation.reference_manifest import png_pixels

ROOT = Path(__file__).resolve().parents[2]
SCALE = 1_000_000_000
WEIGHTS = (1, 8, 38, 114, 222, 277, 222, 114, 38, 8, 1)
PARAMETERS = {
    "profile": "STREAM_SSIM_RGB8_INTEGER_GAUSSIAN11_V1",
    "window": list(WEIGHTS), "windowRule": "separable fixed integer weights; valid windows only",
    "moments": "weighted population moments", "channels": "mean of RGB; RGBA requires alpha255",
    "range": 255, "c1": [65025, 10000], "c2": [585225, 10000],
    "rounding": "floor each window/channel score at1e9; floor their mean",
    "scaling": "no resampling, gamma conversion or color-profile application",
    "input": "PNG8 RGB/RGBA, noninterlaced, sRGB or untagged;11..512 each dimension",
}
METRIC_ABI = ("bytes32", "bytes32", "string", "string", "bytes32", "bytes32", "uint64")
REPORT_ABI = ("bytes32", "bytes32", METRIC_ABI, "uint256", Array("uint256", 2), "uint64")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def implementation_hash():
    # Pin the local source files containing the functions used by this tool. Python/zlib
    # executable versions still belong in the separately retained capture environment.
    names = ("tools/preservation/reference_metric.py", "tools/preservation/reference_manifest.py",
             "tools/museum/chain_abi.py", "tools/museum/canonical.py")
    return keccak256(canonical({name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names}))


def metric():
    return (keccak256(b"STREAM_METRIC_SSIM_V1"), keccak256(PARAMETERS["profile"].encode()),
            "6529Stream integer SSIM", "1.0.0", implementation_hash(),
            keccak256(canonical(PARAMETERS)), SCALE)


def rgb(raw, width, height):
    if type(width) is not int or type(height) is not int or not (11 <= width <= 512 and 11 <= height <= 512):
        raise ValueError("metric geometry bound")
    if len(raw) > 4_194_304:
        raise ValueError("metric PNG byte bound")
    filtered = png_pixels(raw, width, height)
    # The closed profile doesn't silently interpret embedded ICC/gamma/chromaticity.
    offset = 8
    while offset < len(raw):
        size = int.from_bytes(raw[offset:offset + 4], "big")
        kind = raw[offset + 4:offset + 8]
        body = raw[offset + 8:offset + 8 + size]
        if kind in (b"iCCP", b"gAMA", b"cHRM", b"tRNS") or (kind == b"sRGB" and body != b"\x00"):
            raise ValueError("unsupported PNG color interpretation")
        offset += 12 + size
    channels = 3 if raw[25] == 2 else 4
    stride = width * channels
    previous = bytearray(stride)
    result = []
    for row in range(height):
        start = row * (stride + 1)
        method = filtered[start]
        current = bytearray(filtered[start + 1:start + 1 + stride])
        for i in range(stride):
            left = current[i - channels] if i >= channels else 0
            above = previous[i]
            upper_left = previous[i - channels] if i >= channels else 0
            predictor = 0
            if method == 1:
                predictor = left
            elif method == 2:
                predictor = above
            elif method == 3:
                predictor = (left + above) // 2
            elif method == 4:
                p = left + above - upper_left
                a, b, c = abs(p - left), abs(p - above), abs(p - upper_left)
                predictor = left if a <= b and a <= c else above if b <= c else upper_left
            current[i] = (current[i] + predictor) & 255
        if channels == 4 and any(current[i] != 255 for i in range(3, stride, 4)):
            raise ValueError("nonopaque alpha")
        result.append(tuple(tuple(current[i:i + 3]) for i in range(0, stride, channels)))
        previous = current
    return result


def score(first, second, width, height):
    """Weighted SSIM formula with exact rational moments and declared integer rounding."""
    a, b = rgb(first, width, height), rgb(second, width, height)
    total = count = 0
    weight = sum(WEIGHTS) ** 2
    squared = weight * weight
    for channel in range(3):
        horizontal = []
        for y in range(height):
            row = []
            for x in range(width - 10):
                sx = sy = sxx = syy = sxy = 0
                for i, w in enumerate(WEIGHTS):
                    ax, bx = a[y][x + i][channel], b[y][x + i][channel]
                    sx += w * ax; sy += w * bx
                    sxx += w * ax * ax; syy += w * bx * bx; sxy += w * ax * bx
                row.append((sx, sy, sxx, syy, sxy))
            horizontal.append(row)
        for y in range(height - 10):
            for x in range(width - 10):
                moments = [sum(w * horizontal[y + i][x][k] for i, w in enumerate(WEIGHTS)) for k in range(5)]
                sx, sy, sxx, syy, sxy = moments
                luminance_n = 20000 * sx * sy + 65025 * squared
                luminance_d = 10000 * (sx * sx + sy * sy) + 65025 * squared
                contrast_n = 20000 * (weight * sxy - sx * sy) + 585225 * squared
                contrast_d = 10000 * (weight * (sxx + syy) - sx * sx - sy * sy) + 585225 * squared
                total += (SCALE * luminance_n * contrast_n) // (luminance_d * contrast_d)
                count += 1
    return total // count


def report_preimage(context, definition, threshold, scores, evaluated_at):
    hex_bytes(context, 32)
    if type(threshold) is not int or not 0 <= threshold <= SCALE or not 1 <= len(scores) <= 2:
        raise ValueError("report threshold/sample bound")
    if any(type(s) is not int or not -SCALE <= s <= SCALE for s in scores):
        raise ValueError("report signed score bound")
    if type(evaluated_at) is not int or not 0 < evaluated_at < 1 << 64:
        raise ValueError("report date bound")
    # Sign extension to256 exactly matches Solidity abi.encode(int64).
    return encode(REPORT_ABI, (keccak256(b"6529STREAM_PERCEPTUAL_REPORT_V1"), context,
                  definition, threshold, [s % (1 << 256) for s in scores], evaluated_at))


def measure(manifest, environment, pairs):
    """Join both exact PNGs/environment to declared source context, then measure each."""
    if set(manifest) != {"contextHash", "environmentHash", "threshold", "evaluatedAt", "captures"}:
        raise ValueError("closed report input")
    if keccak256(environment) != manifest["environmentHash"] or len(pairs) != len(manifest["captures"]) or not 1 <= len(pairs) <= 2:
        raise ValueError("environment/sample join")
    scores, outcomes = [], []
    for row, (first, second) in zip(manifest["captures"], pairs):
        if set(row) != {"firstSha256", "secondSha256", "width", "height"}:
            raise ValueError("closed capture input")
        if ["0x" + hashlib.sha256(v).hexdigest() for v in (first, second)] != [row["firstSha256"], row["secondSha256"]]:
            raise ValueError("original capture bytes")
        value = score(first, second, row["width"], row["height"])
        scores.append(value)
        outcomes.append("MATCH" if first == second else "TOLERABLE_VARIANCE" if value >= manifest["threshold"] else "DIVERGENT")
    definition = metric()
    encoded = report_preimage(manifest["contextHash"], definition, manifest["threshold"], scores, manifest["evaluatedAt"])
    return {"metric": list(definition), "metricDocumentABI": "0x" + encode((METRIC_ABI,), (definition,)).hex(),
            "parameters": PARAMETERS, "inputs": manifest, "scores": scores, "outcomes": outcomes,
            "reportPreimageABI": "0x" + encoded.hex(), "reportHash": keccak256(encoded),
            "publishableThreshold": all(s >= manifest["threshold"] for s in scores),
            "qualification": "Measured supplied bytes; context/source/RPC and browser execution are not authenticated by this tool."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--environment", type=Path, required=True)
    parser.add_argument("--pair", nargs=2, action="append", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    value = measure(json.loads(args.manifest.read_bytes()), args.environment.read_bytes(),
                    [(a.read_bytes(), b.read_bytes()) for a, b in args.pair])
    with args.output.open("xb") as handle:
        handle.write(canonical(value) + b"\n")


if __name__ == "__main__":
    main()
