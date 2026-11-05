#!/usr/bin/env python3
"""The blueprint as cards and areas, for the pages that rank and count it.

The progress page (scripts/render_progress.py) reads the graph through
`Model`, so its counts and its ranking agree:

  - each area's cards and how many are in each status;
  - how many cards depend on each card, directly or through other cards;
  - the proven version of an open guarantee for one reading of the guide,
    found by name (`<open name>_of_<reading>`, tagged with no criterion).

Areas are the blueprint's sections.  AREA_ORDER lists them from the
foundations down; a new section must be added there, and the build stops
until it is.
"""

import re
import sys
from collections import Counter, defaultdict

# The areas, from the foundations down.  The ranking breaks ties by the
# number of areas an answer reaches, and the pages list areas in this order.
AREA_ORDER = [
    "Core concepts",
    "Credential data model",
    "Functional requirements and assumptions",
    "Remote presentation",
    "Proximity presentation",
    "What the guide leaves out",
    "Issuance and contactless travel",
    "Candidate guarantees",
]

# Shorter names where a row has little room.
SHORT = {
    "Credential data model": "Credentials",
    "Functional requirements and assumptions": "Requirements and assumptions",
    "Remote presentation": "Remote",
    "Proximity presentation": "Proximity",
    "What the guide leaves out": "Left out of the guide",
    "Issuance and contactless travel": "Contactless travel",
    "Candidate guarantees": "Guarantees",
}

# The order statuses are listed in, on every page.
STATUS_ORDER = ["modelled", "proven", "open", "decision", "ready", "waiting"]
QUESTION = {"open", "decision"}


def slug(area):
    return re.sub(r"[^a-z0-9]+", "-", area.lower()).strip("-")


def short(area):
    return SHORT.get(area, area)


def reading_pairs(decls):
    """For each open theorem, the proven theorems named `<its name>_of_<reading>`
    that check no criterion: the guarantee proven for one reading of the
    guide.  Pairs are found by name only."""
    opens = {n for n, d in decls.items() if d["status"] == "open"}
    pairs = defaultdict(list)
    for name, d in sorted(decls.items()):
        if d["status"] != "proven" or d.get("checks"):
            continue
        i = name.find("_of_")
        while i != -1:
            if name[:i] in opens:
                pairs[name[:i]].append(name)
                break
            i = name.find("_of_", i + 1)
    return dict(pairs)


def docstring_html(s):
    """A docstring as one paragraph of HTML: `code` in code tags, and Verso's
    escapes and roles removed."""
    import html as _html
    s = re.sub(r"\{(?:name|lit|lean|attr)\}`", "`", s or "")
    s = s.replace("\\(", "(").replace("\\)", ")")
    s = _html.escape(re.sub(r"\s+", " ", s).strip(), quote=False)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", s)


class Model:
    """The classified blueprint nodes, with what the pages compute from them."""

    def __init__(self, nodes, decls):
        self.decls = decls
        self.nodes = nodes
        self.by = {n["label"]: n for n in nodes}
        unknown = sorted({(n["label"], u) for n in nodes for u in n["uses"] if u not in self.by})
        if unknown:
            sys.exit("blueprint \\uses names labels that do not exist: "
                     + ", ".join(f"{a} uses {b}" for a, b in unknown))
        self.users = {n["label"]: [] for n in nodes}
        for n in nodes:
            for u in n["uses"]:
                self.users[u].append(n["label"])
        areas = list(dict.fromkeys(n["section"] for n in nodes))
        missing = [a for a in areas if a not in AREA_ORDER]
        if missing:
            sys.exit("scripts/graph_model.py: add the blueprint section(s) " + ", ".join(repr(a) for a in missing)
                     + " to AREA_ORDER")
        self.order = [a for a in AREA_ORDER if a in areas]
        self.area_nodes = {a: [n for n in nodes if n["section"] == a] for a in self.order}
        self._down = {}
        self.pairs = reading_pairs(decls)

    def counts(self, area=None):
        ns = self.nodes if area is None else self.area_nodes[area]
        c = Counter(n["status"] for n in ns)
        return {s: c.get(s, 0) for s in STATUS_ORDER}

    def downstream(self, label):
        """Every card that uses this one, directly or through other cards."""
        if label not in self._down:
            seen, stack = set(), [label]
            while stack:
                for y in self.users[stack.pop()]:
                    if y not in seen and y != label:
                        seen.add(y)
                        stack.append(y)
            self._down[label] = seen
        return self._down[label]

    def impact(self, label):
        """How far an answer reaches: the cards that depend on this one and
        the areas they are in, in area order."""
        down = self.downstream(label)
        areas = [a for a in self.order if any(self.by[x]["section"] == a for x in down)]
        return {"count": len(down), "areas": areas, "cards": [n for n in self.nodes if n["label"] in down]}

    def ranking(self, limit=None):
        """Open questions and decisions, by the number of cards that depend on
        them, then by the number of areas those cards are in, then by title.
        A card with nothing depending on it comes last, with a count of 0."""
        rows = []
        for n in self.nodes:
            if n["status"] in QUESTION:
                rows.append({"node": n, **self.impact(n["label"])})
        rows.sort(key=lambda r: (-r["count"], -len(r["areas"]), r["node"]["title"]))
        return rows[:limit] if limit else rows

    def readings(self, n):
        """For an open card, each of its open theorems that has a proven version
        for one reading: (open name, proven name, the proven theorem's
        docstring as HTML)."""
        out = []
        for name in n["lean"]:
            if self.decls.get(name, {}).get("status") != "open":
                continue
            for p in self.pairs.get(name, []):
                out.append({"open": name, "proven": p, "doc": docstring_html(self.decls[p].get("docstring"))})
        return out

    def unpaired_open(self):
        """Open theorems with no proven `_of_` version found by name."""
        return sorted(n for n, d in self.decls.items() if d["status"] == "open" and n not in self.pairs)
