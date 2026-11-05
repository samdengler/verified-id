import Rules.OneId.Traveler
import Rules.OneId.Validity

/-!
# What a wallet and a relying party exchange

The guide gives three ways to present a credential (§4.2): two remote
profiles over the W3C Digital Credentials API, one using the ISO mdoc
protocol and one using OpenID4VP, and one proximity profile.  All three have
the same parts: a request that names data elements, the holder's consent, a
response that discloses data elements, and the relying party's checks.  This
module holds those parts.

No cryptography is modelled.  A key, a nonce and an origin are values that
can only be compared.  Whether a signature verifies is a field of the thing
signed, and a device signature is the pair of the key that made it and the
value it was made over.  The model does not say how hard a signature is to
forge or a nonce to guess; it says what a relying party compares.
-/

namespace Rules.OneId

open Rules.Core

/-- A cryptographic key, known to the model by a name only.  Two keys are the
same key when their names are equal. -/
structure Key where
  /-- A name that tells one key from another. -/
  name : String
  deriving DecidableEq, Repr, Inhabited

/-- A value a relying party makes for one request, so that a response can be
tied to it. -/
structure Nonce where
  /-- The value. -/
  value : String
  /-- How many bytes of entropy the value has.  The mdoc profile sets a
  minimum (§4.2.1.2); the model cannot measure it and takes it as given. -/
  entropyBytes : Nat
  deriving DecidableEq, Repr, Inhabited

/-- The origin of a relying party's web page or app, as the user agent reports
it to the wallet (§4.2.1.1).  In proximity it stands for the reader. -/
structure Origin where
  /-- The origin, such as {lit}`https://checkin.example`. -/
  value : String
  deriving DecidableEq, Repr, Inhabited

/-- An issuer of credentials, known to the model by the name of the
certificate it signs with. -/
structure Issuer where
  /-- A name that tells one issuer from another. -/
  name : String
  deriving DecidableEq, Repr, Inhabited

/-- One data element of one kind of credential: a document type, a namespace
and an identifier.  A request names data elements this way in all three
profiles (§4.2.1.2 step 1, §4.2.1.3 step 1, §4.2.2 step 3). -/
structure ElementRef where
  /-- The document type of the credential. -/
  docType : String
  /-- The namespace. -/
  nameSpace : String
  /-- The identifier of the data element within the namespace. -/
  identifier : String
  deriving DecidableEq, Repr, Inhabited

/-- The three presentation profiles of the guide. -/
inductive Profile
  /-- The mdoc protocol over the Digital Credentials API (§4.2.1.2). -/
  | mdocOverDcApi
  /-- OpenID4VP over the Digital Credentials API (§4.2.1.3). -/
  | openid4vp
  /-- Proximity presentation between a reader and a device (§4.2.2). -/
  | proximity
  deriving DecidableEq, Repr, Inhabited

/-- The value a device signs so that its response belongs to one exchange.
Every profile calls it the session transcript and defines it differently. -/
inductive SessionTranscript
  /-- The transcript of the OpenID4VP profile over the Digital Credentials
  API: the origin of the request, the nonce and the relying party's encryption
  key (OpenID4VP §B.2.6.2, which hashes the three values; the model keeps the
  values themselves). -/
  | handover (origin : Origin) (nonce : Nonce) (encryptionKey : Key)
  /-- A transcript an ISO document defines.  The model does not look inside
  it. -/
  | iso (value : String)
  deriving DecidableEq, Repr, Inhabited

/-- A signature a device made: the key that made it and the transcript it
was made over.  The guide calls checking it mdoc authentication, or holder
binding (§4.2.1.3 step 5). -/
structure DeviceSignature where
  /-- The key that made the signature. -/
  key : Key
  /-- The transcript the signature was made over. -/
  transcript : SessionTranscript
  deriving DecidableEq, Repr, Inhabited

/-- A credential as it was issued and as a wallet holds it: its content, the
traveler it is about, its issuer, and the key of the device it was issued to.
The guide says a response must come from the device a credential was
originally issued to (§4.2.1.3 step 5, §4.2.2 step 4); how an issuer puts the
device's key into a credential is in ISO/IEC 18013-5, which this project has
not read. -/
structure Credential where
  /-- The content the issuer signed. -/
  mdoc : Mdoc
  /-- The traveler the issuer issued it about.  A relying party does not see
  this. -/
  subject : Traveler
  /-- The issuer. -/
  issuer : Issuer
  /-- The key of the device the credential was issued to. -/
  deviceKey : Key
  deriving DecidableEq, Repr, Inhabited

/-- One credential as a relying party receives it: the data elements
disclosed, the issuer's signature and the device's signature. -/
structure Presented where
  /-- The document type, the data elements disclosed, and the end of
  validity.  A data element the holder did not disclose is absent. -/
  mdoc : Mdoc
  /-- The issuer whose certificate comes with the credential. -/
  issuer : Issuer
  /-- Whether the issuer's signature over what was disclosed verifies. -/
  issuerSignatureValid : Bool
  /-- The device key the issuer signed into the credential. -/
  deviceKey : Key
  /-- The device's signature, if the response has one. -/
  deviceSignature : Option DeviceSignature
  deriving DecidableEq, Repr, Inhabited

/-- What a relying party receives in answer to one request. -/
structure Response where
  /-- The credentials presented. -/
  documents : List Presented
  deriving DecidableEq, Repr, Inhabited

/-- A relying party's request, as far as all three profiles share it. -/
structure Request where
  /-- The profile the request is made in. -/
  profile : Profile
  /-- The origin of the relying party. -/
  origin : Origin
  /-- The nonce of this request.  Proximity has none in the guide; the field
  is unused there. -/
  nonce : Nonce
  /-- The relying party's public key for this request: the encryption key of
  the remote profiles, the reader's key of a proximity session. -/
  encryptionKey : Key
  /-- In proximity, the public key the wallet presented when it engaged the
  reader (§4.2.2 step 1).  The remote profiles have none. -/
  engagementKey : Option Key
  /-- The data elements requested. -/
  elements : List ElementRef
  deriving DecidableEq, Repr, Inhabited

/-- What the holder approved for one request.  The guide requires informed
consent before every response and requires the wallet to show what is shared
with whom (§3.2, §4.2.1.2 step 5, §4.2.1.3 step 4, §4.2.2 step 4). -/
structure Consent where
  /-- The data elements the holder approved. -/
  approved : List ElementRef
  deriving DecidableEq, Repr, Inhabited

/-- Every data element a credential holds, each named by document type,
namespace and identifier. -/
def Mdoc.refs (m : Mdoc) : List ElementRef :=
  m.nameSpaces.flatMap fun ns => ns.elements.map fun el => ⟨m.docType, ns.name, el.identifier⟩

/-- A credential with only the allowed data elements disclosed.  A namespace
left with no data element is dropped.  The document type and the end of
validity stay. -/
def Mdoc.disclose (m : Mdoc) (allowed : List ElementRef) : Mdoc :=
  let shown (ns : NameSpace) : NameSpace :=
    { ns with elements := ns.elements.filter fun el =>
        decide ((⟨m.docType, ns.name, el.identifier⟩ : ElementRef) ∈ allowed) }
  { m with nameSpaces := (m.nameSpaces.map shown).filter fun ns => decide (ns.elements ≠ []) }

/-- Every data element a response holds. -/
def Response.refs (response : Response) : List ElementRef :=
  response.documents.flatMap fun d => d.mdoc.refs

end Rules.OneId
