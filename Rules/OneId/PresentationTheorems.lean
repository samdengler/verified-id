import Rules.OneId.Presentation
import Rules.OneId.Theorems

/-!
# Guarantees about presentation

Properties the presentation rules are claimed to have.  A guarantee holds for
every reading of the guide, for every list of trusted issuers, and for every
content the ISO clauses and Resolution 792 could have.  One left open is a
question for the business, with an example in
{lit}`Rules.OneId.PresentationExamples`
that shows the case.

Signatures are symbolic here, as in the rules: a theorem says what a relying
party that makes the guide's comparisons can conclude, and assumes that a
signature that verifies was made with the key it names.
-/

namespace Rules.OneId

open Rules.Core

/-! ## The wallet's answer -/

/-- A data element of a credential with only the allowed data elements
disclosed is one of the allowed ones and one the credential holds. -/
theorem Mdoc.mem_refs_disclose (m : Mdoc) (allowed : List ElementRef) (ref : ElementRef)
    (h : ref ∈ (m.disclose allowed).refs) : ref ∈ allowed ∧ ref ∈ m.refs := by
  simp only [Mdoc.refs, Mdoc.disclose, List.mem_flatMap, List.mem_map, List.mem_filter] at h ⊢
  obtain ⟨ns, ⟨⟨ns0, hns0, rfl⟩, _⟩, el, hel, rfl⟩ := h
  simp only [List.mem_filter, decide_eq_true_eq] at hel
  exact ⟨hel.2, ns0, hns0, el, hel.1, rfl⟩

private theorem present_some (c : ConsentReading) (q : Request) (consent : Consent)
    (t : SessionTranscript) (cred : Credential) (d : Presented)
    (h : Credential.present c q consent t cred = some d) :
    d.mdoc = cred.mdoc.disclose ((q.wanted cred).filter fun ref => decide (ref ∈ consent.approved)) ∧
      d.issuer = cred.issuer ∧ d.issuerSignatureValid = true ∧ d.deviceKey = cred.deviceKey ∧
      d.deviceSignature = some ⟨cred.deviceKey, t⟩ := by
  unfold Credential.present at h
  simp only at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · split at h
      · simp at h
      · simp only [Option.some.injEq] at h
        subst h
        exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- A wallet discloses only data elements the request named and the holder
approved, under both readings of partial approval. -/
@[checks "OID-201.1 OID-201.2"]
theorem wallet_discloses_only_requested_and_approved (c : ConsentReading) (x : IsoTranscripts)
    (held : List Credential) (seen : Request) (consent : Consent) (ref : ElementRef)
    (h : ref ∈ (Wallet.respond c x held seen consent).refs) :
    ref ∈ seen.elements ∧ ref ∈ consent.approved := by
  simp only [Response.refs, Wallet.respond, List.mem_flatMap, List.mem_filterMap] at h
  obtain ⟨d, ⟨cred, _, hd⟩, href⟩ := h
  obtain ⟨hm, _⟩ := present_some c seen consent _ cred d hd
  rw [hm] at href
  have := (Mdoc.mem_refs_disclose _ _ _ href).1
  simp only [Request.wanted, List.mem_filter, decide_eq_true_eq] at this
  exact ⟨this.1.1, this.2⟩

/-- A wallet presents no credential when the holder approved nothing. -/
@[checks "OID-201.3"]
theorem wallet_presents_nothing_without_consent (c : ConsentReading) (x : IsoTranscripts)
    (held : List Credential) (seen : Request) (consent : Consent) (h : consent.approved = []) :
    (Wallet.respond c x held seen consent).documents = [] := by
  simp only [Wallet.respond, List.filterMap_eq_nil_iff]
  intro cred _
  unfold Credential.present
  simp [h, Mdoc.disclose]

/-- Every credential a wallet presents is signed with that credential's
device key, over the session transcript of the request as the wallet received
it. -/
@[checks "OID-201.4"]
theorem wallet_signs_with_device_key (c : ConsentReading) (x : IsoTranscripts)
    (held : List Credential) (seen : Request) (consent : Consent) (d : Presented)
    (h : d ∈ (Wallet.respond c x held seen consent).documents) :
    ∃ cred ∈ held, d.issuer = cred.issuer ∧ d.deviceKey = cred.deviceKey ∧
      d.deviceSignature = some ⟨cred.deviceKey, expectedTranscript x seen⟩ := by
  simp only [Wallet.respond, List.mem_filterMap] at h
  obtain ⟨cred, hc, hd⟩ := h
  obtain ⟨_, hi, _, hk, hs⟩ := present_some c seen consent _ cred d hd
  exact ⟨cred, hc, hi, hk, hs⟩

/-- A wallet presents nothing of a credential when the holder approved only
some of the data elements requested from it.

Not proven: it fails when a wallet sends the data elements the holder
approved.  The example {lit}`partialConsent` shows a request for a name and a
portrait, a holder who approves the name only, and a wallet that sends the
name under one reading and nothing under the other.

Open question for the business.  The guide requires informed consent and says
the wallet must show what is shared with whom.  It does not say what happens
when a holder agrees to a part.  OpenID4VP says a wallet that cannot deliver
every claim asked of a credential must not return it (§6.4.1), which fits the
second reading if a refusal counts, and a relying party in that profile
refuses a response that lacks a requested claim (§8.6).  When a holder approves only some of the
data elements requested, does the wallet send those, or nothing from that
credential?  And is the answer the same in all three profiles? -/
@[open_question, checks "OID-201.5"]
theorem partial_consent_withholds_credential (c : ConsentReading) (q : Request) (consent : Consent)
    (t : SessionTranscript) (cred : Credential) (ref : ElementRef) (hw : ref ∈ q.wanted cred)
    (hn : ref ∉ consent.approved) : Credential.present c q consent t cred = none := by
  sorry

/-- Under the reading that a wallet sends a credential only when every data
element requested from it is approved, a wallet presents nothing of a
credential the holder approved in part. -/
theorem partial_consent_withholds_credential_of_wholeCredential (q : Request) (consent : Consent)
    (t : SessionTranscript) (cred : Credential) (ref : ElementRef) (hw : ref ∈ q.wanted cred)
    (hn : ref ∉ consent.approved) : Credential.present .wholeCredential q consent t cred = none := by
  unfold Credential.present
  simp only
  split
  · rfl
  · split
    · rfl
    · have hall : ¬ ((q.wanted cred).all fun ref => decide (ref ∈ consent.approved)) = true := by
        intro hall
        rw [List.all_eq_true] at hall
        have := hall ref hw
        simp [hn] at this
      simp [hall]

/-! ## The relying party's decision -/

private theorem refusals_mem (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    Presented.refusals r e x trusted q now d = [] := by
  unfold refusals at h
  rw [List.append_eq_nil_iff, List.flatMap_eq_nil_iff] at h
  exact h.1 d hd

private theorem refusals_missing (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) : missingRefusals r q response = [] := by
  unfold refusals at h
  rw [List.append_eq_nil_iff] at h
  exact h.2

private theorem presented_parts (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (now : Instant) (d : Presented)
    (h : Presented.refusals r e x trusted q now d = []) :
    d.issuer ∈ trusted ∧ d.issuerSignatureValid = true ∧
      ¬ (r.checksValidity q.profile = true ∧ expired e d.mdoc now = true) ∧
      (∃ s, d.deviceSignature = some s ∧ s.key = d.deviceKey ∧
        ¬ (r.checksTranscript q.profile = true ∧ s.transcript ≠ expectedTranscript x q)) ∧
      (r.refusesExtras q.profile = true → ∀ ref ∈ d.mdoc.refs, ref ∈ q.elements) := by
  unfold Presented.refusals at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩ := h
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · by_contra hc
    simp [hc] at h1
  · by_contra hc
    simp [hc] at h2
  · intro hc
    simp [hc] at h3
  · cases hs : d.deviceSignature with
    | none => simp [hs] at h4
    | some s =>
      simp only [hs, List.append_eq_nil_iff] at h4
      refine ⟨s, rfl, ?_, ?_⟩
      · by_contra hc
        simp [hc] at h4
      · intro hc
        simp [hc] at h4
  · intro hr ref href
    simp only [hr, ↓reduceIte, List.map_eq_nil_iff, List.filter_eq_nil_iff] at h5
    simpa using h5 ref href

/-- Every credential in an accepted response comes from an issuer on the
relying party's list, with an issuer's signature that verifies. -/
@[checks "OID-202.1 OID-202.2"]
theorem accepted_from_trusted_issuer (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    d.issuer ∈ trusted ∧ d.issuerSignatureValid = true := by
  obtain ⟨h1, h2, _⟩ := presented_parts r e x trusted q now d (refusals_mem r e x trusted q response now h d hd)
  exact ⟨h1, h2⟩

/-- Every credential in an accepted response has a device signature made with
the device key its issuer signed, in every profile and under every reading.
This is the device half of the guarantee that a presentation is bound to the
holder's device and the relying party's request. -/
@[checks "OID-202.3"]
theorem accepted_signed_by_device_key (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    ∃ s, d.deviceSignature = some s ∧ s.key = d.deviceKey := by
  obtain ⟨_, _, _, ⟨s, hs, hk, _⟩, _⟩ :=
    presented_parts r e x trusted q now d (refusals_mem r e x trusted q response now h d hd)
  exact ⟨s, hs, hk⟩

private theorem answers_when_compared (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hr : r.checksTranscript q.profile = true)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    ∃ s, d.deviceSignature = some s ∧ s.transcript = expectedTranscript x q := by
  obtain ⟨_, _, _, ⟨s, hs, _, ht⟩, _⟩ :=
    presented_parts r e x trusted q now d (refusals_mem r e x trusted q response now h d hd)
  refine ⟨s, hs, ?_⟩
  by_contra hc
  exact ht ⟨hr, hc⟩

/-- Every credential in an accepted response has a device signature made over
the session transcript of the relying party's own request.

Not proven: it fails in proximity under the reading that the reader does not
rebuild the session transcript.  The example {lit}`replayedInProximity` shows
a response made in one proximity session and accepted in a later session with
a new reader key under that reading.  The two remote profiles compare the
transcript under every reading.

Open question for the business.  The OpenID4VP profile requires the relying
party to rebuild the session transcript and validate the nonce, and the mdoc
profile requires mdoc authentication with the session transcript to prevent
replay.  The proximity profile lists the rebuilding with no requirement word,
after a decryption step it marks should, in a list of checks a verifier is
said to need to perform, and requires the device signature to be validated to
prevent man in the middle attacks.  Must a reader in proximity rebuild the
session transcript and check that the device signature was made over it? -/
@[open_question, checks "OID-202.4"]
theorem accepted_answers_this_request (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    ∃ s, d.deviceSignature = some s ∧ s.transcript = expectedTranscript x q := by
  sorry

/-- Under the reading that a reader in proximity rebuilds the session
transcript, an accepted response was signed over the transcript of the
relying party's own request, in every profile. -/
theorem accepted_answers_this_request_of_proximityRebuildsTranscript (r : AcceptanceReading)
    (e : ExpiryReading) (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response)
    (now : Instant) (hr : r.proximityRebuildsTranscript = true)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    ∃ s, d.deviceSignature = some s ∧ s.transcript = expectedTranscript x q :=
  answers_when_compared r e x trusted q response now
    (by cases hq : q.profile <;> simp [AcceptanceReading.checksTranscript, hr]) h d hd

/-- In the two remote profiles, under every reading, an accepted response was
signed over the transcript of the relying party's own request.  What the
transcript of the mdoc profile contains is in ISO/IEC TS 18013-7, which was
not read. -/
theorem accepted_answers_this_request_in_remote_profiles (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hq : q.profile ≠ .proximity)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    ∃ s, d.deviceSignature = some s ∧ s.transcript = expectedTranscript x q :=
  answers_when_compared r e x trusted q response now
    (by cases hp : q.profile <;> simp_all [AcceptanceReading.checksTranscript]) h d hd

/-- In the mdoc profile a response accepted for two requests was made for one
nonce: a captured response cannot answer a request with a new nonce.

Not proven: the relying party compares the session transcript, and the guide
does not say what the transcript of this profile contains.  The example
{lit}`nonceOutsideTheTranscript` shows, with invented stand-ins for the
transcript, a response refused for a later request when the transcript holds
the nonce and accepted when it does not.

Open question for the business, settled by reading a source.  The guide says
the request carries a nonce and that the session transcript follows ISO/IEC
TS 18013-7 Annex C §C.5, which this project has not read.  Does the session
transcript of the mdoc profile include the nonce of the request? -/
@[open_question]
theorem MdocProfile.accepted_for_one_nonce (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q1 q2 : Request) (response : Response)
    (now1 now2 : Instant) (h1 : q1.profile = .mdocOverDcApi) (h2 : q2.profile = .mdocOverDcApi)
    (d : Presented) (hd : d ∈ response.documents)
    (a1 : refusals r e x trusted q1 response now1 = [])
    (a2 : refusals r e x trusted q2 response now2 = []) : q1.nonce = q2.nonce := by
  sorry

/-- Where the session transcript of the mdoc profile determines the nonce of
the request, a response accepted for two requests of that profile was made
for one nonce, under every reading.  The condition is what ISO/IEC TS 18013-7
Annex C §C.5 would have to say. -/
theorem MdocProfile.accepted_for_one_nonce_if_transcript_holds_nonce (r : AcceptanceReading)
    (e : ExpiryReading) (x : IsoTranscripts) (trusted : List Issuer) (q1 q2 : Request)
    (response : Response) (now1 now2 : Instant)
    (hx : ∀ q q', x.annexC q = x.annexC q' → q.nonce = q'.nonce)
    (h1 : q1.profile = .mdocOverDcApi) (h2 : q2.profile = .mdocOverDcApi)
    (d : Presented) (hd : d ∈ response.documents)
    (a1 : refusals r e x trusted q1 response now1 = [])
    (a2 : refusals r e x trusted q2 response now2 = []) : q1.nonce = q2.nonce := by
  obtain ⟨s1, hs1, ht1⟩ :=
    accepted_answers_this_request_in_remote_profiles r e x trusted q1 response now1 (by simp [h1]) a1 d hd
  obtain ⟨s2, hs2, ht2⟩ :=
    accepted_answers_this_request_in_remote_profiles r e x trusted q2 response now2 (by simp [h2]) a2 d hd
  rw [hs1] at hs2
  simp only [Option.some.injEq] at hs2
  subst hs2
  rw [ht1] at ht2
  simp only [expectedTranscript, h1, h2] at ht2
  exact hx _ _ ht2

private theorem not_expired_when_checked (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hr : r.checksValidity q.profile = true)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    expired e d.mdoc now = false := by
  obtain ⟨_, _, hv, _⟩ :=
    presented_parts r e x trusted q now d (refusals_mem r e x trusted q response now h d hd)
  cases hx : expired e d.mdoc now with
  | false => rfl
  | true => exact absurd ⟨hr, hx⟩ hv

/-- No credential in an accepted response has passed the end of its validity.

Not proven: it fails in the OpenID4VP profile and in proximity under the
reading that the relying party there does not check validity.  The example
{lit}`expiredBoardingPassAccepted` shows a boarding pass presented an hour
after its validity ended, refused in the mdoc profile and accepted in the
other two under that reading.

Open question for the business.  The mdoc profile cites ISO/IEC 18013-5
§9.3.1 for issuer data authentication and says it covers time validity.  The
OpenID4VP profile cites §9.1.2 with must and does not say whether it does, and
OpenID4VP §8.6 names no check of an mdoc's validity.  Proximity cites §9.1.2
with must and §9.3.1 with should, and its list of checks opens by saying they
include the validity of what was received.  Neither ISO clause was read.  Is
a relying party required to refuse an expired credential in the OpenID4VP
profile and in proximity? -/
@[open_question, checks "OID-202.5"]
theorem accepted_not_expired (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    expired e d.mdoc now = false := by
  sorry

/-- Under the reading that the relying party checks validity in the OpenID4VP
profile and in proximity, no credential in an accepted response is expired,
in every profile. -/
theorem accepted_not_expired_of_validityChecked (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (ho : r.validityCheckedInOpenId4Vp = true) (hp : r.validityCheckedInProximity = true)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    expired e d.mdoc now = false :=
  not_expired_when_checked r e x trusted q response now
    (by cases hq : q.profile <;> simp [AcceptanceReading.checksValidity, ho, hp]) h d hd

/-- In the mdoc profile, under every reading, no credential in an accepted
response is expired. -/
theorem accepted_not_expired_in_mdocProfile (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hq : q.profile = .mdocOverDcApi)
    (h : refusals r e x trusted q response now = []) (d : Presented) (hd : d ∈ response.documents) :
    expired e d.mdoc now = false :=
  not_expired_when_checked r e x trusted q response now
    (by simp [AcceptanceReading.checksValidity, hq]) h d hd

/-- An accepted response holds only data elements the request named.

Not proven: it fails in each profile under the reading that a relying party
there does not refuse extra data.  The example {lit}`extraElementAccepted`
shows a request for a family name and a response that also holds the
portrait, accepted under that reading.

Open question for the business.  OpenID4VP forbids a wallet to send a claim
the query did not select (§6.4), tells a verifier to check that what is
returned satisfies the request as §6.4 describes and to discard a
presentation that fails a check (§8.6), and not to rely on the wallet for it
(§14.9).  The mdoc profile's list of checks has no step that compares the
response with the request.  The proximity profile says issuer data validation
ensures the data elements requested.  In each profile, must a relying party
refuse a response that holds a data element it did not request, discard the
credential that holds it, or may it accept the response and set the extra
aside? -/
@[open_question, checks "OID-202.6"]
theorem accepted_holds_only_requested (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (ref : ElementRef) (href : ref ∈ response.refs) :
    ref ∈ q.elements := by
  sorry

/-- Under the reading that a relying party refuses extra data in all three
profiles, an accepted response holds only data elements the request named. -/
theorem accepted_holds_only_requested_of_extrasRefused (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hm : r.extrasRefusedInMdocProfile = true) (ho : r.extrasRefusedInOpenId4Vp = true)
    (hp : r.extrasRefusedInProximity = true)
    (h : refusals r e x trusted q response now = []) (ref : ElementRef) (href : ref ∈ response.refs) :
    ref ∈ q.elements := by
  simp only [Response.refs, List.mem_flatMap] at href
  obtain ⟨d, hd, href⟩ := href
  obtain ⟨_, _, _, _, hx⟩ :=
    presented_parts r e x trusted q now d (refusals_mem r e x trusted q response now h d hd)
  exact hx (by cases hq : q.profile <;> simp [AcceptanceReading.refusesExtras, hm, ho, hp]) ref href

private theorem holds_every_when_refused (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hr : r.refusesMissing q.profile = true)
    (h : refusals r e x trusted q response now = []) (ref : ElementRef) (href : ref ∈ q.elements) :
    ref ∈ response.refs := by
  have hm := refusals_missing r e x trusted q response now h
  unfold missingRefusals at hm
  simp only [hr, ↓reduceIte, List.map_eq_nil_iff, List.filter_eq_nil_iff] at hm
  simpa using hm ref href

/-- An accepted response holds every data element the request named.

Not proven: it fails in the mdoc profile and in proximity under the reading
that a relying party there does not refuse a response that lacks something.
The example {lit}`partialResponse` shows a request for a family name and a
portrait answered with the family name only, refused in the OpenID4VP profile
and accepted in the mdoc profile under that reading.

Open question for the business.  OpenID4VP requires the verifier to check
that the returned credentials meet the query and that what is returned
satisfies the request (§8.6), which the guide makes a must for its profile.
The mdoc profile's list of checks has no such step, and the proximity profile
says issuer data validation ensures the data elements requested, from an ISO
clause this project has not read.  Must a relying party in the mdoc profile
and in proximity refuse a response that lacks a data element it requested? -/
@[open_question, checks "OID-202.7"]
theorem accepted_holds_every_requested (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (h : refusals r e x trusted q response now = []) (ref : ElementRef) (href : ref ∈ q.elements) :
    ref ∈ response.refs := by
  sorry

/-- Under the reading that a relying party in the mdoc profile and in
proximity refuses a response that lacks a requested data element, an accepted
response holds every data element the request named, in every profile. -/
theorem accepted_holds_every_requested_of_missingRefused (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hm : r.missingRefusedInMdocProfile = true) (hp : r.missingRefusedInProximity = true)
    (h : refusals r e x trusted q response now = []) (ref : ElementRef) (href : ref ∈ q.elements) :
    ref ∈ response.refs :=
  holds_every_when_refused r e x trusted q response now
    (by cases hq : q.profile <;> simp [AcceptanceReading.refusesMissing, hm, hp]) h ref href

/-- In the OpenID4VP profile, under every reading, an accepted response holds
every data element the request named. -/
theorem accepted_holds_every_requested_in_openid4vp (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hq : q.profile = .openid4vp)
    (h : refusals r e x trusted q response now = []) (ref : ElementRef) (href : ref ∈ q.elements) :
    ref ∈ response.refs :=
  holds_every_when_refused r e x trusted q response now
    (by simp [AcceptanceReading.refusesMissing, hq]) h ref href

/-- A relying party has nothing in a request or a response that records
consent: the model's response carries data elements, signatures and keys, and
no approval.  So for any check of a request and a response, and any data
element in the response, there is a consent that did not approve it.  This
follows from what a response carries, not from a property of the checks.  The
guarantee that a relying party receives only what the holder consented to
rests on the wallet, and on whoever vouches for wallets. -/
theorem no_check_shows_consent (check : Request → Response → Bool) (q : Request) (response : Response)
    (_h : check q response = true) (ref : ElementRef) (href : ref ∈ response.refs) :
    ∃ consent : Consent, ref ∈ response.refs ∧ ref ∉ consent.approved :=
  ⟨⟨[]⟩, href, by simp⟩

/-- The only reason a relying party can give for refusing a response a wallet
makes for its own request, from credentials of trusted issuers that have not
expired, is a data element it requested and did not receive.  This holds in
every profile and under every reading. -/
theorem wallet_response_refused_only_for_missing (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (c : ConsentReading) (held : List Credential)
    (q : Request) (consent : Consent) (now : Instant) (ht : ∀ cred ∈ held, cred.issuer ∈ trusted)
    (hv : ∀ cred ∈ held, expired e cred.mdoc now = false) :
    refusals r e x trusted q (Wallet.respond c x held q consent) now =
      missingRefusals r q (Wallet.respond c x held q consent) := by
  unfold refusals
  have hnil : (Wallet.respond c x held q consent).documents.flatMap
      (Presented.refusals r e x trusted q now) = [] := by
    rw [List.flatMap_eq_nil_iff]
    intro d hd
    simp only [Wallet.respond, List.mem_filterMap] at hd
    obtain ⟨cred, hc, hp⟩ := hd
    obtain ⟨hm, hi, hsv, hk, hs⟩ := present_some c q consent _ cred d hp
    have hexp : expired e d.mdoc now = false := by
      have hu : d.mdoc.validUntil = cred.mdoc.validUntil := by rw [hm]; rfl
      have h0 := hv cred hc
      unfold expired at h0 ⊢
      rw [hu]
      exact h0
    have hrefs : ∀ ref ∈ d.mdoc.refs, ref ∈ q.elements := by
      intro ref href
      rw [hm] at href
      have := (Mdoc.mem_refs_disclose _ _ _ href).1
      simp only [Request.wanted, List.mem_filter, decide_eq_true_eq] at this
      exact this.1.1
    unfold Presented.refusals
    simp only [hi, ht cred hc, hsv, hexp, hs, hk]
    simp
    exact fun _ => hrefs
  rw [hnil, List.nil_append]

/-- A response a wallet makes for the relying party's own request, from
credentials of trusted issuers that have not expired, is accepted in every
profile and under every reading when it holds every data element the request
named.  When the holder approves only part of a request, or the wallet holds
less than was asked, the response may lack something, and whether it is then
refused depends on the profile ({name}`wallet_response_refused_only_for_missing`). -/
theorem wallet_response_accepted (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (c : ConsentReading) (held : List Credential) (q : Request)
    (consent : Consent) (now : Instant) (ht : ∀ cred ∈ held, cred.issuer ∈ trusted)
    (hv : ∀ cred ∈ held, expired e cred.mdoc now = false)
    (hfull : ∀ ref ∈ q.elements, ref ∈ (Wallet.respond c x held q consent).refs) :
    refusals r e x trusted q (Wallet.respond c x held q consent) now = [] := by
  rw [wallet_response_refused_only_for_missing r e x trusted c held q consent now ht hv]
  unfold missingRefusals
  split
  · rw [List.map_eq_nil_iff, List.filter_eq_nil_iff]
    intro ref href
    simpa using hfull ref href
  · rfl

/-! ## The OpenID4VP profile -/

private theorem OpenId4Vp.signatureFindings_eq_nil (a : OpenId4Vp.AuthorizationRequest) :
    OpenId4Vp.signatureFindings a = [] ↔ a.signedWith = some a.clientCertificate := by
  unfold OpenId4Vp.signatureFindings
  cases hs : a.signedWith with
  | none => simp
  | some c => by_cases hc : c = a.clientCertificate <;> simp [hc]

/-- An accepted OpenID4VP request has the values the guide names, is signed
with the key of the certificate its client identifier names, names an
expected origin, carries an encryption key and a nonce, and asks only for
mdoc credentials. -/
@[checks "OID-203.1 OID-203.2 OID-203.3 OID-203.4 OID-203.5"]
theorem OpenId4Vp.accepted_request_parts (r : OpenId4Vp.RequestReading)
    (a : OpenId4Vp.AuthorizationRequest) (h : OpenId4Vp.requestFindings r a = []) :
    a.protocol = OpenId4Vp.protocolValue ∧ a.responseType = OpenId4Vp.responseTypeValue ∧
      a.responseMode = OpenId4Vp.responseModeValue ∧ a.clientIdPrefix = OpenId4Vp.clientIdPrefixValue ∧
      a.signedWith = some a.clientCertificate ∧ a.expectedOrigins ≠ [] ∧ a.encryptionKey ≠ none ∧
      a.nonce ≠ none ∧ ∀ c ∈ a.credentials, c.format = OpenId4Vp.mdocFormat := by
  unfold OpenId4Vp.requestFindings at h
  rw [List.append_eq_nil_iff] at h
  obtain ⟨hp, h5⟩ := h
  unfold OpenId4Vp.parameterFindings at hp
  simp only [List.append_eq_nil_iff] at hp
  obtain ⟨⟨⟨⟨⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h6⟩, h7⟩, h8⟩, h9⟩, _⟩ := hp
  refine ⟨?_, ?_, ?_, ?_, (OpenId4Vp.signatureFindings_eq_nil a).1 h5, ?_, ?_, ?_, ?_⟩
  · by_contra hc; simp [hc] at h1
  · by_contra hc; simp [hc] at h2
  · by_contra hc; simp [hc] at h3
  · by_contra hc; simp [hc] at h4
  · intro hc; simp [hc] at h6
  · intro hc; simp [hc] at h7
  · intro hc; simp [hc] at h9
  · intro c hcm
    simp only [List.map_eq_nil_iff, List.filter_eq_nil_iff] at h8
    simpa using h8 c hcm

/-- An accepted OpenID4VP request carries a state value.

Not proven: it fails under the reading that follows OpenID4VP, which does not
define the parameter over the Digital Credentials API.  The example
{lit}`requestWithoutState` shows a request shaped like the guide's own
example, rejected under the guide's sentence and accepted under the
specification it cites.

Open question for the business.  The guide says the nonce and state must be
set as OpenID4VP §5.2 says.  That clause requires state only for a
presentation without a holder binding proof, §5.3 exempts the Digital
Credentials API, and Appendix A, which the guide says must be followed, does
not list the parameter.  The guide's example request has none.  Is the must
for state meant, and if so what does a relying party or a wallet do with
it? -/
@[open_question, checks "OID-203.6"]
theorem OpenId4Vp.accepted_request_has_state (r : OpenId4Vp.RequestReading)
    (a : OpenId4Vp.AuthorizationRequest) (h : OpenId4Vp.requestFindings r a = []) : a.state ≠ none := by
  sorry

/-- Under the reading that the guide's must for state is meant, an accepted
OpenID4VP request carries a state value. -/
theorem OpenId4Vp.accepted_request_has_state_of_stateRequired (r : OpenId4Vp.RequestReading)
    (a : OpenId4Vp.AuthorizationRequest) (hr : r.stateRequired = true)
    (h : OpenId4Vp.requestFindings r a = []) : a.state ≠ none := by
  unfold OpenId4Vp.requestFindings OpenId4Vp.parameterFindings at h
  simp only [List.append_eq_nil_iff] at h
  intro hc
  simp [hr, hc] at h

/-- No two accepted requests of one relying party share a nonce or an
encryption key. -/
@[checks "OID-203.7 OID-203.8"]
theorem OpenId4Vp.accepted_requests_fresh (requests : List OpenId4Vp.AuthorizationRequest)
    (h : OpenId4Vp.reuseFindings requests = []) :
    (requests.filterMap (·.nonce)).Nodup ∧ (requests.filterMap (·.encryptionKey)).Nodup := by
  unfold OpenId4Vp.reuseFindings at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨h1, h2⟩ := h
  refine ⟨?_, ?_⟩
  · by_contra hc; simp [hc] at h1
  · by_contra hc; simp [hc] at h2

/-- A wallet answers an OpenID4VP request only if the request came from an
origin it names, under every reading. -/
@[checks "OID-204.1"]
theorem OpenId4Vp.answered_from_expected_origin (r : OpenId4Vp.RequestReading) (w : OpenId4Vp.WalletReading)
    (trustedVerifiers : List OpenId4Vp.Certificate) (seenOrigin : Origin) (a : OpenId4Vp.AuthorizationRequest)
    (h : OpenId4Vp.walletFindings r w trustedVerifiers seenOrigin a = []) :
    seenOrigin ∈ a.expectedOrigins := by
  unfold OpenId4Vp.walletFindings at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨⟨⟨_, h2⟩, _⟩, _⟩ := h
  by_contra hc; simp [hc] at h2

/-- A wallet answers an OpenID4VP request only if it is signed with the key of
the certificate its client identifier names.

Not proven: it fails under the reading that a wallet need not validate the
signature.  The example {lit}`wronglySignedRequestAnswered` shows a request
signed with another certificate's key, from an expected origin, refused by a
wallet that validates the signature and answered by one that does not.

Open question for the business.  The guide introduces the wallet's checks with
should and gives the signature check no requirement word.  OpenID4VP leaves
it to the wallet whether it validates the signature of a request over the
Digital Credentials API (§5.9.3), and the profile requires a wallet only to
support signed requests (HAIP §5.2).  Must a wallet validate the signature of
an OpenID4VP request and refuse one it cannot validate? -/
@[open_question, checks "OID-204.2"]
theorem OpenId4Vp.answered_request_signed (r : OpenId4Vp.RequestReading) (w : OpenId4Vp.WalletReading)
    (trustedVerifiers : List OpenId4Vp.Certificate) (seenOrigin : Origin) (a : OpenId4Vp.AuthorizationRequest)
    (h : OpenId4Vp.walletFindings r w trustedVerifiers seenOrigin a = []) :
    a.signedWith = some a.clientCertificate := by
  sorry

/-- Under the reading that a wallet validates the signature, a request it
answers is signed with the key of the certificate its client identifier
names. -/
theorem OpenId4Vp.answered_request_signed_of_signatureChecked (r : OpenId4Vp.RequestReading)
    (w : OpenId4Vp.WalletReading) (trustedVerifiers : List OpenId4Vp.Certificate) (seenOrigin : Origin)
    (a : OpenId4Vp.AuthorizationRequest) (hw : w.signatureChecked = true)
    (h : OpenId4Vp.walletFindings r w trustedVerifiers seenOrigin a = []) :
    a.signedWith = some a.clientCertificate := by
  unfold OpenId4Vp.walletFindings at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨⟨_, h3⟩, _⟩ := h
  rw [← OpenId4Vp.signatureFindings_eq_nil]
  by_contra hc
  simp [hw, hc] at h3

/-- A wallet answers an OpenID4VP request only if the certificate its client
identifier names is on the wallet's list of trusted verifiers.

Not proven: it fails under the reading that a wallet need not check the list.
The example {lit}`untrustedVerifierAnswered` shows a well formed, signed
request from an expected origin whose certificate is not on the wallet's
list, refused under one reading and answered under the other.

Open question for the business.  The guide says the client identifier must be
checked against trusted verifiers, in a list of checks it introduces with
should, and §3.2 says wallets must have a list of trusted verifiers.  For the
mdoc profile it says a wallet should be able to check a verifier against such
a list, and OpenID4VP names no list.  Must a wallet refuse an OpenID4VP
request from a verifier that is not on its list? -/
@[open_question, checks "OID-204.3"]
theorem OpenId4Vp.answered_by_trusted_verifier (r : OpenId4Vp.RequestReading) (w : OpenId4Vp.WalletReading)
    (trustedVerifiers : List OpenId4Vp.Certificate) (seenOrigin : Origin) (a : OpenId4Vp.AuthorizationRequest)
    (h : OpenId4Vp.walletFindings r w trustedVerifiers seenOrigin a = []) :
    a.clientCertificate ∈ trustedVerifiers := by
  sorry

/-- Under the reading that a wallet checks its list of trusted verifiers, a
request it answers names a certificate on the list. -/
theorem OpenId4Vp.answered_by_trusted_verifier_of_verifierListChecked (r : OpenId4Vp.RequestReading)
    (w : OpenId4Vp.WalletReading) (trustedVerifiers : List OpenId4Vp.Certificate) (seenOrigin : Origin)
    (a : OpenId4Vp.AuthorizationRequest) (hw : w.verifierListChecked = true)
    (h : OpenId4Vp.walletFindings r w trustedVerifiers seenOrigin a = []) :
    a.clientCertificate ∈ trustedVerifiers := by
  unfold OpenId4Vp.walletFindings at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨_, h4⟩ := h
  by_contra hc
  simp [hw, hc] at h4

/-- In the OpenID4VP profile a response signed for another nonce, another
origin or another encryption key is refused, under every reading. -/
@[checks "OID-205.1 OID-205.2 OID-205.3"]
theorem OpenId4Vp.refuses_other_request (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (q : Request) (response : Response) (now : Instant)
    (hq : q.profile = .openid4vp) (d : Presented) (hd : d ∈ response.documents)
    (key : Key) (origin : Origin) (nonce : Nonce) (encryptionKey : Key)
    (hs : d.deviceSignature = some ⟨key, OpenId4Vp.transcript origin nonce encryptionKey⟩)
    (hne : origin ≠ q.origin ∨ nonce ≠ q.nonce ∨ encryptionKey ≠ q.encryptionKey) :
    refusals r e x trusted q response now ≠ [] := by
  intro h
  obtain ⟨s, hs', ht⟩ :=
    accepted_answers_this_request_in_remote_profiles r e x trusted q response now (by simp [hq]) h d hd
  rw [hs] at hs'
  simp only [Option.some.injEq] at hs'
  subst hs'
  simp only [expectedTranscript, hq, OpenId4Vp.transcript, SessionTranscript.handover.injEq] at ht
  obtain ⟨h1, h2, h3⟩ := ht
  rcases hne with hne | hne | hne
  · exact hne h1
  · exact hne h2
  · exact hne h3

/-- In the OpenID4VP profile a response accepted for two requests was made for
one nonce, one origin and one encryption key.  Two requests of one relying
party that pass {name}`OpenId4Vp.reuseFindings` have different nonces, so a
response answers at most one of them. -/
theorem OpenId4Vp.accepted_for_one_request (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (q1 q2 : Request) (response : Response)
    (now1 now2 : Instant) (h1 : q1.profile = .openid4vp) (h2 : q2.profile = .openid4vp)
    (d : Presented) (hd : d ∈ response.documents)
    (a1 : refusals r e x trusted q1 response now1 = [])
    (a2 : refusals r e x trusted q2 response now2 = []) :
    q1.nonce = q2.nonce ∧ q1.origin = q2.origin ∧ q1.encryptionKey = q2.encryptionKey := by
  obtain ⟨s1, hs1, ht1⟩ :=
    accepted_answers_this_request_in_remote_profiles r e x trusted q1 response now1 (by simp [h1]) a1 d hd
  obtain ⟨s2, hs2, ht2⟩ :=
    accepted_answers_this_request_in_remote_profiles r e x trusted q2 response now2 (by simp [h2]) a2 d hd
  rw [hs1] at hs2
  simp only [Option.some.injEq] at hs2
  subst hs2
  rw [ht1] at ht2
  simp only [expectedTranscript, h1, h2, OpenId4Vp.transcript, SessionTranscript.handover.injEq] at ht2
  exact ⟨ht2.2.1, ht2.1, ht2.2.2⟩

/-- In a token a relying party accepts, every device response holds at most
one mdoc. -/
@[checks "OID-205.4"]
theorem OpenId4Vp.accepted_token_one_mdoc_each (token : OpenId4Vp.VpToken)
    (h : OpenId4Vp.tokenFindings token = []) (dr : List Presented) (hdr : dr ∈ token) : dr.length ≤ 1 := by
  unfold OpenId4Vp.tokenFindings at h
  rw [List.map_eq_nil_iff, List.filter_eq_nil_iff] at h
  have := h dr hdr
  simp only [decide_eq_true_eq] at this
  omega

/-- The token a wallet builds, one device response for each mdoc, passes the
relying party's check of its form. -/
theorem OpenId4Vp.wallet_token_accepted (response : Response) :
    OpenId4Vp.tokenFindings (OpenId4Vp.deviceResponses response) = [] := by
  simp [OpenId4Vp.tokenFindings, OpenId4Vp.deviceResponses]

/-! ## The mdoc profile and proximity -/

/-- An accepted request of the mdoc profile names both protocol values and
carries a nonce of at least 16 bytes of entropy and a recipient key. -/
@[checks "OID-206.1 OID-206.2 OID-206.3"]
theorem MdocProfile.accepted_deviceRequest_parts (d : MdocProfile.DeviceRequest)
    (h : MdocProfile.requestFindings d = []) :
    d.protocol = MdocProfile.protocolValue ∧
      d.encryptionProtocol = MdocProfile.encryptionProtocolValue ∧
      (∃ n, d.nonce = some n ∧ MdocProfile.minimumNonceEntropy ≤ n.entropyBytes) ∧
      d.recipientKey ≠ none := by
  unfold MdocProfile.requestFindings at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨⟨⟨h1, h2⟩, h3⟩, h4⟩ := h
  refine ⟨?_, ?_, ?_, ?_⟩
  · by_contra hc; simp [hc] at h1
  · by_contra hc; simp [hc] at h2
  · cases hn : d.nonce with
    | none => simp [hn] at h3
    | some n =>
      refine ⟨n, rfl, ?_⟩
      by_contra hc
      simp [hn, hc] at h3
  · intro hc; simp [hc] at h4

/-- In accepted proximity sessions no session retrieves data from a server,
no reader's key is used twice and no device's engagement key is used twice. -/
@[checks "OID-301.1 OID-301.2 OID-301.3"]
theorem Proximity.accepted_sessions (sessions : List Proximity.Session)
    (h : Proximity.sessionFindings sessions = []) :
    (∀ s ∈ sessions, s.retrieval ≠ .server) ∧ (sessions.map (·.readerKey)).Nodup ∧
      (sessions.map (·.deviceKey)).Nodup := by
  unfold Proximity.sessionFindings at h
  simp only [List.append_eq_nil_iff] at h
  obtain ⟨⟨h1, h2⟩, h3⟩ := h
  refine ⟨?_, ?_, ?_⟩
  · intro s hs
    split at h1
    · rename_i hall
      rw [List.all_eq_true] at hall
      simpa using hall s hs
    · exact absurd h1 (List.cons_ne_nil _ _)
  · by_contra hc; simp [hc] at h2
  · by_contra hc; simp [hc] at h3

/-! ## A photoid and a boarding pass presented together -/

private theorem pair_parts (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (pr : PairReading) (x792 : Resolution792) (q : Request)
    (dp db : Presented) (now : Instant)
    (h : pairRefusals r e x trusted pr x792 q dp db now = []) :
    refusals r e x trusted q ⟨[dp, db]⟩ now = [] ∧ dp.mdoc.docType = photoidDocType ∧
      db.mdoc.docType = boardingPassDocType ∧ pairMatch pr x792 dp db = true := by
  unfold pairRefusals at h
  simp only [List.append_eq_nil_iff, List.map_eq_nil_iff] at h
  obtain ⟨⟨⟨h1, h2⟩, h3⟩, h4⟩ := h
  refine ⟨h1, ?_, ?_, ?_⟩
  · by_contra hc; simp [hc] at h2
  · by_contra hc; simp [hc] at h3
  · by_contra hc; simp [hc] at h4

/-- In an accepted pair each credential is accepted on its own, the first is
a photoid and the second is a boarding pass. -/
@[checks "OID-207.2"]
theorem accepted_pair_each_accepted (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (pr : PairReading) (x792 : Resolution792) (q : Request)
    (dp db : Presented) (now : Instant)
    (h : pairRefusals r e x trusted pr x792 q dp db now = []) :
    refusals r e x trusted q ⟨[dp, db]⟩ now = [] ∧ dp.mdoc.docType = photoidDocType ∧
      db.mdoc.docType = boardingPassDocType := by
  obtain ⟨h1, h2, h3, _⟩ := pair_parts r e x trusted pr x792 q dp db now h
  exact ⟨h1, h2, h3⟩

/-- A photoid and a boarding pass that are accepted together are about the
same traveler.

Not proven.  The example {lit}`twoTravelersOneDevice` shows two travelers whose
credentials sit in one wallet under one device key, accepted together under
the reading that compares device keys.  With no comparison, or with names
compared, the examples of the credential data model apply.

Open question for the business.  A presentation gives a relying party one
more thing to compare than the content of the two credentials: the device
key each was issued to.  That settles the question only if issuance makes a
device key stand for one traveler, and the guide puts issuance out of scope.
What ties a photoid and a boarding pass presented together to one traveler:
the same device key, a rule for issuers, a comparison of names, or something
else, and what must a relying party check? -/
@[open_question, checks "OID-207.1"]
theorem accepted_pair_same_traveler (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (pr : PairReading) (x792 : Resolution792) (q : Request)
    (dp db : Presented) (now : Instant) (p b : Credential) (hp : dp.isOf p) (hb : db.isOf b)
    (h : pairRefusals r e x trusted pr x792 q dp db now = []) : p.subject = b.subject := by
  sorry

/-- Under the reading that the two credentials must carry the same device
key, and where issuance gives every device key to one traveler, an accepted
pair is about one traveler.  The second condition is a rule about issuance
that the guide does not state, so deciding the reading is not enough on its
own. -/
theorem accepted_pair_same_traveler_if_one_traveler_per_key (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (pr : PairReading) (x792 : Resolution792) (q : Request)
    (dp db : Presented) (now : Instant) (p b : Credential) (hp : dp.isOf p) (hb : db.isOf b)
    (hpr : pr.sameDeviceKey = true) (issued : List Credential) (hpi : p ∈ issued) (hbi : b ∈ issued)
    (hone : ∀ a ∈ issued, ∀ c ∈ issued, a.deviceKey = c.deviceKey → a.subject = c.subject)
    (h : pairRefusals r e x trusted pr x792 q dp db now = []) : p.subject = b.subject := by
  obtain ⟨_, _, _, hm⟩ := pair_parts r e x trusted pr x792 q dp db now h
  simp only [pairMatch, hpr, Bool.not_true, Bool.false_or, Bool.and_eq_true, decide_eq_true_eq] at hm
  apply hone p hpi b hbi
  rw [← hp.2.1, ← hb.2.1]
  exact hm.2

/-- A presented credential does not carry the traveler it was issued about,
so any two presentations, whatever a relying party checks on them, device keys
included, can be presentations of credentials issued about two different
travelers.  This follows from what a presentation carries, not from a
property of the checks.  So a check of device keys gives one traveler only
together with a rule about issuance. -/
theorem no_presentation_check_identifies_the_traveler (check : Presented → Presented → Bool)
    (dp db : Presented) (_h : check dp db = true) :
    ∃ p b : Credential, dp.isOf p ∧ db.isOf b ∧ p.subject ≠ b.subject :=
  ⟨⟨dp.mdoc, ⟨"one traveler"⟩, dp.issuer, dp.deviceKey⟩,
    ⟨db.mdoc, ⟨"another traveler"⟩, db.issuer, db.deviceKey⟩,
    ⟨rfl, rfl, rfl, rfl, fun _ h => h⟩, ⟨rfl, rfl, rfl, rfl, fun _ h => h⟩, by simp⟩

/-- A photoid and a boarding pass about the same traveler, each accepted on
its own, are accepted together.

Not proven: it fails when names are compared, as in the credential data
model, and when device keys are compared and one traveler's credentials were
issued to two devices.  The example {lit}`twoDevicesOneTraveler` shows a
traveler with a photoid on a phone and a boarding pass on a tablet, refused
under the reading that compares device keys.

Open question for the business.  If the device key is what ties the two
credentials together, a traveler must hold both in one wallet on one device,
and both issuers must issue to the same key.  Does One ID require a photoid
and a boarding pass to be issued to the same device key, and what does a
traveler do who holds them on two devices? -/
@[open_question, checks "OID-207.3"]
theorem same_traveler_pair_accepted (r : AcceptanceReading) (e : ExpiryReading) (x : IsoTranscripts)
    (trusted : List Issuer) (pr : PairReading) (x792 : Resolution792) (q : Request)
    (dp db : Presented) (now : Instant) (p b : Credential) (hp : dp.isOf p) (hb : db.isOf b)
    (hs : p.subject = b.subject) (hd : dp.mdoc.docType = photoidDocType)
    (hbd : db.mdoc.docType = boardingPassDocType)
    (h : refusals r e x trusted q ⟨[dp, db]⟩ now = []) :
    pairRefusals r e x trusted pr x792 q dp db now = [] := by
  sorry

/-- Under the reading that nothing is compared, a photoid and a boarding pass
each accepted on its own are accepted together. -/
theorem same_traveler_pair_accepted_of_notChecked (r : AcceptanceReading) (e : ExpiryReading)
    (x : IsoTranscripts) (trusted : List Issuer) (pr : PairReading) (x792 : Resolution792) (q : Request)
    (dp db : Presented) (now : Instant) (hc : pr.content = .notChecked) (hk : pr.sameDeviceKey = false)
    (hd : dp.mdoc.docType = photoidDocType) (hbd : db.mdoc.docType = boardingPassDocType)
    (h : refusals r e x trusted q ⟨[dp, db]⟩ now = []) :
    pairRefusals r e x trusted pr x792 q dp db now = [] := by
  simp [pairRefusals, h, hd, hbd, pairMatch, hc, hk, travelerMatch]

end Rules.OneId
