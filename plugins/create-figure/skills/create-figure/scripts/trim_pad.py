#!/usr/bin/env python3
"""レンダリングした図版PNGを内容にトリミングし、全辺を均等な余白で付け直す。

使い方: trim_pad.py <margin_css_px> <png> [<png> ...] [--scale N] [--thresh N]
  例:   trim_pad.py 16 fig.png
        trim_pad.py 24 a.png b.png --scale 2

- 第1の非オプション引数は必ず margin（整数 CSS px）。以降の非オプション引数は対象 PNG。
- 背景色は画像の左上隅ピクセルから自動検出（body の背景を想定）。
- margin の device px = margin_css_px * scale（既定 scale=2 のretina前提なので 16CSS=32px）。
  render を 2x 以外で撮った場合は、同じ値を --scale で渡して余白計算を合わせること。
- thresh: 背景との差がこれ未満のピクセル（影の薄い裾など）は内容と見なさず切り落とす。

依存: Pillow（無ければ `python3 -m pip install --user Pillow`）。
"""
import sys

try:
    from PIL import Image, ImageChops
except ModuleNotFoundError:
    sys.exit("Pillow が見つかりません。`python3 -m pip install --user Pillow` で導入してください。")


def process(path, margin_css, scale, thresh):
    m = margin_css * scale
    im = Image.open(path).convert("RGB")
    # 角の (0,0) はアンチエイリアスや 1px 枠を拾うことがあるため、少し内側を背景色とする
    bg = im.getpixel((2, 2))  # ≒ body 背景色
    diff = ImageChops.difference(im, Image.new("RGB", im.size, bg)).convert("L")
    mask = diff.point(lambda p: 255 if p > thresh else 0)
    bbox = mask.getbbox()
    if not bbox:
        print(f"  {path}: 内容を検出できず（背景一色？）スキップ")
        return
    cropped = im.crop(bbox)
    out = Image.new("RGB", (cropped.width + 2 * m, cropped.height + 2 * m), bg)
    out.paste(cropped, (m, m))
    out.save(path)
    print(f"  {path}: {im.size} -> {out.size}  bg={bg}  余白 {m}px=各辺{margin_css}CSSpx")


def main(argv):
    scale, thresh, margin, files = 2, 14, None, []
    i = 0
    try:
        while i < len(argv):
            a = argv[i]
            if a == "--scale":
                scale = int(argv[i + 1]); i += 2
            elif a == "--thresh":
                thresh = int(argv[i + 1]); i += 2
            elif margin is None:
                margin = int(a); i += 1  # 第1非オプション引数 = margin（整数）
            else:
                files.append(a); i += 1
    except (IndexError, ValueError):
        print(__doc__)
        sys.exit(1)
    if margin is None or not files:
        print(__doc__)
        sys.exit(1)
    failed = 0
    for f in files:
        try:
            process(f, margin, scale, thresh)
        except Exception as e:  # 1 枚の失敗で全体を止めず、報告して続行する
            failed += 1
            print(f"  {f}: 処理に失敗しました（{e}）")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
