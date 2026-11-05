import Rules.OneId.Mdoc

/-!
# The photoid credential

The photoid holds the identity attributes of the holder, including a face
image (§4.1.1).  The guide takes its profile from ISO/IEC TS 23220-4 Annex C
and adds requirements of its own: the document type, which namespaces must be
present and which are recommended, and where the portrait comes from.  The
tables that list the data elements are in the ISO document, which this project
has not read, so the rules take them as a parameter.
-/

namespace Rules.OneId

open Rules.Core

/-- The document type of a photoid (§4.1.1). -/
def photoidDocType : String := "org.iso.23220.photoid.1"

/-- The base identity namespace, which holds the attributes of a natural
person whatever the document (§4.1.1). -/
def baseNameSpace : String := "org.iso.23220.1"

/-- The photoid namespace, which holds data of the travel document the photoid
was derived from (§4.1.1).  Its name is the same string as the document
type. -/
def photoidNameSpace : String := "org.iso.23220.photoid.1"

/-- The data groups namespace, which holds the raw chip data of the passport
(§4.1.1). -/
def dataGroupsNameSpace : String := "org.iso.23220.datagroups.1"

/-- The identifier of the face image in the base identity namespace. -/
def portraitId : String := "portrait"

/-- The identifier of the live face image captured at enrolment, in the
photoid namespace. -/
def enrolmentPortraitId : String := "enrolment_portrait_image"

/-- The identifier of data group 2 in the data groups namespace, as the guide
writes it. -/
def dg2Id : String := "dg2"

/-- What a table of an external specification says about whether a data
element is present. -/
inductive Presence
  /-- The data element must be present. -/
  | mandatory
  /-- The data element may be absent. -/
  | optional
  /-- Anything else the table may say, such as a condition.  The model
  requires nothing of such an element. -/
  | other
  deriving DecidableEq, Repr, Inhabited

/-- The encoding a table gives a data element, as far as the model tells
encodings apart. -/
inductive Encoding
  /-- A text string. -/
  | text
  /-- A byte string. -/
  | bytes
  /-- A yes or no value. -/
  | flag
  /-- Any other encoding.  The model does not check it. -/
  | other
  deriving DecidableEq, Repr, Inhabited

/-- Whether a value has an encoding.  An encoding the model does not tell
apart accepts every value. -/
def Encoding.accepts : Encoding → Value → Bool
  | .text, .text _ => true
  | .bytes, .bytes _ => true
  | .flag, .flag _ => true
  | .other, _ => true
  | _, _ => false

/-- One row of a table of data elements. -/
structure TableEntry where
  /-- The identifier of the data element. -/
  identifier : String
  /-- Whether it must be present. -/
  presence : Presence
  /-- Its encoding. -/
  encoding : Encoding
  deriving DecidableEq, Repr, Inhabited

/-- A table of data elements from an external specification. -/
structure ElementTable where
  /-- The rows of the table. -/
  entries : List TableEntry
  deriving DecidableEq, Repr, Inhabited

/-- The identifiers a table marks as mandatory. -/
def ElementTable.mandatory (t : ElementTable) : List String :=
  (t.entries.filter (·.presence == .mandatory)).map (·.identifier)

/-- The row of a table for an identifier, if the table lists it. -/
def ElementTable.entry? (t : ElementTable) (identifier : String) : Option TableEntry :=
  t.entries.find? (·.identifier == identifier)

/-- Tables C.1, C.2 and C.3 of ISO/IEC TS 23220-4 Annex C, which the guide
refers to for the identifier, presence and encoding of each photoid data
element.  This project has not read them, so the rules take them as a
parameter, and a guarantee counts as proven only when it holds for every
content the tables could have. -/
structure PhotoidTables where
  /-- Table C.1: the base identity namespace. -/
  base : ElementTable
  /-- Table C.2: the photoid namespace. -/
  photoid : ElementTable
  /-- Table C.3: the data groups namespace. -/
  dataGroups : ElementTable
  deriving DecidableEq, Repr, Inhabited

/-- The table for a namespace of a photoid, if the namespace is one of the
three the guide lists. -/
def PhotoidTables.tableOf (t : PhotoidTables) (name : String) : Option ElementTable :=
  if name = baseNameSpace then some t.base
  else if name = photoidNameSpace then some t.photoid
  else if name = dataGroupsNameSpace then some t.dataGroups
  else none

/-- The kind of identity document a photoid was derived from.  The issuer
knows it; a relying party sees it only through the photoid namespace, which
is recommended and may be absent. -/
inductive SourceDocument
  /-- A passport. -/
  | passport
  /-- Another identity document with a face image, which the guide's
  terminology allows (§2). -/
  | other
  deriving DecidableEq, Repr, Inhabited

/-- The parts of the photoid requirements the guide leaves undecided.  The
model takes each as a parameter, a reading of the guide.  A guarantee counts
as proven only when it holds for every reading. -/
structure PhotoidReading where
  /-- Whether the guide itself makes the portrait mandatory.  It says the
  portrait MUST hold the passport's image and that the business requirements
  need it, and it also refers the presence of every base element to Table
  C.1. -/
  portraitRequired : Bool
  /-- Whether a photoid may carry a namespace other than the three the guide
  lists, or a data element its table does not list.  The guide lists three
  namespaces and does not say the lists are closed. -/
  unlistedDataAllowed : Bool
  /-- Whether the portrait must be the same bytes as data group 2 when the
  photoid carries both.  The guide says the portrait MUST hold "the dg2 or
  equivalent image data" and does not say what equivalent means.  A reading
  in which the portrait is the image inside the data group cannot be stated
  without ICAO Doc 9303, so it is not among the readings here. -/
  portraitIsDg2 : Bool
  /-- Whether the photoid namespace, once present, must hold every data
  element Table C.2 marks mandatory.  The guide recommends "this namespace
  and data elements presence" in one sentence, which can be read either
  way. -/
  photoidTableBinds : Bool
  /-- Whether the data groups namespace, once present, must hold every data
  element Table C.3 marks mandatory.  The guide's sentence has the same
  form. -/
  dataGroupsTableBinds : Bool
  /-- Whether a photoid in which a namespace name or a data element
  identifier repeats is rejected.  The guide does not say names are unique.
  Where a repeat is allowed, every copy of a name is checked, and a data
  element counts as present when a request for it returns a value. -/
  repeatedNamesRefused : Bool
  /-- Whether a photoid must be derived from a passport.  The terminology
  allows an equivalent identity document (§2); §4.1.1 says the values should
  always come from the passport and that the portrait MUST hold image data
  sourced from the passport. -/
  passportRequired : Bool
  deriving DecidableEq, Repr, Inhabited

/-- The identifiers a table marks mandatory that a namespace lacks. -/
def missingMandatory (t : ElementTable) (ns : NameSpace) : List String :=
  t.mandatory.filter fun id => (ns.element? id).isNone

/-- The data elements of a namespace whose value does not have the encoding
its table gives. -/
def wronglyEncoded (t : ElementTable) (ns : NameSpace) : List DataElement :=
  ns.elements.filter fun e =>
    match t.entry? e.identifier with
    | some entry => !entry.encoding.accepts e.value
    | none => false

/-- The findings about one base identity namespace: it must hold every data
element Table C.1 marks mandatory, each data element in the encoding the table
gives, and the portrait under the reading that the guide requires it. -/
def Photoid.baseIn (r : PhotoidReading) (t : PhotoidTables) (ns : NameSpace) : List Finding :=
  (missingMandatory t.base ns).map (.missingElement baseNameSpace ·) ++
    (wronglyEncoded t.base ns).map (.wrongEncoding baseNameSpace ·.identifier) ++
    (if r.portraitRequired && (ns.element? portraitId).isNone && !t.base.mandatory.contains portraitId
     then [.missingElement baseNameSpace portraitId] else [])

/-- The findings about the base identity namespace: it must be present, and
every namespace of that name must meet the requirements.  Checking every copy
matters only under the reading that names may repeat. -/
def Photoid.baseFindings (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc) : List Finding :=
  match m.nameSpacesNamed baseNameSpace with
  | [] => [.missingNameSpace baseNameSpace]
  | copies => copies.flatMap (Photoid.baseIn r t)

/-- The findings about a recommended namespace that is present: under the
reading that its table binds, each mandatory data element it lacks. -/
def Photoid.tableFindings (binds : Bool) (t : ElementTable) (name : String) (m : Mdoc) :
    List Finding :=
  if binds then
    (m.nameSpacesNamed name).flatMap fun ns => (missingMandatory t ns).map (.missingElement name ·)
  else []

/-- What a namespace of a photoid carries that the guide does not list: the
namespace itself when it is not one of the three, or else each data element
its table does not list. -/
def Photoid.unlistedIn (t : PhotoidTables) (ns : NameSpace) : List Finding :=
  match t.tableOf ns.name with
  | none => [.unlistedNameSpace ns.name]
  | some table =>
    (ns.elements.filter fun e => (table.entry? e.identifier).isNone).map
      (.unlistedElement ns.name ·.identifier)

/-- The findings about namespaces and data elements the guide does not list
for a photoid, under the reading that the lists are closed. -/
def Photoid.unlistedFindings (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc) : List Finding :=
  if r.unlistedDataAllowed then [] else m.nameSpaces.flatMap (Photoid.unlistedIn t)

/-- The finding about a portrait that differs from a data group 2 of the same
photoid, under the reading that they must be the same. -/
def Photoid.portraitFindings (r : PhotoidReading) (m : Mdoc) : List Finding :=
  if r.portraitIsDg2 &&
      (m.values baseNameSpace portraitId).any fun p =>
        (m.values dataGroupsNameSpace dg2Id).any fun d => p != d
  then [.portraitDiffersFromDg2] else []

/-- EARS: The system shall accept a credential as a photoid only when it meets
every requirement the guide places on one.

Story: As a relying party, I want to know what every photoid I accept is sure
to contain, so that I can build admissibility checks and face matching on it.

Acceptance criteria:

* OID-101.1: If the document type of a credential is not the photoid document
  type, then the system shall reject it as a photoid.
* OID-101.2: If a photoid lacks the base identity namespace, then the system
  shall reject it.
* OID-101.3: If a photoid lacks a data element that Table C.1 marks mandatory
  in the base identity namespace, then the system shall reject it.
* OID-101.4: If a data element of the base identity namespace does not have
  the encoding Table C.1 gives it, then the system shall reject the photoid.
* OID-101.5: If a photoid has no portrait, then the system shall reject it.
* OID-101.6: If a photoid carries a namespace other than the three the guide
  lists, or a data element its table does not list, then the system shall
  reject it.
* OID-101.7: If a photoid carries a portrait and a data group 2 that differ,
  then the system shall reject it.
* OID-101.8: If a photoid carries the photoid namespace without a data element
  that Table C.2 marks mandatory, then the system shall reject it.
* OID-101.9: If a photoid carries the data groups namespace without a data
  element that Table C.3 marks mandatory, then the system shall reject it.

The document type and the base identity namespace are stated with MUST
(§4.1.1), and the identifier, presence and encoding of each base element are
referred with MUST to Table C.1 of ISO/IEC TS 23220-4, taken here as the
parameter {name}`PhotoidTables`.  The model tells only a text string, a byte
string and a yes or no value apart.  The portrait, data the guide does not
list, the relation between the portrait and data group 2, the tables of the
recommended namespaces, and repeated names are left to the reading
({name}`PhotoidReading`).  The result lists every requirement the content of
the credential breaks, and is empty for a photoid whose content the system
accepts.  The document a photoid was derived from and the length of its
validity are not part of its content; {lit}`Photoid.sourceFindings` and
{lit}`Photoid.validityFindings` check them. -/
@[ears "OID-101", source "tig-4.1.1 tig-2",
  assumes "x-23220-4-annex-c x-23220-4-table-c1 x-23220-4-table-c2 x-23220-4-table-c3 x-23220-2-encoding x-18013-5-data-model"]
def Photoid.violations (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc) : List Finding :=
  docTypeFindings photoidDocType m ++ nameFindings r.repeatedNamesRefused m ++
    Photoid.baseFindings r t m ++
    Photoid.tableFindings r.photoidTableBinds t.photoid photoidNameSpace m ++
    Photoid.tableFindings r.dataGroupsTableBinds t.dataGroups dataGroupsNameSpace m ++
    Photoid.unlistedFindings r t m ++ Photoid.portraitFindings r m

/-- The recommendations about one recommended namespace: that it be present,
with every data element its table marks mandatory. -/
def Photoid.nameSpaceAdvisories (t : ElementTable) (name : String) (extra : List String) (m : Mdoc) :
    List Advisory :=
  match m.nameSpace? name with
  | none => [.missingRecommendedNameSpace name]
  | some ns =>
    (missingMandatory t ns ++ extra.filter fun id => (ns.element? id).isNone && !t.mandatory.contains id).map
      (.missingRecommendedElement name ·)

/-- EARS: Where a photoid does not follow a recommendation of the guide, the
system shall report the recommendation.

Story: As an issuer, I want to know which recommendations of the guide a
photoid I issue does not follow, so that I can decide whether to add the
passport data a border authority may ask for later.

Acceptance criteria:

* OID-102.1: When a photoid lacks the photoid namespace or the data groups
  namespace, the system shall report each missing namespace as a
  recommendation it does not follow.
* OID-102.2: When a photoid carries the photoid namespace without the image
  captured at enrolment, the system shall report the missing image as a
  recommendation it does not follow.
* OID-102.3: When a photoid was derived from a document other than a passport,
  the system shall report that as a recommendation it does not follow.
* OID-102.4: When a photoid lacks the photoid namespace or the data groups
  namespace, the system shall report no broken requirement for the missing
  namespace.

The guide recommends the photoid namespace with the presence of Table C.2,
the image captured at enrolment, the data groups namespace with the presence
of Table C.3 (§4.1.1), and that the values come from the passenger's passport.
Missing a recommended namespace is not a finding of
{name}`Photoid.violations` under any reading.  Whether a source other than a
passport is only a recommendation not followed, or a reason to reject, is the
reading of {lit}`Photoid.sourceFindings`. -/
@[ears "OID-102", source "tig-4.1.1 tig-2",
  assumes "x-23220-4-table-c2 x-23220-4-table-c3 x-icao-9303-10"]
def Photoid.advisories (t : PhotoidTables) (source : SourceDocument) (m : Mdoc) : List Advisory :=
  (if source = .passport then [] else [.notDerivedFromPassport]) ++
    Photoid.nameSpaceAdvisories t.photoid photoidNameSpace [enrolmentPortraitId] m ++
    Photoid.nameSpaceAdvisories t.dataGroups dataGroupsNameSpace [] m

/-- EARS: When an issuer derives a photoid from an identity document, the
system shall accept the photoid only if the guide allows that kind of
document.

Story: As a border authority, I want to know whether a photoid can come from a
document other than a passport, so that I know what a photoid stands for when
I check admissibility.

Acceptance criteria:

* OID-109.1: If a photoid was derived from a document other than a passport,
  then the system shall reject it.

The terminology says a photoid can be derived from a passport or an
equivalent identity document (§2).  §4.1.1 says the values SHOULD always be
derived from the passport, and that the portrait MUST hold image data sourced
from the passport.  Whether the second makes a passport mandatory is left to
the reading ({name}`PhotoidReading`).  The kind of source document is a fact
the issuer knows; no data element the guide requires carries it. -/
@[ears "OID-109", source "tig-2 tig-4.1.1"]
def Photoid.sourceFindings (r : PhotoidReading) (source : SourceDocument) : List Finding :=
  if r.passportRequired && source != .passport then [.notFromPassport] else []

end Rules.OneId
