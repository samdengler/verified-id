import Exports.Decisions
import Exports.PresentationScenarios
import Std.Data.HashSet

set_option doc.verso false

/-!
# Presentation readings and decisions

The reading points of the presentation rules, and every presentation scenario
evaluated by the model's functions under every combination of the settings
of the points each rule reads in the scenario's profile.  Boundary vectors
follow for the rules no scenario gives a finding: nonces and keys shared by
two requests, a token with two mdocs in one device response, a malformed mdoc
profile request, and proximity sessions that break each rule.

`presentationDecisionLines` applies the gates of the credential decisions to
this set: the default presentation of each profile may not depend on a
reading, a scenario must agree with the example it reproduces, names are
unique, and the oracle answers every request as the model's functions do.
-/

open Lean Rules.Core Rules.OneId Oracle

namespace Exports

/-! ## Settings -/

def consentReadings : List ConsentReading := [.perElement, .wholeCredential]

def acceptanceReadings : List AcceptanceReading :=
  bools.flatMap fun a => bools.flatMap fun b => bools.flatMap fun c => bools.flatMap fun d =>
  bools.flatMap fun e => bools.flatMap fun f => bools.flatMap fun g => bools.map fun h =>
    ⟨a, b, c, d, e, f, g, h⟩

def requestReadings : List OpenId4Vp.RequestReading := bools.map (⟨·⟩)

def walletReadings : List OpenId4Vp.WalletReading := bools.flatMap fun a => bools.map fun b => ⟨a, b⟩

def pairReadings : List PairReading := matchReadings.flatMap fun c => bools.map fun k => ⟨c, k⟩

def allPresentationPoints : List (List (String × Json)) :=
  consentReadings.map consentPoints ++ acceptanceReadings.map acceptancePoints ++ expiryReadings.map expiryPoints ++
    requestReadings.map requestReadingPoints ++ walletReadings.map walletReadingPoints ++ pairReadings.map pairPoints

def presentationSettingsOf (id : String) : List Json := (allPresentationPoints.filterMap (·.lookup id)).eraseDups

/-! ## The points -/

def presentationPoints : List Point :=
  [{ lean := ``ConsentReading, settingsType := some ``ConsentReading,
     questions := [``partial_consent_withholds_credential] },
   { lean := ``AcceptanceReading.extrasRefusedInMdocProfile, questions := [``accepted_holds_only_requested] },
   { lean := ``AcceptanceReading.extrasRefusedInOpenId4Vp, questions := [``accepted_holds_only_requested] },
   { lean := ``AcceptanceReading.extrasRefusedInProximity, questions := [``accepted_holds_only_requested] },
   { lean := ``AcceptanceReading.missingRefusedInMdocProfile, questions := [``accepted_holds_every_requested] },
   { lean := ``AcceptanceReading.missingRefusedInProximity, questions := [``accepted_holds_every_requested] },
   { lean := ``AcceptanceReading.validityCheckedInOpenId4Vp, questions := [``accepted_not_expired] },
   { lean := ``AcceptanceReading.validityCheckedInProximity, questions := [``accepted_not_expired] },
   { lean := ``AcceptanceReading.proximityRebuildsTranscript, questions := [``accepted_answers_this_request] },
   { lean := ``ExpiryReading.validAtEnd, questions := [``valid_at_validUntil] },
   { lean := ``OpenId4Vp.RequestReading.stateRequired, questions := [``OpenId4Vp.accepted_request_has_state] },
   { lean := ``OpenId4Vp.WalletReading.signatureChecked, questions := [``OpenId4Vp.answered_request_signed] },
   { lean := ``OpenId4Vp.WalletReading.verifierListChecked,
     questions := [``OpenId4Vp.answered_by_trusted_verifier] },
   { lean := ``PairReading.content, settingsType := some ``MatchReading,
     questions := [``accepted_pair_same_traveler, ``same_traveler_pair_accepted] },
   { lean := ``PairReading.sameDeviceKey, questions := [``accepted_pair_same_traveler, ``same_traveler_pair_accepted] }]

def presentationPointTable : List (String × Name × Option Name × List Json × List Name) :=
  presentationPoints.map fun p => (p.id, p.lean, p.settingsType, presentationSettingsOf p.id, p.questions)

def presentationStructures : List Name :=
  [``AcceptanceReading, ``ExpiryReading, ``OpenId4Vp.RequestReading, ``OpenId4Vp.WalletReading, ``PairReading]

/-- The four functions through which the decisions read an acceptance
reading.  `lake exe oneid-facts` checks that `refusals` and `pairRefusals`
read it through nothing else. -/
def acceptanceDispatchers : List Name :=
  [``AcceptanceReading.checksValidity, ``AcceptanceReading.checksTranscript, ``AcceptanceReading.refusesExtras,
   ``AcceptanceReading.refusesMissing]

/-- An acceptance reading with one point flipped, through the oracle's
encoding. -/
def flipped (id : String) (r : AcceptanceReading) : AcceptanceReading :=
  let obj := (acceptancePoints r).map fun (k, v) => if k == id then (k, toJson !(v.getBool?.toOption.getD false)) else (k, v)
  (acceptanceReadingOf (Json.mkObj obj)).toOption.getD r

/-- Whether a point of the acceptance reading changes what a relying party
does in a profile, for some setting of the others. -/
def influences (p : Profile) (id : String) : Bool :=
  acceptanceReadings.any fun r =>
    let r' := flipped id r
    r.checksValidity p != r'.checksValidity p || r.checksTranscript p != r'.checksTranscript p ||
      r.refusesExtras p != r'.refusesExtras p || r.refusesMissing p != r'.refusesMissing p

/-- Where the points of the acceptance reading that change something in a
profile differ from the ones the oracle lists for it. -/
def acceptanceInfluenceErrors : List String :=
  let ids := (acceptancePoints default).map (·.1)
  profiles.filterMap fun p =>
    let read := ids.filter (influences p)
    let listed := acceptancePointsIn p
    if read.all listed.contains && listed.all read.contains then none
    else some s!"in the profile {profileName p} the acceptance reading points {read} change a decision, \
      and Oracle.acceptancePointsIn lists {listed}"

/-! ## Decisions -/

/-- The first of each kind among some settings, by their points that a list
names. -/
def distinctOn {α : Type} (points : List String) (encode : α → List (String × Json)) (xs : List α) : List α :=
  (xs.foldl (fun (seen, acc) a =>
    let k := (Json.mkObj ((encode a).filter (points.contains ·.1))).compress
    if seen.contains k then (seen, acc) else (seen.insert k, acc.push a))
    ((∅ : Std.HashSet String), (#[] : Array α))).2.toList

/-- The points a presentation rule reads in a profile. -/
def pointsIn (rule : String) (profile : Profile) : List String :=
  (presentationPointsFor rule (some profile)).toOption.getD []

/-- Every decision for one presentation scenario. -/
def presentationDecisionsOf (s : PresentationScenario) : List Decision :=
  let d (case : String) (req resp : Json) : Decision := ⟨s!"{s.id} {case}", some s.id, req, resp⟩
  let x := s.iso
  let wallet : List Decision := match s.seen, s.consent with
    | some seen, some c =>
      consentReadings.map fun cr =>
        d "Wallet.respond" (walletRespondRequest cr s.transcripts s.held seen c)
          (valueResult (Wallet.respond cr x s.held seen c))
    | _, _ => []
  let decided : List Decision := match s.request, s.response with
    | some q, some resp =>
      let deciding := acceptanceReadings.flatMap fun a => expiryReadings.map (a, ·)
      (distinctOn (pointsIn "refusals" q.profile) (fun (a, e) => acceptancePoints a ++ expiryPoints e) deciding).map
        (fun (a, e) =>
          d "refusals" (refusalsRequest a e s.transcripts s.trusted q resp s.checkedAt)
            (listResult refusalJson (refusals a e x s.trusted q resp s.checkedAt))) ++
      (match pairOf resp with
       | none => []
       | some (dp, db) =>
         let pairing := deciding.flatMap fun (a, e) => pairReadings.map (a, e, ·)
         (distinctOn (pointsIn "pairRefusals" q.profile)
            (fun (a, e, pr) => acceptancePoints a ++ expiryPoints e ++ pairPoints pr) pairing).map fun (a, e, pr) =>
           d "pairRefusals" (pairRefusalsRequest a e pr s.transcripts s.trusted format q dp db s.checkedAt)
             (listResult pairRefusalJson (pairRefusals a e x s.trusted pr exampleResolution792 q dp db s.checkedAt))) ++
      (if q.profile == .openid4vp then
        [d "OpenId4Vp.transcript" (transcriptRequest q.origin q.nonce q.encryptionKey)
           (valueResult (OpenId4Vp.transcript q.origin q.nonce q.encryptionKey)),
         d "OpenId4Vp.tokenFindings" (tokenRequest (OpenId4Vp.deviceResponses resp))
           (listResult tokenFindingJson (OpenId4Vp.tokenFindings (OpenId4Vp.deviceResponses resp)))]
       else [])
    | _, _ => []
  let travelling : List Decision := match s.authorization with
    | none => []
    | some a =>
      requestReadings.map (fun r =>
        d "OpenId4Vp.requestFindings" (openId4VpRequestRequest r a)
          (listResult requestFindingJson (OpenId4Vp.requestFindings r a))) ++
      (match s.seenOrigin with
       | none => []
       | some o =>
         (requestReadings.flatMap fun r => walletReadings.map (r, ·)).map fun (r, w) =>
           d "OpenId4Vp.walletFindings" (walletFindingsRequest r w s.trustedVerifiers o a)
             (listResult walletFindingJson (OpenId4Vp.walletFindings r w s.trustedVerifiers o a)))
  let mdoc : List Decision := match s.deviceRequest with
    | none => []
    | some dr =>
      [d "MdocProfile.requestFindings" (deviceRequestRequest dr)
        (listResult mdocRequestFindingJson (MdocProfile.requestFindings dr))]
  let proximity : List Decision :=
    if s.sessions.isEmpty then []
    else [d "Proximity.sessionFindings" (sessionsRequest s.sessions)
      (listResult sessionFindingJson (Proximity.sessionFindings s.sessions))]
  wallet ++ decided ++ travelling ++ mdoc ++ proximity

/-- Requests no scenario gives a finding, with the model's answers. -/
def presentationBoundaryDecisions : List Decision :=
  let b (case : String) (req resp : Json) : Decision := ⟨s!"boundary {case}", none, req, resp⟩
  let a1 := honestAuthorization
  let a2 := { a1 with nonce := some ⟨"nonce 2", 16⟩, encryptionKey := some ⟨"key for nonce 2"⟩ }
  let sameNonce := { a2 with nonce := a1.nonce }
  let sameKey := { a2 with encryptionKey := a1.encryptionKey }
  let reuse (case : String) (rs : List OpenId4Vp.AuthorizationRequest) :=
    b s!"OpenId4Vp.reuseFindings {case}" (reuseRequest rs) (listResult reuseFindingJson (OpenId4Vp.reuseFindings rs))
  let documents := ((defaultOpenId4Vp.response.map (·.documents)).getD [])
  let token : OpenId4Vp.VpToken := [documents]
  let weak : MdocProfile.DeviceRequest :=
    { honestDeviceRequest with protocol := OpenId4Vp.protocolValue, nonce := some ⟨"nonce 1", 8⟩, recipientKey := none }
  let later : Proximity.Session := ⟨⟨"engagement 2"⟩, ⟨"reader key 2"⟩, .nfc⟩
  let sessions (case : String) (ss : List Proximity.Session) :=
    b s!"Proximity.sessionFindings {case}" (sessionsRequest ss) (listResult sessionFindingJson (Proximity.sessionFindings ss))
  [reuse "two fresh requests" [a1, a2], reuse "two requests with one nonce" [a1, sameNonce],
   reuse "two requests with one encryption key" [a1, sameKey],
   b "OpenId4Vp.tokenFindings two mdocs in one device response" (tokenRequest token)
     (listResult tokenFindingJson (OpenId4Vp.tokenFindings token)),
   b "MdocProfile.requestFindings a weak request" (deviceRequestRequest weak)
     (listResult mdocRequestFindingJson (MdocProfile.requestFindings weak)),
   sessions "retrieval from a server" [{ gateSession with retrieval := .server }],
   sessions "one reader key in two sessions" [gateSession, { later with readerKey := gateSession.readerKey }],
   sessions "one engagement key in two sessions" [gateSession, { later with deviceKey := gateSession.deviceKey }]]

def presentationDecisions : List Decision :=
  presentationScenarios.flatMap presentationDecisionsOf ++ presentationBoundaryDecisions

/-- The presentation decisions as JSON lines, once every check passes. -/
def presentationDecisionLines : Except String (List String) := do
  for p in profiles do
    match presentationScenarios.filter (fun s => s.isDefault && s.profile == p) with
    | [s] => readingFree (presentationDecisionsOf s)
    | ss => throw s!"the profile {profileName p} must have one default presentation, and has {ss.length}"
  for s in presentationScenarios do presentationAgrees s
  if let some id := firstRepeat (presentationScenarios.map (·.id)) then throw s!"two presentation scenarios have the id {id}"
  if let some n := firstRepeat (presentationDecisions.map (·.name)) then throw s!"two presentation decisions have the name {n}"
  for d in presentationDecisions do
    match respondAny d.request with
    | .ok r =>
      if r != d.response then
        throw s!"the oracle answers {d.name} with {r.compress}, and the model's functions with {d.response.compress}"
    | .error e => throw s!"the oracle cannot read the request of {d.name}: {e}"
  return presentationDecisions.map (·.json.compress)

def presentationScenariosJson : Json :=
  Json.mkObj [("generatedBy", toJson "lake exe oneid-facts"), ("standIns", presentationStandInsJson),
    ("scenarios", Json.arr (presentationScenarios.map (·.json)).toArray)]

def presentationScenarioExamples : List (String × Name) :=
  presentationScenarios.filterMap fun s => s.reproduces.map (s.id, ·)

end Exports
