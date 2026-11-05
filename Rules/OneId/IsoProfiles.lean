import Rules.OneId.OpenId4Vp

/-!
# The two profiles that rest on ISO documents

The mdoc profile over the Digital Credentials API (§4.2.1.2) and the
proximity profile (§4.2.2) are defined by ISO/IEC 18013-5 and ISO/IEC TS
18013-7, which this project has not read.  This module holds the rules the
guide itself states for them.  What an ISO clause decides is a parameter, so
a guarantee proven here holds whatever the clause says.
-/

namespace Rules.OneId

open Rules.Core

/-- What the ISO documents decide about the session transcript of the two ISO
profiles: for a request, the value a device signs over.  ISO/IEC TS 18013-7
Annex C §C.5 defines it for the mdoc profile and ISO/IEC 18013-5 §9.1.5.1 for
proximity.  Neither was read, so the model does not know which parts of a
request a transcript depends on. -/
structure IsoTranscripts where
  /-- The transcript of a request in the mdoc profile. -/
  annexC : Request → SessionTranscript
  /-- The transcript of a proximity session. -/
  proximity : Request → SessionTranscript

/-- The session transcript a relying party expects a response to its request
to be signed over, in the request's profile. -/
def expectedTranscript (x : IsoTranscripts) (q : Request) : SessionTranscript :=
  match q.profile with
  | .openid4vp => OpenId4Vp.transcript q.origin q.nonce q.encryptionKey
  | .mdocOverDcApi => x.annexC q
  | .proximity => x.proximity q

namespace MdocProfile

/-- A request of the mdoc profile, as the guide's step 1 describes it: a
protocol value, encryption information that names its own protocol and
carries a nonce and the recipient's public key, and the data elements
wanted. -/
structure DeviceRequest where
  /-- The protocol value given to the Digital Credentials API. -/
  protocol : String
  /-- The protocol the encryption information names. -/
  encryptionProtocol : String
  /-- The nonce, if there is one. -/
  nonce : Option Nonce
  /-- The recipient's public key, if there is one. -/
  recipientKey : Option Key
  /-- The data elements requested. -/
  elements : List ElementRef
  deriving DecidableEq, Repr, Inhabited

/-- The protocol value of the mdoc profile (§4.2.1.2 step 1). -/
def protocolValue : String := "org-iso-mdoc"

/-- The value the encryption information must carry (§4.2.1.2 step 1). -/
def encryptionProtocolValue : String := "dcapi"

/-- The least entropy of the nonce, in bytes (§4.2.1.2 step 1). -/
def minimumNonceEntropy : Nat := 16

/-- A requirement a request of the mdoc profile does not meet. -/
inductive RequestFinding
  /-- The protocol value is not the one of the mdoc profile. -/
  | wrongProtocol (found : String)
  /-- The encryption information does not name the required protocol. -/
  | wrongEncryptionProtocol (found : String)
  /-- The request carries no nonce. -/
  | noNonce
  /-- The nonce has less entropy than required. -/
  | weakNonce (entropyBytes : Nat)
  /-- The request carries no recipient public key. -/
  | noRecipientKey
  deriving DecidableEq, Repr

/-- EARS: When a relying party makes a request in the mdoc profile, the
system shall accept the request only if it names the protocol and carries a
nonce of at least 16 bytes of entropy and the recipient's public key.

Story: As a wallet provider, I want every request of this profile to carry a
strong nonce and a key to answer to, so that a response can be encrypted to
the relying party and tied to its request.

Acceptance criteria:

* OID-206.1: If a request's protocol value or the protocol its encryption
  information names is not the one the guide requires, then the system shall
  reject it.
* OID-206.2: If a request carries no nonce, or a nonce of less than 16 bytes
  of entropy, then the system shall reject it.
* OID-206.3: If a request carries no recipient public key, then the system
  shall reject it.

The guide states these in §4.2.1.2 step 1 and gives the format of the request
to ISO/IEC TS 18013-7 Annex C §C.2, which was not read.  Reader
authentication is recommended there and is not checked by this rule.  The
entropy of a nonce is taken as given. -/
@[ears "OID-206", source "tig-4.2.1.2", assumes "x-18013-7-annex-c x-w3c-dc-api"]
def requestFindings (d : DeviceRequest) : List RequestFinding :=
  (if d.protocol = protocolValue then [] else [.wrongProtocol d.protocol]) ++
  (if d.encryptionProtocol = encryptionProtocolValue then []
    else [.wrongEncryptionProtocol d.encryptionProtocol]) ++
  (match d.nonce with
    | none => [.noNonce]
    | some n => if minimumNonceEntropy ≤ n.entropyBytes then [] else [.weakNonce n.entropyBytes]) ++
  (if d.recipientKey = none then [.noRecipientKey] else [])

/-- The request as the shared model sees it, for a relying party at an
origin.  A request with no nonce or no recipient key has no shared form. -/
def DeviceRequest.shared (d : DeviceRequest) (origin : Origin) : Option Request :=
  match d.nonce, d.recipientKey with
  | some nonce, some key =>
    some { profile := .mdocOverDcApi, origin, nonce, encryptionKey := key, engagementKey := none,
           elements := d.elements }
  | _, _ => none

end MdocProfile

namespace Proximity

/-- How a reader retrieves data in a proximity session.  The first three are
the methods the guide names for retrieval from the device; the last is
retrieval from a server, which the ISO standard also defines (§4.2.2
step 2). -/
inductive Retrieval
  /-- Bluetooth low energy. -/
  | bluetoothLowEnergy
  /-- Near field communication. -/
  | nfc
  /-- Wi-Fi Aware. -/
  | wifiAware
  /-- Retrieval from a server. -/
  | server
  deriving DecidableEq, Repr, Inhabited

/-- One proximity session between a device and a reader. -/
structure Session where
  /-- The public key the device made for this engagement (§4.2.2 step 1). -/
  deviceKey : Key
  /-- The public key the reader made for this engagement (§4.2.2 step 2). -/
  readerKey : Key
  /-- How the reader retrieves the data. -/
  retrieval : Retrieval
  deriving DecidableEq, Repr, Inhabited

/-- A requirement a list of proximity sessions does not meet. -/
inductive SessionFinding
  /-- A session retrieves data from a server. -/
  | serverRetrieval
  /-- A reader's key is used in more than one session. -/
  | readerKeyReused
  /-- A device's engagement key is used in more than one session. -/
  | deviceKeyReused
  deriving DecidableEq, Repr

/-- EARS: While a reader and a device are in a proximity session, the system
shall use keys made for that session and shall retrieve data from the device
only.

Story: As a passenger, I want every tap or scan at a touchpoint to start a
session of its own, so that what I present at one gate cannot be linked to or
reused at another.

Acceptance criteria:

* OID-301.1: If a session retrieves data from a server, then the system shall
  reject it.
* OID-301.2: If a reader's key is used in more than one session, then the
  system shall reject the sessions.
* OID-301.3: If a device's engagement key is used in more than one session,
  then the system shall reject the sessions.

The guide requires the device to make a key pair for each engagement and the
reader to make one before each engagement, and says server retrieval shall
not be used (§4.2.2 steps 1 and 2).  The structures and the derivation of
session keys are in ISO/IEC 18013-5, which was not read.  The rule looks at
the sessions of one deployment together, since a reused key shows only across
sessions.  The end of a session and the deletion of its data (§4.2.2 step 7)
are not modelled. -/
@[ears "OID-301", source "tig-4.2.2", assumes "x-18013-5-engagement x-18013-5-session"]
def sessionFindings (sessions : List Session) : List SessionFinding :=
  (if sessions.all (fun s => decide (s.retrieval ≠ .server)) then [] else [.serverRetrieval]) ++
  (if (sessions.map (·.readerKey)).Nodup then [] else [.readerKeyReused]) ++
  (if (sessions.map (·.deviceKey)).Nodup then [] else [.deviceKeyReused])

/-- A proximity request as the shared model sees it: the reader, the keys of
the session and the data elements the reader asks for.  The nonce is a fixed
empty value, since proximity has none in the guide. -/
def Session.shared (s : Session) (reader : Origin) (elements : List ElementRef) : Request :=
  { profile := .proximity, origin := reader, nonce := ⟨"", 0⟩, encryptionKey := s.readerKey,
    engagementKey := some s.deviceKey, elements }

end Proximity

end Rules.OneId
