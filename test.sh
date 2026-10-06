#!/bin/zsh
# End-to-end test on a FAT32 disk image: CLI clean, then clean-on-eject.
set -uo pipefail
cd "${0:A:h}"
BIN=build/Ejectus.app/Contents/MacOS/Ejectus
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

echo "== Test 3: unreadable junk folder must not wipe the drive (regression) =="
IMG3=$TMP/hfs.dmg; VOL3=/Volumes/DSTEST3
hdiutil create -quiet -size 32m -fs HFS+ -volname DSTEST3 "$IMG3"
hdiutil attach -quiet "$IMG3"; for _ in {1..20}; do [[ -d $VOL3 ]] && break; sleep 0.25; done
mkdir -p "$VOL3/.TemporaryItems/inner" "$VOL3/AAA" "$VOL3/DCIM/100CANON" "$VOL3/ZZZ"
for f in AAA/a.txt DCIM/100CANON/IMG_0001.JPG ZZZ/z.txt top.txt; do echo keep > "$VOL3/$f"; done
echo x > "$VOL3/ZZZ/.DS_Store"
chmod 000 "$VOL3/.TemporaryItems"
$BIN --clean "$VOL3"
chmod 755 "$VOL3/.TemporaryItems"
missing=0
for f in AAA/a.txt DCIM/100CANON/IMG_0001.JPG ZZZ/z.txt top.txt; do
    [[ -f $VOL3/$f ]] || { echo "FAIL (unreadable): deleted real file $f"; missing=1; fail=1; }
done
(( missing )) || echo "PASS (unreadable): all real files kept"
[[ -e $VOL3/ZZZ/.DS_Store ]] && { echo "FAIL (unreadable): .DS_Store left"; fail=1; } || echo "PASS (unreadable): junk after it still cleaned"
diskutil eject "$VOL3" >/dev/null

echo "== Test 4: --keep-trash leaves .Trashes alone =="
mount_img
mkdir -p "$VOL/.Trashes/501" "$VOL/Photos"
echo trashed > "$VOL/.Trashes/501/deleted.txt"
echo keep > "$VOL/Photos/keep.jpg"
echo x > "$VOL/Photos/.DS_Store"
$BIN --clean "$VOL" --keep-trash
[[ -f $VOL/.Trashes/501/deleted.txt ]] && echo "PASS (keep-trash): trash kept" || { echo "FAIL (keep-trash): trash emptied"; fail=1; }
[[ -e $VOL/Photos/.DS_Store ]] && { echo "FAIL (keep-trash): .DS_Store left"; fail=1; } || echo "PASS (keep-trash): other junk still cleaned"
[[ -f $VOL/Photos/keep.jpg ]] && echo "PASS (keep-trash): real files kept" || { echo "FAIL (keep-trash): real file missing"; fail=1; }
diskutil eject "$VOL" >/dev/null

echo "== Test 5: a skipped drive is left alone on eject =="
mount_img
echo x > "$VOL/.DS_Store"
UUID=$(diskutil info "$VOL" | awk -F': *' '/Volume UUID/{print $2}')
HAD_SKIPS=$(defaults read local.ejectus skippedDrives >/dev/null 2>&1 && echo yes)
defaults export local.ejectus "$TMP/prefs.plist" 2>/dev/null
defaults write local.ejectus skippedDrives -array-add "$UUID"
$BIN & APP_PID=$!
sleep 2
diskutil eject "$VOL" >/dev/null
kill $APP_PID 2>/dev/null
# Put the user's skip list back exactly as it was.
if [[ -n $HAD_SKIPS ]]; then defaults import local.ejectus "$TMP/prefs.plist"; else defaults delete local.ejectus skippedDrives; fi
mount_img
[[ -e $VOL/.DS_Store ]] && echo "PASS (skip): junk left on skipped drive" || { echo "FAIL (skip): skipped drive was cleaned"; fail=1; }
diskutil eject "$VOL" >/dev/null

rm -rf "$TMP"
exit $fail
