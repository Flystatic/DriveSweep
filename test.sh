#!/bin/zsh
# End-to-end test on a FAT32 disk image: CLI clean, then clean-on-eject.
set -uo pipefail
cd "${0:A:h}"
BIN=build/DriveSweep.app/Contents/MacOS/DriveSweep
TMP=$(mktemp -d)
IMG=$TMP/test.dmg
VOL=/Volumes/DSTEST
fail=0

mount_img() {
    hdiutil attach -quiet "$IMG" || { echo "attach failed"; exit 1; }
    for _ in {1..20}; do [[ -d $VOL ]] && break; sleep 0.25; done
}

add_junk() {
    mkdir -p "$VOL/Photos/2026" "$VOL/.Trashes/501" "$VOL/.TemporaryItems"
    echo keep > "$VOL/Photos/keep.jpg"
    echo keep > "$VOL/Photos/2026/also keep.txt"
    for d in "$VOL" "$VOL/Photos" "$VOL/Photos/2026"; do echo x > "$d/.DS_Store"; done
    echo x > "$VOL/Photos/._keep.jpg"
    echo x > "$VOL/.Trashes/501/deleted.txt"
    echo x > "$VOL/.apdisk"
    sleep 1  # let macOS create its own .fseventsd / .Spotlight-V100
}

check_clean() {
    local junk
    junk=$(find "$VOL" \( -name .DS_Store -o -name '._*' \) 2>/dev/null)
    for n in .Spotlight-V100 .Trashes .TemporaryItems .apdisk; do
        [[ -e $VOL/$n ]] && junk+=$'\n'"$VOL/$n"
    done
    # macOS always rewrites .fseventsd/fseventsd-uuid on unmount; anything more is junk.
    local fse=$(ls -A "$VOL/.fseventsd" 2>/dev/null | grep -v '^fseventsd-uuid$')
    [[ -n $fse ]] && junk+=$'\n'"$VOL/.fseventsd: $fse"
    junk=${junk##$'\n'}
    if [[ -n $junk ]]; then echo "FAIL ($1): leftover junk:"; echo "$junk"; fail=1
    else echo "PASS ($1): no junk"; fi
    if [[ -f $VOL/Photos/keep.jpg && -f "$VOL/Photos/2026/also keep.txt" ]]; then
        echo "PASS ($1): real files kept"
    else echo "FAIL ($1): real files missing"; fail=1; fi
}

hdiutil create -quiet -size 64m -fs MS-DOS -volname DSTEST "$IMG"

echo "== Test 1: command-line clean =="
mount_img; add_junk
ls -A "$VOL"
$BIN --clean "$VOL"
check_clean "cli"
echo "== Internal disk must be refused =="
$BIN --clean / && { echo "FAIL: cleaned /"; fail=1; } || echo "PASS: / refused"

echo "== Test 2: clean on eject =="
add_junk
$BIN & APP_PID=$!
sleep 2
diskutil eject "$VOL" >/dev/null || { echo "FAIL: eject failed"; fail=1; }
kill $APP_PID 2>/dev/null
mount_img
ls -A "$VOL"
check_clean "eject"
diskutil eject "$VOL" >/dev/null

rm -rf "$TMP"
exit $fail
