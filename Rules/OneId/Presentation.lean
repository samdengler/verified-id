import Rules.OneId.IsoProfiles

/-!
# Presenting credentials and accepting a presentation

The part every profile of §4.2 shares: a wallet answers a request with the
data elements that were requested and that the holder approved, and a relying
party accepts the answer after it has authenticated the issuer, the data and
the device.  The guide states the relying party's checks profile by profile
and not always with the same force, so the differences are readings.
-/

namespace Rules.OneId

open Rules.Core

/-! ## The wallet's answer -/

/-- What a wallet does when the holder approves only some of the data elements
requested from a credential.  The guide requires informed consent and that
the wallet show what is shared, and says nothing of a holder who approves a
part.  For its own profile OpenID4VP says a wallet that cannot deliver every
claim asked of a credential must not return that credential (§6.4.1); whether
a holder's refusal counts as that is not said.  A credential that does not
hold a requested data element is a separate case, which does not depend on
consent and is decided where a credential is presented. -/
inductive ConsentReading
  /-- The wallet sends the data elements the holder approved. -/
  | perElement
  /-- The wallet sends a credential only when the holder approved every data
  element requested from it. -/
  | wholeCredential
  deriving DecidableEq, Repr, Inhabited

/-- The data elements a request asks of one credential. -/
def Request.wanted (q : Request) (cred : Credential) : List ElementRef :=
  q.elements.filter fun ref => decide (ref.docType = cred.mdoc.docType)

/-- One credential as a wallet presents it for a request: the data elements
that were requested and approved, signed with the credential's device key over
the session transcript.  The wallet presents nothing of a credential when no
data element is left to disclose, and under the whole credential reading also
when a requested data element is not approved.  In the OpenID4VP profile it
also presents nothing of a credential that does not hold every data element
requested from it (OpenID4VP §6.4.1).  In the two ISO profiles it presents
the requested data elements it holds: the guide says so for proximity
(§4.2.2 step 4), and the mdoc profile leaves the response to ISO/IEC TS
18013-7 Annex C §C.3, which was not read. -/
def Credential.present (c : ConsentReading) (q : Request) (consent : Consent) (t : SessionTranscript)
    (cred : Credential) : Option Presented :=
  let wanted := q.wanted cred
  let view := cred.mdoc.disclose (wanted.filter fun ref => decide (ref ∈ consent.approved))
  if view.nameSpaces = [] then none
  else if q.profile = .openid4vp ∧ ¬ (wanted.all fun ref => decide (ref ∈ cred.mdoc.refs)) then none
  else if c = .wholeCredential ∧ ¬ (wanted.all fun ref => decide (ref ∈ consent.approved)) then none
  else some { mdoc := view, issuer := cred.issuer, issuerSignatureValid := true, deviceKey := cred.deviceKey,
              deviceSignature := some ⟨cred.deviceKey, t⟩ }

/-- EARS: When a wallet answers a request, the system shall disclose only
data elements that the request names and that the holder approved.

Story: As a passenger, I want my wallet to share what I was asked for and
agreed to and nothing else, so that a relying party learns no more about me
than I chose.

Acceptance criteria:

* OID-201.1: The system shall disclose no data element that the request did
  not name.
* OID-201.2: The system shall disclose no data element that the holder did
  not approve.
* OID-201.3: If the holder approves nothing, then the system shall present no
  credential.
* OID-201.4: The system shall sign each credential it presents with that
  credential's device key, over the session transcript of the request as the
  wallet received it.
* OID-201.5: If the holder approves only some of the data elements requested
  from a credential, then the system shall not present that credential.

The request is the one that reached the wallet, with the origin the user
agent reports, which may differ from the request a relying party made.  The
guide requires informed consent before a response in every profile (§3.2,
§4.2.1.2 step 5, §4.2.1.3 step 4, §4.2.2 step 4) and says selective
disclosure lets a holder share the minimum (§3.1).  OpenID4VP forbids a
wallet to send a selectively disclosable claim the query did not select
(§6.4).  What a wallet does with partial approval is the reading
({name}`ConsentReading`).  The guide also requires holder authentication
before a presentation (§3.2), which the model does not have: a consent here
stands for an approval by the authenticated holder.  How a device signs is in
ISO/IEC 18013-5, which was not read; the model records which key signed and
over what.  The wallet's own
checks on a request are separate rules ({name}`OpenId4Vp.walletFindings` for
the OpenID4VP profile). -/
@[ears "OID-201", source "tig-3.1 tig-3.2 tig-4.2.1.2 tig-4.2.1.3 tig-4.2.2",
  assumes "x-openid4vp x-18013-5-mdoc-auth x-18013-5-request-response"]
def Wallet.respond (c : ConsentReading) (x : IsoTranscripts) (held : List Credential) (seen : Request)
    (consent : Consent) : Response :=
  ⟨held.filterMap (Credential.present c seen consent (expectedTranscript x seen))⟩

/-! ## The relying party's decision -/

/-- What the guide leaves undecided about a relying party's checks.  Each
point is stated for the profiles whose text leaves it open; where a profile's
text settles it, the point does not apply there. -/
structure AcceptanceReading where
  /-- Whether a relying party in the mdoc profile refuses a response that holds
  a data element it did not request.  The guide's list of checks for that
  profile has no step that compares the response with the request (§4.2.1.2
  step 6). -/
  extrasRefusedInMdocProfile : Bool
  /-- Whether a relying party in the OpenID4VP profile refuses a response that
  holds a data element it did not request.  The guide says the token must
  match the query (§4.2.1.3 step 5).  OpenID4VP requires the verifier to check
  that the returned presentations satisfy the request as §6.4 describes, where
  a wallet must not send a selectively disclosable claim that was not
  selected, and to discard a presentation that fails a check (§8.6, §14.9).
  Whether that rule of §6.4 is among what the verifier checks is not said in
  so many words. -/
  extrasRefusedInOpenId4Vp : Bool
  /-- Whether a reader in proximity refuses a response that holds a data
  element it did not request.  The guide says issuer data validation ensures
  the data elements that were requested (§4.2.2 step 5); what the ISO clause
  it cites checks was not read. -/
  extrasRefusedInProximity : Bool
  /-- Whether a relying party in the mdoc profile refuses a response that lacks
  a data element it requested.  The guide's list of checks for that profile
  has no such step (§4.2.1.2 step 6). -/
  missingRefusedInMdocProfile : Bool
  /-- Whether a reader in proximity refuses a response that lacks a data
  element it requested.  The guide says issuer data validation ensures the
  data elements that were requested (§4.2.2 step 5), from an ISO clause that
  was not read. -/
  missingRefusedInProximity : Bool
  /-- Whether issuer data authentication in the OpenID4VP profile includes the
  check that a credential is within its validity.  The profile cites ISO/IEC
  18013-5 §9.1.2 with must and does not say (§4.2.1.3 step 5), and OpenID4VP
  §8.6 names no such check.  The clause was not read. -/
  validityCheckedInOpenId4Vp : Bool
  /-- Whether a reader in proximity refuses a credential past its validity.
  The profile cites ISO/IEC 18013-5 §9.1.2 with must and §9.3.1, the clause
  the mdoc profile says covers time validity, with should; its list opens by
  saying the checks include the validity of what was received (§4.2.2
  step 5).  Neither clause was read. -/
  validityCheckedInProximity : Bool
  /-- Whether a reader in proximity rebuilds the session transcript and
  validates the device signature over it.  The guide lists the rebuilding with
  no requirement word, after a decryption step it marks should, in a list a
  verifier is said to need to perform; the device signature must be validated
  to prevent man in the middle attacks (§4.2.2 step 5). -/
  proximityRebuildsTranscript : Bool
  deriving DecidableEq, Repr, Inhabited

/-- Whether a relying party checks the end of validity, in a profile.  The
mdoc profile says its issuer data authentication covers time validity
(§4.2.1.2 step 6). -/
def AcceptanceReading.checksValidity (r : AcceptanceReading) : Profile → Bool
  | .mdocOverDcApi => true
  | .openid4vp => r.validityCheckedInOpenId4Vp
  | .proximity => r.validityCheckedInProximity

/-- Whether a relying party compares a response's session transcript with its
request, in a profile.  The OpenID4VP profile requires it (§4.2.1.3 step 5).
The mdoc profile requires mdoc authentication with the session transcript of
Annex C, to prevent replay (§4.2.1.2 steps 4 and 6). -/
def AcceptanceReading.checksTranscript (r : AcceptanceReading) : Profile → Bool
  | .openid4vp => true
  | .mdocOverDcApi => true
  | .proximity => r.proximityRebuildsTranscript

/-- Whether a relying party refuses a response with a data element it did not
request, in a profile. -/
def AcceptanceReading.refusesExtras (r : AcceptanceReading) : Profile → Bool
  | .mdocOverDcApi => r.extrasRefusedInMdocProfile
  | .openid4vp => r.extrasRefusedInOpenId4Vp
  | .proximity => r.extrasRefusedInProximity

/-- Whether a relying party refuses a response that lacks a data element it
requested, in a profile.  In the OpenID4VP profile the verifier must check
that the returned credentials meet the query and that the set returned
satisfies the request (OpenID4VP §8.6, which the guide requires in §4.2.1.3
step 5). -/
def AcceptanceReading.refusesMissing (r : AcceptanceReading) : Profile → Bool
  | .openid4vp => true
  | .mdocOverDcApi => r.missingRefusedInMdocProfile
  | .proximity => r.missingRefusedInProximity

/-- A reason a relying party refuses a response. -/
inductive Refusal
  /-- The issuer of a credential is not on the list of trusted issuers. -/
  | untrustedIssuer (issuer : Issuer)
  /-- The issuer's signature on a credential does not verify. -/
  | issuerSignatureInvalid (docType : String)
  /-- The validity of a credential has ended. -/
  | expired (docType : String)
  /-- A credential comes with no device signature. -/
  | noDeviceSignature (docType : String)
  /-- The device signature was not made with the credential's device key. -/
  | wrongDeviceKey (docType : String)
  /-- The device signature was made over the transcript of another request. -/
  | otherRequest (docType : String)
  /-- The response holds a data element the request did not name. -/
  | notRequested (element : ElementRef)
  /-- The response lacks a data element the request named. -/
  | missing (element : ElementRef)
  deriving DecidableEq, Repr

/-- The reasons a relying party refuses one presented credential. -/
def Presented.refusals (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (now : Instant) (d : Presented) : List Refusal :=
  (if d.issuer ∈ trusted then [] else [.untrustedIssuer d.issuer]) ++
  (if d.issuerSignatureValid = true then [] else [.issuerSignatureInvalid d.mdoc.docType]) ++
  (if r.checksValidity q.profile = true ∧ expired e d.mdoc now = true then [.expired d.mdoc.docType] else []) ++
  (match d.deviceSignature with
    | none => [.noDeviceSignature d.mdoc.docType]
    | some s =>
      (if s.key = d.deviceKey then [] else [.wrongDeviceKey d.mdoc.docType]) ++
      (if r.checksTranscript q.profile = true ∧ s.transcript ≠ expectedTranscript x q
        then [.otherRequest d.mdoc.docType] else [])) ++
  (if r.refusesExtras q.profile = true then
    (d.mdoc.refs.filter fun ref => decide (ref ∉ q.elements)).map .notRequested else [])

/-- The data elements a request named that a response lacks, when the
relying party refuses such a response. -/
def missingRefusals (r : AcceptanceReading) (q : Request) (response : Response) : List Refusal :=
  if r.refusesMissing q.profile = true then
    (q.elements.filter fun ref => decide (ref ∉ response.refs)).map .missing else []

/-- EARS: When a relying party receives a response to its request, the system
shall accept the response only if every credential in it comes from a trusted
issuer, is authentic, is presented by the device it was issued to, and
answers that request.

Story: As a relying party, I want to act only on data a trusted issuer signed
and the holder's own device presented for my request, so that I can rely on
it at a touchpoint.

Acceptance criteria:

* OID-202.1: If the issuer of a presented credential is not on the relying
  party's list of trusted issuers, then the system shall reject the response.
* OID-202.2: If the issuer's signature on a presented credential does not
  verify, then the system shall reject the response.
* OID-202.3: If a presented credential has no device signature made with the
  device key its issuer signed, then the system shall reject the response.
* OID-202.4: If a presented credential's device signature was made for
  another request, then the system shall reject the response.
* OID-202.5: If the validity of a presented credential has ended, then the
  system shall reject the response.
* OID-202.6: If a response holds a data element the request did not name,
  then the system shall reject the response.
* OID-202.7: If a response lacks a data element the request named, then the
  system shall reject the response.

The result lists the reasons for refusal, and an empty list means the response
is accepted.  All three profiles require issuer authentication against a
list of trusted issuers, issuer data authentication and mdoc authentication
(§4.2.1.2 step 6, §4.2.1.3 step 5, §4.2.2 step 5); the ISO clauses that
define those checks were not read, so the model records only their outcome.
Who is on the list is part of the trust model, which the guide leaves out, so
the list is given to the rule.  The two remote profiles compare the device
signature with the transcript of the request: the OpenID4VP profile says so,
and the mdoc profile requires mdoc authentication with the session transcript
to prevent replay.  The OpenID4VP profile refuses a response that lacks a
requested data element (OpenID4VP §8.6).  The rest differs by profile and is
the reading ({name}`AcceptanceReading`).  A reason to refuse one credential
refuses the whole response; OpenID4VP discards the presentation that fails a
check and rejects the token only when a check of the whole response fails,
and the model does not tell the two apart.  Revocation is out of the guide's
scope and is not checked.  Decryption is not modelled. -/
@[ears "OID-202", source "tig-3.1 tig-3.2 tig-4.2.1.1 tig-4.2.1.2 tig-4.2.1.3 tig-4.2.2",
  assumes "x-18013-5-issuer-data-auth x-18013-5-mdoc-auth x-18013-5-validity x-18013-7-annex-c x-18013-5-session x-openid4vp"]
def refusals (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts) (trusted : List Issuer)
    (q : Request) (response : Response) (now : Instant) : List Refusal :=
  response.documents.flatMap (Presented.refusals r e x trusted q now) ++ missingRefusals r q response

/-! ## A photoid and a boarding pass presented together -/

/-- What a relying party checks before it treats a presented photoid and a
presented boarding pass as one traveler's.  The guide states no rule.  The
content of the two credentials can be compared ({name}`MatchReading`), and a
presentation adds one more thing to compare: the device keys. -/
structure PairReading where
  /-- What is compared in the content of the two credentials. -/
  content : MatchReading
  /-- Whether the two credentials must carry the same device key. -/
  sameDeviceKey : Bool
  deriving DecidableEq, Repr, Inhabited

/-- Whether a presented photoid and a presented boarding pass pass the check
of a reading. -/
def pairMatch (pr : PairReading) (x792 : Resolution792) (photoid boardingPass : Presented) : Bool :=
  travelerMatch pr.content x792 photoid.mdoc boardingPass.mdoc &&
    (!pr.sameDeviceKey || decide (photoid.deviceKey = boardingPass.deviceKey))

/-- A reason a relying party refuses a photoid and a boarding pass presented
together. -/
inductive PairRefusal
  /-- One of the two credentials is refused on its own. -/
  | refused (reason : Refusal)
  /-- The first credential is not of the photoid document type. -/
  | notAPhotoid (docType : String)
  /-- The second credential is not of the boarding pass document type. -/
  | notABoardingPass (docType : String)
  /-- The two credentials do not pass the check that they are one
  traveler's. -/
  | notOneTraveler
  deriving DecidableEq, Repr

/-- EARS: When a photoid and a boarding pass are presented together, the
system shall accept the pair only if each is accepted on its own and both are
about the same traveler.

Story: As an airport touchpoint, I want the face I match and the boarding
pass I admit to come from one traveler's wallet, so that nobody boards on
another person's boarding pass.

Acceptance criteria:

* OID-207.1: If a photoid and a boarding pass presented together are about
  different travelers, then the system shall reject the pair.
* OID-207.2: If either credential is refused on its own, then the system
  shall reject the pair.
* OID-207.3: When a photoid and a boarding pass presented together are about
  the same traveler and each is accepted on its own, the system shall accept
  the pair.

One request may name both document types (§4.2.1.2 step 1), and a contactless
touchpoint needs both (§4.1.2).  The guide gives no rule for deciding that
the two are one traveler's, so the check is the reading
({name}`PairReading`).  A relying party sees data elements and keys, and who a
credential is about is fixed when it is issued, which the guide puts out of
scope (§1.4). -/
@[ears "OID-207", source "tig-4.1.2 tig-3.2 tig-1.4 tig-4.2.1.2 model-matching model-pair-device-key",
  assumes "x-res792-bcbp x-18013-5-mdoc-auth"]
def pairRefusals (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts) (trusted : List Issuer)
    (pr : PairReading) (x792 : Resolution792) (q : Request) (photoid boardingPass : Presented)
    (now : Instant) : List PairRefusal :=
  (refusals r e x trusted q ⟨[photoid, boardingPass]⟩ now).map .refused ++
  (if photoid.mdoc.docType = photoidDocType then [] else [.notAPhotoid photoid.mdoc.docType]) ++
  (if boardingPass.mdoc.docType = boardingPassDocType then []
    else [.notABoardingPass boardingPass.mdoc.docType]) ++
  (if pairMatch pr x792 photoid boardingPass = true then [] else [.notOneTraveler])

/-- Whether a presented credential is a presentation of an issued one: the
same issuer, device key, document type and end of validity, and no data
element the issued credential does not hold. -/
def Presented.isOf (d : Presented) (c : Credential) : Prop :=
  d.issuer = c.issuer ∧ d.deviceKey = c.deviceKey ∧ d.mdoc.docType = c.mdoc.docType ∧
    d.mdoc.validUntil = c.mdoc.validUntil ∧ ∀ ref ∈ d.mdoc.refs, ref ∈ c.mdoc.refs

end Rules.OneId
