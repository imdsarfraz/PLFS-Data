# Third-Party Materials and Data

## Scope of the Repository Licence

The [LICENSE](LICENSE) applies to the original code and original documentation
authored for this repository. **It does not license the MoSPI report, survey
data, third-party software, logos or other externally authored material.**
Their applicable source terms and any existing notices continue to apply.

## MoSPI Annual Report

The bundled
[PLFS Data 2024/AnnualReport_PLFS2023-24L2.pdf](PLFS%20Data%202024/AnnualReport_PLFS2023-24L2.pdf)
is the **Annual Report, Periodic Labour Force Survey (PLFS), July 2023-June 2024**.

- **Source and attribution:** National Statistical Office, Ministry of Statistics
  and Programme Implementation (MoSPI), Government of India.
- **Official source:** [Annual Report PLFS 2023-24](https://www.mospi.gov.in/sites/default/files/publication_reports/AnnualReport_PLFS2023-24L2.pdf).
- **Purpose here:** reference for definitions, methods and comparison tables.
  The repository author does not claim authorship of the report or official
  endorsement of the example code.
- **Reuse:** consult [MoSPI's copyright policy](https://www.mospi.gov.in/CopyrightPolicy),
  its applicable dissemination guidelines, and notices within the report.

When checked on 20 September 2026, MoSPI's website policy referred reproduction
to the revised Guidelines for Statistical Data Dissemination (GSDD) 2026. It
required accurate reproduction, no misleading or derogatory use, and clear,
prominent source acknowledgement. It excluded material identified as belonging
to third-party copyright holders from that permission. Read the current source
policy and guidelines before redistributing; this summary does not replace them.

The report is **not relicensed under MIT** by its inclusion in this repository.
Preserve its attribution and notices. No claim is made that it is public domain.

## Unit-Level Data and Survey Documentation

Raw household/person data is not distributed in this repository. Obtain the
correct release and its documentation from the
[MoSPI Microdata Library](https://microdata.gov.in/NADA/index.php/catalog), under
that release's access, use, attribution and redistribution conditions.

Do not treat the repository licence, or the website's general copyright policy,
as blanket permission to redistribute unit-level data. Do not attempt to identify
survey respondents. Do not upload unit-level extracts or identifying information
in commits, issues or pull requests. Use invented examples to demonstrate errors.

Quoted definitions, official code meanings and report comparison values retain
their source attribution. The lesson points to the README, estimation procedure,
instructions and report sections used; cite those official sources in research.

## Stata and Optional Commands

Stata is a separate proprietary product from StataCorp LLC. It is not included
here, and the repository licence does not grant a Stata licence.

The optional user-written `oaxaca` command is obtained separately through Stata's
package system. Its authorship and terms are independent of this repository.
Refer to its package documentation and retain appropriate citations when used.

## Python Packages

[requirements.txt](requirements.txt) lists separately installed packages:
NumPy, pandas, openpyxl and PyMuPDF. They retain their own authorship and licences;
the MIT licence on this repository does not replace their terms. PyMuPDF is used
for the optional PDF comparison; consult its
[licensing information](https://pymupdf.readthedocs.io/en/latest/about.html#license-and-copyright)
before redistributing or embedding it. No package source or binaries are bundled.

## Attribution Corrections

If you identify missing attribution or a rights concern, open a repository issue
with the affected file and the relevant source or notice. Do not attach private
or restricted data as evidence.