/*---------------- PLFS 2023-24: Extended annual analysis ----------------*/
// Start with PLFS_walkthrough.do for the first lesson. This file runs independently.
// Read first visits -> check the merge -> weight people -> define groups -> make tables.
// These are usual-status (ps+ss) point estimates, not CWS or survey standard errors.
// Run the whole file. Save unsaved Stata work before clear all.
version 14.0
clear all
set more off

/*---------------- 1. Set paths ----------------*/
// Example for this computer; root contains the dta_data_PLFS_2023_2024 folder.
local root "C:/Users/mdsarfraj/Pictures/PLFS"
local data "`root'/dta_data_PLFS_2023_2024"
local output "`root'/stata_output"
// Set 0 only for an intentional subset exercise; structural checks stay on.
local check_report 1
// Stop early if either first-visit file is missing.
foreach source in hhv1 perv1 {
  confirm file "`data'/`source'.dta"
}
capture mkdir "`output'"
capture log close plfs_analysis
log using "`output'/PLFS_refactored.log", text replace name(plfs_analysis)
tempfile household_first_visit

/*---------------- 2. Identify each household ----------------*/
// First visit is not first quarter. hhv1 and perv1 contain Q1-Q4 first visits.
// Annual usual-status estimates use first visits; revisits need a separate workflow.
// Source: Estimation Procedure 4.2.1 and official README, section B.
use "`data'/hhv1.dta", clear

// Keep key fields as text, including leading zeros. Their widths total 14 characters.
rename (qtr_hhv1 visit_hhv1 b1q3_hhv1 b1q1_hhv1 b1q13_hhv1 b1q14_hhv1 b1q15_hhv1) ///
       (Quarter Visit Sector fsu hamlet sss shn)
assert inlist(Quarter, "Q1", "Q2", "Q3", "Q4") & Visit == "V1"
assert inlist(Sector, "1", "2")
assert strlen(fsu) == 5 & strlen(hamlet) == 1 & strlen(sss) == 1 & strlen(shn) == 2
foreach part in fsu hamlet sss shn {
    assert !regexm(`part', "[^0-9]")
}
gen str14 HHID = Quarter + Visit + Sector + fsu + hamlet + sss + shn
// isid stops on duplicate or missing IDs; tempfile leaves the source file unchanged.
isid HHID
save "`household_first_visit'"

/*---------------- 3. Prepare people and annual weights ----------------*/
use "`data'/perv1.dta", clear
rename (NSS_perv1 NSC_perv1 mult_perv1) (NSS NSC Mult)
// NSS/NSC count sampled FSUs, not people. MULT has two implied decimal places.
assert !missing(Mult, NSS, NSC, no_qtr_perv1)
assert Mult > 0 & NSS > 0 & NSC > 0 & inlist(no_qtr_perv1, 1, 2, 3, 4)
gen double weight_quarter = Mult / 100 if NSS == NSC
replace weight_quarter = Mult / 200 if NSS != NSC
// NO_QTR counts contributing quarters for the sampling group, not a person's visits.
// Use the supplied value, not always 4. Apply this annual adjustment only once.
gen double weight = weight_quarter / no_qtr_perv1
assert weight > 0 & weight < .
label variable weight "Annual combined-sample weight"

rename (qtr_perv1 visit_perv1 b1q3_perv1 b1q1_perv1 b1q13_perv1 b1q14_perv1 b1q15_perv1 b4q1_perv1) ///
       (Quarter Visit Sector fsu hamlet sss shn psn)
assert inlist(Quarter, "Q1", "Q2", "Q3", "Q4") & Visit == "V1"
assert inlist(Sector, "1", "2")
assert strlen(fsu) == 5 & strlen(hamlet) == 1 & strlen(sss) == 1 & strlen(shn) == 2
assert strlen(psn) == 2
foreach part in fsu hamlet sss shn psn {
    assert !regexm(`part', "[^0-9]")
}
gen str14 HHID = Quarter + Visit + Sector + fsu + hamlet + sss + shn
gen str16 PID = HHID + psn
// Several people share an HHID. The extra member number makes PID unique.
isid PID

/*---------------- 4. Attach household details to each person ----------------*/
// m:1 = many persons to one household. keepusing selects columns, not observations.
local persons_before_merge = _N
merge m:1 HHID using "`household_first_visit'", ///
    keepusing(state_hhv1 b3q1_hhv1 b3q2_hhv1 b3q3_hhv1 b3q4_hhv1 b3q5pt6_hhv1 ///
              nss_hhv1 nsc_hhv1 mult_hhv1 no_qtr_hhv1)
tab _merge
// 1 = person without HH; 2 = HH without persons; 3 = matched. Do not drop failures.
// Complete checked release: 418,159 persons matched to 101,920 households.
assert _merge == 3
assert _N == `persons_before_merge'
isid PID

// The two sources must agree on state and every weight component.
assert state_perv1 == state_hhv1
assert NSS == nss_hhv1 & NSC == nsc_hhv1 & Mult == mult_hhv1
assert no_qtr_perv1 == no_qtr_hhv1
drop _merge

// A reusable merged copy, before analysis renames. Only generated outputs are replaced.
save "`output'/HH_Ind_merged.dta", replace

/*---------------- 5. Give variables and categories readable names ----------------*/
rename (b5pt1q3_perv1 b5pt2q3_perv1) (Status_Code_PP Status_Code_SS)
rename (b3q4_hhv1 b4q5_perv1 b4q6_perv1 b3q3_hhv1 state_hhv1 b3q5pt6_hhv1) ///
       (Social_Group Gender Age Religion State HH_Monthly_Exp)
rename (b4q7_perv1 b4q8_perv1 b4q9_perv1) (Marital_Status General_Edu Tech_Edu)
destring Gender Sector State Social_Group Religion Marital_Status Status_Code_PP Status_Code_SS, replace
// In Stata, missing numeric values exceed real numbers. Age >= 15 alone includes them.
assert Age >= 0 & Age < .
assert inlist(Gender, 1, 2, 3)
assert inlist(Social_Group, 1, 2, 3, 9)
assert inlist(Religion, 1, 2, 3, 4, 5, 6, 7, 9)
// Report section 1.5.3 includes code 3 in Male; retain the original code as well.
clonevar Gender_Original = Gender
replace Gender = 1 if Gender == 3
label define Gender_lbl 1 "Male" 2 "Female"
label values Gender Gender_lbl
label define Sector_lbl 1 "Rural" 2 "Urban"
label values Sector Sector_lbl
label define Social_Group_lbl 1 "ST" 2 "SC" 3 "OBC" 9 "Others"
label values Social_Group Social_Group_lbl
label define Religion_lbl 1 "Hindu" 2 "Muslim" 3 "Christian" 4 "Sikh" ///
    5 "Jain" 6 "Buddhist" 7 "Zoroastrian" 9 "Others"
label values Religion Religion_lbl
label define State_lbl 1 "Jammu and Kashmir" 2 "Himachal Pradesh" 3 "Punjab" ///
    4 "Chandigarh" 5 "Uttarakhand" 6 "Haryana" 7 "Delhi" 8 "Rajasthan" ///
    9 "Uttar Pradesh" 10 "Bihar" 11 "Sikkim" 12 "Arunachal Pradesh" ///
    13 "Nagaland" 14 "Manipur" 15 "Mizoram" 16 "Tripura" 17 "Meghalaya" ///
    18 "Assam" 19 "West Bengal" 20 "Jharkhand" 21 "Odisha" 22 "Chhattisgarh" ///
    23 "Madhya Pradesh" 24 "Gujarat" 25 "Dadra and Nagar Haveli and Daman and Diu" ///
    27 "Maharashtra" 28 "Andhra Pradesh" 29 "Karnataka" 30 "Goa" 31 "Lakshadweep" ///
    32 "Kerala" 33 "Tamil Nadu" 34 "Puducherry" 35 "Andaman and Nicobar Islands" ///
    36 "Telangana" 37 "Ladakh"
label values State State_lbl

/*---------------- 6. Workers, labour force and the three rates ----------------*/
// PP = principal activity over the past 365 days. SS = qualifying subsidiary work.
// SS needs at least 30 days of work. The survey already supplies these status codes.
// Reject unknown codes instead of silently counting them as outside the labour force.
assert inlist(Status_Code_PP, 11, 12, 21, 31, 41, 51, 81, 91, 92, 93, 94, 95, 97, 99)
assert missing(Status_Code_SS) | inlist(Status_Code_SS, 11, 12, 21, 31, 41, 51)
// 11/12 = own account/employer; 21 = unpaid HH helper; 31 = salaried; 41/51 = casual.
// WPR here is a 0/1 worker flag, not a percentage. Unpaid domestic duties are not code 21.
gen byte WPR_ps = inlist(Status_Code_PP, 11, 12, 21, 31, 41, 51)
gen byte WPR_ss = inlist(Status_Code_SS, 11, 12, 21, 31, 41, 51)
gen byte WPR = (WPR_ps == 1 | WPR_ss == 1)
label variable WPR "Worker in usual status: 1 yes, 0 no"
gen byte Labor_Force = (WPR == 1 | Status_Code_PP == 81)
gen byte Unemployed = (Labor_Force == 1 & WPR == 0)
// PP 81 + SS 21 counts as employed, not unemployed, under ps+ss.
assert WPR <= Labor_Force
assert WPR + Unemployed == Labor_Force

// Use this same job in every employment, industry, occupation and benefit table.
gen byte Status_used = Status_Code_PP if WPR_ps == 1
replace Status_used = Status_Code_SS if WPR_ps == 0 & WPR_ss == 1

// LFPR = labour force / persons; WPR = workers / persons; UR = unemployed / labour force.
// With 57 workers and 3 unemployed among 100 people: LFPR 60%, WPR 57%, UR 5%.
gen double Labour_Force_Perct = 100 * Labor_Force
gen double WPR_Perct = 100 * WPR
gen double UR_Perct = 100 * Unemployed if Labor_Force == 1
label variable Labour_Force_Perct "LFPR (%)"
label variable WPR_Perct "WPR (%)"
label variable UR_Perct "UR (%)"
// Blank UR values exclude people outside the labour force from its denominator.
// iweights give point estimates here. They do not specify the PLFS survey design.
display "LFPR, usual status (ps+ss), age 15+"
table Gender Sector if Age >= 15 & Age < . [iw=weight], ///
    c(mean Labour_Force_Perct) row col format(%9.1f)
display "WPR, usual status (ps+ss), age 15+"
table Gender Sector if Age >= 15 & Age < . [iw=weight], ///
    c(mean WPR_Perct) row col format(%9.1f)
display "UR, usual status (ps+ss), age 15+"
table Gender Sector if Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], ///
    c(mean UR_Perct) row col format(%9.1f)

// Annual Report: Statements 2, 4 and 15 ('all' education); PDF pages 36, 39 and 51.
// These are all-India persons, age 15+, rounded to one decimal place.
if `check_report' {
    quietly summarize Labour_Force_Perct if Age >= 15 & Age < . [iw=weight], meanonly
    assert abs(r(mean) - 60.1) < 0.05
    quietly summarize WPR_Perct if Age >= 15 & Age < . [iw=weight], meanonly
    assert abs(r(mean) - 58.2) < 0.05
    quietly summarize UR_Perct if Age >= 15 & Age < . [iw=weight], meanonly
    assert abs(r(mean) - 3.2) < 0.05
}

// Each pass repeats the same table with a different indicator; no rows are dropped.
// row/col add pooled totals; scolumn adds Rural + Urban for a three-way table.
foreach rate in Labour_Force_Perct WPR_Perct UR_Perct {
    local rate_name : variable label `rate'
    display "`rate_name' by social group, all ages"
    table Social_Group Gender Sector [iw=weight], ///
        c(mean `rate') row col scolumn format(%9.1f)
}
display "Youth LFPR by state, age 15-29"
table State Gender Sector if inrange(Age, 15, 29) [iw=weight], ///
    c(mean Labour_Force_Perct) row col scolumn format(%9.1f)

/*---------------- 7. Describe the selected job ----------------*/
// NIC-2008 describes the industry; NCO-2015 describes the person's occupation.
// Keep the full codes as text. Only the two-digit NIC grouping becomes numeric.
rename (b5pt1q5_perv1 b5pt2q5_perv1) (NIC_PP NIC_SS)
rename (b5pt1q6_perv1 b5pt2q6_perv1) (NCO_PP NCO_SS)
gen str5 NIC_combined = NIC_PP if WPR_ps == 1
replace NIC_combined = NIC_SS if WPR_ps == 0 & WPR_ss == 1
gen str3 NCO_combined = NCO_PP if WPR_ps == 1
replace NCO_combined = NCO_SS if WPR_ps == 0 & WPR_ss == 1
// A blank principal-job detail must not silently be replaced by a different job.
assert strlen(NIC_combined) == 5 & !regexm(NIC_combined, "[^0-9]") if WPR == 1
assert strlen(NCO_combined) == 3 & !regexm(NCO_combined, "[^0-9]") if WPR == 1
gen str2 NIC_two_Combined = substr(NIC_combined, 1, 2)
gen str1 NCO_Division = substr(NCO_combined, 1, 1)
gen str2 NCO_Subdivision = substr(NCO_combined, 1, 2)
destring NIC_two_Combined, replace
recode NIC_two_Combined (1/3 = 1 "Agriculture") (5/9 = 2 "Mining and quarrying") ///
    (10/33 = 3 "Manufacturing") (35/39 = 4 "Electricity and water supply") ///
    (41/43 = 5 "Construction") (45/47 = 7 "Trade") (49/53 = 8 "Transport") ///
    (55/56 = 9 "Accommodation and food services") (58/99 = 10 "Other services") ///
    (else = .), gen(NIC_Broad)
recode NIC_two_Combined (1/3 = 1 "Agriculture") (5/43 = 6 "Secondary") ///
    (45/99 = 11 "Tertiary") (else = .), gen(NIC_Broad_Three)
assert !missing(NIC_Broad, NIC_Broad_Three) if WPR == 1

gen byte Broad_Status = .
replace Broad_Status = 1 if inlist(Status_used, 11, 12)
replace Broad_Status = 2 if Status_used == 21
replace Broad_Status = 3 if Status_used == 31
replace Broad_Status = 4 if inlist(Status_used, 41, 51)
assert !missing(Broad_Status) if WPR == 1
assert missing(Broad_Status) if WPR == 0
label define Broad_Status_lbl 1 "Own account / employer" 2 "Unpaid HH helper" ///
    3 "Regular wage / salary" 4 "Casual labour"
label values Broad_Status Broad_Status_lbl
// Report Table 46 uses ALL AGES. Its 'all self-employed' column is categories 1 + 2.
gen double Unpaid_Perct = 100 * (Broad_Status == 2) if WPR == 1
if `check_report' {
    quietly summarize Unpaid_Perct if Sector == 1 & Social_Group == 1 & Gender == 1 [iw=weight], meanonly
    assert abs(r(mean) - 14.7) < 0.05
}

// Benefits belong to the selected job. A self-employed principal worker may also
// have a casual subsidiary job; those benefits do not describe the principal job.
// Source: Instruction Manual I, 3.5.1.21; questionnaire Blocks 5.1 and 5.2.
gen str1 Social_Security = b5pt1q13_perv1 if WPR_ps == 1
replace Social_Security = b5pt2q12_perv1 if WPR_ps == 0 & WPR_ss == 1
destring Social_Security, replace
assert inrange(Social_Security, 1, 9) | missing(Social_Security)
assert missing(Social_Security) if !inlist(Status_used, 31, 41, 51)
label define Social_Security_lbl 1 "PF/pension only" 2 "Gratuity only" ///
    3 "Health/maternity only" 4 "PF/pension and gratuity" ///
    5 "PF/pension and health/maternity" 6 "Gratuity and health/maternity" ///
    7 "All three benefits" 8 "Not eligible for these benefits" 9 "Not known"
label values Social_Security Social_Security_lbl

/*---------------- 8. Prepare training, attendance and household categories ----------------*/
rename (b4q12_perv1 b4q11_perv1 b3q2_hhv1) (Voc_Edu Current_Attendance HH_Type)
rename (b4pt1q4_perv1 b4pt1q5_perv1 b4pt1q6_perv1) ///
       (field_of_training Duration_of_training type_of_training)
destring Voc_Edu Current_Attendance Duration_of_training type_of_training, replace
// Training is collected at ages 12-59; our adult examples deliberately use 15-59.
// Field, duration and type describe formal training only (Voc_Edu == 1).
// Sources: Instruction Manual I, 3.4.13 and 3.4.1.1.
label define Voc_Edu_lbl 1 "Formal" 2 "Hereditary" 3 "Self-learning" ///
    4 "Learning on the job" 5 "Other non-formal" 6 "No vocational training"
label values Voc_Edu Voc_Edu_lbl
label define Training_Duration_lbl 1 "Less than 3 months" 2 "3 to under 6 months" ///
    3 "6 to under 12 months" 4 "12 to under 18 months" ///
    5 "18 to under 24 months" 6 "24 months or more"
label values Duration_of_training Training_Duration_lbl
label define Training_Type_lbl 1 "On the job" 2 "Off the job, part-time" 3 "Off the job, full-time"
label values type_of_training Training_Type_lbl

// Attendance is asked below age 30, not at every age (Manual I, 3.4.12).
// This describes CURRENT attendance, not highest education completed.
recode Current_Attendance (1/5 = 1 "Never attended") (11/15 = 2 "Attended, not currently") ///
    (21/24 = 3 "Up to primary") (25 = 4 "Middle") (26 = 5 "Secondary") ///
    (27 = 6 "Higher secondary") (28/31 = 7 "Graduate") (32 = 8 "Postgraduate or above") ///
    (33/43 = 9 "Diploma/certificate") (else = .), gen(Curr_Atten_Grp)
assert !missing(Curr_Atten_Grp) if !missing(Current_Attendance)
label define Marital_Status_lbl 1 "Never married" 2 "Currently married" ///
    3 "Widowed" 4 "Divorced/separated"
label values Marital_Status Marital_Status_lbl

// Whole-household spending bands, NOT monthly per-capita expenditure (MPCE).
// The official README cautions against using PLFS as a standalone spending survey.
assert HH_Monthly_Exp >= 0 if !missing(HH_Monthly_Exp)
recode HH_Monthly_Exp (0/9999 = 1 "Below Rs 10,000") ///
    (10000/19999 = 2 "Rs 10,000-19,999") (20000/29999 = 3 "Rs 20,000-29,999") ///
    (30000/39999 = 4 "Rs 30,000-39,999") (40000/49999 = 5 "Rs 40,000-49,999") ///
    (50000/max = 6 "Rs 50,000 or more") (else = .), gen(HH_Spending_Band)

/*---------------- 9. Respect who was asked each work-history question ----------------*/
rename (b5pt3q6_perv1 b5pt3q7_perv1) (Dur_Eco_Act_PP Dur_Eco_Act_SS)
rename (b5pt3q8_perv1 b5pt3q9_perv1 b5pt3q11_perv1) ///
       (Efforts_to_Search_work Dur_Spell_Unemp Reason_Not_Working)
gen str1 Dur_Eco_Activity = Dur_Eco_Act_PP if WPR_ps == 1
replace Dur_Eco_Activity = Dur_Eco_Act_SS if WPR_ps == 0 & WPR_ss == 1
destring Dur_Eco_Activity Efforts_to_Search_work Dur_Spell_Unemp Reason_Not_Working, replace
// These are duration BANDS, not the number of months worked in the reference year.
// The same band codes apply to activity duration and unemployment duration.
// Source: Instruction Manual I, 3.5.3.5-3.5.3.8.
label define Duration_Band_lbl 1 "Up to 6 months" 2 "Over 6 months to 1 year" ///
    3 "Over 1 to 2 years" 4 "Over 2 to 3 years" 5 "Over 3 years"
label values Dur_Eco_Activity Duration_Band_lbl
label values Dur_Spell_Unemp Duration_Band_lbl
label define Search_Effort_lbl 1 "Employers, advertisements or work sites" ///
    2 "Employment exchange" 3 "Private employment centre" ///
    4 "Finance to start a business" 5 "Relatives or friends" ///
    6 "Business permit or licence" 7 "Other efforts"
label values Efforts_to_Search_work Search_Effort_lbl
// Reasons are recorded for non-workers who worked BEFORE the last 365 days.
// This includes people outside the labour force, not only the unemployed.
// Reason codes: questionnaire Block 5.3 column 11; Manual I, 3.5.3.10.

/*---------------- 10. Repeat table families for rural, urban and combined areas ----------------*/
// The tables below are analysis examples, not claims to reproduce every report table.
// Each heading names the population and age group. Blanks are excluded, not coded 'no'.
// tab ..., row: each row sums to 100. tab ..., col: each column sums to 100.
// nof hides weighted counts; Total pools people rather than averaging percentages.
// foreach repeats a block. Here 0 means a combined VIEW, not a survey sector code.
foreach sector_code in 1 2 0 {
    local area "Rural + Urban"
    local area_filter "inlist(Sector, 1, 2)"
    if `sector_code' == 1 local area "Rural"
    if `sector_code' == 2 local area "Urban"
    if `sector_code' != 0 local area_filter "Sector == `sector_code'"

    // A. Worker distributions: the denominator is workers, not the labour force.
    foreach minimum_age in 0 15 {
        local age_name "all ages"
        if `minimum_age' == 15 local age_name "age 15+"
        display _newline "`area': employment type among workers, `age_name'"
        tab Gender Broad_Status if (`area_filter') & WPR == 1 & Age >= `minimum_age' & Age < . [iw=weight], nof row

        foreach category in NIC_two_Combined NIC_Broad NIC_Broad_Three NCO_combined NCO_Division NCO_Subdivision {
            display "`area': `category' among workers, `age_name'"
            tab `category' Gender if (`area_filter') & WPR == 1 & Age >= `minimum_age' & Age < . [iw=weight], nof col
        }

        // levelsof finds groups present in this sample. An absent group is not zero percent.
        foreach grouping in Social_Group Religion {
            quietly levelsof `grouping' if (`area_filter') & WPR == 1 & Age >= `minimum_age' & Age < ., local(group_codes)
            foreach group_code of local group_codes {
                local group_name : label (`grouping') `group_code'
                display "`area': employment type, `grouping' = `group_name', workers, `age_name'"
                tab Gender Broad_Status if (`area_filter') & WPR == 1 & `grouping' == `group_code' ///
                    & Age >= `minimum_age' & Age < . [iw=weight], nof row
            }
        }
    }

    // B. Within each industry: employment-type shares for persons, then each gender.
    foreach industry in NIC_Broad NIC_Broad_Three {
        display "`area': employment type by `industry', workers age 15+, persons"
        tab `industry' Broad_Status if (`area_filter') & WPR == 1 & Age >= 15 & Age < . [iw=weight], nof row
        display "`area': the same industry table separately for each gender"
        // bysort repeats the command separately for each gender; it does not pool them.
        bysort Gender: tab `industry' Broad_Status ///
            if (`area_filter') & WPR == 1 & Age >= 15 & Age < . [iw=weight], nof row
    }

    // C. Training: all adults aged 15-59, then the labour-force subset of that age group.
    display "`area': vocational training, all persons age 15-59"
    tab Voc_Edu Gender if (`area_filter') & inrange(Age, 15, 59) [iw=weight], nof col
    display "`area': vocational training, labour force age 15-59"
    tab Voc_Edu Gender if (`area_filter') & Labor_Force == 1 & inrange(Age, 15, 59) [iw=weight], nof col
    foreach detail in field_of_training Duration_of_training type_of_training {
        display "`area': `detail', formal trainees in the labour force, age 15-59"
        tab `detail' Gender if (`area_filter') & Labor_Force == 1 & Voc_Edu == 1 & inrange(Age, 15, 59) [iw=weight], nof col
    }

    // D. Employees in the selected job: regular and casual wage work, all industries.
    // This is NOT the report's narrower regular-salaried, non-agricultural indicator.
    display "`area': employer-provided benefits, employees age 15+, reported answers"
    tab Social_Security Gender if (`area_filter') & inlist(Status_used, 31, 41, 51) & Age >= 15 & Age < . [iw=weight], nof col

    // E. Profiles of the labour force: these distributions are not LFPRs.
    foreach characteristic in Religion Social_Group HH_Spending_Band Marital_Status {
        display "`area': `characteristic' within gender, labour force age 15+"
        tab Gender `characteristic' if (`area_filter') & Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], nof row
    }
    // Household-type codes mean different things in rural and urban areas. Do not pool them.
    if `sector_code' != 0 {
        display "`area': household type, labour force age 15+"
        tab Gender HH_Type if (`area_filter') & Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], nof row
    }
    display "`area': current educational attendance, labour force age 15-29"
    tab Gender Curr_Atten_Grp if (`area_filter') & Labor_Force == 1 & inrange(Age, 15, 29) [iw=weight], nof row

    // F. Each work-history question has its own eligible population.
    display "`area': duration in the selected activity, workers age 15+"
    tab Dur_Eco_Activity Gender if (`area_filter') & WPR == 1 & Age >= 15 & Age < . [iw=weight], nof col
    // Search efforts include PP 81 with subsidiary work; unemployment duration does not.
    display "`area': search efforts, principal-status unemployed, age 15+"
    tab Efforts_to_Search_work Gender if (`area_filter') & Status_Code_PP == 81 & Age >= 15 & Age < . [iw=weight], nof col
    display "`area': unemployment duration, ps+ss unemployed, age 15+"
    tab Dur_Spell_Unemp Gender if (`area_filter') & Unemployed == 1 & Age >= 15 & Age < . [iw=weight], nof col
    display "`area': reasons for not working, previous workers now non-working, age 15+"
    tab Reason_Not_Working Gender if (`area_filter') & WPR == 0 & Age >= 15 & Age < . [iw=weight], nof col
}

/*---------------- 11. Interpret spending and save outputs ----------------*/
// HH spending repeats for each member. This mean describes people by their HH spending,
// not the mean across households and not MPCE. It is an illustrative classifier only.
// table reports point estimates without suggesting survey-design standard errors.
display "Person-weighted household spending (rupees), all ages; illustrative only"
table Gender Sector [iw=weight], c(mean HH_Monthly_Exp) row col format(%12.2f)

// Keep all people in the prepared data. Table if conditions do not delete other people.
assert _N == `persons_before_merge'
isid PID
save "`output'/PLFS_analysis_data.dta", replace
display "Finished. Prepared data and the command log are in: `output'"
log close plfs_analysis
*----------------------------------------------------------------------------------------
* Table 13
 // Rural : Male + Female + Person
tab  Gender Religion[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof row

// Urban : Male + Female + Person
tab  Gender Religion[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof row

// Rural + Urban
tab  Gender Religion[iw=weight] if  Labor_Force==1 & Age>=15, nof row

*-----------------------------------------------------------------------------------------------------
* Table 14
// Rural : Male + Female + Person
tab  Gender Social_Group[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof row

// Urban : Male + Female + Person
tab  Gender Social_Group[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof row

// Rural + Urban
tab  Gender Social_Group[iw=weight] if  Labor_Force==1 & Age>=15, nof row

*---------------------------------------------------------------------------------------------------------------
* Table -15
// MPCE is the old variable name here; these are HH spending bands, not per-person spending.
recode HH_Monthly_Exp (0/9999=1 "Less Than 10k") (10000/19999=2 "10k to 20k") (20000/29999=3 "20k to 30k") (30000/39999=4 "30k to 40k") (40000/49999=5 "40k to 50k") (50000/max=6 "More than 50k"), gen (MPCE)

// Rural : Male + Female + Person
tab  Gender MPCE[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof row

// Urban : Male + Female + Person
tab  Gender MPCE[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof row

// Rural + Urban
tab  Gender MPCE[iw=weight] if  Labor_Force==1 & Age>=15, nof row

*------------------------------------------------------------------------------------------------------------------------
* Table 16
*never married-1, currently married-2, widowed-3, divorced/separated-4.
label define Marital_Status 1 Never_Married 2 Currently_Married 3 Widowed 4 Separated
destring Marital_Status, replace
label values Marital_Status Marital_Status 

// Rural : Male + Female + Person
tab  Gender Marital_Status[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof row

// Urban : Male + Female + Person
tab  Gender Marital_Status[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof row

// Rural + Urban
tab  Gender Marital_Status[iw=weight] if  Labor_Force==1 & Age>=15, nof row

*----------------------------------------------------------------------------------------------------------------------------------------
* Table 18
rename b4q11_perv1 Current_Attendance
destring Current_Attendance, replace
recode Current_Attendance (01/05= 1 "Never_Attended") (11/15=2 "Attended_But_Not_currently") (21/24=3 "Upto_Primary") (25/25=4 "Middle") (26/26= 5 "Secondary") (27/27=6 "Higher_Secondary") (28/31=7 "Graduate") (32/32=8 "PG") (33/43=9 "Diploma_Certificate"), gen(Curr_Atten_Grp)

// Rural : Male + Female + Person
tab  Gender Curr_Atten_Grp[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof row

// Urban : Male + Female + Person
tab  Gender Curr_Atten_Grp[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof row

// Rural + Urban
tab  Gender Curr_Atten_Grp[iw=weight] if  Labor_Force==1 & Age>=15, nof row

*---------------------------------------------------------------------------------------------------------------------------------------------------------
*Table 19
rename b4pt1q4_perv1 field_of_training

// Rural : Male + Female + Person
tab  field_of_training Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab  field_of_training Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab  field_of_training Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col

*-----------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-20
rename b4pt1q5_perv1 Duration_of_training

// Rural : Male + Female + Person
tab  Duration_of_training Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Duration_of_training Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab  Duration_of_training Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col

*-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-21
rename b4pt1q6_perv1 type_of_training

// Rural : Male + Female + Person
tab type_of_training  Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab type_of_training  Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab type_of_training Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col

**---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-33
rename ( b5pt3q6_perv1 b5pt3q7_perv1) (Dur_Eco_Act_PP Dur_Eco_Act_SS)

gen str1 Dur_Eco_Activity = Dur_Eco_Act_PP if WPR_ps == 1
replace Dur_Eco_Activity = Dur_Eco_Act_SS if WPR_ps == 0 & WPR_ss == 1
 
// Rural : Male + Female + Person
tab Dur_Eco_Activity  Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Dur_Eco_Activity Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab Dur_Eco_Activity Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col 

**---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-34
rename b5pt3q8_perv1 Efforts_to_Search_work

// Asked of principal-status unemployed people, including those with subsidiary work.
// Rural : Male + Female + Person
tab Efforts_to_Search_work Gender [iw=weight] if Sector==1 & Status_Code_PP==81 & Age>=15, nof col

// Urban : Male + Female + Person
tab Efforts_to_Search_work Gender [iw=weight] if Sector==2 & Status_Code_PP==81 & Age>=15, nof col

// Rural + Urban
tab Efforts_to_Search_work Gender [iw=weight] if Status_Code_PP==81 & Age>=15, nof col
 
*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-35
rename b5pt3q9_perv1 Dur_Spell_Unemp

// Unlike search efforts, this question excludes people with subsidiary work.
// Rural : Male + Female + Person
tab Dur_Spell_Unemp Gender [iw=weight] if Sector==1 & Unemployed==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Dur_Spell_Unemp Gender [iw=weight] if Sector==2 & Unemployed==1 & Age>=15, nof col

// Rural + Urban
tab Dur_Spell_Unemp Gender [iw=weight] if Unemployed==1 & Age>=15, nof col

*-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-36
rename b5pt3q11_perv1 Reason_Not_Working

// Manual 3.5.3.10: non-workers who worked before the last 365 days.
// Retired people and others outside the labour force must not be excluded.
// tab excludes blanks: this is a distribution among reported reasons only.
// Rural : Male + Female + Person
tab Reason_Not_Working Gender [iw=weight] if Sector==1 & WPR==0 & Age>=15, nof col

// Urban : Male + Female + Person
tab Reason_Not_Working Gender [iw=weight] if Sector==2 & WPR==0 & Age>=15, nof col

// Rural + Urban
tab Reason_Not_Working Gender [iw=weight] if WPR==0 & Age>=15, nof col
