#!/usr/bin/env python3
"""Generate the NightWise app icons (ink tile + lime crescent).

Pure standard library: renders at 4x and box-filters down, then writes PNGs.
Run from the repository root:

    python3 scripts/generate_icons.py
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

INK = (0x12, 0x14, 0x10)
LIME = (0xC8, 0xF2, 0x5B)

OUT = Path(__file__).resolve().parent.parent / "app" / "web" / "icons"
SCALE = 4


def blend(dst, src, alpha):
    return tuple(round(d * (1 - alpha) + s * alpha) for d, s in zip(dst, src))


def rounded_rect_alpha(x, y, size, radius):
    """Coverage for a rounded square, with one sample per pixel."""
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    d = math.hypot(x - cx, y - cy)
    if d <= radius:
        return 1.0
    return max(0.0, 1.0 - (d - radius))


def render(size, maskable):
    """Return raw RGB rows for an icon at `size` px."""
    s = size * SCALE
    radius = s * 0.22 if not maskable else s * 0.5
    moon_c = (s * 0.5, s * 0.5)
    moon_r = s * (0.235 if maskable else 0.27)
    bite_c = (s * 0.595, s * 0.405)
    bite_r = moon_r * 0.86

    hi = [[INK] * s for _ in range(s)]
    for y in range(s):
        for x in range(s):
            a = rounded_rect_alpha(x + 0.5, y + 0.5, s, radius)
            if a < 1:
                hi[y][x] = blend((0xEC, 0xEC, 0xE6), INK, a)
    for y in range(s):
        for x in range(s):
            px, py = x + 0.5, y + 0.5
            cover = 0.0
            samples = ((0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75))
            for ox, oy in samples:
                sx, sy = x + ox, y + oy
                in_moon = math.hypot(sx - moon_c[0], sy - moon_c[1]) <= moon_r
                in_bite = math.hypot(sx - bite_c[0], sy - bite_c[1]) <= bite_r
                if in_moon and not in_bite:
                    cover += 0.25
            if cover > 0:
                hi[y][x] = blend(hi[y][x], LIME, cover)

    rows = []
    for oy in range(size):
        row = bytearray()
        for ox in range(size):
            r = g = b = 0
            for dy in range(SCALE):
                for dx in range(SCALE):
                    p = hi[oy * SCALE + dy][ox * SCALE + dx]
                    r += p[0]
                    g += p[1]
                    b += p[2]
            n = SCALE * SCALE
            row += bytes((r // n, g // n, b // n))
        rows.append(bytes(row))
    return rows


def write_png(path, size, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(
            ">I", zlib.crc32(body) & 0xFFFFFFFF
        )

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        write_png(OUT / f"Icon-{size}.png", size, render(size, False))
        write_png(
            OUT / f"Icon-maskable-{size}.png", size, render(size, True)
        )
    # The browser favicon mirrors the 192 px tile.
    (OUT.parent / "favicon.png").write_bytes((OUT / "Icon-192.png").read_bytes())
    print(f"wrote icons to {OUT}")


if __name__ == "__main__":
    main()