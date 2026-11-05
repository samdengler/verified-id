#!/usr/bin/env python3
"""Render the computed status into both review layers.

Reads build/status.json (written by `lake exe status`) and writes:

  blueprint/src/content.generated.tex   content.tex with \\leanok added from the build
  blueprint/src/ears.generated.tex      the EARS table as a blueprint section
  Review/Review/Generated/OID10n.lean       Verso chapter per requirement: the rule, how each
                                            criterion is checked, its guarantees and examples
  Review/Review/Generated/Questions.lean    Verso chapter: every open guarantee, as a question
  Review/Review/Generated/Assumptions.lean  Verso chapter: what the model takes from external specifications
  Review/Review/Generated/Ears.lean         Verso chapter: the EARS table
  .kiro/specs/<spec>/requirements.md        one requirement spec per module that holds rules
  .kiro/specs/README.md                     index of the specs, with every criterion's status

The .kiro/specs files are committed so they can be read on GitHub and opened
in Kiro; CI fails if the committed copies differ from what this script writes.

Nothing here decides a status.  Every status and example value comes from
status.json, which the status executable computes from the compiled Lean.
"""

import datetime
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "build" / "status.json"
BLUEPRINT = ROOT / "blueprint" / "src"
GENERATED = ROOT / "Review" / "Review" / "Generated"
SPECS = ROOT / ".kiro" / "specs"
REPO = "https://github.com/samdengler/verified-id/blob/main"

# Every open guarantee gets a section in the generated questions chapter.
QUESTIONS_TITLE = "Open questions"

# A survey candidate's or candidate guarantee's ID at the end of a blueprint title.
CANDIDATE_ID = r"\((?:C|G)-\d+\)"

DONE = {"definition", "proven"}

ENV_RE = re.compile(
    r"\\begin\{(definition|theorem|lemma|proposition|corollary|proof)\}(.*?)\\end\{\1\}",
    re.S,
)
LEAN_RE = re.compile(r"\\lean\{([^}]*)\}")


def load_status():
    if not STATUS.exists():
        sys.exit(f"{STATUS} not found; run `lake exe status` first")
    data = json.loads(STATUS.read_text())
    return {d["name"]: d for d in data["declarations"]}


def load_assumptions():
    """The assumptions about external specifications, by key, with the declarations that rely on each."""
    return {a["key"]: a for a in json.loads(STATUS.read_text())["assumptions"]}


def load_sources():
    """The sources the rules may cite, by key, as the status executable lists them."""
    return {s["key"]: s for s in json.loads(STATUS.read_text())["sources"]}


# How a confirmation was made, in words.
METHOD_TEXT = {"sme": "subject matter expert", "data": "production data", "crosscheck": "independent source"}

# A rule's provenance, as the status executable computes it, in words.
PROVENANCE_TEXT = {
    "confirmed": "confirmed",
    "out of date": "confirmed but out of date",
    "sourced": "written from a source",
    "assumed": "assumed by the modeller",
}


def rule_sources(d, sources):
    """The sources a rule names with @[source], in the order it names them."""
    return [sources[k] for k in d.get("sources", [])]


def confirmation_text(d):
    """One or two sentences on whether anyone outside the model confirmed a rule."""
    c = d.get("confirmation")
    p = d.get("provenance")
    if c:
        said = f"Confirmed on {c['date']} by {c['who']} ({METHOD_TEXT[c['method']]}): {c['note'].rstrip('.')}."
        if p == "out of date":
            said += " The rule changed after that, so the confirmation is out of date."
        return said
    if p == "assumed":
        return "Not confirmed. The modeller wrote this rule where no source states it."
    return "Not confirmed yet."


def rule_name(name):
    """A rule's Lean name without the model's namespace: Photoid.violations."""
    return re.sub(r"^Rules\.(?:OneId|Core)\.", "", name)


def ears_rows(decls):
    """One row per declaration with an EARS statement, ordered by ID then name."""
    rows = [d for d in decls.values() if d.get("ears")]
    return sorted(rows, key=lambda d: (d.get("earsId") or "~", d["name"]))


def proven_by(d, decls):
    names = d.get("provenBy") or []
    out = []
    for n in names:
        short = n.rsplit(".", 1)[-1]
        status = decls.get(n, {}).get("status")
        out.append((n, short, status))
    return out


# ---------------------------------------------------------------- blueprint


AREA_INPUT_RE = re.compile(r"\\input\{(areas/[^}]+)\}")


def read_blueprint(read=None):
    """content.tex with each \\input{areas/...} replaced by that file's text.

    The candidate rules live in one file per area under blueprint/src/areas/,
    so that work on different areas does not edit the same file.  `read`
    reads a path relative to blueprint/src; by default, from the working
    tree (scripts/graph_history.py passes one that reads an earlier commit)."""
    read = read or (lambda rel: (BLUEPRINT / rel).read_text())
    src = read("content.tex")
    return AREA_INPUT_RE.sub(lambda m: read(m.group(1) if m.group(1).endswith(".tex") else m.group(1) + ".tex"), src)


def render_content(decls):
    src = read_blueprint()
    uncommented = "\n".join(line.split("%", 1)[0] for line in src.splitlines())
    if "\\leanok" in uncommented:
        sys.exit("content.tex must not contain \\leanok; the build adds it")
    last_theorem_done = None
    missing = []

    def replace(m):
        nonlocal last_theorem_done
        env, body = m.group(1), m.group(2)
        if env == "proof":
            done = last_theorem_done
            last_theorem_done = None
        else:
            names = [n.strip() for lm in LEAN_RE.finditer(body) for n in lm.group(1).split(",")]
            names = [n for n in names if n]
            for n in names:
                if n not in decls:
                    missing.append(n)
            done = bool(names) and all(decls.get(n, {}).get("status") in DONE for n in names)
            last_theorem_done = done if env != "definition" else None
        if not done:
            return m.group(0)
        opt = re.match(r"\[[^\]]*\]", body)
        title, rest = (opt.group(0), body[opt.end():]) if opt else ("", body)
        return f"\\begin{{{env}}}{title}\n  \\leanok{rest}\\end{{{env}}}"

    out = ENV_RE.sub(replace, src)
    if missing:
        sys.exit("content.tex names declarations the build does not report: " + ", ".join(missing))
    header = "% Generated by scripts/render_status.py from content.tex and build/status.json.\n% Do not edit.\n\n"
    (BLUEPRINT / "content.generated.tex").write_text(header + out)


def tex_escape(s):
    for a, b in [("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"), ("$", r"\$"),
                 ("#", r"\#"), ("_", r"\_"), ("{", r"\{"), ("}", r"\}")]:
        s = s.replace(a, b)
    return s


def render_ears_tex(decls):
    """The EARS statements as a list.  A table of this length does not break
    across the pages of the PDF."""
    lines = [
        "% Generated by scripts/render_status.py from build/status.json.  Do not edit.",
        "",
        "\\section{EARS requirements}",
        "",
        "Each requirement below is the EARS statement in a rule's Lean docstring.",
        "The proving theorems are computed by the build.",
        "",
        # Set flush left: the Lean names are long and do not hyphenate.
        "\\begin{flushleft}",
        "\\begin{description}",
    ]
    for d in ears_rows(decls):
        pb = ", ".join(
            "\\texttt{" + tex_escape(short) + "}" + (" (open)" if st == "open" else "")
            for _, short, st in proven_by(d, decls)
        ) or "none"
        lines.append(
            f"\\item[{tex_escape(d.get('earsId') or '')}] {tex_escape(d['ears'])} "
            f"Rule: \\texttt{{{tex_escape(rule_name(d['name']))}}}. Guarantees about it: {pb}."
        )
    lines += ["\\end{description}", "\\end{flushleft}", ""]
    (BLUEPRINT / "ears.generated.tex").write_text("\n".join(lines))


# -------------------------------------------------------------------- verso


def verso_escape(s):
    return re.sub(r"([\\*_\[\]{}`#])", r"\\\1", s)


VERSO_HEADER = """\
-- Generated by scripts/render_status.py from build/status.json.  Do not edit.
import VersoManual
import Rules
import Review.Status

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open Review

set_option pp.rawOnError true
"""

STATUS_TEXT = {
    "proven": '{status "proven"}[Proven] Lean checked the proof, and the proof depends on no unproven step.',
    "open": '{status "open"}[Open] The proof is not complete. See the open questions chapter.',
}

# The EARS table's status column, as status labels.
DECL_STATUS = {
    "definition": '{status "modelled"}[Modelled]',
    "proven": '{status "proven"}[Proven]',
    "open": '{status "open"}[Open]',
}


def blueprint_titles():
    """The title of each blueprint node, by the Lean names in its \\lean{}.
    A survey candidate's ID, such as " (C-06)", is left off."""
    src = read_blueprint()
    titles = {}
    for m in re.finditer(r"\\begin\{(?:theorem|lemma|definition)\}\[([^\]]*)\](.*?)\\end", src, re.S):
        title = re.sub(r"\s*" + CANDIDATE_ID + "$", "", m.group(1).strip())
        for lm in LEAN_RE.finditer(m.group(2)):
            for n in lm.group(1).split(","):
                titles[n.strip()] = title
    return titles


def humanize(name):
    """acceptBeforeExpiry or accept_before_expiry as "Accept before expiry"."""
    words = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", name).replace("_", " ").lower()
    return words[:1].upper() + words[1:]


# ------------------------------------------------------- computed values
#
# The status executable stores each example's value as Lean prints it.  The
# functions below parse that text and show it in business terms: amounts as
# "245.00 USD", instants as UTC times, constructor names as words, and lists
# of records as tables.  If a value does not parse, it is shown as Lean
# printed it.

VALUE_TOKEN = re.compile(r'\s*(?:(:=)|([{}\[\](),])|("(?:[^"\\]|\\.)*")|(\d+)|([^\s{}\[\](),:"]+))')


def parse_value(text):
    tokens, pos = [], 0
    while pos < len(text):
        m = VALUE_TOKEN.match(text, pos)
        if not m or m.end() == pos:
            if text[pos:].strip():
                raise ValueError(f"cannot read {text[pos:pos + 20]!r}")
            break
        pos = m.end()
        assign, punct, string, number, ident = m.groups()
        if assign:
            tokens.append((":=", None))
        elif punct:
            tokens.append((punct, None))
        elif string:
            tokens.append(("str", json.loads(string)))
        elif number:
            tokens.append(("num", int(number)))
        elif ident:
            tokens.append(("id", ident))
    i = 0

    def peek():
        return tokens[i][0] if i < len(tokens) else None

    def take(kind=None):
        nonlocal i
        tok = tokens[i]
        if kind and tok[0] != kind:
            raise ValueError(f"expected {kind}, found {tok}")
        i += 1
        return tok

    def primary():
        kind, val = take()
        if kind == "{":
            fields = {}
            while peek() != "}":
                name = take("id")[1]
                take(":=")
                fields[name] = term()
                if peek() == ",":
                    take()
            take("}")
            return {"record": fields}
        if kind in ("[", "("):
            close = "]" if kind == "[" else ")"
            items = []
            while peek() != close:
                items.append(term())
                if peek() == ",":
                    take()
            take(close)
            if kind == "[":
                return {"list": items}
            return items[0] if len(items) == 1 else {"tuple": items}
        if kind in ("str", "num"):
            return val
        if kind == "id":
            return {"id": val}
        raise ValueError(f"unexpected {kind}")

    def term():
        head = primary()
        args = []
        while isinstance(head, dict) and "id" in head and peek() in ("{", "[", "(", "str", "num", "id"):
            args.append(primary())
        return {"app": head["id"], "args": args} if args else head

    value = term()
    if i != len(tokens):
        raise ValueError("trailing text")
    return value


def words(name):
    """The last part of a Lean name in words: emptyOffer as "empty offer"; USD stays USD."""
    last = name.rsplit(".", 1)[-1]
    if last.isupper():
        return last
    spaced = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", last)
    # A one-letter word: ifAPassport is "if a passport".
    return re.sub(r"\b([A-Z])([A-Z][a-z])", r"\1 \2", spaced).replace("_", " ").lower()


def field_label(name):
    w = words(name)
    return w[:1].upper() + w[1:]


# Findings and advisories as phrases.  {0}, {1} are the constructor's arguments.
PHRASES = {
    "wrongDocType": "the document type is {1}, where {0} is required",
    "repeatedName": "a namespace name or a data element identifier is repeated",
    "missingNameSpace": "the namespace {0} is missing",
    "missingElement": "the data element {1} is missing from {0}",
    "notText": "the data element {1} of {0} is not a text string",
    "notResolution792": "the boarding pass string does not follow Resolution 792",
    "wrongEncoding": "the data element {1} of {0} does not have the encoding its table gives",
    "notFromPassport": "the photoid was not derived from a passport",
    "unlistedNameSpace": "the namespace {0} is not one the guide lists",
    "unlistedElement": "the data element {1} of {0} is not one the guide lists",
    "portraitDiffersFromDg2": "the portrait differs from data group 2",
    "endsBeforeLastDeparture": "the validity ends before the last leg departs",
    "endsLongAfterLastDeparture": "the validity ends later than soon after the last leg departs",
    "outlivesSourceDocument": "the validity ends after the source document expires",
    "missingRecommendedNameSpace": "the recommended namespace {0} is absent",
    "missingRecommendedElement": "the recommended data element {1} is absent from {0}",
    "notDerivedFromPassport": "the photoid was not derived from a passport",
}


def phrase(name, args):
    """A finding or an advisory as a phrase, or None for any other constructor."""
    p = PHRASES.get(name.rsplit(".", 1)[-1])
    return p.format(*[inline(a) for a in args]) if p and p.count("{") == len(args) else None


def inline(v):
    """A value as one line of Verso text."""
    if isinstance(v, str):
        return verso_escape(v)
    if isinstance(v, int):
        return str(v)
    if "record" in v:
        f = v["record"]
        if set(f) == {"epochSeconds"} and isinstance(f["epochSeconds"], int):
            t = datetime.datetime.fromtimestamp(f["epochSeconds"], datetime.UTC)
            return t.strftime("%Y-%m-%d %H:%M UTC")
        return ", ".join(f"{words(k)} {inline(x)}" for k, x in f.items())
    if "id" in v:
        return {"true": "yes", "false": "no", "none": "none"}.get(v["id"]) or phrase(v["id"], []) or words(v["id"])
    if "app" in v:
        if v["app"] == "some" and len(v["args"]) == 1:
            return inline(v["args"][0])
        if v["app"].endswith("Value.text") and len(v["args"]) == 1:
            return inline(v["args"][0])
        return phrase(v["app"], v["args"]) or words(v["app"]) + " " + " ".join(inline(a) for a in v["args"])
    if "list" in v:
        return "; ".join(inline(x) for x in v["list"]) or "none"
    if "tuple" in v:
        return ", ".join(inline(x) for x in v["tuple"])
    return verso_escape(str(v))


def record_table(rows):
    """A list of records with the same fields as a Verso table."""
    keys = list(rows[0]["record"])
    out = [":::table +header", "*"] + [f"  * {field_label(k)}" for k in keys]
    for r in rows:
        out.append("*")
        out += [f"  * {inline(r['record'][k])}" for k in keys]
    return out + [":::"]


def is_record_list(v):
    return (isinstance(v, dict) and "list" in v and v["list"]
            and all(isinstance(x, dict) and "record" in x for x in v["list"])
            and len({tuple(x["record"]) for x in v["list"]}) == 1)


def readable(v):
    """Verso blocks that show a computed value."""
    if isinstance(v, dict) and "app" in v and v["app"] == "Except.error" and len(v["args"]) == 1:
        return [f"Rejected: {inline(v['args'][0])}."]
    if isinstance(v, dict) and "app" in v and v["app"] == "Except.ok" and len(v["args"]) == 1:
        return ["Accepted. The result:", ""] + readable(v["args"][0])
    if is_record_list(v):
        return record_table(v["list"])
    if isinstance(v, dict) and "record" in v:
        out, tables = [], []
        for k, x in v["record"].items():
            if is_record_list(x):
                out.append(f" * {field_label(k)}: see the table below.")
                tables += ["", f"{field_label(k)}:", ""] + record_table(x["list"])
            else:
                out.append(f" * {field_label(k)}: {inline(x)}")
        return out + tables
    return [inline(v)]


def computed_blocks(value):
    try:
        return readable(parse_value(value))
    except (ValueError, IndexError, KeyError, TypeError):
        fence = "```"
        while fence in value:
            fence += "`"
        return [fence, value, fence]


# ----------------------------------------------------------- requirements

CRITERION_STATUS = {
    "proven": '{status "proven"}[Proven]',
    "example": '{status "example"}[Example only]',
    "open": '{status "open"}[Open]',
    "not checked": '{status "notChecked"}[Not checked]',
}


def requirement_module(ears_id):
    return ears_id.replace("-", "")


def check_title(name, decls, titles):
    d = decls.get(name, {})
    short = name.rsplit(".", 1)[-1]
    return titles.get(name, humanize(short)) if d.get("kind") == "theorem" else humanize(short)


def section_tag(kind, name):
    """The Verso tag of a guarantee's or example's section, such as
    guarantee-delivered-not-cancellable.  Links elsewhere on the site find the
    section through Verso's lookup with this tag (scripts/render_progress.py)."""
    short = name.rsplit(".", 1)[-1]
    return f"{kind}-" + kebab(short)


def chapter_tag(kind, d, ears_id):
    """The section tag of a guarantee or example in one requirement's chapter.  A
    declaration that checks several requirements appears in each chapter; the
    chapter of its first criterion keeps the plain tag, which other pages link to."""
    tag = section_tag(kind, d["name"])
    home = min(d["checks"]).rsplit(".", 1)[0]
    return tag if home == ears_id else f"{tag}-in-{ears_id.lower()}"


def render_requirement(rule, decls, titles, sources, assumptions):
    ears_id = rule["earsId"]
    prefix = ears_id + "."
    def checks_this(d):
        return any(c.startswith(prefix) for c in d.get("checks", []))
    theorems = sorted((d for d in decls.values() if d["kind"] == "theorem" and checks_this(d)),
                      key=lambda d: (min(d["checks"]), d["name"]))
    cases = sorted((d for d in decls.values() if d["kind"] == "case" and checks_this(d)),
                   key=lambda d: (min(d["checks"]), d["name"]))
    title = titles.get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1]))
    criteria = rule.get("criteria", [])
    counts = {}
    for c in criteria:
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    phrases = {"proven": "proven", "example": "checked by examples only", "open": "open",
               "not checked": "not checked yet"}
    parts_ = [f"{n} {'is' if n == 1 else 'are'} {phrases[s]}"
              for s, n in sorted(counts.items(), key=lambda x: list(CRITERION_TEXT).index(x[0]))]
    summary = parts_[0] if len(parts_) == 1 else ", ".join(parts_[:-1]) + " and " + parts_[-1]
    parts = [VERSO_HEADER, f'#doc (Manual) "{title}" =>', "%%%", f'tag := "{ears_id.lower()}"', "%%%", ""]
    links = ", ".join(f"[{verso_escape(s['title'])}]({s['url']})" for s in rule_sources(rule, sources))
    parts += [
        (f"Requirement {ears_id}. Its one acceptance criterion is {phrases[criteria[0]['status']]}."
         if len(criteria) == 1 else
         f"Requirement {ears_id}. Of its {len(criteria)} acceptance criteria, {summary}."),
        "",
        f"Sources: {links}. {verso_escape(confirmation_text(rule))}",
        "",
    ] + relies_on_lines(rule, assumptions) + [
        f'{{docstring {rule["name"]} +hideStructureConstructor (label := "rule")}}',
        "",
        "# How each acceptance criterion is checked",
        "",
        "A criterion is proven when a guarantee below proves it for every input, and example only when only "
        "examples check it.",
        "",
        ":::table +header",
        "*",
        "  * Criterion",
        "  * Status",
        "  * Checked by",
    ]
    for c in criteria:
        by = ", ".join(check_title(n, decls, titles) for n in c.get("checkedBy", [])) or "nothing yet"
        parts += ["*", f"  * {c['id']}", f"  * {CRITERION_STATUS[c['status']]}", f"  * {verso_escape(by)}"]
    parts += [":::", ""]

    if theorems:
        parts += ["# Guarantees", ""]
        for d in theorems:
            parts += [
                f"## {verso_escape(check_title(d['name'], decls, titles))}",
                "%%%",
                f'tag := "{chapter_tag("guarantee", d, ears_id)}"',
                "%%%",
                "",
                f'{{docstring {d["name"]} (label := "guarantee")}}',
                "",
                STATUS_TEXT[d["status"]],
                "",
                f"Checks acceptance criteria {', '.join(d['checks'])}.",
                "",
            ]
    if cases:
        parts += ["# Examples", ""]
        for d in cases:
            parts += [
                f"## {humanize(d['name'].rsplit('.', 1)[-1])}",
                "%%%",
                f'tag := "{chapter_tag("example", d, ears_id)}"',
                "%%%",
                "",
                f'{{docstring {d["name"]} (label := "example")}}',
                "",
                "*What Lean computed:*",
                "",
            ] + computed_blocks(d["value"]) + [
                "",
                f"Checks acceptance criteria {', '.join(d['checks'])}.",
                "",
            ]
    for d in (t for t in theorems if t["status"] == "open"):
        title = check_title(d["name"], decls, titles)
        shown_by = [humanize(c["name"].rsplit(".", 1)[-1]) for c in cases if set(c["checks"]) & set(d["checks"])]
        why = (f"the {'example' if len(shown_by) == 1 else 'examples'} {', '.join(shown_by)} "
               f"{'shows' if len(shown_by) == 1 else 'show'} a case the guide as written allows and the guarantee forbids"
               if shown_by else "it has no proof yet")
        where = f"[{QUESTIONS_TITLE}]({slug(QUESTIONS_TITLE)}/)"
        parts += [
            "# Open question",
            "",
            f"The guarantee {verso_escape(title)} is open: {why}. "
            f"{where} sets out the question for the business.",
            "",
        ]
    module = requirement_module(ears_id)
    (GENERATED / f"{module}.lean").write_text("\n".join(parts))
    return module


def lean_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


STATUS_ICON = {"proven": "✓", "example": "◆", "open": "!", "not checked": "…"}
CHIP_TEXT = {"proven": "proven", "example": "by example", "open": "open", "not checked": "not checked"}
STATUS_CLASS = {"proven": "s-proven", "example": "s-example", "open": "s-open", "not checked": "s-notChecked"}
ASSUMPTIONS_TITLE = "Assumptions about external specifications"
REFERENCE_CHAPTERS = [
    ("Overview", "How to read this document, where the material comes from, and what the build computes."),
    (QUESTIONS_TITLE, "The open guarantees, each with the example that shows the case and the question to answer."),
    ("Objects", "The credentials, data elements, findings and readings the rules talk about."),
    (ASSUMPTIONS_TITLE, "What the model takes from the ISO, OpenID, IATA and other specifications it has not read."),
    ("EARS requirements", "Every requirement statement in one table."),
]


def slug(title):
    return re.sub(r"[^A-Za-z0-9-]", "", title.replace(" ", "-"))


def render_front(decls, titles):
    """The review document's front page: a card per requirement, then the reference chapters."""
    cards = []
    for rule in ears_rows(decls):
        title = titles.get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1]))
        counts = {}
        for c in rule.get("criteria", []):
            counts[c["status"]] = counts.get(c["status"], 0) + 1
        chips = "".join(
            f'<span class="status {STATUS_CLASS[st]}"><span class="ico" aria-hidden="true">{STATUS_ICON[st]}</span>'
            f'{n} {CHIP_TEXT[st]}</span>'
            for st, n in sorted(counts.items(), key=lambda x: list(CRITERION_TEXT).index(x[0])))
        story = html.escape(plain(rule.get("story") or ""))
        cards.append(
            f'<a class="req-card" href="{slug(title)}/">'
            f'<span class="req-id">{rule["earsId"]}</span>'
            f'<span class="req-title">{html.escape(title)}</span>'
            f'<span class="req-story">{story}</span>'
            f'<span class="req-stats">{chips}</span></a>')
    refs = "".join(f'<li><a href="{slug(t)}/">{html.escape(t)}</a>: {html.escape(d)}</li>' for t, d in REFERENCE_CHAPTERS)
    page = (
        '<section class="front">'
        '<h2>Requirements</h2>'
        '<p class="front-note">One chapter per requirement: the rule, how each acceptance criterion is checked, '
        'the guarantees Lean proves, and the examples the build computes.</p>'
        f'<div class="req-cards">{"".join(cards)}</div>'
        '<h2>Reference</h2>'
        f'<ul class="ref-list">{refs}</ul>'
        '</section>'
    )
    (GENERATED / "Front.lean").write_text(
        "-- Generated by scripts/render_status.py from build/status.json.  Do not edit.\n\n"
        "namespace Review.Generated.Front\n\n"
        "/-- The front page's requirement cards and reference list, as HTML. -/\n"
        f"def html : String := {lean_string(page)}\n\n"
        "end Review.Generated.Front\n")


def render_requirements(decls):
    titles = blueprint_titles()
    sources = load_sources()
    assumptions = load_assumptions()
    modules = [render_requirement(r, decls, titles, sources, assumptions) for r in ears_rows(decls)]
    render_front(decls, titles)
    render_questions(decls, titles)
    render_assumptions(decls, titles, assumptions)
    modules += ["Questions", "Assumptions"]
    review = (ROOT / "Review" / "Review.lean").read_text()
    missing = [m for m in modules if f"{{include 1 Review.Generated.{m}}}" not in review]
    if missing:
        sys.exit("Review/Review.lean does not include " + ", ".join(f"Review.Generated.{m}" for m in missing))
    return modules


def render_questions(decls, titles):
    """A chapter with one section per open guarantee."""
    open_ = sorted((d for d in decls.values() if d["kind"] == "theorem" and d["status"] == "open"),
                   key=lambda d: (min(d["checks"] or ["~"]), d["name"]))
    cases = [d for d in decls.values() if d["kind"] == "case"]
    rules = {c["id"]: r for r in ears_rows(decls) for c in r.get("criteria", [])}
    n = len(open_)
    parts = [VERSO_HEADER, f'#doc (Manual) "{QUESTIONS_TITLE}" =>', "%%%", 'tag := "open-questions"', "%%%", ""]
    parts += [
        f"{n} {'guarantee is' if n == 1 else 'guarantees are'} open in the credential rules. "
        "Each is a place where the One ID guide is vague or silent, so the rule as written allows a case "
        "the guarantee forbids. An example the build computes shows that case, and the question under it is "
        "for the business to answer. The model does not decide it. "
        "The [progress page](../progress/) ranks these questions, and the candidate rules that still need a decision, "
        "by how much of the model each answer affects.",
        "",
    ]
    for d in open_:
        title = check_title(d["name"], decls, titles)
        owner = next((rules[c] for c in d["checks"] if c in rules), None)
        parts += [f"# {verso_escape(title)}", "%%%", f'tag := "{section_tag("question", d["name"])}"', "%%%", ""]
        parts += [f'{{docstring {d["name"]} (label := "open question")}}', ""]
        if owner:
            chapter = titles.get(owner["name"], humanize(owner["name"].rsplit(".", 1)[-1]))
            shown = [c for c in cases if set(c["checks"]) & set(d["checks"])]
            examples = ", ".join(humanize(c["name"].rsplit(".", 1)[-1]) for c in shown)
            parts += [f"It checks acceptance criteria {', '.join(d['checks'])} of requirement {owner['earsId']}, "
                      f"[{verso_escape(chapter)}]({slug(chapter)}/)"
                      + (f", where the {'example' if len(shown) == 1 else 'examples'} {verso_escape(examples)} "
                         f"{'shows' if len(shown) == 1 else 'show'} what Lean computed." if shown else "."), ""]
    (GENERATED / "Questions.lean").write_text("\n".join(parts))


def relies_on_lines(rule, assumptions):
    """A sentence naming the external specifications a rule relies on."""
    keys = rule.get("assumes", [])
    if not keys:
        return []
    def one(a):
        clause = verso_escape(f"{a['spec']}, {a['clause']}")
        return f"[{clause}]({a['url']})" if a.get("url") else clause
    named = "; ".join(one(assumptions[k]) for k in keys)
    return [f"It relies on specifications this project has not read: {named}. "
            f"[{ASSUMPTIONS_TITLE}]({slug(ASSUMPTIONS_TITLE)}/) says what the model takes from each.", ""]


def render_assumptions(decls, titles, assumptions):
    """A chapter listing every dependency on an external specification."""
    used = [a for a in assumptions.values() if a["usedBy"]]
    later = [a for a in assumptions.values() if not a["usedBy"]]
    parts = [VERSO_HEADER, f'#doc (Manual) "{ASSUMPTIONS_TITLE}" =>', "%%%", 'tag := "assumptions"', "%%%", ""]
    parts += [
        "The One ID guide builds on ISO, OpenID, W3C, IETF, ICAO and IATA specifications. "
        "This project has not read them. The model takes from each only what the guide itself says about it, "
        "and each dependency is listed here with the clause the guide cites. "
        "A specification's name links to where it is published or sold, as the guide's reference list gives it. "
        f"{len(assumptions)} are recorded: {len(used)} that rules in the model rely on, and {len(later)} that "
        "belong to the presentation flows, which are not modelled yet.",
        "",
        "Where a rule depends on the content of an external table or format, the rule takes that content as a "
        "parameter. A guarantee is proven only when it holds for every content the external clause could have.",
        "",
    ]

    def table(rows, with_users):
        out = [":::table +header", "*", "  * Specification", "  * Clause", "  * Cited in the guide",
               "  * What the model takes from it"] + (["  * Relied on by"] if with_users else [])
        for a in rows:
            spec = verso_escape(a["spec"])
            out += ["*", f"  * [{spec}]({a['url']})" if a.get("url") else f"  * {spec}", f"  * {verso_escape(a['clause'])}",
                    f"  * {verso_escape(a['guide'])}", f"  * {verso_escape(a['statement'])}"]
            if with_users:
                users = sorted({titles.get(n, humanize(n.rsplit(".", 1)[-1])) for n in a["usedBy"]})
                out.append(f"  * {verso_escape(', '.join(users))}")
        return out + [":::", ""]

    parts += ["# Relied on by the model", ""] + table(used, True)
    parts += ["# Named by the guide and not modelled yet", ""] + table(later, False)
    (GENERATED / "Assumptions.lean").write_text("\n".join(parts))


def render_ears_verso(decls):
    parts = [VERSO_HEADER, '#doc (Manual) "EARS requirements" =>', "%%%", 'tag := "ears"', "%%%", ""]
    parts.append(
        "This table lists every EARS statement in the model, with the rule that implements it and the "
        "guarantees that mention that rule. The build generates it from the docstrings; the same table "
        "is in the blueprint and in [ears.csv](../ears.csv)."
    )
    parts.append("")
    parts += [":::table +header", "*", "  * ID", "  * EARS statement", "  * Rule", "  * Status", "  * Proven by"]
    for d in ears_rows(decls):
        pb = ", ".join(
            f"`{short}`" + (" (open)" if st == "open" else "") for _, short, st in proven_by(d, decls)
        ) or "none"
        parts += [
            "*",
            f"  * {d.get('earsId') or ''}",
            f"  * {verso_escape(d['ears'])}",
            f"  * `{rule_name(d['name'])}`",
            f"  * {DECL_STATUS.get(d['status'], d['status'])}",
            f"  * {pb}",
        ]
    parts += [":::", ""]
    (GENERATED / "Ears.lean").write_text("\n".join(parts))


# -------------------------------------------------------------------- kiro

SPEC_MARK = "<!-- Generated by scripts/render_status.py"

CRITERION_TEXT = {
    "proven": "proven",
    "example": "example only",
    "open": "open",
    "not checked": "not checked",
}


def plain(s):
    """Docstring text with Verso roles such as {name}`x` reduced to `x`."""
    return re.sub(r"\{(?:name|lit|lean|attr)\}`", "`", s)


def kiro_ears(s):
    """An EARS statement in Kiro's notation: WHEN ... THE SYSTEM SHALL ..."""
    s = re.sub(r",? then the system shall ", " THEN THE SYSTEM SHALL ", s)
    s = re.sub(r", the system shall ", " THE SYSTEM SHALL ", s)
    s = re.sub(r"^The system shall ", "THE SYSTEM SHALL ", s)
    return re.sub(r"^(When|While|If|Where) ", lambda m: m.group(1).upper() + " ", s)


def module_doc(module):
    """The title and the paragraphs of a module's `/-! ... -/` docstring."""
    path = ROOT / (module.replace(".", "/") + ".lean")
    m = re.search(r"/-!(.*?)-/", path.read_text(), re.S)
    lines = m.group(1).strip().splitlines()
    title = lines[0].lstrip("# ").strip()
    body = "\n".join(lines[1:]).strip()
    return path.relative_to(ROOT).as_posix(), title, plain(body)


def kebab(s):
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", s)
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def checked_by_text(c, decls):
    parts = []
    # Theorems first, then examples.
    for n in sorted(c["checkedBy"], key=lambda n: (decls[n]["kind"] == "case", n)):
        d = decls[n]
        short = d["name"].rsplit(".", 1)[-1]
        if d["kind"] == "case":
            label = "counterexample" if c["status"] == "open" else "example"
        else:
            label = f"{d['status']} theorem"
        parts.append(f"{label} `{short}`")
    return "; ".join(parts) if parts else "nothing in the build checks this yet"


def spec_dirs(decls):
    """Rules grouped by module, with each group's spec folder name."""
    groups = {}
    for d in ears_rows(decls):
        groups.setdefault(d["module"], []).append(d)
    out = []
    for module, rules in groups.items():
        source, title, intro = module_doc(module)
        group = kebab(module.split(".")[1])
        out.append((f"{group}-{kebab(title)}", module, source, title, intro, rules))
    return sorted(out, key=lambda g: g[5][0]["earsId"])


SPEC_PROVENANCE_NOTE = (
    " *Sources* lists the sections of the guide each rule was written from, *External specifications* lists "
    "the specifications it relies on that this project has not read, and *Confirmation* says whether anyone "
    "outside the model has confirmed the rule as written."
)


def spec_provenance_lines(d, sources, assumptions):
    """The Sources, External specifications and Confirmation lines under a requirement's rule in its spec."""
    links = "; ".join(f"[{s['title']}]({s['url']}) ({s['kind']})" for s in rule_sources(d, sources))
    external = "; ".join(f"{assumptions[k]['spec']}, {assumptions[k]['clause']}" for k in d.get("assumes", []))
    return (["", f"**Sources:** {links}"]
            + (["", f"**External specifications:** {external}"] if external else [])
            + ["", f"**Confirmation:** {confirmation_text(d)}"])


def render_spec(folder, source, title, intro, rules, decls, sources, assumptions):
    lines = [
        f"{SPEC_MARK} from {source}. Edit the docstrings there, not this file. -->",
        "",
        f"# Requirements Document: {title}",
        "",
        "## Introduction",
        "",
        intro,
        "",
        f"These requirements are generated from the Lean model in [`{source}`]({REPO}/{source}). "
        "Each acceptance criterion carries the status the build computed for it: *proven* means a "
        "theorem the build checked, *example only* means a computed example, *open* means a theorem "
        "the build could not prove, and *not checked* means no theorem or example covers it yet."
        + SPEC_PROVENANCE_NOTE,
        "",
        "## Requirements",
        "",
    ]
    for d in rules:
        rule = rule_name(d["name"])
        lines += [
            f"### Requirement {d['earsId']}",
            "",
            f"**User Story:** {d['story']}",
            "",
            f"**Rule:** {kiro_ears(d['ears'])} (Lean: `{rule}`)",
        ] + spec_provenance_lines(d, sources, assumptions) + [
            "",
            "#### Acceptance Criteria",
            "",
        ]
        for i, c in enumerate(d["criteria"], 1):
            lines += [
                f"{i}. {kiro_ears(c['ears'])}",
                f"   - {c['id']}, {CRITERION_TEXT[c['status']]}: {checked_by_text(c, decls)}",
            ]
        lines.append("")
        for c in d["criteria"]:
            for n in c["checkedBy"]:
                t = decls[n]
                if t["kind"] == "theorem" and t["status"] == "open":
                    lines += [f"#### Open question on {c['id']}", ""]
                    lines += ["> " + l if l else ">" for l in plain(t["docstring"]).splitlines()]
                    lines.append("")
    (SPECS / folder).mkdir(parents=True, exist_ok=True)
    (SPECS / folder / "requirements.md").write_text("\n".join(lines))


def render_specs_index(groups, decls):
    criteria = [c for *_, rules in groups for d in rules for c in d["criteria"]]
    counts = {k: sum(c["status"] == k for c in criteria) for k in CRITERION_TEXT}
    lines = [
        f"{SPEC_MARK} from build/status.json. Do not edit. -->",
        "",
        "# Specs generated from the Lean model",
        "",
        "Each folder is a requirement spec with one `requirements.md`, generated from the rules in one Lean "
        "module. The acceptance criteria are in EARS notation, and the folders follow the layout Kiro reads. "
        "The rule's docstring holds the user story and the acceptance criteria; the build "
        "computes each criterion's status from the theorems and examples tagged `@[checks]` with its ID. "
        "To change a requirement, edit the docstring and rebuild.",
        "",
        f"{len(criteria)} acceptance criteria: {counts['proven']} proven, {counts['example']} example only, "
        f"{counts['open']} open, {counts['not checked']} not checked.",
        "",
        provenance_summary([d for *_, rules in groups for d in rules]),
        "",
        "| Spec | Requirement | User story | Criteria | Proven | Example only | Open | Not checked |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for folder, _, _, title, _, rules in groups:
        for d in rules:
            n = lambda k: sum(c["status"] == k for c in d["criteria"])
            lines.append(
                f"| [{title}]({folder}/requirements.md) | {d['earsId']} | {d['story']} | {len(d['criteria'])} "
                f"| {n('proven')} | {n('example')} | {n('open')} | {n('not checked')} |"
            )
    lines += ["", "## Acceptance criteria", "", "| ID | Criterion | Status | Checked by |", "| --- | --- | --- | --- |"]
    for c in criteria:
        lines.append(f"| {c['id']} | {kiro_ears(c['ears'])} | {CRITERION_TEXT[c['status']]} | {checked_by_text(c, decls)} |")
    lines += [
        "",
        "The build writes the same rows to `build/ears-criteria.csv`, one row per rule to `build/ears.csv`, "
        "each rule's sources and confirmation to `build/provenance.csv`, and the assumptions about external "
        "specifications to `build/assumptions.csv`. The site serves all four at its root.",
        "",
    ]
    (SPECS / "README.md").write_text("\n".join(lines))


def provenance_summary(rules):
    """One sentence counting the rules by provenance."""
    n = {p: sum(d.get("provenance") == p for d in rules) for p in PROVENANCE_TEXT}
    return (f"{len(rules)} rules: {n['confirmed']} {PROVENANCE_TEXT['confirmed']}, "
            f"{n['out of date']} {PROVENANCE_TEXT['out of date']}, {n['sourced']} {PROVENANCE_TEXT['sourced']}, "
            f"{n['assumed']} {PROVENANCE_TEXT['assumed']}.")


def render_specs(decls):
    groups = spec_dirs(decls)
    written = {g[0] for g in groups}
    # Remove spec folders this script wrote earlier for modules that no longer have rules.
    if SPECS.exists():
        for f in SPECS.glob("*/requirements.md"):
            if f.parent.name not in written and f.read_text().startswith(SPEC_MARK):
                f.unlink()
                f.parent.rmdir()
    sources = load_sources()
    assumptions = load_assumptions()
    for folder, _, source, title, intro, rules in groups:
        render_spec(folder, source, title, intro, rules, decls, sources, assumptions)
    render_specs_index(groups, decls)


def main():
    decls = load_status()
    GENERATED.mkdir(parents=True, exist_ok=True)
    render_content(decls)
    render_ears_tex(decls)
    modules = render_requirements(decls)
    render_ears_verso(decls)
    for stale in GENERATED.glob("*.lean"):
        if stale.stem not in modules + ["Ears", "Front"]:
            stale.unlink()
    render_specs(decls)
    print("rendered blueprint/src/content.generated.tex, ears.generated.tex, "
          "Review/Review/Generated/*.lean, .kiro/specs/")


if __name__ == "__main__":
    main()
