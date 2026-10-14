"""Host-only rejection coverage for independent retained-evidence reads."""
# Shared companions: scripts/ci/failure_evidence.py
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from failure_evidence import regular_evidence_archive, verify_compact_tools


class EvidenceTests(unittest.TestCase):
    def test_required_reads_and_unsafe_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "evidence.tar.gz"
            for kind in ("valid", "duplicate", "absolute", "parent", "alias", "link", "mode"):
                with tarfile.open(path, "w:gz") as archive:
                    name = {"absolute": "/input", "parent": "../input", "alias": "././input"}.get(kind, "input")
                    member = tarfile.TarInfo(name); member.size = 5; member.mode = 0o640
                    if kind == "mode": member.mode = 0o644
                    if kind == "link": member.type = tarfile.SYMTYPE; member.linkname = "outside"; member.size = 0
                    archive.addfile(member, io.BytesIO(b"bytes") if member.isfile() else None)
                    if kind == "duplicate": archive.addfile(member, io.BytesIO(b"bytes"))
                if kind == "valid":
                    with regular_evidence_archive(path) as (_, read): self.assertEqual(read("input", 0o640), b"bytes")
                else:
                    with self.assertRaises(ValueError):
                        with regular_evidence_archive(path) as (_, read): read("input", 0o640)
            with regular_evidence_archive(path) as (_, read):
                with self.assertRaises(ValueError): read("missing")

    def test_compact_tool_receipts(self):
        root = Path(__file__).resolve().parents[2]
        pins = (root / "ci/ic-tools.tsv").read_bytes()
        tool_pins = {"host": b"caller host pins\n", "ic": pins}
        files = {}
        for kind in ("host", "ic"):
            prefix = f"tool-evidence/{kind}/"
            files[prefix + "caller-pins"] = tool_pins[kind]
            files[prefix + "check.log"] = b"fresh check\n"
            files[prefix + "selection.txt"] = f"/consumer/.tools/{kind}-set.ABC123\n".encode()
        files["tool-evidence/ic/pins.tsv"] = pins
        files["tool-evidence/ic/host"] = b"linux-x86_64\n"
        files["tool-evidence/ic/files.sha256"] = b"nonempty receipt\n"
        def read(name):
            if name not in files: raise ValueError("missing required file")
            return files[name]
        verify_compact_tools({}, read, tool_pins, "Linux/X64")
        for name, replacement in (
            ("tool-evidence/ic/caller-pins", b"different"),
            ("tool-evidence/ic/pins.tsv", b"malformed"),
            ("tool-evidence/ic/host", b"darwin-arm64\n"),
            ("tool-evidence/host/check.log", b""),
            ("tool-evidence/ic/selection.txt", b"invalid"),
        ):
            saved = files[name]; files[name] = replacement
            with self.assertRaises(ValueError): verify_compact_tools({}, read, tool_pins, "Linux/X64")
            files[name] = saved
        with self.assertRaises(ValueError):
            verify_compact_tools({".tools/ic-set.ABC123/bin/wasm-opt": None}, read, tool_pins, "Linux/X64")


if __name__ == "__main__": unittest.main()
