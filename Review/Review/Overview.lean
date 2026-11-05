import VersoManual

open Verso.Genre Manual

#doc (Manual) "Overview" =>
%%%
tag := "overview"
%%%

IATA's One ID Technical Implementation Guide says how a passenger's wallet holds two digital credentials, a photoid and a boarding pass, and how it presents them to an airline or an airport.
This document covers the first part: what each credential must contain, how long it stays valid, and how the two are matched to one traveler.
The presentation flows come next.

The rules are written as a Lean model.
Each object is a Lean type, each rule is a Lean function, and each guarantee is a Lean theorem.
A guarantee is either proven, which means Lean checked a proof that it holds for every input, or open, which means it has no proof and is marked as a question for the business.
Each open guarantee has a counterexample: an example the build computes shows the guide as written allowing a case the guarantee forbids.

# Sources

The model is written from the approved version 26.3 of IATA's One ID Technical Implementation Guide, section by section.
IATA publishes [the same text](https://standards.atlassian.net/wiki/spaces/OneID/pages/2947416082/Technical+Implementation+Guide), and describes the programme the guide belongs to on its [One ID page](https://www.iata.org/en/programs/passenger/one-id/).
The guide states no license, so this document cites it by section number, describes its rules in its own words, and quotes at most a few words.
This is a proof of concept. It is not affiliated with or endorsed by IATA, and it is not an implementation of the standard.

The guide builds on ISO, OpenID, W3C, IETF, ICAO and IATA specifications.
The public ones (OpenID, W3C, IETF, ICAO, and IATA's guide to the boarding pass bar code) were fetched and read, and what this document says about them comes from their text, with the clause.
The ISO/IEC documents and IATA Resolution 792 are sold and were not read: from each of those the model takes only what the guide says about it.
Where a rule depends on the content of an external table or format, that content is a parameter of the rule, and a guarantee is proven only when it holds for every content the external clause could have.
*Assumptions about external specifications* lists every such dependency with its citation.

# Readings

Where the guide is vague or silent, the rule takes the undecided part as a parameter, called a reading.
A guarantee counts as proven only when it holds under every reading.
When one reading breaks it, the guarantee is open, an example shows the case under that reading, and the chapter says which reading would make it hold.
The model never picks a reading for the business.

# How to read this document

Each requirement has its own chapter.
A requirement chapter gives:

 * the rule, with its EARS statement, user story and acceptance criteria;
 * the sections of the guide it was written from, and the external specifications it relies on;
 * how each acceptance criterion is checked, and its status;
 * the guarantees Lean proves about the rule;
 * the examples the build computes, as Given, When and Then, with the result Lean computed.

After the requirements, *Open questions* lists what the guide does not settle, *Objects* describes the credentials, findings and readings the rules talk about, *Assumptions about external specifications* lists what the model takes on trust, and *EARS requirements* lists every requirement statement in one table.

Two other pages show the same model, and the bar at the top of every page links both: the [progress page](../progress/) gives the status of every rule and every candidate rule from the survey of the guide, and ranks the open questions by how much of the model each answer affects.
The [blueprint](../blueprint/index.html), written for the people who work on the Lean, restates the model as numbered definitions and theorems, with a [PDF](../blueprint/print.pdf) for printing.

# What is authored and what is computed

The prose in each docstring is written by hand and is to be reviewed against the Lean by a second person.
The examples, the proven or open status of each guarantee, and the dependency graph are computed by the build.
Nobody types a status or an example result by hand: if the model changes, the build changes them.
No rule has been confirmed by a subject matter expert yet. When one is, the chapter says who confirmed it and when.
