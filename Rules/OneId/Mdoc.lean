import Mathlib.Tactic
import Rules.Core.Attributes
import Rules.Core.Time

/-!
# Credentials and their data elements

The One ID guide stores both of its credentials, the photoid and the boarding
pass, in the ISO mdoc format (§4.1).  This module holds what the guide says
every such credential has: a document type, namespaces, data elements
identified within a namespace, and an end of validity.  The guide leaves the
rest of the format to ISO/IEC 18013-5, which this project has not read.
-/

namespace Rules.OneId

open Rules.Core

/-- The value of a data element, as far as the guide tells encodings apart. -/
inductive Value
  /-- A text string, the encoding the guide gives the boarding pass string. -/
  | text (s : String)
  /-- A byte string, such as an image or a passport data group. -/
  | bytes (b : List Nat)
  /-- A yes or no value. -/
  | flag (b : Bool)
  /-- Any other value.  The model does not look inside it. -/
  | other (description : String)
  deriving DecidableEq, Repr, Inhabited

/-- One piece of information about the subject of a credential.  The guide
uses claim, data element and data attribute for the same thing (§2). -/
structure DataElement where
  /-- The identifier of the data element within its namespace. -/
  identifier : String
  /-- Its value. -/
  value : Value
  deriving DecidableEq, Repr, Inhabited

/-- A named group of data elements inside a credential. -/
structure NameSpace where
  /-- The name of the namespace, such as {lit}`org.iata.bcbp.1`. -/
  name : String
  /-- The data elements it holds. -/
  elements : List DataElement
  deriving DecidableEq, Repr, Inhabited

/-- A digital credential in the mdoc format, as far as the guide describes
one: a document type, namespaces of data elements, and the instant its
validity ends.  The issuer's signature and the device key belong to the
presentation flows and are not modelled yet. -/
structure Mdoc where
  /-- The document type, a string that names the kind of credential (§2). -/
  docType : String
  /-- The namespaces the credential holds. -/
  nameSpaces : List NameSpace
  /-- The end of the validity the issuer signed (§4.1.2 calls it
  {lit}`validUntil`). -/
  validUntil : Instant
  deriving DecidableEq, Repr, Inhabited

/-- The value of a data element of a namespace, if the namespace has one with
that identifier. -/
def NameSpace.element? (ns : NameSpace) (identifier : String) : Option Value :=
  (ns.elements.find? (·.identifier == identifier)).map (·.value)

/-- The namespace of a credential with a given name, if it has one. -/
def Mdoc.nameSpace? (m : Mdoc) (name : String) : Option NameSpace :=
  m.nameSpaces.find? (·.name == name)

/-- Every namespace of a credential with a given name.  There is at most one
when the names of the credential are unique. -/
def Mdoc.nameSpacesNamed (m : Mdoc) (name : String) : List NameSpace :=
  m.nameSpaces.filter (·.name == name)

/-- Every value a credential holds under a namespace name and an identifier.
There is at most one when the names of the credential are unique. -/
def Mdoc.values (m : Mdoc) (name identifier : String) : List Value :=
  (m.nameSpacesNamed name).flatMap fun ns =>
    (ns.elements.filter (·.identifier == identifier)).map (·.value)

/-- EARS: The system shall identify each data element of a credential by the
name of its namespace and its identifier.

Story: As a relying party, I want to name one data element of a credential by
its namespace and its identifier, so that I can request only that element and
the wallet can disclose it without the others.

Acceptance criteria:

* OID-106.1: When the namespace names of a credential and the identifiers
  within each namespace are unique, the system shall return the value of each
  data element for the name of its namespace and its identifier.
* OID-106.2: If a credential has no data element with a given namespace name
  and identifier, then the system shall return no value for them.
* OID-106.3: If two namespaces of a credential have the same name, or two
  data elements of one namespace have the same identifier, then the system
  shall reject the credential.

The guide says selective disclosure works on individual data elements
(§4.1.1) and that requests name namespaces and data elements (§4.2.1.2).  It
leaves the structure itself to ISO/IEC 18013-5, and does not say that names
are unique.  When a name repeats, a request for it is ambiguous.  Whether such
a credential is rejected is left to the reading of each credential type.
Where it is not rejected, the checks of a credential look at every copy of a
name, so a requirement holds whichever copy a reader takes.  The result is the
value of the first match, or {lean}`none` when the credential has no such
element. -/
@[ears "OID-106", source "tig-4.1 tig-4.1.1", assumes "x-18013-5-data-model"]
def Mdoc.element? (m : Mdoc) (nameSpace identifier : String) : Option Value :=
  (m.nameSpace? nameSpace).bind (·.element? identifier)

/-- Whether the names in a credential are unique: no two namespaces share a
name, and no two data elements of one namespace share an identifier.  When
they are not, a request for a name is ambiguous. -/
@[assumes "x-18013-5-data-model"]
def Mdoc.wellFormed (m : Mdoc) : Bool :=
  decide (m.nameSpaces.map (·.name)).Nodup &&
    m.nameSpaces.all fun ns => decide (ns.elements.map (·.identifier)).Nodup

/-- A reason a credential is rejected: it breaks something the guide says with
MUST or SHALL, or something a reading of the guide requires. -/
inductive Finding
  /-- The document type is not the one the guide gives for this credential. -/
  | wrongDocType (expected found : String)
  /-- Two namespaces share a name, or two data elements of one namespace
  share an identifier. -/
  | repeatedName
  /-- A namespace the guide requires is absent. -/
  | missingNameSpace (name : String)
  /-- A data element the guide requires is absent. -/
  | missingElement (nameSpace identifier : String)
  /-- A data element that must be a text string is something else. -/
  | notText (nameSpace identifier : String)
  /-- A data element does not have the encoding its table gives. -/
  | wrongEncoding (nameSpace identifier : String)
  /-- The photoid was derived from a document other than a passport. -/
  | notFromPassport
  /-- The boarding pass string does not follow IATA Resolution 792. -/
  | notResolution792
  /-- The credential carries a namespace the guide does not list for it. -/
  | unlistedNameSpace (name : String)
  /-- The credential carries a data element the guide does not list for its
  namespace. -/
  | unlistedElement (nameSpace identifier : String)
  /-- The portrait is not the image in data group 2 of the same credential. -/
  | portraitDiffersFromDg2
  /-- The validity ends before the last leg of the journey departs. -/
  | endsBeforeLastDeparture
  /-- The validity ends later than soon after the last leg departs. -/
  | endsLongAfterLastDeparture
  /-- The validity ends after the document the credential was derived from
  expires. -/
  | outlivesSourceDocument
  deriving DecidableEq, Repr, Inhabited

/-- Something the guide recommends, with SHOULD or RECOMMENDED, that a
credential does not follow.  It does not make the credential unacceptable. -/
inductive Advisory
  /-- A namespace the guide recommends is absent. -/
  | missingRecommendedNameSpace (name : String)
  /-- A data element the guide recommends is absent. -/
  | missingRecommendedElement (nameSpace identifier : String)
  /-- The photoid was derived from a document other than a passport. -/
  | notDerivedFromPassport
  deriving DecidableEq, Repr, Inhabited

/-- The finding for a credential whose document type is not the expected
one. -/
def docTypeFindings (expected : String) (m : Mdoc) : List Finding :=
  if m.docType = expected then [] else [.wrongDocType expected m.docType]

/-- The finding for a credential whose names are not unique, under the
reading that such a credential is rejected. -/
def nameFindings (refused : Bool) (m : Mdoc) : List Finding :=
  if refused && !m.wellFormed then [.repeatedName] else []

end Rules.OneId
