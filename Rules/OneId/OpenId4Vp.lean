import Rules.OneId.Exchange

/-!
# The OpenID4VP profile

Remote presentation with OpenID for Verifiable Presentations 1.0 over the
Digital Credentials API, profiled by the OpenID4VC High Assurance
Interoperability Profile 1.0 (§4.2.1.3).  Both specifications are public and
were read; a statement about one of them here names its clause.  The device
response inside the token is an ISO structure, which this project has not
read.

This module holds what a request must carry, what a wallet checks before it
answers, and what a response is bound to.
-/

namespace Rules.OneId.OpenId4Vp

open Rules.Core

/-- A relying party's certificate, known to the model by a name only. -/
structure Certificate where
  /-- A name that tells one certificate from another. -/
  name : String
  deriving DecidableEq, Repr, Inhabited

/-- One credential a query asks for: a format, a document type and claims.
A claim is a path of a namespace and then a data element name (§4.2.1.3
step 1). -/
structure CredentialQuery where
  /-- The credential format. -/
  format : String
  /-- The document type wanted. -/
  docType : String
  /-- The claims wanted, each a namespace and a data element identifier. -/
  claims : List (String × String)
  deriving DecidableEq, Repr, Inhabited

/-- An OpenID4VP request as the guide's step 2 lists its parts. -/
structure AuthorizationRequest where
  /-- The protocol value given to the Digital Credentials API. -/
  protocol : String
  /-- The response type. -/
  responseType : String
  /-- The response mode. -/
  responseMode : String
  /-- The prefix of the client identifier. -/
  clientIdPrefix : String
  /-- The certificate the client identifier names by its hash. -/
  clientCertificate : Certificate
  /-- The certificate whose key signed the request, if the request is
  signed. -/
  signedWith : Option Certificate
  /-- The origins the relying party expects the request to come from. -/
  expectedOrigins : List Origin
  /-- The encryption key made for this request, if there is one. -/
  encryptionKey : Option Key
  /-- The credentials the query asks for. -/
  credentials : List CredentialQuery
  /-- The nonce, if there is one. -/
  nonce : Option Nonce
  /-- The {lit}`state` value, if there is one. -/
  state : Option String
  deriving DecidableEq, Repr, Inhabited

/-- The protocol value of a signed OpenID4VP request (§4.2.1.3 step 3). -/
def protocolValue : String := "openid4vp-v1-signed"

/-- The response type the guide requires (§4.2.1.3 step 2). -/
def responseTypeValue : String := "vp_token"

/-- The response mode the guide requires (§4.2.1.3 step 2). -/
def responseModeValue : String := "dc_api.jwt"

/-- The client identifier prefix the guide requires (§4.2.1.3 step 2). -/
def clientIdPrefixValue : String := "x509_hash"

/-- The credential format of an mdoc in a query (§4.2.1.3 step 1). -/
def mdocFormat : String := "mso_mdoc"

/-- What the guide leaves undecided about an OpenID4VP request. -/
structure RequestReading where
  /-- Whether a request must carry {lit}`state`.  The guide says the nonce and
  {lit}`state` must be set as OpenID4VP §5.2 says.  That clause requires
  {lit}`state` only for a presentation without a holder binding proof, §5.3
  exempts the Digital Credentials API, and Appendix A does not define the
  parameter there.  The guide's own example request has none. -/
  stateRequired : Bool
  deriving DecidableEq, Repr, Inhabited

/-- A requirement an OpenID4VP request does not meet. -/
inductive RequestFinding
  /-- The protocol value is not the one for a signed request. -/
  | wrongProtocol (found : String)
  /-- The response type is not the required one. -/
  | wrongResponseType (found : String)
  /-- The response mode is not the required one. -/
  | wrongResponseMode (found : String)
  /-- The client identifier does not have the required prefix. -/
  | wrongClientIdPrefix (found : String)
  /-- The request is not signed. -/
  | notSigned
  /-- The request is signed with the key of a certificate other than the one
  its client identifier names. -/
  | signedWithAnotherKey
  /-- The request names no expected origin. -/
  | noExpectedOrigins
  /-- The request carries no encryption key. -/
  | noEncryptionKey
  /-- A credential query asks for a format other than mdoc. -/
  | wrongFormat (docType : String)
  /-- The request carries no nonce. -/
  | noNonce
  /-- The request carries no {lit}`state`. -/
  | noState
  deriving DecidableEq, Repr

/-- The parts of a request a wallet can check without validating its
signature: the four values the guide names, the expected origins, the
encryption key, the formats of the query, the nonce and, under one reading,
{lit}`state`. -/
def parameterFindings (r : RequestReading) (a : AuthorizationRequest) : List RequestFinding :=
  (if a.protocol = protocolValue then [] else [.wrongProtocol a.protocol]) ++
  (if a.responseType = responseTypeValue then [] else [.wrongResponseType a.responseType]) ++
  (if a.responseMode = responseModeValue then [] else [.wrongResponseMode a.responseMode]) ++
  (if a.clientIdPrefix = clientIdPrefixValue then [] else [.wrongClientIdPrefix a.clientIdPrefix]) ++
  (if a.expectedOrigins = [] then [.noExpectedOrigins] else []) ++
  (if a.encryptionKey = none then [.noEncryptionKey] else []) ++
  ((a.credentials.filter fun c => decide (c.format ≠ mdocFormat)).map fun c => .wrongFormat c.docType) ++
  (if a.nonce = none then [.noNonce] else []) ++
  (if r.stateRequired = true ∧ a.state = none then [.noState] else [])

/-- Whether a request is signed with the key of the certificate its client
identifier names.  Only a party that validates the signature can tell. -/
def signatureFindings (a : AuthorizationRequest) : List RequestFinding :=
  match a.signedWith with
  | none => [.notSigned]
  | some c => if c = a.clientCertificate then [] else [.signedWithAnotherKey]

/-- A nonce or a key that more than one request of a relying party carries. -/
inductive ReuseFinding
  /-- Two requests carry the same nonce. -/
  | nonceReused
  /-- Two requests carry the same encryption key. -/
  | encryptionKeyReused
  deriving DecidableEq, Repr

/-- The nonces and encryption keys the requests of one relying party share.
A request that lacks one is refused on its own and is not counted
here. -/
def reuseFindings (requests : List AuthorizationRequest) : List ReuseFinding :=
  (if (requests.filterMap (·.nonce)).Nodup then [] else [.nonceReused]) ++
  (if (requests.filterMap (·.encryptionKey)).Nodup then [] else [.encryptionKeyReused])

/-- EARS: When a relying party makes an OpenID4VP request, the system shall
accept the request only if it carries what the guide requires of one.

Story: As a wallet provider, I want every request to have the same required
parts, so that my wallet can tell who asks, for what, and where to send the
answer.

Acceptance criteria:

* OID-203.1: If a request's protocol value, response type, response mode or
  client identifier prefix is not the one the guide names, then the system
  shall reject it.
* OID-203.2: If a request is not signed with the key of the certificate its
  client identifier names, then the system shall reject it.
* OID-203.3: If a request names no expected origin, then the system shall
  reject it.
* OID-203.4: If a request carries no encryption key or no nonce, then the
  system shall reject it.
* OID-203.5: If a credential query asks for a format other than mdoc, then
  the system shall reject the request.
* OID-203.6: If a request carries no state value, then the system shall
  reject it.
* OID-203.7: If two requests of a relying party carry the same nonce, then
  the system shall reject them.
* OID-203.8: If two requests of a relying party carry the same encryption
  key, then the system shall reject them.

The guide lists the parts in §4.2.1.3 steps 1 to 3 and says a request must
always be signed.  OpenID4VP makes the signature optional (§A.3.2) and the
profile allows a relying party to support signed requests only (HAIP §5.2),
so the guide's rule is narrower and allowed.  A signed request must be signed
with the key of the certificate the client identifier names (OpenID4VP
§5.9.3), must name its expected origins (§A.2), and must carry a nonce
(§5.2).  The guide requires an encryption key made for each request (step 2),
as the profile does (HAIP §5), and OpenID4VP requires a fresh nonce for every
request (§5.2).  A request on its own shows only that a key and a nonce are
present; that they are new shows across the requests of one relying party,
which {name}`reuseFindings` checks.  The guide's must for {lit}`state` is the
reading ({name}`RequestReading`).  The minimum set of claims and the entropy
of the nonce are not checked: the guide gives neither a list nor a number for
this profile. -/
@[ears "OID-203", source "tig-4.2.1.3", assumes "x-openid4vp x-haip x-w3c-dc-api"]
def requestFindings (r : RequestReading) (a : AuthorizationRequest) : List RequestFinding :=
  parameterFindings r a ++ signatureFindings a

/-- What the guide leaves undecided about a wallet's checks of an OpenID4VP
request.  The guide introduces its list of four checks with should (§4.2.1.3
step 4).  The parameter check, the origin check and the check of the client
identifier against trusted verifiers say must; the signature check has no
requirement word.  OpenID4VP requires the origin check of a wallet (§A.2) and
leaves it to the wallet whether it validates the signature of a request over
the Digital Credentials API (§5.9.3).  The parameters and the origin are
checked under every reading. -/
structure WalletReading where
  /-- Whether a wallet must validate the signature of a request and refuse one
  not signed with the key of the certificate its client identifier names. -/
  signatureChecked : Bool
  /-- Whether a wallet must refuse a request whose client identifier names a
  certificate that is not on its list of trusted verifiers. -/
  verifierListChecked : Bool
  deriving DecidableEq, Repr, Inhabited

/-- A reason a wallet does not answer an OpenID4VP request. -/
inductive WalletFinding
  /-- The request's parameters are not what the guide requires. -/
  | malformed
  /-- The request did not come from an origin it names. -/
  | originNotExpected (origin : Origin)
  /-- The request is not signed with the key of the certificate its client
  identifier names. -/
  | badSignature
  /-- The certificate the client identifier names is not a trusted
  verifier's. -/
  | untrustedVerifier (certificate : Certificate)
  deriving DecidableEq, Repr

/-- EARS: When a wallet receives an OpenID4VP request, the system shall
answer it only if the request is well formed, comes from an origin it names,
and is signed by a trusted relying party.

Story: As a passenger, I want my wallet to answer only the relying party that
signed the request on the page I am on, so that a copied request on another
site gets nothing.

Acceptance criteria:

* OID-204.1: If a request comes from an origin that is not among its expected
  origins, then the system shall refuse it.
* OID-204.2: If a request is not signed with the key of the certificate its
  client identifier names, then the system shall refuse it.
* OID-204.3: If the certificate a request's client identifier names is not a
  trusted relying party's, then the system shall refuse it.

The guide lists four checks in §4.2.1.3 step 4: the parameters, the origin,
the signature and the client identifier.  It introduces the list with should,
marks three of the four with must, and gives the signature check no
requirement word.  OpenID4VP requires the origin check of a wallet (§A.2), so
the origin is checked under every reading.  It leaves the signature check over
the Digital Credentials API to the wallet (§5.9.3), and it names no list of
trusted verifiers.  Whether a wallet must make the last two checks is the
reading ({name}`WalletReading`).  Which list a wallet checks a relying party
against is part of the trust model, which the guide leaves out, so the list is
given to the rule. -/
@[ears "OID-204", source "tig-4.2.1.3 tig-3.2", assumes "x-openid4vp"]
def walletFindings (r : RequestReading) (w : WalletReading) (trustedVerifiers : List Certificate)
    (seenOrigin : Origin) (a : AuthorizationRequest) : List WalletFinding :=
  (if parameterFindings r a = [] then [] else [.malformed]) ++
  (if seenOrigin ∈ a.expectedOrigins then [] else [.originNotExpected seenOrigin]) ++
  (if w.signatureChecked = true ∧ signatureFindings a ≠ [] then [.badSignature] else []) ++
  (if w.verifierListChecked = true ∧ a.clientCertificate ∉ trustedVerifiers
    then [.untrustedVerifier a.clientCertificate] else [])

/-- The request as the shared model sees it, for a relying party at an
origin: the profile, the nonce, the encryption key and the data elements the
query's claims name.  A request with no nonce or no encryption key has no
shared form. -/
def AuthorizationRequest.shared (a : AuthorizationRequest) (origin : Origin) : Option Request :=
  match a.nonce, a.encryptionKey with
  | some nonce, some key =>
    some { profile := .openid4vp, origin, nonce, encryptionKey := key, engagementKey := none,
           elements := a.credentials.flatMap fun c =>
             c.claims.map fun claim => ⟨c.docType, claim.1, claim.2⟩ }
  | _, _ => none

/-- EARS: When a wallet answers an OpenID4VP request over the Digital
Credentials API, the system shall sign its response over the origin of the
request, the nonce and the relying party's encryption key.

Story: As a relying party, I want a response to be usable only for the
request it answers, so that a response captured elsewhere or earlier is
refused.

Acceptance criteria:

* OID-205.1: If a response was signed for a nonce other than the one of this
  request, then the system shall reject it.
* OID-205.2: If a response was signed for an origin other than the relying
  party's, then the system shall reject it.
* OID-205.3: If a response was signed for an encryption key other than the
  one of this request, then the system shall reject it.
* OID-205.4: If a device response in a token holds more than one mdoc, then
  the system shall reject the token.

The wallet sets the session transcript from the three values and the relying
party rebuilds it and validates the nonce (§4.2.1.3 steps 4 and 5).
OpenID4VP §B.2.6.2 defines the transcript as a hash of the origin, the nonce
and the thumbprint of the encryption key; the model keeps the three values in
place of the hash, so it does not model two different inputs with one hash.
The device signs over the transcript (§B.2.5).  The profile requires a
separate device response for each mdoc returned (HAIP §5.3.1).  The guide's
opening of §4.2.1.3 requires both parties to comply with the profile; step 2
cites the same clause with should, and that sentence is about the request,
so the rule for the response follows the opening. -/
@[ears "OID-205", source "tig-4.2.1.3", assumes "x-openid4vp x-haip x-18013-5-mdoc-auth"]
def transcript (origin : Origin) (nonce : Nonce) (encryptionKey : Key) : SessionTranscript :=
  .handover origin nonce encryptionKey

/-- The token of an OpenID4VP response with mdocs: its device responses, each
the list of mdocs it holds (OpenID4VP §B.2.5). -/
abbrev VpToken := List (List Presented)

/-- A reason a relying party refuses the form of a token. -/
inductive TokenFinding
  /-- A device response holds more than one mdoc. -/
  | severalMdocs (count : Nat)
  deriving DecidableEq, Repr

/-- The device responses of a token that hold more than one mdoc. -/
def tokenFindings (token : VpToken) : List TokenFinding :=
  (token.filter fun dr => decide (1 < dr.length)).map fun dr => .severalMdocs dr.length

/-- The credentials a token presents, as the shared model's response. -/
def VpToken.response (token : VpToken) : Response :=
  ⟨token.flatten⟩

/-- The token a wallet builds from its response: one device response for each
mdoc (HAIP §5.3.1). -/
def deviceResponses (response : Response) : VpToken :=
  response.documents.map fun d => [d]

end Rules.OneId.OpenId4Vp
