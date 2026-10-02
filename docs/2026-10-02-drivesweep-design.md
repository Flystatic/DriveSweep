# DriveSweep — design

Menu bar app that removes macOS junk from external drives.

## Triggers
1. **Services menu**: right-click a drive in Finder → Services → "Clean Junk Files".
2. **Eject**: a DiskArbitration unmount-approval callback cleans the volume, then lets the eject continue. Can be switched off in the menu.
3. **Menu bar**: lists external drives with "Clean" and "Clean & Eject".

## What gets deleted
- Volume root only: `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems`, `.DocumentRevisions-V100`, `.apdisk`
- Anywhere: regular files named `.DS_Store` or starting with `._`

## Safety
A volume is eligible only if it is local, writable, mounted under `/Volumes/`, not the root
filesystem, external or removable (built-in SD slots count), and not a Time Machine destination.
Cleaning during eject has a 15 s time budget so the eject never hangs.

## Install
`./build.sh` makes `build/DriveSweep.app` (ad-hoc signed). Copy to `/Applications` on each Mac.
Registers itself as a login item on first launch.

## Testing
`DriveSweep --clean <path>` runs the cleaner from the command line.
`./test.sh` builds a FAT32 disk image, fills it with junk, and checks the cleaner and the eject hook.
