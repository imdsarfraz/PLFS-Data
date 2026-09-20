/*---------------- PLFS 2023-24: From raw data to annual tables ----------------*/
// Goal: one row per person, five worked tables, then extended annual analysis.
// Sections 1-12 teach the basics; sections 13-18 extend the same prepared data.
// Run the whole file from the top; local paths do not survive a separate selection.
// Save any unsaved Stata work first: clear all clears the data in memory.
// Stata 14+; version keeps the older table commands working on newer Stata.
version 14.0
clear all
set more off

// Example for this computer. Change root to your own PLFS data folder.
local root "C:/Users/mdsarfraj/Pictures/PLFS"
local data "`root'/dta_data_PLFS_2023_2024"
local output "`root'/plfs_learning_output"
// Use 1 for the complete 2023-24 release; 0 for an intentional subset exercise.
// This switches report comparisons only. ID, merge and definition checks stay on.
local check_report 1
// Check both inputs before starting; confirm does not change the files.
foreach source in hhv1 perv1 {
       confirm file "`data'/`source'.dta"
}
capture mkdir "`output'"
capture log close plfs_learning
log using "`output'/PLFS_walkthrough.log", text replace name(plfs_learning)

/*---------------- 1. What PLFS does ----------------*/
// PLFS surveys selected households, not every household in India.
// First, villages / urban blocks are sampled. These are called FSUs.
// Households are then selected within them; their members are interviewed.
// Weights allow these sampled people to represent the wider population.

// This is the July 2023-June 2024 design, not the redesigned survey from 2025.
// Rural HHs: one visit. Urban HHs: first visit + three quarterly revisits.
// New urban households enter as earlier households finish their four visits.
// A household's visit number and the survey quarter are different things.

/*---------------- 2. Which files do we need? ----------------*/
// hhv1: household details, first visit. Example: religion and social group.
// perv1: person details, first visit. Example: age and employment status.
// hhrv / perrv: household / person records for urban visits 2, 3 and 4.
// Each file covers the survey quarters Q1-Q4. First visit does NOT mean Q1.

// Usual status (ps+ss) looks at activity over the preceding 365 days.
// Current weekly status (CWS) looks at the preceding 7 days.
// First visits collect both; revisits update the weekly information.
// Here we make ANNUAL usual-status tables, so we use hhv1 + perv1 only.
// Source: Estimation Procedure, section 4.2.1; Instruction Manual I, Box 1.

// HH + person merge: add household columns to each member's row.
// First visit + revisit is a different task, not another HH-person merge.
// For quarterly CWS, harmonize visit columns and stack records with append,
// then use the appropriate quarterly sample and weights.
// Following one person across visits needs verified, stable identifiers.
// Do not simply remove Visit from the ID and assume the matches are correct.

/*---------------- 3. Prepare the household file ----------------*/
use "`data'/hhv1.dta", clear
count
tab qtr_hhv1 visit_hhv1
// In this release: 101,920 first-visit households across the four quarters.

// README Section B lists these seven fields as the household key.
// Keep them as text: household 01 should not lose its leading zero.
// fsu = sampled village/block; hamlet = segment; sss = second-stage stratum;
// shn = sampled household number within that group.
rename (qtr_hhv1 visit_hhv1 b1q3_hhv1 b1q1_hhv1 b1q13_hhv1 b1q14_hhv1 b1q15_hhv1) ///
       (Quarter Visit Sector fsu hamlet sss shn)
assert inlist(Quarter, "Q1", "Q2", "Q3", "Q4") & Visit == "V1"
assert inlist(Sector, "1", "2")
assert strlen(fsu) == 5 & strlen(hamlet) == 1 & strlen(sss) == 1 & strlen(shn) == 2
// foreach repeats the same check for each field; reject spaces and letters in IDs.
foreach part in fsu hamlet sss shn {
       assert !regexm(`part', "[^0-9]")
}
// The field widths add to 14; a person serial number adds two more characters.
gen str14 HHID = Quarter + Visit + Sector + fsu + hamlet + sss + shn

// isid checks that an ID is not missing or repeated.
// assert stops on a failed check; it does not change or delete observations.
isid HHID
list Quarter Visit HHID b3q4_hhv1 in 1/5, noobs

// A temporary copy keeps our original household file unchanged.
tempfile households
save "`households'"

/*---------------- 4. Prepare the person file ----------------*/
use "`data'/perv1.dta", clear
count
tab qtr_perv1 visit_perv1
// In this release: 418,159 first-visit persons, not just workers.

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
isid PID
// HHID can repeat here: several members belong to one household. PID cannot.

/*---------------- 5. Connect each person to their household ----------------*/
// m:1 means many persons matched to one household, using the same HHID.
// merge brings columns automatically; keepusing only limits that list.
local persons_before_merge = _N
merge m:1 HHID using "`households'", ///
       keepusing(state_hhv1 b3q1_hhv1 b3q2_hhv1 b3q3_hhv1 b3q4_hhv1 b3q5pt6_hhv1 ///
                       nss_hhv1 nsc_hhv1 mult_hhv1 no_qtr_hhv1)
tab _merge

// 1 = person without an HH match; 2 = HH without persons; 3 = matched.
// Expect 418,159 matched rows and no unmatched rows in these files.
assert _merge == 3
assert _N == `persons_before_merge'
isid PID
assert state_perv1 == state_hhv1
assert NSS_perv1 == nss_hhv1 & NSC_perv1 == nsc_hhv1
assert mult_perv1 == mult_hhv1 & no_qtr_perv1 == no_qtr_hhv1
drop _merge

/*---------------- 6. Apply the survey weights ----------------*/
// Each row is one sampled person. It does not represent one person nationally.
// NSS / NSC count surveyed FSUs in a sampling group, not household members.
// MULT has two implied decimal places; the combined-sample rule comes from the README.
rename (NSS_perv1 NSC_perv1 mult_perv1 no_qtr_perv1) (NSS NSC Mult NO_QTR)
assert !missing(NSS, NSC, Mult, NO_QTR)
assert NSS > 0 & NSC > 0 & Mult > 0 & inlist(NO_QTR, 1, 2, 3, 4)

gen double weight_quarter = Mult / 100 if NSS == NSC
replace weight_quarter = Mult / 200 if NSS != NSC
gen double weight = weight_quarter / NO_QTR
assert weight > 0 & weight < .
label variable weight "Annual combined-sample weight"

// NO_QTR = contributing quarters for the sampling group, not visits to a person.
// Use the supplied value, not a fixed 4. Some groups have fewer quarters.
// It annualizes pooled quarterly weights; do not divide by NO_QTR a second time.
// Source: README Section B, Generation of combined estimate for the entire Year.
tab NO_QTR
summarize weight

// A common factor cancels in a percentage, but not in a population total.
// If NO_QTR varies, percentages can change too. Use annual weights for both.

// Keep a full merged copy before selecting the lesson's columns and analysis names.
save "`output'/HH_Ind_merged.dta", replace

/*---------------- 7. Make the columns easier to read ----------------*/
// Keep the columns for the introductory and extended tables. Source files stay unchanged.
keep HHID PID Quarter Visit Sector fsu hamlet sss shn psn state_perv1 ///
       b4q5_perv1 b4q6_perv1 b3q1_hhv1 b3q2_hhv1 b3q3_hhv1 b3q4_hhv1 b3q5pt6_hhv1 ///
       b4q7_perv1 b4q8_perv1 b4q9_perv1 b4q11_perv1 b4q12_perv1 ///
       b4pt1q4_perv1 b4pt1q5_perv1 b4pt1q6_perv1 ///
       b5pt1q3_perv1 b5pt2q3_perv1 b5pt1q5_perv1 b5pt2q5_perv1 ///
       b5pt1q6_perv1 b5pt2q6_perv1 b5pt1q13_perv1 b5pt2q12_perv1 ///
       b5pt3q6_perv1 b5pt3q7_perv1 b5pt3q8_perv1 b5pt3q9_perv1 b5pt3q11_perv1 ///
        NSS NSC Mult NO_QTR weight_quarter weight
rename (state_perv1 b4q5_perv1 b4q6_perv1 b3q3_hhv1 b3q4_hhv1) ///
          (State Gender Age Religion Social_Group)
rename (b5pt1q3_perv1 b5pt2q3_perv1) (Status_Code_PP Status_Code_SS)
destring Gender Sector Social_Group Status_Code_PP Status_Code_SS, replace
assert Age >= 0 & Age < .
// An unknown activity code must not silently become 'not in the labour force'.
assert inlist(Status_Code_PP, 11, 12, 21, 31, 41, 51, 81, 91, 92, 93, 94, 95, 97, 99)
assert missing(Status_Code_SS) | inlist(Status_Code_SS, 11, 12, 21, 31, 41, 51)
assert inlist(Social_Group, 1, 2, 3, 9)

// Report section 1.5.3 includes gender code 3 in Male when presenting estimates.
// Keep the original code too; this grouping is for report replication only.
assert inlist(Gender, 1, 2, 3)
clonevar Gender_Original = Gender
replace Gender = 1 if Gender == 3
label define Gender_lbl 1 "Male" 2 "Female"
label values Gender Gender_lbl
label define Sector_lbl 1 "Rural" 2 "Urban"
label values Sector Sector_lbl
label define Social_Group_lbl 1 "ST" 2 "SC" 3 "OBC" 9 "Others"
label values Social_Group Social_Group_lbl
list HHID psn Age Gender Social_Group in 1/5, noobs

/*---------------- 8. Who is a worker? Who is unemployed? ----------------*/
// PP = usual principal status: the main activity, using the past 365 days.
// The major-time rule first separates labour force from outside the labour force,
// then working from unemployed. It is not a simple 'worked for half the year' test.
// SS = usual subsidiary status: work for at least 30 days during that period.
// Someone without a principal job can still count as a worker through SS.
// The survey has already assigned these activity codes to each person.

// 11 = own-account worker; 12 = employer; 21 = unpaid helper in an HH enterprise.
// 31 = regular wage/salary worker; 41 and 51 = casual labour.
// 81 = unemployed in principal status. Other codes can be outside the labour force.
// Unpaid helpers count as employed. Ordinary unpaid domestic work is different.

// inlist asks: is the status one of these codes? Yes = 1; no = 0.
gen byte Principal_worker = inlist(Status_Code_PP, 11, 12, 21, 31, 41, 51)
gen byte Subsidiary_worker = inlist(Status_Code_SS, 11, 12, 21, 31, 41, 51)
gen byte Worker = (Principal_worker == 1 | Subsidiary_worker == 1)
gen byte Labor_Force = (Worker == 1 | Status_Code_PP == 81)
gen byte Unemployed = (Labor_Force == 1 & Worker == 0)

// PP 81 + SS 21 is a worker, not unemployed, under the combined ps+ss measure.
assert Worker <= Labor_Force
assert Worker + Unemployed == Labor_Force
tab Worker Labor_Force, missing

/*---------------- 9. Three rates, two different denominators ----------------*/
// LFPR = labour force / all persons * 100.
// WPR  = workers / all persons * 100.
// UR   = unemployed / labour force * 100, NOT unemployed / all persons.
// Example: 100 people, 57 working and 3 unemployed -> LFPR 60%, WPR 57%, UR 5%.

// A weighted mean of 0 and 100 gives the weighted percentage.
gen double LFPR_Perct = 100 * Labor_Force
gen double WPR_Perct = 100 * Worker
gen double UR_Perct = 100 * Unemployed if Labor_Force == 1
// UR is blank outside the labour force, so those people cannot enter its denominator.

// iweights below are used for point estimates, not survey-design standard errors.
// Age < . excludes missing ages in Stata. Age 15+ is not the same as all ages.
// row and col add pooled totals; do not average the subgroup percentages yourself.

/*---------------- Table A: LFPR, age 15+ ----------------*/
// Statement 2, PDF page 36 / printed page 7. Expected all-India persons: 60.1%.
display "Table A: LFPR, usual status (ps+ss), age 15+"
table Gender Sector if Age >= 15 & Age < . [iw=weight], ///
       c(mean LFPR_Perct) row col format(%9.1f)
if `check_report' {
       quietly summarize LFPR_Perct if Age >= 15 & Age < . [iw=weight], meanonly
       assert abs(r(mean) - 60.1) < 0.05
}

/*---------------- Table B: WPR, age 15+ ----------------*/
// Statement 4, PDF page 39 / printed page 10. Expected all-India persons: 58.2%.
display "Table B: WPR, usual status (ps+ss), age 15+"
table Gender Sector if Age >= 15 & Age < . [iw=weight], ///
       c(mean WPR_Perct) row col format(%9.1f)
if `check_report' {
       quietly summarize WPR_Perct if Age >= 15 & Age < . [iw=weight], meanonly
       assert abs(r(mean) - 58.2) < 0.05
}

/*---------------- Table C: UR, age 15+ ----------------*/
// Statement 15, 'all' education levels, PDF page 51 / printed page 22.
// Expected: rural persons 2.5%, urban persons 5.1%, all-India persons 3.2%.
display "Table C: UR, usual status (ps+ss), age 15+"
table Gender Sector if Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], ///
       c(mean UR_Perct) row col format(%9.1f)
if `check_report' {
       quietly summarize UR_Perct if Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], meanonly
       assert abs(r(mean) - 3.2) < 0.05
}

// These checks allow the rounding used in the report: one decimal place.
// For youth rates, use Age >= 15 & Age <= 29 in the table's if condition.
// For state rates, replace Gender with State; the denominator rules stay the same.

/*---------------- 10. What kind of work do workers do? ----------------*/
// For the report's employment categories, use the principal job when employed in PP.
// Otherwise use the subsidiary job. Do not count the same worker twice.
gen byte Status_used = Status_Code_PP if Principal_worker == 1
replace Status_used = Status_Code_SS if Principal_worker == 0 & Subsidiary_worker == 1
gen byte Broad_Status = .
replace Broad_Status = 1 if inlist(Status_used, 11, 12)
replace Broad_Status = 2 if Status_used == 21
replace Broad_Status = 3 if Status_used == 31
replace Broad_Status = 4 if inlist(Status_used, 41, 51)
assert !missing(Broad_Status) if Worker == 1
assert missing(Broad_Status) if Worker == 0
label define Broad_Status_lbl 1 "Own account / employer" 2 "Unpaid HH helper" ///
                                                   3 "Regular wage / salary" 4 "Casual labour"
label values Broad_Status Broad_Status_lbl

/*---------------- Table D: Employment type, rural ST workers ----------------*/
// Table 46, PDF page 393 / printed page A-330. This table uses ALL AGES.
// Denominator: workers within each gender, not everyone in the labour force.
// Expected rural ST male row: 41.6, 14.7, 12.0, 31.8 (report rounds to one decimal).
// The report also adds 'all self-employed' = first two categories; this is a subtotal.
// Stata's tab below shows the four separate categories and displays two decimals.
display "Table D: Employment type, rural ST workers, all ages"
tab Gender Broad_Status if Worker == 1 & Sector == 1 & Social_Group == 1 [iw=weight], nof row

/*---------------- Table E: Unpaid helpers as a share of workers ----------------*/
// Table 46, 'helper in household enterprise' column; PDF pages 393-394, ALL AGES.
// This explains why we needed the HH merge: Social_Group comes from the HH file.
gen double Unpaid_Perct = 100 * (Broad_Status == 2) if Worker == 1
display "Table E: Unpaid HH helpers as a percentage of workers, all ages"
// Sector is the third variable; scolumn adds the Rural + Urban totals.
table Social_Group Gender Sector if Worker == 1 [iw=weight], ///
       c(mean Unpaid_Perct) row col scolumn format(%9.1f)
if `check_report' {
       quietly summarize Unpaid_Perct if Worker == 1 & Sector == 1 & Social_Group == 1 & Gender == 1 [iw=weight], meanonly
       assert abs(r(mean) - 14.7) < 0.05
}

// This is the report's employment category, not 'any unpaid job in PP or SS'.
// For example, a principal salaried worker with unpaid SS work stays in the salary category.

/*---------------- 11. Sample count is not the estimated population count ----------------*/
display "Sampled unpaid helpers, all ages:"
count if Broad_Status == 2
// Add their annual weights to estimate how many people they represent.
quietly summarize weight if Broad_Status == 2, meanonly
display "Estimated unpaid helpers, all ages: " %15.0fc r(sum)

/*---------------- 12. Before comparing any other table ----------------*/
// Match year, usual/CWS status, age group, rural/urban scope and gender grouping.
// Check the denominator: persons, labour force or workers?
// Check the annual weight, missing answers, and the report's rounding.
// A blank answer may mean 'not asked', not 'no'. Check the questionnaire's age limits.
// A matching percentage alone does not prove that a merge or weight was correct.
// Standard errors / confidence intervals need the PLFS sampling design.
// For detailed definitions, see the README, Instruction Manuals and Estimation Procedure.

/*---------------- 13. Extend the lesson: social groups and states ----------------*/
// Continue with the same people, weights and worker flags. No second merge is needed.
destring State Religion, replace
assert inlist(Religion, 1, 2, 3, 4, 5, 6, 7, 9)
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
label variable LFPR_Perct "LFPR (%)"
label variable WPR_Perct "WPR (%)"
label variable UR_Perct "UR (%)"

// Each pass repeats the same table for a different indicator; no rows are dropped.
// row/col add pooled totals; scolumn adds Rural + Urban for a three-way table.
foreach rate in LFPR_Perct WPR_Perct UR_Perct {
       local rate_name : variable label `rate'
       display "`rate_name' by social group, all ages"
       table Social_Group Gender Sector [iw=weight], ///
              c(mean `rate') row col scolumn format(%9.1f)
}
display "Youth LFPR by state, age 15-29"
table State Gender Sector if inrange(Age, 15, 29) [iw=weight], ///
       c(mean LFPR_Perct) row col scolumn format(%9.1f)

/*---------------- 14. Industry, occupation and benefits of the selected job ----------------*/
// NIC-2008 describes the industry; NCO-2015 describes the person's occupation.
// Keep the full codes as text. Only the two-digit NIC grouping becomes numeric.
rename (b5pt1q5_perv1 b5pt2q5_perv1) (NIC_PP NIC_SS)
rename (b5pt1q6_perv1 b5pt2q6_perv1) (NCO_PP NCO_SS)
gen str5 NIC_combined = NIC_PP if Principal_worker == 1
replace NIC_combined = NIC_SS if Principal_worker == 0 & Subsidiary_worker == 1
gen str3 NCO_combined = NCO_PP if Principal_worker == 1
replace NCO_combined = NCO_SS if Principal_worker == 0 & Subsidiary_worker == 1
// A blank principal-job detail must not silently be replaced by a different job.
assert strlen(NIC_combined) == 5 & !regexm(NIC_combined, "[^0-9]") if Worker == 1
assert strlen(NCO_combined) == 3 & !regexm(NCO_combined, "[^0-9]") if Worker == 1
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
assert !missing(NIC_Broad, NIC_Broad_Three) if Worker == 1

// Broad_Status and Status_used were already defined in section 10 for the same job.
// A self-employed principal worker may also have a casual subsidiary job;
// those benefits do not describe the principal job.
// Source: Instruction Manual I, 3.5.1.21; questionnaire Blocks 5.1 and 5.2.
gen str1 Social_Security = b5pt1q13_perv1 if Principal_worker == 1
replace Social_Security = b5pt2q12_perv1 if Principal_worker == 0 & Subsidiary_worker == 1
destring Social_Security, replace
assert inrange(Social_Security, 1, 9) | missing(Social_Security)
assert missing(Social_Security) if !inlist(Status_used, 31, 41, 51)
label define Social_Security_lbl 1 "PF/pension only" 2 "Gratuity only" ///
       3 "Health/maternity only" 4 "PF/pension and gratuity" ///
       5 "PF/pension and health/maternity" 6 "Gratuity and health/maternity" ///
       7 "All three benefits" 8 "Not eligible for these benefits" 9 "Not known"
label values Social_Security Social_Security_lbl

/*---------------- 15. Training, attendance and household categories ----------------*/
rename b3q5pt6_hhv1 HH_Monthly_Exp
rename (b4q7_perv1 b4q8_perv1 b4q9_perv1) (Marital_Status General_Edu Tech_Edu)
destring Marital_Status, replace
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

/*---------------- 16. Who was asked each work-history question? ----------------*/
rename (b5pt3q6_perv1 b5pt3q7_perv1) (Dur_Eco_Act_PP Dur_Eco_Act_SS)
rename (b5pt3q8_perv1 b5pt3q9_perv1 b5pt3q11_perv1) ///
       (Efforts_to_Search_work Dur_Spell_Unemp Reason_Not_Working)
gen str1 Dur_Eco_Activity = Dur_Eco_Act_PP if Principal_worker == 1
replace Dur_Eco_Activity = Dur_Eco_Act_SS if Principal_worker == 0 & Subsidiary_worker == 1
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

/*---------------- 17. Extended tables: rural, urban and combined areas ----------------*/
// These are analysis examples, not claims to reproduce every report table.
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
              tab Gender Broad_Status if (`area_filter') & Worker == 1 & Age >= `minimum_age' & Age < . [iw=weight], nof row

              foreach category in NIC_two_Combined NIC_Broad NIC_Broad_Three NCO_combined NCO_Division NCO_Subdivision {
                     display "`area': `category' among workers, `age_name'"
                     tab `category' Gender if (`area_filter') & Worker == 1 & Age >= `minimum_age' & Age < . [iw=weight], nof col
              }

              // levelsof finds groups present in this sample. An absent group is not zero percent.
              foreach grouping in Social_Group Religion {
                     quietly levelsof `grouping' if (`area_filter') & Worker == 1 & Age >= `minimum_age' & Age < ., local(group_codes)
                     foreach group_code of local group_codes {
                            local group_name : label (`grouping') `group_code'
                            display "`area': employment type, `grouping' = `group_name', workers, `age_name'"
                            tab Gender Broad_Status if (`area_filter') & Worker == 1 & `grouping' == `group_code' ///
                                   & Age >= `minimum_age' & Age < . [iw=weight], nof row
                     }
              }
       }

       // B. Within each industry: employment-type shares for persons, then each gender.
       foreach industry in NIC_Broad NIC_Broad_Three {
              display "`area': employment type by `industry', workers age 15+, persons"
              tab `industry' Broad_Status if (`area_filter') & Worker == 1 & Age >= 15 & Age < . [iw=weight], nof row
              display "`area': the same industry table separately for each gender"
              // bysort repeats the command separately for each gender; it does not pool them.
              bysort Gender: tab `industry' Broad_Status ///
                     if (`area_filter') & Worker == 1 & Age >= 15 & Age < . [iw=weight], nof row
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
       tab Dur_Eco_Activity Gender if (`area_filter') & Worker == 1 & Age >= 15 & Age < . [iw=weight], nof col
       // Search efforts include PP 81 with subsidiary work; unemployment duration does not.
       display "`area': search efforts, principal-status unemployed, age 15+"
       tab Efforts_to_Search_work Gender if (`area_filter') & Status_Code_PP == 81 & Age >= 15 & Age < . [iw=weight], nof col
       display "`area': unemployment duration, ps+ss unemployed, age 15+"
       tab Dur_Spell_Unemp Gender if (`area_filter') & Unemployed == 1 & Age >= 15 & Age < . [iw=weight], nof col
       display "`area': reasons for not working, previous workers now non-working, age 15+"
       tab Reason_Not_Working Gender if (`area_filter') & Worker == 0 & Age >= 15 & Age < . [iw=weight], nof col
}

/*---------------- 18. Interpret spending and save outputs ----------------*/
// HH spending repeats for each member. This mean describes people by their HH spending,
// not the mean across households and not MPCE. It is an illustrative classifier only.
// table reports point estimates without suggesting survey-design standard errors.
display "Person-weighted household spending (rupees), all ages; illustrative only"
table Gender Sector [iw=weight], c(mean HH_Monthly_Exp) row col format(%12.2f)

// Table if conditions do not delete other people from the prepared data.
assert _N == `persons_before_merge'
isid PID
// Save only the lesson's outputs. Source DTA files are never replaced.
save "`output'/PLFS_learning_data.dta", replace
display "Finished. Commands and tables are in: `output'/PLFS_walkthrough.log"
log close plfs_learning