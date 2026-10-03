#!/usr/bin/env python3
"""Gera AppIcon.ico (16–256 px, entradas PNG) a partir do ícone-mestre de 1024 px.
Uso: python3 make-ico.py <AppIcon.png> <saida.ico>   (usa `sips` no macOS ou Pillow se houver)"""
import os, struct, subprocess, sys, tempfile

src, dst = sys.argv[1], sys.argv[2]
sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
tmp = tempfile.mkdtemp()
blobs = []
for s in sizes:
    out = os.path.join(tmp, f"{s}.png")
    try:
        from PIL import Image
        Image.open(src).resize((s, s), Image.LANCZOS).save(out)
    except ImportError:
        subprocess.run(["sips", "-z", str(s), str(s), src, "--out", out], check=True, capture_output=True)
    blobs.append(open(out, "rb").read())

header = struct.pack("<HHH", 0, 1, len(sizes))
offset = 6 + 16 * len(sizes)
entries = b""
for s, data in zip(sizes, blobs):
    entries += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
with open(dst, "wb") as f:
    f.write(header + entries + b"".join(blobs))
print(f"{dst}: {len(sizes)} tamanhos")
