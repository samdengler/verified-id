import Lean

/-!
# Assumptions about external specifications

The One ID guide builds on ISO, OpenID, W3C, IETF, ICAO and IATA
specifications.  Each dependency is listed here once, with the clause the
guide cites, the guide section that cites it, and whether this project has
read the specification.

The public ones were fetched and read: {lit}`scripts/fetch-sources.sh` fetches
them and {lit}`sources/external.json` records the address, the version and
the SHA-256 of each.  For a specification that was read, the statement says
what the cited clause says, in our words, with the clause number.  The
ISO/IEC documents and IATA Resolution 792 are sold, and the One ID business
requirements are not public.  They were not read, and for each of them the
statement says only what the guide itself says about it.

A declaration that relies on one names it with {lit}`@[assumes "<key> ..."]`.
The attribute rejects a key that is not here.  A theorem that relies on an
assumption holds for every content the external clause could have, unless its
statement says otherwise.
-/

namespace Rules.Core

/-- Whether this project has read a specification. -/
inductive ReadStatus where
  /-- Read.  The document is the entry of {lit}`sources/external.json` with
  this name, which records the address, the version and the SHA-256 of what
  was read. -/
  | read (document : String)
  /-- Not read, with the reason. -/
  | notRead (reason : String)
  deriving Repr, Inhabited

/-- A dependency on an external specification. -/
structure Assumption where
  /-- The key declarations name it by. -/
  key : String
  /-- The external specification, as the guide's reference list names it. -/
  spec : String
  /-- Where the specification is published or sold, from the guide's reference
  list where it gives one.  Empty for a document that is not public. -/
  url : String
  /-- The clause, table or annex the guide cites. -/
  clause : String
  /-- The section of the guide that cites it. -/
  guide : String
  /-- Whether this project has read the specification. -/
  read : ReadStatus
  /-- For a specification that was read: what the cited clause says, in our
  words, with the clause number.  For one that was not: what the guide says
  the clause provides.  Then how the model stands in for it. -/
  statement : String
  deriving Repr, Inhabited

/-- Every external dependency the in-scope sections of the guide name. -/
def assumptions : List Assumption := [
  -- Credential data model, §4.1
  { key := "x-18013-5-data-model", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§6.3.1, §8.3.1, §8.3.2",
    guide := "§4.1",
    read := .notRead "sold by ISO",
    statement := "Governs the mdoc data model and how data is stored, retrieved and presented. The model takes an mdoc to be a document type, namespaces, and data elements identified within a namespace. Whether names may repeat is not stated in the guide, so it is a reading." },
  { key := "x-23220-4-annex-c", spec := "ISO/IEC TS 23220-4:2026", url := "https://www.iso.org/standard/86785.html", clause := "Annex C, §C.2.1",
    guide := "§2, §4.1.1",
    read := .notRead "sold by ISO",
    statement := "Defines the photoid profile, its document type and its three namespaces. The model takes the document type and namespace names the guide prints." },
  { key := "x-23220-4-table-c1", spec := "ISO/IEC TS 23220-4:2026", url := "https://www.iso.org/standard/86785.html", clause := "Annex C, Table C.1",
    guide := "§4.1.1",
    read := .notRead "sold by ISO",
    statement := "Gives the identifier, description, presence and encoding of each data element of the base identity namespace. The model takes the table as a parameter, with a presence and an encoding for each identifier, and proves its guarantees for every table." },
  { key := "x-23220-4-table-c2", spec := "ISO/IEC TS 23220-4:2026", url := "https://www.iso.org/standard/86785.html", clause := "Annex C, Table C.2",
    guide := "§4.1.1",
    read := .notRead "sold by ISO",
    statement := "Gives the presence of each data element of the photoid namespace. The model takes the table as a parameter." },
  { key := "x-23220-4-table-c3", spec := "ISO/IEC TS 23220-4:2026", url := "https://www.iso.org/standard/86785.html", clause := "Annex C, Table C.3",
    guide := "§4.1.1",
    read := .notRead "sold by ISO",
    statement := "Gives the presence of each data element of the data groups namespace. The model takes the table as a parameter, and takes the identifiers dg2 and sod as the guide writes them." },
  { key := "x-23220-2-encoding", spec := "ISO/IEC TS 23220-2:2026", url := "https://www.iso.org/standard/91155.html", clause := "§6.2.4 and its encoding rules",
    guide := "§4.1.1",
    read := .notRead "sold by ISO",
    statement := "Gives the data objects and encoding rules the photoid profile refers to. The model tells a text string, a byte string and a yes or no value apart, and checks nothing finer." },
  { key := "x-23220-4-security", spec := "ISO/IEC TS 23220-4:2026", url := "https://www.iso.org/standard/86785.html", clause := "Annex A and Annex B",
    guide := "§4.1.1",
    read := .notRead "sold by ISO",
    statement := "The security model: an issuer-signed mobile security object, device-signed responses, and selective disclosure of individual data elements. The guide says these ensure a verifier receives only what it requested and the holder consented to. The model's wallet discloses only requested and approved data elements (OID-201); the mechanisms themselves are not modelled." },
  { key := "x-icao-9303-10", spec := "ICAO Doc 9303", url := "https://www.icao.int/sites/default/files/publications/DocSeries/9303_p10_cons_en.pdf", clause := "Part 10",
    guide := "§4.1.1",
    read := .read "icao-9303-10",
    statement := "Defines the data groups and the document security object of a passport chip, which the data groups namespace carries. Data group 2 is the image of the holder's face and is mandatory on the chip (§4.7.2). It is a biometric template that can hold from one to nine encodings of the face, with a header for each (§4.7.2.1, §4.7.2.2), so it is more than one image. The document security object is mandatory, is signed by the issuing State and holds a hash of each data group (§4.5.2, §4.6.2). The model treats their content as opaque bytes." },
  { key := "x-res792-bcbp", spec := "IATA Resolution 792 (BCBP)", url := "https://www.iata.org/en/publications/manuals/passenger-services-conference-resolution-manual/", clause := "the resolution as a whole",
    guide := "§4.1.2",
    read := .notRead "sold by IATA, in the Passenger Services Conference Resolutions Manual",
    statement := "Defines the format of a bar-coded boarding pass string, to which the guide refers for the string's value and its mandatory elements. The model takes as parameters which strings follow the resolution and which passenger name a string carries." },
  { key := "x-iata-bcbp-guide", spec := "IATA Bar Coded Boarding Pass Implementation Guide, seventh edition", url := "https://www.iata.org/contentassets/1dccc9ed041b4f3bbdcf8ee8682e75c4/2021_03_02-bcbp-implementation-guide-version-7-.pdf", clause := "the guide as a whole",
    guide := "§4.1.2",
    read := .read "iata-bcbp-guide",
    statement := "IATA's public guide to Resolution 792, which the One ID guide lists beside the resolution. A boarding pass is issued for each passenger, and one string holds one flight leg or several (§2.2.1). The items of a string are mandatory, conditional or for an airline's own use, and the passenger name is a mandatory item (§2.2.1). One boarding pass may cover an adult travelling with an infant (§2.3.5). It leaves the list of items, their sizes and their values to the resolution (§2.2.1, §2.2.2), so it does not replace it. No declaration relies on it." },
  { key := "x-cbor-tstr", spec := "IETF RFC 8949 (CBOR)", url := "https://datatracker.ietf.org/doc/html/rfc8949", clause := "text string (tstr)",
    guide := "§4.1.2",
    read := .read "rfc8949",
    statement := "The encoding of the boarding pass string. A text string is major type 3 and is encoded as UTF-8 (§3.1). The model distinguishes a text value from a byte string, a flag and any other value." },
  { key := "x-18013-5-validity", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§9.3.1, and the validity information set when an mdoc is signed",
    guide := "§4.1.2, §4.2.1.2",
    read := .notRead "sold by ISO",
    statement := "The guide names validUntil as part of the validity information set at signing, and time validity checks a verifier makes. The model takes validUntil as an instant, and takes whether a credential is still valid at that exact instant as a reading. Any other part of the check is not modelled." },
  { key := "x-one-id-brd", spec := "One ID business requirements documents", url := "", clause := "Digitalization of Admissibility Part 1 v3.0; Contactless Travel v1.1",
    guide := "§1.3, §4.1.1",
    read := .notRead "not public",
    statement := "The business requirements the guide implements. The guide says the portrait from the passport is required by them." },
  -- Remote presentation, §4.2.1
  { key := "x-w3c-dc-api", spec := "W3C Digital Credentials API, draft of 16 July 2026", url := "https://www.w3.org/TR/2026/WD-digital-credentials-20260716/", clause := "§1, §2.1 to §2.4, §5",
    guide := "§4.2.1.1, §4.2.1.2, §4.2.1.3",
    read := .read "w3c-dc-api",
    statement := "The browser API that carries a presentation request and its response. Its introduction and examples are marked non-normative (§1, §2): §2.1 shows feature detection, §2.2 the check that the user agent allows a protocol, and §2.3 a request. §5 lists the presentation protocols, among them org-iso-mdoc and openid4vp-v1-signed. The guide cites §3 for terms; in this draft the terms are in §4. The model checks the two protocol identifiers (OID-203, OID-206); the API itself is not modelled." },
  { key := "x-18013-7-annex-c", spec := "ISO/IEC TS 18013-7:2025", url := "https://www.iso.org/standard/91154.html", clause := "Annex C, §C.2 to §C.5",
    guide := "§4.2.1.2",
    read := .notRead "sold by ISO",
    statement := "The request format with its encryption information and nonce, the response format, the encryption of the response, and the session transcript, for mdoc over the DC API. The model takes the session transcript as a parameter with no assumption about its content. The relying party compares it with its request, as the guide requires mdoc authentication with it; whether it holds the request's nonce is an open lookup (§C.5). Encryption is not modelled." },
  { key := "x-18013-5-request-response", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§8.3.2.1.2.1, §8.3.2.1.2.2, §8.3.2.1.2.3",
    guide := "§4.2.1.2, §4.2.2",
    read := .notRead "sold by ISO",
    statement := "The device request, the device response with its issuer-signed and device-signed parts, and the status and error codes. The model records the data elements a response discloses and its two signatures; the structures and the codes are not modelled." },
  { key := "x-18013-5-issuer-data-auth", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§9.1.2, §9.1.2.4, §9.3.1",
    guide := "§4.2.1.2, §4.2.1.3, §4.2.2",
    read := .notRead "sold by ISO",
    statement := "Issuer data authentication. The guide says §9.3.1 covers a trusted issuer, the signature and time validity (mdoc profile). For §9.1.2 it names a trusted issuer and data that was not changed (OpenID4VP profile), and a trusted issuer, a valid document type and the data elements requested (proximity, which adds §9.3.1 with should). Whether §9.1.2 includes time validity is an open lookup. The model records the outcome: an issuer on the list and a signature that verifies." },
  { key := "x-18013-5-mdoc-auth", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§9.1.3",
    guide := "§4.2.1.2, §4.2.1.3, §4.2.2",
    read := .notRead "sold by ISO",
    statement := "Mdoc authentication: that the response comes from the device the credential was issued to. The model records the key a device signature was made with and the transcript it was made over, and the relying party compares both." },
  { key := "x-18013-5-reader-auth", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§9.1.4",
    guide := "§4.2.1.2, §4.2.2",
    read := .notRead "sold by ISO",
    statement := "Reader authentication: how a wallet checks who is asking. Not modelled." },
  { key := "x-18013-5-session", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§9.1.1.4, §9.1.1.5, §9.1.5, §9.1.5.1, §9.1.5.2",
    guide := "§4.2.1.2, §4.2.2",
    read := .notRead "sold by ISO",
    statement := "Session encryption, session keys, the session transcript, the cipher suites and session termination. The proximity transcript is a parameter, and the keys of a session are values that must not be reused (OID-301). Encryption, the derivation of session keys and termination are not modelled." },
  { key := "x-18013-5-engagement", spec := "ISO/IEC 18013-5:2021", url := "https://www.iso.org/standard/69084.html", clause := "§8.2.1.1, §8.2.2.1, §8.2.2.3, §8.3.3.1.1 to §8.3.3.1.3",
    guide := "§4.2.2",
    read := .notRead "sold by ISO",
    statement := "Device engagement by QR code or NFC, and data transfer over Bluetooth low energy, NFC or Wi-Fi Aware. The model records a session's engagement key and how data is retrieved (OID-301); the structures are not modelled." },
  { key := "x-23220-4-reader-and-certificates", spec := "ISO/IEC TS 23220-4:2026", url := "https://www.iso.org/standard/86785.html", clause := "Annex A, §A.1.4, §A.3.1, §A.3.4; Annex E, §E.2.1, §E.2.2",
    guide := "§4.2.1.2, §4.2.1.3",
    read := .notRead "sold by ISO",
    statement := "Reader authentication, issuer validation, certificate validation, and example device requests. Not modelled." },
  { key := "x-openid4vp", spec := "OpenID for Verifiable Presentations 1.0", url := "https://openid.net/specs/openid-4-verifiable-presentations-1_0.html", clause := "§5, §5.1, §5.2, §5.9.3, §6, §6.1.1.1, §6.4, §6.4.1, §8.1, §8.5, §8.6, §14.9, Appendix A, §A.2, §A.3.2, §B.2.2, §B.2.4, §B.2.5, §B.2.6.2",
    guide := "§4.2.1.3",
    read := .read "openid4vp",
    statement := "The authorization request and its parameters (§5), the DCQL query language (§6), the response and its validation (§8.1, §8.6), error responses (§8.5), the DC API profile (Appendix A), and the mdoc session transcript (§B.2.6.2). A wallet must not send a selectively disclosable claim that the query did not select (§6.4). The nonce is required, fresh and random for every request (§5.2). Over the DC API, state is not a defined parameter (§A.2), and the session transcript ties a response to the verifier's origin, the nonce and the verifier's encryption key (§B.2.6.2). The wallet must compare the expected origins with the origin of a request (§A.2), and it is left to the wallet whether it validates the signature of a request over the DC API (§5.9.3). A wallet that cannot deliver every claim asked of a credential must not return it (§6.4.1). A verifier must check that what is returned satisfies the request and discard a presentation that fails a check (§8.6), and must not rely on the wallet to enforce the query (§14.9). Modelled in OID-201 to OID-205, with the three values of the transcript in place of their hash." },
  { key := "x-haip", spec := "OpenID4VC High Assurance Interoperability Profile 1.0", url := "https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0.html", clause := "§5, §5.2, §5.3.1",
    guide := "§4.2.1.3",
    read := .read "haip",
    statement := "The profile both verifier and wallet must comply with. For every OpenID4VP flow it requires the response type vp_token, the x509_hash client identifier for signed requests, DCQL, an encrypted response, an encryption key made for each request, and support for the authority key identifier query (§5). Over the DC API it requires the response mode dc_api.jwt and Appendix A of OpenID4VP (§5.2). For mdoc it requires the format mso_mdoc and a separate device response for each mdoc returned (§5.3.1). It leaves trust management out of scope (§3.4). Modelled in OID-203 and OID-205: the values, a key for each request, and a refusal of a device response that holds more than one mdoc." },
  { key := "x-hpke", spec := "IETF RFC 9180 (HPKE)", url := "https://datatracker.ietf.org/doc/rfc9180/", clause := "the mechanism as a whole",
    guide := "§4.2.1.2",
    read := .read "rfc9180",
    statement := "Hybrid public key encryption: a message is encrypted to a recipient's public key (§1, §5). How the mdoc profile uses it is set in ISO/IEC TS 18013-7 Annex C, which was not read. Not yet modelled." },
  { key := "x-cose", spec := "IETF RFC 9052 (COSE)", url := "https://datatracker.ietf.org/doc/html/rfc9052", clause := "COSE_Key, COSE_Sign1",
    guide := "§4.2.1.2, §4.2.2",
    read := .read "rfc9052",
    statement := "The key and signature formats. A COSE key is a map of key parameters (§7), and COSE_Sign1 carries one signature over a payload (§4.2). Not yet modelled." },
  { key := "x-rfc5280", spec := "IETF RFC 5280", url := "https://datatracker.ietf.org/doc/html/rfc5280", clause := "certificates and certificate chains",
    guide := "§2",
    read := .read "rfc5280",
    statement := "What a certificate and a certificate chain are. A certificate binds a public key to a subject and is signed by a certification authority (§3.1), and a chain of certificates leads back to a key the user already trusts (§3.2). Validating a chain checks each certificate's signature, its validity period and that it is not revoked (§6.1.3). Not yet modelled." },
  { key := "x-icao-9303-11", spec := "ICAO Doc 9303", url := "https://www.icao.int/sites/default/files/publications/DocSeries/9303_p11_cons_en.pdf", clause := "Part 11, §5",
    guide := "§4.2.1.2, §4.2.1.3",
    read := .read "icao-9303-11",
    statement := "The check of the document security object, which a verifier may make when a photoid carries data groups. The inspection system validates a certificate chain from a trust anchor to the certificate that signed the object, verifies the object's signature, and compares the hash of each data group it read with the hash in the object (§5.1.1). The check shows the content is authentic and unchanged, and does not show that it was not copied (§5). Not yet modelled." },
  { key := "x-iata-cuws", spec := "IATA CUWS standard APIs", url := "https://standards.atlassian.net/wiki/spaces/AIDM/pages/2241003524/IATA+Data+Exchange+Standards+-+Download", clause := "the APIs as a whole",
    guide := "§4.2.1.2, §4.2.1.3, §4.2.2",
    read := .notRead "not fetched: the guide cites no clause of it, and the model does not reach the hand-off to the identity management system",
    statement := "How a verifier touchpoint sends validated data to an identity management system. Not yet modelled." }
]

/-- The assumption a key names, if the list has it. -/
def assumptionOf? (key : String) : Option Assumption :=
  assumptions.find? (·.key == key)

end Rules.Core
