import Lean

/-!
# Assumptions about external specifications

The One ID guide builds on ISO, OpenID, W3C, IETF, ICAO and IATA
specifications.  This project has not read them: they are not available here.
The model takes from each one only what the guide itself says about it, and
each such dependency is listed here once, with the clause the guide cites and
the guide section that cites it.

A declaration that relies on one names it with {lit}`@[assumes "<key> ..."]`.
The attribute rejects a key that is not here.  A theorem that relies on an
assumption holds for every content the external clause could have, unless its
statement says otherwise.
-/

namespace Rules.Core

/-- A dependency on a specification this project has not read. -/
structure Assumption where
  /-- The key declarations name it by. -/
  key : String
  /-- The external specification, as the guide's reference list names it. -/
  spec : String
  /-- The clause, table or annex the guide cites. -/
  clause : String
  /-- The section of the guide that cites it. -/
  guide : String
  /-- What the guide says the clause provides, in our words, and how the
  model stands in for it. -/
  statement : String
  deriving Repr, Inhabited

/-- Every external dependency the in-scope sections of the guide name. -/
def assumptions : List Assumption := [
  -- Credential data model, §4.1
  { key := "x-18013-5-data-model", spec := "ISO/IEC 18013-5:2021", clause := "§6.3.1, §8.3.1, §8.3.2",
    guide := "§4.1",
    statement := "Governs the mdoc data model and how data is stored, retrieved and presented. The model takes an mdoc to be a document type, namespaces, and data elements identified within a namespace. Whether names may repeat is not stated in the guide, so it is a reading." },
  { key := "x-23220-4-annex-c", spec := "ISO/IEC TS 23220-4:2026", clause := "Annex C, §C.2.1",
    guide := "§2, §4.1.1",
    statement := "Defines the photoid profile, its document type and its three namespaces. The model takes the document type and namespace names the guide prints." },
  { key := "x-23220-4-table-c1", spec := "ISO/IEC TS 23220-4:2026", clause := "Annex C, Table C.1",
    guide := "§4.1.1",
    statement := "Gives the identifier, description, presence and encoding of each data element of the base identity namespace. The model takes the table as a parameter, with a presence and an encoding for each identifier, and proves its guarantees for every table." },
  { key := "x-23220-4-table-c2", spec := "ISO/IEC TS 23220-4:2026", clause := "Annex C, Table C.2",
    guide := "§4.1.1",
    statement := "Gives the presence of each data element of the photoid namespace. The model takes the table as a parameter." },
  { key := "x-23220-4-table-c3", spec := "ISO/IEC TS 23220-4:2026", clause := "Annex C, Table C.3",
    guide := "§4.1.1",
    statement := "Gives the presence of each data element of the data groups namespace. The model takes the table as a parameter, and takes the identifiers dg2 and sod as the guide writes them." },
  { key := "x-23220-2-encoding", spec := "ISO/IEC TS 23220-2:2026", clause := "§6.2.4 and its encoding rules",
    guide := "§4.1.1",
    statement := "Gives the data objects and encoding rules the photoid profile refers to. The model tells a text string, a byte string and a yes or no value apart, and checks nothing finer." },
  { key := "x-23220-4-security", spec := "ISO/IEC TS 23220-4:2026", clause := "Annex A and Annex B",
    guide := "§4.1.1",
    statement := "The security model: an issuer-signed mobile security object, device-signed responses, and selective disclosure of individual data elements. The guide says these ensure a verifier receives only what it requested and the holder consented to. Not modelled until the presentation flows are." },
  { key := "x-icao-9303-10", spec := "ICAO Doc 9303", clause := "Part 10",
    guide := "§4.1.1",
    statement := "Defines the data groups and the document security object of a passport chip, which the data groups namespace carries. The model treats their content as opaque bytes." },
  { key := "x-res792-bcbp", spec := "IATA Resolution 792 (BCBP)", clause := "the resolution as a whole",
    guide := "§4.1.2",
    statement := "Defines the format of a bar-coded boarding pass string, to which the guide refers for the string's value and its mandatory elements. The model takes as parameters which strings follow the resolution and which passenger name a string carries." },
  { key := "x-cbor-tstr", spec := "IETF RFC 8949 (CBOR)", clause := "text string (tstr)",
    guide := "§4.1.2",
    statement := "The encoding of the boarding pass string. The model distinguishes a text value from a byte string, a flag and any other value." },
  { key := "x-18013-5-validity", spec := "ISO/IEC 18013-5:2021", clause := "§9.3.1, and the validity information set when an mdoc is signed",
    guide := "§4.1.2, §4.2.1.2",
    statement := "The guide names validUntil as part of the validity information set at signing, and time validity checks a verifier makes. The model takes validUntil as an instant, and takes whether a credential is still valid at that exact instant as a reading. Any other part of the check is not modelled." },
  { key := "x-one-id-brd", spec := "One ID business requirements documents", clause := "Digitalization of Admissibility Part 1 v3.0; Contactless Travel v1.1",
    guide := "§1.3, §4.1.1",
    statement := "The business requirements the guide implements. The guide says the portrait from the passport is required by them. Not read." },
  -- Remote presentation, §4.2.1
  { key := "x-w3c-dc-api", spec := "W3C Digital Credentials API, draft of 16 July 2026", clause := "§1, §2.1 to §2.4, §5",
    guide := "§4.2.1.1, §4.2.1.2, §4.2.1.3",
    statement := "The browser API that carries a presentation request and its response, feature and protocol detection, and the protocol identifiers org-iso-mdoc and openid4vp-v1-signed. Not yet modelled." },
  { key := "x-18013-7-annex-c", spec := "ISO/IEC TS 18013-7:2025", clause := "Annex C, §C.2 to §C.5",
    guide := "§4.2.1.2",
    statement := "The request format with its encryption information and nonce, the response format, the encryption of the response, and the session transcript, for mdoc over the DC API. Not yet modelled." },
  { key := "x-18013-5-request-response", spec := "ISO/IEC 18013-5:2021", clause := "§8.3.2.1.2.1, §8.3.2.1.2.2, §8.3.2.1.2.3",
    guide := "§4.2.1.2, §4.2.2",
    statement := "The device request, the device response with its issuer-signed and device-signed parts, and the status and error codes. Not yet modelled." },
  { key := "x-18013-5-issuer-data-auth", spec := "ISO/IEC 18013-5:2021", clause := "§9.1.2, §9.1.2.4, §9.3.1",
    guide := "§4.2.1.2, §4.2.1.3, §4.2.2",
    statement := "Issuer data authentication: that the data was issued by a trusted issuer, is unchanged, and is within its validity. The guide cites §9.3.1 in one profile and §9.1.2 in the others. Not yet modelled." },
  { key := "x-18013-5-mdoc-auth", spec := "ISO/IEC 18013-5:2021", clause := "§9.1.3",
    guide := "§4.2.1.2, §4.2.1.3, §4.2.2",
    statement := "Mdoc authentication: that the response comes from the device the credential was issued to. Not yet modelled." },
  { key := "x-18013-5-reader-auth", spec := "ISO/IEC 18013-5:2021", clause := "§9.1.4",
    guide := "§4.2.1.2, §4.2.2",
    statement := "Reader authentication: how a wallet checks who is asking. Not yet modelled." },
  { key := "x-18013-5-session", spec := "ISO/IEC 18013-5:2021", clause := "§9.1.1.4, §9.1.1.5, §9.1.5, §9.1.5.1, §9.1.5.2",
    guide := "§4.2.1.2, §4.2.2",
    statement := "Session encryption, session keys, the session transcript, the cipher suites and session termination. Not yet modelled." },
  { key := "x-18013-5-engagement", spec := "ISO/IEC 18013-5:2021", clause := "§8.2.1.1, §8.2.2.1, §8.2.2.3, §8.3.3.1.1 to §8.3.3.1.3",
    guide := "§4.2.2",
    statement := "Device engagement by QR code or NFC, and data transfer over Bluetooth low energy, NFC or Wi-Fi Aware. Not yet modelled." },
  { key := "x-23220-4-reader-and-certificates", spec := "ISO/IEC TS 23220-4:2026", clause := "Annex A, §A.1.4, §A.3.1, §A.3.4; Annex E, §E.2.1, §E.2.2",
    guide := "§4.2.1.2, §4.2.1.3",
    statement := "Reader authentication, issuer validation, certificate validation, and example device requests. Not yet modelled." },
  { key := "x-openid4vp", spec := "OpenID for Verifiable Presentations 1.0", clause := "§5, §5.1, §5.2, §5.9.3, §6, §6.1.1.1, §8.1, §8.5, §8.6, Appendix A, §A.2, §A.3.2, §B.2.2, §B.2.4, §B.2.5, §B.2.6.2",
    guide := "§4.2.1.3",
    statement := "The authorization request and its parameters, the DCQL query language, the response and its validation, error responses, the DC API profile, and the mdoc session transcript. Not yet modelled." },
  { key := "x-haip", spec := "OpenID4VC High Assurance Interoperability Profile 1.0", clause := "§5, §5.2, §5.3.1",
    guide := "§4.2.1.3",
    statement := "The security and privacy profile both verifier and wallet must comply with. Not yet modelled." },
  { key := "x-hpke", spec := "IETF RFC 9180 (HPKE)", clause := "the mechanism as a whole",
    guide := "§4.2.1.2",
    statement := "The encryption of the response in the mdoc profile. Not yet modelled." },
  { key := "x-cose", spec := "IETF RFC 9052 (COSE)", clause := "COSE_Key, COSE_Sign1",
    guide := "§4.2.1.2, §4.2.2",
    statement := "The key and signature formats. Not yet modelled." },
  { key := "x-rfc5280", spec := "IETF RFC 5280", clause := "certificates and certificate chains",
    guide := "§2",
    statement := "What a certificate and a certificate chain are. Not yet modelled." },
  { key := "x-icao-9303-11", spec := "ICAO Doc 9303", clause := "Part 11, §5",
    guide := "§4.2.1.2, §4.2.1.3",
    statement := "The check of the document security object, which a verifier may make when a photoid carries data groups. Not yet modelled." },
  { key := "x-iata-cuws", spec := "IATA CUWS standard APIs", clause := "the APIs as a whole",
    guide := "§4.2.1.2, §4.2.1.3, §4.2.2",
    statement := "How a verifier touchpoint sends validated data to an identity management system. Not yet modelled." }
]

/-- The assumption a key names, if the list has it. -/
def assumptionOf? (key : String) : Option Assumption :=
  assumptions.find? (·.key == key)

end Rules.Core
