"""App Store 用スクリーンショット（6.9インチ：1320×2868）を、キャプション付きで合成する。
使い方: python3 content/make_screenshots.py <生の画面画像フォルダ>
生の画面画像は Web 版を 440×956・倍率3 で撮影したもの（raw_home.png など）。"""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = pathlib.Path(sys.argv[1])
OUT = ROOT / "docs/screenshots"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1320, 2868
NAVY, NAVY2, GOLD, WHITE = (24, 40, 92), (36, 64, 140), (226, 178, 62), (255, 255, 255)
BOLD = str(ROOT / "app/assets/fonts/MPLUS1p-Bold.ttf")
REG = str(ROOT / "app/assets/fonts/MPLUS1p-Regular.ttf")

SHOTS = [
    ("raw_home.png", "毎日のクエストで\n勉強が習慣になる", "レベル・連続日数・拠点の成長"),
    ("raw_battle_ok.png", "1次・2次 1,100問の\nオリジナル一問一答", "すべての問題に解説つき"),
    ("raw_dungeon.png", "間違えた問題は\n忘れる前にもう一度", "復習の塔が1→3→7日後に出題"),
    ("raw_train0.png", "学習時間を\nかんたんに記録", "自由計測・ポモドーロ・手入力"),
    ("raw_log.png", "学習時間も過去問も\nひと目でわかる", "今週の記録・過去問の○×・実績"),
]

def compose(raw, title, sub, n):
    bg = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(bg)
    for y in range(H):  # 上が明るい紺のグラデーション
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(NAVY2[i] + (NAVY[i] - NAVY2[i]) * t) for i in range(3)))
    ft, fs = ImageFont.truetype(BOLD, 104), ImageFont.truetype(REG, 50)
    y = 170
    for line in title.split("\n"):
        x0, y0, x1, y1 = d.textbbox((0, 0), line, font=ft)
        d.text(((W - (x1 - x0)) / 2 - x0, y), line, font=ft, fill=WHITE)
        y += 140
    d.rounded_rectangle([W / 2 - 90, y + 20, W / 2 + 90, y + 32], radius=6, fill=GOLD)
    x0, y0, x1, y1 = d.textbbox((0, 0), sub, font=fs)
    d.text(((W - (x1 - x0)) / 2 - x0, y + 70), sub, font=fs, fill=(210, 216, 236))
    # 画面（角丸＋白い縁）
    shot = Image.open(raw).convert("RGB")
    sw = int(W * 0.80)
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    top = y + 200
    visible = min(sh, H - top + 200)  # 下端ははみ出してよい（下を切る）
    shot = shot.crop((0, 0, sw, min(sh, H - top)))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height + 80], radius=56, fill=255)
    frame = Image.new("RGB", (shot.width + 24, shot.height + 24), (235, 238, 246))
    fmask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fmask).rounded_rectangle([0, 0, frame.width - 1, frame.height + 80], radius=68, fill=255)
    left = (W - frame.width) // 2
    bg.paste(frame, (left, top - 12), fmask)
    bg.paste(shot, (left + 12, top), mask)
    out = OUT / f"screenshot_{n}.png"
    bg.save(out)
    return out

if __name__ == "__main__":
    for i, (f, t, s) in enumerate(SHOTS, 1):
        print(compose(RAW / f, t, s, i))
