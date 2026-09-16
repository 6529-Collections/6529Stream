"""Reproduce test-only Safe bytecode fixtures from integrity-pinned official packages.

Run explicitly when changing fixtures, not during ordinary offline Foundry tests.
No package installation, external execution, or filesystem tar extraction occurs.
"""

import base64
import hashlib
import io
import json
from pathlib import Path
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "test/fixtures/safe"
PACKAGES = (
    ("@gnosis.pm/safe-contracts", "1.3.0", "186a21a74b327f17fc41217a927dea7064f74604",
     "1p+1HwGvxGUVzVkFjNzglwHrLNA67U/axP0Ct85FzzH8yhGJb4t9jDjPYocVMzLorDoWAfKicGy1akPY9jXRVw=="),
    ("@safe-global/safe-contracts", "1.4.1", "bf943f80fec5ac647159d26161446ac5d716a294",
     "fP1jewywSwsIniM04NsqPyVRFKPMAuirC3ftA/TA4X3Zc5EnwQp/UCJUU2PL/37/z/jMo8UUaJ+pnFNWmMU7dQ=="),
    ("@safe-global/safe-smart-account", "1.5.0", "dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be",
     "VIMWxoeY/kNuZVsQVvAeOFKcQS3eojCXg0ecGnesBSLn5ypYshmBhVEEU5XiurJJGTs/MrcoLTbTxhs9W9GvdQ=="),
)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for package, version, commit, integrity in PACKAGES:
        basename = package.split("/")[1]
        url = f"https://registry.npmjs.org/{package}/-/{basename}-{version}.tgz"
        with urllib.request.urlopen(url, timeout=60) as response:
            raw = response.read(32 * 1024 * 1024 + 1)
        if len(raw) > 32 * 1024 * 1024:
            raise ValueError("Package exceeds size bound")
        if base64.b64encode(hashlib.sha512(raw).digest()).decode() != integrity:
            raise ValueError(f"Package integrity mismatch: {version}")
        names = {
            "singleton": "GnosisSafe" if version == "1.3.0" else "Safe",
            "factory": "GnosisSafeProxyFactory" if version == "1.3.0" else "SafeProxyFactory",
            "handler": "CompatibilityFallbackHandler",
            "multiSend": "MultiSendCallOnly",
            "signMessage": "SignMessageLib",
        }
        result = {
            "version": version, "package": package, "packageUrl": url,
            "packageIntegrity": "sha512-" + integrity, "sourceCommit": commit,
            "sourceUrl": f"https://github.com/safe-fndn/safe-smart-account/tree/{commit}",
        }
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as archive:
            for key, name in names.items():
                matches = [m for m in archive.getmembers()
                           if m.name.startswith("package/build/artifacts/contracts/")
                           and m.name.endswith(f"/{name}.json")]
                if len(matches) != 1:
                    raise ValueError(f"Expected one artifact for {name}")
                artifact = json.load(archive.extractfile(matches[0]))
                if artifact["linkReferences"] or artifact["deployedLinkReferences"]:
                    raise ValueError("Unexpected linked artifact")
                creation = bytes.fromhex(artifact["bytecode"][2:])
                runtime = bytes.fromhex(artifact["deployedBytecode"][2:])
                if not creation or not runtime:
                    raise ValueError("Empty artifact")
                result[key] = {
                    "artifactPath": matches[0].name,
                    "creationCode": artifact["bytecode"],
                    "runtimeCode": artifact["deployedBytecode"],
                    "creationSHA256": hashlib.sha256(creation).hexdigest(),
                    "runtimeSHA256": hashlib.sha256(runtime).hexdigest(),
                }
            (DEST / f"LICENSE-{version}").write_bytes(archive.extractfile("package/LICENSE").read())
        path = DEST / f"{version}.json"
        path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"Verified and wrote Safe {version}: five official artifacts")


if __name__ == "__main__":
    main()
