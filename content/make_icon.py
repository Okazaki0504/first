"""アプリアイコン（ドット絵の城）を生成して iOS の AppIcon セットに書き出す"""
import json, pathlib
from PIL import Image, ImageDraw
ROOT = pathlib.Path(__file__).resolve().parent.parent
G = 32  # 32x32 ドット
img = Image.new("RGB", (G, G), "#141a33")
d = ImageDraw.Draw(img)
def r(x, y, w, h, c): d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
r(0, 0, 32, 20, "#1f2850"); r(0, 20, 32, 12, "#141a33")
for x, y in [(4, 4), (26, 3), (22, 8), (7, 11)]: r(x, y, 1, 1, "#e9e4cf")
r(0, 25, 32, 7, "#3d6b3a"); r(0, 29, 32, 3, "#2e5230")
# 城
r(9, 13, 14, 13, "#d7d9e6"); r(6, 9, 5, 17, "#c4c7d8"); r(21, 9, 5, 17, "#c4c7d8"); r(13, 6, 6, 10, "#c4c7d8")
for x in (6, 8, 10, 21, 23, 25): r(x, 8, 1, 1, "#c4c7d8")
r(6, 7, 5, 2, "#b5523b"); r(21, 7, 5, 2, "#b5523b"); r(13, 4, 6, 2, "#b5523b")
r(15, 20, 2, 6, "#3b2a1a"); r(14, 21, 4, 5, "#3b2a1a")
r(8, 13, 1, 2, "#f2c14e"); r(23, 13, 1, 2, "#f2c14e"); r(15, 9, 2, 2, "#f2c14e")
r(16, 0, 1, 4, "#e9e4cf"); r(17, 0, 3, 2, "#f2c14e")  # 旗
big = img.resize((1024, 1024), Image.NEAREST)
out = ROOT / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
spec = json.load(open(out / "Contents.json"))
for im in spec["images"]:
    px = round(float(im["size"].split("x")[0]) * int(im["scale"][0]))
    big.resize((px, px), Image.NEAREST if px % 32 == 0 else Image.LANCZOS).save(out / im["filename"])
big.save(ROOT / "docs/app_icon_1024.png")
print("icons written")
