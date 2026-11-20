"""DrangedAddons hub textures from the Penrose triangle logo.

Usage: python tools/make_icon.py [penrose.png]
  default source: tools/penrose.png (a copy of the manager app's src/logo.png)

Writes logo.tga (128x128, the window's logo), icon.tga (64x64, the .toc
IconTexture and minimap button) and icon.ico (RGBA, so the DrangedAddons
manager's WPF decoder accepts it).
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "penrose.png")

src = Image.open(src_path).convert("RGBA")
src.resize((128, 128), Image.LANCZOS).save(os.path.join(ROOT, "logo.tga"))
small = src.resize((64, 64), Image.LANCZOS)
small.save(os.path.join(ROOT, "icon.tga"))
small.save(os.path.join(ROOT, "icon.ico"), sizes=[(64, 64), (48, 48), (32, 32), (16, 16)])
print("wrote logo.tga, icon.tga and icon.ico")
