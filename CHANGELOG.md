# Changelog

## 0.2.0 — public beta

- Name the project **iPad Portrait Vibe** and document its portrait iPad + UU Remote + Mac vibe-coding use case.
- Make the application self-contained: recovery records live in user Application Support, not beside the application bundle.
- Build arm64 and x86_64 slices into a universal macOS app; add an app icon, reproducible build/package scripts, and CI packaging.
- Activate an existing app instance rather than opening another one.
- Wait for observed display restoration and guard delayed callbacks against a different switching session.
- Publish Chinese and English instructions, compatibility limits, privacy notes, an MIT license, and archive checksums.

The desktop preset remains 744 × 1134. Native Retina output and additional iPad aspect-ratio presets are future work, not features of this beta.

## Earlier private prototypes

- Established portrait mirroring on the author's M4 MacBook Air.
- Verified manual, timeout, and control-pipe-close restoration locally.
- The author reported successful use with an iPad mini 7 and UU Remote.
