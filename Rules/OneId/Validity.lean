import Rules.OneId.Photoid
import Rules.OneId.BoardingPass

/-!
# How long a credential stays valid

A credential carries the instant its validity ends.  The guide says how an
issuer sets it for a boarding pass (§4.1.2, implementation consideration 1)
and says a verifier checks time validity (§4.2.1.2, step 6).  It gives no rule
for a photoid.  The guide puts revocation out of scope (§1.4), so within its
rules a credential from a trusted issuer stops being accepted only when its
validity ends.
-/

namespace Rules.OneId

open Rules.Core

/-- What the guide leaves undecided about the instant a validity ends.  The
check itself is in ISO/IEC 18013-5, which this project has not read, so this
is the one point of it the model can name.  Anything else that check requires
is not modelled. -/
structure ExpiryReading where
  /-- Whether a credential is still valid at the exact instant its validity
  ends. -/
  validAtEnd : Bool
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When the current time is after the end of a credential's validity,
the system shall treat the credential as expired.

Story: As a relying party, I want a credential to count as expired once its
validity has ended, so that I never act on a boarding pass or a photoid that
is no longer in force.

Acceptance criteria:

* OID-105.1: When the current time is after the end of a credential's
  validity, the system shall treat the credential as expired.
* OID-105.2: While the current time is before the end of a credential's
  validity, the system shall treat the credential as not expired.
* OID-105.3: When a credential has expired, the system shall treat it as
  expired at every later time.
* OID-105.4: While the current time is no later than the end of a
  credential's validity, the system shall treat the credential as not expired.

The guide names the time validity check and leaves its details to ISO/IEC
18013-5.  Whether a credential is still valid at the exact instant its
validity ends is left to the reading ({name}`ExpiryReading`).  The guide says
nothing of a start of validity, so the model has none. -/
@[ears "OID-105", source "tig-4.1.2 tig-4.2.1.2", assumes "x-18013-5-validity"]
def expired (e : ExpiryReading) (m : Mdoc) (now : Instant) : Bool :=
  if e.validAtEnd then decide (m.validUntil < now) else decide (m.validUntil ≤ now)

/-- The facts about a journey that decide how long its boarding pass should
stay valid.  The issuer knows the scheduled departure when it signs the
boarding pass; the other two instants are known only later. -/
structure Journey where
  /-- The scheduled departure of the last leg of the journey. -/
  scheduledDeparture : Instant
  /-- When the last leg actually departs. -/
  actualDeparture : Instant
  /-- When the journey is completed. -/
  completed : Instant
  deriving DecidableEq, Repr, Inhabited

/-- Which departure the guide means by the departure of the last leg.  It
does not say, and the two differ when a flight is delayed or leaves early. -/
inductive DepartureReading
  /-- The scheduled departure, the one an issuer knows when it signs. -/
  | scheduled
  /-- The actual departure, which an issuer can follow only by signing the
  boarding pass again when the time changes. -/
  | actual
  deriving DecidableEq, Repr, Inhabited

/-- What the guide leaves undecided about the validity of a boarding pass. -/
structure ValidityReading where
  /-- Which departure the end of validity is measured from. -/
  departure : DepartureReading
  /-- How many seconds after that departure still count as "soon after".  The
  guide gives no limit. -/
  soonAfter : Nat
  deriving DecidableEq, Repr, Inhabited

/-- The departure of the last leg, under a reading of which departure the
guide means. -/
def Journey.departure (j : Journey) : DepartureReading → Instant
  | .scheduled => j.scheduledDeparture
  | .actual => j.actualDeparture

/-- EARS: When an issuer signs a boarding pass, the system shall accept its
validity only if it ends on or soon after the departure of the last leg of the
journey.

Story: As an airline, I want a boarding pass credential to stop being valid
shortly after the journey's last flight leaves, so that it cannot be presented
again once the journey is over.

Acceptance criteria:

* OID-104.1: If the validity of a boarding pass ends before the departure of
  the last leg of its journey, then the system shall reject it.
* OID-104.2: If the validity of a boarding pass ends later than soon after
  the departure of the last leg of its journey, then the system shall reject
  it.
* OID-104.3: While the current time is before the departure of the last leg
  of the journey, the system shall treat the boarding pass as not expired.
* OID-104.4: When the journey is completed, the system shall treat the
  boarding pass as expired.
* OID-104.5: While the last leg of the journey has not actually departed, the
  system shall treat the boarding pass as not expired.

The guide says the issuer MUST set the end of validity "on or soon after last
leg journey departure", and that this makes the boarding pass expire once the
journey is completed.  Which departure is meant and how long "soon after"
lasts are left to the reading ({name}`ValidityReading`).  In the first three
criteria the departure is the one the reading names.  The result lists the
requirements the validity breaks, and is empty for a validity the system
accepts. -/
@[ears "OID-104", source "tig-4.1.2", assumes "x-18013-5-validity"]
def BoardingPass.validityFindings (v : ValidityReading) (j : Journey) (m : Mdoc) : List Finding :=
  (if m.validUntil < j.departure v.departure then [.endsBeforeLastDeparture] else []) ++
    (if (j.departure v.departure).epochSeconds + v.soonAfter < m.validUntil.epochSeconds
     then [.endsLongAfterLastDeparture] else [])

/-- How the validity of a photoid relates to the expiry of the document it
was derived from.  The guide gives no rule.  These two readings are not the
only ones: a fixed longest period is a third, which the model cannot state
because the guide names no start of validity. -/
inductive PhotoidValidityReading
  /-- The issuer may set any end of validity. -/
  | unbounded
  /-- The validity of the photoid ends no later than the document expires. -/
  | endsWithDocument
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When an issuer signs a photoid, the system shall accept its validity
only if it ends no later than the allowed limit for the document it was
derived from.

Story: As a border authority, I want a photoid to stop being valid when the
passport it was derived from expires, so that an expired passport is not
accepted in digital form.

Acceptance criteria:

* OID-108.1: When the document a photoid was derived from has expired, the
  system shall treat the photoid as expired.

The guide sets the validity of a boarding pass and gives no rule for the
validity of a photoid, and it puts revocation out of scope (§1.4).  Whether
the validity of a photoid is tied to the expiry of its source document is
left to the reading ({name}`PhotoidValidityReading`).  The result lists the
requirements the validity breaks under the reading. -/
@[ears "OID-108", source "tig-4.1.1 tig-1.4 model-photoid-validity", assumes "x-18013-5-validity"]
def Photoid.validityFindings (r : PhotoidValidityReading) (documentExpiry : Instant) (m : Mdoc) :
    List Finding :=
  match r with
  | .unbounded => []
  | .endsWithDocument => if documentExpiry < m.validUntil then [.outlivesSourceDocument] else []

end Rules.OneId
