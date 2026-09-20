/*---------------- PLFS 2023-24: From raw data to annual tables ----------------*/
// Run this file from the top. Change the root path below if needed.
// Stata 14+; version keeps the older table commands working on newer Stata.
version 14.0
clear all
set more off

local root "C:/Users/mdsarfraj/PLFS"
local data "`root'/dta_data_PLFS_2023_2024"
local output "`root'/plfs_learning_output"
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
rename (qtr_hhv1 visit_hhv1 b1q3_hhv1 b1q1_hhv1 b1q13_hhv1 b1q14_hhv1 b1q15_hhv1) ///
       (Quarter Visit Sector fsu hamlet sss shn)
assert inlist(Quarter, "Q1", "Q2", "Q3", "Q4") & Visit == "V1"
assert inlist(Sector, "1", "2")
assert strlen(fsu) == 5 & strlen(hamlet) == 1 & strlen(sss) == 1 & strlen(shn) == 2
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
gen str14 HHID = Quarter + Visit + Sector + fsu + hamlet + sss + shn
gen str16 PID = HHID + psn
isid PID
// HHID can repeat here: several members belong to one household. PID cannot.

/*---------------- 5. Connect each person to their household ----------------*/
// m:1 means many persons matched to one household, using the same HHID.
// merge brings columns automatically; keepusing only limits that list.
local persons_before_merge = _N
merge m:1 HHID using "`households'", ///
    keepusing(state_hhv1 b3q3_hhv1 b3q4_hhv1 nss_hhv1 nsc_hhv1 mult_hhv1 no_qtr_hhv1)
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
label variable weight "Annual combined-sample weight"

// NO_QTR = contributing quarters for the sampling group, not visits to a person.
// Use the supplied value, not a fixed 4. Some groups have fewer quarters.
// It annualizes pooled quarterly weights; do not divide by NO_QTR a second time.
// Source: README Section B, Generation of combined estimate for the entire Year.
tab NO_QTR
summarize weight

// A common factor cancels in a percentage, but not in a population total.
// If NO_QTR varies, percentages can change too. Use annual weights for both.

/*---------------- 7. Make the columns easier to read ----------------*/
// Keep just what this lesson needs. Nothing is removed from the original files.
keep HHID PID Quarter Visit Sector fsu hamlet sss shn psn state_perv1 ///
        b4q5_perv1 b4q6_perv1 b3q3_hhv1 b3q4_hhv1 b5pt1q3_perv1 b5pt2q3_perv1 ///
        NSS NSC Mult NO_QTR weight_quarter weight
rename (state_perv1 b4q5_perv1 b4q6_perv1 b3q3_hhv1 b3q4_hhv1) ///
          (State Gender Age Religion Social_Group)
rename (b5pt1q3_perv1 b5pt2q3_perv1) (Status_Code_PP Status_Code_SS)
destring Gender Sector Social_Group Status_Code_PP Status_Code_SS, replace
assert Age >= 0 & Age < .
assert !missing(Status_Code_PP)
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
quietly summarize LFPR_Perct if Age >= 15 & Age < . [iw=weight], meanonly
assert abs(r(mean) - 60.1) < 0.05

/*---------------- Table B: WPR, age 15+ ----------------*/
// Statement 4, PDF page 39 / printed page 10. Expected all-India persons: 58.2%.
display "Table B: WPR, usual status (ps+ss), age 15+"
table Gender Sector if Age >= 15 & Age < . [iw=weight], ///
       c(mean WPR_Perct) row col format(%9.1f)
quietly summarize WPR_Perct if Age >= 15 & Age < . [iw=weight], meanonly
assert abs(r(mean) - 58.2) < 0.05

/*---------------- Table C: UR, age 15+ ----------------*/
// Statement 15, 'all' education levels, PDF page 51 / printed page 22.
// Expected: rural persons 2.5%, urban persons 5.1%, all-India persons 3.2%.
display "Table C: UR, usual status (ps+ss), age 15+"
table Gender Sector if Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], ///
       c(mean UR_Perct) row col format(%9.1f)
quietly summarize UR_Perct if Labor_Force == 1 & Age >= 15 & Age < . [iw=weight], meanonly
assert abs(r(mean) - 3.2) < 0.05

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
quietly summarize Unpaid_Perct if Worker == 1 & Sector == 1 & Social_Group == 1 & Gender == 1 [iw=weight], meanonly
assert abs(r(mean) - 14.7) < 0.05

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
// A matching percentage alone does not prove that a merge or weight was correct.
// Standard errors / confidence intervals need the PLFS sampling design.
// For detailed definitions, see the README, Instruction Manuals and Estimation Procedure.

// Save only the lesson's outputs. Source DTA files are never replaced.
save "`output'/PLFS_learning_data.dta", replace
display "Finished. Commands and tables are in: `output'/PLFS_walkthrough.log"
log close plfs_learning