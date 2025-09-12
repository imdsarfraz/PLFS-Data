
 
 /*Renaming */
 rename (b5pt1q3_perv1 b5pt2q3_perv1) (Status_Code_PP Status_Code_SS)
 rename b3q4_hhv1 Social_Group
 rename b4q5_perv1 Gender
 rename b4q6_perv1 Age
 rename b3q3_hhv1 Religion
 rename state_hhv1 State
 rename b3q5pt6_hhv1 HH_Monthly_Exp
 rename (b4q7_perv1 b4q8_perv1 b4q9_perv1)(Marital_Status General_Edu Tech_Edu)
 
 
 /* Keeping Only Male Females*/
destring Gender, replace
keep if Gender == 1 | Gender == 2
  
label define Gender 1 Male 2 Female
destring Gender, replace
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

*---------------------------------- Marital Status
destring Marital_Status, replace
gen dummy_married = .
replace dummy_married = 1 if Marital_Status == 2
replace dummy_married = 0 if Marital_Status == 1

*------------- Gender
* Gender dummy: male = 1, female = 0
destring Gender,replace
gen dummy_male = .
replace dummy_male = 1 if Gender == 1
replace dummy_male = 0 if Gender == 2

gen dummy_female = .
replace dummy_female = 1 if Gender == 2
replace dummy_female = 0 if Gender == 1
*--------------- Sector 
* Sector dummy: urban = 1, rural = 0
destring Sector, replace
gen dummy_urban = .
replace dummy_urban = 1 if Sector == 2
replace dummy_urban = 0 if Sector== 1



**----------------Wage
rename b6q9_perv1 wage_regular_salaried
gen log_wage = log( wage_regular_salaried)

*------------ Age Square 
gen age_sq = Age^2


*----------------- Dummy for General_Educatioon

destring General_Edu, replace
gen dummy_primary_below = (inlist(General_Edu, 5))
gen dummy_middle = (General_Edu == 7)
gen dummy_secondary = (General_Edu == 8)
gen dummy_higher_secondary = (General_Edu == 10)
gen dummy_graduate_diploma = inlist(General_Edu, 11, 12)
gen dummy_postgraduate = (General_Edu == 13)

*--------------------- Regression for Regular Salaried/Wage

reg log_wage Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male if Broad_Status == 3


*------------------
oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_female) noisily

oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_female) noisily detail


oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_female) pooled

*------------------------25 Percentile

* First, find the 25th percentile
_pctile log_wage if Broad_Status == 3 [iw=weight], p(25)
scalar q25 = r(r1)

* Generate RIF variable manually
gen rif25 = (log_wage <= q25)
replace rif25 = rif25 / (0.25*(1-0.25))
replace rif25 = q25 - rif25


reg rif25 Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male [iw=weight] if Broad_Status == 3



reg log_wage Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male [iw=weight] if Broad_Status == 3


oaxaca rif25 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, by(dummy_female) noisily

*-------------------------------75 
* First, find the 75th percentile
_pctile log_wage if Broad_Status == 3 [iw=weight], p(75)
scalar q75 = r(r1)

* Generate RIF variable manually
gen rif75 = (log_wage <= q75)
replace rif75 = rif75 / (0.75*(1-0.75))
replace rif75 = q75 - rif75

* Run RIF regression at 75th percentile
reg rif75 Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male [iw=weight] if Broad_Status == 3

* Run standard regression for comparison
reg log_wage Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male [iw=weight] if Broad_Status == 3

oaxaca rif75 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, by(dummy_female) noisily

*----------90 percentile 

* First, find the 90th percentile
_pctile log_wage if Broad_Status == 3 [iw=weight], p(90)
scalar q90 = r(r1)

* Generate RIF variable manually
gen rif90 = (log_wage <= q90)
replace rif90 = rif90 / (0.9*(1-0.9))
replace rif90 = q90 - rif90

* Run RIF regression at 90th percentile
reg rif90 Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male [iw=weight] if Broad_Status == 3

* Run standard regression for comparison
reg log_wage Age age_sq i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male [iw=weight] if Broad_Status == 3

* Oaxaca decomposition at 90th percentile
oaxaca rif90 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, by(dummy_female) noisily

*------------Quantile -----------------------------------------------------
qreg log_wage Age age_sq dummy_male dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, quantile(0.10)

qreg log_wage Age age_sq dummy_male dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, quantile(0.25)

qreg log_wage Age age_sq dummy_male dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, quantile(0.50)

qreg log_wage Age age_sq dummy_male dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, quantile(0.75)

qreg log_wage Age age_sq dummy_male dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married [iw=weight] if Broad_Status == 3, quantile(0.90)

*---------------- 09 Sep 2025
* Keep only SC, ST, and Others
keep if inlist(Social_Group, 1, 2, 9)

* Generate dummy: 1 = Others, 0 = SC/ST
gen scst = (Social_Group == 9)

label define scstlbl 0 "SC_ST" 1 "Others"
label values scst scstlbl

destring scst,replace
gen dummy_scst = .
replace dummy_scst = 1 if scst == 0
replace dummy_scst = 0 if scst == 1

gen dummy_others = .
replace dummy_others = 1 if scst == 1
replace dummy_others = 0 if scst == 0

reg log_wage Age age_sq i.dummy_others i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male if Broad_Status == 3

oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_scst) noisily

oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_scst) pooled


*------ RIF
reg rif25 Age age_sq i.dummy_others i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male if Broad_Status == 3

reg rif75 Age age_sq i.dummy_others i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male if Broad_Status == 3

reg rif90 Age age_sq i.dummy_others i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married i.dummy_male if Broad_Status == 3

oaxaca rif25 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_scst) noisily

oaxaca rif75 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_scst) noisily

oaxaca rif90 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_scst) noisily

******
* Gen Male = Others + Male
gen gen_male = (Social_Group == 9 & Gender == 1)

* SC/ST Female = SC/ST + Female
gen scst_female = (inlist(Social_Group, 1, 2) & Gender == 2)

* Third Variable 
gen group_compare = .
replace group_compare = 1 if gen_male == 1
replace group_compare = 2 if scst_female == 1

*Dummy
destring group_compare,replace
gen dummy_mg = .
replace dummy_mg = 1 if group_compare == 1
replace dummy_mg = 0 if group_compare == 2

gen dummy_fscst = .
replace dummy_fscst = 1 if group_compare == 2
replace dummy_fscst = 0 if group_compare == 1

reg log_wage Age age_sq i.dummy_mg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fscst) noisily

*--- RIF

reg rif25 Age age_sq i.dummy_mg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

reg rif75 Age age_sq i.dummy_mg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

reg rif90 Age age_sq i.dummy_mg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

*----
oaxaca rif25 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fscst) noisily

oaxaca rif75 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fscst) noisily

oaxaca rif90 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fscst) noisily

*_____
* Gen Female 
gen gen_female = (Social_Group == 9 & Gender == 2)

gen female_gen_scst = .
replace female_gen_scst = 1 if gen_female == 1
replace female_gen_scst = 2 if scst_female == 1

*Dummy
destring group_compare,replace
gen dummy_fg = .
replace dummy_fg = 1 if female_gen_scst == 1
replace dummy_fg = 0 if female_gen_scst == 2

gen dummy_fe_scst = .
replace dummy_fe_scst = 1 if female_gen_scst == 2
replace dummy_fe_scst = 0 if female_gen_scst == 1

reg log_wage Age age_sq i.dummy_fg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

reg rif25 Age age_sq i.dummy_fg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

reg rif75 Age age_sq i.dummy_fg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

reg rif90 Age age_sq i.dummy_fg i.dummy_primary_below i.dummy_middle i.dummy_secondary i.dummy_higher_secondary i.dummy_graduate_diploma i.dummy_postgraduate i.dummy_urban i.dummy_married if Broad_Status == 3

oaxaca log_wage Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fe_scst) noisily

oaxaca rif25 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fe_scst) noisily

oaxaca rif75 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fe_scst) noisily

oaxaca rif90 Age age_sq dummy_primary_below dummy_middle dummy_secondary dummy_higher_secondary dummy_graduate_diploma dummy_postgraduate dummy_urban dummy_married  [iw=weight] if Broad_Status == 3, by(dummy_fe_scst) noisily