# Testing and evidence boundaries

## v0.4.0 rename verification

The renamed universal VibeScreen app was built and ad-hoc signature verified on M4 MacBook Air / macOS 26.5. Local checks entered the 744 × 1134-point, 1488 × 2268-pixel Retina mode and restored through a short timeout. The installed GUI also passed switching, confirmation, and manual restoration, with the new VibeScreen display and window names. The display algorithm and helper activation policies were retained from v0.3.1. The original bundle identifier was preserved.

The author reports that remote use is also useful on a phone. This is user feedback, not a newly measured end-to-end phone compatibility test. The fixed portrait preset and existing hardware test limits still apply.

## Previously verified behavior

The private prototype was tested on an M4 MacBook Air running macOS 26.5, using a single built-in display. Checks verified 744 × 1134 portrait geometry and restoration to the previously selected mode, including backing pixels, refresh rate, position, and main-display status. Manual restoration, a short test timeout, control-pipe closure, and actual window-button operation passed. The author subsequently reported successful use with an iPad mini 7 through UU Remote.

These observations apply to the tested setup. They do not prove universal compatibility with other Macs, macOS releases, or remote clients. CI checks compilation, metadata, architectures, and packaging; CI does not reconfigure displays.

## Read-only checks

After building, the executable supports:

```bash
"build/VibeScreen.app/Contents/MacOS/VibeScreen" --probe
"build/VibeScreen.app/Contents/MacOS/VibeScreen" --check-storage
```

`--probe` prints local display information. Treat that output as local diagnostics and review identifiers before sharing it. `--check-storage` creates a new local run folder and reports whether it was writable; it does not change display settings.

## Optional display-changing smoke check

This command **temporarily changes your desktop**. Close or finish display-sensitive work first. Use a single display with mirroring disabled, and keep a local recovery route available. Run it only on your own Mac; it is not a CI step.

```bash
test_root="$(mktemp -d)"
"build/VibeScreen.app/Contents/MacOS/VibeScreen" --smoke "$test_root/01_timeout" 10
```

The helper should enter portrait mode, then restore the original mode after ten seconds. Exit status 0 means the command observed portrait entry, restoration, and virtual-display removal. Additional flags `--keep` and `--close-pipe` exercise confirmation followed by a stop request, and loss of the control pipe, respectively. Use a fresh output directory for every check.

## End-to-end manual check

On the remote mobile device, check portrait orientation, the selected remote display, editor/terminal readability, and pointer alignment near all four screen edges. Confirm the timer only when the picture and input both work. Then restore through the main button and through closing the app. Test sleep/wake and docking separately before relying on those cases.

## v0.3.0 local Retina validation

The HiDPI trial on M4 MacBook Air / macOS 26.5 exposed a 744 × 1134 logical mode backed by 1488 × 2268 pixels, with NSScreen scale 2. Timeout restoration returned to the original 1710 × 1107 logical / 3420 × 2214 framebuffer mode. The strict production checks also cover confirmed restoration, control-pipe closure and the GUI switch. Local display evidence does not prove the delivered UU stream resolution; the iPad user must assess that separately.

## v0.3.1 Dock identity validation

Before the fix, the GUI and virtual-display helper both registered as regular applications. After the fix, the GUI registers as regular (one Dock icon) and the helper as prohibited (no Dock icon). Timeout, control-pipe closure, GUI confirmation and manual restoration passed on M4 / macOS 26.5. The 2x portrait framebuffer remains unchanged.
