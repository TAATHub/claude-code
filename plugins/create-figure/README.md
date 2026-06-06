# create-figure

図や表を **HTML で作成 → headless Chrome で PNG にレンダリング → 均等な余白でトリミング** する Claude Code 用スキル。データ・ランキング・構造・関係・フローなどを、技術ドキュメント風の図版に仕上げる。

## 仕組み

1. **引数解釈** — 図にしたい内容・デザイン指示／参考デザイン・出力名・保存先を読み取る
2. **デザイン方針** — `frontend-design` skill で配色・レイアウト・タイポグラフィを決める（ユーザー指示があれば最優先）
3. **HTML 作成** — 1 枚のカード（`.panel`）に収めた自己完結の HTML を書く（背景色＋パディング必須）
4. **PNG レンダリング** — `scripts/render.sh` で headless Chrome（2x）撮影
5. **トリミング** — `scripts/trim_pad.py` で背景色を基準に切り出し、全辺に均等な余白を付け直す（**render とは別ステップで実行**）
6. **確認** — 生成 PNG を見て見切れ・余白・配色・文字の収まりをチェックし、必要なら HTML を直して再実行

## スクリプト

### `scripts/render.sh`

```
scripts/render.sh <html> <out.png> [WxH] [scale]
```

HTML を headless Chrome で PNG 化する（既定 2x）。`<WxH>` はパネルが収まる十分なサイズにする（余白は後でトリムされる）。

プロファイルはリポジトリ外の一時ディレクトリに作り、撮影完了を検知したらプロセスグループごと `SIGKILL` で即終了して後始末する（`--screenshot` 完了後も Chrome が終了せず、プロファイルが書き戻されてゴミ・ゾンビ化するのを防ぐため）。

### `scripts/trim_pad.py`

```
python3 scripts/trim_pad.py <pad_px> <out.png> [more.png ...] [--scale N] [--thresh N]
```

背景色を自動検出してパネルにトリミングし、全辺に均等な余白（CSS px 指定）を付け直す。複数画像をまとめて渡せる。Pillow が必要（`python3 -m pip install --user Pillow`）。

- 第1の非オプション引数は必ず余白（整数 CSS px）。以降の非オプション引数が対象 PNG
- `--scale N`（既定 2）: render を 2x 以外で撮った場合に同じ値を渡す（余白 device px = CSS px × scale）
- `--thresh N`（既定 14）: 背景との差がこれ未満のピクセルは内容と見なさず切り落とす

## 使い方

```
/create-figure 1ヶ月の被リンク数ランキングを棒グラフで。既存の LLM Wiki 図に揃えて
/create-figure 三層構造の概念図を作って。出力は llm-wiki-layers.png
```

トリガーフレーズ（「図にして」「表を画像化」「○○を図版にして」「figure を作って」等）からの自動起動にも対応する。

## 注意

- **render と trim は必ず別の Bash 呼び出し**にする（`&&` でまとめると trim がスキップされることがある）
- HTML の body には背景色とパディングを必ず付ける（トリミングが背景色基準で切り出すため）
- フォント読み込みに数百 ms かかるため、render.sh は撮影完了まで待機する（最大 15 秒）
- 動作には Google Chrome（`/Applications/Google Chrome.app`）が必要
