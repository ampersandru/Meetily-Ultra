<div align="center">
  <img src="docs/ultra-banner.svg" alt="Meetily Ultra — Your meetings. Your models. Your data." width="760" />
  <p><strong>A free, local-first meeting assistant built from ActuallyFree PR38.</strong></p>
  <p><a href="https://github.com/ampersandru/Meetily-Ultra/releases">Download for Windows and macOS</a> · <a href="#whats-new-over-the-actuallyfree-base">Features</a> · <a href="#build-from-source">Build</a> · <a href="LICENSE.md">MIT license</a></p>
</div>

Meetily Ultra records microphone and computer audio, transcribes meetings, labels speakers, and generates AI summaries. It continues the work in [ActuallyFree PR38](https://github.com/TylerBuza/Meetily-ActuallyFree/pull/38), with its own branding, application identity and releases. No subscription or feature paywall.

## What's new over the ActuallyFree base

These are the PR38 additions relative to its ActuallyFree base (`9d19667`), rather than a claim that every feature is absent from later ActuallyFree releases.

| Area | What Ultra adds |
| --- | --- |
| Live captions | Near-live Parakeet previews, independent microphone/computer captions, and more resilient recording and transcript updates. |
| Playback | Word timestamps, click-to-seek, active-word highlighting, and waveform scrubbing. |
| Speaker editing | Rename speakers across overlapping labels; correct one line, all lines, or speech from a chosen point onward. |
| Voice profiles | A dedicated settings category; opt-in beta recognition, adjustable match threshold, “Maybe [name]?” review, automatic clear-sample updates, Learn more turns and Learn all. Profile capacity defaults to 50; set 0 for unlimited. |
| AI name suggestions | Optional Summaries setting displays guesses such as “Tony (Speaker 7)” with **AI · unsaved**. Original transcript labels remain unchanged until you review and save a name. |
| Screenshots and images | Capture from Notes or the recording bar, or paste images. Pictures appear at their capture time, including inside a long speaker turn. |
| Translation | Post-call transcript translation, including English, with bilingual, translated-only and original-only views. |
| More sources | YouTube transcription with synchronized video, audio/video imports, and experimental watched folders. |
| Transcript controls | Clean Transcript and waveform scrubbing default on; optional display-line duration; left-aligned names and independent speaker dots. |
| Meeting tools | Rich meeting previews, notes, action items, and a choice to retain recordings or delete their folders when removing meetings. |

Some features remain under **Labs**. Voice matching and AI name suggestions are uncertain; review them before saving an identity. Speaker detection does not separate overlapping voices into independent audio tracks.

## Download and install

Get installers from [Meetily Ultra releases](https://github.com/ampersandru/Meetily-Ultra/releases).

| Platform | File | Requirements |
| --- | --- | --- |
| Windows | `Meetily-Ultra_0.3.0_windows-x64-setup.exe` | Windows 10/11 x64; CPU transcription, bundled local AI/audio runtimes and Visual C++ installer. |
| Windows, NVIDIA CUDA | `Meetily-Ultra_0.3.0_windows-x64-cuda-setup.exe` | NVIDIA RTX 20/30/40/50 series or Ampere SM80 GPU, with a current CUDA 13-compatible driver. |
| macOS, Apple Silicon | `Meetily-Ultra_0.3.0_macos-arm64.dmg` | macOS 14.2 or newer; Apple Silicon. |
| macOS, Intel | `Meetily-Ultra_0.3.0_macos-x64.dmg` | macOS 14.2 or newer; Intel processor. |

Windows builds are unsigned. macOS builds are ad-hoc signed, not Apple Developer ID notarized; macOS may require you to approve the app under **System Settings → Privacy & Security → Open Anyway** after attempting to open it. Mount the DMG and drag **Meetily Ultra** into Applications. Grant microphone and system-audio recording permissions when prompted. Each release includes SHA-256 checksums.

Ultra installs separately from ActuallyFree. macOS stores Ultra data in `~/Library/Application Support/Meetily Ultra`; Windows uses its own install folder's `data` directory, falling back to the OS data directory under `Meetily Ultra`. Existing ActuallyFree recordings are not moved or deleted. You can import saved recordings into Ultra. The first release uses manual downloads from the Ultra release page; automatic upstream updates are disabled.

## Privacy and models

Local transcription and local summaries run on your machine after downloading their models. You can optionally configure cloud providers; doing so sends the relevant meeting content to that provider. Model downloads, update downloads and optional YouTube imports use the network. Choose local models if you need meeting content to remain on-device. Review [the privacy policy](PRIVACY_POLICY.md) and obtain appropriate participant consent before recording.

Windows has separate CPU and NVIDIA CUDA installers. CUDA builds accelerate Whisper and the local AI helper; use the CPU installer on machines without a supported NVIDIA GPU. Choose one Windows installer; changing backends keeps Ultra data. Vulkan is available for source builds but is not a separate installer in this release. The macOS builds use the platform's supported Metal/CoreML paths; model and hardware support vary.

## Build from source

```sh
git clone --branch codex/meetily-ultra https://github.com/ampersandru/Meetily-Ultra.git
cd Meetily-Ultra/frontend
pnpm install --frozen-lockfile
```

Use Node.js 24, pnpm 11.9.0, Rust 1.97.1 or newer, and your platform's native compiler. Windows needs Visual Studio C++ Build Tools, CMake/Ninja and LLVM; macOS needs Xcode command-line tools and OpenSSL 3 headers. Build instructions and verification are in [docs/ULTRA_RELEASE.md](docs/ULTRA_RELEASE.md). The **Release Meetily Ultra** workflow builds, verifies and publishes all three installers together.

The recording/transcription architecture and feature qualification notes are mapped in [docs/DEVELOPMENT_MAP.md](docs/DEVELOPMENT_MAP.md).

## Credits and license

Ultra is maintained by [ampersandru](https://github.com/ampersandru). It is based on [Meetily — ActuallyFree by Tyler Buza](https://github.com/TylerBuza/Meetily-ActuallyFree) and [the original Meetily project by Zackriya Solutions](https://github.com/Zackriya-Solutions/meetily). Original copyright and license notices are retained. Ultra is an independent community fork, not an official upstream product.

See [LICENSE.md](LICENSE.md) and the bundled third-party model/runtime notices. Model downloads remain hosted by their existing providers and retain their own licenses.
