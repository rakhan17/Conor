# Secure in-app updates

Conor uses Sparkle 2 for signed macOS updates. Sparkle verifies each update archive with an Ed25519 signature before installation. The private key must never be committed to this repository.

## One-time key setup

1. On your own Mac, install the Python cryptography package:

   ```bash
   python3 -m pip install cryptography
   ```

2. From a clone of this repository, run:

   ```bash
   python3 scripts/generate_sparkle_keys.py
   ```

3. The script prints two values. In GitHub, open **Settings → Secrets and variables → Actions**:
   - Add a **repository variable** named `SPARKLE_PUBLIC_ED_KEY` and paste the public key.
   - Add a **repository secret** named `SPARKLE_EDDSA_PRIVATE_KEY` and paste the private key.
4. Keep the private key in the GitHub secret only. Do not paste it into issues, chat, source files, or commits.
5. Trigger a new tagged release after configuring both values. The release workflow embeds the public key in the app, signs the update ZIP using the private key, and publishes `appcast.xml` as a release asset.

## Release behavior

- The app checks the signed feed at `https://github.com/rakhan17/Conor/releases/latest/download/appcast.xml`.
- Automatic checks run daily. Sparkle handles downloading, signature verification, and installation inside the app.
- The regular DMG remains available as a first-install option.
- If the keys are not configured, the workflow still publishes the DMG, but secure in-app updates remain unavailable. The Settings tab displays this state.

## Key rotation

Do not regenerate the keys casually. Existing installed builds trust the public key embedded in their app bundle. Replacing the key requires a planned key-rotation release so existing installations can continue to verify updates.
