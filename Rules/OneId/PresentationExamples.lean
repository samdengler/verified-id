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

/-- Another invented stand-in for the session transcript of the mdoc profile,
one that leaves out the nonce.  Whether the real one includes it is in a
clause this project has not read. -/
def transcriptsWithoutNonce : IsoTranscripts :=
  { annexC := fun q => .iso s!"example mdoc profile without a nonce|{q.origin.value}|{q.encryptionKey.name}"
    proximity := exampleIsoTranscripts.proximity }

/-- The reading in which a relying party makes every comparison the guide
could be read to require. -/
def strictAcceptance : AcceptanceReading :=
  { extrasRefusedInMdocProfile := true, extrasRefusedInOpenId4Vp := true, extrasRefusedInProximity := true,
    missingRefusedInMdocProfile := true, missingRefusedInProximity := true,
    validityCheckedInOpenId4Vp := true, validityCheckedInProximity := true,
    proximityRebuildsTranscript := true }

/-- The reading in which a relying party makes only the checks the guide
settles for its profile. -/
def looseAcceptance : AcceptanceReading :=
  { extrasRefusedInMdocProfile := false, extrasRefusedInOpenId4Vp := false, extrasRefusedInProximity := false,
    missingRefusedInMdocProfile := false, missingRefusedInProximity := false,
    validityCheckedInOpenId4Vp := false, validityCheckedInProximity := false,
    proximityRebuildsTranscript := false }

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

/-- The certificate of the check-in page's relying party. -/
def checkInVerifier : OpenId4Vp.Certificate := ⟨"Example Air check-in"⟩

/-- A request from the check-in page in the OpenID4VP profile for the family
name of a photoid, with every part the guide's step 2 lists and no state
value, as in the guide's own example, signed with the key of a certificate. -/
def checkInRequest (signedWith : OpenId4Vp.Certificate) : OpenId4Vp.AuthorizationRequest :=
  { protocol := OpenId4Vp.protocolValue, responseType := OpenId4Vp.responseTypeValue,
    responseMode := OpenId4Vp.responseModeValue, clientIdPrefix := OpenId4Vp.clientIdPrefixValue,
    clientCertificate := checkInVerifier, signedWith := some signedWith, expectedOrigins := [checkInOrigin],
    encryptionKey := some ⟨"key for nonce 1"⟩,
    credentials := [⟨OpenId4Vp.mdocFormat, photoidDocType, [(baseNameSpace, familyNameId)]⟩],
    nonce := some ⟨"nonce 1", 16⟩, state := none }

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

/-- A response that lacks something requested, checked profile by profile. -/
structure MissingDataCheck where
  /-- The data elements the relying party requested. -/
  requested : List ElementRef
  /-- The data elements the wallet sent. -/
  received : List ElementRef
  /-- The reasons to refuse it in the OpenID4VP profile. -/
  reasonsInTheOpenId4VpProfile : List Refusal
  /-- The reasons to refuse it in the mdoc profile, if a relying party there
  refuses a response that lacks something. -/
  reasonsInTheMdocProfileIfMissingDataIsRefused : List Refusal
  /-- The reasons to refuse it in the mdoc profile, if it does not. -/
  reasonsInTheMdocProfileIfItIsNot : List Refusal
  /-- The reasons to refuse an empty response in the OpenID4VP profile, from a
  wallet that sends nothing of a credential the holder approved in part. -/
  reasonsForAnEmptyResponseInTheOpenId4VpProfile : List Refusal
  deriving DecidableEq, Repr

/-- The relying party's reasons to refuse the answer of a wallet to a request
for a family name and a portrait, when the traveler approves the family name
only, in a profile. -/
def answerToPartialApproval (profile : Profile) (r : AcceptanceReading) (c : ConsentReading) :
    Response × List Refusal :=
  let q := requestFor profile "nonce 1" [baseRef familyNameId, baseRef portraitId]
  let response := Wallet.respond c exampleIsoTranscripts [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"] q
    ⟨[baseRef familyNameId]⟩
  (response, refusals r ⟨true⟩ exampleIsoTranscripts trustedIssuers q response beforeDeparture)

/-- *Given* a check-in page that requests the family name and the portrait of
a photoid, and a traveler who approves the family name and declines the
portrait.

*When* the wallet sends the data element the traveler approved, and the
relying party checks the response.

*Then* the OpenID4VP profile refuses it for the missing portrait.  The mdoc
profile refuses it if a relying party there refuses a response that lacks
something, and accepts it if not.  A wallet that sends nothing at all is
refused in the OpenID4VP profile for both data elements. -/
@[case, checks "OID-202.7"]
def partialResponse : MissingDataCheck :=
  { requested := [baseRef familyNameId, baseRef portraitId],
    received := (answerToPartialApproval .openid4vp looseAcceptance .perElement).1.refs,
    reasonsInTheOpenId4VpProfile := (answerToPartialApproval .openid4vp looseAcceptance .perElement).2,
    reasonsInTheMdocProfileIfMissingDataIsRefused :=
      (answerToPartialApproval .mdocOverDcApi strictAcceptance .perElement).2,
    reasonsInTheMdocProfileIfItIsNot := (answerToPartialApproval .mdocOverDcApi looseAcceptance .perElement).2,
    reasonsForAnEmptyResponseInTheOpenId4VpProfile :=
      (answerToPartialApproval .openid4vp looseAcceptance .wholeCredential).2 }

#guard partialResponse.received == [baseRef familyNameId] &&
  partialResponse.reasonsInTheOpenId4VpProfile == [.missing (baseRef portraitId)] &&
  partialResponse.reasonsInTheMdocProfileIfMissingDataIsRefused == [.missing (baseRef portraitId)] &&
  partialResponse.reasonsInTheMdocProfileIfItIsNot == [] &&
  partialResponse.reasonsForAnEmptyResponseInTheOpenId4VpProfile ==
    [.missing (baseRef familyNameId), .missing (baseRef portraitId)]

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

/-- One response checked against a later request, in the two remote
profiles. -/
structure ReplayCheck where
  /-- The nonce of the request the response was made for. -/
  madeForNonce : String
  /-- The nonce of the request it is checked against. -/
  checkedAgainstNonce : String
  /-- The reasons to refuse it in the OpenID4VP profile. -/
  reasonsInTheOpenId4VpProfile : List Refusal
  /-- The reasons to refuse it in the mdoc profile, with the invented stand-in
  transcript that holds the nonce. -/
  reasonsInTheMdocProfile : List Refusal
  deriving DecidableEq, Repr

/-- A wallet's answer to one request, checked against a second request from
the same page that differs only in its nonce, in a profile, with stand-ins for
the ISO transcripts. -/
def replay (profile : Profile) (r : AcceptanceReading) (x : IsoTranscripts) : List Refusal :=
  let wanted := [baseRef familyNameId]
  let first := requestFor profile "nonce 1" wanted
  let second := { requestFor profile "nonce 2" wanted with encryptionKey := first.encryptionKey }
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .perElement x held first ⟨wanted⟩
  refusals r ⟨true⟩ x trustedIssuers second response beforeDeparture

/-- *Given* a response a wallet made for a request with one nonce, captured
and sent again in answer to a later request from the same page with another
nonce and the same encryption key.

*When* the relying party checks it against the later request.

*Then* the OpenID4VP profile refuses it, and so does the mdoc profile, under
every reading, since both compare the session transcript.  For the mdoc
profile this rests on the transcript holding the nonce, which the invented
stand-in here does and the real one may not
({lit}`nonceOutsideTheTranscript`).  Decryption is not modelled; with the same
key it would not tell the two requests apart. -/
@[case, checks "OID-205.1"]
def replayedResponse : ReplayCheck :=
  { madeForNonce := "nonce 1", checkedAgainstNonce := "nonce 2",
    reasonsInTheOpenId4VpProfile := replay .openid4vp looseAcceptance exampleIsoTranscripts,
    reasonsInTheMdocProfile := replay .mdocOverDcApi looseAcceptance exampleIsoTranscripts }

#guard replayedResponse.reasonsInTheOpenId4VpProfile == [.otherRequest photoidDocType] &&
  replayedResponse.reasonsInTheMdocProfile == [.otherRequest photoidDocType]

/-- One response of the mdoc profile checked against a later request, with two
stand-ins for the session transcript. -/
structure NonceCheck where
  /-- The nonce of the request the response was made for. -/
  madeForNonce : String
  /-- The nonce of the request it is checked against. -/
  checkedAgainstNonce : String
  /-- The reasons to refuse it, if the session transcript holds the nonce. -/
  reasonsIfTheTranscriptHoldsTheNonce : List Refusal
  /-- The reasons to refuse it, if it does not. -/
  reasonsIfItDoesNot : List Refusal
  deriving DecidableEq, Repr

/-- *Given* a response a wallet made in the mdoc profile for a request with one
nonce, captured and sent again in answer to a later request from the same
page with another nonce and the same encryption key.

*When* the relying party checks it against the later request, comparing the
session transcript as the profile requires.

*Then* it is refused if the session transcript holds the nonce, and accepted
if it does not.  Both transcripts are invented stand-ins for ISO/IEC TS
18013-7 Annex C, which this project has not read. -/
@[case]
def nonceOutsideTheTranscript : NonceCheck :=
  { madeForNonce := "nonce 1", checkedAgainstNonce := "nonce 2",
    reasonsIfTheTranscriptHoldsTheNonce := replay .mdocOverDcApi strictAcceptance exampleIsoTranscripts,
    reasonsIfItDoesNot := replay .mdocOverDcApi strictAcceptance transcriptsWithoutNonce }

#guard nonceOutsideTheTranscript.reasonsIfTheTranscriptHoldsTheNonce == [.otherRequest photoidDocType] &&
  nonceOutsideTheTranscript.reasonsIfItDoesNot == []

/-- One response of a proximity session checked in a later session. -/
structure ProximityReplayCheck where
  /-- The reader's key in the session the response was made in. -/
  madeWithReaderKey : String
  /-- The reader's key in the session it is checked in. -/
  checkedWithReaderKey : String
  /-- The reasons to refuse it, if the reader rebuilds the session
  transcript. -/
  reasonsIfTheReaderRebuildsTheTranscript : List Refusal
  /-- The reasons to refuse it, if it does not. -/
  reasonsIfItDoesNot : List Refusal
  deriving DecidableEq, Repr

/-- A gate reader, as the origin of a proximity request. -/
def gateReader : Origin := ⟨"gate B12 reader"⟩

/-- A wallet's answer in one proximity session, checked in a later session with
a new reader key. -/
def replayInProximity (r : AcceptanceReading) : List Refusal :=
  let wanted := [baseRef familyNameId]
  let first := Proximity.Session.shared ⟨⟨"engagement 1"⟩, ⟨"reader key 1"⟩, .bluetoothLowEnergy⟩ gateReader wanted
  let second := Proximity.Session.shared ⟨⟨"engagement 2"⟩, ⟨"reader key 2"⟩, .bluetoothLowEnergy⟩ gateReader wanted
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .perElement exampleIsoTranscripts held first ⟨wanted⟩
  refusals r ⟨true⟩ exampleIsoTranscripts trustedIssuers second response beforeDeparture

/-- *Given* a response a wallet made in one proximity session at a gate reader,
captured and sent again in a later session with a new reader key.

*When* the reader checks it in the later session.

*Then* it is refused if the reader rebuilds the session transcript, and
accepted if not.  The transcript here is an invented stand-in.  Decrypting
with the session keys, which the guide marks should, is not modelled. -/
@[case, checks "OID-202.4"]
def replayedInProximity : ProximityReplayCheck :=
  { madeWithReaderKey := "reader key 1", checkedWithReaderKey := "reader key 2",
    reasonsIfTheReaderRebuildsTheTranscript := replayInProximity strictAcceptance,
    reasonsIfItDoesNot := replayInProximity looseAcceptance }

#guard replayedInProximity.reasonsIfTheReaderRebuildsTheTranscript == [.otherRequest photoidDocType] &&
  replayedInProximity.reasonsIfItDoesNot == []

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

*Then* the wallet refuses, under every reading, because that origin is not
one the request names.
A wallet that answered would sign over the other site's origin, and the
relying party would refuse the response as made for another request. -/
@[case, checks "OID-204.1 OID-205.2"]
def requestFromAnotherOrigin : RelayCheck :=
  let wanted := [baseRef familyNameId]
  let other : Origin := ⟨"https://checkin.example.invalid"⟩
  let q := requestFor .openid4vp "nonce 1" wanted
  let held := [heldPhotoid "SMITH" "JOHN" "traveler 1" "phone"]
  let response := Wallet.respond .perElement exampleIsoTranscripts held { q with origin := other } ⟨wanted⟩
  { expectedOrigin := checkInOrigin.value, receivedFrom := other.value,
    reasonsTheWalletRefuses :=
      OpenId4Vp.walletFindings ⟨false⟩ ⟨false, false⟩ [checkInVerifier] other (checkInRequest checkInVerifier),
    reasonsTheRelyingPartyRefuses :=
      refusals looseAcceptance ⟨true⟩ exampleIsoTranscripts trustedIssuers q response beforeDeparture }

#guard requestFromAnotherOrigin.reasonsTheWalletRefuses ==
    [.originNotExpected ⟨"https://checkin.example.invalid"⟩] &&
  requestFromAnotherOrigin.reasonsTheRelyingPartyRefuses == [.otherRequest photoidDocType]

/-- An OpenID4VP request checked by a wallet under two readings of one of its
checks. -/
structure WalletCheck where
  /-- The reasons the wallet refuses, if it makes the check. -/
  reasonsIfTheWalletMakesTheCheck : List OpenId4Vp.WalletFinding
  /-- The reasons the wallet refuses, if it does not. -/
  reasonsIfItDoesNot : List OpenId4Vp.WalletFinding
  deriving DecidableEq, Repr

/-- *Given* a request from the check-in page, received from an origin it
names, whose client identifier names the airline's certificate and which is
signed with the key of another certificate.

*When* a wallet receives it.

*Then* a wallet that validates the signature refuses it, and a wallet that
does not answers it. -/
@[case, checks "OID-204.2"]
def wronglySignedRequestAnswered : WalletCheck :=
  let a := checkInRequest ⟨"Someone else's certificate"⟩
  { reasonsIfTheWalletMakesTheCheck := OpenId4Vp.walletFindings ⟨false⟩ ⟨true, false⟩ [checkInVerifier] checkInOrigin a,
    reasonsIfItDoesNot := OpenId4Vp.walletFindings ⟨false⟩ ⟨false, false⟩ [checkInVerifier] checkInOrigin a }

#guard wronglySignedRequestAnswered.reasonsIfTheWalletMakesTheCheck == [.badSignature] &&
  wronglySignedRequestAnswered.reasonsIfItDoesNot == []

/-- *Given* a well formed request from the check-in page, received from an
origin it names and signed with the key of the certificate its client
identifier names, and a wallet whose list of trusted verifiers does not hold
that certificate.

*When* the wallet receives it.

*Then* a wallet that checks its list refuses the request, and a wallet that
does not answers it. -/
@[case, checks "OID-204.3"]
def untrustedVerifierAnswered : WalletCheck :=
  let a := checkInRequest checkInVerifier
  { reasonsIfTheWalletMakesTheCheck := OpenId4Vp.walletFindings ⟨false⟩ ⟨true, true⟩ [] checkInOrigin a,
    reasonsIfItDoesNot := OpenId4Vp.walletFindings ⟨false⟩ ⟨true, false⟩ [] checkInOrigin a }

#guard untrustedVerifierAnswered.reasonsIfTheWalletMakesTheCheck == [.untrustedVerifier checkInVerifier] &&
  untrustedVerifierAnswered.reasonsIfItDoesNot == []

/-- An expired credential checked profile by profile. -/
structure ExpiredCheck where
  /-- The end of the credential's validity. -/
  validityEnds : Instant
  /-- The instant it is presented. -/
  presentedAt : Instant
  /-- The reasons to refuse it in the mdoc profile. -/
  reasonsInTheMdocProfile : List Refusal
  /-- The reasons to refuse it in the OpenID4VP profile, if a relying party
  there checks validity. -/
  reasonsInTheOpenId4VpProfileIfValidityIsChecked : List Refusal
  /-- The reasons to refuse it in the OpenID4VP profile, if it does not. -/
  reasonsInTheOpenId4VpProfileIfItDoesNot : List Refusal
  /-- The reasons to refuse it in proximity, if a reader there does not
  check validity. -/
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
refuse it if a relying party there checks validity, and accept it if not. -/
@[case, checks "OID-202.5"]
def expiredBoardingPassAccepted : ExpiredCheck :=
  let everyCheckButValidity :=
    { strictAcceptance with validityCheckedInOpenId4Vp := false, validityCheckedInProximity := false }
  { validityEnds := departure, presentedAt := afterDeparture,
    reasonsInTheMdocProfile := presentExpired .mdocOverDcApi everyCheckButValidity,
    reasonsInTheOpenId4VpProfileIfValidityIsChecked := presentExpired .openid4vp strictAcceptance,
    reasonsInTheOpenId4VpProfileIfItDoesNot := presentExpired .openid4vp everyCheckButValidity,
    reasonsInProximityIfItDoesNot := presentExpired .proximity everyCheckButValidity }

#guard expiredBoardingPassAccepted.reasonsInTheMdocProfile == [.expired boardingPassDocType] &&
  expiredBoardingPassAccepted.reasonsInTheOpenId4VpProfileIfValidityIsChecked ==
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
  let a := checkInRequest checkInVerifier
  { brokenIfStateIsRequired := OpenId4Vp.requestFindings ⟨true⟩ a,
    brokenIfItIsNot := OpenId4Vp.requestFindings ⟨false⟩ a }

#guard requestWithoutState.brokenIfStateIsRequired == [.noState] &&
  requestWithoutState.brokenIfItIsNot == []

/-! ## A photoid and a boarding pass presented together -/

/-- A photoid and a boarding pass presented together, checked with the device
keys compared and with nothing compared.  The names are not compared in
either. -/
structure DevicePairCheck where
  /-- The traveler the photoid is about. -/
  photoidIsAbout : String
  /-- The device the photoid was issued to. -/
  photoidIssuedTo : String
  /-- The traveler the boarding pass is about. -/
  boardingPassIsAbout : String
  /-- The device the boarding pass was issued to. -/
  boardingPassIssuedTo : String
  /-- The reasons to refuse the pair, if the device keys must be the same;
  none if the wallet did not present both credentials. -/
  reasonsIfDeviceKeysMustMatch : Option (List PairRefusal)
  /-- The reasons to refuse the pair, if nothing is compared; none if the
  wallet did not present both credentials. -/
  reasonsIfNothingIsCompared : Option (List PairRefusal)
  deriving DecidableEq, Repr

/-- A photoid and a boarding pass presented together by wallets that follow
the rules, for one request. -/
def checkDevicePair (p b : Credential) : DevicePairCheck :=
  let wanted := [baseRef familyNameId, baseRef portraitId, bcbpRef]
  let q := requestFor .openid4vp "nonce 1" wanted
  let t := expectedTranscript exampleIsoTranscripts q
  let check (pr : PairReading) : Option (List PairRefusal) :=
    match Credential.present .perElement q ⟨wanted⟩ t p, Credential.present .perElement q ⟨wanted⟩ t b with
    | some dp, some db =>
      some (pairRefusals strictAcceptance ⟨true⟩ exampleIsoTranscripts trustedIssuers pr exampleResolution792 q
        dp db beforeDeparture)
    | _, _ => none
  { photoidIsAbout := p.subject.id, photoidIssuedTo := p.deviceKey.name,
    boardingPassIsAbout := b.subject.id, boardingPassIssuedTo := b.deviceKey.name,
    reasonsIfDeviceKeysMustMatch := check ⟨.notChecked, true⟩,
    reasonsIfNothingIsCompared := check ⟨.notChecked, false⟩ }

/-- *Given* two travelers whose credentials were issued to one device: Alice
Martin's photoid and Bruno Keller's boarding pass in the wallet of a shared
phone.

*When* the phone presents both together, under the reading that the two
credentials must carry the same device key and their names are not compared.

*Then* the pair is accepted: Alice's face goes with Bruno's boarding pass.
Comparing the names as well would refuse this pair. -/
@[case, checks "OID-207.1"]
def twoTravelersOneDevice : DevicePairCheck :=
  checkDevicePair (heldPhotoid "MARTIN" "ALICE" "traveler 1" "shared phone")
    (heldBoardingPass "KELLER/BRUNO" "traveler 2" "shared phone")

#guard twoTravelersOneDevice.reasonsIfDeviceKeysMustMatch == some []

/-- *Given* one traveler who holds a photoid on a phone and a boarding pass on
a tablet, each accepted on its own.

*When* the two are presented together, under the reading that the two
credentials must carry the same device key and their names are not compared.

*Then* the pair is refused, though both credentials are about the same
person.  With nothing compared it is accepted. -/
@[case, checks "OID-207.3"]
def twoDevicesOneTraveler : DevicePairCheck :=
  checkDevicePair (heldPhotoid "SMITH" "JOHN" "traveler 1" "phone")
    (heldBoardingPass "SMITH/JOHN" "traveler 1" "tablet")

#guard twoDevicesOneTraveler.reasonsIfDeviceKeysMustMatch == some [.notOneTraveler] &&
  twoDevicesOneTraveler.reasonsIfNothingIsCompared == some []

end Rules.OneId
