# UoN_PrescriptionDuration
Stata do-files to estimate prescription duration for CPRD GOLD Therapy records

The files in this repository were designed and written by researchers at the University of Nottingham. They were created for projects funded by the National Institute for Health and Care Research Nottingham Biomedical Research Centre. Any views expressed are those of the author(s) and not necessarily those of the NIHR or the Department of Health and Social Care.

We acknowledge the work of [Pye et al. (2018)](https://doi.org/10.1002/pds.4440) which was inspiration for this code.


## User guide & requirements
This repository includes two Stata do-files created using Stata MP version 17.0. The file 'estdur.do' estimates a duration, start date, and stop date for prescription records in a CPRD GOLD Therapy dataset (see https://www.cprd.com/). The file 'clean_commondosages.do' extracts information from the dosage text provided in the common_dosage lookup file.

Requirements:
* CPRD GOLD Therapy data
* CPRD GOLD common_dosages lookup file
* Stata v16+ (frames functionality is required)
* The user-written command frameappend (`ssc install frameappend`)

Detailed instructions for using the two files are provided below. It is not necessary to run clean_commondosages.do to run estdur.do, but it will generate the variable **prn** which may be useful. Before running estdur.do, load the therapy data and link it with _either_ the common_dosages lookup, or the file clean_dosages.dta produced by clean_commondosages.do. 

Futher recommendations:
* If the therapy data are large, it may be useful to split them into multiple datasets. All available records of each individual prodcode of interest should be contained within a single file, as study population-based averages are calculated.
* Keep only the variables of interest to reduce the memory load. Try to remove string variables where possible. In particular, using the user-generated **dosekey** variable instead of the original **dosageid** is recommended.


## clean_commondosages.do
Run this do-file using the common_dosages file provided by CPRD to generate **prn**, a flag indicating whether the dosage instruction includes "use as required". It also generates **unitform**, which is formulation information extracted from the dosage text. Specify file paths at line 18 and 19. Specify file type (.dta or .txt) at line 25 or 27.


## estdur.do
First, run this do-file to define the program 'estdur'. Then run the command estdur as described below. The user-written command **frameappend** is required. 

**Syntax**

`estdur [if] [, options]`

|**options**                 |**description**|
|----------------------------|---------------|
|**keepdup**s                |keep duplicate records in terms of _all_ variables|
|**dropsameday**             |drop records that are duplicates on patid prodcode eventdate|
|**maxdur**ation(_integer_)  |maximum duration (days) of any individual prescription; default is maxdur(365)|
|**dropqty**                 |do not use quantity over daily dose as a duration option|
|**maxdif**ference(_integer_)|maximum acceptable difference (days) between two duration variables when taking mean; default is maxdif(28)|
|**bypat**                   |calculate median duration (days) by patid prodcode rather than just prodcode|
|**prndef**ault(_integer_)   |default duration (days) for 'as required' prescriptions if no duration is estimated; default is prndef(28)|
|**default**(_integer_)      |default duration (days) for normal prescriptions if no duration is estimated; default is default(28)|
|**overlap**(_integer_)      |maximum overlap (days) carried forward to next gap in exposure; default is overlap(14)|
|**maxgap**(_integer_)       |maximum gap (days) to treat as continuous exposure; default is maxgap(14)|

**Description**

**estdur** estimates a start and stop date for every prescription record in a CPRD GOLD therapy dataset. It uses multiple sources to estimate a prescription duration, and the process differs depending on whether or not the prescription is marked **prn** (i.e. 'use as required'). The start date is the original eventdate and the stop date is the start date plus the estimated duration. Where consecutive prescriptions for the same prodcode overlap, the records are truncated and the total number of days of overlap (up to a user-specified maximum) are added to the last prescription record in the sequence. Where there are small gaps between prescriptions of the same prodcode (up to a user-specified maximum), the gaps are filled in and so treated as continuous exposure. 

The duration variables/information considered are:
1. qty/daily_dose (Quantity divided by daily dose).
2. numdays (number of days specified by prescriber).
3. dose_duration (prescription duration derived from dosage instructions by CPRD).
4. Average time between repeat prescriptions (by patid prodcode).
5. Median duration (by prodcode, or patid prodcode if option 'bypat' is specified).
6. A user-specified default duration

**Required variables**
|**variable name**|**description**|
|-----------------|---------------|
|patid            |patid as provided by CPRD in Therapy file|
|prodcode         |prodcode as provided by CPRD in Therapy file|
|eventdate        |**numerical** version of eventdate|
|consid*          |consid as provided by CPRD in Therapy file|
|issueseq**       |issueseq as provided by CPRD in Therapy file|
|qty              |qty as provided by CPRD in Therapy file|
|dosekey*         |user-generated numerical id linking to string dosageid var provided by CPRD|
|numdays          |numdays as provided by CPRD in Therapy file|
|daily_dose       |daily_dose from common_dosages file (links to Therapy via dosageid)|
|dose_duration    |dose_duration from common_dosages file (links to Therapy via dosageid)|
|prn**            |indicator of whether or not the prescription indicated prn ('use as required'); user-generated using clean_commondosages.do (note, CPRD also provide a flag). 1 indicates prn.|

*These variables are only used to sort the dataset. If you don't have these variables in your dataset, generate them as missing to prevent the code crashing.

**If you don't have these variables, or don't want to use them, create them and/or set them to missing for all records.


**Options**

**keepdups**	- unless keepdups is specified, true duplicates (duplicates in _all_ variables) are dropped. 

**dropsameday**	- specifying dropsameday means duplicates in terms of patid prodcode and eventdate are dropped, and the time associated with those records will not be accounted for.

**maxduration**	is the maximum duration (days) allowed for any individual prescription record. Individual durations are set to missing if greater than maxduration. When prescriptions for the same drug with the same start date are combined, the new total duration is set to maxduration if it is greater than maxduration. 

**dropqty**	- specifying dropqty means the duration calculated by dividing quantity by daily dose is set to missing (and thus not used). May be particularly useful for medicines that are not in a discrete formulation (e.g. creams and inhalers).

**maxdifference** is the maximum allowable difference (days) between different duration variables when they are used to calculate the mean duration. Where there are multiple duration variables for a single record, the difference between the variables is calculated. If the _smallest_ difference between variables is greater than maxdifference, then the mean is ignored.

**bypat** - specifying bypat means median durations are calculated by patid and prodcode, not just prodcode.

**prndefault** is the default value (days) for prescriptions marked 'prn' (use as required), used when no other duration is available. The default value is 28 days.

**default** is the default value (days) for remaining prescriptions (i.e. prescriptions not marked 'prn'), used when no other duration is available. The default value is 28 days.

**overlap** is the maximum number of days that are carried forwards when records overlap. Where records overlap, the number of days overlap is calculated and added to the final record before a gap in exposure.If the total overlap is greater than **overlap**, it is replaced with **overlap**.

**maxgap** is the maximum number of days' gap between two prescriptions for the same prodcode allowed before the gap is considered a break in exposure. If the gap is less than or equal to **maxgap**, the time is considered exposed; if the gap is greater than **maxgap**, the time is considered unexposed.


**Examples**

`estdur if formulation==7, maxdur(365) maxdif(28) prndef(28) default(28) overlap(14) maxgap(14)`

`estdur if formulation!=7, dropqty maxdur(365) maxdif(28) prndef(28) default(28) overlap(14) maxgap(14)`

`estdur if bnf==5, maxdur(365) maxdif(28) prndef(7) default(7) overlap(14) maxgap(14)`
