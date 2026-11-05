#!/usr/bin/env python3
"""Render the site's home page, build/home/index.html, served at the root.

The page is written for a reader with no context.  It says what the project
is in plain words, then works through one open guarantee: the rule, the
guarantee we want from it, the example that shows the case, and the question
it leaves.  Then it points each kind of reader to a page, says what the model
covers and what the guide leaves out, shows the status tiles of the progress
page with what each status means, the three questions at the top of "Decide
these first", what the model takes on trust, and a card for each part of the
site.  The progress page itself is at /progress/ (scripts/render_progress.py).

The worked guarantee is QUESTION below.  The build stops when it is no longer
open: pick another open guarantee with an example and a clear question.  Its
text comes from the model: the rule's EARS statement, the guarantee's
blueprint card, and the example's docstring, with the result Lean computes.
Every count comes from the build: the statuses from build/status.json and the
blueprint through scripts/graph_model.py, the requirements, criteria and
assumptions from build/status.json, and the survey's grades from the rows of
docs/one-id-survey.md.

  python3 scripts/render_home.py
"""

import html
import json
import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_survey import survey_rows  # noqa: E402
from graph_model import docstring_html  # noqa: E402
from render_progress import CSS, card_id, chip, decide_first, load, split_question, tiles_html  # noqa: E402
from render_status import blueprint_titles, field_label, humanize, inline, parse_value, plain  # noqa: E402
from site_nav import FAVICON, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

esc = html.escape

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "home" / "index.html"
STATUS = ROOT / "build" / "status.json"

# The open guarantee the page works through.
QUESTION = "Rules.OneId.matched_pair_same_traveler"

# What the guide puts out of scope: the survey entries, by blueprint label.
LEFT_OUT = ["def:c01", "def:c02", "def:c03"]

# IATA's own page about One ID.  The guide's address comes from the model's
# list of sources (Rules/Core/Sources.lean), through build/status.json.
ONE_ID = "https://www.iata.org/en/programs/passenger/one-id/"

# Sections of the review document, by their Verso tags, found through Verso's
# own lookup so a renamed chapter keeps working.
FIND = "review/find/?domain=Verso.Genre.Manual.section&name="

HOME_CSS = """
.parts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
.part { position: relative; display: flex; flex-direction: column; background: var(--surface); border: 1px solid var(--ring);
  border-radius: 10px; padding: 16px 18px 14px; transition: border-color .15s; }
.part:hover { border-color: color-mix(in srgb, var(--ready) 45%, var(--ring)); }
.part h3 { margin: 0 0 6px; font-size: 17px; color: var(--ink); }
.part h3 a, .part h3 a:visited { color: var(--ink); text-decoration: none; }
.part h3 a::after { content: ""; position: absolute; inset: 0; border-radius: 10px; }
.part h3 a:focus-visible::after { outline: 2px solid var(--ready); outline-offset: 2px; }
.part p { margin: 4px 0; color: var(--ink-2); }
.part strong { color: var(--ink); font-variant-numeric: tabular-nums; }
.part .more { position: relative; z-index: 1; display: flex; flex-wrap: wrap; gap: 4px 14px; font-size: 13.5px;
  margin-top: auto; padding-top: 10px; }
.top3 + .more { margin: 10px 0 0; font-size: 14px; }
.lede + .lede { margin-top: 0; }
.lede + .kicker { margin: 4px 0 0; }
.kicker a { color: inherit; }
.part p a { position: relative; z-index: 1; }
.worked h2 { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 12px; }
.worked h2 .chip { font-size: 13px; font-weight: 600; }
.worked-panel { background: var(--surface); border: 1px solid var(--ring); border-radius: 12px; padding: 4px 20px;
  max-width: 920px; }
.worked-panel .row { display: grid; grid-template-columns: 190px minmax(0, 1fr); gap: 16px; padding: 12px 0;
  border-top: 1px solid var(--hair); }
.worked-panel .row:first-child { border-top: 0; }
.worked-panel .label { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase;
  padding-top: 3px; }
.worked-panel .row p { margin: 0 0 4px; }
.worked-panel .result { border-left: 3px solid var(--critical); padding-left: 12px; }
.worked-panel .result dl { display: grid; grid-template-columns: auto 1fr; gap: 2px 14px; margin: 0 0 4px; }
.worked-panel .result dt { color: var(--ink-2); }
.worked-panel .result dd { margin: 0; font-weight: 600; font-variant-numeric: tabular-nums; }
.worked-panel .note { color: var(--muted); font-size: 13px; }
.worked-panel .ask { background: color-mix(in srgb, var(--warning) 14%, transparent); border-radius: 8px; padding: 8px 12px; }
.cta { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 20px; margin: 18px 0 0; }
.cta .button, .cta .button:visited { background: var(--ready); color: #fff; font-weight: 600; padding: 9px 16px; border-radius: 8px;
  text-decoration: none; }
.cta .button:hover { background: color-mix(in srgb, var(--ready) 88%, #000); }
.routes { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
.part .who { margin: 0 0 4px; font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); }
.part ul { margin: 4px 0; padding-left: 18px; color: var(--ink-2); }
.part li { margin: 3px 0; }
.part li a { position: relative; z-index: 1; }
@media (max-width: 900px) { .parts, .routes { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 600px) { .parts, .routes { grid-template-columns: minmax(0, 1fr); }
  .worked-panel .row { grid-template-columns: minmax(0, 1fr); gap: 4px; } }
"""


def plural(k, one, many):
    return f"<strong>{k}</strong> {one if k == 1 else many}"


def part(href, title, text, more=(), who=None):
    """A card.  With an address its title is a link that covers the card."""
    links = f'<p class="more">{" ".join(more)}</p>' if more else ""
    who = f'<p class="who">{who}</p>' if who else ""
    heading = f'<a href="{href}">{title}</a>' if href else title
    return f'<article class="part">{who}<h3>{heading}</h3>{text}{links}</article>'


def example_of(decls, theorem):
    """The example that shows the case: one that checks a criterion the
    theorem checks, as scripts/render_status.py finds it."""
    checks = set(theorem.get("checks", []))
    cases = sorted((d for d in decls.values() if d["kind"] == "case" and checks & set(d.get("checks", []))),
                   key=lambda d: d["name"])
    return cases[0] if cases else None


def unescaped(text):
    """Text from render_status.inline, without the escapes it adds for Verso."""
    return re.sub(r"\\([\\*_\[\]{}`#])", r"\1", text)


def computed(value):
    """An example's computed result as a list of labelled values."""
    try:
        v = parse_value(value)
    except (ValueError, IndexError, KeyError, TypeError):
        return f"<p><code>{esc(value)}</code></p>"
    if isinstance(v, dict) and "record" in v:
        rows = "".join(f"<dt>{esc(field_label(k))}</dt><dd>{esc(unescaped(inline(x)))}</dd>"
                       for k, x in v["record"].items())
        return f"<dl>{rows}</dl>"
    return f"<p>{esc(unescaped(inline(v)))}</p>"


def worked(m):
    """One open guarantee, worked through: the rule, the guarantee, the
    example and what the guide as written gives for it, and the question."""
    decls = m.decls
    theorem = decls.get(QUESTION)
    if not theorem or theorem["status"] != "open":
        sys.exit(f"scripts/render_home.py: {QUESTION} is no longer open; choose another open question as QUESTION")
    example = example_of(decls, theorem)
    rule = next((d for d in decls.values() if d.get("earsId") and
                 any(c["id"] in theorem["checks"] for c in d.get("criteria", []))), None)
    card = next((n for n in m.nodes if QUESTION in n["lean"]), None)
    if not example or not rule or not card:
        sys.exit(f"scripts/render_home.py: {QUESTION} needs an example, a rule whose criterion it checks, "
                 "and a blueprint card")
    q = split_question(card)
    question = q.get("question", "")
    if not question:
        sys.exit(f"scripts/render_home.py: the blueprint card of {QUESTION} has no open point")
    guarantee = re.sub(r"\s*Not proven\.$", "", " ".join(q["desc"]))
    paragraphs = [docstring_html(p) for p in (example.get("docstring") or "").split("\n\n") if p.strip()]
    # The example's Then paragraph says what happens; the computed result stands in for it.
    given = [p for p in paragraphs if p.startswith(("<strong>Given", "<strong>When"))]
    chapter = blueprint_titles().get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1]))
    chapter_href = FIND + quote(rule["earsId"].lower())
    rows = [
        ("The rule", f"<p>{esc(plain(rule['ears']))}</p>"),
        ("The guarantee we want", f"<p>{guarantee}</p>"),
        ("An example", "".join(f"<p>{p}</p>" for p in given)),
        ("What the guide as written gives",
         f'<div class="result">{computed(example.get("value") or "")}'
         '<p class="note">Lean computes this result from the rule on every build. The names are invented.</p></div>'),
        ("The question", f'<p class="ask">{question[:1].upper() + question[1:]}</p>'),
    ]
    panel = "".join(f'<div class="row"><div class="label">{k}</div><div>{v}</div></div>' for k, v in rows)
    return f"""<section class="worked">
<h2 id="example">{esc(card["title"])} {chip("open")}</h2>
<p class="sub">One guarantee from the model, worked through. It is still open: an example shows a case the guide as written
allows and the guarantee forbids, so someone who owns the standard has to say what the rule should be.</p>
<div class="worked-panel">{panel}</div>
<p class="cta"><a class="button" href="progress/#decide">See the questions to decide first</a>
<a href="{chapter_href}">Read “{esc(chapter)}” in the review document</a></p>
</section>"""


def covers(show, m, rules, criteria, guide):
    """Three cards: what is in Lean, what is surveyed, and what the guide leaves out."""
    proven = sum(1 for c in criteria if c.get("status") == "proven")
    open_ = sum(1 for c in criteria if c.get("status") == "open")
    candidates = [n for n in show if not n["lean"]]
    by_status = Counter(n["status"] for n in candidates)
    grades = Counter(r["grade"] for cid, r in survey_rows().items() if cid.startswith("C-"))
    left = []
    for label in LEFT_OUT:
        n = m.by.get(label)
        if not n:
            sys.exit(f"scripts/render_home.py: the blueprint has no node {label}; update LEFT_OUT")
        k = m.impact(label)["count"]
        left.append(f'<li><a href="progress/#{card_id(n)}">{esc(n["title"])}</a>: '
                    f'{k} {"card depends" if k == 1 else "cards depend"} on it</li>')
    return "".join([
        part("review/", "In Lean: the two credentials",
             f"<p>What a photoid and a boarding pass must contain, how long each stays valid, and how the two are "
             f"matched to one traveler (§4.1 of the guide). {plural(len(rules), 'requirement', 'requirements')} with "
             f"{plural(len(criteria), 'acceptance criterion', 'acceptance criteria')}: <strong>{proven}</strong> proven "
             f"and <strong>{open_}</strong> open.</p>"),
        part("progress/#next", "Surveyed: every other rule",
             f"<p>A survey graded {plural(sum(grades.values()), 'rule', 'rules')} of the guide by how clearly it is "
             f"stated: <strong>{grades['Clear']}</strong> clear, <strong>{grades['Vague']}</strong> vague and "
             f"<strong>{grades['Silent']}</strong> silent. The presentation of credentials to a relying party (§4.2) and "
             f"the requirements of §3 are candidates for Lean: {plural(by_status['decision'], 'needs', 'need')} a "
             f"decision first, {plural(by_status['source'], 'needs', 'need')} a source to be read, "
             f"{plural(by_status['ready'], 'is', 'are')} ready to build and "
             f"{plural(by_status['waiting'], 'waits', 'wait')} on others.</p>"),
        part(None, "Left out by the guide",
             f'<p>The guide puts three matters out of scope in <a href="{guide}">§1.4</a>. The model does not fill '
             "them in; it records which "
             f"guarantees each one blocks.</p><ul>{''.join(left)}</ul>"),
    ])


def page(show, m):
    decls = m.decls
    counts = {k: sum(1 for n in show if n["status"] == k) for k in ("open", "decision", "source")}
    in_lean = sum(1 for n in show if n["lean"])
    rules = [d for d in decls.values() if d.get("earsId")]
    criteria = [c for d in rules for c in d.get("criteria", [])]
    proven = sum(1 for c in criteria if c.get("status") == "proven")
    status = json.loads(STATUS.read_text())
    assumptions = status["assumptions"]
    relied = sum(1 for a in assumptions if a["usedBy"])
    confirmed = status["provenance"]["confirmed"]
    guide = next(s["url"] for s in status["sources"] if s["key"].startswith("tig-"))
    deps = sum(1 for n in m.nodes for u in n["uses"])
    lookup_count = len(m.ranking(lookup=True))
    confirmed_text = ("No rule has been confirmed by a subject matter expert yet." if confirmed == 0 else
                      f"{plural(confirmed, 'rule has', 'rules have')} been confirmed by a subject matter expert so far.")
    routes = "".join([
        part("progress/#decide", "Questions to answer",
             "<p>The open questions and the decisions, ranked by how much of the model each answer reaches. Each has "
             "an example or an open point you can answer from the guide.</p>",
             who="You know the guide"),
        part("review/", "Requirements and their checks",
             "<p>A chapter per requirement, with its acceptance criteria, the guarantees proven about it and the "
             "examples the build computes.</p>",
             who="You build wallets or verifiers"),
        part("progress/#next", "Every rule of the guide",
             "<p>Each rule from the survey as a card: what the guide says, how clearly, and what has to be decided "
             "before it can be modelled.</p>",
             who="You want the whole picture"),
        part("blueprint/", "Definitions and theorems",
             "<p>The model as numbered statements with the Lean name of each, and the graph of what depends on "
             "what.</p>",
             who="You work on the Lean"),
    ])
    parts = "".join([
        part("progress/", "Progress",
             f"<p>Every rule, guarantee and candidate rule with its status, grouped by area: "
             f"{plural(in_lean, 'card', 'cards')} in Lean and {plural(len(show) - in_lean, 'candidate', 'candidates')} "
             f"from the survey. Of these, {plural(counts['open'], 'is an open question', 'are open questions')}, "
             f"{plural(counts['decision'], 'candidate needs', 'candidates need')} a decision, "
             f"and {plural(counts['source'], 'needs', 'need')} a source to be read.</p>",
             ['<a href="progress/#decide">Decide these first</a>', '<a href="progress/#lookup">Look these up first</a>',
              '<a href="progress/#found">Open questions</a>',
              '<a href="progress/#today">In the model today</a>', '<a href="progress/#next">Candidates</a>']),
        part("review/", "Review document",
             f"<p>The rules in plain words, a chapter per requirement: {plural(len(rules), 'requirement', 'requirements')} "
             f"with {plural(len(criteria), 'acceptance criterion', 'acceptance criteria')}, <strong>{proven}</strong> of "
             "them proven. Each criterion shows the Lean that checks it and the examples the build computes.</p>",
             [f'<a href="{FIND}overview">How to read it</a>', f'<a href="{FIND}open-questions">Open questions</a>',
              f'<a href="{FIND}objects">Objects</a>', f'<a href="{FIND}assumptions">Assumptions</a>']),
        part("blueprint/", "Blueprint",
             f"<p>The model as numbered definitions and theorems, for the people who work on the Lean: "
             f"{plural(len(m.nodes), 'node', 'nodes')} with {plural(deps, 'dependency', 'dependencies')} between them, "
             "drawn as a graph and set as a PDF.</p>",
             ['<a href="blueprint/dep_graph_document.html">Dependency graph</a>',
              '<a href="blueprint/print.pdf">PDF</a>']),
        part("specs/README.md", "Specs and data",
             "<p>The requirements as specs in Kiro's layout, with acceptance criteria in EARS, and the same data as "
             "files a spreadsheet or a script can read.</p>",
             ['<a href="ears-criteria.csv">Acceptance criteria (CSV)</a>', '<a href="provenance.csv">Sources (CSV)</a>',
              '<a href="assumptions.csv">Assumptions (CSV)</a>', '<a href="ranking.json">Ranking (JSON)</a>']),
    ])
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{SITE_NAME}: One ID rules checked by Lean</title>
{FAVICON}
<style>{CSS}{HOME_CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar(None, "")}
<main>
<h1>Checking the rules of One ID travel credentials</h1>
<p class="lede"><a href="{ONE_ID}">One ID</a> is IATA's programme for a passenger journey without paper documents,
based on digital identity and biometric recognition. Its <a href="{guide}">Technical Implementation Guide</a> describes
how a passenger travels with digital credentials. A wallet on the passenger's phone holds a
<a href="{FIND}oid-101">photoid</a>, with identity data and a face image taken from the passport, and a
<a href="{FIND}oid-103">boarding pass</a>. It presents them to an airline or an airport, which checks them and may match
the passenger's face. The guide is written in prose and builds on
<a href="{FIND}assumptions">ISO, OpenID and W3C specifications</a>, and prose leaves gaps that two implementers can fill
differently.</p>
<p class="lede">This project writes each rule of the guide as code in <a href="https://lean-lang.org">Lean</a>, a language
that checks proofs. A guarantee that Lean proves holds in every possible case, under
<a href="{FIND}overview">every way the guide can be read</a>. Where the guide as written does not give a guarantee, the gap
becomes <a href="progress/#decide">a question for the people who own the standard</a>, with an example that shows it.</p>
<p class="kicker">A proof of concept built from <a href="{guide}">version 26.3 of the guide</a>, not affiliated with IATA.
This page is generated from the model on every build.</p>

{worked(m)}

<h2 id="start">Where to start</h2>
<p class="sub">Each page shows the same model from a different side. Pick the one that fits what you do.</p>
<div class="routes">{routes}</div>

<h2 id="covers">What the model covers</h2>
<p class="sub">The work goes in milestones: every rule of the guide is surveyed first, then one area at a time is written in
Lean. The credentials are in Lean now. The presentation flows come next.</p>
<div class="parts">{covers(show, m, rules, criteria, guide)}</div>

<h2 id="status">The model's status today</h2>
<p class="sub">The model is a set of cards: rules written in Lean, guarantees about those rules, and candidate rules from
the survey. A proven guarantee holds for every input and every reading of the guide. An open question is a guarantee the
guide as written does not give. A candidate rule needs a decision from the people who own the standard, needs a source
to be read because its question is about a specification the guide cites, is ready to build, or waits on other rules.</p>
{tiles_html(show)}

<h2 id="decide-top">Decide these first</h2>
<p class="sub">The three open questions and decisions with the most cards depending on them, so an answer reaches furthest.</p>
<div class="top3">{decide_first(m, 3, "progress/")}</div>
<p class="more"><a href="progress/#decide">See the top ten on the progress page</a> ·
<a href="progress/#lookup">{lookup_count} {"question" if lookup_count == 1 else "questions"} a cited specification would settle</a></p>

<h2 id="trust">What the model takes on trust</h2>
<p class="sub">The guide refers to ISO, OpenID, W3C, IETF, ICAO and IATA specifications that were not read for this project.
The model takes from each only what the guide says about it: {plural(len(assumptions), 'dependency is', 'dependencies are')}
recorded with the clause the guide cites, and {plural(relied, 'is', 'are')} relied on by rules in the model so far.
Where a rule needs the content of an external table or format, that content is a parameter, and a guarantee is proven only
if it holds whatever the content is. The tables and the boarding pass format in the examples are invented stand-ins.
{confirmed_text}
<a href="{FIND}assumptions">Read the list of assumptions</a>.</p>

<h2 id="parts">Every part of the site</h2>
<p class="sub">The site name in the bar at the top of every page leads back here.</p>
<div class="parts">{parts}</div>

<footer>Generated by <code>scripts/render_home.py</code> from the Lean build, the blueprint and the survey.
Counts are computed; nothing on this page is typed by hand.</footer>
</main>
</body>
</html>
"""


def main():
    show, m = load()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(show, m))
    print(f"rendered {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
