#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:?Pass a Rust macOS target}"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
export MACOSX_DEPLOYMENT_TARGET=14.2
export NEXT_TELEMETRY_DISABLED=1
export PNPM_CONFIG_ENABLE_GLOBAL_VIRTUAL_STORE=false
# A verified artifact may be reused only from this trusted release workflow,
# with byte-identical application inputs. Packaging-only fixes need not recompile it.
if [[ "$TARGET" == "x86_64-apple-darwin" && -n "${ULTRA_REUSE_INTEL_RUN:-}" ]]; then
  [[ "$ULTRA_REUSE_INTEL_RUN" =~ ^[0-9]+$ ]] || { echo 'Invalid artifact run'; exit 1; }
  IFS=$'\t' read -r SOURCE_SHA SOURCE_WORKFLOW SOURCE_EVENT SOURCE_BRANCH SOURCE_ACTOR < <(
    gh api "repos/$GITHUB_REPOSITORY/actions/runs/$ULTRA_REUSE_INTEL_RUN" --jq '[.head_sha,.path,.event,.head_branch,.actor.login] | @tsv'
  )
  [[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ && "$SOURCE_WORKFLOW" == '.github/workflows/ultra-release.yml' && "$SOURCE_EVENT" == 'workflow_dispatch' && "$SOURCE_BRANCH" == 'codex/meetily-ultra' && "$SOURCE_ACTOR" == "$GITHUB_REPOSITORY_OWNER" ]] || { echo 'Untrusted artifact source'; exit 1; }
  git fetch --no-tags --depth=1 origin "$SOURCE_SHA"
  git diff --exit-code "$SOURCE_SHA" HEAD -- frontend/src frontend/public frontend/src-tauri Cargo.toml Cargo.lock llama-helper frontend/package.json frontend/pnpm-lock.yaml THIRD_PARTY_NOTICES.md LICENSE.md ':(exclude)frontend/src-tauri/windows/**'
  mkdir -p dist-ultra
  gh run download "$ULTRA_REUSE_INTEL_RUN" --repo "$GITHUB_REPOSITORY" --name ultra-macos-x64 --dir dist-ultra
  (cd dist-ultra && shasum -a 256 --check *.sha256)
  SOURCE_DMG=$(find dist-ultra -maxdepth 1 -name '*macos-x64.dmg' -print -quit)
  test -n "$SOURCE_DMG"
  MOUNT_POINT=$(mktemp -d)
  hdiutil attach "$SOURCE_DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT"
  trap 'hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true; rmdir "$MOUNT_POINT" || true' EXIT
  mkdir -p "target/$TARGET/release/bundle/macos" "target/$TARGET/release/bundle/dmg"
  ditto "$MOUNT_POINT/Meetily Ultra.app" "target/$TARGET/release/bundle/macos/Meetily Ultra.app"
  hdiutil detach "$MOUNT_POINT"
  rmdir "$MOUNT_POINT"
  trap - EXIT
  cp "$SOURCE_DMG" "target/$TARGET/release/bundle/dmg/Meetily-Ultra.dmg"
  python3 frontend/scripts/verify-ultra-release.py macos "$TARGET"
  echo "Verified Intel artifact reused from run $ULTRA_REUSE_INTEL_RUN ($SOURCE_SHA); application inputs identical"
  exit 0
fi
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
# Tests have finished. Preserve app/binaries, but reclaim intermediate Rust outputs
# before copying the bundle and creating a second filesystem image on small runners.
python3 frontend/scripts/cleanup-ultra-macos-build.py "$TARGET"
df -h .
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -cR "$APP" "$STAGING/Meetily Ultra.app" || ditto "$APP" "$STAGING/Meetily Ultra.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p "target/$TARGET/release/bundle/dmg"
hdiutil create -volname "Meetily Ultra" -srcfolder "$STAGING" -ov -format UDZO "target/$TARGET/release/bundle/dmg/Meetily-Ultra.dmg"
python3 frontend/scripts/verify-ultra-release.py macos "$TARGET"
