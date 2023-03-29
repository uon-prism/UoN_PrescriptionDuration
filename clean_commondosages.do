** Created 2022-04-20 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	clean_commondosages.do
* Creator:	RMJ
* Date:	20220420	
* Desc:	Defines these using common_dosages.txt: prn, unitform
* Notes: 
* Version History:
*	Date	Reference	Update
*	20220420	first clean draft	n/a
*	20220620	clean_commondosages	rename unitform dose_form
*	20220622	clean_commondosages	Update file paths with macros
*	20220627	clean_commondosages	Adapt for medication review analysis
*	20230207	prep_clean_commondosages	Adapt for polypharm proj
*   20230329	prep_clean_commondosages	Remove filepath, generate dosekey
*************************************

local loaddir "filepath"	// location of common_dosages.dta OR common_dosages.txt
local savedir "filepath"	// location for saving clean_dosages.dta

frames reset

**# Open & prepare file
** Load dosage lookup. Link with dosage key to get rid of doseid
use "`loaddir'/common_dosages.dta"
// OR
*import delimited "`loaddir'/common_dosages.txt"

sort dosageid

** Numerical identifier - use to reduce memory load in later files
gen dosekey=_n


** Other prep (set 0s to missing)
rename daily_dose ndd
sort dosekey

order dose_unit, last
recode ndd-dose_duration (0=.)
capture drop dosage2
capture drop tag*
gen dosage2 = dosage_text
order dosekey dosage_text dosage2
format dosage_text dosage2 %50s

replace dosage2=lower(dosage2)



**# identify and tag instructions suggesting PRN / as required 
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"prn|p[.]r[.]n|p r n")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"as[ ]*need[ed]*|when[ ]*need[ed]*|if[ ]*need[ed]*")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"as[ ]*nec[cesary]*|when[ ]*nec[cesary]*|if[ ]*nec[cesary]*")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"if really necessary|if absolutely necessary|when absolutely necessary")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"as[ ]*re[c]*q[uired]*|[w]*hen[evr]*[ ]*re[c]*q[uired]*|if[ ]*re[c]*q[uired]*")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"as frequently required")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"ad lib")==1

gen prn=(tag!="")
replace dosage2=subinstr(dosage2,tag," PRN ",.)
drop tag

order dosekey prn





**# identify and label route/formulation information
gen unitform=.
label define unitform 1 "drops" 2 "spray" 3 "inhaled" 4 "injected" 5 "creams/topical" 6 "patches" 7 "tablets" 8 "unspec liquid" 9 "other" , modify
label values unitform unitform



** 1 drops
replace dosage2=subinstr(dosage2,"ladropen","",.)

*** drop(s), dropper(s), dropperful(s)
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"dropper[fuls]*|drop[(]s[)]|drop[s]*")==1
replace tag=regexs(0) if tag=="" & regexm(dosage2,"gtt[s]*|guttat")==1
replace dosage2=subinstr(dosage2,tag," DROP ",.)
replace unitform=1 if tag!=""
drop tag

*** shortened to dr or drp, but do not confuse with Dr (e.g. see dr about...). Also use existing classification.
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"dr[p]* |dr[p]*$")==1
replace dosage2=subinstr(dosage2,tag," DROP ",.) if dose_unit=="DROPS" & unitform!=1
replace unitform=1 if dose_unit=="DROPS"
drop tag

*** instill
capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"insti[ledation]*")==1
replace dosage2=subinstr(dosage2,tag," DROP ",.)
replace unitform=1 if tag!=""
drop tag





** 2 sprays
replace dosage2=subinstr(dosage2,"respritory","respiratory",.)
replace dosage2=subinstr(dosage2,"lispro","",.)
replace dosage2=subinstr(dosage2,"spraringly","sparingly",.)
replace dosage2=subinstr(dosage2,"sprip","strip",.)

forval x=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"spray[sed]*")==1
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"spr|spy")==1
	replace tag="" if tag=="spr" & regexm(dosage2,"spread")==1

	replace dosage2=subinstr(dosage2,tag," SPRAY ",.) if tag!=""
	replace unitform=2 if tag!=""
	drop tag
	}


	
** 3 inhaled
* metered dose inhalers, dry powder inhalers, nebulizers, soft mist inhalers, spacers
replace dosage2=subinstr(dosage2,"inhibitor","",.)
replace dosage2=subinstr(dosage2,"inhibit","",.)

*** inhaled/inhalers/inhalations
forval x=1/2 {
	capture drop tag
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"inh[al]*tion[s()]*")==1
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"inh[alerds()]*")==1

	replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
	replace unitform=3 if tag!=""
	drop tag
}

capture drop tag
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"mdi")==1	// metered dose inhaler
replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
replace unitform=3 if tag!=""
drop tag

*** nebulised
capture drop tag
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"nebuli[sz]er")==1
replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
replace unitform=3 if tag!=""
drop tag

capture drop tag
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"nebul[eizsrd]*")==1
replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
replace unitform=3 if tag!=""
drop tag

capture drop tag
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2," neb ")==1
replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
replace unitform=3 if tag!=""
drop tag

*** (via) spacer devices
forval X=1/2 {
	capture drop tag
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"via spacer|spacer")==1
	replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
	replace unitform=3 if tag!=""
	drop tag
	}

	
** puff (gtn spray under tongue described as puff? puffs in nostril=spray etc)
capture drop tag tag2

gen tag2=regexs(0) if regexm(dosage2,"under[the ]*tongue|subling[ualy]*|chest.+pain|angina|rhinitis")==1

forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"puf[fs()]*")==1
	replace dosage2=subinstr(dosage2,tag," SPRAY ",.) if tag!="" & tag2!=""
	replace unitform=2 if tag!="" & tag2!=""
	drop tag
	}

capture drop tag tag2
gen tag2=regexs(0) if regexm(dosage2,"nose|nostril| ear|aural")==1

forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"puf[fs()]*")==1
	replace dosage2=subinstr(dosage2,tag," SPRAY ",.) if tag!="" & (tag2!="" | unitform==2)
	replace unitform=2 if tag!=""  & (tag2!="" | unitform==2)
	drop tag
	}

capture drop tag tag2
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"puf[fs()]*")==1
replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
replace unitform=3 if tag!=""
drop tag

capture drop tag tag2
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"pu[ufs()]*")==1
replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!="" & dose_unit=="PUFF"
replace unitform=3 if tag!="" & dose_unit=="PUFF"
drop tag

format dosage2 %50s

capture drop tag*
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*hale[r]*")==1
	replace dosage2=subinstr(dosage2,tag," INHALE ",.) if tag!=""
	replace unitform=3 if tag!=""
	drop tag
	}


*** Actuation (if not inhaled then spray?)
capture drop tag*
gen tag=""
replace tag=regexs(0) if regexm(dosage2,"[a-z]*actuat[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag," SPRAY ",.) if tag!="" 
replace unitform=2 if tag!="" & unitform==.
drop tag





** 4 Injections
*** IM IV SC intrathecal (im can also be immediately)
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"inj[ections()]*")==1
	replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
	replace unitform=4 if tag!=""
	drop tag
	}

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"intra[ /-]*m[usculary]*|i[. \/]m[. ]+|i[. \/]m[.]*$| im | im$")==1
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"intrav[enously]*|i[. ]v[. ]+|i[. ]v[.]*$| iv | iv$")==1
drop tag // no changes


gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"intra[ /-]*a[articuly]*|i[. \/]s[. ]+|i[. \/]a[.]*$| ia | ia$")==1
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"subc[utaneosly]*|s[. ]c[. ]+|s[. ]c[.]*$| sc | sc$")==1
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"intrath[ecaly]*")==1
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"syr[inge]*")==1
replace tag="" if tag=="syringing"
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag


gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"ampoule")==1
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2," amp$")==1
replace dosage2=subinstr(dosage2,tag," INJECTION ",.) if tag!="" 
replace unitform=4 if tag!=""
drop tag






** 5 Creams/lotions/ointments/moisturisers/balm/other topical
capture drop tag 
replace dosage2=subinstr(dosage2,"appointment","",.)
replace dosage2=subinstr(dosage2,"top lip","",.)
replace dosage2=subinstr(dosage2,"on top","",.)
replace dosage2=subinstr(dosage2,"top up","",.)
replace dosage2=subinstr(dosage2,"top 20","",.)
replace dosage2=subinstr(dosage2,"top 20","",.)
replace dosage2=subinstr(dosage2,"topper","",.)
replace dosage2=subinstr(dosage2,"soapy","",.)

forval X=1/4 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"cream")==1	// checked for alt spellings
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"e[m]+o[l]+ient")==1	// checked for alt spellings
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"ointment")==1	// checked for alt spellings
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"moistur[iszersng]*")==1
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"lot[io]+n")==1	// checked for alt spellings
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"^top[icaly]*| top[icaly]*")==1
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"bath")==1	
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"shampoo")==1	
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"soap")==1	
	replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
	replace unitform=5 if tag!=""
	drop tag
	}

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"shower gel")==1
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
replace unitform=5 if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"gel")==1
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
replace unitform=5 if tag!=""
drop tag
	
	
	
	
** 6 Patches
capture drop tag 
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"patch[es]*")==1	// checked for alt spellings
replace dosage2=subinstr(dosage2,tag," PATCH ",.) if tag!="" 
replace unitform=6 if tag!=""
drop tag




** 7 Tablets and capsules, pills, pillules (DO NOT REPLACE unitform)
capture drop tag*

*** TABLETS
replace dosage2=subinstr(dosage2,"tabphyn","",.)

**** tablet(s)
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"tablet[s()]*")==1
	replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
	replace unitform=7 if tag!="" & unitform==.
	drop tag
	}

**** tabs (check for 'tabs' within words)
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"tab[s()]+")==1
replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag

**** tab (check for 'tab' within words, e.g. stabilise)
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*tab[a-z]*")==1
replace dosage2=subinstr(dosage2,tag," tab ",.) if tag=="tabl" | tag=="table"	// typos for tablets
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[ein]*stab[a-z]*")==1 // estab*, instab*, stab*
replace dosage2=subinstr(dosage2,tag,"",.) if tag!=""
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*tab[a-z]*")==1
gen tag2=regexs(0) if regexm(tag,"table")==1	// words containing 'table'
gen tag3=subinstr(tag,"tab"," tab ",.)
// replace "tab" in dosage2 with " tab " if tag doesn't include "table"
replace dosage2=subinstr(dosage2,tag,tag3,.) if tag!="" & tag2==""
drop tag*

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2," tab ")==1
replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag


*** CAPSULES
capture drop tag*
replace dosage2=subinstr(dosage2,"capsful","capfulls",.)
replace dosage2=subinstr(dosage2,"lacaps","",.)
replace dosage2=subinstr(dosage2,"caplenal","",.)
replace dosage2=subinstr(dosage2,"capcule","capsule",.)

**** capsule(s)
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"capsule[s()]*")==1	// checked for alt spellings
	replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
	replace unitform=7 if tag!="" & unitform==.
	drop tag
	}

**** caps
capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*caps[a-z]*")==1	// check for caps within other words
drop tag
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"caps[s()]*")==1	
replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag

**** caplets (rename to handle with cap below)
capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*caplet[s()]*")==1
replace dosage2=subinstr(dosage2,tag,"cap",.) 
drop tag

**** cap
capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*cap[a-z]*")==1	// check for cap within other words
gen tag2=regexs(0) if regexm(dosage2,"capf[fuls]*")==1	// identify capful variants (and correct)
replace dosage2=subinstr(dosage2,tag2,"capful",.) if tag2!=""
gen tag3=subinstr(tag,"cap"," cap ",.)
// replace "cap" in dosage2 with " cap " if tag doesn't include "capful"
replace dosage2=subinstr(dosage2,tag,tag3,.) if tag!="" & tag2==""
drop tag*

capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2," cap ")==1
replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag


*** PILLS
capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*pill[a-z]*")==1	// check for pill within other words

// remove reference to contraceptive pill within other instructions
gen tag2=regexs(0) if regexm(dosage2,"course")==1
replace dosage2=subinstr(dosage2,tag,"",.) if tag!="" & tag2!=""

drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*pill[a-z]*")==1	// check for pill within other words
replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag





** 8 UNSPEC LIQUIDS
*** ML
replace dosage2=subinstr(dosage2,"amlodipine","",.)
replace dosage2=subinstr(dosage2,"amlostin","",.)
replace dosage2=subinstr(dosage2,"opthalmlogist","",.)
replace dosage2=subinstr(dosage2,"cipramil","",.)
replace dosage2=subinstr(dosage2,"family","",.)
replace dosage2=subinstr(dosage2,"mild","",.)
replace dosage2=subinstr(dosage2,"milder","",.)
replace dosage2=subinstr(dosage2,"milk","",.)
replace dosage2=subinstr(dosage2,"milky","",.)
replace dosage2=subinstr(dosage2,"similar","",.)

capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*m[il]*l[iltres]*[a-z]*")==1 // check within other words
replace dosage2=subinstr(dosage2,tag," mg ",.) if tag=="milligram" | tag=="milligramme" | tag=="milligrams"
replace dosage2=subinstr(dosage2,tag," ml stat ",.) if tag=="mlstat"

gen tag2=""
replace tag2=regexs(0) if regexm(dosage2,"mil[litres]*")==1 // mil and millilitre
replace dosage2=subinstr(dosage2,tag2," ML ",.) if tag2!="" 
replace unitform=8 if tag2!="" & unitform==.
drop tag2

forval X=1/2 {
	gen tag2=""
	replace tag2=regexs(0) if regexm(dosage2,"ml[s]*")==1 // 
	replace dosage2=subinstr(dosage2,tag2," ML ",.) if tag2!="" 
	replace unitform=8 if tag2!="" & unitform==.
	drop tag2
}

capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*msl[a-z]*")==1 // typo, msl
replace dosage2=subinstr(dosage2,"msl"," ML ",.) if tag!="" 
replace unitform=8 if tag!="" & unitform==.
drop tag

*** cc (1ml)
* checked for cm, centimetre
capture drop tag*

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*cc[a-z]*")==1 // check within other words

gen tag2=""
replace tag2=regexs(0) if tag2=="" & regexm(dosage2,"[05]cc")==1 // check within other words
replace dosage2=subinstr(dosage2,"cc"," ML ",.) if tag2!="" 
replace unitform=8 if tag2!="" & unitform==.

drop tag*



*** SPOONS
capture drop tag*

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z\-]*[ ]*sp[o]*n[fuls()]*[a-z]*")==1	

gen tag2=""
replace tag2=regexs(0) if tag2=="" & regexm(dosage2,"dessertspoon[fuls()]*[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag2," X 10 ML SPOON ",.) if tag2!="" 
replace unitform=8 if tag2!="" & unitform==.
drop tag2

gen tag2=""
replace tag2=regexs(0) if tag2=="" & regexm(dosage2,"tablespoon[fuls()]*[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag2," X 15 ML SPOON ",.) if tag2!="" 
replace unitform=8 if tag2!="" & unitform==.
drop tag2

gen tag2=""
replace tag2=regexs(0) if tag2=="" & regexm(dosage2,"teaspoon[fuls()]*[a-z]*")==1	
gen tag3=regexs(0) if regexm(dosage2,"ML teaspoon[fuls()]*[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag2," X 5 ML SPOON ",.) if tag2!="" & tag3==""
replace dosage2=subinstr(dosage2,tag2," SPOON ",.) if tag2!=""
replace unitform=8 if tag2!="" & unitform==.
drop tag2

capture drop tag*
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"spoon[fuls()]*[a-z]*")==1
	replace dosage2=subinstr(dosage2,tag," SPOON ",.) if tag!="" 
	replace unitform=8 if tag!="" & unitform==.
	drop tag
	}

	
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2," spn[fuls()]*[a-z]*")==1
replace dosage2=subinstr(dosage2,tag," SPOON ",.) if tag!="" 
replace unitform=8 if tag!="" & unitform==.
drop tag

*************
replace dosage2=stritrim(dosage2)
replace dosage2=strtrim(dosage2)
*************




** 9 OTHER
*** sachet
replace dosage2=subinstr(dosage2,"dansac","",.)
replace dosage2=subinstr(dosage2,"rosacea","",.)

capture drop tag*
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if regexm(dosage2,"sac[hets]*")==1	// alt spellings checked
	replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
	replace unitform=9 if tag!="" & unitform==.
	drop tag
	}

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"sa[tc]+het[s]*")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag


*** pessary, suppository, per rectum, per vagina, pv	
capture drop tag*
gen tag=""
replace tag=regexs(0) if regexm(dosage2,"perssary|pe[s]+a[ry]+")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"supp |suppositor[y]*")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"per[ ]*rectum|rectum")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"per[ ]*vagin[aly]*|[a-z]*vagin[aly]*[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2," pv | pv$")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag



*** insert	
capture drop tag*
gen tag=""
replace tag=regexs(0) if regexm(dosage2,"[a-z]*insert[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag


*** pen, penfill
capture drop tag*
gen tag=""
replace tag=regexs(0) if regexm(dosage2," pen[ ]*fi[ls]*| pen[s]* | pen[s]*$")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag


*** to dissolve in mouth (chew, suck, pastille, lozenge, wafer, sublingual)
replace dosage2=subinstr(dosage2,"don't chew","",.)
replace dosage2=subinstr(dosage2,"calcichew","",.)
replace dosage2=subinstr(dosage2,"not chewed","",.)

capture drop tag*
gen tag=""
replace tag=regexs(0) if regexm(dosage2,"[a-z]*chew[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"suck[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"pastille")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"lozenge")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"wafer[s]*")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"sub[ \-]ling[ualy]*")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if regexm(dosage2,"under[the ]*tong[ue]+")==1	// alt spellings checked
replace dosage2=subinstr(dosage2,tag," OTHER ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag



*** items that dissolve (set to other)
capture drop tag*
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"di[s]+olve[d]*")==1	// ignore 'dissolving'
replace dosage2=subinstr(dosage2,tag," DISSOLVE ",.) if tag!="" 
replace unitform=9 if tag!="" & unitform==.
drop tag





** FURTHER EDITS: CREAMS (apply* -> topical if not otherwise specified)
capture drop tag*
gen tag=""
*replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a]+[p]+[l]+[yied]*")==1	
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a]+[p]+[l]+y")==1	
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
replace unitform=5 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a]+[p]+[l]+icat[ionrfuls]*")==1	
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
replace unitform=5 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"apple[dy]")==1	
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
replace unitform=5 if tag!="" & unitform==.
drop tag

replace dosage2=subinstr(dosage2,"appliance","",.)
replace dosage2=subinstr(dosage2,"kaplon","",.)
replace dosage2=subinstr(dosage2,"pineapple","",.)
replace dosage2=subinstr(dosage2,"apple","",.)

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a]+[p]+[l]+[iedy]*")==1	
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" 
replace unitform=5 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"app")==1	
gen tag2=regexs(0) if regexm(dosage2,"[a-z]*app[a-z]*")==1	

replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" & tag2=="app"
replace unitform=5 if tag!="" & tag2=="app" & unitform==.

replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" & (tag2=="appod"|tag2=="appbd"|tag2=="apptds"|tag2=="appqds"|tag2=="appy"|tag2=="appicatorful")
replace unitform=5 if tag!="" & unitform==. & (tag2=="appod"|tag2=="appbd"|tag2=="apptds"|tag2=="appqds"|tag2=="appy"|tag2=="appicatorful")

drop tag*


*** rub(bed)
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"ru[b]+[ed]*")==1	
replace dosage2=subinstr(dosage2,tag," TOPICAL ",.) if tag!="" & dosage2!="rubavax"
replace unitform=5 if tag!="" & unitform==. & dosage2!="rubavax"
drop tag




** FURTHER EDITS: TABLETS (taken or swallowed, mcg or mg)
capture drop tag*
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"to be taken|taken")==1	
	replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
	replace unitform=7 if tag!="" & unitform==.
	drop tag
	}

replace dosage2=subinstr(dosage2,"intake","",.)
capture drop tag*
forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*ta[k]+[ew]")==1	
	replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
	replace unitform=7 if tag!="" & unitform==.
	drop tag
	}	

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*ta[lm]+e")==1
	
	
*** swallow	
capture drop tag
gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"[a-z]*swa[l]+o[w]+[ed]+[a-z]*")==1	
replace dosage2=subinstr(dosage2,tag," TABLET ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag


*** weights
// grams large volumes, could be creams
replace dosage2=subinstr(dosage2,"microgynon","",.)

capture drop tag*

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2,"m[i]*c[ro]*g[ram]*[s()]*")==1	
replace dosage2=subinstr(dosage2,tag," MICROGRAMS ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag

gen tag=""
replace tag=regexs(0) if tag=="" & regexm(dosage2," ug ")==1	
replace dosage2=subinstr(dosage2,tag," MICROGRAMS ",.) if tag!="" 
replace unitform=7 if tag!="" & unitform==.
drop tag

forval X=1/2 {
	gen tag=""
	replace tag=regexs(0) if tag=="" & regexm(dosage2,"mg[rams()]*")==1	
	replace dosage2=subinstr(dosage2,tag," MG ",.) if tag!="" 
	replace unitform=7 if tag!="" & unitform==.
	drop tag
	}



***
replace dosage2=stritrim(dosage2)
replace dosage2=strtrim(dosage2)
***

order dosekey prn unitform


**# Finalise file
keep dosageid dosekey prn unitform dosage2
label var prn "1 = take/use as required"
label var unitform "Formulation information extracted from dosage text"
label var dosage2 "Simplified dosage text"

rename unitform dose_form

save "`savedir'/clean_dosages.dta", replace

frames reset

exit


