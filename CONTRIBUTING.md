# Questions, Corrections and Contributions

Start with [README.md](README.md) and the
[PLFS Data 2024/PLFS_walkthrough.do](PLFS%20Data%202024/PLFS_walkthrough.do) lesson.
You can contribute a clearer explanation, report a mismatch, or propose a code
change. The historical scripts are reference material, not the default workflow.

## Ask a Useful Question

Use the repository's Issues tab. Include:

- Your Stata or Python version and operating system; for Python, also the package versions.
- The survey year, data source, file format and script being run.
- The exact command and error text, or the observed and expected result.
- The report statement/table, page, age group, sector and status measure.
- Whether you ran the complete do-file or only a selection.

Remove personal path details if needed. Use a few invented rows when an example
is necessary. Do not share unit-level survey records, access credentials or
information that could identify a respondent.

## Propose a Change

1. Open an issue first for changes to the methodology, supported survey years
   or file structure, so the scope can be discussed.
2. Work in your fork and make a focused change. Keep existing teaching comments
   and add short, plain-language explanations where helpful.
3. State which problem is fixed, which files change, and how you checked it.
4. Open a pull request. Report any checks you could not run; do not label
   a Python reproduction or static check as a successful native Stata execution.

Do not introduce user-specific paths beyond clearly marked configuration
examples. Preserve leading zeros in IDs and keep source inputs unchanged.
Save outputs separately. Avoid unrelated formatting changes to historical files.

## Check Scientific Changes

For changes to matching, weights or definitions, run the walkthrough from the
top in Stata when available. Check all of the following:

- Household IDs are unique in the household file; person IDs are unique in the
  person file; no records are unexpectedly lost, duplicated or left unmatched.
- The release and required variable names/types match the official data layout.
- Annual weights follow the release README, including the appropriate `NO_QTR`.
- The denominator is correct: population for LFPR/WPR, labour force for UR,
  and workers for employment-type shares.
- Principal and subsidiary work are combined correctly without double counting.
- Ages, gender grouping, geography and status measure match the reference table.
- Report comparisons specify whether agreement is exact or only at printed precision.

Do not remove an assertion merely to bypass a failure. Explain the data issue
or show why the check itself is inappropriate. Keep proposed work on quarterly
revisits or later survey designs separate from the 2023-24 annual examples.

The advanced decomposition notes require a separate review of estimation methods,
weights, missing values and model assumptions. A script finishing without an
error does not establish that its research interpretation is valid.

## Check Python Results

Follow the Python setup and run instructions in [README.md](README.md).
With compatible local CSV files, run
[PLFS Data 2024/plfs_analysis.py](PLFS%20Data%202024/plfs_analysis.py) with
`--verify` to compare selected annual-report entries. Report the exact command,
input release, comparison count and any mismatches. Do not upload the merged
person-level CSV with a pull request.

The analysis script checks IDs, household matching and weights automatically.
Keep those checks when changing the calculations. After changing the script or
package versions, rerun the analysis and report comparisons when the data is
available. State clearly when you could not check the results yourself.

## Keep Data and Rights Separate

The [.gitignore](.gitignore) excludes common raw data, output and environment
files. It does not remove files already tracked by Git or from repository history.
Check the files in your change before submitting. If a small invented CSV is
needed to explain a problem, discuss a narrow ignore-rule exception rather than uploading
real data or bypassing the rules wholesale.

Original contributions are submitted under the repository's [LICENSE](LICENSE).
Only contribute material you have the right to license. Preserve third-party
attribution and follow [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md); the MIT
licence does not cover MoSPI materials or separately obtained software.

Keep discussion respectful and focused on the code, evidence and explanation.