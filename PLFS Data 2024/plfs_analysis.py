"""Read PLFS 2023-24 CSV data, join households to people, and make annual tables.

Start with main() at the bottom to see the whole workflow in order.
No Stata installation is needed. Source data is read, never overwritten.
Only first visits are used for these annual usual-status (ps+ss) examples.
"""

import argparse
import json
import re
from pathlib import Path

import numpy as np
import pandas as pd


# Paths start beside this script, so moving the repository does not break them.
ROOT = Path(__file__).resolve().parent

# 1. Give the source columns clear names.
# These seven fields identify a household in the official README, section B.
KEY_PARTS = {
    "qtr": ("Quarter", 2),
    "visit": ("Visit", 2),
    "b1q3": ("Sector_code", 1),
    "b1q1": ("FSU", 5),
    "b1q13": ("Hamlet", 1),
    "b1q14": ("Second_stage_stratum", 1),
    "b1q15": ("Household_number", 2),
}

PERSON_FIELDS = {
    "state_perv1": "State_code",
    "b4q1_perv1": "Person_number",
    "b4q5_perv1": "Gender_original",
    "b4q6_perv1": "Age",
    "b4q7_perv1": "Marital_status",
    "b4q8_perv1": "General_education",
    "b4q9_perv1": "Technical_education",
    "b4q11_perv1": "Attendance_code",
    "b4q12_perv1": "Training_code",
    "b4pt1q4_perv1": "Training_field",
    "b4pt1q5_perv1": "Training_duration",
    "b4pt1q6_perv1": "Training_type",
    "b5pt1q3_perv1": "Principal_status",
    "b5pt2q3_perv1": "Subsidiary_status",
    "b5pt1q5_perv1": "NIC_principal",
    "b5pt2q5_perv1": "NIC_subsidiary",
    "b5pt1q6_perv1": "NCO_principal",
    "b5pt2q6_perv1": "NCO_subsidiary",
    "b5pt1q13_perv1": "Security_principal",
    "b5pt2q12_perv1": "Security_subsidiary",
    "b5pt3q6_perv1": "Economic_months_principal",
    "b5pt3q7_perv1": "Economic_months_subsidiary",
    "b5pt3q8_perv1": "Efforts_to_find_work",
    "b5pt3q9_perv1": "Unemployment_duration",
    "b5pt3q11_perv1": "Reason_not_working",
    "NSS_perv1": "NSS",
    "NSC_perv1": "NSC",
    "mult_perv1": "Multiplier",
    "no_qtr_perv1": "Contributing_quarters",
}

HOUSEHOLD_FIELDS = {
    "b3q1_hhv1": "Household_size",
    "b3q2_hhv1": "Household_type",
    "b3q3_hhv1": "Religion",
    "b3q4_hhv1": "Social_group",
    "b3q5pt6_hhv1": "Household_monthly_spending",
}

AGE_GROUPS = {
    "All ages": (0, None), "15+": (15, None),
    "15-29": (15, 29), "15-59": (15, 59),
}
SECTORS = {"Rural": "1", "Urban": "2", "Rural + Urban": None}
GENDERS = ["Male", "Female", "Persons"]
LABELS = {
    "Social_group": {"1": "ST", "2": "SC", "3": "OBC", "9": "Others"},
    "Religion": {
        "1": "Hindu", "2": "Muslim", "3": "Christian", "4": "Sikh",
        "5": "Jain", "6": "Buddhist", "7": "Zoroastrian", "9": "Others",
    },
    "Broad_status": {
        "1": "Own-account worker or employer", "2": "Helper in household enterprise",
        "self": "All self-employed", "3": "Regular wage or salary", "4": "Casual labour",
    },
    "NIC_broad": {
        "1": "Agriculture", "2": "Mining and quarrying", "3": "Manufacturing",
        "4": "Electricity and water supply", "5": "Construction", "7": "Trade",
        "8": "Transport", "9": "Accommodation and food services", "10": "Other services",
    },
    "NIC_three": {"1": "Agriculture", "6": "Secondary", "11": "Tertiary"},
    "Training_code": {
        "1": "Formal", "2": "Hereditary", "3": "Self-learning",
        "4": "Learning on the job", "5": "Others", "6": "No vocational training",
    },
    "Social_security": {
        "1": "Only pension", "2": "Only gratuity", "3": "Only health care",
        "4": "Pension and gratuity", "5": "Pension and health care",
        "6": "Gratuity and health care", "7": "Pension, gratuity and health care",
        "8": "Not eligible", "9": "Not known",
    },
    "Marital_status": {
        "1": "Never married", "2": "Currently married", "3": "Widowed",
        "4": "Divorced or separated",
    },
    "Attendance_group": {
        "1": "Never attended", "2": "Attended, not currently attending",
        "3": "Up to primary", "4": "Middle", "5": "Secondary",
        "6": "Higher secondary", "7": "Graduate", "8": "Postgraduate",
        "9": "Diploma or certificate",
    },
    "Household_spending_band": {
        "1": "Below Rs 10,000", "2": "Rs 10,000-19,999", "3": "Rs 20,000-29,999",
        "4": "Rs 30,000-39,999", "5": "Rs 40,000-49,999", "6": "Rs 50,000 or more",
    },
    "State_code": {
        "01": "Jammu and Kashmir", "02": "Himachal Pradesh", "03": "Punjab",
        "04": "Chandigarh", "05": "Uttarakhand", "06": "Haryana", "07": "Delhi",
        "08": "Rajasthan", "09": "Uttar Pradesh", "10": "Bihar", "11": "Sikkim",
        "12": "Arunachal Pradesh", "13": "Nagaland", "14": "Manipur", "15": "Mizoram",
        "16": "Tripura", "17": "Meghalaya", "18": "Assam", "19": "West Bengal",
        "20": "Jharkhand", "21": "Odisha", "22": "Chhattisgarh", "23": "Madhya Pradesh",
        "24": "Gujarat", "25": "Dadra and Nagar Haveli and Daman and Diu",
        "27": "Maharashtra", "28": "Andhra Pradesh", "29": "Karnataka", "30": "Goa",
        "31": "Lakshadweep", "32": "Kerala", "33": "Tamil Nadu", "34": "Puducherry",
        "35": "Andaman and Nicobar Islands", "36": "Telangana", "37": "Ladakh",
    },
}


# 2. Read first visits and connect people to their households.
def read_csv_columns(path, columns):
    """Read only the columns used in this analysis."""
    if not path.is_file():
        raise ValueError(f"Cannot find the input file: {path}")
    # Text keeps leading zeros, such as household 01. Convert amounts later.
    data = pd.read_csv(
        path, usecols=columns, dtype="string", keep_default_na=False,
        encoding="utf-8-sig",
    )
    for column in data.columns:
        data[column] = data[column].str.strip().replace("", pd.NA)
    if data.empty:
        raise ValueError(f"The input file has no records: {path.name}")
    return data


def add_household_id(data, suffix):
    """Make the same household ID in each file."""
    parts = []
    for prefix, (_, width) in KEY_PARTS.items():
        column = f"{prefix}_{suffix}"
        values = data[column]
        valid = values.notna() & values.str.len().eq(width)
        if prefix == "qtr":
            valid &= values.isin(["Q1", "Q2", "Q3", "Q4"])
        elif prefix == "visit":
            valid &= values.eq("V1")
        else:
            valid &= values.str.fullmatch(r"\d+")
        if not valid.all():
            raise ValueError(f"Missing or unexpected ID values in {column}.")
        parts.append(values)
    data["HHID"] = parts[0].str.cat(parts[1:])


def load_first_visits(data_dir, mode="annual"):
    """Attach each first-visit person's household details."""
    if mode not in {"annual", "video"}:
        raise ValueError("Choose annual or video mode.")
    data_dir = Path(data_dir)
    household_checks = [
        "state_hhv1", "nss_hhv1", "nsc_hhv1", "mult_hhv1", "no_qtr_hhv1",
    ]
    households = read_csv_columns(
        data_dir / "hhv1.csv",
        [f"{prefix}_hhv1" for prefix in KEY_PARTS]
        + list(HOUSEHOLD_FIELDS) + household_checks,
    )
    persons = read_csv_columns(
        data_dir / "perv1.csv",
        [f"{prefix}_perv1" for prefix in KEY_PARTS] + list(PERSON_FIELDS),
    )
    add_household_id(households, "hhv1")
    add_household_id(persons, "perv1")
    if households["HHID"].duplicated().any():
        raise ValueError("A household ID appears more than once. The join was stopped.")
    serial = persons["b4q1_perv1"]
    if not (serial.notna() & serial.str.fullmatch(r"\d{2}")).all():
        raise ValueError("Some person serial numbers are missing or not two digits.")
    persons["PID"] = persons["HHID"] + serial
    if persons["PID"].duplicated().any():
        raise ValueError("A person ID appears more than once. The join was stopped.")

    # Equivalent to Stata's merge m:1. Keep unmatched rows visible for checking.
    merged = persons.merge(
        households, on="HHID", how="outer", validate="many_to_one",
        indicator=True,
    )
    missing_households = int(merged["_merge"].eq("left_only").sum())
    unused_households = int(merged["_merge"].eq("right_only").sum())
    if missing_households or unused_households:
        raise ValueError(
            f"Join stopped: {missing_households:,} persons have no household; "
            f"{unused_households:,} households have no persons."
        )
    comparisons = [(f"{prefix}_perv1", f"{prefix}_hhv1") for prefix in KEY_PARTS]
    comparisons += [
        ("state_perv1", "state_hhv1"), ("NSS_perv1", "nss_hhv1"),
        ("NSC_perv1", "nsc_hhv1"), ("mult_perv1", "mult_hhv1"),
        ("no_qtr_perv1", "no_qtr_hhv1"),
    ]
    for person_column, household_column in comparisons:
        if not merged[person_column].eq(merged[household_column]).fillna(False).all():
            raise ValueError(f"The files disagree on {person_column} and {household_column}.")

    names = {f"{prefix}_perv1": name for prefix, (name, _) in KEY_PARTS.items()}
    names.update(PERSON_FIELDS)
    names.update(HOUSEHOLD_FIELDS)
    data = merged[["HHID", "PID"] + list(names)].rename(columns=names).copy()
    for column in [
        "Age", "Household_size", "Household_monthly_spending", "NSS", "NSC",
        "Multiplier", "Contributing_quarters", "Principal_status", "Subsidiary_status",
    ]:
        data[column] = pd.to_numeric(data[column], errors="raise")
    weight_fields = ["NSS", "NSC", "Multiplier", "Contributing_quarters"]
    weight_values = data[weight_fields].to_numpy(dtype=float, na_value=np.nan)
    if not np.isfinite(weight_values).all() or not (weight_values > 0).all():
        raise ValueError("Some survey weights or quarter counts are missing, infinite or not positive.")
    if not data["Contributing_quarters"].isin([1, 2, 3, 4]).all():
        raise ValueError("The number of contributing quarters must be 1, 2, 3 or 4.")
    if data["Age"].isna().any() or data["Age"].lt(0).any():
        raise ValueError("Some ages are missing or negative.")
    if not data["Gender_original"].isin(["1", "2", "3"]).all():
        raise ValueError("Unexpected gender codes. Check the source data.")
    if not data["Sector_code"].isin(["1", "2"]).all():
        raise ValueError("Unexpected rural/urban codes. Check the source data.")

    # 3. Annual weights: the README's quarter weight divided by NO_QTR.
    # NO_QTR belongs to a sampling group; it is not a person's number of visits.
    divisor = np.where(data["NSS"].eq(data["NSC"]), 100, 200)
    quarter_weight = data["Multiplier"].astype("float64") / divisor
    data["Annual_weight"] = quarter_weight / data["Contributing_quarters"]
    data["Weight"] = data["Annual_weight"].astype("float64")
    # Follow report section 1.5.3, but also keep the original gender code.
    data["Gender_code"] = data["Gender_original"].replace({"3": "1"})
    audit = {
        "mode": mode,
        "input_directory": str(data_dir.resolve()),
        "households": len(households),
        "persons_before_filter": len(persons),
        "matched_persons": len(merged),
        "persons_without_household": missing_households,
        "households_without_persons": unused_households,
        "gender_code_3_records": int(data["Gender_original"].eq("3").sum()),
        "persons_with_fewer_than_four_quarters": int(data["Contributing_quarters"].lt(4).sum()),
    }
    if mode == "video":
        # Historical comparison only: reproduce the old weights and gender filter.
        data["Weight"] = quarter_weight.astype("float32").astype("float64")
        data = data.loc[data["Gender_original"].isin(["1", "2"])].copy()
    audit["persons_used"] = len(data)
    audit["sum_of_weights"] = float(data["Weight"].sum())
    return data, audit


def group_codes(values, bands):
    """Put related codes into the groups used in the do-file."""
    numbers = pd.to_numeric(values, errors="raise")
    result = values.astype("string").copy()
    for lower, upper, code in bands:
        result.loc[numbers.between(lower, upper).fillna(False)] = code
    return result


# 4. Identify workers and prepare the other table categories.
def prepare_variables(data):
    """Make the employment and other columns needed by the tables."""
    data = data.copy()
    data["Gender"] = data["Gender_code"].map({"1": "Male", "2": "Female"})
    principal = data["Principal_status"]
    subsidiary = data["Subsidiary_status"]
    # 21 is unpaid work in a household enterprise, not ordinary domestic duties.
    work_codes = [11, 12, 21, 31, 41, 51]
    if principal.isna().any():
        raise ValueError("Some principal activity codes are missing. Check before making rates.")
    data["Worker"] = principal.isin(work_codes) | subsidiary.isin(work_codes)
    data["Labour_force"] = data["Worker"] | principal.eq(81)
    # A person with subsidiary work is employed, even if principal status is 81.
    data["Unemployed"] = data["Labour_force"] & ~data["Worker"]
    employment_groups = {11: "1", 12: "1", 21: "2", 31: "3", 41: "4", 51: "4"}
    # Assign one employment category: principal job first, otherwise subsidiary.
    data["Broad_status"] = principal.map(employment_groups).fillna(subsidiary.map(employment_groups))

    # Use the subsidiary job only when the main-job detail is blank.
    for name in ["NIC", "NCO"]:
        data[name] = data[f"{name}_principal"].fillna(data[f"{name}_subsidiary"])
    data["NIC_division"] = data["NIC"].str[:2]
    data["NIC_broad"] = group_codes(data["NIC_division"], [
        (1, 3, "1"), (5, 9, "2"), (10, 33, "3"), (35, 39, "4"),
        (41, 43, "5"), (45, 47, "7"), (49, 53, "8"), (55, 56, "9"), (58, 99, "10"),
    ])
    data["NIC_three"] = group_codes(data["NIC_division"], [(1, 3, "1"), (5, 43, "6"), (45, 99, "11")])
    data["NCO_division"] = data["NCO"].str[:1]
    data["NCO_subdivision"] = data["NCO"].str[:2]
    data["Social_security"] = data["Security_principal"].fillna(data["Security_subsidiary"])
    data["Economic_months"] = data["Economic_months_principal"].fillna(data["Economic_months_subsidiary"])
    data["Attendance_group"] = group_codes(data["Attendance_code"], [
        (1, 5, "1"), (11, 15, "2"), (21, 24, "3"), (25, 25, "4"),
        (26, 26, "5"), (27, 27, "6"), (28, 31, "7"), (32, 32, "8"), (33, 43, "9"),
    ])
    # These bands describe whole-household spending, not spending per person.
    spending = data["Household_monthly_spending"].where(data["Household_monthly_spending"].ge(0))
    data["Household_spending_band"] = pd.cut(
        spending.astype("float64"), [-1, 9999, 19999, 29999, 39999, 49999, np.inf],
        labels=["1", "2", "3", "4", "5", "6"],
    ).astype("string")
    return data


# 5. Calculate tables for the requested populations, ages and sectors.
def table_slices(data, ages, population="All persons", group=None, combined=True):
    """Select the people named in each table heading."""
    if population == "Workers":
        data = data.loc[data["Worker"]]
    elif population == "Labour force":
        data = data.loc[data["Labour_force"]]
    elif population != "All persons":
        raise ValueError(f"Unknown table population: {population}")
    for age_group in ages:
        lower, upper = AGE_GROUPS[age_group]
        age_mask = data["Age"].ge(lower)
        if upper is not None:
            age_mask &= data["Age"].le(upper)
        aged = data.loc[age_mask]
        for sector, sector_code in SECTORS.items():
            if sector_code is None and not combined:
                continue
            selected = aged if sector_code is None else aged.loc[aged["Sector_code"].eq(sector_code)]
            groups = selected.groupby(group, observed=True) if group else [(None, selected)]
            for group_code, members in groups:
                if members.empty:
                    continue
                heading = {"Age_group": age_group, "Sector": sector}
                if group:
                    heading[group] = LABELS.get(group, {}).get(str(group_code), str(group_code))
                yield heading, members


def rate_table(data, ages, group=None):
    """Calculate rates with the correct denominator for each one."""
    rows = []
    needed = ["Age", "Sector_code", "Gender", "Weight", "Worker", "Labour_force", "Unemployed"]
    if group:
        needed.append(group)
    for heading, members in table_slices(data[needed], ages, group=group):
        for gender in GENDERS:
            selected = members if gender == "Persons" else members.loc[members["Gender"].eq(gender)]
            total = selected["Weight"].sum()
            labour_force = selected.loc[selected["Labour_force"], "Weight"].sum()
            workers = selected.loc[selected["Worker"], "Weight"].sum()
            unemployed = selected.loc[selected["Unemployed"], "Weight"].sum()
            # LFPR and WPR divide by all persons; UR divides by the labour force.
            # An empty denominator gives a blank result, not a zero rate.
            rows.append({
                **heading, "Gender": gender, "Sample_persons": len(selected),
                "Weighted_persons": total,
                "LFPR": 100 * labour_force / total if total else np.nan,
                "WPR": 100 * workers / total if total else np.nan,
                "UR": 100 * unemployed / labour_force if labour_force else np.nan,
            })
    return pd.DataFrame(rows)


def percentage_table(data, column, ages, population="Workers", group=None, combined=True):
    """Show each category's share for men, women and all persons."""
    rows = []
    needed = list(dict.fromkeys([
        "Age", "Sector_code", "Gender", "Weight", "Worker", "Labour_force", column,
    ] + ([group] if group else [])))
    for heading, members in table_slices(data[needed], ages, population, group, combined):
        # Blank answers are left out, just as Stata's tabulation does.
        members = members.dropna(subset=[column])
        if members.empty:
            continue
        counts = members.groupby([column, "Gender"], observed=True)["Weight"].sum().unstack(fill_value=0)
        counts = counts.reindex(columns=["Male", "Female"], fill_value=0)
        # Pool the weighted counts; do not average male and female percentages.
        counts["Persons"] = counts.sum(axis=1)
        denominator = counts.sum().replace(0, np.nan)
        percentages = counts.div(denominator, axis=1) * 100
        if not np.allclose(percentages.sum()[denominator.notna()], 100):
            raise ValueError(f"The percentages in {column} do not add up to 100.")
        if column == "Broad_status":
            percentages = percentages.reindex(["1", "2", "3", "4"], fill_value=0)
            percentages.loc["self"] = percentages.loc[["1", "2"]].sum(min_count=1)
            percentages = percentages.reindex(["1", "2", "self", "3", "4"])
        percentages.loc[:, denominator.isna()] = np.nan
        percentages.loc["total"] = np.where(denominator.notna(), 100.0, np.nan)
        for code, values in percentages.iterrows():
            label = "All reported categories" if code == "total" else LABELS.get(column, {}).get(str(code), str(code))
            rows.append({**heading, "Code": str(code), column: label, **values.to_dict()})
    return pd.DataFrame(rows)


def spending_means(data):
    """Match the do-file's person-weighted household-spending means."""
    rows = []
    columns = ["Age", "Sector_code", "Gender", "Weight", "Household_monthly_spending"]
    for heading, members in table_slices(data[columns], ["All ages"]):
        for gender in GENDERS:
            selected = members if gender == "Persons" else members.loc[members["Gender"].eq(gender)]
            selected = selected.dropna(subset=["Household_monthly_spending"])
            total = selected["Weight"].sum()
            spending_total = (selected["Weight"] * selected["Household_monthly_spending"]).sum()
            rows.append({
                **heading, "Gender": gender, "Sample_persons": len(selected),
                "Mean_rupees": spending_total / total if total else np.nan,
            })
    return pd.DataFrame(rows)


def make_tables(data):
    """Make the table families covered in the Stata examples."""
    tables = {
        "rates": rate_table(data, ["All ages", "15+", "15-29"]),
        "rates_social_group": rate_table(data, ["All ages", "15+"], "Social_group"),
        "rates_state_youth": rate_table(data, ["15-29"], "State_code"),
    }
    notes = [
        {"Sheet": name, "Population": "All persons", "Ages": ages,
         "Meaning": "LFPR and WPR use all persons; UR uses the labour force. Rates are percentages."}
        for name, ages in [("rates", "All ages; 15+; 15-29"), ("rates_social_group", "All ages; 15+"), ("rates_state_youth", "15-29")]
    ]
    # Each row names a table, its category, population, ages and optional grouping.
    specifications = [
        ("employment_status", "Broad_status", "Workers", ["All ages", "15+"], None),
        ("employment_social_group", "Broad_status", "Workers", ["All ages", "15+"], "Social_group"),
        ("employment_religion", "Broad_status", "Workers", ["All ages", "15+"], "Religion"),
        ("employment_NIC_broad", "Broad_status", "Workers", ["All ages", "15+"], "NIC_broad"),
        ("employment_NIC_three", "Broad_status", "Workers", ["All ages", "15+"], "NIC_three"),
        ("NIC_division", "NIC_division", "Workers", ["All ages", "15+"], None),
        ("NIC_broad", "NIC_broad", "Workers", ["All ages", "15+"], None),
        ("NIC_three", "NIC_three", "Workers", ["All ages", "15+"], None),
        ("NCO_group", "NCO", "Workers", ["All ages", "15+"], None),
        ("NCO_subdivision", "NCO_subdivision", "Workers", ["All ages", "15+"], None),
        ("NCO_division", "NCO_division", "Workers", ["All ages", "15+"], None),
        ("vocational_labour_force", "Training_code", "Labour force", ["15+"], None),
        ("vocational_15_59", "Training_code", "All persons", ["15-59"], None),
        ("social_security", "Social_security", "Labour force", ["15+"], None),
        ("household_type", "Household_type", "Labour force", ["15+"], None),
        ("religion", "Religion", "Labour force", ["15+"], None),
        ("social_group", "Social_group", "Labour force", ["15+"], None),
        ("household_spending", "Household_spending_band", "Labour force", ["15+"], None),
        ("marital_status", "Marital_status", "Labour force", ["15+"], None),
        ("attendance", "Attendance_group", "Labour force", ["15+"], None),
        ("training_field", "Training_field", "Labour force", ["15+"], None),
        ("training_duration", "Training_duration", "Labour force", ["15+"], None),
        ("training_type", "Training_type", "Labour force", ["15+"], None),
        ("economic_months", "Economic_months", "Labour force", ["15+"], None),
        ("efforts_to_find_work", "Efforts_to_find_work", "Labour force", ["15+"], None),
        ("unemployment_duration", "Unemployment_duration", "Labour force", ["15+"], None),
        ("reason_not_working", "Reason_not_working", "Labour force", ["15+"], None),
    ]
    for name, column, population, ages, group in specifications:
        tables[name] = percentage_table(
            data, column, ages, population, group, combined=column != "Household_type",
        )
        notes.append({
            "Sheet": name, "Population": population, "Ages": "; ".join(ages),
            "Meaning": "Percent within each age, sector, gender and group; blank answers excluded.",
        })
    tables["mean_HH_spending"] = spending_means(data)
    notes.append({
        "Sheet": "mean_HH_spending", "Population": "All persons", "Ages": "All ages",
        "Meaning": "Person-weighted household spending, not a household-average estimate. No standard errors.",
    })
    return tables, pd.DataFrame(notes)


# 6. Optional check: compare calculated values with the source PDF.
def verify_tables(tables, mode, pdf_path):
    """Compare selected table entries with the numbers printed in a PDF."""
    try:
        import fitz
    except ImportError as error:
        raise ValueError("PDF checking needs PyMuPDF. Install it or run without --verify.") from error
    if not pdf_path.is_file():
        raise ValueError(f"Cannot find the reference PDF: {pdf_path}")
    checks = []

    def compare(sheet, age, sector, code, gender, expected, decimals, group=None, group_name=None):
        table = tables[sheet]
        mask = table["Age_group"].eq(age) & table["Sector"].eq(sector) & table["Code"].eq(code)
        if group:
            mask &= table[group].eq(group_name)
        selected = table.loc[mask, gender]
        if len(selected) != 1:
            raise ValueError(f"Cannot locate one comparison row in {sheet}: {sector}, {code}.")
        actual = float(selected.iloc[0])
        checks.append({
            "Sheet": sheet, "Age_group": age, "Sector": sector,
            "Group": group_name or "All", "Code": code, "Gender": gender,
            "Python_value": actual, "PDF_value": float(expected),
            "Decimal_places": decimals, "Matches": f"{actual:.{decimals}f}" == expected,
        })

    with fitz.open(pdf_path) as document:
        if mode == "annual":
            if len(document) < 393:
                raise ValueError("Expected the full PLFS 2023-24 annual report for annual verification.")
            # These page locations belong to this report, not every PLFS edition.
            occupation_text = "\n".join(document[page - 1].get_text(sort=True) for page in [210, 211, 212])
            social_text = document[392].get_text(sort=True)
            number = r"(\d+\.\d+)"
            rows = re.findall(r"(?m)^\s*Division\s+([1-9])\s+" + r"\s+".join([number] * 9), occupation_text)
            if len(rows) != 9:
                raise ValueError("Could not read all nine occupation divisions from annual Table 25.")
            for division, *expected in rows:
                for position, (sector, gender) in enumerate(
                    (sector, gender) for sector in SECTORS for gender in GENDERS
                ):
                    compare("NCO_division", "All ages", sector, division, gender, expected[position], 2)
            for group_code, heading in [
                ("1", "scheduled tribe"), ("2", "scheduled caste"), ("3", "other backward classes"),
            ]:
                marker = re.search(r"social group:\s*" + heading, social_text, re.I)
                if marker is None:
                    raise ValueError(f"Could not find {heading} in annual Table 46.")
                block = re.split(r"social group:", social_text[marker.end():], flags=re.I)[0]
                rows = re.findall(
                    r"(?m)^\s*(rural\s*\+\s*urban|rural|urban)\s+(male|female|person)\s+"
                    + r"\s+".join([number] * 6), block,
                )
                if len(rows) != 9:
                    raise ValueError(f"Could not read the nine sector/gender rows for {heading}.")
                for sector_text, gender_text, *expected in rows:
                    sector = "Rural + Urban" if "+" in sector_text else sector_text.title()
                    gender = "Persons" if gender_text == "person" else gender_text.title()
                    for code, value in zip(["1", "2", "self", "3", "4", "total"], expected):
                        compare(
                            "employment_social_group", "All ages", sector, code, gender, value, 1,
                            "Social_group", LABELS["Social_group"][group_code],
                        )
        else:
            text = "\n".join(page.get_text(sort=True) for page in document)
            pattern = r"(?m)^\s*\d+\s*\.\s*(tab\s+(?:Gender\s+Broad_Status|NCO_Divison\s+Gender)[^\r\n]*)"
            commands = list(re.finditer(pattern, text))
            if not commands:
                raise ValueError("No supported Stata table commands were found in the video PDF.")
            for command_match in commands:
                command = command_match.group(1)
                remaining = text[command_match.end():]
                next_command = re.search(r"(?m)^\s*\d+\s*\.", remaining)
                block = remaining[:next_command.start()] if next_command else remaining
                sector_match = re.search(r"Sector\s*==\s*(\d+)", command)
                sector = {"1": "Rural", "2": "Urban"}[sector_match.group(1)] if sector_match else "Rural + Urban"
                age = "15+" if re.search(r"Age\s*>=\s*15", command) else "All ages"
                if "Broad_Status" in command:
                    sheet, group, group_name = "employment_status", None, None
                    for stata_name, column in [("Social_Group", "Social_group"), ("Religion", "Religion")]:
                        restriction = re.search(stata_name + r"\s*==\s*(\d+)", command)
                        if restriction:
                            group = column
                            group_name = LABELS[column][restriction.group(1)]
                            sheet = "employment_social_group" if column == "Social_group" else "employment_religion"
                    rows = re.findall(
                        r"(?m)^\s*(Male|Female|Total)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+100\.00",
                        block,
                    )
                    if len(rows) != 3:
                        raise ValueError(f"Could not read all gender rows for: {command}")
                    for gender, *expected in rows:
                        gender = "Persons" if gender == "Total" else gender
                        for code, value in zip(["1", "2", "3", "4"], expected):
                            compare(sheet, age, sector, code, gender, value, 2, group, group_name)
                else:
                    rows = re.findall(r"(?m)^\s*([1-9])\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s*$", block)
                    if len(rows) != 9:
                        raise ValueError(f"Could not read all occupation divisions for: {command}")
                    for division, *expected in rows:
                        for gender, value in zip(GENDERS, expected):
                            compare("NCO_division", age, sector, division, gender, value, 2)
    return pd.DataFrame(checks)


# 7. Save tables and a short record of what was checked.
def save_results(data, audit, tables, guide, output_dir, save_merged=False, checks=None):
    """Save new results without changing the source CSV files."""
    output_dir.mkdir(parents=True, exist_ok=True)
    notes = {
        "Mode": audit["mode"],
        "Inputs": "First-visit household and person CSV files only. No revisit records are used.",
        "Annual mode": "Weight = multiplier / (100 if NSS = NSC, otherwise 200) / contributing quarters.",
        "Gender in annual mode": "Code 3 is included in Male to follow report section 1.5.3; original code is kept.",
        "Video mode": "Uses the original Stata weights and drops gender code 3. For reproducing the old output only.",
        "Age": "All ages and 15+ are separate. Choose the same age group as the table you are comparing.",
        "Percentages": "Male, Female and Persons are weighted percentages, not sample counts.",
        "Totals": "All self-employed is a subtotal; do not add it again to its two parts.",
        "Rates": "LFPR = labour force / persons; WPR = workers / persons; UR = unemployed / labour force, times 100.",
        "Spending": "Household spending bands are not per-person spending (MPCE).",
        "Household type": "Code meanings differ between rural and urban areas, so no combined-sector table is made.",
        "Other codes": "Unlabelled categories keep the supplied survey codes. See the questionnaire for their meanings.",
        "Coverage": "The workbook covers the do-file's table families, not every table in the annual report.",
        "Precision": "These are point estimates only. Survey-design standard errors are not calculated.",
        "Sources": "PLFS README section B; Estimation Procedure section 4.2.1; Annual Report section 1.5.3.",
    }
    workbook_tables = {
        "Read_me": pd.DataFrame(notes.items(), columns=["Topic", "Explanation"]),
        "Table_guide": guide,
        "Merge_check": pd.DataFrame(audit.items(), columns=["Check", "Result"]),
        **tables,
    }
    if checks is not None:
        workbook_tables["PDF_check"] = checks
    with pd.ExcelWriter(output_dir / "plfs_tables.xlsx", engine="openpyxl") as writer:
        for name, table in workbook_tables.items():
            table.to_excel(writer, sheet_name=name, index=False)
            sheet = writer.sheets[name]
            sheet.freeze_panes = "C2"
            sheet.auto_filter.ref = sheet.dimensions
            for cells in sheet.columns:
                longest = max(len(str(cell.value or "")) for cell in list(cells)[:100])
                sheet.column_dimensions[cells[0].column_letter].width = min(max(longest + 2, 12), 65)
                for cell in cells[1:]:
                    if isinstance(cell.value, float):
                        cell.number_format = "0.00"
    (output_dir / "merge_audit.json").write_text(json.dumps(audit, indent=2), encoding="utf-8")
    if checks is not None:
        checks.to_csv(output_dir / "pdf_comparison.csv", index=False)
    if save_merged:
        data.to_csv(output_dir / "merged_first_visit.csv", index=False, encoding="utf-8-sig")


# Read from here first: each function above handles one step below.
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=ROOT / "CSV_data_PLFS_2023_2024",
                        help="Folder containing hhv1.csv and perv1.csv; no revisit files needed.")
    parser.add_argument("--mode", choices=["annual", "video"], default="annual",
                        help="annual: report weights; video: historical comparison only.")
    parser.add_argument("--output-dir", type=Path, help="Folder for generated results; reruns replace these results.")
    parser.add_argument("--save-merged", action="store_true", help="Also save the analysis data as CSV.")
    parser.add_argument("--check-only", action="store_true", help="Check the data and join without saving files.")
    parser.add_argument("--verify", action="store_true", help="Compare selected table cells with the reference PDF.")
    parser.add_argument("--reference-pdf", type=Path,
                        help="Use this PDF for --verify; video mode needs the separately obtained result PDF.")
    arguments = parser.parse_args()
    if arguments.check_only and (arguments.verify or arguments.save_merged):
        parser.error("--check-only cannot be combined with --verify or --save-merged.")
    if arguments.reference_pdf and not arguments.verify:
        parser.error("Use --verify with --reference-pdf.")
    try:
        print("Step 1: read the first-visit CSV files and check the household-person join.", flush=True)
        data, audit = load_first_visits(arguments.data_dir, arguments.mode)
        print("Step 2: apply the selected weights and prepare the employment definitions.", flush=True)
        data = prepare_variables(data)
        if arguments.check_only:
            print(json.dumps(audit, indent=2))
            return
        print("Step 3: calculate weighted rates and category tables.", flush=True)
        tables, guide = make_tables(data)
        output_dir = arguments.output_dir or ROOT / "plfs_output" / arguments.mode
        checks = None
        if arguments.verify:
            print("Step 4: compare selected values with the reference PDF.", flush=True)
            pdf_name = "AnnualReport_PLFS2023-24L2.pdf" if arguments.mode == "annual" else "PLFS_exercise_result.pdf"
            reference_pdf = arguments.reference_pdf or ROOT / pdf_name
            checks = verify_tables(tables, arguments.mode, reference_pdf)
            audit["reference_pdf"] = str(reference_pdf.resolve())
            audit["pdf_cells_checked"] = len(checks)
            audit["pdf_cells_matched"] = int(checks["Matches"].sum())
        print("Save results: Excel tables, merge checks, and any requested CSV files.", flush=True)
        save_results(data, audit, tables, guide, output_dir, arguments.save_merged, checks)
        if checks is not None and not checks["Matches"].all():
            raise ValueError(f"Some PDF values differ. See {output_dir / 'pdf_comparison.csv'}.")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Stopped: {error}\n")
    print(f"Matched {audit['matched_persons']:,} persons to {audit['households']:,} households.")
    print(f"Mode: {arguments.mode}. Persons used: {audit['persons_used']:,}.")
    print(f"Saved {len(tables)} table sheets to {output_dir / 'plfs_tables.xlsx'}")
    if checks is not None:
        print(f"PDF check passed: {len(checks):,} cells match at the printed precision.")
    headline = tables["rates"]
    headline = headline.loc[
        headline["Age_group"].eq("15+") & headline["Sector"].eq("Rural + Urban")
        & headline["Gender"].eq("Persons"), ["LFPR", "WPR", "UR"],
    ]
    print("All-India, age 15+ (%):")
    print(headline.to_string(index=False, float_format=lambda value: f"{value:.1f}"))


if __name__ == "__main__":
    main()