#!/usr/bin/env python3
"""Generate a one-time Ed25519 keypair for Conor's Sparkle update feed.

Run locally with: python3 scripts/generate_sparkle_keys.py
Keep the private key only in GitHub Actions secrets. Never commit it.
"""
import base64
import secrets

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
except ImportError as exc:
    raise SystemExit("Install cryptography first: python3 -m pip install cryptography") from exc

seed = secrets.token_bytes(32)
private_key = Ed25519PrivateKey.from_private_bytes(seed)
public_key = private_key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
print("SPARKLE_PUBLIC_ED_KEY=" + base64.b64encode(public_key).decode("ascii"))
print("SPARKLE_EDDSA_PRIVATE_KEY=" + base64.b64encode(seed).decode("ascii"))
