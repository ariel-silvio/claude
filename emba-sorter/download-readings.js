// Paste into the browser Console (F12) on the course's syllabus page
// (ie-lti-syllabus.ie.edu). Opens every Harvard coursepack reading, one
// every 8 seconds. With Edge set to "Always download PDF files", each one
// lands in Downloads; then run Sort-MPDE.ps1 to rename and file them.
(() => {
  const links = [...new Set([...document.querySelectorAll('a[href*="hbsp.harvard.edu/tu/"]')].map(a => a.href))];
  console.log(`Found ${links.length} Harvard readings. One every 8 s, about ${Math.ceil(links.length * 8 / 60)} min.`);
  let i = 0;
  const timer = setInterval(() => {
    if (i >= links.length) { clearInterval(timer); console.log('Done. Now run Sort-MPDE.ps1.'); return; }
    const w = window.open(links[i], '_blank');
    console.log(`${i + 1}/${links.length}`, links[i], w ? '' : '<- BLOCKED: allow pop-ups for this site and run again');
    i++;
  }, 8000);
})();
