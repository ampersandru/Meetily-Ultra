#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:?Pass a Rust macOS target}"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
export MACOSX_DEPLOYMENT_TARGET=14.2
export NEXT_TELEMETRY_DISABLED=1
export PNPM_CONFIG_ENABLE_GLOBAL_VIRTUAL_STORE=false
OPENSSL_PREFIX=$(brew --prefix openssl@3)
export OPENSSL_DIR="$OPENSSL_PREFIX"
export OPENSSL_ROOT_DIR="$OPENSSL_PREFIX"
export CMAKE_PREFIX_PATH="$OPENSSL_PREFIX"
export CPPFLAGS="-I$OPENSSL_PREFIX/include"
export CFLAGS="-I$OPENSSL_PREFIX/include"
export CXXFLAGS="-I$OPENSSL_PREFIX/include"
export LDFLAGS="-L$OPENSSL_PREFIX/lib"
export PKG_CONFIG_PATH="$OPENSSL_PREFIX/lib/pkgconfig"
cargo build --locked --release -p llama-helper --target "$TARGET" --features metal
mkdir -p frontend/src-tauri/binaries
cp "target/$TARGET/release/llama-helper" "frontend/src-tauri/binaries/llama-helper-$TARGET"
chmod +x "frontend/src-tauri/binaries/llama-helper-$TARGET"
(cd frontend && pnpm exec tauri build --target "$TARGET" --bundles app)
APP="target/$TARGET/release/bundle/macos/Meetily Ultra.app"
python3 frontend/scripts/bundle-ultra-macos-deps.py "$APP"
mkdir -p "$APP/Contents/Resources/licenses"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/licenses/"
for license in "$OPENSSL_PREFIX/LICENSE.txt" "$OPENSSL_PREFIX/share/doc/openssl@3/LICENSE.txt"; do
  if [[ -f "$license" ]]; then cp "$license" "$APP/Contents/Resources/licenses/OpenSSL-LICENSE.txt"; break; fi
done
codesign --force --sign - --timestamp=none --options runtime --entitlements frontend/src-tauri/entitlements.plist "$APP"
codesign --verify --deep --strict "$APP"
cargo test --locked --release -p meetily --lib --target "$TARGET" audio::capture_worker:: -- --test-threads=1
cargo test --locked --release -p meetily --lib --target "$TARGET" audio::pipeline::ring_buffer_tests:: -- --test-threads=1
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Meetily Ultra.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p "target/$TARGET/release/bundle/dmg"
hdiutil create -volname "Meetily Ultra" -srcfolder "$STAGING" -ov -format UDZO "target/$TARGET/release/bundle/dmg/Meetily-Ultra.dmg"
python3 frontend/scripts/verify-ultra-release.py macos "$TARGET"
