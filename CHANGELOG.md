# Changelog

## v0.4.0 — VibeScreen

- Rename the app and repository to **VibeScreen** / `vibe-screen`.
- Describe the purpose as mobile devices controlling a Mac through NetEase UU Remote for Vibe Coding. The author also reports successful use from a phone.
- Update window text, virtual display name, build scripts, downloads, and bilingual documentation.
- Retain the verified Retina 2× preset, confirmation timer, restoration protocol, and background helper Dock fix. The preset is fixed; automatic device sizing is not implemented.
- Keep the existing bundle identifier so the renamed app retains its identity. New local runs use the VibeScreen support folder; existing recovery records are preserved.

## 0.3.1 — Dock fix

- Keep the virtual-display helper out of the Dock, leaving one icon for the main window.
- Mark the bundle as an agent at launch; the normal GUI explicitly promotes itself to a regular application while its helper stays prohibited.


## 0.3.0 — Retina beta

- Fix HiDPI mode construction: use 744 × 1134 desktop dimensions with a 1488 × 2268 maximum framebuffer.
- Select only the exact 2× portrait mode and verify actual framebuffer dimensions before reporting success.
- Keep the existing desktop, window and text size while increasing pixel count fourfold.
- Show Retina 2× status in the app and document the distinction between Mac rendering and UU stream quality.


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
