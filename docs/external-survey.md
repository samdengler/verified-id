# Survey of the public specifications the guide cites

The One ID guide builds on other specifications. This survey covers the ones that are public. For each clause the guide cites in one of them, it records what the guide says about the clause, what the clause says, and whether the two agree.

Read on 2026-11-05. `scripts/fetch-sources.sh` fetches the documents, and `sources/external.json` records the address, the SHA-256 and the section headings of each copy that was read. `scripts/check_survey.py` checks every clause cited below against those headings.

Several of these documents forbid copying, so each entry describes its clause in our own words and quotes at most a few words. The texts are not in the repository.

Only cited clauses were read, with the clauses they depend on to be understood. A clause this survey does not list was not read for this project, and nothing here says what it contains.

## Documents read

The printed version is what the fetched copy says about itself. `sources/external.json` has the same strings, and the build fails if this table differs from it.

| Key | Document | The guide names | The copy prints |
| --- | --- | --- | --- |
| `openid4vp` | OpenID for Verifiable Presentations 1.0 | version 1.0 published 9 July 2025 | OpenID for Verifiable Presentations 1.0, 9 July 2025, Final |
| `haip` | OpenID4VC High Assurance Interoperability Profile 1.0 | version 1.0 published 24 December 2025 | OpenID4VC High Assurance Interoperability Profile 1.0, 24 December 2025, Final |
| `openid4vci` | OpenID for Verifiable Credential Issuance 1.0 | version 1.0 published 16 September 2025 | OpenID for Verifiable Credential Issuance 1.0, 16 September 2025, Final |
| `w3c-dc-api` | W3C Digital Credentials | draft of 16 July 2026 | W3C Working Draft, 16 July 2026 |
| `icao-9303-10` | ICAO Doc 9303 Part 10 | no version named, and no address given | Eighth Edition, 2021, Part 10: Logical Data Structure |
| `icao-9303-11` | ICAO Doc 9303 Part 11 | no version named | Eighth Edition, 2021, Part 11: Security Mechanisms for MRTDs |
| `iata-bcbp-guide` | IATA Bar Coded Boarding Pass Implementation Guide | the open implementation guide, listed under Resolution 792 | IMPLEMENTATION GUIDE, Effective Date: 1st June, 2018, Seven Edition |
| `rfc8949` | IETF RFC 8949 (CBOR) | no version named | Request for Comments: 8949, December 2020 |
| `rfc9052` | IETF RFC 9052 (COSE) | no version named | Request for Comments: 9052, August 2022 |
| `rfc9180` | IETF RFC 9180 (HPKE) | no version named | Request for Comments: 9180, February 2022 |
| `rfc5280` | IETF RFC 5280 | no version named | Request for Comments: 5280, May 2008 |

Differences between what the guide names and what is at the address:

* The address the guide gives for OpenID4VP holds the latest revision with errata. The text as approved is at the same address ending in `-final.html`. On the day of reading the two differed in one line, a reference to the issuance specification. For the high assurance profile and the issuance specification the two addresses held the same bytes.
* The guide's reference list has no entry for ICAO Doc 9303 Part 10, which §4.1.1 names. The copy read is at the address the guide gives for Part 11, with `p10` in place of `p11`.
* Both ICAO files are the consolidated text with Amendment No. 1, later than the edition year they print.
* The RFCs were fetched as plain text from the RFC Editor. The guide links the IETF datatracker pages for the same documents.
* The guide's reference list puts IATA's implementation guide beside Resolution 792, and §4.1.2 requires the resolution. The implementation guide says it is "not a definitive or binding document" (§1) and leaves the format of each item to the resolution.

## Documents not read

| Document | Why |
| --- | --- |
| ISO/IEC 18013-5:2021 | Sold by ISO. |
| ISO/IEC TS 18013-7:2025 | Sold by ISO. |
| ISO/IEC TS 23220-2:2026 | Sold by ISO. |
| ISO/IEC TS 23220-4:2026 | Sold by ISO. |
| IATA Resolution 792 | Sold by IATA, in the Passenger Services Conference Resolutions Manual. |
| One ID business requirements documents | Not public. |
| IATA CUWS standard APIs | Not fetched. The guide cites no clause of them, and the model does not reach the hand-off to the identity management system. |
| RFC 2119, RFC 8174, RFC 8610 | Not fetched. The guide cites them for its requirement words and for the notation of its examples. |

The public specifications cite the ISO documents in turn. Where a clause below rests on one, the entry says so and stops there.

## How to read the tables

The verdict in the last column is one of three words.

* **Agrees**: the clause says what the guide says it does.
* **Adds**: the clause agrees and says more that bears on the model. The addition is in the entry.
* **Differs**: the clause does not say what the guide says, or the citation points at another section.

A clause number is the specification's own. A section of the One ID guide is written as "guide §4.2.1.3".

## OpenID for Verifiable Presentations 1.0

Document: `openid4vp`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §2 | guide §2 | The guide's terms follow it. | It is the terminology section. | Agrees |
| §5 | guide §4.2.1.3, step 2 | The verifier must create an authorization request as the clause defines. | It defines the request. The wallet must process the query in it, and must ignore a parameter it does not recognise, other than transaction data. | Agrees |
| §5.1 | guide §4.2.1.3, step 2, item 6 | The verifier supplies encryption keys made for the request, in `client_metadata`. | `client_metadata` may carry a key set for encrypting the response, and the clause says this lets a verifier pass keys made for the one request. Those keys must not be used to check the request's signature. The clause makes neither the keys nor their freshness a must. The high assurance profile does (HAIP §5). | Agrees |
| §5.2 | guide §4.2.1.3, step 2, item 9 | The nonce and `state` must be set as the clause says. | The nonce is required. The verifier must make it fresh and random for every request, with "sufficient entropy" and no number, and keep it with its session. `state` is required only in the case §5.3 describes, a presentation requested without a holder binding proof, and §5.3 exempts the DC API from that case. | Differs for `state`. Adds for the nonce. |
| §5.9.3 | guide §4.2.1.3, step 2, item 2 | The client identifier has the prefix `x509_hash` and a hash of the verifier's certificate. | The identifier is the SHA-256 hash of the verifier's certificate. The request must be signed with the key of that certificate, and the wallet must validate the signature and the certificate's chain. Over the DC API, the clause's second paragraph leaves it to the wallet whether it validates the signature by these rules. | Adds. The guide's list of a wallet's checks gives the signature check no requirement word (C-73). |
| §6 | guide §4.2.1.3, step 1 | The verifier must write a DCQL query as the clause defines. | It defines the query. §6.4 adds the rules for answering it: a wallet must not send a selectively disclosable claim that the query did not select, and must not return a credential if it cannot deliver every claim asked of it. | Adds |
| §6.4.1 | not cited | | A wallet that cannot deliver every claim the verifier asks of a credential must not return that credential. | Adds. The guide does not say what a wallet does when a holder approves only part of a request (C-105). |
| §6.1.1.1 | guide §4.2.1.3, step 2, item 8 | Verifier and wallet must support the authority key identifier query. | The query names certificate authorities by key identifier, matched against the certificate chain inside the credential. §6.1 says a returned credential should match, and that the verifier must still check on its own that the issuer is trusted. | Adds |
| §8.1 | guide §4.2.1.3, step 4 | The wallet must build the token as the clause says. | The token is an object with one entry for each credential query answered, holding the presentations for it. | Agrees |
| §8.5 | guide §4.2.1.3, steps 4 and 6 | Errors follow the clause. | It lists the error codes. Over the DC API an error is returned as the response's data (§A.4). | Agrees |
| §8.6 | guide §4.2.1.3, step 5, item 2 | The verifier must validate the token as the clause says. | The verifier must check the token's format, the integrity and authenticity of each presentation, that what came back meets the query, that a holder binding proof is present and valid, including the replay checks of §14.1, and what its own policy requires, "if applicable". It names revocation as an example of policy. It names no check of the validity period of an mdoc. §14.9 adds that a verifier must not rely on the wallet to enforce the query. | Adds |
| §14.9 | not cited | | A verifier must not rely on the wallet to enforce the constraints of its query, and must make its own checks on what is returned. | Adds. With §8.6, which has the verifier check that what is returned satisfies the request as §6.4 describes and discard a presentation that fails a check, it bears on a response with more than was asked; neither says so in so many words (C-76). |
| Appendix A | guide §4.2.1.3, opening | It must be followed for the protocol. | It defines OpenID4VP over the DC API: the protocol values, the request parameters that are supported, and the response. `state` is not among the parameters (§A.2). The response is bound to the verifier's origin, where the other flows use the client identifier (§A.4, §A.5). | Adds |
| §A.2 | guide §4.2.1.3, step 2, item 5 | The expected origins must be set, as the clause requires for a signed request. | `expected_origins` is required with a signed request. The wallet must compare it with the origin of the request and return an error when none matches. | Adds |
| §A.3.2 | guide §4.2.1.3, step 3 | The request must be signed as the clause says. | A verifier may sign its request. The clause does not require it. The compact form is the one the protocol value `openid4vp-v1-signed` names (§A.1). | Agrees. The must is the guide's own. |
| §B.2.2 | guide §4.2.1.3, step 2, item 7 | `vp_formats_supported` must be used as the clause says. | Under `mso_mdoc` it holds two optional lists of algorithm identifiers, one for the issuer's signature and one for the device's. | Agrees |
| §B.2.4 | guide §4.2.1.3, step 1 | `intent_to_retain` is optional. | It is optional, and stands for the member of the same meaning in the ISO device request. | Agrees |
| §B.2.5 | guide §4.2.1.3, step 4 | The token's value is the encoded device response. | It is. The clause adds that the device response holds a signature or a MAC over the session transcript. | Adds |
| §B.2.6.2 | guide §4.2.1.3, steps 4 and 5 | The session transcript is set, and rebuilt, as the clause defines. | Its first two members are null. The third is a fixed name and the SHA-256 hash of three values: the origin of the request, the nonce, and the thumbprint of the verifier's encryption key. With an encrypted response the thumbprint is required. The guide's sample has this structure. | Agrees |

## OpenID4VC High Assurance Interoperability Profile 1.0

Document: `haip`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §2 | guide §2 | The guide's terms follow it. | It is the terminology section. | Agrees |
| §4 | guide Annex A | Issuance should be profiled as the clause says. | It is the profile of issuance. Annex A is informative, so the clause was not surveyed further. | Agrees |
| §5 | guide §4.2.1.3, step 2 and item 8 | The request should comply with it, and it requires the authority key identifier query. | For every OpenID4VP flow: the response type `vp_token`, the `x509_hash` client identifier for a signed request, DCQL, an encrypted response, an encryption key made for each request, and support for the authority key identifier query. It adds that the certificate that signs a request must not be self-signed, and that the trust anchor's certificate must not travel with the request. | Adds |
| §5.2 | guide §4.2.1.3, step 2 | The request should comply with it. | Over the DC API: the response mode `dc_api.jwt` and Appendix A of OpenID4VP are required. A wallet must support unsigned, signed and multi-signed requests, and a verifier at least one of them. | Adds. The guide's rule that a request is always signed is narrower, and the profile allows it. |
| §5.3.1 | guide §4.2.1.3, step 2 | The request should comply with it. | For mdoc: the format `mso_mdoc`, and a separate device response for each mdoc returned. An issuer may include a revocation mechanism in an mdoc. | Adds |
| §10, §11 | guide §4.2.1.3, opening | The profile's security and privacy considerations take precedence over those of Appendix A of OpenID4VP. | For the DC API, the profile's two sections name OpenID4VP §A.5 and §A.6 as the considerations that apply, and add notes on testing, key sizes and key attestations. | Differs. The profile points to the considerations the guide says it replaces. |
| §3.4 | not cited | | The profile puts trust management out of scope: who may issue, hold or receive a type of credential, and how root certificates are obtained. | Adds. The guide leaves the trust model out as well (C-01), so no document read here defines it. |

## W3C Digital Credentials, Working Draft of 16 July 2026

Document: `w3c-dc-api`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §1 | guide §4.2.1.1 | The details and goals of the API. | The introduction, marked non-normative. Its goals include a request the user agent can inspect, a response the user agent need not be able to read, and a user who mediates every exchange. | Agrees |
| §2.1 | guide §4.2.1.1 | Example 1 shows feature detection. | It does. The section is marked non-normative. | Agrees |
| §2.2 | guide §4.2.1.1 | Example 3 shows how to check protocol support. | Example 3 checks several protocol identifiers with `userAgentAllowsProtocol`. | Agrees |
| §2.3 | guide §4.2.1.1 | An example of a request and of handling the response. | Example 5 calls `navigator.credentials.get` with a list of requests, each a protocol and its data, and posts the result to the verifier's server. | Agrees |
| §2.4 | guide Annex A | An example of issuance over the API. | It is. Annex A is informative, so the clause was not surveyed further. | Agrees |
| §3 | guide §2 | The guide's terms follow it. | §3 is the scope. The terms are in §4. | Differs |
| §5 | guide §4.2.1.1, §4.2.1.2, §4.2.1.3 | It defines the protocol identifiers `openid4vp-v1-signed` and `org-iso-mdoc`. | It lists four presentation protocols: three OpenID4VP ones, unsigned, signed and multi-signed, and `org-iso-mdoc`, which it refers to ISO/IEC TS 18013-7 Annex C. | Agrees |

The guide tells a verifier to make these checks "in the same order" with a must. The sections it cites for them are examples and carry no requirement of their own. The draft says of itself that it may be replaced at any time, and the guide notes the same.

## ICAO Doc 9303 Part 10

Document: `icao-9303-10`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §4.7.2 | guide §4.1.1 | The portrait must hold "dg2 or equivalent image data" from the passport. The guide cites Part 10 as a whole. | Data group 2 is the image of the holder's face and is mandatory on the chip. It is a biometric template that can hold from one to nine encodings of the face, each with a header (§4.7.2.1, §4.7.2.2). | Adds. Data group 2 is more than one image, so the portrait and `dg2` hold the same bytes only if the portrait's encoding is the whole template. The encoding of the portrait is in ISO/IEC TS 23220-4 Table C.1, which was not read. |
| §4.6.2 | guide §4.1.1 | The data groups namespace holds the document security object with the data groups. | The object is mandatory on the chip, is signed by the issuing State, and holds a hash of each data group (§4.5.2). | Agrees |

## ICAO Doc 9303 Part 11

Document: `icao-9303-11`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §5 | guide §4.2.1.2, step 6 and §4.2.1.3, step 5 | A verifier may check the document security object as the clause defines, when a photoid carries the data groups. | The check validates a certificate chain from a trust anchor to the certificate that signed the object, verifies the object's signature, and compares the hash of each data group read with the hash in the object (§5.1.1). The clause says the check shows the content is authentic and unchanged, and does not show that it was not copied. | Adds |

The check needs trust anchors for passport signing certificates. The guide's lists of trusted issuers are for the issuers of the mdoc, and the guide does not say where the passport anchors come from. The check covers the data groups. It says nothing about the `portrait` element unless a verifier also compares that element with data group 2.

## IATA Bar Coded Boarding Pass Implementation Guide, seventh edition

Document: `iata-bcbp-guide`

The guide requires the boarding pass string to follow Resolution 792 and lists this document beside it. It cites no clause of it.

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §2.2.1 | guide §4.1.2 | The string must follow Resolution 792, which decides its mandatory elements. | A boarding pass is issued for each passenger, and one string holds one flight leg or several. Items are mandatory, conditional or for an airline's own use. The passenger name is a mandatory item, padded to a fixed number of characters, and the clause notes that airline systems do not carry every character of a name over correctly. The format and the allowed values of each item are in Attachments A and C of the resolution. | Adds |
| §2.2.2 | guide §4.1.2 | The same. | For the encoding of a flight leg the section refers the reader to the resolution and says nothing else. | Agrees. The public guide does not replace the resolution. |
| §2.2.3 | guide §4.1.2 | The guide names no version of the resolution. | The format has versions. The seventh dates from 2018, and the clause recommends that airlines support the latest and the one before it. | Adds |
| §2.2.5 | not cited | | A string may carry an optional security item with an airline's digital signature over the bar code data. | Adds. A boarding pass string can carry a signature of its own, apart from the mdoc's. |
| §2.3.5 | not cited | | Some airlines issue one boarding pass for an adult travelling with an infant, and others issue two. | Adds. The model gives a credential one subject (C-104). |

## IETF RFCs

Documents: `rfc8949`, `rfc9052`, `rfc9180`, `rfc5280`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| RFC 8949 §3.1 | guide §4.1.2 | The boarding pass string is a text string as CBOR defines it. | A text string is major type 3, encoded as UTF-8. | Agrees |
| RFC 9052 §7 | guide §4.2.1.2, step 1 | The recipient's public key is a COSE key. | A COSE key is a map of key parameters. | Agrees |
| RFC 9052 §4.2 | guide §4.2.2 | Reader authentication is a COSE_Sign1 structure. | COSE_Sign1 carries one signature over a payload. | Agrees |
| RFC 9180 §5 | guide §4.2.1.2, step 6 | The response is decrypted with hybrid public key encryption, as ISO/IEC TS 18013-7 Annex C specifies. | It defines the encryption of a message to a recipient's public key. The parameters the mdoc profile uses are in the ISO annex, which was not read. | Agrees |
| RFC 5280 §3.1 | guide §2 | A certificate is a signed structure that binds a public key to an identity. | It does, signed by a certification authority. A chain of certificates leads back to a key the user already trusts (§3.2), and validating a chain checks each certificate's signature, its validity period and that it is not revoked (§6.1.3). | Adds. The guide puts the revocation of credentials out of scope (C-02). The validation of the certificates it relies on includes revocation. |

## OpenID for Verifiable Credential Issuance 1.0

Document: `openid4vci`

| Clause | Cited in | What the guide says about it | What the clause says | Verdict |
| --- | --- | --- | --- | --- |
| §2 | guide §2 | The guide's terms follow it. | It is the terminology section. | Agrees |

The guide cites the rest of this document from Annex A, which is informative and outside this project's scope. It was not surveyed further.

## Where the guide and the specifications differ

1. **`state` in the OpenID4VP profile.** Guide §4.2.1.3 says the nonce and `state` must be set as OpenID4VP §5.2 says. That clause requires `state` only for a presentation without a holder binding proof, and §5.3 exempts the DC API. Appendix A, which the guide says must be followed, does not define `state` over the DC API, and a wallet ignores it (§A.2). The guide's own example request has no `state`.
2. **Which considerations take precedence.** Guide §4.2.1.3 says the high assurance profile's security and privacy considerations take precedence over those of Appendix A of OpenID4VP. For the DC API the profile's own sections point to OpenID4VP §A.5 and §A.6 (HAIP §10, §11).
3. **The W3C terminology section.** Guide §2 cites §3 of the W3C draft for terms. In the draft of 16 July 2026, §3 is the scope and §4 the terminology.
4. **A reference without an entry.** Guide §4.1.1 names ICAO Doc 9303 Part 10. The reference list has Part 11 only.

No clause the guide cites in a public specification is missing from the copy that was read.

## What the reading settled, and what it did not

Nine open points were marked as answered by reading a cited clause. Two of the clauses are in public documents.

| Entry | Clause it waited on | Outcome |
| --- | --- | --- |
| C-72 The nonce and state | OpenID4VP §5.2 and Appendix A, HAIP §5 | Read. `state` is not required, and not defined, over the DC API. The nonce is fresh for every request. The minimum entropy is not given as a number, so that part is now a decision. The lookup is removed. |
| C-102 What a boarding pass string contains | IATA Resolution 792 and its public guide | Partly read. The public guide gives the kinds of item, says the passenger name is mandatory, and allows several legs in one string. The list of items, their sizes and the form of dates are in the resolution's Attachments A and C. The lookup stays, narrowed to those attachments. |
| C-25 Whether names may repeat | ISO/IEC 18013-5 §8.3.1, §8.3.2 | Not read. The document is sold. |
| The portrait of a photoid (OID-101.5) | ISO/IEC TS 23220-4 Table C.1 | Not read. ICAO Part 10 adds that data group 2 is a template and not one image, which bears on OID-101.7. |
| C-44 Validity at the end instant | ISO/IEC 18013-5 §9.3.1 | Not read. |
| C-98 A start of validity | ISO/IEC 18013-5 §9.3.1 | Not read. |
| C-103 What Tables C.1 to C.3 list | ISO/IEC TS 23220-4 Annex C | Not read. |
| C-65 What the session transcript of the mdoc profile contains | ISO/IEC TS 18013-7 Annex C §C.5 | Not read. |
| C-101 Whether issuer data authentication includes validity | ISO/IEC 18013-5 §9.1.2, §9.3.1 | Not read. OpenID4VP §8.6 names no validity check for an mdoc, so the public text does not settle it either. |

The reading added one entry to the survey: C-104, a boarding pass that covers an adult and an infant.

Three things the public specifications leave where the guide left them:

* **The trust model.** The high assurance profile puts trust management out of scope (HAIP §3.4), and OpenID4VP tells a verifier to check on its own that an issuer is trusted (§6.1). Neither says which issuers or verifiers are trusted.
* **Refusing extra data.** OpenID4VP forbids a wallet to send a claim the query did not select (§6.4), has the verifier check that what is returned satisfies the request as §6.4 describes and discard a presentation that fails a check (§8.6), and tells it not to rely on the wallet (§14.9). It does not say in so many words that a presentation with more than was asked fails that check.
* **Expiry in the OpenID4VP profile.** No clause read here requires a verifier to refuse an mdoc whose validity has ended.
