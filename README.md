# PLFS Data: Learn, Merge and Replicate

A practical guide for researchers using Stata or Python to analyse India's
**Periodic Labour Force Survey (PLFS), July 2023-June 2024**. Learn how the survey files fit
together, apply annual weights, and reproduce selected employment tables.

This is an independent learning resource, not an official MoSPI publication or
a replacement for the survey documentation. The folder name "PLFS Data 2024"
refers to **2023-24**, not calendar-year 2024 or the redesigned survey from 2025.

You can follow this YOUTUBE Playlist as well : https://www.youtube.com/playlist?list=PLDu9RPLRPcu8mvEVE5bkuqI4lxLd6vlQ1

Original code and documentation are [MIT-licensed](LICENSE). **The MoSPI report
and survey data are excluded**; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Start Here

For **Stata**, open
[PLFS Data 2024/PLFS_walkthrough.do](PLFS%20Data%202024/PLFS_walkthrough.do).
This is the single main workflow: merge the data, apply weights, learn from five
worked tables, then continue to the extended analysis. Sections 1-12 explain the
basics; sections 13-18 contain the extended tables. You do not need to run the
older merging script first.

For **Python**, use
[PLFS Data 2024/plfs_analysis.py](PLFS%20Data%202024/plfs_analysis.py) and follow
[Run with Python](#run-with-python). It reads CSV files (MoSPI now provides data in csv format as well), checks the merge, applies
annual weights, and exports tables without needing Stata.

**Before running anything:** the raw data is not included, paths must be changed
for your computer, and the older scripts are not interchangeable with the walkthrough.

| File | Purpose and status |
| --- | --- |
| [PLFS Data 2024/PLFS_walkthrough.do](PLFS%20Data%202024/PLFS_walkthrough.do) | Main Stata file. Checked merge, annual weights, five worked examples and extended tables, with teaching comments and a command log. |
| [PLFS Data 2024/plfs_analysis.py](PLFS%20Data%202024/plfs_analysis.py) | Complete Python CSV workflow with numbered comments, merge checks, annual weights, 31 table sheets and optional PDF comparisons. |
| [PLFS Data 2024/Merging HH and Ind Level data.do](PLFS%20Data%202024/Merging%20HH%20and%20Ind%20Level%20data.do) | Original YouTube merging code, preserved unchanged. Contains `save, replace` on input files and manual preparation steps. Do not run on your only copy of the data. |
| [PLFS Data 2024/Replicating PLFS Report Tables.do](PLFS%20Data%202024/Replicating%20PLFS%20Report%20Tables.do) | Original YouTube table code, preserved unchanged. Expects a previously prepared merged file and uses earlier sample/weight choices. |
| [PLFS Data 2024/oaxaca decomposition.do](PLFS%20Data%202024/oaxaca%20decomposition.do) | Advanced exploratory notes, not a validated research pipeline. Requires prepared data and the user-written `oaxaca` command. |
| [PLFS Data 2024/AnnualReport_PLFS2023-24L2.pdf](PLFS%20Data%202024/AnnualReport_PLFS2023-24L2.pdf) | Official reference report by MoSPI/NSO. It is third-party material, not repository-authored work. |

**Following the YouTube recording?** The two original video files keep their
filenames and code so you can follow along. The walkthrough is the corrected,
standalone alternative; do not run it as an extra step in the video workflow.
The Oaxaca notes remain separate because they cover a different, advanced analysis.

## What You Need

- A licensed installation of **Stata 14 or later** for the walkthrough.
- Or **Python 3.11** and the packages in [requirements.txt](requirements.txt)
  for the Python workflow. The listed versions were tested with Python 3.11.
- Basic familiarity with the Do-file Editor or a terminal, depending on your choice.
- The **2023-24 first-visit household and person data**, prepared with the column
  names and types expected by these scripts.
- The matching MoSPI README, data layout and estimation instructions.

No extra Stata packages are needed for the beginner walkthrough. Python users
do not need a Stata licence. Both routes run locally; neither uploads your data.

### Get the Correct Data

Use the [MoSPI Microdata Library](https://microdata.gov.in/NADA/index.php/catalog)
and find **Periodic Labour Force Survey, July 2023-June 2024**. Follow the portal's
access conditions. Download the unit-level data and accompanying documentation,
especially the official README, data layout, estimation procedure and instructions
to field staff. These supporting documents are not included here.

**A download is not necessarily ready to run with these examples.** The Stata scripts
expect DTA files called `hhv1.dta` and `perv1.dta`, with source-specific suffixes
such as `qtr_hhv1`, `b3q4_hhv1`, `b4q5_perv1`, `NSS_perv1` and `no_qtr_perv1`.
Identification fields must remain strings with leading zeros intact; weights and
age must be numeric. A CSV or fixed-width release may use different names.

Compare your columns with the official data layout and the first `rename`
commands before running the lesson. **Renaming a CSV extension to `.dta` does
not convert it.** This repository does not currently provide an import/conversion
script for every format distributed by MoSPI. The Python script reads compatible
CSVs directly; its expected layout is explained below.

### Set Up and Run with Stata

1. Download this repository using **Code > Download ZIP**, then extract it,
   or clone it with Git.
2. Create a local data folder. For example:

   ```text
   C:/PLFS/
     dta_data_PLFS_2023_2024/
       hhv1.dta
       perv1.dta
   ```

3. Open the walkthrough in Stata's Do-file Editor. Change the line near the top to:

   ```stata
   local root "C:/PLFS"
   ```

   `root` is the folder containing your data subfolder, not necessarily the Git
  repository. Forward slashes and quotes work well for Windows paths with spaces.
4. Run the **whole file from the top**. For example, replacing this example
   repository location with your own:

   ```stata
   do "C:/repos/PLFS-Data/PLFS Data 2024/PLFS_walkthrough.do"
   ```

The walkthrough starts with `clear all`, so save any unsaved Stata work first.
It writes three outputs beneath `root/plfs_learning_output/`:
`HH_Ind_merged.dta` before selecting the lesson's columns and analysis names,
`PLFS_learning_data.dta` with the introductory and extended analysis variables,
and `PLFS_walkthrough.log` with commands and tables. Reruns replace these generated
outputs; the walkthrough does not overwrite the source DTA files.

The walkthrough uses `local check_report 1` to check selected national/report values
for the complete release. Set it to `0` only for an intentional subset exercise,
not to bypass an unexplained mismatch. ID, merge, weight and activity-code checks
remain active. The table filters select observations without deleting other people
from the prepared data.

## Run with Python

### 1. Prepare the CSV Files

Obtain the 2023-24 first-visit household and person CSVs under the source's terms.
Keep them outside Git or in the ignored local data folder. For example:

```text
C:/PLFS/CSV_data_PLFS_2023_2024/
  hhv1.csv
  perv1.csv
```

The script expects the suffixed column names used by the examples, including
`qtr_hhv1`, `b3q4_hhv1`, `b4q5_perv1`, `NSS_perv1`, `NSC_perv1`, `mult_perv1`
and `no_qtr_perv1`. Names are case-sensitive. The complete column lists are at
the top of the script. Other releases or CSV layouts need an explicit column
mapping; this is not an automatic importer for every MoSPI download.

IDs are read as text so `01` stays `01`. Numeric amounts and activity codes are
converted after reading. Keep the CSVs in their original form: do not open and
resave them in a spreadsheet that might remove leading zeros.

### 2. Install the Packages

Open a terminal in the **repository root**, where [requirements.txt](requirements.txt)
is located. You can use an existing environment instead of creating a new one.
For the tested Python 3.11 setup, run these PowerShell commands on Windows:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

On macOS or Linux:

```bash
python3.11 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

No activation command is necessary when you call that environment's Python
directly. In VS Code, use **Python: Select Interpreter** to select the same
environment for editor checks and running code.

### 3. Run the Whole Analysis

From the repository root, changing the data path to your own folder:

```powershell
.\.venv\Scripts\python.exe "PLFS Data 2024/plfs_analysis.py" --data-dir "C:/PLFS/CSV_data_PLFS_2023_2024" --verify --save-merged
```

On macOS or Linux, use `.venv/bin/python` and your local data path instead.
If the CSV folder is beside the script, named `CSV_data_PLFS_2023_2024`, you can
omit `--data-dir`. The annual-report PDF is already beside the script in this
repository, so the default annual verification needs no extra PDF path.

| Option | What it does |
| --- | --- |
| `--help` | Show the available options and stop. |
| `--check-only` | Check inputs, IDs, matching, weights and definitions without saving results. |
| `--verify` | Compare selected calculated values with the reference PDF at its printed precision. |
| `--save-merged` | Also save the joined analysis columns as CSV. |
| `--output-dir "folder"` | Choose a results folder instead of the default. Reruns replace generated files there. |
| `--reference-pdf "file.pdf"` | With `--verify`, select another copy of the reference PDF. |
| `--mode video` | Reproduce the earlier weights and male/female-only filter for historical comparison, not new annual estimates. |

Use `--check-only` on its own, not with `--verify` or `--save-merged`.
Annual mode is the default. Video verification needs the earlier Stata-result
PDF supplied separately with `--reference-pdf`; that PDF is not bundled here.

### 4. Open and Read the Results

The script handles the preparation and calculations in one run. Its comments
explain each step, but you do not need to understand every Python function to
use it. Always check the table's population, age group and denominator before
interpreting a result.

By default, annual results go into `PLFS Data 2024/plfs_output/annual/`:

- `plfs_tables.xlsx`: 31 analysis sheets, plus Read_me, Table_guide and Merge_check.
  `--verify` adds a PDF_check sheet. Start with Read_me and Table_guide.
- `merge_audit.json`: input/match counts, mode and verification summary.
- `pdf_comparison.csv`: the selected PDF values, Python values and match flags,
  created by `--verify`.
- `merged_first_visit.csv`: selected input columns and derived analysis columns,
  created by `--save-merged`. This is not an export of every raw survey column.

For the five Stata lesson examples, look at **rates** for LFPR/WPR/UR and filter
to age 15+. For employment type and unpaid helpers, use **employment_social_group**,
select **All ages**, and select code **2** for the unpaid-helper share. The other
sheets extend the examples to industry, occupation, training and household details.

Category tables exclude blank answers. An empty denominator produces a blank,
not a zero. "All self-employed" is a subtotal; do not add it again to its parts.
Spending bands refer to whole-household spending, not MPCE. The spending mean is
person-weighted, not an average across households. No survey-design standard
errors, confidence intervals or Oaxaca models are calculated by this script.
The official release README cautions against using PLFS for standalone analysis
of classificatory variables such as household consumption expenditure.

With the checked release, expect 418,159 persons matched to 101,920 households.
The age-15+ headline rates are **LFPR 60.1%, WPR 58.2%, UR 3.2%**.
All source CSVs remain unchanged. Generated data stays local and is ignored by Git.

### 5. Check Against the Annual Report

The script automatically checks IDs, household-person matches and weights.
The `--verify` option in the run command above also compares **243 table cells**
with the annual report, using your CSV data and the bundled PDF:
81 occupation-division entries in Table 25 and 162 ST/SC/OBC employment entries
in Table 46. It does not check every workbook sheet or every annual-report table.
PDF parsing is specific to the bundled 2023-24 report's page layout.

If a parsed comparison differs, results and comparison rows are saved and the
command exits with an error. A missing input or unreadable PDF stops the run
earlier. For missing-package errors, install into the same Python environment
you use to run the script. For missing-column errors, check the release and
column mapping rather than deleting the safety checks.

## Read the Extended Tables

Sections 13-18 of the walkthrough and the Python workbook go beyond the five
introductory examples. These are analysis examples, not a claim to reproduce every official
table. Read each heading and, in Excel, the **Table_guide** sheet.

| Table family | Who enters the denominator? |
| --- | --- |
| Employment type, industry, occupation | Workers in the named age group, not everyone in the labour force |
| Social-security benefits | Regular and casual wage workers aged 15+ in the selected job, with a reported answer; all industries |
| Vocational training | All persons or the labour-force subset aged 15-59, as specified |
| Field, duration and type of training | Formal trainees in the labour force, aged 15-59 |
| Current educational attendance | Labour-force members aged 15-29; this is not completed education |
| Search efforts | Principal-status unemployed people aged 15+, including those with subsidiary work |
| Unemployment duration | Unemployed people aged 15+ with no principal or subsidiary work |
| Reasons for not working | Non-workers aged 15+ who worked before the last 365 days and reported a reason, including those outside the labour force |

Job details consistently use the **principal job when employed there, otherwise
the subsidiary job**. A blank benefit for a principal job is not filled with a
benefit from a different job. The benefits example is broader than the report's
regular-salaried, non-agricultural indicator; do not compare them directly.

A blank answer can mean **not asked**, not **no**. The survey collects attendance
below age 30 and training at ages 12-59; these examples deliberately use adult
subsets. Activity and unemployment durations are **coded bands**, not month counts.
The Python `economic_months` sheet keeps its existing name but now labels the bands.
See Instruction Manual I, sections 3.4 and 3.5, and the matching questionnaire.

## Understand the Files and Merge

PLFS samples villages or urban blocks, then households within them. Person records
describe household members; household records contain shared details such as
social group and religion. Survey weights let the sampled records represent the
wider population.

For the **2023-24 design**, rural households have one visit; urban households have
a first visit followed by three quarterly revisits. First-visit files contain
observations from **all four quarters**. First visit does not mean first quarter.

The walkthrough uses usual status: principal activity over the preceding 365 days,
plus qualifying subsidiary work. Current weekly status refers to the preceding
seven days and is a different measure. These annual usual-status examples use
**first visits only**, following the annual estimation instructions.

The household ID combines quarter, visit, sector, FSU number, hamlet/sub-block,
second-stage stratum and sample household number. The person ID adds the member's
serial number. These are the fields specified in section B of the official README.

`merge m:1 HHID` attaches one household's information to its several members.
The first-visit release checked here has **101,920 households and 418,159 persons**,
with all person records matched. This is not a link between the same person across
different visits. Quarterly analysis or longitudinal linkage needs a separate,
carefully validated workflow.

An `assert` checks an assumption and stops if it fails; it does not alter the
data. Do not delete a failed check just to make the file finish. Investigate the
IDs, source files, types and sample first.

## Weights and Rates

For annual estimates combining the four quarters, the walkthrough uses:

```stata
gen double weight_quarter = Mult / 100 if NSS == NSC
replace weight_quarter = Mult / 200 if NSS != NSC
gen double weight = weight_quarter / NO_QTR
```

`NO_QTR` counts contributing quarters for the relevant sampling group, not a
person's visits. Use the supplied value, not a fixed four. See the official
README, section B. A common scaling factor cancels in percentages but not totals;
when quarter counts differ, percentages can change too. Do not carry this annual
formula into quarterly revisit analysis without checking that analysis's instructions.

| Indicator | Numerator | Denominator |
| --- | --- | --- |
| Labour force participation rate (LFPR) | Employed + unemployed persons | All persons in the selected age group |
| Worker population ratio (WPR) | Employed persons | All persons in the selected age group |
| Unemployment rate (UR) | Unemployed persons | Labour force in the selected age group |

Use weighted sums and multiply each ratio by 100. Being outside the labour force
is not the same as being unemployed. Under usual status (ps+ss), qualifying
subsidiary work can make a person employed even without a principal job.

For replication, gender code 3 is included in Male, as specified in annual-report
section 1.5.3. The original gender code is retained separately.

## Replicate the Worked Examples

The page numbers below refer to the report bundled in this repository. PDF page
numbers and printed page numbers are different.

| Walkthrough example | Population | Annual-report reference | Useful benchmark |
| --- | --- | --- | --- |
| A: LFPR | Age 15+ | Statement 2; PDF p. 36, printed p. 7 | All-India persons: **60.1%** |
| B: WPR | Age 15+ | Statement 4; PDF p. 39, printed p. 10 | All-India persons: **58.2%** |
| C: UR | Age 15+ | Statement 15, all education levels; PDF p. 51, printed p. 22 | Rural **2.5%**, urban **5.1%**, combined **3.2%** |
| D: Employment type | Rural ST workers, all ages | Table 46; PDF p. 393, printed p. A-330 | Male unpaid-helper share: **14.7%** |
| E: Unpaid helpers by social group | Workers, all ages | Table 46; PDF pp. 393-394, printed pp. A-330 to A-331 | Compare the helper-in-household-enterprise column |

Code 21 identifies unpaid helpers in a household enterprise; it does not mean
all unpaid domestic work. The employment-type examples use the principal job
when a person is employed in principal status, and the subsidiary job otherwise.
That is not the same as asking whether someone did *any* unpaid subsidiary work.

Before comparing results, match **year, status measure, age, sector, gender,
denominator, weights and rounding**. Do not average rural and urban percentages
to obtain a national result; pool the underlying weighted counts.

### Verification Status

During development, 84 table-cell comparisons across these five examples matched
the report at its printed precision. Those checks reproduced the calculations
in Python using the local DTA inputs; **the do-file has not been executed in a
native Stata session as part of that validation**. The walkthrough includes
merge checks and four rounded benchmark checks that you can run in Stata.

The Python workflow is now included and has been run end to end on the local
CSV inputs: all 243 selected annual-report comparisons passed.
Its `--verify` option makes those comparisons repeatable with your
own compatible data. Raw survey data remains excluded from the repository.

The underlying calculations were also checked against the supplied DTA files for
IDs, matching, annual weights, headline rates and rural ST male employment shares.
Additional Python checks covered job selection, question eligibility, empty subgroups
and invalid input codes. These are calculation checks, **not native Stata execution**;
the extended Stata table syntax still needs a run in a licensed Stata installation.

## Limits and Troubleshooting

- **File not found:** edit `local root` and check the data subfolder and filenames.
- **Variable not found or type mismatch:** compare your input layout with the
  names expected by the do-file. Do not force-convert ID strings to numbers.
- **A local macro is empty when running a selection:** rerun from the top;
  path macros and temporary files are set earlier in the same run.
- **Assertion failed:** check the release, missing values and merge output.
  A matching rounded national rate alone does not validate every subgroup.
- **Unknown activity code or missing job detail:** check the source columns and
  codebook. Do not turn an unknown code into a non-worker or borrow another job's details.
- **Different table values:** check age limits first, then status, weights and
  missing answers. The report includes gender code 3 in Male.
- **Standard errors:** these examples focus on point estimates. `iw=weight`
  alone is not a full survey-design specification for confidence intervals.

The exploratory Oaxaca file expects data already loaded and a `weight` variable.
For that optional command, use `help oaxaca`; if it is absent, review
`ssc describe oaxaca` before installing it with `ssc install oaxaca`.
The file's manually constructed RIF variables and model choices require
methodological review before research use; installing the package does not
validate those calculations. A decomposition's unexplained component is not,
by itself, a causal estimate of discrimination.

The historical scripts have been kept for context, not certified for current
research use. This repository does not validate all annual-report tables, produce
official estimates, or cover the redesigned PLFS from 2025 onward.

## Sources and Citation

- [MoSPI Microdata Library](https://microdata.gov.in/NADA/index.php/catalog):
  obtain the 2023-24 release and its official README and data layout.
- [Official annual report](https://www.mospi.gov.in/sites/default/files/publication_reports/AnnualReport_PLFS2023-24L2.pdf):
  survey definitions, section 1.5.3 and the tables referenced above.
- Official **Sample Design and Estimation Procedure**, section 4.2.1:
  first-visit schedules for annual urban estimates.
- Official **Instructions to Field Staff, Volume I**, Chapter 3, Box 1:
  information collected at first visits and revisits.
- The same manual, sections **3.4 and 3.5**, and **Volume II, Schedule 10.4**:
  question eligibility, activity codes, training, duration and job-benefit definitions.

For academic work, cite MoSPI/NSO as the data and report source. Separately
acknowledge this repository as a code/learning resource, recording the repository
URL, the commit you used, and your access date. Do not attribute the underlying
survey data to the repository author.

[CITATION.cff](CITATION.cff) supplies GitHub's citation metadata for the code.
An acknowledgement can read: "Code adapted from Md Sarfraz, PLFS Data: Learn,
Merge and Replicate, https://github.com/imdsarfraz/PLFS-Data, commit [the commit
you used], accessed [date]." Cite the official PLFS release separately.

## Questions and Corrections

Use this repository's **Issues** tab. Include your Stata or Python version, survey year,
script, exact command/error, and the report table and age group being compared.
Share a small invented example or aggregate output, not respondent-level data,
credentials or identifying details. Contributions that improve explanations,
add documented checks or correct methods are welcome.

See [CONTRIBUTING.md](CONTRIBUTING.md) for reporting and validation guidance.
The original code and documentation are available under the [LICENSE](LICENSE),
with copyright credited to **Md Sarfraz**. Keep the notice when redistributing
substantial portions. This licence does not certify the statistical methods or
grant rights over third-party materials.
