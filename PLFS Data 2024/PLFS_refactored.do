// Annual PLFS 2023-24 -- first visit only
version 14.0
clear all
set more off

// make changes in path
local root "C:\Users\sarfr\OneDrive\Desktop\PLFS"
local data "`root'/dta_data_PLFS_2023_2024"
local output "`root'/stata_output"
capture mkdir "`output'"
tempfile household_first_visit

// HH Data Visit-1
use "`data'/hhv1.dta", clear

// Renaming
// HH weight names stay separate, so we can check them after merging.

// Generating Weights

// Renaming + Creating HHID

rename ( qtr_hhv1 visit_hhv1 b1q3_hhv1 b1q1_hhv1 b1q13_hhv1 b1q14_hhv1 b1q15_hhv1)(Quarter Visit Sector fsu hamlet sss shn)

// README Section B: same seven fields in HH and person files.
assert inlist(Quarter, "Q1", "Q2", "Q3", "Q4") & Visit == "V1"
assert inlist(Sector, "1", "2")
assert strlen(fsu) == 5 & strlen(hamlet) == 1 & strlen(sss) == 1 & strlen(shn) == 2
gen str14 HHID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn
isid HHID
save "`household_first_visit'"

// Old revisit headings kept below -- not used for these annual ps+ss tables.
/*
// HH Data Visit-2 --REVISIT
// Renaming
// Generating Weights
// Renaming + Creating HHID
// merging HH Level Data
**Open 1 HH level file then merged with another HH data
** Saved as 'HH Merged Data' 
*/

/*-----------------------------------------------------------------------------------------------------*/
/*-------- INDIVIDUAL LEVEL DATA -----Visit-1----*/

use "`data'/perv1.dta", clear
rename ( NSS_perv1 NSC_perv1 mult_perv1 )(NSS NSC Mult)

// Generating Weights

assert !missing(Mult, NSS, NSC, no_qtr_perv1)
assert Mult > 0 & NSS > 0 & NSC > 0 & inlist(no_qtr_perv1, 1, 2, 3, 4)
gen double weight_quarter = Mult /100 if NSS == NSC
replace weight_quarter = Mult /200 if NSS != NSC
// Annual tables: divide by NO_QTR from the file, not always 4 (README, Section B).
gen double weight = weight_quarter / no_qtr_perv1
label variable weight "Annual combined-sample weight"

// Renaming + Creating HHID  PID 
rename ( qtr_perv1 visit_perv1 b1q3_perv1 b1q1_perv1 b1q13_perv1 b1q14_perv1 b1q15_perv1 b4q1_perv1 )(Quarter Visit Sector fsu hamlet sss shn psn)

assert inlist(Quarter, "Q1", "Q2", "Q3", "Q4") & Visit == "V1"
assert inlist(Sector, "1", "2")
assert strlen(fsu) == 5 & strlen(hamlet) == 1 & strlen(sss) == 1 & strlen(shn) == 2
assert strlen(psn) == 2
gen str14 HHID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn
gen str16 PID = HHID + psn
isid PID

/*--------------- INDIVIDUAL LEVEL DATA -----Visit-2----*/
// Revisit skip -- same person across visits is a different analysis.
/*
// Renaming
// Generating Weights
// Renaming + Creating HHID  PID 
// merging Individual Level Data
**Open 1 Ind level file then merged with another Ind data
** Saved as 'Ind Merged Data'
*/

/*----------------------------------------Merging ----------------------------*/
/*------------- HH + INDIVIDUAL level --------*/

// Many persons, one HH. Keep only the HH columns needed below, plus weight checks.
local persons_before_merge = _N
merge m:1 HHID using "`household_first_visit'", ///
  keepusing(state_hhv1 b3q1_hhv1 b3q2_hhv1 b3q3_hhv1 b3q4_hhv1 b3q5pt6_hhv1 ///
        nss_hhv1 nsc_hhv1 mult_hhv1 no_qtr_hhv1)
tab _merge
assert _merge == 3
assert _N == `persons_before_merge'
isid PID

// Dono files mein state aur weights same hone chahiye.
assert state_perv1 == state_hhv1
assert NSS == nss_hhv1 & NSC == nsc_hhv1 & Mult == mult_hhv1
assert no_qtr_perv1 == no_qtr_hhv1
drop _merge

// Only this output gets replaced on rerun; original DTA files stay unchanged.
save "`output'/HH_Ind_merged.dta", replace

 
 * LOAD Your Merged Dataset
 // Already loaded above -- no need to clear and open again.
 * Let's Try To replicate PLFS table from Annual Report (2023-2024)
 // Table age limits stay as written; 15+ tables should not be compared with all ages.
 

 /*Renaming */
 rename (b5pt1q3_perv1 b5pt2q3_perv1) (Status_Code_PP Status_Code_SS)
 rename b3q4_hhv1 Social_Group
 rename b4q5_perv1 Gender
 rename b4q6_perv1 Age
 rename b3q3_hhv1 Religion
 rename state_hhv1 State
 rename b3q5pt6_hhv1 HH_Monthly_Exp
 rename (b4q7_perv1 b4q8_perv1 b4q9_perv1)(Marital_Status General_Edu Tech_Edu)
 assert Age >= 0 & Age < .
 
 
 /* Keeping Only Male Females*/
destring Gender, replace
assert inlist(Gender, 1, 2, 3)
clonevar Gender_Original = Gender
// Annual Report 1.5.3: code 3 male mein include hai; original code alag rakha hai.
replace Gender = 1 if Gender == 3
keep if Gender == 1 | Gender == 2
  
label define Gender 1 Male 2 Female
label values Gender Gender

 
 /* Renaming or Labeling*/

// Social_Group
 
 label define Social_Group 1 ST 2 SC 3 OBC 9 Others
 destring Social_Group, replace
 label values Social_Group Social_Group
 

 
 // Religion
label define Religion 1 Hindus 2 Muslims 3 Christianity 4 Sikhism 5 Jainism 6 Buddhism 7 Zoroastrianism 9 others 
 
destring Religion, replace
label values Religion Religion
 
 // Sector
label define Sector 1 Rural 2 Urban
destring Sector ,replace
label values Sector Sector

 // State
 
 label define State 01 Jammu_and_Kashmir 	02 Himachal_Pradesh 	03 Punjab 	04 Chandigarh 	05 Uttarakhand 	06 Haryana 	07 Delhi 	08 Rajasthan 	09 Uttar_Pradesh 	10 Bihar 	11 Sikkim 	12 Arunachal_Pradesh 	13 Nagaland 	14 Manipur 	15 Mizoram 	16 Tripura 	17 Meghalaya 	18 Assam 	19 West_Bengal 	20 Jharkhand 	21 Odisha 	22 Chhattisgarh 	23 Madhya_Pradesh 	24 Gujarat 	25 D_and_N_Haveli_and_Daman_and_Diu 	27 Maharashtra 	28 Andhra_Pradesh 	29 Karnataka 	30 Goa 	31 Lakshadweep 	32 Kerala 	33 Tamilnadu 	34 Puduchery 	35 Andaman_N_Island  36 Telangana 	37 Ladakh 
 
 destring State,replace
 label values State State


  // LABOR FORCE
 
 destring Status_Code_PP ,replace
 destring Status_Code_SS ,replace
   assert !missing(Status_Code_PP)
 
 /*Generation LABOR FORCE using Principal Status Approach
 gen labor_force_ps = 1 if Status_Code_PP >=11 & Status_Code_PP <=82 */
 
  // Work = 11, 12, 21, 31, 41, 51; unemployed = 81. Har flag: yes 1, no 0.
  gen byte labor_force_ps = inlist(Status_Code_PP, 11, 12, 21, 31, 41, 51, 81)

 
 // Generation LABOR FORCE using Usual Subsidary Status Approach
   gen byte labor_force_ss = inlist(Status_Code_SS, 11, 12, 21, 31, 41, 51)
 
 // LABOR FORCE (PS+SS)'
   gen byte Labor_Force = (labor_force_ps == 1 | labor_force_ss == 1)
 
/*-------Generation WPR using Principal Status Approach------ */
 
  gen byte WPR_ps = inlist(Status_Code_PP, 11, 12, 21, 31, 41, 51)

 
 // Generation WPR using Usual Subsidary Status Approach
   gen byte WPR_ss = inlist(Status_Code_SS, 11, 12, 21, 31, 41, 51)
 
 // WPR (PS+SS)'
   gen byte WPR = (WPR_ps == 1 | WPR_ss == 1)

 // Unemployment rate in usual status (ps+ss)
 // Unemployed people are in the labour force but have no principal or subsidiary work.
 assert inlist(Labor_Force, 0, 1) & inlist(WPR, 0, 1)
 assert WPR <= Labor_Force
 gen byte Unemployed = (Labor_Force == 1 & WPR == 0)

 // Leave others blank so only the labour force enters the UR denominator.
 gen double UR_Perct = 100 * Unemployed if Labor_Force == 1
 label variable UR_Perct "Unemployment rate (usual status), percent"

 // Annual weights from the README; the weights used by earlier tables stay unchanged.
 // weight ab sab tables mein annual hai; UR ke liye bhi same weight.
 gen double UR_weight = weight

 // Age 15+: male, female and total; rural, urban and rural + urban.
 // Check: Annual Report Statement 15, 'all' row (PDF pg 51).
 table Gender Sector if Labor_Force == 1 & Age >= 15 & Age < . [iw=UR_weight], ///
   c(mean UR_Perct) row col format(%9.1f)
 
 //
 * pg 54
 gen WPR_Perct = WPR*100
 table Social_Group Gender Sector[iw=weight], c(mean WPR_Perct ) row col format(%9.1f)
 
 
 
  
 
 //------------------------------------------------------------------------------------------------------------------------------------------------------------
 
 

 /*Percentage distribution of workers in usual status (ps+ss) by broad status in employment
 for each social group
 (Male, Female)
 (Rural, Urban & Rural+Urban) */
 
 tab Social_Group Labor_Force [iw=weight] if Sector==1 & Gender==1, nof row
 tab Social_Group Labor_Force [iw=weight] if Sector==1 & Gender==2, nof row
 tab Social_Group Labor_Force [iw=weight] if Sector==2 & Gender==1, nof row
 
 // Table format mein banane k liye 
 table Social_Group Gender Sector [iw=weight], c(mean Labor_Force) row col
 
 // pg 53
 
 gen Labour_Force_Perct = Labor_Force*100
 table Social_Group Gender Sector[iw=weight], c(mean Labour_Force_Perct ) row col format(%9.1f)
 
 // Rural +Urban EK saath
 table Social_Group Gender [iw=weight], c(mean Labour_Force_Perct ) row col format(%9.1f)
 
 // pg 123
 table State Gender Sector[iw=weight] if Age>=15 & Age<=29, c(mean Labour_Force_Perct ) row col format(%9.1f)
 
 
 
 /*---------------------------------------------------------------------------------------------------------------------------*/
 
 /* Trying to create grp based on NIC code */
 rename ( b5pt1q5_perv1 b5pt2q5_perv1) (NIC_PP NIC_SS)
 gen str NIC_two_PP = substr( NIC_PP,1,2)
 gen str NIC_two_SS = substr( NIC_SS,1,2)
 gen NIC_two_Combined= NIC_two_PP
 replace NIC_two_Combined = NIC_two_SS if missing( NIC_two_PP )
 
 // pg 213 matched table 
 tab NIC_two_Combined Gender [iw=weight] if Sector==1 & Labor_Force==1 , nof col
 
 
 //------ Recoding Of NIC codes to make group--------------------*/
 destring NIC_two_Combined, replace
 
 recode NIC_two_Combined (01/03=1 "Agriculture") (05/09=2 "mining and quarrying") (10/33=3 "manufacturing") (35/39=4 "Electricity and water supply") (41/43=5 "Construction") (45/47=7 "Trade") (49/53 =8 "Transport") (55/56=9 "Accomodation and Food Services") (58/99= 10 "Other Services") , gen (NIC_Broad)
 
 /** Primary Secondary Tertiary----*/
 recode NIC_two_Combined (01/03=1 "Agriculture")   (05/43=6 "Secondary") (45/max=11 "Tertiary"), gen (NIC_Broad_Three)
 
 
 tab NIC_Broad Gender [iw=weight] if Sector==1 & Labor_Force==1 , nof col
 tab NIC_Broad_Three Gender [iw=weight] if Sector==1 & Labor_Force==1 , nof col
 



 
 /*---------------------------------------------------------------------------------------------------------------------------*/
 
  /*--------------------------- Creating Broad Employmenmt Status Code ---------------------------------*/

gen Broad_Status = .
replace Broad_Status = 1 if inlist(Status_Code_PP, 11, 12)
replace Broad_Status = 2 if Status_Code_PP == 21
replace Broad_Status = 3 if Status_Code_PP == 31
replace Broad_Status = 4 if inlist(Status_Code_PP, 41, 51)

// Now consider Status_Code_SS only if Broad_Status is still missing
replace Broad_Status = 1 if Broad_Status == . & inlist(Status_Code_SS, 11, 12)
replace Broad_Status = 2 if Broad_Status == . & Status_Code_SS == 21
replace Broad_Status = 3 if Broad_Status == . & Status_Code_SS == 31
replace Broad_Status = 4 if Broad_Status == . & inlist(Status_Code_SS, 41, 51)



label define Broad_Status_lbl 1 "Own Account Work/Employer" 2 "Helper in Household" 3 "Regular Salaried/Wage" 4 "Casual Labor" 
label values Broad_Status Broad_Status_lbl

// pg- 42
tab Gender Broad_Status [iw=weight] if Sector==1 & Labor_Force==1 , nof row

// RURAL
tab Gender Broad_Status [iw=weight] if Sector==1 & Labor_Force==1 , nof row

// URBAN
tab Gender Broad_Status [iw=weight] if Sector==2 & Labor_Force==1 , nof row

// RURAL + URBAN
tab Gender Broad_Status [iw=weight] if  Labor_Force==1 , nof row

// Table -1 
 /* ------Percentage distribution of workers in usual status (ps+ss) by broad status in employment for each industry of work
 ---------(Age Group:15+)(Male, Female) (Rural, Urban & Rural+Urban -----------*/
 
 // pg 147
 tab NIC_Broad Broad_Status [iw=weight] if Sector==1 & Gender==1 & Labor_Force==1 , nof row
 
 *Rural + Male
  tab NIC_Broad Broad_Status [iw=weight] if Sector==1 & Gender==1 & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Sector==1 & Gender==1 & Labor_Force==1 & Age>=15 , nof row
 
 *Rural Females
 tab NIC_Broad Broad_Status [iw=weight] if Sector==1 & Gender==2 & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Sector==1 & Gender==2 & Labor_Force==1 & Age>=15 , nof row

 *Rural Person
 tab NIC_Broad Broad_Status [iw=weight] if Sector==1  & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Sector==1  & Labor_Force==1 & Age>=15 , nof row
  
 *Urban + Male
  tab NIC_Broad Broad_Status [iw=weight] if Sector==2 & Gender==1 & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Sector==2 & Gender==1 & Labor_Force==1 & Age>=15 , nof row
 
 *Urban Females
 tab NIC_Broad Broad_Status [iw=weight] if Sector==2 & Gender==2 & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Sector==2 & Gender==2 & Labor_Force==1 & Age>=15 , nof row

 *Urban Person
 tab NIC_Broad Broad_Status [iw=weight] if Sector==2  & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15 , nof row 
 
 *Rural+Urban : Male
  tab NIC_Broad Broad_Status [iw=weight] if Gender==1 & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if  Gender==1 & Labor_Force==1 & Age>=15 , nof row
 
 *Rural+Urban : Females
 tab NIC_Broad Broad_Status [iw=weight] if  Gender==2 & Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if  Gender==2 & Labor_Force==1 & Age>=15 , nof row

 *Rural+Urban : Person
 tab NIC_Broad Broad_Status [iw=weight] if  Labor_Force==1 & Age>=15 , nof row
  tab NIC_Broad_Three Broad_Status [iw=weight] if Labor_Force==1 & Age>=15 , nof row
 
 
 

/*--------------- vocational/technical training received -----------*/
rename b4q12_perv1 Voc_Edu
label define Voc_Edu 1 Formal 2 Hereditary 3 Self_Learning 4 Learning_On_Job 5 Others 6 No_Voc_Training 
destring Voc_Edu, replace
label values Voc_Edu Voc_Edu
 
 //PAGE 103 same table'
 tab Voc_Edu [iw=weight] if Sector==1 & Gender==1 & Age>=15 & Age<=59
 

 //Rural Male
 tab Voc_Edu  [iw=weight] if Sector==1 & Gender==1 &  Labor_Force==1 & Age>=15
//Rural Female
 tab Voc_Edu  [iw=weight] if Sector==1 & Gender==2 &  Labor_Force==1 & Age>=15
//Rural Person
 tab Voc_Edu  [iw=weight] if Sector==1  &  Labor_Force==1 & Age>=15
 
//Urban Male
tab Voc_Edu  [iw=weight] if Sector==2 & Gender==1 &  Labor_Force==1 & Age>=15
 //Urban Female
 tab Voc_Edu  [iw=weight] if Sector==2 & Gender==2 &  Labor_Force==1 & Age>=15
 //Urban Person
 tab Voc_Edu  [iw=weight] if Sector==2 &  Labor_Force==1 & Age>=15
 
// Rural+Urban Male
 tab Voc_Edu  [iw=weight] if Gender==1 &  Labor_Force==1 & Age>=15
//Rural+Urban Female
 tab Voc_Edu  [iw=weight] if Gender==2 &  Labor_Force==1 & Age>=15
// Rural+Urban Person
 tab Voc_Edu  [iw=weight] if   Labor_Force==1 & Age>=15
 
 
 /*-------------------- Percentage distribution of workers in usual status (ps+ss)----------------
 by occupation group/ sub-division /division as per National Classification of Occupation (NCO) 2004 
 (Age Group:15+)(Male, Female) (Rural, Urban & Rural+Urban) */
 // 2023-24 data uses NCO-2015; old heading upar reference ke liye kept.
 
rename (b5pt1q6_perv1 b5pt2q6_perv1) (NCO_PP NCO_SS)
gen NCO_combined = NCO_PP
replace NCO_combined = NCO_SS if missing(NCO_PP)

//Matched with table pg-210
tab NCO_combined Gender[iw=weight] if Sector==1 & Labor_Force==1 , nof col

// Rural : Male + Female + Person
tab NCO_combined Gender[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
 tab NCO_combined Gender[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col
 
 // Rural+ Urban : Male + Female + Person
 tab NCO_combined Gender[iw=weight] if  Labor_Force==1 & Age>=15 , nof col
 
 *---------------------NCO table Division ---------------------------
 gen str NCO_Divison = substr( NCO_combined,1,1)
 
 // Rural : Male + Female + Person
tab NCO_Divison Gender[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
 tab NCO_Divison Gender[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col
 
 // Rural+ Urban : Male + Female + Person
 tab NCO_Divison Gender[iw=weight] if  Labor_Force==1 & Age>=15 , nof col
 
 *-------------------------------NCO table Sub-Division ---------------------------
  gen str NCO_Sub_Divison = substr( NCO_combined,1,2)
  
  // Rural : Male + Female + Person
tab NCO_Sub_Divison Gender[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
 tab NCO_Sub_Divison Gender[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col
 
 // Rural+ Urban : Male + Female + Person
 tab NCO_Sub_Divison Gender[iw=weight] if  Labor_Force==1 & Age>=15 , nof col
 
 /*-------------- Percentage distribution of workers in usual status (ps+ss) by broad status in employment for each social group
 -----------------(Age Group: 15+)(Male, Female) (Rural, Urban & Rural+Urban) */
 
** table Social_Group Gender Sector [iw=weight] if , c(mean Labor_Force) row col
  
  
 *----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------* 
*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*

/* Percentage distribution of workers in usual status (ps+ss) by Social Security Benefits (See: Codes for Block 5.1 col. (13): status of PLF Report 2020-21) (Male, Female) (Rural, Urban & Rural+Urban) (Age Group: 15+) */

// Social Security
 gen Social_Security = b5pt1q13_perv1 
replace Social_Security = b5pt2q12_perv1 if missing(Social_Security)

label define Social_Security 1 Only_Pension 2 Only_Gratuity 3 Only_health_care 4 Pension_and_Gratuity 5 Pension_and_health 6 Gratuity_and_health 7 Pension_Gratuity_Health 8 Not_Eligible_SSB 9 Unknown
destring Social_Security, replace
label values Social_Security Social_Security

// Rural : Male + Female + Person
tab Social_Security Gender[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
 tab Social_Security Gender[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col
 
 // Rural+ Urban : Male + Female + Person
 tab Social_Security Gender[iw=weight] if  Labor_Force==1 & Age>=15 , nof col


/* TABLE -4 */

* RURAL ST : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==1 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN ST : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==1 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN ST : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==1 & Labor_Force==1 & Age>=15, nof row

*-------------------------------------------------------
* RURAL SC : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==2 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN SC : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==2 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN SC : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==2 & Labor_Force==1 & Age>=15, nof row

*----------------------------------------------------------
* RURAL OBC : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==3 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN OBC : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==3 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN OBC : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==3 & Labor_Force==1 & Age>=15, nof row

*------------------------------------------------------------
* RURAL Others : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==9 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN Others : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==9 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN Others : Male Female Person
tab Gender Broad_Status [iw=weight] if Social_Group==9 & Labor_Force==1 & Age>=15, nof row

*-------- Table 5----------------------------

*--------1 Hindus 2 Muslims 3 Christianity 4 Sikhism 5 Jainism 6 Buddhism 7 Zoroastrianism 9 others 

* RURAL Hindu : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==1 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN Hindu : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==1 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN Hindu : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==1 & Labor_Force==1 & Age>=15, nof row

*----------------------------------------------------------------------------------------------------------------
* RURAL Muslim : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==2 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN Muslim : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==2 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN Muslim : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==2 & Labor_Force==1 & Age>=15, nof row

*-----------------------------------------------------------------------------------------------------------------------
* RURAL Christians : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==3 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN Christians : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==3 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN Christians : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==3 & Labor_Force==1 & Age>=15, nof row

*----------------------------------------------------------------------------------------------------------------------------
* RURAL Sikhism : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==4 & Sector==1 & Labor_Force==1 & Age>=15, nof row

* URBAN Sikhism : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==4 & Sector==2 & Labor_Force==1 & Age>=15, nof row

* RURAL+URBAN Sikhism : Male Female Person
tab Gender Broad_Status [iw=weight] if Religion ==4 & Labor_Force==1 & Age>=15, nof row

*-------------------------------------------------------------------------------------------------------------------------------------
*-------------------------------------------------------------------------------------------------------------------------------------
 /* Mean Expenditure Calculation*/
 // Person-level data: HH spending repeats for each member, not a mean across HHs.
 // Neeche standard errors survey design ke liye adjusted nahi hain.
 summarize HH_Monthly_Exp [iw=weight]

 
 // RURAL
  mean HH_Monthly_Exp [iw=weight] if Sector==1, over (Gender)
  mean HH_Monthly_Exp [iw=weight] if Sector==1
  
 // URBAN
  mean HH_Monthly_Exp [iw=weight] if Sector==2, over (Gender)
  mean HH_Monthly_Exp [iw=weight] if Sector==2
 
 // RURAL + URBAN
 mean HH_Monthly_Exp [iw=weight], over (Gender)
  mean HH_Monthly_Exp [iw=weight]


 *----------------------------------------
 *-----------------------------------------
 //Rural
 tab Gender Broad_Status [iw=weight] if  Sector==1 & Age >=15, nof row
 //Urban 
 tab Gender Broad_Status [iw=weight] if  Sector==2 & Age >=15, nof row
 // Rural + Urban
 tab Gender Broad_Status [iw=weight] if Age >=15, nof row
 
 *---------------------------------------------------------------------------------------
 * Table 12
 rename b3q2_hhv1 HH_Type
 
 // Rural : Male + Female + Person
tab  Gender HH_Type[iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof row

// Urban : Male + Female + Person
tab  Gender HH_Type[iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof row

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

gen Dur_Eco_Activity= Dur_Eco_Act_PP
 replace Dur_Eco_Activity = Dur_Eco_Act_SS if missing( Dur_Eco_Act_PP )
 
// Rural : Male + Female + Person
tab Dur_Eco_Activity  Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Dur_Eco_Activity Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab Dur_Eco_Activity Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col 

**---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-34
rename b5pt3q8_perv1 Efforts_to_Search_work

// Rural : Male + Female + Person
tab Efforts_to_Search_work  Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Efforts_to_Search_work  Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab Efforts_to_Search_work Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col
 
*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-35
rename b5pt3q9_perv1 Dur_Spell_Unemp

// Rural : Male + Female + Person
tab Dur_Spell_Unemp  Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Dur_Spell_Unemp  Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab Dur_Spell_Unemp Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col

*-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Table-36
rename b5pt3q11_perv1 Reason_Not_Working

// Rural : Male + Female + Person
tab Reason_Not_Working  Gender [iw=weight] if Sector==1 & Labor_Force==1 & Age>=15, nof col

// Urban : Male + Female + Person
tab Reason_Not_Working  Gender [iw=weight] if Sector==2 & Labor_Force==1 & Age>=15, nof col

// Rural + Urban
tab Reason_Not_Working Gender [iw=weight] if  Labor_Force==1 & Age>=15, nof col
