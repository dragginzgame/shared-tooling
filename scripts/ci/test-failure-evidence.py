"""Host-only rejection coverage for independent retained-evidence reads."""
# Shared companions: scripts/ci/failure_evidence.py
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from failure_evidence import (regular_evidence_archive, verify_compact_tools,
                              verify_hosted_scenario)


class EvidenceTests(unittest.TestCase):
    def test_required_reads_and_unsafe_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "evidence.tar.gz"
            for kind in ("valid", "duplicate", "alias-duplicate", "absolute", "parent", "prefixed-parent",
                         "dot", "separator", "alias", "link", "mode"):
                with tarfile.open(path, "w:gz") as archive:
                    name = {"absolute": "/input", "parent": "../input", "prefixed-parent": "./../input",
                            "dot": "inside/./input", "separator": "inside//input",
                            "alias": "././input"}.get(kind, "input")
                    member = tarfile.TarInfo(name); member.size = 5; member.mode = 0o640
                    if kind == "mode": member.mode = 0o644
                    if kind == "link": member.type = tarfile.SYMTYPE; member.linkname = "outside"; member.size = 0
                    archive.addfile(member, io.BytesIO(b"bytes") if member.isfile() else None)
                    if kind == "duplicate": archive.addfile(member, io.BytesIO(b"bytes"))
                    if kind == "alias-duplicate":
                        member.name = "./input"
                        archive.addfile(member, io.BytesIO(b"bytes"))
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
        first = next(line for line in pins.splitlines() if line and not line.startswith(b"#"))
        fields = first.split(b"\t")
        other_version = b"\t".join((fields[0], b"999.0.0", fields[2], fields[3]))
        other_digest = b"\t".join((*fields[:3], b"1" * 64 if fields[3] != b"1" * 64 else b"2" * 64))
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
            ("tool-evidence/host/caller-pins", b"different"),
            ("tool-evidence/ic/pins.tsv", b"malformed"),
            ("tool-evidence/ic/pins.tsv", pins.replace(first, other_version, 1)),
            ("tool-evidence/ic/pins.tsv", pins.replace(first, other_digest, 1)),
            ("tool-evidence/ic/pins.tsv", pins + first + b"\n"),
            ("tool-evidence/ic/host", b"darwin-arm64\n"),
            ("tool-evidence/host/check.log", b""),
            ("tool-evidence/ic/check.log", b""),
            ("tool-evidence/ic/files.sha256", b""),
            ("tool-evidence/host/selection.txt", b"/consumer/.tools/host-set.ABC123\n\n"),
            ("tool-evidence/ic/selection.txt", b"invalid"),
        ):
            saved = files[name]; files[name] = replacement
            with self.assertRaises(ValueError): verify_compact_tools({}, read, tool_pins, "Linux/X64")
            files[name] = saved
        # Receipt comments/order do not change its admitted selection.
        saved = files["tool-evidence/ic/pins.tsv"]
        files["tool-evidence/ic/pins.tsv"] = b"# installation receipt\n" + b"\n".join(reversed(pins.splitlines())) + b"\n"
        verify_compact_tools({}, read, tool_pins, "Linux/X64")
        files["tool-evidence/ic/pins.tsv"] = saved
        for kind in ("host", "ic"):
            with self.assertRaises(ValueError):
                verify_compact_tools({f".tools/{kind}-set.ABC123/bin/tool": None}, read, tool_pins, "Linux/X64")
        for name in list(files):
            saved = files.pop(name)
            with self.assertRaises(ValueError): verify_compact_tools({}, read, tool_pins, "Linux/X64")
            files[name] = saved



    def test_hosted_scenarios(self):
        # Literal expectations are independent of the shell producer. Alternate
        # prefixes (including regex characters) remain caller-owned selections.
        for stage in ("early", "late"):
            parent, logs = "consumer fixtures/[selected]", "consumer logs/validation"
            scenario = f"{parent}/hosted-{stage}.ABC123"
            marker = (b"error: controlled early installer download failure\n" if stage == "early"
                      else b"error: controlled late validation failure\n")
            status = 22 if stage == "early" else 2
            files = {
                scenario + "/status.txt": (f"stage={stage}\nstatus={status}\nexpected={status}\n".encode(), 0o644),
                scenario + "/scenario.log": (marker, 0o644),
            }
            for name in ("before.txt", "after.txt", "consumer/input.txt"):
                files[scenario + "/" + name] = (f"controlled {stage} input\n".encode(), 0o640)
            if stage == "early":
                payload = scenario + "/tool-store/host-" + "0" * 64 + "/set.ABC123/bin/jq"
                files[payload] = (b"controlled rejected download bytes\n", 0o644)
            else:
                payload = logs + "/latest-combined.log"
                files[payload] = (b"batch\n" + marker, 0o644)
                files[logs + "/latest.log"] = (marker, 0o644)
            with tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / "evidence.tar.gz"

                def verify(entries, selected=stage, prefixes=(parent, logs), link=None):
                    with tarfile.open(path, "w:gz") as archive:
                        for name, (data, mode) in entries.items():
                            member = tarfile.TarInfo(name)
                            member.size, member.mode = len(data), mode
                            archive.addfile(member, io.BytesIO(data))
                        if link is not None:
                            member = tarfile.TarInfo(link)
                            member.type, member.linkname = tarfile.SYMTYPE, "outside"
                            archive.addfile(member)
                    with regular_evidence_archive(path) as (members, read):
                        verify_hosted_scenario(members, read, selected,
                                               scenario_parent=prefixes[0],
                                               failure_log_root=prefixes[1])

                verify(files)
                verify({"./" + name: value for name, value in files.items()})
                for invalid in ("", "other", "early\n", "late\n"):
                    with self.subTest(stage=stage, invalid=invalid), self.assertRaises(ValueError):
                        verify(files, selected=invalid)
                for index in (0, 1):
                    for invalid in ("", "/absolute", "../outside", "inside/./alias", "inside//alias", "trailing/"):
                        prefixes = [parent, logs]
                        prefixes[index] = invalid
                        with self.subTest(prefix=invalid, index=index), self.assertRaises(ValueError):
                            verify(files, prefixes=prefixes)
                with self.assertRaises(ValueError):
                    verify(files, selected="late" if stage == "early" else "early")
                other = scenario.replace("ABC123", "DEF456") + "/status.txt"
                with self.assertRaises(ValueError):
                    verify(dict(files, **{other: files[scenario + "/status.txt"]}))
                for name in files:
                    missing = {key: value for key, value in files.items() if key != name}
                    with self.subTest(missing=name), self.assertRaises(ValueError):
                        verify(missing)
                    with self.subTest(link=name), self.assertRaises(ValueError):
                        verify(missing, link=name)
                for name, replacement in (
                    (scenario + "/after.txt", (b"changed\n", 0o640)),
                    (scenario + "/before.txt", (f"controlled {stage} input\n".encode(), 0o644)),
                    (scenario + "/status.txt", (b"status=0\n", 0o644)),
                    (scenario + "/scenario.log", (b"unrelated setup outage\n", 0o644)),
                    (payload, (b"damaged retained bytes\n", 0o644)),
                ):
                    with self.subTest(corrupt=name), self.assertRaises(ValueError):
                        verify(dict(files, **{name: replacement}))
                if stage == "early":
                    for wrong in (
                        scenario + "/consumer/.tools/host-set.ABC123/bin/jq",
                        payload.replace("0" * 64, "invalid"),
                        payload.replace("set.ABC123", "set.invalid-name"),
                    ):
                        entries = {key: value for key, value in files.items() if key != payload}
                        entries[wrong] = files[payload]
                        with self.subTest(candidate=wrong), self.assertRaises(ValueError):
                            verify(entries)
                    with self.assertRaises(ValueError):
                        verify(dict(files, **{payload.replace("set.ABC123", "set.DEF456"): files[payload]}))
                else:
                    # A marker substring is insufficient in the retained raw log.
                    bad_raw = b"prefix " + marker
                    with self.assertRaises(ValueError):
                        verify(dict(files, **{logs + "/latest.log": (bad_raw, 0o644),
                                              payload: (bad_raw, 0o644)}))

if __name__ == "__main__": unittest.main()
