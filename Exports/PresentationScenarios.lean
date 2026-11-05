import Exports.Scenarios
import Oracle.Presentation

set_option doc.verso false

/-!
# Presentation scenarios

Presentations a product site can show: the credentials a wallet holds, the
request as the wallet received it, the holder's consent, the relying party's
own request and the response it receives, and in the OpenID4VP profile the
request as it travels and the wallet's list of trusted verifiers.  They are
built with the definitions behind the `@[case]` examples of
`Rules/OneId/PresentationExamples.lean`.

The default presentation is the honest check-in of the traveler of the default
trip, Alice Martin, in each profile, built so that every rule gives the same
answer under every reading.  Every other scenario reproduces an example: the
example's record, or the part of it about the scenario's profile, is
recomputed from the scenario's own inputs, and `lake exe oneid-facts` stops if
it differs from what the example computes.

The issuers, keys, nonces and origins are invented, and so are the ISO session
transcripts and the boarding pass format, so every scenario carries a flag
saying so.
-/

open Lean Rules.Core Rules.OneId Oracle

namespace Exports

/-- One presentation a product site can show. -/
structure PresentationScenario where
  /-- A stable identifier. -/
  id : String
  /-- One line that says what happens. -/
  title : String
  /-- Whether this is the presentation a site shows first in its profile. -/
  isDefault : Bool := false
  /-- The profile of the presentation. -/
  profile : Profile
  /-- The credentials the wallet holds. -/
  held : List Credential := []
  /-- The request as the wallet received it. -/
  seen : Option Request := none
  /-- What the holder approved. -/
  consent : Option Consent := none
  /-- The relying party's own request. -/
  request : Option Request := none
  /-- The response the relying party receives. -/
  response : Option Response := none
  /-- The instant of the check. -/
  checkedAt : Instant := beforeDeparture
  /-- The issuers the relying party trusts. -/
  trusted : List Issuer := trustedIssuers
  /-- The invented stand-in for the ISO session transcripts. -/
  transcripts : String := "exampleIsoTranscripts"
  /-- In the OpenID4VP profile, the request as it travels to the wallet. -/
  authorization : Option OpenId4Vp.AuthorizationRequest := none
  /-- In the OpenID4VP profile, the origin the wallet received the request
  from. -/
  seenOrigin : Option Origin := none
  /-- In the OpenID4VP profile, the wallet's list of trusted verifiers. -/
  trustedVerifiers : List OpenId4Vp.Certificate := []
  /-- In the mdoc profile, the request as the guide's step 1 describes it. -/
  deviceRequest : Option MdocProfile.DeviceRequest := none
  /-- In proximity, the sessions of the deployment. -/
  sessions : List Proximity.Session := []
  /-- The `@[case]` example the scenario reproduces. -/
  reproduces : Option Name := none

/-- The ISO transcripts a scenario names. -/
def PresentationScenario.iso (s : PresentationScenario) : IsoTranscripts :=
  (isoFormats.lookup s.transcripts).getD exampleIsoTranscripts

/-- The photoid and the boarding pass a response presents, in that order, if
it presents one of each. -/
def pairOf (response : Response) : Option (Presented × Presented) := do
  let p ← response.documents.find? (·.mdoc.docType == photoidDocType)
  let b ← response.documents.find? (·.mdoc.docType == boardingPassDocType)
  return (p, b)

/-! ## The default presentation -/

/-- Alice Martin's photoid and boarding pass, both issued to one phone. -/
def alicePhone : List Credential :=
  [heldPhotoid "MARTIN" "ALICE" "traveler 1" "phone", heldBoardingPass "MARTIN/ALICE" "traveler 1" "phone"]

/-- What a check-in asks of the two credentials: the names and the portrait of
the photoid, and the boarding pass string. -/
def checkInElements : List ElementRef :=
  [baseRef familyNameId, baseRef givenNameId, baseRef portraitId, bcbpRef]

/-- The check-in page's OpenID4VP request for the check-in elements, with a
state value, so that it meets the guide under both readings of its sentence on
state. -/
def honestAuthorization : OpenId4Vp.AuthorizationRequest :=
  { checkInRequest checkInVerifier with
    credentials :=
      [⟨OpenId4Vp.mdocFormat, photoidDocType,
         [(baseNameSpace, familyNameId), (baseNameSpace, givenNameId), (baseNameSpace, portraitId)]⟩,
       ⟨OpenId4Vp.mdocFormat, boardingPassDocType, [(bcbpNameSpace, bcbpStringId)]⟩],
    state := some "check-in 1" }

/-- The check-in request of the mdoc profile, as the guide's step 1 describes
it. -/
def honestDeviceRequest : MdocProfile.DeviceRequest :=
  { protocol := MdocProfile.protocolValue, encryptionProtocol := MdocProfile.encryptionProtocolValue,
    nonce := some ⟨"nonce 1", 16⟩, recipientKey := some ⟨"key for nonce 1"⟩, elements := checkInElements }

/-- The first proximity session at the gate reader. -/
def gateSession : Proximity.Session := ⟨⟨"engagement 1"⟩, ⟨"reader key 1"⟩, .bluetoothLowEnergy⟩

/-- Alice Martin's honest check-in in a profile, for a request: the wallet
answers it with everything asked and approved. -/
def honestCheckIn (profile : Profile) (id title : String) (q : Request) : PresentationScenario :=
  { id, title, profile, isDefault := true, held := alicePhone, seen := some q, consent := some ⟨checkInElements⟩,
    request := some q, response := some (Wallet.respond .perElement exampleIsoTranscripts alicePhone q ⟨checkInElements⟩),
    checkedAt := beforeBoarding }

def defaultOpenId4Vp : PresentationScenario :=
  { honestCheckIn .openid4vp "default-openid4vp"
      "Alice Martin checks in online with the OpenID4VP profile and approves everything asked"
      (requestFor .openid4vp "nonce 1" checkInElements) with
    authorization := some honestAuthorization, seenOrigin := some checkInOrigin,
    trustedVerifiers := [checkInVerifier] }

def defaultMdoc : PresentationScenario :=
  { honestCheckIn .mdocOverDcApi "default-mdoc"
      "Alice Martin checks in online with the mdoc profile and approves everything asked"
      (requestFor .mdocOverDcApi "nonce 1" checkInElements) with
    deviceRequest := some honestDeviceRequest }

def defaultProximity : PresentationScenario :=
  { honestCheckIn .proximity "default-proximity"
      "Alice Martin taps a phone at the gate reader and approves everything asked"
      (gateSession.shared gateReader checkInElements) with
    sessions := [gateSession] }

/-! ## The examples -/

/-- John Smith's photoid on a phone. -/
def johnPhotoid : Credential := heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"

def checkIn : PresentationScenario :=
  let wanted := [baseRef familyNameId, baseRef givenNameId, baseRef portraitId]
  let q := requestFor .openid4vp "nonce 1" wanted
  let held := [johnPhotoid, heldBoardingPass "SMITH/JOHN" "traveler 1" "phone"]
  { id := "honest-check-in", profile := .openid4vp,
    title := "John Smith approves the names and the portrait a check-in page asks for, and nothing of the boarding pass is sent",
    held, seen := some q, consent := some ⟨wanted⟩, request := some q,
    response := some (Wallet.respond .wholeCredential exampleIsoTranscripts held q ⟨wanted⟩),
    reproduces := some ``checkInPresentation }

def partialConsentScenario : PresentationScenario :=
  let q := requestFor .openid4vp "nonce 1" [baseRef familyNameId, baseRef portraitId]
  { id := "partial-consent", profile := .openid4vp,
    title := "John Smith approves the family name and declines the portrait",
    held := [johnPhotoid], seen := some q, consent := some ⟨[baseRef familyNameId]⟩,
    reproduces := some ``partialConsent }

/-- A wallet's answer to a request for a family name and a portrait when the
holder approves the family name only, in a profile. -/
def partialResponseIn (profile : Profile) (id title : String) : PresentationScenario :=
  let q := requestFor profile "nonce 1" [baseRef familyNameId, baseRef portraitId]
  let c : Consent := ⟨[baseRef familyNameId]⟩
  { id, title, profile, held := [johnPhotoid], seen := some q, consent := some c, request := some q,
    response := some (Wallet.respond .perElement exampleIsoTranscripts [johnPhotoid] q c),
    reproduces := some ``partialResponse }

def extraElement : PresentationScenario :=
  let q := requestFor .openid4vp "nonce 1" [baseRef familyNameId]
  let sent := [baseRef familyNameId, baseRef portraitId]
  let d : Presented :=
    { mdoc := (photoidOf "SMITH" "JOHN").disclose sent, issuer := passportOffice, issuerSignatureValid := true,
      deviceKey := ⟨"phone"⟩, deviceSignature := some ⟨⟨"phone"⟩, expectedTranscript exampleIsoTranscripts q⟩ }
  { id := "extra-element", profile := .openid4vp,
    title := "A wallet that breaks the rules sends the portrait with the family name it was asked for",
    request := some q, response := some ⟨[d]⟩, reproduces := some ``extraElementAccepted }

/-- A response made for a request with one nonce and checked against a later
request from the same page with another nonce and the same key. -/
def replayIn (profile : Profile) (transcripts : String) (x : IsoTranscripts) (id title : String) (case : Name) :
    PresentationScenario :=
  let wanted := [baseRef familyNameId]
  let first := requestFor profile "nonce 1" wanted
  let second := { requestFor profile "nonce 2" wanted with encryptionKey := first.encryptionKey }
  { id, title, profile, transcripts, held := [johnPhotoid], seen := some first, consent := some ⟨wanted⟩,
    request := some second, response := some (Wallet.respond .perElement x [johnPhotoid] first ⟨wanted⟩),
    reproduces := some case }

def replayedInProximityScenario : PresentationScenario :=
  let wanted := [baseRef familyNameId]
  let later : Proximity.Session := ⟨⟨"engagement 2"⟩, ⟨"reader key 2"⟩, .bluetoothLowEnergy⟩
  let first := gateSession.shared gateReader wanted
  let second := later.shared gateReader wanted
  { id := "replay-proximity", profile := .proximity,
    title := "A response captured in one session at the gate reader is sent again in a later session",
    held := [johnPhotoid], seen := some first, consent := some ⟨wanted⟩, request := some second,
    response := some (Wallet.respond .perElement exampleIsoTranscripts [johnPhotoid] first ⟨wanted⟩),
    sessions := [gateSession, later], reproduces := some ``replayedInProximity }

def anotherOrigin : PresentationScenario :=
  let wanted := [baseRef familyNameId]
  let other : Origin := ⟨"https://checkin.example.invalid"⟩
  let q := requestFor .openid4vp "nonce 1" wanted
  let seen := { q with origin := other }
  { id := "another-origin", profile := .openid4vp,
    title := "Another site copies the check-in page's request and shows it to John Smith",
    held := [johnPhotoid], seen := some seen, consent := some ⟨wanted⟩, request := some q,
    response := some (Wallet.respond .perElement exampleIsoTranscripts [johnPhotoid] seen ⟨wanted⟩),
    authorization := some (checkInRequest checkInVerifier), seenOrigin := some other,
    trustedVerifiers := [checkInVerifier], reproduces := some ``requestFromAnotherOrigin }

/-- A boarding pass presented an hour after its validity ended, in a
profile. -/
def expiredIn (profile : Profile) (id title : String) : PresentationScenario :=
  let q := requestFor profile "nonce 1" [bcbpRef]
  let held := [heldBoardingPass "SMITH/JOHN" "traveler 1" "phone"]
  { id, title, profile, held, seen := some q, consent := some ⟨[bcbpRef]⟩, request := some q,
    response := some (Wallet.respond .perElement exampleIsoTranscripts held q ⟨[bcbpRef]⟩),
    checkedAt := afterDeparture, reproduces := some ``expiredBoardingPassAccepted }

def withoutState : PresentationScenario :=
  { id := "request-without-state", profile := .openid4vp,
    title := "The check-in page's request has every part the guide lists and no state value",
    authorization := some (checkInRequest checkInVerifier), reproduces := some ``requestWithoutState }

/-- A photoid and a boarding pass presented together for one request. -/
def devicePair (p b : Credential) (id title : String) (case : Name) : PresentationScenario :=
  let wanted := [baseRef familyNameId, baseRef portraitId, bcbpRef]
  let q := requestFor .openid4vp "nonce 1" wanted
  { id, title, profile := .openid4vp, held := [p, b], seen := some q, consent := some ⟨wanted⟩, request := some q,
    response := some (Wallet.respond .perElement exampleIsoTranscripts [p, b] q ⟨wanted⟩),
    reproduces := some case }

def wronglySigned : PresentationScenario :=
  { id := "wrongly-signed-request", profile := .openid4vp,
    title := "The check-in page's request is signed with the key of another certificate",
    authorization := some (checkInRequest ⟨"Someone else's certificate"⟩), seenOrigin := some checkInOrigin,
    trustedVerifiers := [checkInVerifier], reproduces := some ``wronglySignedRequestAnswered }

def untrustedVerifier : PresentationScenario :=
  { id := "untrusted-verifier", profile := .openid4vp,
    title := "The check-in page's certificate is not on the wallet's list of trusted verifiers",
    authorization := some (checkInRequest checkInVerifier), seenOrigin := some checkInOrigin,
    trustedVerifiers := [], reproduces := some ``untrustedVerifierAnswered }

/-- Every presentation scenario, the defaults first. -/
def presentationScenarios : List PresentationScenario :=
  [defaultOpenId4Vp, defaultMdoc, defaultProximity, checkIn, partialConsentScenario,
   partialResponseIn .openid4vp "partial-response-openid4vp"
     "John Smith's wallet sends the family name and not the portrait, in the OpenID4VP profile",
   partialResponseIn .mdocOverDcApi "partial-response-mdoc"
     "John Smith's wallet sends the family name and not the portrait, in the mdoc profile",
   extraElement,
   replayIn .openid4vp "exampleIsoTranscripts" exampleIsoTranscripts "replay-openid4vp"
     "A captured response is sent again to a later request with another nonce, in the OpenID4VP profile"
     ``replayedResponse,
   replayIn .mdocOverDcApi "exampleIsoTranscripts" exampleIsoTranscripts "replay-mdoc"
     "A captured response is sent again to a later request with another nonce, in the mdoc profile"
     ``replayedResponse,
   replayIn .mdocOverDcApi "transcriptsWithoutNonce" transcriptsWithoutNonce "nonce-outside-transcript"
     "The same replay in the mdoc profile, with a stand-in transcript that leaves out the nonce"
     ``nonceOutsideTheTranscript,
   replayedInProximityScenario, anotherOrigin,
   expiredIn .mdocOverDcApi "expired-mdoc" "An expired boarding pass is presented an hour after departure, in the mdoc profile",
   expiredIn .openid4vp "expired-openid4vp"
     "An expired boarding pass is presented an hour after departure, in the OpenID4VP profile",
   expiredIn .proximity "expired-proximity" "An expired boarding pass is presented an hour after departure, at the gate reader",
   withoutState,
   devicePair (heldPhotoid "MARTIN" "ALICE" "traveler 1" "shared phone")
     (heldBoardingPass "KELLER/BRUNO" "traveler 2" "shared phone") "two-travelers-one-device"
     "Alice Martin's photoid and Bruno Keller's boarding pass are presented from one shared phone"
     ``twoTravelersOneDevice,
   devicePair johnPhotoid (heldBoardingPass "SMITH/JOHN" "traveler 1" "tablet") "two-devices-one-traveler"
     "John Smith holds the photoid on a phone and the boarding pass on a tablet" ``twoDevicesOneTraveler,
   wronglySigned, untrustedVerifier]

/-! ## Agreement with the examples -/

/-- Every check but the validity check, the reading the expired example uses
for the profile under test. -/
def everyCheckButValidity : AcceptanceReading :=
  { strictAcceptance with validityCheckedInOpenId4Vp := false, validityCheckedInProximity := false }

/-- The part of the example a scenario reproduces that is about the scenario's
profile, recomputed from the scenario's inputs under the readings the example
uses, compared with the value the example computes.  `none` when the scenario
lacks an input the example needs. -/
def presentationExampleChecks : List (Name × (PresentationScenario → Option Bool)) :=
  let rp (s : PresentationScenario) (r : AcceptanceReading) : Option (List Refusal) := do
    return refusals r ⟨true⟩ s.iso s.trusted (← s.request) (← s.response) s.checkedAt
  [(``checkInPresentation, fun s => do
     let q ← s.request
     return checkInPresentation ==
       { requested := q.elements, approved := (← s.consent).approved, received := (← s.response).refs,
         reasonsToRefuse := ← rp s strictAcceptance }),
   (``partialConsent, fun s => do
     let seen ← s.seen
     let c ← s.consent
     return partialConsent ==
       { requested := seen.elements, approved := c.approved,
         sentIfApprovedElementsAreSent := (Wallet.respond .perElement s.iso s.held seen c).refs,
         sentIfTheWholeRequestMustBeApproved := (Wallet.respond .wholeCredential s.iso s.held seen c).refs }),
   (``partialResponse, fun s => do
     let q ← s.request
     let common := partialResponse.requested == q.elements && partialResponse.received == (← s.response).refs
     match s.profile with
     | .openid4vp =>
       let empty := Wallet.respond .wholeCredential s.iso s.held (← s.seen) (← s.consent)
       return common && partialResponse.reasonsInTheOpenId4VpProfile == (← rp s looseAcceptance) &&
         partialResponse.reasonsForAnEmptyResponseInTheOpenId4VpProfile ==
           refusals looseAcceptance ⟨true⟩ s.iso s.trusted q empty s.checkedAt
     | .mdocOverDcApi =>
       return common && partialResponse.reasonsInTheMdocProfileIfMissingDataIsRefused == (← rp s strictAcceptance) &&
         partialResponse.reasonsInTheMdocProfileIfItIsNot == (← rp s looseAcceptance)
     | .proximity => none),
   (``extraElementAccepted, fun s => do
     return extraElementAccepted ==
       { requested := (← s.request).elements, received := (← s.response).refs,
         reasonsIfExtraDataIsRefused := ← rp s strictAcceptance,
         reasonsIfExtraDataIsNotRefused := ← rp s looseAcceptance }),
   (``replayedResponse, fun s => do
     let nonces := replayedResponse.madeForNonce == (← s.seen).nonce.value &&
       replayedResponse.checkedAgainstNonce == (← s.request).nonce.value
     match s.profile with
     | .openid4vp => return nonces && replayedResponse.reasonsInTheOpenId4VpProfile == (← rp s looseAcceptance)
     | .mdocOverDcApi => return nonces && replayedResponse.reasonsInTheMdocProfile == (← rp s looseAcceptance)
     | .proximity => none),
   (``nonceOutsideTheTranscript, fun s => do
     return nonceOutsideTheTranscript.madeForNonce == (← s.seen).nonce.value &&
       nonceOutsideTheTranscript.checkedAgainstNonce == (← s.request).nonce.value &&
       nonceOutsideTheTranscript.reasonsIfItDoesNot == (← rp s strictAcceptance)),
   (``replayedInProximity, fun s => do
     return replayedInProximity ==
       { madeWithReaderKey := (← s.seen).encryptionKey.name, checkedWithReaderKey := (← s.request).encryptionKey.name,
         reasonsIfTheReaderRebuildsTheTranscript := ← rp s strictAcceptance,
         reasonsIfItDoesNot := ← rp s looseAcceptance }),
   (``requestFromAnotherOrigin, fun s => do
     let o ← s.seenOrigin
     return requestFromAnotherOrigin ==
       { expectedOrigin := (← s.request).origin.value, receivedFrom := o.value,
         reasonsTheWalletRefuses := OpenId4Vp.walletFindings ⟨false⟩ ⟨false, false⟩ s.trustedVerifiers o (← s.authorization),
         reasonsTheRelyingPartyRefuses := ← rp s looseAcceptance }),
   (``expiredBoardingPassAccepted, fun s => do
     let b ← (← s.response).documents.head?
     let times := expiredBoardingPassAccepted.validityEnds == b.mdoc.validUntil &&
       expiredBoardingPassAccepted.presentedAt == s.checkedAt
     match s.profile with
     | .mdocOverDcApi =>
       return times && expiredBoardingPassAccepted.reasonsInTheMdocProfile == (← rp s everyCheckButValidity)
     | .openid4vp =>
       return times && expiredBoardingPassAccepted.reasonsInTheOpenId4VpProfileIfValidityIsChecked ==
           (← rp s strictAcceptance) &&
         expiredBoardingPassAccepted.reasonsInTheOpenId4VpProfileIfItDoesNot == (← rp s everyCheckButValidity)
     | .proximity =>
       return times && expiredBoardingPassAccepted.reasonsInProximityIfItDoesNot == (← rp s everyCheckButValidity)),
   (``requestWithoutState, fun s => do
     let a ← s.authorization
     return requestWithoutState ==
       { brokenIfStateIsRequired := OpenId4Vp.requestFindings ⟨true⟩ a, brokenIfItIsNot := OpenId4Vp.requestFindings ⟨false⟩ a }),
   (``twoTravelersOneDevice, fun s => devicePairCheck s twoTravelersOneDevice),
   (``twoDevicesOneTraveler, fun s => devicePairCheck s twoDevicesOneTraveler),
   (``wronglySignedRequestAnswered, fun s => walletCheck s ⟨true, false⟩ ⟨false, false⟩ wronglySignedRequestAnswered),
   (``untrustedVerifierAnswered, fun s => walletCheck s ⟨true, true⟩ ⟨true, false⟩ untrustedVerifierAnswered)]
where
  /-- The record of a pair example from a scenario's inputs. -/
  devicePairCheck (s : PresentationScenario) (expected : DevicePairCheck) : Option Bool := do
    let p ← s.held.find? (·.mdoc.docType == photoidDocType)
    let b ← s.held.find? (·.mdoc.docType == boardingPassDocType)
    let q ← s.request
    let check (pr : PairReading) : Option (List PairRefusal) := do
      let (dp, db) ← pairOf (← s.response)
      return pairRefusals strictAcceptance ⟨true⟩ s.iso s.trusted pr exampleResolution792 q dp db s.checkedAt
    return expected ==
      { photoidIsAbout := p.subject.id, photoidIssuedTo := p.deviceKey.name,
        boardingPassIsAbout := b.subject.id, boardingPassIssuedTo := b.deviceKey.name,
        reasonsIfDeviceKeysMustMatch := check ⟨.notChecked, true⟩,
        reasonsIfNothingIsCompared := check ⟨.notChecked, false⟩ }
  /-- The record of a wallet example from a scenario's inputs. -/
  walletCheck (s : PresentationScenario) (checked unchecked : OpenId4Vp.WalletReading) (expected : WalletCheck) :
      Option Bool := do
    let a ← s.authorization
    let o ← s.seenOrigin
    return expected ==
      { reasonsIfTheWalletMakesTheCheck := OpenId4Vp.walletFindings ⟨false⟩ checked s.trustedVerifiers o a,
        reasonsIfItDoesNot := OpenId4Vp.walletFindings ⟨false⟩ unchecked s.trustedVerifiers o a }

/-- Nothing, or the reason a presentation scenario disagrees with the example
it reproduces or with itself. -/
def presentationAgrees (s : PresentationScenario) : Except String Unit := do
  unless isoFormats.any (·.1 == s.transcripts) do
    throw s!"scenario {s.id} names the ISO transcripts {s.transcripts}, which the oracle does not have"
  -- The request as it travels and the shared request are one request.
  if let (some a, some q) := (s.authorization, s.request) then
    unless a.shared q.origin == some q do
      throw s!"scenario {s.id}: its OpenID4VP request does not have its request as its shared form"
  if let (some d, some q) := (s.deviceRequest, s.request) then
    unless d.shared q.origin == some q do
      throw s!"scenario {s.id}: its mdoc profile request does not have its request as its shared form"
  if let some q := s.request then
    unless q.profile == s.profile do throw s!"scenario {s.id}: its request is not in its profile"
  match s.reproduces with
  | none => pure ()
  | some n =>
    match presentationExampleChecks.lookup n with
    | none => throw s!"scenario {s.id} reproduces {n}, which has no check in Exports.presentationExampleChecks"
    | some check =>
      match check s with
      | some true => pure ()
      | some false => throw s!"scenario {s.id} disagrees with the example {n}: its inputs give a different record"
      | none => throw s!"scenario {s.id} lacks an input the example {n} needs"

/-! ## As JSON -/

def optJson {α : Type} [ToJson α] : Option α → Json
  | some a => toJson a
  | none => Json.null

def PresentationScenario.json (s : PresentationScenario) : Json :=
  Json.mkObj [
    ("id", toJson s.id), ("title", toJson s.title), ("default", toJson s.isDefault), ("profile", toJson s.profile),
    ("held", toJson s.held), ("seen", optJson s.seen), ("consent", optJson s.consent),
    ("request", optJson s.request), ("response", optJson s.response), ("checkedAt", toJson s.checkedAt),
    ("trustedIssuers", toJson s.trusted), ("isoTranscripts", toJson s.transcripts),
    ("authorization", optJson s.authorization), ("seenOrigin", optJson s.seenOrigin),
    ("trustedVerifiers", toJson s.trustedVerifiers), ("deviceRequest", optJson s.deviceRequest),
    ("sessions", toJson s.sessions), ("standIns", toJson true),
    ("example", match s.reproduces with | some n => toJson n.toString | none => Json.null)]

/-- The stand-ins the presentation scenarios use. -/
def presentationStandInsJson : Json :=
  Json.mkObj [
    ("invented", toJson true),
    ("isoTranscripts", Json.arr (isoFormats.map fun (n, _) =>
      Json.mkObj [("name", toJson n), ("lean", toJson (`Rules.OneId ++ n.toName).toString)]).toArray),
    ("resolution792", Json.mkObj [("lean", toJson (``exampleResolution792).toString),
      ("format", toJson "exampleResolution792")])]

end Exports
