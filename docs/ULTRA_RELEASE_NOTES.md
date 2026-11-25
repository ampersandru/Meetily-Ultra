Meetily Ultra continues ActuallyFree PR38 with its own app identity and logo.

- Near-live captions, word-level seeking, screenshots placed within the transcript, YouTube import and post-call translations.
- Voice Profiles settings, adjustable matching threshold, possible-match review, sample-learning controls and configurable profile capacity (0 = unlimited).
- Optional AI-summary speaker names marked **AI · unsaved**, with explicit review before saving.
- Improved speaker edits, meeting previews, transcript layout and recording stability.

**Downloads:** Windows x64 CPU setup, Windows NVIDIA CUDA setup, macOS Apple Silicon DMG, and macOS Intel DMG. macOS requires 14.2 or later. SHA256SUMS.txt covers all installers. CUDA targets RTX 20/30/40/50 and Ampere SM80 with a current CUDA 13-compatible NVIDIA driver. The Windows built-in local AI helper requires AVX2.

Windows installers are unsigned. macOS apps are ad-hoc signed and not Developer ID notarized; use Privacy & Security → Open Anyway if macOS blocks the app. Ultra installs separately and does not move or delete ActuallyFree data. This release uses manual Ultra downloads rather than the upstream automatic updater.

Local models keep meeting content on-device; optional cloud providers receive the content they process. Voice and AI name matches are unverified suggestions.

Based on ActuallyFree PR38 at eb7ba469817706fb562ea900bdff0484a010419e. Thanks to Tyler Buza, Zackriya Solutions and all upstream contributors. MIT project license; third-party models and runtimes retain their own notices.

Windows CPU and CUDA installers each passed 423 native tests (13 opt-in tests ignored), exact archive/payload and Microsoft runtime compatibility verification, and sidecar smoke tests. Both Whisper and the local AI helper have CUDA enabled in the NVIDIA build. These checks do not benchmark transcription/voice-match accuracy or replace physical capture testing on each target computer.
