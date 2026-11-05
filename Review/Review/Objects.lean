import VersoManual
import Rules

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option pp.rawOnError true

#doc (Manual) "Objects" =>
%%%
tag := "objects"
%%%

The objects are the things the rules talk about.
Each card gives an object's description from its Lean docstring, then its fields or values, then the object as Lean states it.
A reading is a point the guide leaves undecided, kept as a parameter of the rules.

# Credentials

{docstring Rules.OneId.Mdoc +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.NameSpace +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.DataElement +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Value +hideStructureConstructor (label := "object")}

{docstring Rules.Core.Instant +hideStructureConstructor (label := "object")}

# What a check reports

{docstring Rules.OneId.Finding +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Advisory +hideStructureConstructor (label := "object")}

# The photoid

{docstring Rules.OneId.photoidDocType (label := "name")}

{docstring Rules.OneId.baseNameSpace (label := "name")}

{docstring Rules.OneId.photoidNameSpace (label := "name")}

{docstring Rules.OneId.dataGroupsNameSpace (label := "name")}

{docstring Rules.OneId.PhotoidReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.PhotoidTables +hideStructureConstructor (label := "external")}

{docstring Rules.OneId.ElementTable +hideStructureConstructor (label := "external")}

{docstring Rules.OneId.TableEntry +hideStructureConstructor (label := "external")}

{docstring Rules.OneId.Presence +hideStructureConstructor (label := "external")}

{docstring Rules.OneId.Encoding +hideStructureConstructor (label := "external")}

{docstring Rules.OneId.SourceDocument +hideStructureConstructor (label := "object")}

# The boarding pass

{docstring Rules.OneId.boardingPassDocType (label := "name")}

{docstring Rules.OneId.bcbpNameSpace (label := "name")}

{docstring Rules.OneId.bcbpStringId (label := "name")}

{docstring Rules.OneId.BoardingPassReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.Resolution792 +hideStructureConstructor (label := "external")}

# Validity

{docstring Rules.OneId.ExpiryReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.Journey +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.ValidityReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.DepartureReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.PhotoidValidityReading +hideStructureConstructor (label := "reading")}

# Travelers

{docstring Rules.OneId.Traveler +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Issued +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.MatchReading +hideStructureConstructor (label := "reading")}

# Requests and responses

{docstring Rules.OneId.Request +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.ElementRef +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Profile +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Consent +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Credential +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Presented +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Response +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.DeviceSignature +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.SessionTranscript +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Key +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Nonce +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Origin +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Issuer +hideStructureConstructor (label := "object")}

# What a wallet and a relying party decide

{docstring Rules.OneId.ConsentReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.AcceptanceReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.Refusal +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.IsoTranscripts +hideStructureConstructor (label := "external")}

{docstring Rules.OneId.PairReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.PairRefusal +hideStructureConstructor (label := "object")}

# The OpenID4VP profile

{docstring Rules.OneId.OpenId4Vp.AuthorizationRequest +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.OpenId4Vp.CredentialQuery +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.OpenId4Vp.Certificate +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.OpenId4Vp.RequestReading +hideStructureConstructor (label := "reading")}

{docstring Rules.OneId.OpenId4Vp.RequestFinding +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.OpenId4Vp.WalletFinding +hideStructureConstructor (label := "object")}

# The mdoc profile and proximity

{docstring Rules.OneId.MdocProfile.DeviceRequest +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.MdocProfile.RequestFinding +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Proximity.Session +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Proximity.Retrieval +hideStructureConstructor (label := "object")}

{docstring Rules.OneId.Proximity.SessionFinding +hideStructureConstructor (label := "object")}
