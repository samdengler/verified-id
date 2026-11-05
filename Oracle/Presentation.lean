import Oracle.Handle
import Rules.OneId.PresentationExamples

set_option doc.verso false

/-!
# Test oracle: presentations

The presentation rules of §4.2 behind the same JSON interface as the
credential checks (`Oracle/Handle.lean`).  `handleAny` answers both kinds.

Keys, nonces, origins, issuers and certificates are symbolic, as in the model:
`{"name": "phone"}`, `{"value": "nonce 1", "entropyBytes": 16}`,
`{"value": "https://checkin.example"}`.  A session transcript is
`{"handover": {"origin", "nonce", "encryptionKey"}}` in the OpenID4VP profile
or `{"iso": "..."}` in the two ISO profiles.  The ISO transcripts are
functions in the model (`IsoTranscripts`), so a request names one of the two
invented stand-ins of `Rules/OneId/PresentationExamples.lean` under
`isoTranscripts`.

The reading points `refusals` and `pairRefusals` read depend on the profile of
the request under `request`: a relying party in the mdoc profile, for
instance, reads none of the points that apply to proximity.
`lake exe oneid-facts` checks each list against the definitions.
-/

open Lean Rules.Core Rules.OneId

namespace Oracle

/-! ## The model's types as JSON -/

deriving instance ToJson, FromJson for Key, Nonce, Origin, Issuer, ElementRef, Profile, Traveler

/-- A session transcript is an object with one key, the name of its
constructor. -/
instance : ToJson SessionTranscript where
  toJson
    | .handover origin nonce encryptionKey =>
      Json.mkObj [("handover", Json.mkObj [("origin", toJson origin), ("nonce", toJson nonce),
        ("encryptionKey", toJson encryptionKey)])]
    | .iso value => Json.mkObj [("iso", toJson value)]

instance : FromJson SessionTranscript where
  fromJson? j := do
    let obj ← j.getObj?
    match obj.toList with
    | [("handover", h)] =>
      return .handover (← h.getObjValAs? Origin "origin") (← h.getObjValAs? Nonce "nonce")
        (← h.getObjValAs? Key "encryptionKey")
    | [("iso", v)] => .iso <$> fromJson? v
    | _ => throw "a session transcript is an object with one key: handover or iso"

deriving instance ToJson, FromJson for DeviceSignature, Credential, Presented, Response, Request, Consent,
  ConsentReading, OpenId4Vp.Certificate, OpenId4Vp.CredentialQuery, OpenId4Vp.AuthorizationRequest,
  MdocProfile.DeviceRequest, Proximity.Retrieval, Proximity.Session

/-- A finding with its code and fields. -/
def coded (code : String) (fields : List (String × Json) := []) : Json :=
  Json.mkObj (("code", toJson code) :: fields)

def refusalJson : Refusal → Json
  | .untrustedIssuer issuer => coded "untrustedIssuer" [("issuer", toJson issuer)]
  | .issuerSignatureInvalid docType => coded "issuerSignatureInvalid" [("docType", toJson docType)]
  | .expired docType => coded "expired" [("docType", toJson docType)]
  | .noDeviceSignature docType => coded "noDeviceSignature" [("docType", toJson docType)]
  | .wrongDeviceKey docType => coded "wrongDeviceKey" [("docType", toJson docType)]
  | .otherRequest docType => coded "otherRequest" [("docType", toJson docType)]
  | .notRequested element => coded "notRequested" [("element", toJson element)]
  | .missing element => coded "missing" [("element", toJson element)]

def pairRefusalJson : PairRefusal → Json
  | .refused reason => coded "refused" [("reason", refusalJson reason)]
  | .notAPhotoid docType => coded "notAPhotoid" [("docType", toJson docType)]
  | .notABoardingPass docType => coded "notABoardingPass" [("docType", toJson docType)]
  | .notOneTraveler => coded "notOneTraveler"

def requestFindingJson : OpenId4Vp.RequestFinding → Json
  | .wrongProtocol found => coded "wrongProtocol" [("found", toJson found)]
  | .wrongResponseType found => coded "wrongResponseType" [("found", toJson found)]
  | .wrongResponseMode found => coded "wrongResponseMode" [("found", toJson found)]
  | .wrongClientIdPrefix found => coded "wrongClientIdPrefix" [("found", toJson found)]
  | .notSigned => coded "notSigned"
  | .signedWithAnotherKey => coded "signedWithAnotherKey"
  | .noExpectedOrigins => coded "noExpectedOrigins"
  | .noEncryptionKey => coded "noEncryptionKey"
  | .wrongFormat docType => coded "wrongFormat" [("docType", toJson docType)]
  | .noNonce => coded "noNonce"
  | .noState => coded "noState"

def walletFindingJson : OpenId4Vp.WalletFinding → Json
  | .malformed => coded "malformed"
  | .originNotExpected origin => coded "originNotExpected" [("origin", toJson origin)]
  | .badSignature => coded "badSignature"
  | .untrustedVerifier certificate => coded "untrustedVerifier" [("certificate", toJson certificate)]

def reuseFindingJson : OpenId4Vp.ReuseFinding → Json
  | .nonceReused => coded "nonceReused"
  | .encryptionKeyReused => coded "encryptionKeyReused"

def tokenFindingJson : OpenId4Vp.TokenFinding → Json
  | .severalMdocs count => coded "severalMdocs" [("count", toJson count)]

def mdocRequestFindingJson : MdocProfile.RequestFinding → Json
  | .wrongProtocol found => coded "wrongProtocol" [("found", toJson found)]
  | .wrongEncryptionProtocol found => coded "wrongEncryptionProtocol" [("found", toJson found)]
  | .noNonce => coded "noNonce"
  | .weakNonce entropyBytes => coded "weakNonce" [("entropyBytes", toJson entropyBytes)]
  | .noRecipientKey => coded "noRecipientKey"

def sessionFindingJson : Proximity.SessionFinding → Json
  | .serverRetrieval => coded "serverRetrieval"
  | .readerKeyReused => coded "readerKeyReused"
  | .deviceKeyReused => coded "deviceKeyReused"

/-- The answer of a rule that lists findings of some kind. -/
def listResult {α : Type} (f : α → Json) (xs : List α) : Json :=
  Json.mkObj [("result", Json.arr (xs.map f).toArray)]

/-- The answer of a rule that gives a value. -/
def valueResult {α : Type} [ToJson α] (a : α) : Json := Json.mkObj [("result", toJson a)]

/-! ## Readings as JSON -/

def consentPoints (c : ConsentReading) : List (String × Json) := [("ConsentReading", toJson c)]

def acceptancePoints (r : AcceptanceReading) : List (String × Json) :=
  [("AcceptanceReading.extrasRefusedInMdocProfile", toJson r.extrasRefusedInMdocProfile),
   ("AcceptanceReading.extrasRefusedInOpenId4Vp", toJson r.extrasRefusedInOpenId4Vp),
   ("AcceptanceReading.extrasRefusedInProximity", toJson r.extrasRefusedInProximity),
   ("AcceptanceReading.missingRefusedInMdocProfile", toJson r.missingRefusedInMdocProfile),
   ("AcceptanceReading.missingRefusedInProximity", toJson r.missingRefusedInProximity),
   ("AcceptanceReading.validityCheckedInOpenId4Vp", toJson r.validityCheckedInOpenId4Vp),
   ("AcceptanceReading.validityCheckedInProximity", toJson r.validityCheckedInProximity),
   ("AcceptanceReading.proximityRebuildsTranscript", toJson r.proximityRebuildsTranscript)]

def requestReadingPoints (r : OpenId4Vp.RequestReading) : List (String × Json) :=
  [("OpenId4Vp.RequestReading.stateRequired", toJson r.stateRequired)]

def walletReadingPoints (w : OpenId4Vp.WalletReading) : List (String × Json) :=
  [("OpenId4Vp.WalletReading.signatureChecked", toJson w.signatureChecked),
   ("OpenId4Vp.WalletReading.verifierListChecked", toJson w.verifierListChecked)]

def pairPoints (pr : PairReading) : List (String × Json) :=
  [("PairReading.content", toJson pr.content), ("PairReading.sameDeviceKey", toJson pr.sameDeviceKey)]

def acceptanceReadingOf (r : Json) : Except String AcceptanceReading := do
  let d : AcceptanceReading := default
  return {
    extrasRefusedInMdocProfile :=
      ← boolAt r "AcceptanceReading.extrasRefusedInMdocProfile" d.extrasRefusedInMdocProfile,
    extrasRefusedInOpenId4Vp := ← boolAt r "AcceptanceReading.extrasRefusedInOpenId4Vp" d.extrasRefusedInOpenId4Vp,
    extrasRefusedInProximity := ← boolAt r "AcceptanceReading.extrasRefusedInProximity" d.extrasRefusedInProximity,
    missingRefusedInMdocProfile :=
      ← boolAt r "AcceptanceReading.missingRefusedInMdocProfile" d.missingRefusedInMdocProfile,
    missingRefusedInProximity :=
      ← boolAt r "AcceptanceReading.missingRefusedInProximity" d.missingRefusedInProximity,
    validityCheckedInOpenId4Vp :=
      ← boolAt r "AcceptanceReading.validityCheckedInOpenId4Vp" d.validityCheckedInOpenId4Vp,
    validityCheckedInProximity :=
      ← boolAt r "AcceptanceReading.validityCheckedInProximity" d.validityCheckedInProximity,
    proximityRebuildsTranscript :=
      ← boolAt r "AcceptanceReading.proximityRebuildsTranscript" d.proximityRebuildsTranscript }

def walletReadingOf (r : Json) : Except String OpenId4Vp.WalletReading := do
  return {
    signatureChecked := ← r.getObjValAs? Bool "OpenId4Vp.WalletReading.signatureChecked",
    verifierListChecked := ← r.getObjValAs? Bool "OpenId4Vp.WalletReading.verifierListChecked" }

def pairReadingOf (r : Json) : Except String PairReading := do
  return { content := ← r.getObjValAs? MatchReading "PairReading.content",
           sameDeviceKey := ← r.getObjValAs? Bool "PairReading.sameDeviceKey" }

/-! ## The rules -/

def profiles : List Profile := [.mdocOverDcApi, .openid4vp, .proximity]

def profileName (p : Profile) : String := ((toJson p).getStr?.toOption).getD ""

/-- The points of an acceptance reading that a relying party reads in a
profile. -/
def acceptancePointsIn : Profile → List String
  | .mdocOverDcApi => ["AcceptanceReading.extrasRefusedInMdocProfile", "AcceptanceReading.missingRefusedInMdocProfile"]
  | .openid4vp => ["AcceptanceReading.extrasRefusedInOpenId4Vp", "AcceptanceReading.validityCheckedInOpenId4Vp"]
  | .proximity =>
    ["AcceptanceReading.extrasRefusedInProximity", "AcceptanceReading.missingRefusedInProximity",
     "AcceptanceReading.validityCheckedInProximity", "AcceptanceReading.proximityRebuildsTranscript"]

/-- Each presentation rule: its name in a request, its Lean function, and for
each profile it applies in, the reading points it reads there. -/
def presentationRules : List (String × Name × List (String × List String)) :=
  let every (points : List String) := profiles.map fun p => (profileName p, points)
  let only (p : Profile) (points : List String) := [(profileName p, points)]
  let deciding (extra : List String) :=
    profiles.map fun p => (profileName p, acceptancePointsIn p ++ "ExpiryReading.validAtEnd" :: extra)
  [("Wallet.respond", ``Wallet.respond, every ["ConsentReading"]),
   ("refusals", ``refusals, deciding []),
   ("pairRefusals", ``pairRefusals, deciding ["PairReading.content", "PairReading.sameDeviceKey"]),
   ("OpenId4Vp.requestFindings", ``OpenId4Vp.requestFindings,
     only .openid4vp ["OpenId4Vp.RequestReading.stateRequired"]),
   ("OpenId4Vp.reuseFindings", ``OpenId4Vp.reuseFindings, only .openid4vp []),
   ("OpenId4Vp.walletFindings", ``OpenId4Vp.walletFindings,
     only .openid4vp ["OpenId4Vp.RequestReading.stateRequired", "OpenId4Vp.WalletReading.signatureChecked",
       "OpenId4Vp.WalletReading.verifierListChecked"]),
   ("OpenId4Vp.transcript", ``OpenId4Vp.transcript, only .openid4vp []),
   ("OpenId4Vp.tokenFindings", ``OpenId4Vp.tokenFindings, only .openid4vp []),
   ("MdocProfile.requestFindings", ``MdocProfile.requestFindings, only .mdocOverDcApi []),
   ("Proximity.sessionFindings", ``Proximity.sessionFindings, only .proximity [])]

/-- The reading points a presentation rule reads, in the profile of its
request where they depend on it. -/
def presentationPointsFor (rule : String) (profile : Option Profile) : Except String (List String) :=
  match presentationRules.find? (·.1 == rule) with
  | none => throw s!"unknown rule {rule}"
  | some (_, _, entries) =>
    match entries with
    | [] => pure []
    | (_, first) :: rest =>
      if rest.all (·.2 == first) then pure first
      else match profile with
        | some p => match entries.lookup (profileName p) with
          | some ps => pure ps
          | none => throw s!"{rule} does not apply in the profile {profileName p}"
        | none => throw s!"{rule} reads different reading points in each profile, so it needs a request"

/-- The invented stand-ins for the ISO session transcripts a request may
name. -/
def isoFormats : List (String × IsoTranscripts) :=
  [("exampleIsoTranscripts", exampleIsoTranscripts), ("transcriptsWithoutNonce", transcriptsWithoutNonce)]

def isoTranscriptsOf (req : Json) : Except String IsoTranscripts := do
  let n ← req.getObjValAs? String "isoTranscripts"
  match isoFormats.lookup n with
  | some x => pure x
  | none => throw s!"unknown ISO transcripts {n}; the invented stand-ins are {", ".intercalate (isoFormats.map (·.1))}"

/-- A request for a presentation rule, with its reading cut to the points the
rule reads in a profile. -/
def presentationRequest (rule : String) (profile : Option Profile) (reading : List (String × Json))
    (inputs : List (String × Json)) : Json :=
  let points := (presentationPointsFor rule profile).toOption.getD []
  Json.mkObj ([("rule", toJson rule), ("reading", Json.mkObj (reading.filter (points.contains ·.1)))] ++ inputs)

/-- The reading of a request: every point the rule reads and no other. -/
def readingWith (rule : String) (points : List String) (req : Json) : Except String Json := do
  let r ← req.getObjVal? "reading"
  let keys := (← r.getObj?).toList.map (·.1)
  if let some k := keys.find? (!points.contains ·) then throw s!"{rule} does not read {k} here"
  if let some p := points.find? (!keys.contains ·) then throw s!"{rule} needs the reading point {p}"
  return r

/-- The model's answer to a request for a presentation rule. -/
def respondPresentation (req : Json) : Except String Json := do
  let rule ← req.getObjValAs? String "rule"
  let profile ← match req.getObjVal? "request" with
    | .ok q => some <$> q.getObjValAs? Profile "profile"
    | .error _ => pure none
  let r ← readingWith rule (← presentationPointsFor rule profile) req
  match rule with
  | "Wallet.respond" =>
    let c ← r.getObjValAs? ConsentReading "ConsentReading"
    let x ← isoTranscriptsOf req
    let held ← req.getObjValAs? (List Credential) "held"
    let seen ← req.getObjValAs? Request "seen"
    let consent ← req.getObjValAs? Consent "consent"
    return valueResult (Wallet.respond c x held seen consent)
  | "refusals" =>
    let a ← acceptanceReadingOf r
    let validAtEnd ← r.getObjValAs? Bool "ExpiryReading.validAtEnd"
    let x ← isoTranscriptsOf req
    let trusted ← req.getObjValAs? (List Issuer) "trustedIssuers"
    let q ← req.getObjValAs? Request "request"
    let response ← req.getObjValAs? Response "response"
    let now ← req.getObjValAs? Instant "now"
    return listResult refusalJson (refusals a ⟨validAtEnd⟩ x trusted q response now)
  | "pairRefusals" =>
    let a ← acceptanceReadingOf r
    let validAtEnd ← r.getObjValAs? Bool "ExpiryReading.validAtEnd"
    let pr ← pairReadingOf r
    let x ← isoTranscriptsOf req
    let trusted ← req.getObjValAs? (List Issuer) "trustedIssuers"
    let x792 ← formatOf req
    let q ← req.getObjValAs? Request "request"
    let photoid ← req.getObjValAs? Presented "photoid"
    let boardingPass ← req.getObjValAs? Presented "boardingPass"
    let now ← req.getObjValAs? Instant "now"
    return listResult pairRefusalJson (pairRefusals a ⟨validAtEnd⟩ x trusted pr x792 q photoid boardingPass now)
  | "OpenId4Vp.requestFindings" =>
    let stateRequired ← r.getObjValAs? Bool "OpenId4Vp.RequestReading.stateRequired"
    let a ← req.getObjValAs? OpenId4Vp.AuthorizationRequest "authorization"
    return listResult requestFindingJson (OpenId4Vp.requestFindings ⟨stateRequired⟩ a)
  | "OpenId4Vp.reuseFindings" =>
    let requests ← req.getObjValAs? (List OpenId4Vp.AuthorizationRequest) "authorizations"
    return listResult reuseFindingJson (OpenId4Vp.reuseFindings requests)
  | "OpenId4Vp.walletFindings" =>
    let stateRequired ← r.getObjValAs? Bool "OpenId4Vp.RequestReading.stateRequired"
    let w ← walletReadingOf r
    let trustedVerifiers ← req.getObjValAs? (List OpenId4Vp.Certificate) "trustedVerifiers"
    let seenOrigin ← req.getObjValAs? Origin "seenOrigin"
    let a ← req.getObjValAs? OpenId4Vp.AuthorizationRequest "authorization"
    return listResult walletFindingJson (OpenId4Vp.walletFindings ⟨stateRequired⟩ w trustedVerifiers seenOrigin a)
  | "OpenId4Vp.transcript" =>
    let origin ← req.getObjValAs? Origin "origin"
    let nonce ← req.getObjValAs? Nonce "nonce"
    let encryptionKey ← req.getObjValAs? Key "encryptionKey"
    return valueResult (OpenId4Vp.transcript origin nonce encryptionKey)
  | "OpenId4Vp.tokenFindings" =>
    let token ← req.getObjValAs? (List (List Presented)) "token"
    return listResult tokenFindingJson (OpenId4Vp.tokenFindings token)
  | "MdocProfile.requestFindings" =>
    let d ← req.getObjValAs? MdocProfile.DeviceRequest "deviceRequest"
    return listResult mdocRequestFindingJson (MdocProfile.requestFindings d)
  | "Proximity.sessionFindings" =>
    let sessions ← req.getObjValAs? (List Proximity.Session) "sessions"
    return listResult sessionFindingJson (Proximity.sessionFindings sessions)
  | other => throw s!"unknown rule {other}"

/-- The model's answer to any request, a credential check or a presentation
rule. -/
def respondAny (req : Json) : Except String Json := do
  let rule ← req.getObjValAs? String "rule"
  if presentationRules.any (·.1 == rule) then respondPresentation req
  else if rules.any (·.1 == rule) then respond req
  else throw s!"unknown rule {rule}; the rules are {", ".intercalate ((rules.map (·.1)) ++ presentationRules.map (·.1))}"

/-- One response line for one request line. -/
def handleAny (line : String) : String :=
  match Json.parse line >>= respondAny with
  | .ok j => j.compress
  | .error e => (Json.mkObj [("failure", toJson e)]).compress

/-! ## Requests -/

def walletRespondRequest (c : ConsentReading) (transcripts : String) (held : List Credential) (seen : Request)
    (consent : Consent) : Json :=
  presentationRequest "Wallet.respond" none (consentPoints c)
    [("isoTranscripts", toJson transcripts), ("held", toJson held), ("seen", toJson seen),
     ("consent", toJson consent)]

def refusalsRequest (a : AcceptanceReading) (e : ExpiryReading) (transcripts : String) (trusted : List Issuer)
    (q : Request) (response : Response) (now : Instant) : Json :=
  presentationRequest "refusals" (some q.profile) (acceptancePoints a ++ expiryPoints e)
    [("isoTranscripts", toJson transcripts), ("trustedIssuers", toJson trusted), ("request", toJson q),
     ("response", toJson response), ("now", toJson now)]

def pairRefusalsRequest (a : AcceptanceReading) (e : ExpiryReading) (pr : PairReading) (transcripts : String)
    (trusted : List Issuer) (format : String) (q : Request) (photoid boardingPass : Presented) (now : Instant) :
    Json :=
  presentationRequest "pairRefusals" (some q.profile) (acceptancePoints a ++ expiryPoints e ++ pairPoints pr)
    [("isoTranscripts", toJson transcripts), ("trustedIssuers", toJson trusted), ("resolution792", toJson format),
     ("request", toJson q), ("photoid", toJson photoid), ("boardingPass", toJson boardingPass),
     ("now", toJson now)]

def openId4VpRequestRequest (r : OpenId4Vp.RequestReading) (a : OpenId4Vp.AuthorizationRequest) : Json :=
  presentationRequest "OpenId4Vp.requestFindings" none (requestReadingPoints r) [("authorization", toJson a)]

def reuseRequest (requests : List OpenId4Vp.AuthorizationRequest) : Json :=
  presentationRequest "OpenId4Vp.reuseFindings" none [] [("authorizations", toJson requests)]

def walletFindingsRequest (r : OpenId4Vp.RequestReading) (w : OpenId4Vp.WalletReading)
    (trustedVerifiers : List OpenId4Vp.Certificate) (seenOrigin : Origin) (a : OpenId4Vp.AuthorizationRequest) :
    Json :=
  presentationRequest "OpenId4Vp.walletFindings" none (requestReadingPoints r ++ walletReadingPoints w)
    [("trustedVerifiers", toJson trustedVerifiers), ("seenOrigin", toJson seenOrigin), ("authorization", toJson a)]

def transcriptRequest (origin : Origin) (nonce : Nonce) (encryptionKey : Key) : Json :=
  presentationRequest "OpenId4Vp.transcript" none []
    [("origin", toJson origin), ("nonce", toJson nonce), ("encryptionKey", toJson encryptionKey)]

def tokenRequest (token : OpenId4Vp.VpToken) : Json :=
  presentationRequest "OpenId4Vp.tokenFindings" none [] [("token", toJson token)]

def deviceRequestRequest (d : MdocProfile.DeviceRequest) : Json :=
  presentationRequest "MdocProfile.requestFindings" none [] [("deviceRequest", toJson d)]

def sessionsRequest (sessions : List Proximity.Session) : Json :=
  presentationRequest "Proximity.sessionFindings" none [] [("sessions", toJson sessions)]

end Oracle
