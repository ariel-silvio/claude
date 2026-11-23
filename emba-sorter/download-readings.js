// Paste into the browser Console (F12) on the course's syllabus page
// (ie-lti-syllabus.ie.edu). Adds a panel listing every Harvard coursepack
// reading. Click a row (or "Next") to download it: one click per reading,
// nothing gets blocked. Readings whose codes are in DONE are skipped.
// With Edge set to "Always download PDF files", each lands in Downloads;
// then run Sort-MPDE.ps1 to rename and file them.
(() => {
  const DONE = ['620066', 'F1407E', 'HK1164', 'H07GYQ', '818077'];   // already downloaded
  const seen = new Set();
  const items = [...document.querySelectorAll('a[href*="hbsp.harvard.edu/tu/"]')]
    .filter(a => !seen.has(a.href) && seen.add(a.href))
    .map(a => {
      let t = '', n = a.nextSibling;                 // text right after the link: " (620066-PDF-ENG)"
      while (n && t.length < 40) { t += n.textContent || ''; n = n.nextSibling; }
      const m = t.match(/\(([A-Z0-9]+)-[A-Z]+-ENG\)/i);
      return { title: a.innerText.trim(), href: a.href, code: m ? m[1] : '' };
    })
    .filter(x => !DONE.includes(x.code));

  document.getElementById('dl-panel')?.remove();
  const p = document.createElement('div');
  p.id = 'dl-panel';
  p.style.cssText = 'position:fixed;top:10px;right:10px;z-index:99999;width:420px;max-height:90vh;overflow:auto;background:#fff;border:2px solid #1d0f6b;border-radius:8px;padding:10px;font:13px sans-serif;box-shadow:0 4px 16px #0004';
  p.innerHTML = `<b>${items.length} readings to download</b> <button id="dl-next" style="float:right">Next ▶</button><button id="dl-x" style="float:right;margin-right:6px">✕</button><div style="clear:both"></div>`;
  items.forEach((x, i) => {
    const r = document.createElement('div');
    r.textContent = `${i + 1}. ${x.title} ${x.code ? '(' + x.code + ')' : ''}`;
    r.style.cssText = 'padding:5px;margin-top:4px;border-radius:4px;cursor:pointer;background:#eef';
    r.onclick = () => { window.open(x.href, '_blank'); x.done = true; r.style.background = '#cfc'; r.textContent = '✓ ' + r.textContent.replace(/^✓ /, ''); };
    x.row = r;
    p.appendChild(r);
  });
  document.body.appendChild(p);
  p.querySelector('#dl-x').onclick = () => p.remove();
  p.querySelector('#dl-next').onclick = () => { const n = items.find(x => !x.done); if (n) n.row.click(); else alert('All done. Now run Sort-MPDE.ps1.'); };
})();
