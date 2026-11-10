#!/usr/bin/env python3
"""The bar at the top of every page: the site name and links to its parts.

The home page and the progress page build their bar from `topbar()`.  The
site name leads to the home page (scripts/render_home.py).  Run as a script, this adds the same bar to the blueprint's pages
after leanblueprint has written them:

  python3 scripts/site_nav.py site/blueprint

The review document gets the same bar from Review/review.js and
Review/review.css, since Verso builds its own header.
"""

import re
import sys
from pathlib import Path

SITE_NAME = "Verified ID"

# The site's mark: an identity card, in the text color so it follows the
# theme.  Review/review.js repeats the path for the review document's bar.
MARK_PATH = ("M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zm4 3.5a2.25 2.25 0 1 0 0 4.5"
             "a2.25 2.25 0 0 0 0-4.5zM4.5 16.5h7c0-1.9-1.6-3-3.5-3s-3.5 1.1-3.5 3zM14 9v1.5h5.5V9zm0 3.5V14h4v-1.5z")
MARK_SVG = (f'<svg class="mark" viewBox="0 0 24 24" aria-hidden="true">'
            f'<path fill="currentColor" fill-rule="evenodd" d="{MARK_PATH}"/></svg>')

# The same mark as the browser tab's icon, in a blue that reads on light and
# dark tab bars.
FAVICON = ('<link rel="icon" href="data:image/svg+xml,'
           + "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E"
           + f"%3Cpath fill='%232a78d6' fill-rule='evenodd' d='{MARK_PATH}'/%3E%3C/svg%3E"
           + '">')

# Each link's path from the site root.  The site name leads home.  The
# blueprint is for the people who work on the Lean, so it is linked from the
# home page and the review document and has no place in the bar, as in
# verified-air.
LINKS = [
    ("Progress", "progress/"),
    ("Review document", "review/"),
]

# The colors fall back to the light theme, so the bar is light on pages that
# define no theme of their own, such as the blueprint's.
TOPBAR_CSS = """
.site-topbar { display: flex; align-items: center; justify-content: flex-start; gap: 24px; padding: 0 28px; height: 48px;
  box-sizing: border-box;
  background: var(--surface, #fcfcfb); border-bottom: 1px solid var(--ring, rgba(11,11,11,0.10));
  font: 14px/1.4 system-ui, -apple-system, "Segoe UI", sans-serif; flex-shrink: 0; }
.site-topbar .brand, .site-topbar .brand:visited { display: inline-flex; align-items: center; gap: 8px;
  font-weight: 650; font-size: 16px; color: var(--ink, #0b0b0b); text-decoration: none; white-space: nowrap; }
.site-topbar .brand .mark { width: 20px; height: 20px; flex: none; }
.site-topbar a { margin: 0; }
/* On a narrow screen the links scroll sideways. */
.site-topbar .site-nav { display: flex; gap: 18px; white-space: nowrap; min-width: 0; overflow-x: auto; scrollbar-width: none; }
.site-topbar .site-nav a, .site-topbar .site-nav a:visited, .site-topbar .local, .site-topbar .local:visited {
  color: var(--ink-2, #52514e); text-decoration: none; }
.site-topbar .site-nav a:hover, .site-topbar .local:hover { color: var(--ink, #0b0b0b); }
.site-topbar .site-nav a[aria-current] { color: var(--ink, #0b0b0b); font-weight: 600; }
.site-topbar .local { margin-left: auto; white-space: nowrap; }
/* On a phone the bar keeps the mark, which leads home, and drops the name. */
@media (max-width: 700px) { .site-topbar { gap: 16px; padding: 0 16px; } .site-topbar .brand .name { display: none; } }
"""


def topbar(current, root, extra=""):
    """The bar's HTML.  `root` is the relative path from the page to the site
    root; `extra` goes inside the bar after the links."""
    links = []
    for name, path in LINKS:
        href = path if path.startswith("http") else (root + path or "./")
        cur = ' aria-current="page"' if name == current else ""
        links.append(f'<a href="{href}"{cur}>{name}</a>')
    return (f'<header class="site-topbar"><a class="brand" href="{root or "./"}" aria-label="{SITE_NAME}, home">'
            f'{MARK_SVG}<span class="name">{SITE_NAME}</span></a>'
            f'<nav class="site-nav" aria-label="Site">{"".join(links)}</nav>{extra}</header>')


BLUEPRINT_HEADER = re.compile(r"<body>\s*<header>(.*?)</header>", re.S)


def add_to_blueprint(directory):
    """Replace the header of each blueprint page with the site's bar, keeping
    the page's own table-of-contents button."""
    for page in sorted(Path(directory).glob("*.html")):
        html = page.read_text()
        if "site-topbar" in html:
            continue
        m = BLUEPRINT_HEADER.search(html)
        if not m:
            continue
        toggle = re.search(r'<svg\s+id="toc-toggle".*?</svg>', m.group(1), re.S)
        # The dependency graph's header links back to the chapters; keep that link.
        extra = '<a class="local" href="index.html">Blueprint chapters</a>' if not toggle else ""
        bar = topbar(None, "../", extra)
        if toggle:
            # The button opens the blueprint's table of contents; it stays first.
            bar = bar.replace('<header class="site-topbar">', '<header class="site-topbar">' + toggle.group(0), 1)
        html = html[:m.start()] + "<body>\n" + bar + html[m.end():]
        style = f"<style>{TOPBAR_CSS}.site-topbar #toc-toggle {{ cursor: pointer; flex-shrink: 0; }}</style>"
        html = html.replace("</head>", FAVICON + style + "</head>", 1)
        page.write_text(html)


if __name__ == "__main__":
    add_to_blueprint(sys.argv[1] if len(sys.argv) > 1 else "site/blueprint")
