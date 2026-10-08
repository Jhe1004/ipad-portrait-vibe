# Testing and evidence boundaries

## Previously verified behavior

The private prototype was tested on an M4 MacBook Air running macOS 26.5, using a single built-in display. Checks verified 744 × 1134 portrait geometry and restoration to the previously selected mode, including backing pixels, refresh rate, position, and main-display status. Manual restoration, a short test timeout, control-pipe closure, and actual window-button operation passed. The author subsequently reported successful use with an iPad mini 7 through UU Remote.

These observations apply to the tested setup. They do not prove universal compatibility with other Macs, macOS releases, or remote clients. CI checks compilation, metadata, architectures, and packaging; CI does not reconfigure displays.

## Read-only checks

After building, the executable supports:

```bash
"build/iPad Portrait Vibe.app/Contents/MacOS/iPadPortrait" --probe
"build/iPad Portrait Vibe.app/Contents/MacOS/iPadPortrait" --check-storage
```

`--probe` prints local display information. Treat that output as local diagnostics and review identifiers before sharing it. `--check-storage` creates a new local run folder and reports whether it was writable; it does not change display settings.

## Optional display-changing smoke check

This command **temporarily changes your desktop**. Close or finish display-sensitive work first. Use a single display with mirroring disabled, and keep a local recovery route available. Run it only on your own Mac; it is not a CI step.

```bash
test_root="$(mktemp -d)"
"build/iPad Portrait Vibe.app/Contents/MacOS/iPadPortrait" --smoke "$test_root/01_timeout" 10
```

The helper should enter portrait mode, then restore the original mode after ten seconds. Exit status 0 means the command observed portrait entry, restoration, and virtual-display removal. Additional flags `--keep` and `--close-pipe` exercise confirmation followed by a stop request, and loss of the control pipe, respectively. Use a fresh output directory for every check.

## End-to-end manual check

On the iPad, check portrait orientation, the selected remote display, editor/terminal readability, and pointer alignment near all four screen edges. Confirm the timer only when the picture and input both work. Then restore through the main button and through closing the app. Test sleep/wake and docking separately before relying on those cases.
