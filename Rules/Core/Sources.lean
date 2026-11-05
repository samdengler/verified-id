import Lean

/-!
# Sources

Where the rules come from.  Each rule names its sources with
{lit}`@[source "<key> ..."]`, and each key is listed here once, with the kind
of source, a title and a link.  The attribute rejects a key that is not here,
and the status executable fails on a rule with an EARS ID and no source.

The One ID guide is cited by section number.  It states no license, so the
titles are in our words and nothing from it is quoted at length.
-/

namespace Rules.Core

/-- The kind of a source a rule is written from.  A rule whose only sources
are the modeller's is an assumption until someone confirms it. -/
inductive SourceKind
  /-- A published industry standard, such as IATA's One ID guide. -/
  | standard
  /-- A law or a regulation. -/
  | regulation
  /-- An organisation's own written policy, contract or procedure. -/
  | policy
  /-- The rule set of a rules engine in production. -/
  | engine
  /-- Application source code. -/
  | code
  /-- An existing test suite. -/
  | test
  /-- Production data or logs. -/
  | data
  /-- An answer or an interview from a subject matter expert. -/
  | sme
  /-- The modeller's own choice, where no source states the rule. -/
  | modeller
  deriving DecidableEq, Repr, Inhabited

/-- The name of a kind of source, as the status file and the pages show it. -/
def SourceKind.label : SourceKind → String
  | .standard => "standard"
  | .regulation => "regulation"
  | .policy => "policy"
  | .engine => "engine"
  | .code => "code"
  | .test => "test"
  | .data => "data"
  | .sme => "sme"
  | .modeller => "modeller"

/-- A source the rules cite: the key a rule names it by, its kind, a title in
our words and a link. -/
structure Source where
  key : String
  kind : SourceKind
  title : String
  url : String
  deriving Repr, Inhabited

/-- The public copy of the One ID Technical Implementation Guide.  Its text is
the same as the approved 26.3 document the model was written from;
{lit}`docs/source-crosscheck.md` records the comparison. -/
def guideUrl : String :=
  "https://standards.atlassian.net/wiki/spaces/OneID/pages/2947416082/Technical+Implementation+Guide"

/-- A section of the One ID Technical Implementation Guide, version 26.3. -/
def guideSection (key number title : String) : Source :=
  { key, kind := .standard, title := s!"One ID Technical Implementation Guide 26.3, §{number} {title}",
    url := guideUrl }

/-- Every source the rules cite.  The guide's sections are named by number.
The modeller sources mark rules written where the guide states none. -/
def sources : List Source := [
  guideSection "tig-1.4" "1.4" "Technical Guidance Scope",
  guideSection "tig-2" "2" "Terminology",
  guideSection "tig-3.1" "3.1" "Functional Requirements",
  guideSection "tig-3.2" "3.2" "Assumption",
  guideSection "tig-4.1" "4.1" "Credential format and data model",
  guideSection "tig-4.1.1" "4.1.1" "photoid",
  guideSection "tig-4.1.2" "4.1.2" "Boarding pass",
  guideSection "tig-4.2.1.1" "4.2.1.1" "W3C Digital Credentials API",
  guideSection "tig-4.2.1.2" "4.2.1.2" "Remote presentation using mdoc over the DC API",
  guideSection "tig-4.2.1.3" "4.2.1.3" "Remote presentation using OpenID4VP with HAIP",
  guideSection "tig-4.2.2" "4.2.2" "Proximity presentation",
  guideSection "tig-annex-a" "5" "Annex A (informative), provisioning to the user device",
  guideSection "tig-annex-b" "6" "Annex B (informative), contactless travel",
  { key := "model-matching", kind := .modeller,
    title := "Readings of how a photoid and a boarding pass are matched, where the guide states no rule",
    url := "https://github.com/samdengler/verified-id/blob/main/Rules/OneId/Traveler.lean" },
  { key := "model-photoid-validity", kind := .modeller,
    title := "Readings of how long a photoid stays valid, where the guide states no rule",
    url := "https://github.com/samdengler/verified-id/blob/main/Rules/OneId/Validity.lean" },
  { key := "model-pair-device-key", kind := .modeller,
    title := "A reading that compares the device keys of a photoid and a boarding pass, where the guide states no rule",
    url := "https://github.com/samdengler/verified-id/blob/main/Rules/OneId/Presentation.lean" }
]

/-- The source a key names, if the list has it. -/
def sourceOf? (key : String) : Option Source :=
  sources.find? (·.key == key)

end Rules.Core
