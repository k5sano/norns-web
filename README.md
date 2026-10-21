# norns-web

[English](#english) · 日本語

monome norns のブラウザ版エミュレータ。Lua スクリプトをそのまま動かせます。

- 128×64 OLED、K1–K3、E1–E3、K1 メニュー（MIX / HOME / PARAMETERS）
- grid 128、arc 4、crow（4 out / 2 in）
- softcut（6 ボイス・2 バッファ）、PolyPerc ほか簡易エンジン
- clock / metro / params / sequins / lattice / lfo などのコアライブラリ
- norns.community のカタログからワンクリックで GitHub から取り込み（git submodule 含む）
- 実機の monome grid を USB で接続（Chrome / Edge の Web Serial）。mext（2011年以降）・series（2007–2010）・40h に対応し、16段階 / 4段階 / 単色の階調としきい値を設定可能

## 使い方

GitHub Pages（Settings → Pages → Branch: `main` / `/ (root)`）で公開して URL を開くだけ。
ローカルで試す場合は `python3 -m http.server` などで配信してください（`file://` では動きません）。

## 制限

- midi と crow.ii は無視されます
- SuperCollider 製エンジンは未実装。音名系コマンドは代替音で鳴ります
- GitHub API は未認証だと 1 時間 60 回まで（1 プロジェクトにつき 1 回 + submodule ごとに 1 回）

## ライセンス

このリポジトリのコードは [MIT License](LICENSE) です。

- 外部ライブラリは CDN から読み込んでいて、このリポジトリには含みません：[fengari-web](https://github.com/fengari-lua/fengari-web)（MIT）、[JSZip](https://github.com/Stuk/jszip)（MIT / GPLv3）、フォントは IBM Plex と Silkscreen（SIL Open Font License）。
- `norns/catalog.json` のスクリプト名・作者・説明・URL は [norns.community](https://norns.community) のカタログに由来します。
- カタログからインストールするスクリプトは、使う人のブラウザが GitHub から直接取得するもので、このリポジトリには含まれません。各スクリプトの権利は作者に帰属し、それぞれのライセンスに従います。
- norns と monome は monome の名称です。このエミュレータは非公式のものです。


## English

A browser-based emulator for monome norns that runs norns Lua scripts as they are. Open https://k5sano.github.io/norns-web/ — the interface switches between English and Japanese with the button at the top right, and the [manual](https://k5sano.github.io/norns-web/manual-en.html) is available in both languages.

- 128×64 OLED, K1–K3, E1–E3 and the K1 system menu (MIX / HOME / PARAMETERS)
- grid 128, arc 4 and crow (4 outputs / 2 inputs)
- softcut (6 voices, 2 buffers), PolyPerc and simplified engines
- clock, metro, params, sequins, lattice, lfo and the other core libraries
- one-click installs from the norns.community catalog, fetched straight from GitHub (git submodules included)
- real monome grids over USB in Chrome / Edge (Web Serial): mext (2011+), series (2007–2010) and 40h, with 16-level, 4-step or on/off brightness and adjustable thresholds

MIDI and crow.ii are ignored, and SuperCollider engines are not implemented (note-like commands play a stand-in sound). The code is under the [MIT License](LICENSE); installed scripts belong to their authors and are not part of this repository. norns and monome are names of monome; this emulator is unofficial.
