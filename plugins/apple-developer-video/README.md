# apple-developer-video

Apple Developer の動画セッションページ（`developer.apple.com/videos/play/...`、WWDC / Tech Talks など）から、
**公式トランスクリプト・章ごとSummary・サンプルコード・関連リンク**を取得し、
**要約＋詳細解説（サンプルコードをインライン配置）＋整形済み全文トランスクリプト**を1つのMarkdownファイルに書き出すスキル。

## なぜ別スキルか（youtube-transcript との違い）

Apple Developer の動画ページは `yt-dlp` では字幕トラックを取得できない（`NO_SUBTITLES`）。
一方、ページHTMLには4つの supplement が埋め込まれている:

| supplement | 内容 |
|---|---|
| `transcript` | 公式の逐語トランスクリプト全文（原語=英語） |
| `summary` | 章ごとの要約（タイムスタンプ付き） |
| `sample-code` | 公式Swiftサンプルコード（タイムスタンプ付き） |
| Resources | 関連ドキュメントリンク |

これらは**一次情報**で、API名・サンプルコードが公式表記で確定するため、YouTube自動字幕より上位。
そのため YouTube汎用の youtube-transcript とは分離した専用スキルとして提供する。

## 使い方

```
/apple-developer-video https://developer.apple.com/videos/play/wwdc2026/279/ [出力先パス]
```

URLのみ指定した場合は保存先を、出力先のみ無い場合も対話的に尋ねる。

## 構成

- `skills/apple-developer-video/SKILL.md` — スキル定義
- `skills/apple-developer-video/scripts/fetch_apple_session.sh` — HTML取得＋4 supplement抽出（`curl` + `python3` 標準ライブラリのみ）

## 供給網について

取得スクリプトは `curl`（システム標準）と `python3` 標準ライブラリ（re/json/html）のみを使い、
PyPI/npm 等の第三者パッケージを実行時取得しない。yt-dlp 経路よりも供給網リスクが低く、バージョン固定の管理も不要。

## 抽出の堅牢化メモ

HTML解析で踏みやすい落とし穴を `fetch_apple_session.sh` 内で対処済み:

- トランスクリプトの終端を入れ子の `</section>` で早期に切らないよう、後続 supplement（`sample-code`/`summary`）の開始位置で区切る
- 先頭の `id="transcript-content">` 断片を除去
- 文間スペース（`.X` → `. X`）と数字+語の結合（`harmonics.3D` → `harmonics. 3D`）を補正
- 関連リンクは `<h2>Resources</h2>` 配下の `<li class="document">` に限定し、グローバルナビのリンクを除外

HTML構造が変わって抽出できない場合は `STATUS=APPLE_PARSE_ERROR` を返し、サイレントな部分取得を避ける。
