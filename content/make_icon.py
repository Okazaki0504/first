"""シンプルなアプリアイコン（候補A/B/C）を生成する。使い方: python3 content/make_icon.py B --install（採用は案B）"""
import json, sys, pathlib
from PIL import Image, ImageDraw, ImageFont
ROOT = pathlib.Path(__file__).resolve().parent.parent
S = 4096  # 4倍で描いてから縮小（アンチエイリアス）
NAVY, NAVY2, GOLD, WHITE = (24, 40, 92), (36, 64, 140), (226, 178, 62), (255, 255, 255)
FONT = str(ROOT / "app/assets/fonts/MPLUS1p-Bold.ttf")

def gradient(top, bottom):
    im = Image.new("RGB", (S, S), top)
    d = ImageDraw.Draw(im)
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return im

def centered_text(d, text, size, cy, fill):
    f = ImageFont.truetype(FONT, size)
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=f)
    d.text(((S - (x1 - x0)) / 2 - x0, cy - (y1 - y0) / 2 - y0), text, font=f, fill=fill)

def icon_a():  # 開いた本＋上向きのチェック
    im = gradient(NAVY2, NAVY); d = ImageDraw.Draw(im)
    cx, top, bot = S / 2, S * 0.40, S * 0.74
    w = S * 0.30
    d.polygon([(cx, top + S*0.03), (cx - w, top - S*0.02), (cx - w, bot - S*0.05), (cx, bot)], fill=WHITE)
    d.polygon([(cx, top + S*0.03), (cx + w, top - S*0.02), (cx + w, bot - S*0.05), (cx, bot)], fill=(232, 236, 246))
    lw = int(S * 0.055)
    d.line([(S*0.36, S*0.25), (S*0.47, S*0.34), (S*0.68, S*0.12)], fill=GOLD, width=lw, joint="curve")
    for p in [(S*0.36, S*0.25), (S*0.68, S*0.12)]:
        d.ellipse([p[0]-lw/2, p[1]-lw/2, p[0]+lw/2, p[1]+lw/2], fill=GOLD)
    return im

def icon_b():  # 「診」の文字＋金のライン
    im = gradient(NAVY2, NAVY); d = ImageDraw.Draw(im)
    centered_text(d, "診", int(S * 0.56), S * 0.46, WHITE)
    d.rounded_rectangle([S*0.30, S*0.78, S*0.70, S*0.81], radius=S*0.015, fill=GOLD)
    return im

def icon_c():  # 白地に紺の円章「診」＋金の星
    im = Image.new("RGB", (S, S), (246, 247, 251)); d = ImageDraw.Draw(im)
    r = S * 0.36
    d.ellipse([S/2 - r, S/2 - r, S/2 + r, S/2 + r], fill=NAVY)
    r2 = r * 0.90
    d.ellipse([S/2 - r2, S/2 - r2, S/2 + r2, S/2 + r2], outline=GOLD, width=int(S * 0.012))
    centered_text(d, "診", int(S * 0.38), S * 0.50, WHITE)
    return im

MAKERS = {"A": icon_a, "B": icon_b, "C": icon_c}

def install(big):
    out = ROOT / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    spec = json.load(open(out / "Contents.json"))
    for im in spec["images"]:
        px = round(float(im["size"].split("x")[0]) * int(im["scale"][0]))
        big.resize((px, px), Image.LANCZOS).save(out / im["filename"])
    big.resize((1024, 1024), Image.LANCZOS).save(ROOT / "docs/app_icon_1024.png")
    big.resize((512, 512), Image.LANCZOS).save(ROOT / "app/web/icons/Icon-512.png")
    big.resize((192, 192), Image.LANCZOS).save(ROOT / "app/web/icons/Icon-192.png")

if __name__ == "__main__":
    keys = [sys.argv[1]] if len(sys.argv) > 1 and sys.argv[1] in MAKERS else list(MAKERS)
    for k in keys:
        big = MAKERS[k]()
        if "--install" in sys.argv:
            install(big); print("installed", k)
        else:
            big.resize((1024, 1024), Image.LANCZOS).save(f"/tmp/icon_{k}.png")
