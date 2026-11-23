// AUTOMATIC version. Paste into the Console (F12) on the syllabus page.
// Needs (once): edge://settings/content/pdfDocuments -> "Always download PDF files" ON
//               edge://settings/content/popups -> Allow -> https://ie-lti-syllabus.ie.edu
// Opens one Harvard reading every GAP seconds, reusing ONE extra tab, and skips
// codes in DONE. A small box at the top-right shows progress and has a Stop button.
(() => {
  const GAP = 60;                                                    // seconds between readings (slow internet: keep 60+)
  const DONE = ['620066', 'F1407E', 'HK1164', 'H07GYQ', '818077'];   // already downloaded
  const seen = new Set();
  const items = [...document.querySelectorAll('a[href*="hbsp.harvard.edu/tu/"]')]
    .filter(a => !seen.has(a.href) && seen.add(a.href))
    .map(a => {
      let t = '', n = a.nextSibling;                                 // text after the link: " (620066-PDF-ENG)"
      while (n && t.length < 40) { t += n.textContent || ''; n = n.nextSibling; }
      const m = t.match(/\(([A-Z0-9]+)-[A-Z]+-ENG\)/i);
      return { title: a.innerText.trim(), href: a.href, code: m ? m[1] : '' };
    })
    .filter(x => !DONE.includes(x.code));

  document.getElementById('dl-box')?.remove();
  const box = document.createElement('div');
  box.id = 'dl-box';
  box.style.cssText = 'position:fixed;top:10px;right:10px;z-index:99999;width:380px;background:#fff;border:2px solid #1d0f6b;border-radius:8px;padding:10px;font:13px sans-serif;box-shadow:0 4px 16px #0004';
  box.innerHTML = '<button id="dl-stop" style="float:right">Stop</button><div id="dl-msg"></div>';
  document.body.appendChild(box);
  const msg = box.querySelector('#dl-msg');
  let i = 0, timer = null;
  box.querySelector('#dl-stop').onclick = () => { clearTimeout(timer); msg.innerHTML += '<br><b>Stopped.</b>'; };

  const next = () => {
    if (i >= items.length) { msg.innerHTML = `<b>All ${items.length} opened.</b><br>Wait for Edge's downloads to finish, then run Sort-MPDE.ps1.`; return; }
    const x = items[i];
    const w = window.open(x.href, 'hbsp_dl');                         // same extra tab every time
    if (!w) { msg.innerHTML = '<b style="color:#b00">Pop-up blocked.</b> Allow pop-ups for this site (see top of script) and paste again.'; return; }
    i++;
    msg.innerHTML = `<b>${i}/${items.length}</b> ${x.title} (${x.code})<br>Next in ${GAP}s. Keep this tab open.`;
    console.log(`${i}/${items.length}`, x.code, x.title);
    timer = setTimeout(next, GAP * 1000);
  };
  console.log(`${items.length} readings to download, one every ${GAP}s (~${Math.ceil(items.length * GAP / 60)} min).`);
  next();
})();
