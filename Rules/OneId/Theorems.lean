import Rules.OneId.Mdoc
import Rules.OneId.Photoid
import Rules.OneId.BoardingPass
import Rules.OneId.Validity
import Rules.OneId.Traveler

/-!
# Guarantees about the credentials

Properties the credential rules are claimed to have.  A guarantee holds for
every reading of the guide and for every content the external tables and
Resolution 792 could have.  One left open is a question for the business,
with an example in {lit}`Rules.OneId.Examples` that shows the case.
-/

namespace Rules.OneId

open Rules.Core

/-! ## Data elements and their names -/

private theorem find?_of_nodup_key {α : Type} (key : α → String) (l : List α)
    (h : (l.map key).Nodup) (a : α) (ha : a ∈ l) :
    l.find? (fun x => key x == key a) = some a := by
  induction l with
  | nil => simp at ha
  | cons b l ih =>
    rw [List.map_cons, List.nodup_cons] at h
    rcases List.mem_cons.mp ha with rfl | ha'
    · simp
    · have hne : key b ≠ key a := fun heq => h.1 (heq ▸ List.mem_map_of_mem ha')
      simp [hne, ih h.2 ha']

/-- What it means for the names of a credential to be unique: no two
namespaces share a name, and no two data elements of one namespace share an
identifier. -/
theorem wellFormed_iff (m : Mdoc) :
    m.wellFormed = true ↔
      (m.nameSpaces.map (·.name)).Nodup ∧
        ∀ ns ∈ m.nameSpaces, (ns.elements.map (·.identifier)).Nodup := by
  simp [Mdoc.wellFormed]

/-- In a credential whose names are unique, every data element is found by the
name of its namespace and its identifier.  So a request can name one data
element, and a wallet can disclose that one alone. -/
@[checks "OID-106.1"]
theorem element_addressable (m : Mdoc) (h : m.wellFormed = true) (ns : NameSpace)
    (hns : ns ∈ m.nameSpaces) (e : DataElement) (he : e ∈ ns.elements) :
    m.element? ns.name e.identifier = some e.value := by
  obtain ⟨hn, hid⟩ := (wellFormed_iff m).mp h
  have h1 : m.nameSpace? ns.name = some ns := find?_of_nodup_key NameSpace.name _ hn ns hns
  have h2 : ns.elements.find? (fun x => x.identifier == e.identifier) = some e :=
    find?_of_nodup_key DataElement.identifier _ (hid ns hns) e he
  simp [Mdoc.element?, h1, NameSpace.element?, h2]

/-- A credential returns no value for a namespace name and an identifier when
none of its namespaces of that name holds a data element with that
identifier.  This covers a credential with no such namespace and one whose
namespace lacks the element. -/
@[checks "OID-106.2"]
theorem element_absent (m : Mdoc) (name identifier : String)
    (h : ∀ ns ∈ m.nameSpaces, ns.name = name → ∀ e ∈ ns.elements, e.identifier ≠ identifier) :
    m.element? name identifier = none := by
  unfold Mdoc.element?
  cases hf : m.nameSpace? name with
  | none => rfl
  | some ns =>
    have hmem : ns ∈ m.nameSpaces := List.mem_of_find?_eq_some hf
    have hname : ns.name = name := by simpa using List.find?_some hf
    have : ns.elements.find? (fun x => x.identifier == identifier) = none := by
      simp only [List.find?_eq_none]
      intro e he
      simpa using h ns hmem hname e he
    simp [NameSpace.element?, this]

/-! ## The parts of a credential check -/

private theorem docTypeFindings_nil (expected : String) (m : Mdoc) :
    docTypeFindings expected m = [] ↔ m.docType = expected := by
  unfold docTypeFindings
  split <;> simp_all

private theorem nameFindings_nil (m : Mdoc) (h : nameFindings true m = []) : m.wellFormed = true := by
  unfold nameFindings at h
  by_contra hw
  simp [hw] at h

private theorem photoid_parts (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) :
    docTypeFindings photoidDocType m = [] ∧ nameFindings r.repeatedNamesRefused m = [] ∧
      Photoid.baseFindings r t m = [] ∧
      Photoid.tableFindings r.photoidTableBinds t.photoid photoidNameSpace m = [] ∧
      Photoid.tableFindings r.dataGroupsTableBinds t.dataGroups dataGroupsNameSpace m = [] ∧
      Photoid.unlistedFindings r t m = [] ∧ Photoid.portraitFindings r m = [] := by
  simpa [Photoid.violations, List.append_eq_nil_iff, and_assoc] using h

private theorem boardingPass_parts (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) :
    docTypeFindings boardingPassDocType m = [] ∧ nameFindings r.repeatedNamesRefused m = [] ∧
      BoardingPass.stringFindings x m = [] ∧ BoardingPass.unlistedFindings r m = [] := by
  simpa [BoardingPass.violations, List.append_eq_nil_iff, and_assoc] using h

private theorem missingMandatory_nil (t : ElementTable) (ns : NameSpace)
    (h : missingMandatory t ns = []) (id : String) (hid : id ∈ t.mandatory) :
    (ns.element? id).isSome = true := by
  unfold missingMandatory at h
  have := List.filter_eq_nil_iff.mp h id hid
  exact Option.isSome_iff_ne_none.mpr (by simpa using this)

private theorem nameSpace?_mem (m : Mdoc) (name : String) (ns : NameSpace)
    (h : m.nameSpace? name = some ns) : ns ∈ m.nameSpacesNamed name := by
  have h' : m.nameSpaces.find? (fun x => x.name == name) = some ns := h
  have h2 := List.find?_some h'
  exact List.mem_filter.mpr ⟨List.mem_of_find?_eq_some h', h2⟩

private theorem named_mem (m : Mdoc) (name : String) (ns : NameSpace) (hns : ns ∈ m.nameSpaces)
    (hname : ns.name = name) : ns ∈ m.nameSpacesNamed name :=
  List.mem_filter.mpr ⟨hns, by simp [hname]⟩

private theorem nameSpace?_isSome (m : Mdoc) (name : String) (h : m.nameSpacesNamed name ≠ []) :
    (m.nameSpace? name).isSome = true := by
  obtain ⟨ns, hns⟩ := List.exists_mem_of_ne_nil _ h
  have := List.mem_filter.mp hns
  exact List.find?_isSome.mpr ⟨ns, this.1, this.2⟩

private theorem baseIn_nil (r : PhotoidReading) (t : PhotoidTables) (ns : NameSpace)
    (h : Photoid.baseIn r t ns = []) :
    missingMandatory t.base ns = [] ∧ wronglyEncoded t.base ns = [] ∧
      (r.portraitRequired = true → (ns.element? portraitId).isSome = true) := by
  unfold Photoid.baseIn at h
  simp only [List.append_eq_nil_iff, List.map_eq_nil_iff] at h
  obtain ⟨⟨hmiss, henc⟩, hport⟩ := h
  refine ⟨hmiss, henc, ?_⟩
  intro hr
  by_cases hm : portraitId ∈ t.base.mandatory
  · exact missingMandatory_nil t.base ns hmiss _ hm
  · by_contra hp
    simp [hr, hm] at hport
    exact hp (Option.isSome_iff_ne_none.mpr hport)

/-- What an accepted photoid's base identity namespaces are sure to hold: there
is one, and every namespace of that name meets the requirements. -/
private theorem photoid_base (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) :
    (m.nameSpace? baseNameSpace).isSome = true ∧
      ∀ ns ∈ m.nameSpacesNamed baseNameSpace, Photoid.baseIn r t ns = [] := by
  have hb := (photoid_parts r t m h).2.2.1
  cases hc : m.nameSpacesNamed baseNameSpace with
  | nil => simp [Photoid.baseFindings, hc] at hb
  | cons a l =>
    simp only [Photoid.baseFindings, hc] at hb
    exact ⟨nameSpace?_isSome m _ (by simp [hc]), fun ns hns => List.flatMap_eq_nil_iff.mp hb ns hns⟩

/-! ## The photoid -/

/-- An accepted photoid has the photoid document type, under every reading and
every content of the tables. -/
@[checks "OID-101.1"]
theorem photoid_docType (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) : m.docType = photoidDocType :=
  (docTypeFindings_nil _ m).mp (photoid_parts r t m h).1

/-- An accepted photoid has the base identity namespace, under every reading
and every content of the tables. -/
@[checks "OID-101.2"]
theorem photoid_has_base (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) : (m.nameSpace? baseNameSpace).isSome = true :=
  (photoid_base r t m h).1

/-- An accepted photoid holds every data element Table C.1 marks mandatory in
the base identity namespace, whatever the table lists: a request for one
returns a value. -/
@[checks "OID-101.3"]
theorem photoid_has_mandatory_base (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) (id : String) (hid : id ∈ t.base.mandatory) :
    (m.element? baseNameSpace id).isSome = true := by
  obtain ⟨hsome, hall⟩ := photoid_base r t m h
  obtain ⟨ns, hns⟩ := Option.isSome_iff_exists.mp hsome
  have hmiss := (baseIn_nil r t ns (hall ns (nameSpace?_mem m _ ns hns))).1
  simpa [Mdoc.element?, hns] using missingMandatory_nil t.base ns hmiss id hid

/-- In an accepted photoid, every data element of a base identity namespace
that Table C.1 lists has the encoding the table gives it, whatever the table
says, and in every copy if names repeat.  The model tells a text string, a
byte string and a yes or no value apart, and nothing finer. -/
@[checks "OID-101.4"]
theorem photoid_base_encoding (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) (ns : NameSpace) (hns : ns ∈ m.nameSpaces)
    (hname : ns.name = baseNameSpace) (e : DataElement) (he : e ∈ ns.elements) (entry : TableEntry)
    (hentry : t.base.entry? e.identifier = some entry) : entry.encoding.accepts e.value = true := by
  have henc := (baseIn_nil r t ns ((photoid_base r t m h).2 ns (named_mem m _ ns hns hname))).2.1
  unfold wronglyEncoded at henc
  have := List.filter_eq_nil_iff.mp henc e he
  simpa [hentry] using this

/-- Every accepted photoid has a portrait.

Open question for the business.  The guide says the portrait MUST hold the
image from the passport and that the business requirements need it, and it
also refers the presence of every base element to Table C.1 of ISO/IEC TS
23220-4, which this project has not read.  If the table does not mark the
portrait mandatory and the guide's sentence is read as a rule about the
portrait's content only, a photoid with no face image is accepted.  The
example {lit}`photoidWithoutPortrait` shows it.  Is the portrait mandatory in
a One ID photoid, whatever Table C.1 says? -/
@[open_question, checks "OID-101.5"]
theorem photoid_has_portrait (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) : (m.element? baseNameSpace portraitId).isSome = true := by
  sorry

/-- Under the reading that the guide itself requires the portrait, every
accepted photoid has one, whatever Table C.1 says. -/
theorem photoid_has_portrait_of_portraitRequired (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (hr : r.portraitRequired = true) (h : Photoid.violations r t m = []) :
    (m.element? baseNameSpace portraitId).isSome = true := by
  obtain ⟨hsome, hall⟩ := photoid_base r t m h
  obtain ⟨ns, hns⟩ := Option.isSome_iff_exists.mp hsome
  have hp := (baseIn_nil r t ns (hall ns (nameSpace?_mem m _ ns hns))).2.2
  simpa [Mdoc.element?, hns] using hp hr

/-- An accepted photoid carries only the three namespaces the guide lists, and
in each only data elements its table lists.

Open question for the business.  The guide lists three namespaces for a
photoid and refers to a table for each, and does not say the lists are closed.
Under the reading that they are not, a photoid with a fourth namespace, or
with a data element no table lists, is accepted, and a relying party that asks
for the whole credential receives data the guide does not describe.  The
example {lit}`photoidWithUnlistedData` shows it.  May a One ID photoid carry a
namespace or a data element the guide and its tables do not list? -/
@[open_question, checks "OID-101.6"]
theorem photoid_only_listed (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) :
    ∀ ns ∈ m.nameSpaces, ∃ table, t.tableOf ns.name = some table ∧
      ∀ e ∈ ns.elements, (table.entry? e.identifier).isSome = true := by
  sorry

/-- Under the reading that the lists are closed, an accepted photoid carries
only the three namespaces the guide lists, and in each only data elements its
table lists. -/
theorem photoid_only_listed_of_closed (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (hr : r.unlistedDataAllowed = false) (h : Photoid.violations r t m = []) :
    ∀ ns ∈ m.nameSpaces, ∃ table, t.tableOf ns.name = some table ∧
      ∀ e ∈ ns.elements, (table.entry? e.identifier).isSome = true := by
  have hu := (photoid_parts r t m h).2.2.2.2.2.1
  simp only [Photoid.unlistedFindings, hr, Bool.false_eq_true, ↓reduceIte,
    List.flatMap_eq_nil_iff] at hu
  intro ns hns
  have hin := hu ns hns
  unfold Photoid.unlistedIn at hin
  split at hin
  · simp at hin
  · rename_i table htable
    refine ⟨table, htable, fun e he => ?_⟩
    have := List.filter_eq_nil_iff.mp (List.map_eq_nil_iff.mp hin) e he
    exact Option.isSome_iff_ne_none.mpr (by simpa using this)

/-- When an accepted photoid carries both a portrait and a data group 2, they
are the same.

Open question for the business.  The guide says the portrait MUST hold "the
dg2 or equivalent image data" from the passport and does not say what
equivalent means or who checks it.  Under the reading that it is left to the
issuer, a photoid whose portrait differs from its own data group 2 is
accepted, so a touchpoint that matches a face against the portrait may be
matching a different image from the one the data group holds.  The example
{lit}`portraitDiffersFromDataGroup` shows it.  When a photoid carries data
group 2, must the portrait be that image, and must a relying party check
it? -/
@[open_question, checks "OID-101.7"]
theorem portrait_is_dg2 (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) (p d : Value)
    (hp : p ∈ m.values baseNameSpace portraitId)
    (hd : d ∈ m.values dataGroupsNameSpace dg2Id) : p = d := by
  sorry

/-- Under the reading that the portrait must be the same as data group 2, an
accepted photoid that carries both has the same value in each, in every copy
if names repeat. -/
theorem portrait_is_dg2_of_portraitIsDg2 (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (hr : r.portraitIsDg2 = true) (h : Photoid.violations r t m = []) (p d : Value)
    (hp : p ∈ m.values baseNameSpace portraitId)
    (hd : d ∈ m.values dataGroupsNameSpace dg2Id) : p = d := by
  have hf := (photoid_parts r t m h).2.2.2.2.2.2
  by_contra hne
  have hany : ((m.values baseNameSpace portraitId).any fun p =>
      (m.values dataGroupsNameSpace dg2Id).any fun d => p != d) = true :=
    List.any_eq_true.mpr ⟨p, hp, List.any_eq_true.mpr ⟨d, hd, by simpa using hne⟩⟩
  simp [Photoid.portraitFindings, hr, hany] at hf

/-- When an accepted photoid carries the photoid namespace, the namespace
holds every data element Table C.2 marks mandatory.

Open question for the business.  The guide recommends "this namespace and
data elements presence" as in Table C.2 in one sentence.  Read as one
recommendation, a photoid may carry the photoid namespace with any part of
the travel document data missing, and a relying party that finds the
namespace cannot count on any element in it.  The example
{lit}`photoidNameSpaceIncomplete` shows it.  Once the photoid namespace is
present, are the data elements Table C.2 marks mandatory required? -/
@[open_question, checks "OID-101.8"]
theorem photoid_nameSpace_complete (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) (ns : NameSpace)
    (hns : ns ∈ m.nameSpaces) (hname : ns.name = photoidNameSpace) :
    missingMandatory t.photoid ns = [] := by
  sorry

/-- Under the reading that Table C.2 binds once the photoid namespace is
present, the photoid namespace of an accepted photoid holds every data
element the table marks mandatory. -/
theorem photoid_nameSpace_complete_of_photoidTableBinds (r : PhotoidReading) (t : PhotoidTables)
    (m : Mdoc) (hr : r.photoidTableBinds = true) (h : Photoid.violations r t m = []) (ns : NameSpace)
    (hns : ns ∈ m.nameSpaces) (hname : ns.name = photoidNameSpace) :
    missingMandatory t.photoid ns = [] := by
  have hf := (photoid_parts r t m h).2.2.2.1
  simp only [Photoid.tableFindings, hr, ↓reduceIte, List.flatMap_eq_nil_iff, List.map_eq_nil_iff] at hf
  exact hf ns (named_mem m _ ns hns hname)

/-- When an accepted photoid carries the data groups namespace, the namespace
holds every data element Table C.3 marks mandatory.

Open question for the business.  The guide recommends the data groups
namespace and "presence of the data elements" as in Table C.3 in one
sentence, as it does for the photoid namespace.  Read as one recommendation, a
photoid may carry the data groups namespace with any data group missing.  The
example {lit}`dataGroupsNameSpaceIncomplete` shows it.  Once the data groups
namespace is present, are the data elements Table C.3 marks mandatory
required? -/
@[open_question, checks "OID-101.9"]
theorem dataGroups_nameSpace_complete (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) (ns : NameSpace)
    (hns : ns ∈ m.nameSpaces) (hname : ns.name = dataGroupsNameSpace) :
    missingMandatory t.dataGroups ns = [] := by
  sorry

/-- Under the reading that Table C.3 binds once the data groups namespace is
present, the data groups namespace of an accepted photoid holds every data
element the table marks mandatory. -/
theorem dataGroups_nameSpace_complete_of_dataGroupsTableBinds (r : PhotoidReading)
    (t : PhotoidTables) (m : Mdoc) (hr : r.dataGroupsTableBinds = true)
    (h : Photoid.violations r t m = []) (ns : NameSpace)
    (hns : ns ∈ m.nameSpaces) (hname : ns.name = dataGroupsNameSpace) :
    missingMandatory t.dataGroups ns = [] := by
  have hf := (photoid_parts r t m h).2.2.2.2.1
  simp only [Photoid.tableFindings, hr, ↓reduceIte, List.flatMap_eq_nil_iff, List.map_eq_nil_iff] at hf
  exact hf ns (named_mem m _ ns hns hname)

/-- The names in an accepted photoid are unique.

Open question for the business.  The guide leaves the structure of an mdoc to
ISO/IEC 18013-5 and does not say that namespace names and data element
identifiers are unique.  If they may repeat, a request for a name is
ambiguous: the example {lit}`repeatedIdentifier` shows a photoid with two
family names, of which a relying party receives one.  Is a credential in
which a name repeats rejected? -/
@[open_question, checks "OID-106.3"]
theorem photoid_names_unique (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc)
    (h : Photoid.violations r t m = []) : m.wellFormed = true := by
  sorry

/-- Under the reading that repeated names are refused, the names in an
accepted photoid are unique. -/
theorem photoid_names_unique_of_repeatedNamesRefused (r : PhotoidReading) (t : PhotoidTables)
    (m : Mdoc) (hr : r.repeatedNamesRefused = true) (h : Photoid.violations r t m = []) :
    m.wellFormed = true :=
  nameFindings_nil m (hr ▸ (photoid_parts r t m h).2.1)

/-- A photoid the system accepts was derived from a passport.

Open question for the business.  The terminology says a photoid can be
derived from a passport or an equivalent identity document.  §4.1.1 says the
values should always come from the passport, and that the portrait MUST hold
image data sourced from the passport.  Under the reading that the first
governs, a photoid derived from a national identity card is accepted, and
nothing a relying party must receive says so.  The example
{lit}`photoidFromAnIdentityCard` shows it.  May a One ID photoid be derived
from a document other than a passport? -/
@[open_question, checks "OID-109.1"]
theorem photoid_from_passport (r : PhotoidReading) (source : SourceDocument)
    (h : Photoid.sourceFindings r source = []) : source = .passport := by
  sorry

/-- Under the reading that a passport is required, a photoid the system
accepts was derived from a passport. -/
theorem photoid_from_passport_of_passportRequired (r : PhotoidReading) (source : SourceDocument)
    (hr : r.passportRequired = true) (h : Photoid.sourceFindings r source = []) :
    source = .passport := by
  by_contra hne
  simp [Photoid.sourceFindings, hr, hne] at h

/-! ## Recommendations for a photoid -/

/-- A photoid that lacks the photoid namespace is told so, as a
recommendation it does not follow. -/
@[checks "OID-102.1"]
theorem advises_photoid_nameSpace (t : PhotoidTables) (source : SourceDocument) (m : Mdoc)
    (h : m.nameSpace? photoidNameSpace = none) :
    Advisory.missingRecommendedNameSpace photoidNameSpace ∈ Photoid.advisories t source m := by
  simp [Photoid.advisories, Photoid.nameSpaceAdvisories, h]

/-- A photoid that lacks the data groups namespace is told so, as a
recommendation it does not follow. -/
@[checks "OID-102.1"]
theorem advises_dataGroups_nameSpace (t : PhotoidTables) (source : SourceDocument) (m : Mdoc)
    (h : m.nameSpace? dataGroupsNameSpace = none) :
    Advisory.missingRecommendedNameSpace dataGroupsNameSpace ∈ Photoid.advisories t source m := by
  simp [Photoid.advisories, Photoid.nameSpaceAdvisories, h]

/-- A photoid whose photoid namespace lacks the image captured at enrolment is
told so, whatever Table C.2 says about that image. -/
@[checks "OID-102.2"]
theorem advises_enrolment_portrait (t : PhotoidTables) (source : SourceDocument) (m : Mdoc)
    (ns : NameSpace) (hns : m.nameSpace? photoidNameSpace = some ns)
    (he : ns.element? enrolmentPortraitId = none) :
    Advisory.missingRecommendedElement photoidNameSpace enrolmentPortraitId ∈
      Photoid.advisories t source m := by
  by_cases hm : enrolmentPortraitId ∈ t.photoid.mandatory
  · have : enrolmentPortraitId ∈ missingMandatory t.photoid ns := by
      simp [missingMandatory, List.mem_filter, hm, he]
    simp [Photoid.advisories, Photoid.nameSpaceAdvisories, hns, this]
  · simp [Photoid.advisories, Photoid.nameSpaceAdvisories, hns, he, hm]

/-- A photoid derived from a document other than a passport is told so. -/
@[checks "OID-102.3"]
theorem advises_source_document (t : PhotoidTables) (m : Mdoc) :
    Advisory.notDerivedFromPassport ∈ Photoid.advisories t .other m := by
  simp [Photoid.advisories]

/-- No photoid is ever rejected for lacking the photoid namespace or the data
groups namespace: neither is among the requirements a photoid can break, under
every reading and every content of the tables. -/
@[checks "OID-102.4"]
theorem recommended_nameSpace_never_required (r : PhotoidReading) (t : PhotoidTables) (m : Mdoc) :
    Finding.missingNameSpace photoidNameSpace ∉ Photoid.violations r t m ∧
      Finding.missingNameSpace dataGroupsNameSpace ∉ Photoid.violations r t m := by
  have hb : ∀ n, n ≠ baseNameSpace → Finding.missingNameSpace n ∉ Photoid.baseFindings r t m := by
    intro n hn
    unfold Photoid.baseFindings
    split
    · simpa using hn
    · simp only [List.mem_flatMap, not_exists, not_and]
      intro ns _
      unfold Photoid.baseIn
      simp only [List.mem_append, List.mem_map, not_or, not_exists, not_and]
      refine ⟨⟨by simp, by simp⟩, ?_⟩
      split <;> simp
  have ht : ∀ n b tb nm, Finding.missingNameSpace n ∉ Photoid.tableFindings b tb nm m := by
    intro n b tb nm
    unfold Photoid.tableFindings
    split <;> simp
  have hu : ∀ n, Finding.missingNameSpace n ∉ Photoid.unlistedFindings r t m := by
    intro n
    unfold Photoid.unlistedFindings
    split
    · simp
    · simp only [List.mem_flatMap, not_exists, not_and]
      intro ns _
      unfold Photoid.unlistedIn
      split <;> simp
  have hp : ∀ n, Finding.missingNameSpace n ∉ Photoid.portraitFindings r m := by
    intro n
    unfold Photoid.portraitFindings
    split <;> simp
  have hd : ∀ n, Finding.missingNameSpace n ∉ docTypeFindings photoidDocType m := by
    intro n
    unfold docTypeFindings
    split <;> simp
  have hn : ∀ n, Finding.missingNameSpace n ∉ nameFindings r.repeatedNamesRefused m := by
    intro n
    unfold nameFindings
    split <;> simp
  constructor <;>
  · simp only [Photoid.violations, List.mem_append, not_or]
    exact ⟨⟨⟨⟨⟨⟨hd _, hn _⟩, hb _ (by decide)⟩, ht _ _ _ _⟩, ht _ _ _ _⟩, hu _⟩, hp _⟩

/-! ## The boarding pass -/

/-- An accepted boarding pass has the boarding pass document type, under every
reading and whatever Resolution 792 says. -/
@[checks "OID-103.1"]
theorem boardingPass_docType (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) : m.docType = boardingPassDocType :=
  (docTypeFindings_nil _ m).mp (boardingPass_parts r x m h).1

private theorem boardingPass_string (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) :
    (m.element? bcbpNameSpace bcbpStringId).isSome = true ∧
      ∀ ns ∈ m.nameSpacesNamed bcbpNameSpace, BoardingPass.stringIn x ns = [] := by
  have hs := (boardingPass_parts r x m h).2.2.1
  cases hc : m.nameSpacesNamed bcbpNameSpace with
  | nil => simp [BoardingPass.stringFindings, hc] at hs
  | cons a l =>
    simp only [BoardingPass.stringFindings, hc] at hs
    obtain ⟨h1, h2⟩ := List.append_eq_nil_iff.mp hs
    refine ⟨?_, fun ns hns => List.flatMap_eq_nil_iff.mp h2 ns hns⟩
    cases hel : m.element? bcbpNameSpace bcbpStringId with
    | none => simp [hel] at h1
    | some v => rfl

private theorem stringIn_nil (x : Resolution792) (ns : NameSpace) (h : BoardingPass.stringIn x ns = [])
    (e : DataElement) (he : e ∈ ns.elements) (hid : (e.identifier == bcbpStringId) = true) :
    ∃ s, e.value = .text s ∧ x.follows s = true := by
  unfold BoardingPass.stringIn at h
  have := List.flatMap_eq_nil_iff.mp h e (List.mem_filter.mpr ⟨he, hid⟩)
  cases hval : e.value with
  | text s =>
    refine ⟨s, rfl, ?_⟩
    by_contra hf
    simp [hval, hf] at this
  | bytes b => simp [hval] at this
  | flag b => simp [hval] at this
  | other d => simp [hval] at this

/-- An accepted boarding pass holds a boarding pass string: its namespace is
present, a request for the string returns a value, the value is a text string,
and the string follows Resolution 792. -/
@[checks "OID-103.2 OID-103.3 OID-103.4 OID-103.5"]
theorem boardingPass_has_string (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) :
    ∃ s, BoardingPass.bcbpString m = some s ∧ x.follows s = true := by
  obtain ⟨hsome, hall⟩ := boardingPass_string r x m h
  cases hns : m.nameSpace? bcbpNameSpace with
  | none => simp [Mdoc.element?, hns] at hsome
  | some ns =>
    cases he : ns.elements.find? (·.identifier == bcbpStringId) with
    | none => simp [Mdoc.element?, hns, NameSpace.element?, he] at hsome
    | some e =>
      have hid := List.find?_some he
      obtain ⟨s, hval, hfollows⟩ := stringIn_nil x ns (hall ns (nameSpace?_mem m _ ns hns)) e
        (List.mem_of_find?_eq_some he) hid
      exact ⟨s, by simp [BoardingPass.bcbpString, Mdoc.element?, hns, NameSpace.element?, he, hval], hfollows⟩

/-- In an accepted boarding pass, every boarding pass string is a text string
that follows Resolution 792, in every copy if names repeat. -/
@[checks "OID-103.4 OID-103.5"]
theorem boardingPass_strings_follow (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) (ns : NameSpace) (hns : ns ∈ m.nameSpaces)
    (hname : ns.name = bcbpNameSpace) (e : DataElement) (he : e ∈ ns.elements)
    (hid : e.identifier = bcbpStringId) : ∃ s, e.value = .text s ∧ x.follows s = true :=
  stringIn_nil x ns ((boardingPass_string r x m h).2 ns (named_mem m _ ns hns hname)) e he (by simp [hid])

/-- No credential is accepted both as a photoid and as a boarding pass, since
the two document types differ. -/
@[checks "OID-101.1 OID-103.1"]
theorem not_photoid_and_boardingPass (r : PhotoidReading) (t : PhotoidTables)
    (b : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (hp : Photoid.violations r t m = []) (hb : BoardingPass.violations b x m = []) : False := by
  have h1 := photoid_docType r t m hp
  have h2 := boardingPass_docType b x m hb
  rw [h1] at h2
  exact absurd h2 (by decide)

/-- An accepted boarding pass carries one namespace with one data element, the
boarding pass string.

Open question for the business.  The guide lists one namespace with one data
element and says a later version may add a namespace for separate data
elements.  It does not say whether a boarding pass may carry one today.
Under the reading that it may, a boarding pass with a second namespace is
accepted, and a relying party cannot tell what a boarding pass credential
contains from the guide alone.  The example
{lit}`boardingPassWithExtraNameSpace` shows it.  May a boarding pass
credential carry a namespace or a data element the guide does not list? -/
@[open_question, checks "OID-103.6"]
theorem boardingPass_only_listed (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) :
    ∀ ns ∈ m.nameSpaces, ns.name = bcbpNameSpace ∧ ∀ e ∈ ns.elements, e.identifier = bcbpStringId := by
  sorry

/-- Under the reading that the lists are closed, an accepted boarding pass
carries only the boarding pass namespace, and in it only the boarding pass
string. -/
theorem boardingPass_only_listed_of_closed (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (hr : r.unlistedDataAllowed = false) (h : BoardingPass.violations r x m = []) :
    ∀ ns ∈ m.nameSpaces, ns.name = bcbpNameSpace ∧ ∀ e ∈ ns.elements, e.identifier = bcbpStringId := by
  have hu := (boardingPass_parts r x m h).2.2.2
  simp only [BoardingPass.unlistedFindings, hr, Bool.false_eq_true, ↓reduceIte,
    List.append_eq_nil_iff, List.map_eq_nil_iff, List.filter_eq_nil_iff,
    List.flatMap_eq_nil_iff] at hu
  obtain ⟨h1, h2⟩ := hu
  intro ns hns
  have hname : ns.name = bcbpNameSpace := by simpa using h1 ns hns
  refine ⟨hname, fun e he => ?_⟩
  have := h2 ns (by simp [List.mem_filter, hns, hname])
  simpa using this e he

/-- The names in an accepted boarding pass are unique.

Open question for the business.  The guide does not say that namespace names
and data element identifiers are unique.  If they may repeat, a boarding pass
with two boarding pass strings is accepted, and a relying party receives one
of them.  The example {lit}`twoBoardingPassStrings` shows it.  Is a credential
in which a name repeats rejected? -/
@[open_question, checks "OID-106.3"]
theorem boardingPass_names_unique (r : BoardingPassReading) (x : Resolution792) (m : Mdoc)
    (h : BoardingPass.violations r x m = []) : m.wellFormed = true := by
  sorry

/-- Under the reading that repeated names are refused, the names in an
accepted boarding pass are unique. -/
theorem boardingPass_names_unique_of_repeatedNamesRefused (r : BoardingPassReading)
    (x : Resolution792) (m : Mdoc) (hr : r.repeatedNamesRefused = true)
    (h : BoardingPass.violations r x m = []) : m.wellFormed = true :=
  nameFindings_nil m (hr ▸ (boardingPass_parts r x m h).2.1)

/-! ## Validity -/

/-- A credential is expired once the current time is after the end of its
validity, under both readings of the exact instant. -/
@[checks "OID-105.1"]
theorem expired_after_validUntil (e : ExpiryReading) (m : Mdoc) (now : Instant)
    (h : m.validUntil < now) : expired e m now = true := by
  unfold expired
  split <;> simp [h, le_of_lt h]

/-- A credential is not expired while the current time is before the end of
its validity, under both readings of the exact instant. -/
@[checks "OID-105.2"]
theorem valid_before_validUntil (e : ExpiryReading) (m : Mdoc) (now : Instant)
    (h : now < m.validUntil) : expired e m now = false := by
  unfold expired
  split <;> simp [not_lt_of_gt h, not_le_of_gt h]

/-- Once a credential has expired it stays expired: time passing never makes
it valid again. -/
@[checks "OID-105.3"]
theorem expired_stays_expired (e : ExpiryReading) (m : Mdoc) (now later : Instant)
    (h : expired e m now = true) (hl : now ≤ later) : expired e m later = true := by
  unfold expired at *
  split at h <;> simp_all
  · exact lt_of_lt_of_le h hl
  · exact le_trans h hl

/-- A credential is not expired at the exact instant its validity ends.

Open question for the business.  The guide says a verifier checks time
validity and leaves the check to ISO/IEC 18013-5, which this project has not
read.  If the validity ends at the instant itself, a boarding pass whose
validity was set to end exactly at departure is refused at the moment of
departure.  The example {lit}`atTheEndOfValidity` shows both readings.  Is a
credential still valid at the exact instant its validity ends? -/
@[open_question, checks "OID-105.4"]
theorem valid_at_validUntil (e : ExpiryReading) (m : Mdoc) (now : Instant)
    (h : now ≤ m.validUntil) : expired e m now = false := by
  sorry

/-- Under the reading that a credential is still valid at the instant its
validity ends, it is not expired while the current time is no later than that
instant. -/
theorem valid_at_validUntil_of_validAtEnd (e : ExpiryReading) (m : Mdoc) (now : Instant)
    (he : e.validAtEnd = true) (h : now ≤ m.validUntil) : expired e m now = false := by
  simp [expired, he, not_lt_of_ge h]

private theorem validity_parts (v : ValidityReading) (j : Journey) (m : Mdoc)
    (h : BoardingPass.validityFindings v j m = []) :
    j.departure v.departure ≤ m.validUntil ∧
      m.validUntil.epochSeconds ≤ (j.departure v.departure).epochSeconds + v.soonAfter := by
  unfold BoardingPass.validityFindings at h
  obtain ⟨h1, h2⟩ := List.append_eq_nil_iff.mp h
  constructor
  · by_contra hc
    simp [not_le.mp hc] at h1
  · by_contra hc
    simp [not_le.mp hc] at h2

/-- The validity of an accepted boarding pass does not end before the
departure of the last leg, whichever departure the reading names and however
long "soon after" is. -/
@[checks "OID-104.1"]
theorem validity_reaches_departure (v : ValidityReading) (j : Journey) (m : Mdoc)
    (h : BoardingPass.validityFindings v j m = []) : j.departure v.departure ≤ m.validUntil :=
  (validity_parts v j m h).1

/-- The validity of an accepted boarding pass ends no later than "soon after"
the departure of the last leg, for the departure and the length the reading
gives. -/
@[checks "OID-104.2"]
theorem validity_ends_soon_after (v : ValidityReading) (j : Journey) (m : Mdoc)
    (h : BoardingPass.validityFindings v j m = []) :
    m.validUntil.epochSeconds ≤ (j.departure v.departure).epochSeconds + v.soonAfter :=
  (validity_parts v j m h).2

/-- An accepted boarding pass is not expired before the departure of the last
leg, for the departure the reading names. -/
@[checks "OID-104.3"]
theorem valid_before_departure (e : ExpiryReading) (v : ValidityReading) (j : Journey) (m : Mdoc)
    (h : BoardingPass.validityFindings v j m = []) (now : Instant)
    (hn : now < j.departure v.departure) : expired e m now = false :=
  valid_before_validUntil e m now (lt_of_lt_of_le hn (validity_reaches_departure v j m h))

/-- An accepted boarding pass is expired once the journey is completed, for a
journey that is completed no earlier than its last leg departs.

Open question for the business.  The guide says the end of validity MUST be
"on or soon after last leg journey departure" and that this makes the
boarding pass expire once the journey is completed.  It gives no limit for
"soon after" and no definition of a completed journey.  If "soon after" is a
day, a boarding pass for a two-hour flight is still valid twenty-two hours
after landing, and since the guide puts revocation out of scope no rule of
the guide ends it sooner.  The example {lit}`validAfterTheJourney` shows it.
How long after the last departure may the validity of a boarding pass run? -/
@[open_question, checks "OID-104.4"]
theorem expired_once_journey_completed (e : ExpiryReading) (v : ValidityReading) (j : Journey)
    (m : Mdoc) (hs : j.scheduledDeparture ≤ j.completed) (ha : j.actualDeparture ≤ j.completed)
    (h : BoardingPass.validityFindings v j m = []) (now : Instant)
    (hn : j.completed < now) : expired e m now = true := by
  sorry

/-- Under every reading in which "soon after" ends no later than the journey
is completed, an accepted boarding pass is expired once the journey is
completed. -/
theorem expired_once_journey_completed_of_short_window (e : ExpiryReading) (v : ValidityReading)
    (j : Journey) (m : Mdoc)
    (hw : (j.departure v.departure).epochSeconds + v.soonAfter ≤ j.completed.epochSeconds)
    (h : BoardingPass.validityFindings v j m = []) (now : Instant) (hn : j.completed < now) :
    expired e m now = true := by
  apply expired_after_validUntil
  rw [Instant.lt_iff] at hn ⊢
  have := validity_ends_soon_after v j m h
  omega

/-- An accepted boarding pass is not expired before its last leg actually
departs.

Open question for the business.  An issuer knows only the scheduled departure
when it signs the boarding pass.  Under the reading that the scheduled
departure is meant, the validity may end at any instant from that departure
on, so a boarding pass can expire before a delayed flight boards, and the
guide does not say whether the airline issues a new one.  The example
{lit}`expiredBeforeADelayedDeparture` shows it.  If the airline signs the
boarding pass again to end soon after the actual departure, that boarding pass
is correctly issued under the reading that the actual departure is meant and
wrongly issued under the other, and expiry, the time check a relying party
makes, gives the same answer under both.  The example
{lit}`signedAgainAfterADelay` shows it.  Which departure is meant, and
what happens to a boarding pass credential when its flight is delayed past the
end of its validity? -/
@[open_question, checks "OID-104.5"]
theorem valid_until_actual_departure (e : ExpiryReading) (v : ValidityReading) (j : Journey)
    (m : Mdoc) (h : BoardingPass.validityFindings v j m = []) (now : Instant)
    (hn : now < j.actualDeparture) : expired e m now = false := by
  sorry

/-- Under the reading that the actual departure is meant, an accepted boarding
pass is not expired before its last leg actually departs. -/
theorem valid_until_actual_departure_of_actual (e : ExpiryReading) (v : ValidityReading)
    (j : Journey) (m : Mdoc) (hv : v.departure = .actual)
    (h : BoardingPass.validityFindings v j m = []) (now : Instant)
    (hn : now < j.actualDeparture) : expired e m now = false :=
  valid_before_departure e v j m h now (by simpa [hv, Journey.departure] using hn)

/-- A photoid whose validity was accepted is expired once the document it was
derived from has expired.

Open question for the business.  The guide sets the validity of a boarding
pass and says nothing about the validity of a photoid, and it puts revocation
out of scope.  Under the reading that the issuer may set any end of validity,
a photoid stays valid after its passport expires.  The example
{lit}`photoidOutlivesItsPassport` shows it.  Must the validity of a photoid
end no later than the expiry of the passport it was derived from? -/
@[open_question, checks "OID-108.1"]
theorem photoid_expires_with_document (r : PhotoidValidityReading) (e : ExpiryReading)
    (documentExpiry : Instant) (m : Mdoc) (h : Photoid.validityFindings r documentExpiry m = [])
    (now : Instant) (hn : documentExpiry < now) : expired e m now = true := by
  sorry

/-- Under the reading that the validity of a photoid ends with its source
document, a photoid whose validity was accepted is expired once that document
has expired. -/
theorem photoid_expires_with_document_of_endsWithDocument (e : ExpiryReading)
    (documentExpiry : Instant) (m : Mdoc)
    (h : Photoid.validityFindings .endsWithDocument documentExpiry m = []) (now : Instant)
    (hn : documentExpiry < now) : expired e m now = true := by
  apply expired_after_validUntil
  have : ¬ documentExpiry < m.validUntil := by
    intro hc
    simp [Photoid.validityFindings, hc] at h
  exact lt_of_le_of_lt (not_lt.mp this) hn

/-! ## One traveler -/

/-- A photoid and a boarding pass that the system accepts as a pair are about
the same traveler.

Open question for the business.  The guide requires a boarding pass together
with the face image of a photoid at a contactless touchpoint and assumes the
holder of the wallet is a passenger.  It names no data element to compare and
no way to compare them.  As written, any accepted photoid goes with any
accepted boarding pass: the example {lit}`anotherTravelersBoardingPass` shows
one traveler's face admitted on another traveler's boarding pass.  Comparing
names does not settle it: the example {lit}`twoTravelersWithOneName` shows two
travelers with the same name.  No check of the two credentials' content can
settle it by itself ({lit}`no_content_check_identifies_the_traveler`), because
who a credential is about is fixed at issuance, which the guide puts out of
scope.  What ties a photoid and a boarding pass to one traveler: a rule for
issuers, the device key, or something else, and what must a relying party
check? -/
@[open_question, checks "OID-107.1"]
theorem matched_pair_same_traveler (r : MatchReading) (x : Resolution792) (pr : PhotoidReading)
    (t : PhotoidTables) (br : BoardingPassReading) (p b : Issued)
    (hp : Photoid.violations pr t p.mdoc = []) (hb : BoardingPass.violations br x b.mdoc = [])
    (h : travelerMatch r x p.mdoc b.mdoc = true) : p.subject = b.subject := by
  sorry

/-- Whatever a relying party checks on the content of a photoid and a boarding
pass, a pair it accepts can be about two different travelers: the same two
credentials could have been issued about different people.  So a matching
rule gives one traveler only together with a rule about issuance. -/
theorem no_content_check_identifies_the_traveler (check : Mdoc → Mdoc → Bool) (photoid boardingPass : Mdoc)
    (_h : check photoid boardingPass = true) :
    ∃ p b : Issued, p.mdoc = photoid ∧ b.mdoc = boardingPass ∧ p.subject ≠ b.subject :=
  ⟨⟨photoid, ⟨"one traveler"⟩⟩, ⟨boardingPass, ⟨"another traveler"⟩⟩, rfl, rfl, by simp⟩

/-- A photoid and a boarding pass about the same traveler are accepted as a
pair.

Open question for the business.  If names are compared, the name in a photoid
comes from the passport and the name in a boarding pass string follows
Resolution 792, and the guide does not say how to compare the two.  Under an
exact comparison, a traveler whose passport name has an accent or a second
given name is refused with their own boarding pass.  The example
{lit}`ownBoardingPassRefused` shows it.  If names are compared, how are a
passport name and a boarding pass name brought to the same form? -/
@[open_question, checks "OID-107.2"]
theorem same_traveler_matches (r : MatchReading) (x : Resolution792) (pr : PhotoidReading)
    (t : PhotoidTables) (br : BoardingPassReading) (p b : Issued)
    (hp : Photoid.violations pr t p.mdoc = []) (hb : BoardingPass.violations br x b.mdoc = [])
    (h : p.subject = b.subject) : travelerMatch r x p.mdoc b.mdoc = true := by
  sorry

/-- Under the reading that nothing is checked, a photoid and a boarding pass
about the same traveler are accepted as a pair, as is every other pair. -/
theorem same_traveler_matches_of_notChecked (x : Resolution792) (p b : Issued) :
    travelerMatch .notChecked x p.mdoc b.mdoc = true := rfl

end Rules.OneId
