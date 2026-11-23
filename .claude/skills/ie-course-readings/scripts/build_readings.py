#!/usr/bin/env python3
"""Build readings.csv for one IE course from its syllabus PDF (+ optional link list).

Usage:
  python3 -I build_readings.py SYLLABUS.pdf [LINKS.json] > readings.csv

SYLLABUS.pdf : the syllabus "PDF Version" from ie-lti-syllabus.ie.edu
LINKS.json   : JSON array [{"t": text, "h": href}, ...] copied from the syllabus
               page with the console one-liner in SKILL.md. Adds readings the PDF
               leaves out (IE library / WorldCat items, public articles).

Output columns (pipe-separated): Session|Folder|Type|Code|Title
Review the Folder names afterwards: they come from the syllabus headings and are
often long or in capitals.
"""
import json, re, subprocess, sys, unicodedata
from urllib.parse import urlparse

TYPES = {'W.P.': 'OPT', 'R.A.': 'RA', 'P.C.': 'PC', 'T.N.': 'TN', 'PRACTICAL CASE': 'PC',
         'TECHNICAL NOTE': 'TN', 'ARTICLE': 'RA', 'BOOK CHAPTER': 'BC', 'CASE': 'PC',
         'MULTIMEDIA': 'MM', 'VIDEO': 'MM', 'EXERCISE': 'EX', 'SIMULATION': 'SIM'}
START = re.compile(r'^\s*([A-Z]\.[A-Z]\.|[A-Z][A-Za-z]+(?: [A-Za-z]+){0,2})\s*:\s*\S')
MAT = re.compile(r'^\s*([A-Z]\.[A-Z]\.|[A-Z][A-Za-z]+(?: [A-Za-z]+){0,2})\s*:\s*(.+?)\s*'
                 r'\((?:([A-Z0-9]+)-[A-Z0-9-]*ENG[A-Z0-9-]*|(N/C))\)\s*$')
SESSION = re.compile(r'^\s*SESSION\s+(\d+)\b', re.I)


def ascii_text(s):
    s = s.replace('’', "'").replace('‘', "'").replace('“', '"').replace('”', '"')
    s = s.replace('–', '-').replace('—', '-')
    return unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()


def tidy(title):
    title = ascii_text(title).strip()
    title = re.sub(r'\s*:\s*', ' - ', title)          # ':' is not allowed in Windows names
    title = title.replace('?', '').replace('/', '-').replace('|', '-')
    if title.isupper():
        title = title.title()
    return re.sub(r'\s+', ' ', title).strip(' -')


def norm(s):
    return re.sub(r'[^a-z0-9]', '', ascii_text(s).lower())


def parse_pdf(path):
    text = subprocess.run(['pdftotext', '-layout', path, '-'], capture_output=True, text=True, check=True).stdout
    lines = [l.rstrip() for l in text.splitlines()]
    sessions, cur, i = {}, None, 0
    out = []
    while i < len(lines):
        l = lines[i]
        m = SESSION.match(l)
        if m:
            cur = int(m.group(1))
            sessions[cur] = ''
            # heading = first all-caps line after the header that isn't a topics block
            for j in range(i + 1, min(i + 25, len(lines))):
                s = lines[j].strip()
                if not s or s.lower().startswith('sustainability') or s.startswith('-'):
                    continue
                if SESSION.match(s):
                    break
                if s.isupper() and len(s) > 6:
                    nxt = lines[j + 1].strip() if j + 1 < len(lines) else ''
                    sessions[cur] = s + (' ' + nxt if nxt.isupper() and not SESSION.match(nxt) else '')
                    break
            i += 1
            continue
        # material lines can wrap; join up to 3 lines until "(CODE-...-ENG)" or "(N/C)" closes it
        if cur is not None and START.match(l):
            joined, used = l, 0
            while not MAT.match(joined) and used < 3 and i + used + 1 < len(lines) \
                    and lines[i + used + 1].strip() and not START.match(lines[i + used + 1]):
                used += 1
                joined += ' ' + lines[i + used].strip()
            mm = MAT.match(joined)
            if mm:
                kind = TYPES.get(mm.group(1).strip().upper(), 'RA')
                code = mm.group(3) or ''                 # '' = not in coursepack (N/C): code comes from the link
                out.append({'Session': cur, 'Type': 'LIB' if not code and kind == 'RA' else kind,
                            'Code': code, 'Title': tidy(mm.group(2))})
                i += used
        i += 1
    return sessions, out


def link_code(h, title):
    host = urlparse(h).hostname or ''
    if 'worldcat.org' in host:
        m = re.search(r'/oclc/(\d+)', h)
        return (m.group(1) if m else 'LIB'), 'LIB'
    label = host.replace('www.', '').split('.')[0]
    return (label.upper() if len(label) <= 5 else label.capitalize()), 'OPT'


def add_links(items, links):
    """Give N/C items a code from their link; add linked readings the PDF missed."""
    by_title = {norm(r['Title']): r for r in items}
    codes = {r['Code'] for r in items if r['Code']}
    cur = items[0]['Session'] if items else 1

    def unique(code):
        base, n = code, 2
        while code in codes:
            code, n = f'{base}{n}', n + 1
        codes.add(code)
        return code

    for a in links:
        t, h = (a.get('t') or '').strip(), a.get('h') or ''
        host = urlparse(h).hostname or ''
        hit = by_title.get(norm(tidy(t))) if t else None
        if hit:
            cur = hit['Session']
            if not hit['Code'] and 'hbsp.harvard.edu' not in host and 'ie.edu' not in host:
                hit['Code'], kind = link_code(h, t)
                hit['Code'], hit['Type'] = unique(hit['Code']), kind
            continue
        if not t or len(t) < 8 or h.startswith('mailto:') or host.endswith('ie.edu') or 'hbsp.harvard.edu' in host:
            continue
        code, kind = link_code(h, t)
        items.append({'Session': cur, 'Type': kind, 'Code': unique(code), 'Title': tidy(t)})
    for n, r in enumerate([r for r in items if not r['Code']], 1):
        r['Code'] = unique(f'NC{n}')                   # no link found: placeholder code
    return items


def main():
    sessions, items = parse_pdf(sys.argv[1])
    links = json.load(open(sys.argv[2], encoding='utf-8')) if len(sys.argv) > 2 else []
    items = add_links(items, links)
    items.sort(key=lambda r: r['Session'])
    print('Session|Folder|Type|Code|Title')
    for r in items:
        head = tidy(sessions.get(r['Session'], '') or f"Session {r['Session']}")
        print(f"{r['Session']}|S{r['Session']:02d} - {head}|{r['Type']}|{r['Code']}|{r['Title']}")
    print(f'{len(items)} readings in {len({r["Session"] for r in items})} sessions', file=sys.stderr)


if __name__ == '__main__':
    main()
