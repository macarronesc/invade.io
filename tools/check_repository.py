#!/usr/bin/env python3
"""Reject credential files/material without ever printing their contents."""
import pathlib
import re
import subprocess
import sys

PRIVATE_KEY = re.compile(rb"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----")
TOKEN = re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{30,255}|github_pat_[A-Za-z0-9_]{40,255}|sntrys_[A-Za-z0-9_+/=-]{30,300})")
FORBIDDEN_SUFFIXES = {".keystore", ".jks", ".p12", ".p8", ".pem", ".key", ".pfx", ".mobileprovision", ".provisionprofile", ".b64"}


def sensitive_path(name):
    path = pathlib.PurePosixPath(name.replace("\\", "/"))
    return (path.suffix.lower() in FORBIDDEN_SUFFIXES
            or path.name in {".env", "export_credentials.cfg", "id_rsa", "id_ed25519", ".netrc", ".npmrc", ".pypirc", "google-services.json", "GoogleService-Info.plist"}
            or path.name.startswith(".env.") and path.name != ".env.example")


def sensitive_content(data):
    # Native TLS libraries can contain PEM parser labels, not actual private keys.
    key = PRIVATE_KEY.search(data) if b"\0" not in data else re.search(
        PRIVATE_KEY.pattern + rb"\s+[A-Za-z0-9+/=\r\n]{80,}-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----", data)
    return bool(key or TOKEN.search(data)
                or re.search(rb'"type"\s*:\s*"service_account"', data)
                or data.startswith((b"\xfe\xed\xfe\xed", b"\xce\xce\xce\xce")))


def main():
    paths = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"]).decode().split("\0")
    bad = []
    for name in sorted(set(filter(None, paths))):
        path = pathlib.Path(name)
        if path.is_file() and (sensitive_path(name) or sensitive_content(path.read_bytes())):
            bad.append(name)
    for name in bad:
        print("Sensitive file/material rejected: " + name, file=sys.stderr)
    print("Repository credential-file check: %d failures" % len(bad))
    return bool(bad)


if __name__ == "__main__":
    sys.exit(main())
