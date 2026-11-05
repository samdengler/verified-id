import Rules.OneId.Photoid
import Rules.OneId.BoardingPass

/-!
# Matching a photoid to a boarding pass

For contactless travel a touchpoint needs a boarding pass together with the
face image of a photoid (§4.1.2), and the guide assumes the holder of the
wallet is a passenger (§3.2).  The guide gives no rule for deciding that a
photoid and a boarding pass presented together are about the same traveler.
This module keeps the readings of what a relying party could check from the
two credentials alone.  A reading that uses the device key is added with the
presentation flows.
-/

namespace Rules.OneId

open Rules.Core

/-- A person a credential is about.  The guide calls this the subject of the
credential (§2). -/
structure Traveler where
  /-- A reference that tells one person from another.  It is not a data
  element of any credential. -/
  id : String
  deriving DecidableEq, Repr, Inhabited

/-- A credential together with the traveler its issuer issued it about.  The
issuer knows the subject; a relying party sees only the credential. -/
structure Issued where
  /-- The credential. -/
  mdoc : Mdoc
  /-- The traveler the credential is about. -/
  subject : Traveler
  deriving DecidableEq, Repr, Inhabited

/-- The identifier of the family name in the base identity namespace, as the
guide's example requests write it (§4.2.1.3). -/
def familyNameId : String := "family_name"

/-- The identifier of the given name in the base identity namespace, as the
guide's example requests write it (§4.2.1.3). -/
def givenNameId : String := "given_name"

/-- The family name and given name a photoid carries, if it carries both as
text. -/
def Photoid.name (m : Mdoc) : Option (String × String) :=
  match m.element? baseNameSpace familyNameId, m.element? baseNameSpace givenNameId with
  | some (.text family), some (.text given) => some (family, given)
  | _, _ => none

/-- What a relying party checks before it treats a photoid and a boarding pass
as being about the same traveler.  The guide states no rule, so the model
keeps readings.  The two here use only the content of the two credentials, and
they are not the only ones: a check of the device key, a link the issuer
asserts, names brought to a common form, or a name with a date of birth are
others, to be added as the rules they need are modelled. -/
inductive MatchReading
  /-- Nothing is checked: any photoid goes with any boarding pass.  This is
  the guide as written. -/
  | notChecked
  /-- The names agree: the family name and given name of the photoid equal the
  passenger name the boarding pass string carries. -/
  | namesAgree
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When a photoid and a boarding pass are presented together, the
system shall accept the pair only if both are about the same traveler.

Story: As an airport touchpoint, I want the face I match and the boarding pass
I admit to belong to one traveler, so that nobody boards on another person's
boarding pass.

Acceptance criteria:

* OID-107.1: If a photoid and a boarding pass presented together are about
  different travelers, then the system shall reject the pair.
* OID-107.2: When a photoid and a boarding pass presented together are about
  the same traveler, the system shall accept the pair.

The guide requires both credentials at a contactless touchpoint (§4.1.2) and
assumes the holder is a passenger (§3.2).  It names no data element to
compare and no way to compare them, so the check is the reading
({name}`MatchReading`).  The passenger name inside the boarding pass string
comes from Resolution 792 ({name}`Resolution792`).  Who a credential is about
is fixed when it is issued, and the guide puts issuance out of scope (§1.4),
so no check of the two credentials' content can give both criteria: any pair
it accepts could have been issued about two travelers.  The guarantee also
needs a rule about issuance. -/
@[ears "OID-107", source "tig-4.1.2 tig-3.2 tig-1.4 model-matching", assumes "x-res792-bcbp x-23220-4-table-c1"]
def travelerMatch (r : MatchReading) (x : Resolution792) (photoid boardingPass : Mdoc) : Bool :=
  match r with
  | .notChecked => true
  | .namesAgree =>
    match Photoid.name photoid, (BoardingPass.bcbpString boardingPass).bind x.passenger with
    | some a, some b => a == b
    | _, _ => false

end Rules.OneId
