"""アプリアイコン（ドット絵の「診」と城）を生成して iOS の AppIcon セットに書き出す"""
import json, pathlib
from PIL import Image, ImageDraw
ROOT = pathlib.Path(__file__).resolve().parent.parent
G = 32  # 32x32 ドット
img = Image.new("RGB", (G, G), "#141a33")
d = ImageDraw.Draw(img)
def r(x, y, w, h, c): d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
r(0, 0, 32, 20, "#1f2850"); r(0, 20, 32, 12, "#141a33")
for x, y in [(3, 4), (28, 3), (27, 12), (4, 13)]: r(x, y, 1, 1, "#e9e4cf")
r(0, 25, 32, 7, "#3d6b3a"); r(0, 29, 32, 3, "#2e5230")
# 小さな城（下部）
r(3, 22, 26, 7, "#d7d9e6"); r(1, 19, 5, 10, "#c4c7d8"); r(26, 19, 5, 10, "#c4c7d8")
r(1, 18, 5, 1, "#b5523b"); r(26, 18, 5, 1, "#b5523b"); r(14, 25, 4, 4, "#3b2a1a")
r(3, 21, 1, 2, "#f2c14e"); r(28, 21, 1, 2, "#f2c14e")
# 「診」の文字（16x16ドットの手描き。左＝言、右＝㐱）
KANJI = [
    "...........#....",
    "..........#.#...",
    "..##.....#...#..",
    "######..#.....#.",
    ".......#.......#",
    ".####...........",
    "............##..",
    ".####.....##....",
    "........##......",
    ".............##.",
    ".####......##...",
    ".#..#...##......",
    ".#..#..........#",
    ".####........##.",
    "..........###...",
    ".......##.......",
]
ox, oy = 8, 1
mask = [[c == "#" for c in row] for row in KANJI]
for y in range(16):  # 縁取り（読みやすさのため）
    for x in range(16):
        if mask[y][x]:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)]:
                r(ox + x + dx, oy + y + dy, 1, 1, "#0c1024")
for y in range(16):
    for x in range(16):
        if mask[y][x]:
            r(ox + x, oy + y, 1, 1, "#f2c14e")
big = img.resize((1024, 1024), Image.NEAREST)
out = ROOT / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
spec = json.load(open(out / "Contents.json"))
for im in spec["images"]:
    px = round(float(im["size"].split("x")[0]) * int(im["scale"][0]))
    big.resize((px, px), Image.NEAREST if px % 32 == 0 else Image.LANCZOS).save(out / im["filename"])
big.save(ROOT / "docs/app_icon_1024.png")
print("icons written")
