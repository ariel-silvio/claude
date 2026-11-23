---
name: ie-course-readings
description: Download and organise all readings of an IE Business School EMBA course (Harvard coursepack PDFs, IE library and other syllabus readings) into session folders on the user's Windows laptop. Use when the user shares an IE syllabus (PDF or ie-lti-syllabus.ie.edu page) and wants its readings, cases or articles downloaded, renamed, filed, or checked for missing ones; or says "do the same for another course".
---

# IE course readings: download, rename, file, check

Proven on "Managing People in Digital Era" (31 readings, 21 auto-downloaded) and
"Strategy Design" (15 readings, all 11 coursepack PDFs filed on the first run). The
user is on a Windows company laptop with Edge, Documents in OneDrive, and PowerShell
script execution blocked. Claude runs in the cloud and cannot reach IE, Harvard or
the laptop: the user runs the browser and PowerShell steps; Claude builds the files.

## Files in `scripts/`
- `build_readings.py`: syllabus PDF (+ link list) -> `readings.csv` (Claude runs it).
- `Sort-Readings.ps1`: generic sorter + checklist, reads `readings.csv` (user runs it).
- `download-auto.js`: Console script for the syllabus page, downloads every Harvard
  coursepack PDF one per minute (user runs it).

## Steps

1. **Get two inputs from the user**
   - The syllabus PDF: the "PDF Version" button at the top of the syllabus page.
   - The link list. On the syllabus page: F12, Console (type `allow pasting` if Edge
     asks), paste and paste the copied result back to Claude:
     ```js
     copy(JSON.stringify([...document.querySelectorAll('a')].map(a=>({t:a.innerText.trim().slice(0,100),h:a.href})).filter(x=>x.h&&!x.h.startsWith('javascript')),null,1))
     ```
     Save it as `links.json` in the scratchpad.

2. **Build the reading list**
   ```bash
   python3 -I scripts/build_readings.py SYLLABUS.pdf links.json > readings.csv
   ```
   Then review `readings.csv` by hand:
   - Shorten the `Folder` names (e.g. `S03 - Getting the Talent You Need`); keep the `Sxx - ` prefix.
   - Codes `NC1`, `NC2`... are readings with no link found; give them a short code.
   - Session headings come from the PDF; check none are empty or wrong.
   - Count: coursepack items (`-PDF-ENG`) download automatically; `-HTM-`, IE `getDoc`,
     `LIB` (IE library / WorldCat) and `OPT` (public web pages) are manual.

3. **Deliver** `readings.csv`, plus `Sort-Readings.ps1` and `download-auto.js` the
   first time (send with SendUserFile; also commit to the repo branch). The user saves
   `readings.csv` and `Sort-Readings.ps1` in the course folder, e.g.
   `...\OneDrive - <company>\Documents\2. My Development\EMBA\<n> <Course>`.
   Ask once where they keep the course and use that folder.

4. **User downloads** (tell them exactly this)
   - One-time Edge setup, listed at the top of `download-auto.js`: always download PDFs,
     allow pop-ups for `ie-lti-syllabus.ie.edu`, allow automatic downloads for
     `hbsp.harvard.edu` and `services.hbsp.harvard.edu`. Without the last one Edge
     stops after a few files ("site is downloading multiple files").
   - Open the course syllabus, F12, Console, paste `download-auto.js`. One reading
     per minute; set `GAP = 120` on slow internet. Keep the tab open.
   - Harvard names files `<CODE>-PDF-ENG.pdf`, so matching is exact.

5. **User sorts and checks**, in PowerShell, from the course folder:
   ```powershell
   cd "<course folder>"
   Unblock-File .\Sort-Readings.ps1
   & ([scriptblock]::Create((Get-Content .\Sort-Readings.ps1 -Raw)))
   ```
   - The `scriptblock` form avoids "not digitally signed" errors; `-File` and
     double-click do not work on the company laptop.
   - `cd` paths with spaces need quotes.
   - Checklist only: add `-Check`. It prints a `const DONE = [...]` line to paste into
     `download-auto.js` for a rerun that fetches only what is missing.

6. **Manual leftovers**: user saves each file into Downloads with the code in the
   name (e.g. `8926 Boomerang.pdf`, `McKinsey CEO guide.pdf`), then reruns step 5.
   Web pages and `-HTM-` cases: Print > Save as PDF. Library items: open the WorldCat
   link, log in, download.

## Gotchas learned
- Do not open readings faster than one per minute: on slow connections downloads pile
  up and Edge blocks them. Never parallelise.
- Harvard `tu/` links redirect to `services.hbsp.harvard.edu/api/courses/<id>/items/<CODE>-PDF-ENG/...`,
  a raw PDF; a console script there sees no page elements.
- A script on the syllabus page cannot fetch Harvard files (cross-site), so downloads
  must go through opened tabs, not `fetch`.
- `-HTM-ENG` items share one `hbsp.harvard.edu/import/<course>` link: not downloadable.
- Leave the user's own folders (e.g. `Session 1`, `Session 2 - Forum`) alone; the
  checklist searches them too, so files there count if the code is in the name.
- Coursepack and library files are licensed for the user's own study: don't suggest
  sharing them or bypassing viewer-only items.
