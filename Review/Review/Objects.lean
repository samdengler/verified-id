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
