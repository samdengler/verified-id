# Cross-check of the approved guide against its public copy

The model is written from the approved document, `One+ID+Technical+Implementation+Guide-26.3.docx`. IATA also publishes the guide on Confluence, at <https://standards.atlassian.net/wiki/spaces/OneID/pages/2947416082/Technical+Implementation+Guide>. This page records how the two copies compare.

## Result of the last run

Run on 2026-11-05 with `python3 scripts/crosscheck_source.py`.

| | Approved copy | Public copy |
| --- | --- | --- |
| Identity | SHA-256 `4f947677bb11eb3f93156ce4aa9e3f84a983b5945107a90ec5a6a681fe0e020a` | Confluence page 2947416082, version 1, published 2026-09-30 |
| Words compared | 9,147 | 8,964 |

The body text of the two copies is the same, word for word. Three differences were found, and none changes a rule:

| Difference | Approved copy | Public copy |
| --- | --- | --- |
| Title and table of contents | The document opens with its title and a table of contents, 183 words. | Confluence shows the title and generates the contents itself, so neither is in the page body. |
| Document title as a heading | Present as the first heading. | Not in the page body. |
| Link to the CUWS standard APIs (§7) | An absolute address on `standards.atlassian.net`. | The same page, written as an address relative to the site. |

The 28 numbered section headings are the same and in the same order.

## How the comparison is made

The script fetches the public page through Confluence's read-only page API, which returns the page body as HTML with its version number and date. It renders both copies to plain text with pandoc and compares them word by word. Layout is ignored: line breaks, table rules, and typographic variants of quotes and dashes. It then compares the headings and the link targets. The full report is written to `build/source-crosscheck.md`, which is not committed because it contains the first words of each differing span.

What the comparison does not cover: formatting such as bold text, the nesting of lists, and images. The guide has no images. A change of emphasis would not be noticed.

## When to run it again

Run the script when the approved document changes, or before relying on the public page for a citation. If the public page moves past version 1, the first lines of the report show the new version and its date, and every differing span is listed with the words before it.
