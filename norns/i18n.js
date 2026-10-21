/* UI strings for norns-web (ja / en). Loaded before app.js and hwgrid.js. */
(() => {
'use strict';
const D = {
  // header / status
  'status.boot': ['起動中', 'starting'],
  'status.run': ['実行中 — {s}', 'running — {s}'],
  'status.err': ['エラー — {s}', 'error — {s}'],
  'status.stop': ['停止', 'stopped'],
  'sound.on': ['音 ON', 'SOUND ON'],
  'sound.off': ['音 OFF', 'SOUND OFF'],
  'sound.on.title': ['クリックで音を止める', 'Click to mute'],
  'sound.off.title': ['クリックで音を出す', 'Click to start sound'],
  'manual': ['マニュアル', 'Manual'],
  'lang.toggle': ['English', '日本語'],
  'lang.toggle.title': ['Switch to English', '日本語に切り替え'],
  'audio.hint': ['クリック / タップで音が出ます', 'Click or tap to start sound'],
  'menu.title': ['K1 短押しと同じ', 'Same as a short K1 press'],
  // grid / hw
  'hw.connect': ['USB grid に接続', 'Connect USB grid'],
  'hw.disconnect': ['切断', 'Disconnect'],
  'hw.idle': ['未接続', 'not connected'],
  'hw.unsupported': ['Chrome / Edge（パソコン版）で使えます', 'Available in desktop Chrome / Edge'],
  'hw.connected': ['接続中: {p} {c}×{r}', 'connected: {p} {c}×{r}'],
  'hw.panel': ['実機グリッドの設定', 'Hardware grid settings'],
  'hw.proto': ['プロトコル', 'Protocol'],
  'hw.proto.auto': ['自動判別', 'Auto-detect'],
  'hw.proto.mext': ['mext（2011年以降）', 'mext (2011 and later)'],
  'hw.proto.series': ['series（2007–2010 の 64 / 128 / 256）', 'series (2007–2010 64 / 128 / 256)'],
  'hw.proto.40h': ['40h（2006 / arduinome）', '40h (2006 / arduinome)'],
  'hw.proto.series.short': ['series（2007–2010）', 'series (2007–2010)'],
  'hw.size': ['サイズ', 'Size'],
  'hw.size.auto': ['自動（mext のみ）', 'Auto (mext only)'],
  'hw.size.256': ['256（16×16 の上半分を使用）', '256 (uses the top 16×8)'],
  'hw.baud': ['通信速度', 'Baud rate'],
  'hw.baud.monome': ['115200（monome 純正）', '115200 (monome)'],
  'hw.rot': ['向き', 'Rotation'],
  'hw.rot.0': ['そのまま', 'None'],
  'hw.rot.180': ['180°回転（ケーブルが左）', '180° (cable on the left)'],
  'hw.mode': ['階調', 'Brightness'],
  'hw.mode.16': ['16段階（varibright）', '16 levels (varibright)'],
  'hw.mode.4': ['4段階', '4 steps'],
  'hw.mode.2': ['点灯 / 消灯のみ（初代・単色）', 'On / off only (early mono grids)'],
  'hw.mono': ['点灯するレベル', 'Light from level'],
  'hw.mono.suffix': ['以上で点灯', 'and up'],
  'hw.t1': ['段階1（暗）', 'Step 1 (dim)'],
  'hw.t2': ['段階2（中）', 'Step 2 (mid)'],
  'hw.t3': ['段階3（明）', 'Step 3 (bright)'],
  'hw.t.suffix': ['以上', 'and up'],
  'hw.map': ['対応表', 'Mapping'],
  'hw.map.aria': ['スクリプトのレベル 0–15 と実機の点灯', 'Script levels 0–15 and how the grid lights them'],
  'hw.out': ['送る値 1 / 2 / 3', 'Values sent 1 / 2 / 3'],
  'hw.out1.aria': ['段階1で送る値', 'Value sent for step 1'],
  'hw.out2.aria': ['段階2で送る値', 'Value sent for step 2'],
  'hw.out3.aria': ['段階3で送る値', 'Value sent for step 3'],
  'hw.bright': ['明るさ', 'Intensity'],
  'hw.mirror': ['画面のグリッドも同じ階調で表示', 'Show the same steps on the on-screen grid'],
  'hw.test': ['押している間テスト表示', 'Hold for test pattern'],
  'hw.test.title': ['押している間、左から右へレベル 0〜15 を表示します', 'While held, shows levels 0–15 from left to right'],
  'hw.reset': ['初期設定に戻す', 'Reset settings'],
  'hw.note': ['テスト表示では、左の列から順にレベル 0〜15 を出します。実機でどの列から光るかを見ながら、しきい値を合わせてください。serialosc など、ほかのソフトがグリッドを使っている間は接続できません。',
              'The test pattern shows levels 0–15 from the leftmost column. Watch which column starts to light on your grid and adjust the thresholds. The grid cannot be opened while serialosc or other software is using it.'],
  'hw.cell.on': ['点灯', 'on'],
  'hw.cell.off': ['消灯', 'off'],
  'hw.cell.step': ['段階 {n}', 'step {n}'],
  'hw.prev': ['前回のグリッドに接続', 'Connect the previous grid'],
  'hw.err.send': ['送信エラー: {e}', 'Send error: {e}'],
  'hw.err.lost': ['グリッドとの接続が切れました', 'Lost connection to the grid'],
  'hw.err.browser': ['この機能は Chrome か Edge（パソコン版）で使えます', 'This feature needs desktop Chrome or Edge'],
  'hw.err.open': ['ポートを開けませんでした: {e}（serialosc など、ほかのソフトが使っていないか確認してください）', 'Could not open the port: {e} (check that serialosc or other software is not using it)'],
  'hw.log.connected': ['USB grid に接続しました（{p} {c}×{r}{pid}）', 'USB grid connected ({p} {c}×{r}{pid})'],
  'hw.err.removed': ['グリッドが取り外されました', 'The grid was unplugged'],
  // arc / crow / audio in
  'arc.aria': ['monome arc 4 リング', 'monome arc 4 rings'],
  'arc.note': ['リングをなぞると a.delta、中央を押すと a.key。ホイールでも回せます。', 'Drag around a ring for a.delta, press the center for a.key. The mouse wheel also turns rings.'],
  'crow.aria': ['crow 出力電圧', 'crow output voltages'],
  'crow.listen': ['OUT 1 を V/oct、OUT 2 を VCA として音で聴く', 'Listen: OUT 1 as V/oct, OUT 2 as VCA'],
  'audioin.label': ['AUDIO IN（softcut の録音元）', 'AUDIO IN (softcut recording source)'],
  'audioin.none': ['なし（無音）', 'None (silence)'],
  'audioin.tone': ['テストトーン（アルペジオ）', 'Test tone (arpeggio)'],
  'hint.keys': ['K1 短押しでシステムメニュー（MIX / HOME / PARAMETERS）。エンコーダーは上下ドラッグかホイール。キーボード: <kbd>1</kbd><kbd>2</kbd><kbd>3</kbd> = K1–K3、<kbd>Q</kbd><kbd>W</kbd> = E1、<kbd>A</kbd><kbd>S</kbd> = E2、<kbd>Z</kbd><kbd>X</kbd> = E3。',
                'Short-press K1 for the system menu (MIX / HOME / PARAMETERS). Drag encoders up and down or use the wheel. Keyboard: <kbd>1</kbd><kbd>2</kbd><kbd>3</kbd> = K1–K3, <kbd>Q</kbd><kbd>W</kbd> = E1, <kbd>A</kbd><kbd>S</kbd> = E2, <kbd>Z</kbd><kbd>X</kbd> = E3.'],
  // editor
  'tab.editor': ['エディタ', 'Editor'],
  'tab.library': ['ライブラリ', 'Library'],
  'ed.file': ['ファイル', 'File'],
  'ed.run': ['▶ 実行', '▶ Run'],
  'ed.stop': ['■ 停止', '■ Stop'],
  'ed.new': ['＋ 新規', '+ New'],
  'ed.revert': ['元に戻す', 'Revert'],
  'ed.src': ['Lua スクリプト', 'Lua script'],
  'con.clear': ['クリア', 'Clear'],
  'repl.ph': ['Lua を1行入力して Enter（例: engine.hz(440)）', 'Type a line of Lua and press Enter (e.g. engine.hz(440))'],
  'api.summary': ['対応している norns API（詳しくは<a href="{m}#compat" target="_blank" rel="noopener">マニュアル</a>）', 'Supported norns API (details in the <a href="{m}#compat" target="_blank" rel="noopener">manual</a>)'],
  'api.softcut': ['6ボイス・2バッファ（各約87秒）。rate / loop / fade / rec・pre / post filter / level_cut_cut / phase poll / render_buffer / buffer_read・write', '6 voices, 2 buffers (about 87 s each). rate / loop / fade / rec · pre / post filter / level_cut_cut / phase poll / render_buffer / buffer_read · write'],
  'api.crow': ['output.volts / slew / action（to, loop, times, held, dyn, lfo, ar, adsr, pulse …）· input.mode stream / change', 'output.volts / slew / action (to, loop, times, held, dyn, lfo, ar, adsr, pulse …) · input.mode stream / change'],
  'api.clock': ['clock.run / sleep / sync / cancel · metro.init · poll（amp_in / amp_out）', 'clock.run / sleep / sync / cancel · metro.init · poll (amp_in / amp_out)'],
  'api.params': ['number option control taper binary trigger text file separator group · pset の読み書き', 'number option control taper binary trigger text file separator group · pset read / write'],
  'api.engine': ['PolyPerc · TestSine · PolySub（簡易）· MollyThePoly（簡易）。ほかのエンジンは音名系コマンドを代替音で鳴らします', 'PolyPerc · TestSine · PolySub (simplified) · MollyThePoly (simplified). Other engines play note-like commands with a stand-in sound'],
  'api.note': ['include / require は dust/code 内のファイルとコアライブラリを読み込みます。midi と crow.ii は無視されます。ファイルはこのブラウザ内（IndexedDB）に保存されます。', 'include / require load files from dust/code and the core libraries. midi and crow.ii are ignored. Files are stored in this browser (IndexedDB).'],
  // library
  'lib.drop': ['ZIP・.lua・音声・.png をここにドロップ', 'Drop a ZIP, .lua, audio or .png here'],
  'lib.drop.sub': ['カタログにないスクリプトは ZIP や .lua をここに。音声は dust/audio/ に入ります。', 'Use this for scripts that are not in the catalog. Audio goes into dust/audio/.'],
  'lib.installed': ['インストール済み · dust/code', 'Installed · dust/code'],
  'lib.audio': ['音声と画像 · dust', 'Audio and images · dust'],
  'lib.catalog': ['norns.community カタログ', 'norns.community catalog'],
  'lib.search': ['名前・作者・タグで検索', 'Search by name, author or tag'],
  'lib.search.aria': ['カタログ検索', 'Search the catalog'],
  'lib.filter.aria': ['絞り込み', 'Filter'],
  'lib.f.all': ['すべて', 'All'],
  'lib.f.ok': ['起動確認済み', 'Verified to start'],
  'lib.f.engine': ['対応エンジンのみ', 'Supported engines only'],
  'lib.note': ['「インストール」で GitHub から直接このブラウザに取り込みます（git submodule も含む）。入れたファイルはこのブラウザ内にだけ保存されます。', '“Install” fetches the script straight from GitHub into this browser (including git submodules). Installed files are stored only in this browser.'],
  'lib.count': ['{n} / {t} 件', '{n} / {t}'],
  'lib.noengine': ['エンジンなし', 'no engine'],
  'lib.customengine': ['独自エンジン (代替音)', 'custom engine (stand-in)'],
  'lib.standin': [' (代替音)', ' (stand-in)'],
  'lib.midi': ['midi (未対応)', 'midi (unsupported)'],
  'lib.needs': ['要: {r}', 'needs: {r}'],
  'lib.verified': ['起動確認済', 'verified'],
  'lib.run': ['実行', 'Run'],
  'lib.install': ['インストール', 'Install'],
  'lib.more': ['ほか {n} 件。検索で絞り込めます。', '{n} more. Narrow it down with search.'],
  'lib.empty': ['まだありません', 'Nothing yet'],
  'lib.update': ['更新', 'Update'],
  'lib.update.title': ['GitHub から最新版を取り直します（編集した内容は消えます）', 'Fetch the latest version from GitHub (your edits are lost)'],
  'lib.delete': ['削除', 'Delete'],
  'lib.delete.confirm': ['本当に削除', 'Really delete'],
  'lib.audio.empty': ['dust/audio はまだ空です', 'dust/audio is empty'],
  'lib.files': ['{n} ファイル', '{n} files'],
  'lib.file1': ['1 ファイル', '1 file'],
  // repository footer
  'repo.desc': ['monome norns のブラウザ版エミュレータ', 'A browser-based monome norns emulator'],
  'repo.issues': ['不具合報告・要望', 'Issues and requests'],
  'repo.history': ['更新履歴', 'Changelog'],
  'repo.note': ['norns は monome の製品です。このエミュレータは非公式で、取り込んだスクリプトの権利は各作者に帰属します。', 'norns is a monome product. This emulator is unofficial, and installed scripts belong to their authors.'],
  'repo.updated': ['最終更新 {d}', 'updated {d}'],
  // log / errors
  'log.ignored': ['{k} は未実装のため無視されます', '{k} is not implemented and is ignored'],
  'log.png.missing': ['画像が見つかりません: {p}', 'Image not found: {p}'],
  'log.png.bad': ['画像を読み込めません: {p}', 'Could not load image: {p}'],
  'log.noaudio': ['このブラウザでは Web Audio が使えません', 'Web Audio is not available in this browser'],
  'log.resume.fail': ['音声を開始できませんでした: {e}', 'Could not start audio: {e}'],
  'log.audio.on': ['音声: 出力中（{r} Hz）', 'audio: running ({r} Hz)'],
  'log.softcut.init': ['softcut を初期化できませんでした', 'Could not initialize softcut'],
  'log.softcut.nofile': ['softcut: ファイルがありません {p}（ライブラリから音声を読み込めます）', 'softcut: file not found {p} (you can add audio in the Library)'],
  'log.softcut.decode': ['softcut: 音声をデコードできません {p}', 'softcut: could not decode audio {p}'],
  'log.softcut.wrote': ['softcut: {p} に書き出しました', 'softcut: wrote {p}'],
  'log.engine.cmd': ['engine.{c} は {e} の簡易版では無視されます', 'engine.{c} is ignored by the simplified {e}'],
  'log.engine.approx': ['engine {e}: 簡易シンセで近似しています', 'engine {e}: approximated with a simple synth'],
  'log.engine.missing': ['engine {e} は SuperCollider 製で未実装です。音名らしいコマンドは代替のパーカッシブ音で鳴らします', 'engine {e} is a SuperCollider engine and is not implemented. Note-like commands play a stand-in percussive sound'],
  'log.decode': ['音声をデコードできません: {p}', 'Could not decode audio: {p}'],
  'log.nofengari': ['Lua ランタイム (fengari) を読み込めませんでした。ネットワークを確認して再読み込みしてください。', 'Could not load the Lua runtime (fengari). Check your network and reload.'],
  'log.boot.pending': ['ランタイムの読み込みが終わっていません', 'The runtime is still loading'],
  'log.noscript': ['スクリプトがありません: {p}', 'Script not found: {p}'],
  'log.timeout': ['timeout: 処理が長時間止まらないため中断しました（無限ループ？）', 'timeout: stopped a call that ran too long (infinite loop?)'],
  'log.cantaudio': ['このブラウザでは音声を出せません', 'This browser cannot play audio'],
  'log.reverted': ['{p} を元に戻しました', 'Reverted {p}'],
  'log.notrunning': ['スクリプトが動いていません。先に実行してください', 'No script is running. Run one first'],
  'gh.rate': ['GitHub API の回数制限（1時間60回）に達しました', 'Hit the GitHub API limit (60 requests per hour)'],
  'gh.rate.retry': ['。{t} 以降にもう一度押してください', '. Try again after {t}'],
  'gh.list': ['{r} の一覧を取得できません ({s})', 'Could not list {r} ({s})'],
  'gh.truncated': ['{r} はファイル数が多いため一部だけ取得します', '{r} has many files; fetching only part of it'],
  'gh.progress': ['取得中 {d}/{t}', 'fetching {d}/{t}'],
  'gh.sub': ['サブモジュール {p}', 'submodule {p}'],
  'gh.notgh': ['{n}: GitHub 以外のリポジトリは自動取得できません。ZIP を上の枠に入れてください', '{n}: only GitHub repositories can be fetched. Drop a ZIP in the box above'],
  'gh.listing': ['一覧を取得中…', 'listing files…'],
  'gh.done': ['{n} を GitHub から取得しました ({d} files)', 'Fetched {n} from GitHub ({d} files)'],
  'gh.missingsubs': ['取得できなかった git submodule: {s}', 'git submodules that could not be fetched: {s}'],
  'gh.skipaudio': ['大きいため音声ファイル {n} 個は取得していません', 'Skipped {n} large audio files'],
  'gh.notincat': ['カタログに {n} がありません', '{n} is not in the catalog'],
  'gh.fail': ['{n} の取得に失敗しました: {e}', 'Failed to fetch {n}: {e}'],
  'gh.fail.net': ['（ネットワーク接続を確認してください）', ' (check your network connection)'],
  'gh.dep': ['必要なプロジェクト {r} も入れます', 'Also installing the required project {r}'],
  'lib.nomain': ['{n} に起動できる .lua が見つかりません', 'No runnable .lua found in {n}'],
  'lib.noupdate': ['{n} はカタログにないため更新できません', '{n} is not in the catalog, so it cannot be updated'],
  'lib.nolua': ['{n} に .lua がありません', 'No .lua in {n}'],
  'lib.deleted': ['{n} を削除しました', 'Deleted {n}'],
  'imp.lua': ['{n} を dust/code/{b}/ に入れました', 'Added {n} to dust/code/{b}/'],
  'imp.audio': ['{n} を dust/audio/ に入れました', 'Added {n} to dust/audio/'],
  'imp.png': ['{n} を dust/data/images/ に入れました', 'Added {n} to dust/data/images/'],
  'imp.unsupported': ['未対応のファイル形式です: {n}', 'Unsupported file type: {n}'],
  'imp.fail': ['読み込みに失敗しました: {n} ({e})', 'Could not import {n} ({e})'],
  'imp.nozip': ['ZIP を開くライブラリを読み込めませんでした', 'Could not load the ZIP library'],
  'imp.empty': ['ZIP が空です', 'The ZIP is empty'],
  'imp.toobig': ['大きすぎるため除外: {p}', 'Skipped (too large): {p}'],
  'imp.opened': ['{p} を開きました。▶ 実行 で動きます', 'Opened {p}. Press ▶ Run to start it'],
  'log.runtime.fail': ['ランタイムを読み込めませんでした: {e}', 'Could not load the runtime: {e}'],
};
const KEY = 'norns-emu:lang';
let lang = null;
try { lang = localStorage.getItem(KEY); } catch (e) {}
if (lang !== 'ja' && lang !== 'en') lang = /^ja\b/i.test(navigator.language || '') ? 'ja' : 'en';
const listeners = [];
function t(key, vars) {
  const e = D[key];
  let s = e ? e[lang === 'en' ? 1 : 0] : key;
  if (vars) s = s.replace(/\{(\w+)\}/g, (m, k) => (vars[k] !== undefined ? String(vars[k]) : m));
  return s;
}
const manualUrl = () => (lang === 'en' ? 'manual-en.html' : 'manual.html');
function apply(root) {
  root = root || document;
  document.documentElement.lang = lang;
  root.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
  root.querySelectorAll('[data-i18n-html]').forEach(el => { el.innerHTML = t(el.dataset.i18nHtml, { m: manualUrl() }); });
  for (const attr of ['title', 'placeholder', 'aria-label']) {
    const k = 'i18n' + attr.replace(/(^|-)(\w)/g, (m, a, b) => b.toUpperCase());
    root.querySelectorAll('[data-' + 'i18n-' + attr + ']').forEach(el => { el.setAttribute(attr, t(el.dataset[k])); });
  }
  root.querySelectorAll('a[data-manual]').forEach(a => { a.href = manualUrl() + (a.dataset.manual || ''); });
}
function setLang(l) {
  if (l !== 'ja' && l !== 'en' || l === lang) return;
  lang = l;
  try { localStorage.setItem(KEY, l); } catch (e) {}
  apply();
  for (const f of listeners) { try { f(lang); } catch (e) {} }
}
window.I18N = { t, apply, setLang, get lang() { return lang; }, onChange: f => listeners.push(f), manualUrl };
window.T = t;
document.documentElement.lang = lang;
})();
