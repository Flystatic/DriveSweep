# DriveSweep

Removes macOS junk (`.DS_Store`, `._*`, `.Spotlight-V100`, `.fseventsd`, `.Trashes`,
`.TemporaryItems`, `.DocumentRevisions-V100`, `.apdisk`) from external drives.

- **Finder:** right-click a drive → Services → **Clean Junk Files**
- **Eject:** cleans automatically when you eject (toggle in the menu bar icon)
- **Menu bar icon:** Clean / Clean & Eject per drive, Open at Login, Quit

Only touches external/removable drives. Never the internal disk, Time Machine, or network drives.

Note: macOS always rewrites a tiny `.fseventsd/fseventsd-uuid` (36 bytes) at the moment of
unmount. No app without root access can stop that.

## Build
```
./build.sh      # → build/DriveSweep.app (Apple silicon + Intel, macOS 13+)
./test.sh       # end-to-end test on a FAT32 disk image
```

## Install on another Mac
Copy `DriveSweep.app` to `/Applications`, then right-click → Open the first time.
