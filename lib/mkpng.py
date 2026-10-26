#!/usr/bin/env python3
"""Генератор однотонных PNG без внешних зависимостей (только stdlib).

    mkpng.py OUT W H BG [X1,Y1,X2,Y2,COLOR ...]

Цвета — #RRGGBB. Прямоугольники рисуются поверх фона (координаты включительно).
"""
import struct
import sys
import zlib


def rgb(c):
    c = c.lstrip("#")
    return bytes(int(c[i:i + 2], 16) for i in (0, 2, 4))


def main():
    out, w, h, bg = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), rgb(sys.argv[4])
    rects = []
    for r in sys.argv[5:]:
        x1, y1, x2, y2, col = r.split(",")
        rects.append((int(x1), int(y1), int(x2), int(y2), rgb(col)))

    rows = []
    for y in range(h):
        row = bytearray(bg * w)
        for x1, y1, x2, y2, col in rects:
            if y1 <= y <= y2:
                a, b = max(0, x1), min(w - 1, x2)
                if a <= b:
                    row[a * 3:(b + 1) * 3] = col * (b - a + 1)
        rows.append(b"\x00" + bytes(row))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
    png += chunk(b"IEND", b"")
    with open(out, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    main()
