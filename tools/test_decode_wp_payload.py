#!/usr/bin/env python3
"""Focused tests for decode_wp_payload.py."""

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import decode_wp_payload as decoder


DEFAULT_HEADER = bytes.fromhex(
    "FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00 1E 00"
)


class DecodeWpPayloadTest(unittest.TestCase):
    def run_decoder(self, data: bytes, *args: str) -> tuple[int, str, str]:
        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            tmp.write(data)
            tmp_path = Path(tmp.name)
        stdout = io.StringIO()
        stderr = io.StringIO()
        try:
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                rc = decoder.main([str(tmp_path), *args])
        finally:
            tmp_path.unlink()
        return rc, stdout.getvalue(), stderr.getvalue()

    def test_parse_default_native_header(self) -> None:
        payload = DEFAULT_HEADER + b"abc"
        header = decoder.parse_native_header(payload)

        self.assertIsNotNone(header)
        assert header is not None
        self.assertEqual(header.length, 0x10)
        self.assertEqual(header.body_offset, 0x12)
        self.assertEqual(header.words, (0x003C, 0x0186, 0x0186, 0x01C2, 0x0084, 0x000C, 0x0076))
        self.assertEqual(header.tabs, (0x001E,))
        self.assertEqual(header.warnings, ())

    def test_malformed_native_header_warnings(self) -> None:
        cases = (
            (
                bytes.fromhex("FF 0C 3C 00 86 01 86 01 C2 01 84 00 0C 00"),
                "header length is below the ROM serializer minimum 0x0E",
            ),
            (
                bytes.fromhex("FF 0F 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00 1E"),
                "tab-stop tail length is odd",
            ),
            (
                bytes.fromhex(
                    "FF 30 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00"
                    " 1E 00 3C 00 5A 00 78 00 96 00 B4 00 D2 00 F0 00"
                    " 0E 01 2C 01 4A 01 68 01 86 01 A4 01 C2 01 E0 01 FE 01"
                ),
                "header length exceeds the ROM serializer maximum 0x2E",
            ),
            (bytes.fromhex("FF 0E 3C 00 86 01"), "fixed seven-word header is truncated"),
            (
                bytes.fromhex("FF 10 3C 00 86 01 86 01 C2 01 84 00 0C 00 76 00 80 80"),
                "tab stop 0 has the runtime sentinel high bit set",
            ),
        )

        for payload, warning in cases:
            with self.subTest(warning=warning):
                header = decoder.parse_native_header(payload)

                self.assertIsNotNone(header)
                assert header is not None
                self.assertIn(warning, header.warnings)

    def test_strict_native_malformed_header_fails(self) -> None:
        rc, stdout, stderr = self.run_decoder(
            bytes.fromhex("FF 0E 3C 00 86 01"),
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 1)
        self.assertIn("payload ends before the declared header length", stdout)
        self.assertEqual(stderr, "")

    def test_legacy_plain_normalization(self) -> None:
        plain = b"A\r\nB\tC\x01\xE0D\nE"

        self.assertEqual(
            decoder.normalize_legacy_plain(plain, expand_tabs=False),
            bytes.fromhex("41 0C 42 09 43 44 0C 45"),
        )
        self.assertEqual(
            decoder.normalize_legacy_plain(plain, expand_tabs=True),
            bytes.fromhex("41 0C 42 20 20 20 20 20 20 20 43 44 0C 45"),
        )

    def test_strict_native_valid_record_passes(self) -> None:
        rc, stdout, stderr = self.run_decoder(
            DEFAULT_HEADER + bytes.fromhex("E9 02 0C 00 E9"),
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 0, stderr)
        self.assertIn("E9 subtype=0x02", stdout)

    def test_strict_native_all_fixed_records_pass(self) -> None:
        body = bytes.fromhex(
            "E8 1E 00 00 00 E8"
            " E9 02 0C 00 E9"
            " EC 02 04 EC"
            " ED 02 03 ED"
            " EE 12 00 00 00 EE"
            " EF 06 78 00 FE FF EF"
            " 61"
        )
        rc, stdout, stderr = self.run_decoder(
            DEFAULT_HEADER + body,
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 0, stderr)
        self.assertIn("E8 word_a=0x001E word_b=0x0000", stdout)
        self.assertIn("E9 subtype=0x02", stdout)
        self.assertIn("EC old=0x02 (10) new=0x04 (12)", stdout)
        self.assertIn("ED old=0x02 (1 line) new=0x03 (1 1/2 lines)", stdout)
        self.assertIn("EE word_a=0x0012 word_b=0x0000", stdout)
        self.assertIn("EF subtype=0x06", stdout)
        self.assertIn("0x0032: 61", stdout)

    def test_strict_native_bad_closing_marker_fails(self) -> None:
        rc, stdout, _ = self.run_decoder(
            DEFAULT_HEADER + bytes.fromhex("E9 02 0C 00 00"),
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 1)
        self.assertIn("closing marker is 0x00", stdout)

    def test_strict_native_truncated_record_fails(self) -> None:
        rc, stdout, _ = self.run_decoder(
            DEFAULT_HEADER + bytes.fromhex("EE 12 00"),
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 1)
        self.assertIn("truncated range/spacing boundary record", stdout)

    def test_strict_native_bad_ef_sign_extension_fails(self) -> None:
        rc, stdout, _ = self.run_decoder(
            DEFAULT_HEADER + bytes.fromhex("EF 06 78 00 FF 00 EF"),
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 1)
        self.assertIn("sign extension expected 0xFF", stdout)

    def test_strict_native_unknown_e9_subtype_preserves_record(self) -> None:
        rc, stdout, stderr = self.run_decoder(
            DEFAULT_HEADER + bytes.fromhex("E9 20 34 12 E9 61"),
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 0, stderr)
        self.assertIn("E9 subtype=0x20 (unknown subtype) word=0x1234", stdout)
        self.assertIn("0x0017: 61", stdout)

    def test_strict_native_unknown_ef_subtype_preserves_record(self) -> None:
        rc, stdout, stderr = self.run_decoder(
            DEFAULT_HEADER + bytes.fromhex("EF 08 78 00 01 00 EF 61"),
            "--body",
            "--strict",
            "--require-native",
        )

        self.assertEqual(rc, 0, stderr)
        self.assertIn("EF subtype=0x08 (unknown subtype)", stdout)
        self.assertIn("0x0019: 61", stdout)

    def test_require_native_rejects_plain_payload(self) -> None:
        rc, stdout, stderr = self.run_decoder(b"plain\n", "--strict", "--require-native")

        self.assertEqual(rc, 1)
        self.assertIn("native_header: absent", stdout)
        self.assertIn("native FF header required", stderr)

    def test_strict_legacy_preview_passes_without_require_native(self) -> None:
        rc, stdout, stderr = self.run_decoder(b"plain\n", "--strict", "--legacy-preview")

        self.assertEqual(rc, 0, stderr)
        self.assertIn("70 6C 61 69 6E 0C", stdout)


if __name__ == "__main__":
    unittest.main()
