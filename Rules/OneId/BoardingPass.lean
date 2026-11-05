import Rules.OneId.Mdoc

/-!
# The boarding pass credential

The guide models a bar-coded boarding pass as an mdoc with one namespace and
one data element, a text string that follows IATA Resolution 792 (§4.1.2).
The resolution is not available to this project, so the rules take what it
decides as a parameter.
-/

namespace Rules.OneId

open Rules.Core

/-- The document type of a boarding pass (§4.1.2). -/
def boardingPassDocType : String := "org.iata.boardingpass.1"

/-- The namespace that holds the boarding pass string (§4.1.2). -/
def bcbpNameSpace : String := "org.iata.bcbp.1"

/-- The identifier of the boarding pass string, the one data element the
guide lists for the namespace (§4.1.2). -/
def bcbpStringId : String := "bcbp_string"

/-- What IATA Resolution 792 decides about a boarding pass string.  This
project has not read the resolution, so the rules take its answers as a
parameter, and a guarantee counts as proven only when it holds for every
value of it. -/
structure Resolution792 where
  /-- Whether a string follows the format of the resolution. -/
  follows : String → Bool
  /-- The family name and given name of the passenger a string carries, if it
  carries them. -/
  passenger : String → Option (String × String)

/-- The parts of the boarding pass requirements the guide leaves undecided. -/
structure BoardingPassReading where
  /-- Whether a boarding pass may carry a namespace or a data element the
  guide does not list.  The guide lists one namespace with one data element,
  and says a later version may add a namespace (§4.1.2, implementation
  consideration 3).  It does not say whether one is allowed today. -/
  unlistedDataAllowed : Bool
  /-- Whether a boarding pass in which a namespace name or a data element
  identifier repeats is rejected.  The guide does not say names are unique.
  Where a repeat is allowed, every copy of a name is checked. -/
  repeatedNamesRefused : Bool
  deriving DecidableEq, Repr, Inhabited

/-- The findings about the boarding pass strings of one namespace: each must
be a text string that follows Resolution 792. -/
def BoardingPass.stringIn (x : Resolution792) (ns : NameSpace) : List Finding :=
  (ns.elements.filter (·.identifier == bcbpStringId)).flatMap fun e =>
    match e.value with
    | .text s => if x.follows s then [] else [.notResolution792]
    | _ => [.notText bcbpNameSpace bcbpStringId]

/-- The findings about the boarding pass string: its namespace must be
present, a request for the string must return a value, and every boarding
pass string the credential holds must be a text string that follows Resolution
792.  Checking every copy matters only under the reading that names may
repeat. -/
def BoardingPass.stringFindings (x : Resolution792) (m : Mdoc) : List Finding :=
  match m.nameSpacesNamed bcbpNameSpace with
  | [] => [.missingNameSpace bcbpNameSpace]
  | copies =>
    (if (m.element? bcbpNameSpace bcbpStringId).isNone
     then [.missingElement bcbpNameSpace bcbpStringId] else []) ++
      copies.flatMap (BoardingPass.stringIn x)

/-- The findings about namespaces and data elements the guide does not list
for a boarding pass, under the reading that the lists are closed. -/
def BoardingPass.unlistedFindings (r : BoardingPassReading) (m : Mdoc) : List Finding :=
  if r.unlistedDataAllowed then []
  else
    (m.nameSpaces.filter (·.name != bcbpNameSpace)).map (.unlistedNameSpace ·.name) ++
      (m.nameSpaces.filter (·.name == bcbpNameSpace)).flatMap fun ns =>
        (ns.elements.filter (·.identifier != bcbpStringId)).map (.unlistedElement bcbpNameSpace ·.identifier)

/-- EARS: The system shall accept a credential as a boarding pass only when it
meets every requirement the guide places on one.

Story: As an airport touchpoint, I want every boarding pass credential I
accept to carry one boarding pass string in the standard format, so that I can
process it as I process a printed or mobile bar code.

Acceptance criteria:

* OID-103.1: If the document type of a credential is not the boarding pass
  document type, then the system shall reject it as a boarding pass.
* OID-103.2: If a boarding pass lacks the boarding pass namespace, then the
  system shall reject it.
* OID-103.3: If a boarding pass lacks the boarding pass string, then the
  system shall reject it.
* OID-103.4: If the boarding pass string is not a text string, then the system
  shall reject the boarding pass.
* OID-103.5: If the boarding pass string does not follow IATA Resolution 792,
  then the system shall reject the boarding pass.
* OID-103.6: If a boarding pass carries a namespace or a data element the
  guide does not list, then the system shall reject it.

The document type, the namespace, the data element and its encoding are stated
with MUST in the two tables of §4.1.2.  What makes a string follow Resolution
792 is the parameter {name}`Resolution792`.  Whether unlisted data and
repeated names are allowed is left to the reading
({name}`BoardingPassReading`).  The result lists every requirement the
content of the credential breaks, and is empty for a boarding pass whose
content the system accepts.  The length of its validity is checked by
{lit}`BoardingPass.validityFindings`. -/
@[ears "OID-103", source "tig-4.1.2",
  assumes "x-res792-bcbp x-cbor-tstr x-18013-5-data-model"]
def BoardingPass.violations (r : BoardingPassReading) (x : Resolution792) (m : Mdoc) : List Finding :=
  docTypeFindings boardingPassDocType m ++ nameFindings r.repeatedNamesRefused m ++
    BoardingPass.stringFindings x m ++
    BoardingPass.unlistedFindings r m

/-- The boarding pass string of a credential, if it has one that is a text
string. -/
def BoardingPass.bcbpString (m : Mdoc) : Option String :=
  match m.element? bcbpNameSpace bcbpStringId with
  | some (.text s) => some s
  | _ => none

end Rules.OneId
