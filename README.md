# norns-web

monome norns のブラウザ版エミュレータ。Lua スクリプトをそのまま動かせます。

- 128×64 OLED、K1–K3、E1–E3、K1 メニュー（MIX / HOME / PARAMETERS）
- grid 128、arc 4、crow（4 out / 2 in）
- softcut（6 ボイス・2 バッファ）、PolyPerc ほか簡易エンジン
- clock / metro / params / sequins / lattice / lfo などのコアライブラリ
- norns.community のカタログからワンクリックで GitHub から取り込み（git submodule 含む）

## 使い方

GitHub Pages（Settings → Pages → Branch: `main` / `/ (root)`）で公開して URL を開くだけ。
ローカルで試す場合は `python3 -m http.server` などで配信してください（`file://` では動きません）。

## 制限

- midi と crow.ii は無視されます
- SuperCollider 製エンジンは未実装。音名系コマンドは代替音で鳴ります
- GitHub API は未認証だと 1 時間 60 回まで（1 プロジェクトにつき 1 回 + submodule ごとに 1 回）

取り込んだスクリプトの権利は各作者に帰属します。このリポジトリには含まれていません。
