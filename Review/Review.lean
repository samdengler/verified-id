import VersoManual
import Review.Status
import Review.Generated.Front
import Review.Overview
import Review.Generated.OID101
import Review.Generated.OID102
import Review.Generated.OID103
import Review.Generated.OID104
import Review.Generated.OID105
import Review.Generated.OID106
import Review.Generated.OID107
import Review.Generated.OID108
import Review.Generated.OID109
import Review.Generated.Questions
import Review.Objects
import Review.Generated.Assumptions
import Review.Generated.Ears

open Verso.Genre Manual
open Review

#doc (Manual) "Verified ID: One ID Rules for Review" =>
%%%
authors := ["Sam Dengler"]
shortTitle := "Verified ID"
%%%

This document describes the rules of IATA's One ID Technical Implementation Guide as a Lean model, for review by people who know the guide and the standards it builds on.
There is one chapter per requirement. Requirements OID-101 to OID-109 cover the credential data model: the photoid and the document it comes from, the boarding pass, how long each stays valid, and how the two are matched.
Every rule, guarantee, and example in them is drawn from the model and checked when the document is built.

```rawHtmlDef
Review.Generated.Front.html
```

{include 1 Review.Overview}

{include 1 Review.Generated.OID101}

{include 1 Review.Generated.OID102}

{include 1 Review.Generated.OID103}

{include 1 Review.Generated.OID104}

{include 1 Review.Generated.OID105}

{include 1 Review.Generated.OID106}

{include 1 Review.Generated.OID107}

{include 1 Review.Generated.OID108}

{include 1 Review.Generated.OID109}

{include 1 Review.Generated.Questions}

{include 1 Review.Objects}

{include 1 Review.Generated.Assumptions}

{include 1 Review.Generated.Ears}
