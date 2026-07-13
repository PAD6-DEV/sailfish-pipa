#!/usr/bin/env python3
"""Minimal Android boot.img v0 writer (no AOSP GKI deps)."""
from __future__ import annotations

import argparse
import os
import struct
import sys

BOOT_MAGIC = b"ANDROID!"
PAGE_SIZE = 4096
HEADER_SZ = 1632  # boot_img_hdr_v0 padded usage; we write v0 classic 608+pad to page


def align(n: int, a: int) -> int:
    return (n + a - 1) // a * a


def write_boot_img(kernel_path: str, out_path: str, page_size: int = PAGE_SIZE) -> None:
    with open(kernel_path, "rb") as f:
        kernel = f.read()
    ramdisk = b""
    second = b""

    kernel_size = len(kernel)
    ramdisk_size = 0
    second_size = 0
    kernel_addr = 0x00008000
    ramdisk_addr = 0x01000000
    second_addr = 0x00F00000
    tags_addr = 0x00000100
    name = b"\0" * 16
    cmdline = b"\0" * 512
    id_bytes = b"\0" * 32

    # Classic boot_img_hdr (v0) layout
    hdr = struct.pack(
        "<8s10I16s512s32s",
        BOOT_MAGIC,
        kernel_size,
        kernel_addr,
        ramdisk_size,
        ramdisk_addr,
        second_size,
        second_addr,
        tags_addr,
        page_size,
        0,  # header_version / unused
        0,  # os_version
        name,
        cmdline,
        id_bytes,
    )
    # pad header to one page
    if len(hdr) > page_size:
        raise SystemExit(f"header too large: {len(hdr)}")
    hdr = hdr + b"\0" * (page_size - len(hdr))

    kernel_pad = align(kernel_size, page_size) - kernel_size
    with open(out_path, "wb") as out:
        out.write(hdr)
        out.write(kernel)
        out.write(b"\0" * kernel_pad)
        # empty ramdisk/second already size 0 — no pages


def main() -> int:
    p = argparse.ArgumentParser(description="Write Android boot.img v0")
    p.add_argument("--kernel", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("--pagesize", type=int, default=PAGE_SIZE)
    # Accept and ignore extra AOSP-style args for compatibility
    p.add_argument("--ramdisk", default=None)
    p.add_argument("--cmdline", default="")
    p.add_argument("--base", default=None)
    args, _unknown = p.parse_known_args()
    if not os.path.isfile(args.kernel):
        print(f"missing kernel: {args.kernel}", file=sys.stderr)
        return 1
    write_boot_img(args.kernel, args.output, page_size=args.pagesize)
    print(f"Wrote {args.output} ({os.path.getsize(args.output)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
