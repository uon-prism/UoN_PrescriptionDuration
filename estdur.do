** Created 29 June 2022 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	estdur.do
* Desc:	Estimates start and stop dates for all prescription records
* Notes: Requires frameappend
* Version History:
*	Date	Reference	Update
*	20220629	prep_estprescriptionlength First full version written as program
* 	20220629	estdur	Add if loops to prevent error if no prn records/no records
*	20220701	estdur	Use frameappend instead of tempfile>save>append
*	20220701	estdur	Update def of `prescseq' so sort order is fixed for all
*	20220822	estdur	Use duration1 even when reppresc!=1
* 	20220822	estdur	Fill in newdif (duration1) for all records on same day
* 	20220823	estdur	Add if loops for cleaning qty ndd to avoid crash if all missing
*	20220824	estdur	Update selection of duration vars - now 3 can be averaged
*	20230209	estdur	At start use frame put if "`if'"!=""
*************************************

capture program drop estdur
program define estdur
	version 17.0
	
	*** Specify syntax
	syntax [if] [, KEEPDUPs MAXDURation(integer 365) DROPQTY ///
		MAXDIFference(integer 28) PRNDEFault(integer 28) ///
		DEFAULT(integer 28) BYPAT DROPSAMEDAY OVERLAP(integer 14) ///
		MAXGAP(integer 14)]
	
	*** Display options to user
	di "Options selected are:"
	if "`keepdups'"!="" di as text "At start, drop records that are duplicates in terms of *all* variables?	" as result "NO"
	if "`keepdups'"=="" di as text "At start, drop records that are duplicates in terms of *all* variables?	" as result "YES"
	
	if "`dropsameday'"!="" di as text "Drop records that are duplicates on patid eventdate prodcode?	" as result "YES"
	else di as text "Drop records that are duplicates on patid eventdate prodcode?	" as result "NO"
	
	di as text "Maximum duration of any prescription:	" as result "`maxduration'"
	
	if "`dropqty'"!="" di as text "Drop variable derived from quantity/daily dose?	" as result "YES"
	else di as text "Drop variable derived from quantity/daily dose?	" as result "NO"
	
	di as text "Maximum allowable difference between two durations to be averaged:	" as result "`maxdifference'"
	di as text `"Default length of prescriptions marked "as required":	"' as result "`prndefault'"
	di as text "Default length of other prescriptions:	" as result "`default'"
	
	if "`bypat'"!="" di as text "Calculate median durations by *patid* as well as prodcode?	" as result "YES"
	else di as text "Calculate median durations by *patid* as well as prodcode?	" as result "NO"


	
	di as text "Maximum overlap to be carried forward to next gap:	" as result "`overlap'"
	di as text "Maxumum gap to treat as continued exposure:	" as result "`maxgap'"

	
	*** Move records into temporary frame (subset with `if' where present)
	tempname working
	if "`if'"=="" {
		frame pwf
		frame copy `r(currentframe)' `working' 
	}
	if "`if'"!="" {
		frame put `if', into(`working')
	}
	
	*** Drop records from current frame (will be replaced by modified versions)
	if "`if'"!="" drop `if'
	else drop _all	
	
	*** in new frame
	frame `working' {
		
		capture drop start
		capture drop stop
		capture drop summed_qty
		capture drop num_recs
		
		
		
		******* PART 1 - DEFINE ALL POSSIBLE DURATION VARS FOR RECORDS OF INTEREST
		*******
		
		*** Keep only records that meet the "if" argument
		if "`if'"!="" keep `if'	

		*** exit if no records
		count
		if `r(N)'==0 {
			di as error "There are no observations remaining."
			exit
		}
		
		*** (optionally) Drop duplicates in terms of all variables
		if "`keepdups'"=="" duplicates drop
		
		*** Define temporary variable establishing order of records by patid prodcode
		sort patid prodcode eventdate consid issueseq qty dosekey numdays
		tempvar prescseq
		by patid prodcode: gen `prescseq'=_n

		
		*** (NOTE, MOVED FROM LATER STEP) (optionally) Drop duplicates of ...
		*** ... patid prodcode eventdate (keep FIRST on that day)
		sort patid prodcode eventdate `prescseq'
		if "`dropsameday'"!="" by patid prodcode eventdate: keep if _n==1
			
		
		*** Calculate median time between prescription refills
		**** Time difference between a prescription and the prescription that follows it (if repeat):
		tempvar reppresc dif
		gen `reppresc'=(issueseq>0 & issueseq<.)
		
		sort patid prodcode eventdate
		by patid prodcode: gen `dif'=eventdate[_n+1] - eventdate if _n!=_N
		replace `dif'=. if `reppresc'==0
		
		**** Account for multiple repeat prescs same day (e.g. batch)...
		**** ... time to next DATE divided by number of (repeat) records
		tempvar sumdif numrecs newdif
		by patid prodcode eventdate: egen `sumdif'=sum(`dif')
		replace `sumdif'=. if `sumdif'==0 // happens if last record or not repeat presc
		
		by patid prodcode eventdate: egen `numrecs'=sum(`reppresc')
		
		by patid prodcode eventdate: gen `newdif'=`sumdif'/`numrecs' // if _n==1
		replace `newdif'=. if `reppresc'==0
		
		*** Clean quantity and daily dose
		tempvar quantity ndd
		gen `quantity'=qty if qty>0
		gen `ndd'=daily_dose if daily_dose>0
		
		count if `quantity'==.
		if `r(N)'!=_N {
			sum `quantity', d
			replace `quantity'=. if `quantity'>`r(p99)'
		}
		
		if `r(N)'!=_N {
			sum `ndd',d
			replace `ndd'=. if `ndd'>`r(p99)'
		}
		
		*** Generate duration variables
		tempvar duration1 duration2 duration3 duration4
		by patid prodcode: egen `duration1'=median(`newdif')
		gen `duration2' = `quantity'/`ndd'
		gen `duration3' = numdays if numdays>0
		gen `duration4' = dose_duration if dose_duration>0
		
		

		
		*** Clean duration variables (missing if outside specified range)
		forval NUM=1/4 {
			replace `duration`NUM''=floor(`duration`NUM'')
			replace `duration`NUM''=. if `duration`NUM''<1
			replace `duration`NUM''=. if `duration`NUM''>`maxduration'
		}

		
		*** If indicated, drop duration2 (qty/daily_dose)
		if "`dropqty'"!="" replace `duration2'=.
		
		sort patid prodcode `prescseq'
		
		
		
		******* PART 2 - SPECIFY DURATION FOR EACH RECORD
		******* Set duration if prescription marked "as required"
		tempvar finaldur
		gen `finaldur'=.
		
		*** *IF* there are prn records, copy them into a new frame
		tempname sc_prn
		count if prn==1
		scalar `sc_prn'=`r(N)'
		
		if `sc_prn'>0 { 
			tempname prn123
			frame put if prn==1, into(`prn123')
			drop if prn==1
			
			frame `prn123' {
				
				*** Use duration3 (numdays) or duration4 (dose_duration), or average of them if similar
				tempvar dif2
				gen `dif2'=abs(`duration4' - `duration3')
				
				*** If only one of them is non-missing, use that
				replace `finaldur'=`duration3' if `duration4'==.
				replace `finaldur'=`duration4' if `duration3'==.
				
				*** If both are non-missing, use the average of them if within specified `maxdifference'
				replace `finaldur'=`duration3' if `duration3'==`duration4'
				replace `finaldur'=floor((`duration3' + `duration4')/2) ///
					if `finaldur'==. & `dif2'<`maxdifference'
				
				drop `dif2'
				
				*** Otherwise, use the median time between repeat prescriptions
				replace `finaldur'=`duration1' if `finaldur'==. // cut & `reppresc'==1
				
				*** Otherwise, set to specified default duration
				replace `finaldur'=`prndefault' if `finaldur'==.
				
			} // go back to frame "working" (close frame "prn123")
				
		
		} // close if loop (if sc_prn>0)
	

		******* Set duration for remaining prescriptions		
		*** Use duration2, duration3, or duration4 if present and similar
		**** New temporary vars to calculate differences
		tempvar nonmiss avg dif23 dif24 dif34 mindif meddif
		
		egen `nonmiss' = rownonmiss(`duration2' `duration3' `duration4')
		egen `avg' = rowmean(`duration2' `duration3' `duration4')
		replace `avg' = floor(`avg')

		gen `dif23' = abs(`duration2' - `duration3')
		gen `dif24' = abs(`duration2' - `duration4')
		gen `dif34' = abs(`duration4' - `duration3')

		egen `mindif' = rowmin(`dif23' `dif24' `dif34')	// identifies smallest difference
		egen `meddif' = rowmedian(`dif23' `dif24' `dif34')	// shows if two values are the same

		replace `mindif' = . if `mindif' > `maxdifference' // use to indicate whether durations are similar enough

		**** one non-missing duration (use that value)
		replace `finaldur'=`avg' if `finaldur'==. & `nonmiss'==1

		**** two non-missing durations (use average if difference is smaller than maxdifference)
		replace `finaldur'=`avg' if `finaldur'==. & `nonmiss'==2 & `mindif'<.

		**** any two (or three) equal durations, use that value
		replace `finaldur'=`duration2' if `finaldur'==. & `nonmiss'>1 & `duration2'==`duration3'
		replace `finaldur'=`duration2' if `finaldur'==. & `nonmiss'>1 & `duration2'==`duration4'
		replace `finaldur'=`duration3' if `finaldur'==. & `nonmiss'>1 & `duration3'==`duration4'

		**** three non-missing durations, evenly spaced (use average of all three, i.e. middle value, if small difs)
		replace `finaldur'=`avg' if `finaldur'==. & `nonmiss'==3 & `mindif'<. & `mindif'==`meddif'

		**** three non-missing durations, two values closer than third (use avg of two closest values if dif<maxdif)
		replace `finaldur'=floor((`duration2' + `duration3')/2) ///
			if `finaldur'==. & `nonmiss'==3 & `mindif'<. & `dif23'==`mindif'
		
		replace `finaldur'=floor((`duration2' + `duration4')/2) ///
			if `finaldur'==. & `nonmiss'==3 & `mindif'<. & `dif24'==`mindif'
		
		replace `finaldur'=floor((`duration3' + `duration4')/2) ///
			if `finaldur'==. & `nonmiss'==3 & `mindif'<. & `dif34'==`mindif'
		
		drop `nonmiss' `avg' `dif23' `dif24' `dif34' `mindif' `meddif'
		
		
		*** If still missing, use median time between repeat prescriptions
		replace `finaldur'=`duration1' if `finaldur'==. // cut & `reppresc'==1

		
		*** If still missing, use median duration for that product (pop or pat level)
		tempvar meddur
		
		if "`bypat'"!="" bys patid prodcode: egen `meddur'=median(`finaldur')
		else bys prodcode: egen `meddur'=median(`finaldur')
		
		replace `finaldur'=`meddur' if `finaldur'==.

		*** If still missing, use specified default duration
		replace `finaldur'=`default' if `finaldur'==.
		
		
		*** Re-append the prn records (if they existed)
		if `sc_prn'>0 {

			frameappend `prn123', drop
		}
			
		
		sort patid prodcode `prescseq'
		
		
		
		
		******* PART 3 - CLEAN OVERLAPS / GAPS
		*** Start and stop dates
		gen start = eventdate
		gen stop = start + `finaldur'
		format start stop %dD/N/CY
		
		
		
		*** Where records have same start date (if not already dropped), sum...
		*** ... the total duration and keep one record. Show how many records...
		***	... have been combined.
		tempvar newdur
		
		sort patid prodcode eventdate `prescseq'
		by patid prodcode eventdate: egen summed_qty=sum(`quantity')
		by patid prodcode eventdate: gen num_recs=_N
		by patid prodcode eventdate: egen `newdur'=sum(`finaldur')
		by patid prodcode eventdate: keep if _n==1
		
		**** set this new variable to maxduration if it is >maxduration
		replace `newdur'=`maxduration' if `newdur'>`maxduration'
		replace stop = start + `newdur'

		
		
		
		*** Overlapping records. Truncate, and add the truncated time to the...
		*** ... next available gap.
		tempvar nextstart prevstop truncated new newid sumt newoverlap
		
		**** Number of days overlap of two records A and B, attach to A
		sort patid prodcode `prescseq'
		
		by patid prodcode: gen `nextstart'=start[_n+1] if _n!=_N
		by patid prodcode: gen `prevstop'=stop[_n-1] if _n!=1
		format `nextstart' `prevstop' %dD/N/CY
		gen `truncated' = stop - `nextstart'
		replace `truncated'=. if `truncated'<=0		
	
		**** Truncate record A (stop of A becomes start of B)
		replace stop=`nextstart' if `truncated'<.
		replace `newdur' = stop - start		
		
		**** Make identifier for a run of continuous prescs
		gen `new'=1 if start > `prevstop'
		by patid prodcode: gen `newid'=sum(`new')
		
		**** Sum the number of truncated days within each continuous run of prescriptions
		sort patid prodcode `newid' start
		by patid prodcode `newid': gen `sumt'=sum(`truncated')

		**** If the number of truncated days is greater than specified number... 
		**** ... replace with that number
		replace `sumt'=`overlap' if `sumt'>`overlap' & `sumt'<.
		
		**** Add the number of truncated days to the last day of the run of prescs
		by patid prodcode `newid': replace `newdur'=`newdur' + `sumt' if _n==_N
		replace stop = start + `newdur'		
		
		**** This can introduce new overlaps so truncate records once more
		drop `nextstart' `prevstop' `truncated'

		by patid prodcode: gen `nextstart'=start[_n+1] if _n!=_N
		by patid prodcode: gen `prevstop'=stop[_n-1] if _n!=1
		format `nextstart' `prevstop' %dD/N/CY
		gen `truncated'= stop - `nextstart'
		replace `truncated'=. if `truncated'<=0

		replace stop = `nextstart' if `truncated'<.
		replace `newdur' = stop - start

		**** Check for outstanding overlaps
		by patid prodcode: gen `newoverlap' = start<stop[_n-1] & _n>1
		qui sum `newoverlap'

		if `r(max)'!=0 {
			di as error "There are still overlaps in this dataset - review"
			exit
		}

		drop `new' `newid' `sumt' `nextstart' `prevstop' `truncated' `newoverlap'		
		
		
		
		
		*** Gaps between prescriptions: fill in up to max, truncate new overlaps
		sort patid prodcode start
		
		tempvar nextstart prevstop gap newoverlap truncated
		
		**** Identify and find length of gaps
		by patid prodcode: gen `nextstart'=start[_n+1] if _n!=_N
		by patid prodcode: gen `prevstop'=stop[_n-1] if _n!=1
		format `nextstart' `prevstop' %dD/N/CY

		gen `gap' = `nextstart' - stop
		replace `gap'=0 if `gap'==.		
		
		**** If gap is greater than maxgap, set to 0 (so stop doesn't change)
		replace `gap'=0 if `gap'>`maxgap'

		**** Add the gap to the stop date
		replace `newdur' = `newdur' + `gap'
		replace stop = start + `newdur'
		
		**** If this has created overlaps, truncate
		drop `nextstart' `prevstop' 

		by patid prodcode: gen `nextstart'=start[_n+1] if _n!=_N
		by patid prodcode: gen `prevstop'=stop[_n-1] if _n!=1
		format `nextstart' `prevstop' %dD/N/CY
		gen `truncated' = stop - `nextstart'
		replace `truncated'=. if `truncated'<=0

		replace stop=`nextstart' if `truncated'<.
		replace `newdur' = stop - start

		
		
		**** Check for outstanding overlaps
		by patid prodcode: gen `newoverlap' = start<stop[_n-1] & _n>1
		qui sum `newoverlap'

		if `r(max)'!=0 {
			di as error "There are still overlaps in this dataset - review"
			exit
		}
		
		
		
		********* Save this and add it to the original dataset
		sort patid start prodcode
		
		label var start "Prescription start date"
		label var stop "Prescription end date"
		label var summed_qty "Total quantity if >1 record of prodcode per day"
		label var num_recs "Number of records if >1 record of prodcode per day"
		
	} // go back to original frame (close frame "working")
	
	
	*** Add the processed records back to the original frame
	frameappend `working', drop
	
	
end
exit
