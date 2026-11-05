import Rules.OneId.Examples
import Rules.OneId.PresentationTheorems

/-!
# Examples of presentations

Concrete requests and responses the build checks, in the same form as the
examples of credentials.  The travelers, issuers, origins, keys and nonces
are invented.  The session transcripts of the two ISO profiles are stand-ins
for clauses this project has not read.
-/

namespace Rules.OneId

open Rules.Core

/-! ## Stand-ins, readings and parties -/

/-- A stand-in for the session transcripts the ISO documents define, invented
for the examples: the profile's name with the origin, the nonce and the key
of the request.  The real transcripts are not modelled. -/
def exampleIsoTranscripts : IsoTranscripts :=
  { annexC := fun q => .iso s!"example mdoc profile|{q.origin.value}|{q.nonce.value}|{q.encryptionKey.name}"
    proximity := fun q => .iso s!"example proximity|{q.origin.value}|{q.encryptionKey.name}" }

/-- The reading in which a relying party makes every comparison the guide
could be read to require. -/
def strictAcceptance : AcceptanceReading :=
  { extrasRefused := true, validityInIssuerDataAuthentication := true,
    mdocProfileComparesRequest := true, proximityRebuildsTranscript := true }

/-- The reading in which a relying party makes only the checks the guide
states with must in its profile. -/
def looseAcceptance : AcceptanceReading :=
  { extrasRefused := false, validityInIssuerDataAuthentication := false,
    mdocProfileComparesRequest := false, proximityRebuildsTranscript := false }

/-- An invented issuer of photoids. -/
def passportOffice : Issuer := ⟨"Utopia passport office"⟩

/-- An invented airline that issues boarding passes. -/
def airline : Issuer := ⟨"Example Air"⟩

/-- The issuers the relying party of the examples trusts. -/
def trustedIssuers : List Issuer := [passportOffice, airline]

/-- The origin of the relying party's check-in page. -/
def checkInOrigin : Origin := ⟨"https://checkin.example"⟩

/-- A request from the check-in page with a nonce and a key of its own. -/
def requestFor (profile : Profile) (nonce : String) (elements : List ElementRef) : Request :=
  { profile, origin := checkInOrigin, nonce := ⟨nonce, 16⟩, encryptionKey := ⟨"key for " ++ nonce⟩,
    engagementKey := none, elements }

/-- A data element of the base identity namespace of a photoid. -/
def baseRef (identifier : String) : ElementRef := ⟨photoidDocType, baseNameSpace, identifier⟩

/-- The boarding pass string of a boarding pass. -/
def bcbpRef : ElementRef := ⟨boardingPassDocType, bcbpNameSpace, bcbpStringId⟩

/-- A photoid issued to a device about a traveler. -/
def heldPhotoid (familyName givenName traveler device : String) : Credential :=
  { mdoc := photoidOf familyName givenName, subject := ⟨traveler⟩, issuer := passportOffice,
    deviceKey := ⟨device⟩ }

/-- A boarding pass issued to a device about a traveler. -/
def heldBoardingPass (name traveler device : String) : Credential :=
  { mdoc := boardingPassOf name, subject := ⟨traveler⟩, issuer := airline, deviceKey := ⟨device⟩ }

/-- 1 March 2027 at 09:00 UTC, an hour before the scheduled departure. -/
def beforeDeparture : Instant := ⟨1803891600⟩

/-- 1 March 2027 at 11:00 UTC, an hour after the scheduled departure. -/
def afterDeparture : Instant := ⟨1803898800⟩

/-! ## A wallet's answer -/

/-- What a wallet sent and what the relying party made of it. -/
structure PresentationCheck where
  /-- The data elements the relying party requested. -/
  requested : List ElementRef
  /-- The data elements the holder approved. -/
  approved : List ElementRef
  /-- The data elements the relying party received. -/
  received : List ElementRef
  /-- The reasons the relying party refuses the response. -/
  reasonsToRefuse : List Refusal
  deriving DecidableEq, Repr

/-- *Given* a traveler whose wallet holds a photoid and a boarding pass, and a
check-in page that requests the family name, the given name and the portrait
of the photoid in the OpenID4VP profile.

*When* the traveler approves all three and the wallet answers.

*Then* the relying party receives the three data elements, nothing of the
boarding pass, and accepts the response under the strictest reading. -/
@[case, checks "OID-201.1 OID-201.2 OID-201.4 OID-202.1 OID-202.2 OID-202.3"]
def checkInPresentation : PresentationCheck :=
  let wanted := [baseRef familyNameId, baseRef givenNameId, baseRef portraitId]
  let q := requestFor .openid4vp "nonce 1" wanted
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone", heldBoardingPass "SMITH/JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .wholeCredential exampleIsoTranscripts held q ⟨wanted⟩
  { requested := wanted, approved := wanted, received := response.refs,
    reasonsToRefuse := refusals strictAcceptance ⟨true⟩ exampleIsoTranscripts trustedIssuers q response
      beforeDeparture }

#guard checkInPresentation.received == checkInPresentation.requested &&
  checkInPresentation.reasonsToRefuse == []

/-- What a wallet sends when the holder approves a part of a request. -/
structure PartialConsentCheck where
  /-- The data elements the relying party requested. -/
  requested : List ElementRef
  /-- The data elements the holder approved. -/
  approved : List ElementRef
  /-- What the wallet sends if it sends the data elements the holder
  approved. -/
  sentIfApprovedElementsAreSent : List ElementRef
  /-- What the wallet sends if it sends a credential only when every data
  element requested from it is approved. -/
  sentIfTheWholeRequestMustBeApproved : List ElementRef
  deriving DecidableEq, Repr

/-- *Given* a check-in page that requests the family name and the portrait of
a photoid.

*When* the traveler approves the family name and declines the portrait.

*Then* under one reading the wallet sends the family name, and under the
other it sends nothing. -/
@[case, checks "OID-201.5"]
def partialConsent : PartialConsentCheck :=
  let wanted := [baseRef familyNameId, baseRef portraitId]
  let approved := [baseRef familyNameId]
  let q := requestFor .openid4vp "nonce 1" wanted
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"]
  { requested := wanted, approved,
    sentIfApprovedElementsAreSent :=
      (Wallet.respond .perElement exampleIsoTranscripts held q ⟨approved⟩).refs,
    sentIfTheWholeRequestMustBeApproved :=
      (Wallet.respond .wholeCredential exampleIsoTranscripts held q ⟨approved⟩).refs }

#guard partialConsent.sentIfApprovedElementsAreSent == [baseRef familyNameId] &&
  partialConsent.sentIfTheWholeRequestMustBeApproved == []

/-! ## A relying party's decision -/

/-- A response checked under two readings of what a relying party refuses. -/
structure ExtraDataCheck where
  /-- The data elements the relying party requested. -/
  requested : List ElementRef
  /-- The data elements the response holds. -/
  received : List ElementRef
  /-- The reasons to refuse it, if a relying party refuses extra data. -/
  reasonsIfExtraDataIsRefused : List Refusal
  /-- The reasons to refuse it, if a relying party does not. -/
  reasonsIfExtraDataIsNotRefused : List Refusal
  deriving DecidableEq, Repr

/-- *Given* a check-in page that requests only the family name of a photoid in
the OpenID4VP profile, and a wallet that does not follow the rules and also
sends the portrait, with valid signatures made for this request.

*When* the relying party checks the response.

*Then* under one reading it refuses the response for the portrait it did not
request, and under the other it accepts the response and holds a face image
it never asked for. -/
@[case, checks "OID-202.6"]
def extraElementAccepted : ExtraDataCheck :=
  let q := requestFor .openid4vp "nonce 1" [baseRef familyNameId]
  let sent := [baseRef familyNameId, baseRef portraitId]
  let d : Presented :=
    { mdoc := (photoidOf "SMITH" "JOHN").disclose sent, issuer := passportOffice, issuerSignatureValid := true,
      deviceKey := ⟨"phone"⟩, deviceSignature := some ⟨⟨"phone"⟩, expectedTranscript exampleIsoTranscripts q⟩ }
  let check (r : AcceptanceReading) :=
    refusals r ⟨true⟩ exampleIsoTranscripts trustedIssuers q ⟨[d]⟩ beforeDeparture
  { requested := q.elements, received := d.mdoc.refs,
    reasonsIfExtraDataIsRefused := check strictAcceptance,
    reasonsIfExtraDataIsNotRefused := check looseAcceptance }

#guard extraElementAccepted.reasonsIfExtraDataIsRefused == [.notRequested (baseRef portraitId)] &&
  extraElementAccepted.reasonsIfExtraDataIsNotRefused == []

/-- One response checked against a later request, profile by profile. -/
structure ReplayCheck where
  /-- The nonce of the request the response was made for. -/
  madeForNonce : String
  /-- The nonce of the request it is checked against. -/
  checkedAgainstNonce : String
  /-- The reasons to refuse it in the OpenID4VP profile. -/
  reasonsInTheOpenId4VpProfile : List Refusal
  /-- The reasons to refuse it in the mdoc profile, if the relying party
  compares the session transcript. -/
  reasonsInTheMdocProfileIfTheTranscriptIsCompared : List Refusal
  /-- The reasons to refuse it in the mdoc profile, if it does not. -/
  reasonsInTheMdocProfileIfItIsNot : List Refusal
  deriving DecidableEq, Repr

/-- A wallet's answer to one request, checked against a second request that
differs in its nonce and key, in a profile. -/
def replay (profile : Profile) (r : AcceptanceReading) : List Refusal :=
  let wanted := [baseRef familyNameId]
  let first := requestFor profile "nonce 1" wanted
  let second := requestFor profile "nonce 2" wanted
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .perElement exampleIsoTranscripts held first ⟨wanted⟩
  refusals r ⟨true⟩ exampleIsoTranscripts trustedIssuers second response beforeDeparture

/-- *Given* a response a wallet made for a request with one nonce, captured
and sent again in answer to a later request with another nonce.

*When* the relying party checks it against the later request.

*Then* the OpenID4VP profile refuses it under every reading.  The mdoc profile
refuses it if the relying party compares the session transcript, which the
guide's list of checks for that profile does not say, and accepts it if not.
The transcript of the mdoc profile here is an invented stand-in. -/
@[case, checks "OID-202.4 OID-205.1"]
def replayedResponse : ReplayCheck :=
  { madeForNonce := "nonce 1", checkedAgainstNonce := "nonce 2",
    reasonsInTheOpenId4VpProfile := replay .openid4vp looseAcceptance,
    reasonsInTheMdocProfileIfTheTranscriptIsCompared := replay .mdocOverDcApi strictAcceptance,
    reasonsInTheMdocProfileIfItIsNot := replay .mdocOverDcApi looseAcceptance }

#guard replayedResponse.reasonsInTheOpenId4VpProfile == [.otherRequest photoidDocType] &&
  replayedResponse.reasonsInTheMdocProfileIfTheTranscriptIsCompared == [.otherRequest photoidDocType] &&
  replayedResponse.reasonsInTheMdocProfileIfItIsNot == []

/-- A request relayed through another site. -/
structure RelayCheck where
  /-- The origin the request names. -/
  expectedOrigin : String
  /-- The origin the wallet received it from. -/
  receivedFrom : String
  /-- The reasons the wallet does not answer. -/
  reasonsTheWalletRefuses : List OpenId4Vp.WalletFinding
  /-- The reasons the relying party refuses the response, if a wallet answers
  all the same. -/
  reasonsTheRelyingPartyRefuses : List Refusal
  deriving DecidableEq, Repr

/-- *Given* a signed OpenID4VP request from the check-in page, copied by
another site that shows it to a traveler.

*When* the traveler's wallet receives the request from the other site's
origin.

*Then* the wallet refuses, because that origin is not one the request names.
A wallet that answered would sign over the other site's origin, and the
relying party would refuse the response as made for another request. -/
@[case, checks "OID-204.1 OID-205.2"]
def requestFromAnotherOrigin : RelayCheck :=
  let wanted := [baseRef familyNameId]
  let other : Origin := ⟨"https://checkin.example.invalid"⟩
  let verifier : OpenId4Vp.Certificate := ⟨"Example Air check-in"⟩
  let a : OpenId4Vp.AuthorizationRequest :=
    { protocol := OpenId4Vp.protocolValue, responseType := OpenId4Vp.responseTypeValue,
      responseMode := OpenId4Vp.responseModeValue, clientIdPrefix := OpenId4Vp.clientIdPrefixValue,
      clientCertificate := verifier, signedWith := some verifier, expectedOrigins := [checkInOrigin],
      encryptionKey := some ⟨"key for nonce 1"⟩,
      credentials := [⟨OpenId4Vp.mdocFormat, photoidDocType, [(baseNameSpace, familyNameId)]⟩],
      nonce := some ⟨"nonce 1", 16⟩, state := none }
  let q := requestFor .openid4vp "nonce 1" wanted
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .perElement exampleIsoTranscripts held { q with origin := other } ⟨wanted⟩
  { expectedOrigin := checkInOrigin.value, receivedFrom := other.value,
    reasonsTheWalletRefuses := OpenId4Vp.walletFindings ⟨false⟩ [verifier] other a,
    reasonsTheRelyingPartyRefuses :=
      refusals looseAcceptance ⟨true⟩ exampleIsoTranscripts trustedIssuers q response beforeDeparture }

#guard requestFromAnotherOrigin.reasonsTheWalletRefuses ==
    [.originNotExpected ⟨"https://checkin.example.invalid"⟩] &&
  requestFromAnotherOrigin.reasonsTheRelyingPartyRefuses == [.otherRequest photoidDocType]

/-- An expired credential checked profile by profile. -/
structure ExpiredCheck where
  /-- The end of the credential's validity. -/
  validityEnds : Instant
  /-- The instant it is presented. -/
  presentedAt : Instant
  /-- The reasons to refuse it in the mdoc profile. -/
  reasonsInTheMdocProfile : List Refusal
  /-- The reasons to refuse it in the OpenID4VP profile, if the clause that
  profile cites includes the validity check. -/
  reasonsInTheOpenId4VpProfileIfTheClauseChecksValidity : List Refusal
  /-- The reasons to refuse it in the OpenID4VP profile, if it does not. -/
  reasonsInTheOpenId4VpProfileIfItDoesNot : List Refusal
  /-- The reasons to refuse it in proximity, if it does not. -/
  reasonsInProximityIfItDoesNot : List Refusal
  deriving DecidableEq, Repr

/-- A wallet's presentation of a boarding pass an hour after its validity
ended, in a profile. -/
def presentExpired (profile : Profile) (r : AcceptanceReading) : List Refusal :=
  let q := requestFor profile "nonce 1" [bcbpRef]
  let held := [heldBoardingPass "SMITH/JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .perElement exampleIsoTranscripts held q ⟨[bcbpRef]⟩
  refusals r ⟨true⟩ exampleIsoTranscripts trustedIssuers q response afterDeparture

/-- *Given* a boarding pass whose validity ended at 10:00 UTC on 1 March 2027.

*When* its holder presents it at 11:00, with valid signatures, in each of the
three profiles.

*Then* the mdoc profile refuses it.  The OpenID4VP profile and proximity
refuse it if the clause they cite for issuer data authentication includes the
validity check, and accept it if not. -/
@[case, checks "OID-202.5"]
def expiredBoardingPassAccepted : ExpiredCheck :=
  let onlyValidity := { strictAcceptance with validityInIssuerDataAuthentication := false }
  { validityEnds := departure, presentedAt := afterDeparture,
    reasonsInTheMdocProfile := presentExpired .mdocOverDcApi onlyValidity,
    reasonsInTheOpenId4VpProfileIfTheClauseChecksValidity := presentExpired .openid4vp strictAcceptance,
    reasonsInTheOpenId4VpProfileIfItDoesNot := presentExpired .openid4vp onlyValidity,
    reasonsInProximityIfItDoesNot := presentExpired .proximity onlyValidity }

#guard expiredBoardingPassAccepted.reasonsInTheMdocProfile == [.expired boardingPassDocType] &&
  expiredBoardingPassAccepted.reasonsInTheOpenId4VpProfileIfTheClauseChecksValidity ==
    [.expired boardingPassDocType] &&
  expiredBoardingPassAccepted.reasonsInTheOpenId4VpProfileIfItDoesNot == [] &&
  expiredBoardingPassAccepted.reasonsInProximityIfItDoesNot == []

/-! ## The OpenID4VP request -/

/-- A request checked under two readings of the guide's sentence on state. -/
structure StateCheck where
  /-- The requirements broken if the guide's must for state is meant. -/
  brokenIfStateIsRequired : List OpenId4Vp.RequestFinding
  /-- The requirements broken if the request follows OpenID4VP, which does
  not define state over the Digital Credentials API. -/
  brokenIfItIsNot : List OpenId4Vp.RequestFinding
  deriving DecidableEq, Repr

/-- *Given* a signed OpenID4VP request with every part the guide's step 2
lists and no state value, as in the guide's own example request.

*When* it is checked under each reading of the guide's sentence that the
nonce and state must be set.

*Then* one reading rejects it for the missing state and the other accepts
it. -/
@[case, checks "OID-203.6"]
def requestWithoutState : StateCheck :=
  let verifier : OpenId4Vp.Certificate := ⟨"Example Air check-in"⟩
  let a : OpenId4Vp.AuthorizationRequest :=
    { protocol := OpenId4Vp.protocolValue, responseType := OpenId4Vp.responseTypeValue,
      responseMode := OpenId4Vp.responseModeValue, clientIdPrefix := OpenId4Vp.clientIdPrefixValue,
      clientCertificate := verifier, signedWith := some verifier, expectedOrigins := [checkInOrigin],
      encryptionKey := some ⟨"key for nonce 1"⟩,
      credentials := [⟨OpenId4Vp.mdocFormat, photoidDocType, [(baseNameSpace, familyNameId)]⟩],
      nonce := some ⟨"nonce 1", 16⟩, state := none }
  { brokenIfStateIsRequired := OpenId4Vp.requestFindings ⟨true⟩ a,
    brokenIfItIsNot := OpenId4Vp.requestFindings ⟨false⟩ a }

#guard requestWithoutState.brokenIfStateIsRequired == [.noState] &&
  requestWithoutState.brokenIfItIsNot == []

/-! ## A photoid and a boarding pass presented together -/

/-- A photoid and a boarding pass presented together, checked with the device
keys compared. -/
structure DevicePairCheck where
  /-- The traveler the photoid is about. -/
  photoidIsAbout : String
  /-- The device the photoid was issued to. -/
  photoidIssuedTo : String
  /-- The traveler the boarding pass is about. -/
  boardingPassIsAbout : String
  /-- The device the boarding pass was issued to. -/
  boardingPassIssuedTo : String
  /-- The reasons to refuse the pair, if the device keys must be the same. -/
  reasonsIfDeviceKeysMustMatch : List PairRefusal
  /-- The reasons to refuse the pair, if nothing is compared. -/
  reasonsIfNothingIsCompared : List PairRefusal
  deriving DecidableEq, Repr

/-- A photoid and a boarding pass presented together by wallets that follow
the rules, for one request. -/
def checkDevicePair (p b : Credential) : DevicePairCheck :=
  let wanted := [baseRef familyNameId, baseRef portraitId, bcbpRef]
  let q := requestFor .openid4vp "nonce 1" wanted
  let t := expectedTranscript exampleIsoTranscripts q
  let check (pr : PairReading) : List PairRefusal :=
    match Credential.present .perElement q ⟨wanted⟩ t p, Credential.present .perElement q ⟨wanted⟩ t b with
    | some dp, some db =>
      pairRefusals strictAcceptance ⟨true⟩ exampleIsoTranscripts trustedIssuers pr exampleResolution792 q
        dp db beforeDeparture
    | _, _ => []
  { photoidIsAbout := p.subject.id, photoidIssuedTo := p.deviceKey.name,
    boardingPassIsAbout := b.subject.id, boardingPassIssuedTo := b.deviceKey.name,
    reasonsIfDeviceKeysMustMatch := check ⟨.notChecked, true⟩,
    reasonsIfNothingIsCompared := check ⟨.notChecked, false⟩ }

/-- *Given* two travelers whose credentials were issued to one device: Alice
Martin's photoid and Bruno Keller's boarding pass in the wallet of a shared
phone.

*When* the phone presents both together, under the reading that the two
credentials must carry the same device key.

*Then* the pair is accepted: Alice's face goes with Bruno's boarding pass. -/
@[case, checks "OID-207.1"]
def twoTravelersOneDevice : DevicePairCheck :=
  checkDevicePair (heldPhotoid "MARTIN" "ALICE" "traveler 1" "shared phone")
    (heldBoardingPass "KELLER/BRUNO" "traveler 2" "shared phone")

#guard twoTravelersOneDevice.reasonsIfDeviceKeysMustMatch == []

/-- *Given* one traveler who holds a photoid on a phone and a boarding pass on
a tablet, each accepted on its own.

*When* the two are presented together, under the reading that the two
credentials must carry the same device key.

*Then* the pair is refused, though both credentials are about the same
person.  With nothing compared it is accepted. -/
@[case, checks "OID-207.3"]
def twoDevicesOneTraveler : DevicePairCheck :=
  checkDevicePair (heldPhotoid "SMITH" "JOHN" "traveler 1" "phone")
    (heldBoardingPass "SMITH/JOHN" "traveler 1" "tablet")

#guard twoDevicesOneTraveler.reasonsIfDeviceKeysMustMatch == [.notOneTraveler] &&
  twoDevicesOneTraveler.reasonsIfNothingIsCompared == []

end Rules.OneId
