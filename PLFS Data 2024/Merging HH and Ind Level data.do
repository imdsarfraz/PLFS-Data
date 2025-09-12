
// HH Data Visit-1
use "C:\Users\sarfraz\hhv1.dta"

// Renaming

rename ( nss_hhv1 nsc_hhv1 mult_hhv1)(NSS NSC Mult)

// Generating Weights

gen weight = Mult /100 if NSS == NSC 
replace weight = Mult /200 if NSS != NSC 
gen Weight = Mult /100 

// Renaming + Creating HHID

rename ( qtr_hhv1 visit_hhv1 b1q3_hhv1 b1q1_hhv1 b1q13_hhv1 b1q14_hhv1 b1q15_hhv1)(Quarter Visit Sector fsu hamlet sss shn)

gen HHID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn

save, replace

clear all



// HH Data Visit-2 --REVISIT
use "C:\Users\sarfraz\hhrv.dta"

// Renaming
rename ( nss_hhrv nsc_hhrv mult_hhrv )(NSS NSC Mult)

// Generating Weights

gen weight = Mult /100 if NSS == NSC 
replace weight = Mult /200 if NSS != NSC 
gen Weight = Mult /100 

// Renaming + Creating HHID
rename ( qtr_hhrv visit_hhrv b1q3_hhrv b1q1_hhrv b1q13_hhrv b1q14_hhrv b1q15_hhrv )(Quarter Visit Sector fsu hamlet sss shn)

gen HHID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn

save, replace

// merging HH Level Data
**Open 1 HH level file then merged with another HH data

merge 1:1 HHID using "C:\Users\sarfraz\hhrv.dta"

** Saved as 'HH Merged Data' ~ MANUALLY DO IT using ctrl+S maybe


/*-----------------------------------------------------------------------------------------------------*/
/*-------- INDIVIDUAL LEVEL DATA -----Visit-1----*/

use "C:\Users\sarfraz\perv1.dta"
rename ( NSS_perv1 NSC_perv1 mult_perv1 )(NSS NSC Mult)

// Generating Weights

gen weight = Mult /100 if NSS == NSC 
replace weight = Mult /200 if NSS != NSC 
gen Weight = Mult /100 

// Renaming + Creating HHID  PID 
rename ( qtr_perv1 visit_perv1 b1q3_perv1 b1q1_perv1 b1q13_perv1 b1q14_perv1 b1q15_perv1 b4q1_perv1 )(Quarter Visit Sector fsu hamlet sss shn psn)

gen HHID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn
gen PID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn+psn 

save, replace

/*--------------- INDIVIDUAL LEVEL DATA -----Visit-2----*/

use "C:\Users\sarfraz\perrv.dta"
rename ( NSS_perrv NSC_perrv mult_perrv )(NSS NSC Mult)

// Generating Weights

gen weight = Mult /100 if NSS == NSC 
replace weight = Mult /200 if NSS != NSC 
gen Weight = Mult /100 

// Renaming + Creating HHID  PID 

rename ( qtr_perrv visit_perrv b1q3_perrv b1q1_perrv b1q13_perrv b1q14_perrv b1q15_perrv b4q1_pervv )(Quarter Visit Sector fsu hamlet sss shn psn)

gen HHID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn
gen PID = Quarter+ Visit +Sector +fsu +hamlet+ sss+ shn+psn 

save, replace

// merging Individual Level Data
**Open 1 Ind level file then merged with another Ind data

merge 1:1 PID using "C:\Users\sarfraz\perrv.dta"

drop _merge

** Saved as 'Ind Merged Data'

/*----------------------------------------Merging ----------------------------*/
/*------------- HH + INDIVIDUAL level --------*/


use "C:\Users\sarfraz\HH Merged Data.dta"

drop _merge

merge 1:m HHID using "C:\Users\sarfraz\Ind Merged Data.dta"


** Don't forget to save them 