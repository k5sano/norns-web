/* Shows the latest commit of the repository in the footer.
   One GitHub API call, cached for six hours so it does not eat into the install budget. */
(() => {
'use strict';
const REPO = 'k5sano/norns-web';
const KEY = 'norns-emu:repo-commit';
const TTL = 6 * 3600 * 1000;
const el = document.getElementById('repoVersion');
if (!el) return;
let info = null;
function render() {
  if (!info) { el.hidden = true; return; }
  const d = new Date(info.date);
  const date = isNaN(d) ? info.date : d.toLocaleDateString(window.I18N && window.I18N.lang === 'en' ? 'en-US' : 'ja-JP', { year: 'numeric', month: 'short', day: 'numeric' });
  el.textContent = '';
  el.append(document.createTextNode((window.T ? T('repo.updated', { d: date }) : date) + ' · '));
  const a = document.createElement('a');
  a.href = `https://github.com/${REPO}/commit/${info.sha}`;
  a.target = '_blank'; a.rel = 'noopener';
  a.textContent = info.sha.slice(0, 7);
  if (info.msg) a.title = info.msg;
  el.append(a);
  el.hidden = false;
}
try { const c = JSON.parse(localStorage.getItem(KEY) || 'null'); if (c && c.sha) info = c; } catch (e) {}
render();
if (!info || !info.at || Date.now() - info.at > TTL) {
  fetch(`https://api.github.com/repos/${REPO}/commits/main`, { headers: { Accept: 'application/vnd.github+json' } })
    .then(r => (r.ok ? r.json() : null))
    .then(j => {
      if (!j || !j.sha) return;
      info = { sha: j.sha, date: j.commit && (j.commit.committer || j.commit.author || {}).date, msg: j.commit && j.commit.message.split('\n')[0], at: Date.now() };
      try { localStorage.setItem(KEY, JSON.stringify(info)); } catch (e) {}
      render();
    })
    .catch(() => {});
}
if (window.I18N) window.I18N.onChange(render);
})();
