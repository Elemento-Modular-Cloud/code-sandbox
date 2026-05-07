#!/usr/bin/env python3

import re
import sys


def sanitize_disk_serial(s: str) -> str:
    return re.sub(r'[^A-Za-z0-9_]', '', s)


def make_disk_serial(name: str, seed_int: int, max_len: int = 20) -> str:
    if max_len < 6:
        raise ValueError("max_len must be at least 6 (5-char prefix + 1 char for name)")

    modified = seed_int * 42
    prefix_hex = format(modified, 'x').zfill(4)[:4]
    prefix = prefix_hex + 'x'

    name_budget = max_len - len(prefix)
    clean = sanitize_disk_serial(name)

    if len(clean) > name_budget:
        clean = clean[:name_budget]
    else:
        clean = clean.ljust(name_budget, '0')

    serial = prefix + clean
    assert len(serial) == max_len, "BUG: serial length mismatch"
    return serial


RESET  = "\033[0m"
BOLD   = "\033[1m"
DIM    = "\033[2m"
RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
WHITE  = "\033[97m"

def header(text: str):
    width = 60
    print()
    print(BOLD + CYAN + "" + "" * (width - 2) + "" + RESET)
    padding = width - 2 - len(text)
    left  = padding // 2
    right = padding - left
    print(BOLD + CYAN + "" + " " * left + WHITE + text + " " * right + CYAN + "" + RESET)
    print(BOLD + CYAN + "" + "" * (width - 2) + "" + RESET)

def section(text: str):
    print()
    print(BOLD + YELLOW + f"   {text}" + RESET)
    print(DIM + "  " + "" * 56 + RESET)

def show_sanitize(label: str, raw: str):
    clean = sanitize_disk_serial(raw)
    removed = [c for c in raw if c not in clean and raw.count(c) > clean.count(c)]
    removed_str = " ".join(f"'{c}'" for c in sorted(set(removed))) if removed else "none"
    status = GREEN + "" if clean else RED + " (empty!)"
    print(f"  {status}{RESET}  {DIM}raw{RESET}    : {YELLOW}{repr(raw)}{RESET}")
    print(f"        {DIM}clean{RESET}  : {GREEN}{repr(clean)}{RESET}")
    print(f"        {DIM}removed{RESET}: {RED}{removed_str}{RESET}")
    print()

def show_serial(label: str, name: str, seed_int: int, max_len: int = 20):
    serial = make_disk_serial(name, seed_int, max_len)
    prefix = serial[:5]
    body   = serial[5:]
    clean_name = sanitize_disk_serial(name)
    truncated = len(clean_name) > (max_len - 5)
    padded    = len(clean_name) < (max_len - 5)
    note = (RED    + " [truncated]" if truncated else
            YELLOW + " [zero-padded]" if padded else
            GREEN  + " [exact fit]") + RESET
    print(f"  {DIM}label{RESET}  : {label}")
    print(f"  {DIM}name{RESET}   : {YELLOW}{repr(name)}{RESET}")
    print(f"  {DIM}seed{RESET}   : {seed_int}   multiplied by 42  {seed_int * 42}  hex: {format(seed_int * 42, 'x').zfill(4)[:4]}")
    print(f"  {DIM}serial{RESET} : {CYAN}{prefix}{RESET}{WHITE}{body}{RESET}  ({len(serial)} chars){note}")
    print()


def main():
    header("KVM Disk Serial Number  Demo")

    section("1. sanitize_disk_serial()  character stripping")

    show_sanitize("plain alphanumeric",           "myDisk01")
    show_sanitize("spaces in name",               "my data disk")
    show_sanitize("comma (QEMU delimiter)",        "vol,primary")
    show_sanitize("slashes (path)",               "vms/disk/primary")
    show_sanitize("XML special chars",            "disk<1>&vol\"2\"")
    show_sanitize("mixed problematic",            "prod, db vol! #3")
    show_sanitize("hyphens and underscores",      "prod-db_vol")
    show_sanitize("UUID with hyphens",            "550e8400-e29b-41d4-a716-446655440000")
    show_sanitize("all bad, nothing left",        "!@#$%^&*()")
    show_sanitize("control chars",               "disk\x00\nnew\ttab")

    section("2. make_disk_serial()  20-char serials (IDE / virtio-blk / ATA)")

    show_serial("short name, padded",        "db",                             seed_int=1,   max_len=20)
    show_serial("exact-fit name",           "datavol",                         seed_int=10,  max_len=20)
    show_serial("name with spaces",         "my data volume",                  seed_int=7,   max_len=20)
    show_serial("name too long, truncated", "production-database-volume-alpha", seed_int=99,  max_len=20)
    show_serial("name with bad chars",      "vol, 3! (prod)",                  seed_int=3,   max_len=20)
    show_serial("empty name",              "",                                 seed_int=5,   max_len=20)
    show_serial("all bad chars, empty",    "!@#$%",                           seed_int=2,   max_len=20)

    section("3. make_disk_serial()  36-char serials (SCSI)")

    show_serial("UUID fits in SCSI",     "550e8400e29b41d4a716446655440000", seed_int=8,  max_len=36)
    show_serial("long descriptive name", "productioncephrdbvolumebackend",   seed_int=15, max_len=36)

    section("4. Example libvirt XML snippet")

    volumes = [
        ("boot",   "osbootvolume",   1),
        ("data",   "postgresdata",   2),
        ("backup", "backuparchive!", 3),
    ]
    print(f"  {DIM}<disk type='file' device='disk'>{RESET}")
    print(f"  {DIM}  <source file='/var/lib/libvirt/images/vm.qcow2'/>{RESET}")
    print(f"  {DIM}  <target dev='vda' bus='virtio'/>{RESET}")
    for label, name, seed in volumes:
        serial = make_disk_serial(name, seed)
        print(f"  {GREEN}  <!-- {label}: raw name={repr(name)} -->{RESET}")
        print(f"  {CYAN}  <serial>{serial}</serial>{RESET}")
    print(f"  {DIM}</disk>{RESET}")
    print()

    section("5. Edge cases")

    print(f"  {DIM}max_len=6 (minimum allowed):{RESET}")
    s = make_disk_serial("x", seed_int=1, max_len=6)
    print(f"   {CYAN}{s}{RESET}  ({len(s)} chars)\n")

    print(f"  {DIM}max_len=5 triggers ValueError:{RESET}")
    try:
        make_disk_serial("x", seed_int=1, max_len=5)
    except ValueError as e:
        print(f"  {RED}ValueError: {e}{RESET}\n")

    print(f"  {DIM}Serial is always exactly max_len chars:{RESET}")
    for ml in [20, 36]:
        s = make_disk_serial("testvolume", seed_int=4, max_len=ml)
        ok = GREEN + "" if len(s) == ml else RED + ""
        print(f"  {ok}{RESET} max_len={ml}  len={len(s)}  {CYAN}{s}{RESET}")
    print()

    section("6. Prefix table  seed_int 1 to 128")

    print(f"  {DIM}{'seed':>6}  {' 42':>8}  {'hex (4)':>7}  prefix{RESET}")
    print(f"  {'' * 42}")
    for i in range(1, 129):
        modified = i * 42
        prefix_hex = format(modified, 'x').zfill(4)[:4]
        prefix = prefix_hex + 'x'
        print(f"  {YELLOW}{i:>6}{RESET}  {WHITE}{modified:>8}{RESET}  {GREEN}{prefix_hex:>7}{RESET}  {CYAN}{prefix}{RESET}")
    print()

    header("Done")
    print()


if __name__ == "__main__":
    main()
