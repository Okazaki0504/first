# プロジェクトメモ

## ユーザーとのやり取り
- 質問するときは必ず選択肢形式（AskUserQuestion）で出すこと。自由記述での質問の羅列は避ける。
- 要件は質問を反復して段階的に具体化する。確定した要件は docs/requirements.md に追記する。
- リソース節約のため、仕様変更はまずモック（mock/index.html → Artifact）で確認してから本実装する。

## 開発メモ
- Flutterアプリは `app/`。Flutter 3.47.9（codemagic.yaml と揃える）。コンテナでは `/root/sdk/flutter/bin` に導入（新しいセッションでは再導入が必要）
- 確認コマンド: `cd app && flutter analyze && flutter test`
- Web版で見た目を確認: `flutter build web --release --no-web-resources-cdn`（CanvasKitのCDNに届かないため）
- 一問一答データ: `content/<科目>_questions.py` → `python3 content/build.py <科目>` で `app/assets/questions/<科目>.json` と検証シートPDFを生成
- アイコン: `python3 content/make_icon.py`
- Bundle ID: com.okazaki0504.shindanquest ／ Codemagic のAPIキー名: codemagic_asc ／ ワークフロー: ios-testflight
