# Ejectus

Removes macOS junk (`.DS_Store`, `._*`, `.Spotlight-V100`, `.fseventsd`, `.Trashes`,
`.TemporaryItems`, `.DocumentRevisions-V100`, `.apdisk`) from external drives.

- **Finder:** right-click a drive → Services → **Clean Junk Files**
- **Eject:** cleans automatically when you eject (toggle in the menu bar icon)
- **Menu bar icon:** Clean / Clean & Eject per drive, Open at Login, Quit

Only touches external/removable drives. Never the internal disk, Time Machine, or network drives.

`.Spotlight-V100` is locked by macOS, so a small root helper removes it with `mdutil -X`.
Turn it on from the menu bar icon → "Set Up Spotlight Helper…", then switch Ejectus on in
System Settings → Login Items. The helper only ever runs `mdutil -X` on a verified external drive.

## Download
Get `Ejectus-x.y.dmg` from the [Releases](https://github.com/Flystatic/Ejectus/releases) page.
Open it, drag Ejectus into Applications, and follow "How to Install.txt".
The app isn't signed with an Apple Developer ID, so the first launch needs
right-click → Open (or System Settings → Privacy & Security → Open Anyway).

## Build
```
./build.sh      # → build/Ejectus.app (Apple silicon + Intel, macOS 13+)
./test.sh       # end-to-end test on a FAT32 disk image
```

## Install on another Mac
Copy `Ejectus.app` to `/Applications`, then right-click → Open the first time.
Then set up the Spotlight helper from the menu bar icon (see above).
