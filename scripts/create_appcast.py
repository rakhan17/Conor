#!/usr/bin/env python3
"""Create a signed Sparkle appcast item for a Conor ZIP release."""
import argparse
import base64
import email.utils
import os
from pathlib import Path
from xml.sax.saxutils import escape

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

parser = argparse.ArgumentParser()
parser.add_argument("--archive", required=True)
parser.add_argument("--version", required=True)
parser.add_argument("--build", required=True)
parser.add_argument("--tag", required=True)
parser.add_argument("--private-key", default=os.environ.get("SPARKLE_EDDSA_PRIVATE_KEY", ""))
parser.add_argument("--output", required=True)
args = parser.parse_args()

if not args.private_key:
    raise SystemExit("SPARKLE_EDDSA_PRIVATE_KEY is not configured")
seed = base64.b64decode(args.private_key, validate=True)
if len(seed) != 32:
    raise SystemExit("The Sparkle private key must be a base64-encoded 32-byte Ed25519 seed")

archive = Path(args.archive)
payload = archive.read_bytes()
signature = Ed25519PrivateKey.from_private_bytes(seed).sign(payload)
signature_b64 = base64.b64encode(signature).decode("ascii")
size = len(payload)
url = f"https://github.com/rakhan17/Conor/releases/download/{escape(args.tag)}/{archive.name}"
pub_date = email.utils.formatdate(usegmt=True)

feed = f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Conor Updates</title>
    <link>https://github.com/rakhan17/Conor/releases</link>
    <description>Conor macOS application updates</description>
    <language>en</language>
    <item>
      <title>Conor {escape(args.version)}</title>
      <pubDate>{pub_date}</pubDate>
      <sparkle:version>{escape(args.build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(args.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="{url}" sparkle:edSignature="{signature_b64}" length="{size}" type="application/octet-stream" />
    </item>
  </channel>
</rss>
'''
Path(args.output).write_text(feed, encoding="utf-8")
print(f"Signed appcast created: {args.output} ({size} bytes)")
