// seml_train.do [new] [range]
// Trains a neural network based on meta information and a scrutinized training sample
// to identify false positives in SearchEngine results.
// Several network profiles will be trained and reported.
//
// Parameter:
// new - recreates training data, e.g. to change retention, otherwise an existing train file will be used
// range - an equal value will be copied downward until another non-missing value is encountered within a block
//
// range-mode is typically required, if students misunderstood the default format (see below).
//
// Requires:
// meta.txt or meta.dta - full meta export of the result
// sample*.txt - scrutinized samples in ExtendedExport format 
// export*.txt - scrutinized run-populations (complete runs) in ExtendedExport format
// truth*.txt - scrutinized ground truth (optional)
// at least one sample or export file is required
// brain package for stata (https://github.com/ThorstenDoherr/brain)
//
//
// Output:
// seml_train.dta - training data
// seml.brn - neural network file with the best accuracy
// seml#.brn - numbered neural network files for the different training setups
// train.dta - prediction for training data of the best network
// seml_train.log - log file
//
// Remarks:
// - equal has to be 1 (match) or 9 (non-match) in samples, exports and truths
// - a value in a block header of the scrutinized data (searched not empty, found empty) is the default value for the block (reduces typing)
// - the default value in the block header is used for all missings and zeroes within a block
// - in range-mode, an equal value will be copied until another non-missing value is encountered
// - range-mode is applied before the default replacement but is considered the inferior format because it is more prone to errors
// - truth*.txt files replace the random draw of the retention
// - export*.txt observations overwrite the estimation because they contain complete runs or other sub-populations
// - retention will only be redrawn if the "new" parameter is specified
// - retention will be drawn only from sample files
//
// AGGREGATION OF SEARCH RUNS
// Search runs with similar setups but only different thresholds can be aggregated.
// Search runs with low number of observations should be aggregated with similar search runs,
// i.e. runs using 3gram preparer regardless off smoothing.
// To aggregate search runs add definitions after the settings.
// Examples (enumerate the macros in ascending order):
// global run1 2 3 4    // to aggregate run 2, 3 and 4
// global run2 6 7 8 9  // to aggregate run 6 to 9
//
// Settings:
global batch 8 // mini batch size
global retention 0.1 // 0.1 will retain 10% of the sample for testing

clear all
set more off
tempfile meta sample
cap log close
log using seml_train.log, replace

// isolates meta vars
global non_meta = "source searched found weight retention truth export sample eq id equal"
cap program drop meta_vars
program define meta_vars
	qui des, varlist
	global meta_vars = " "+r(varlist)+" "
	tokenize "$non_meta"
	while "`1'" != "" {
		global meta_vars = subinstr("$meta_vars"," `1' "," ",1)
		macro shift
	}
	global meta_vars = trim("$meta_vars")
end

//aggregates search runs in case of low representation
cap program drop aggregate_run
program define aggregate_run
	di as text "aggregating runs " as result "`*'"
	local run = "`1'"
	local list = "`1'"
	macro shift
	while "`1'" != "" {
		qui replace run`run' = 1 if run`1' == 1
		qui drop run`1'
		local list = "`list'`1'"
		macro shift
	}
	rename run`run' run`list'
end

local new = 0
local range = 0
if "`1'" == "new" {
	local new = 1
}
if "`2'" == "new" {
	local new = 1
}
if "`1'" == "range" {
	local range = 1
}
if "`2'" == "range" {
	local range = 1
}

if `new' {
	cap erase seml_train.dta
}
cap use seml_train, clear
if _rc != 0 {
	cap confirm file meta.dta
	// preparing meta data
	// this is the place where you can aggregate dummies of related runs,
	// in case they have a low representation
	if _rc != 0 {
		import delimited meta.txt, enc("latin1") clear
		sort searched found
		cap foreach v of varlist csf* {
			egen `v'sd = sd(`v'), by(searched)
			replace `v'sd = 0 if `v'sd == .
		}
		cap foreach v of varlist cfs* {
			egen `v'sd = sd(`v'), by(searched)
			replace `v'sd = 0 if `v'sd == .
		}
		local i = 1
		while "${run`i'}" != "" {
			aggregate_run ${run`i'}
			local i = `i'+1
		}
		save meta, replace
	}
	// preparing training data
	local sample : dir "." files "sample*.txt"
	local export : dir "." files "export*.txt"
	local truth : dir "." files "truth*.txt"
	local sample = `"`sample' `export' `truth'"'
	di as result `"`sample'"'
	foreach f in `sample' {
		di as text "importing " as result `"`f'"'
		qui import delimited `"`f'"', enc("latin1") clear
		keep searched found equal identity
		qui gen str source = trim(lower(`"`f'"'))
		drop if searched == .
		cap destring equal, force replace
		cap append using seml_train
		qui save seml_train, replace
	}
	gen long pos = _n
	gen byte truth = substr(source,1,1) == "t" 
	gen byte export = substr(source,1,1) == "e" 
	gen byte sample = substr(source,1,1) == "s"
	sort searched found truth export sample source pos
	replace export = export[_n-1] if export == 0 & searched == searched[_n-1] & found == found[_n-1]
	replace sample = sample[_n-1] if sample == 0 & searched == searched[_n-1] & found == found[_n-1]
	drop if searched == searched[_n+1] & found == found[_n+1] // truth > export > sample
	sort searched pos
	drop pos
	replace found = . if found == 0
	// applying range mode: every equal value in a block is valid until another is encountered
	if `range' {
		replace equal = equal[_n-1] if (equal == 0 | equal == .) & (equal[_n-1] != . | equal[_n-1] != 0) & searched == searched[_n-1]
	}
	// applying the default value for every searched block
	egen byte default = max(equal * (found == .)), by(searched)
	replace equal = default if equal == . | equal == 0
	drop default
	drop if found == .
	gen byte eq = equal
	label var eq "original equal"
	rename identity id
	label var id "original identity"
	// adjusting the equal value from [9,1] to [0,1]
	replace equal = 1 if equal >= 1 & equal <= 5
	replace equal = 9 if equal > 5 & equal <= 9 | equal == 0 | equal == .
	drop if equal != 1 & equal != 9
	replace equal = 0 if equal == 9
	sort searched found
	
	//truth or retention
	count if truth
	if r(N) > 0 {
		di as result "using truth!!!"
		gen byte retention = truth
	}
	else {
		di as result "using retention"
		gen byte retention = uniform() < $retention & sample
	}
	
	// weights
	sum equal
	if r(mean) > 0.5 {
		gen double weight = r(mean)/(1-r(mean)) if equal == 0 & retention == 0
		replace weight = 1 if equal == 1 & retention == 0
	}
	else {
		gen double weight = (1-r(mean)) / r(mean) if equal == 1 & retention == 0
		replace weight = 1 if equal == 0 & retention == 0
	}

	keep $non_meta
	order $non_meta
	
	// merging meta data
	merge 1:1 searched found using meta, keep(match)
	drop if _merge != 3 
	drop _merge
	meta_vars
	
	// removing constants from training data
	foreach v in $meta_vars {
		qui sum `v'
		if r(N) == 0 | r(min) == r(max) {
			di as text "dropping constant " as result "`v'"
			drop `v'
		}
	}

	// data label contains list of meta variables
	save seml_train, replace
}

// identifying meta variables
meta_vars
di as text "Meta: " as result "$meta_vars"

// Probit as reference (can be omitted in case it does not converge)
probit equal $meta_vars if retention == 0 
qui predict equal_probit
qui replace equal_probit = min(max(equal_probit,0),1)
di as result "training"
brain fit equal equal_probit if retention == 0
di as result "retention"
brain fit equal equal_probit if retention == 1

cap program drop train
program define train
	global brain = $brain+1
	di as text "Train " as result "$brain" as text ": " as result "`1'`2'"
	cap drop equal_brain
	qui brain define, input($meta_vars) output(equal) hidden(`1') spread(0.1)
	local eta = 0.5
	local half = 1
	local run = 1
	while `run' <= 50 & `half' <= 10 {
		qui brain train `2' if retention == 0, eta(`eta') batch($batch) iter(100) report(10) best
		local iter = r(iter)
		if `iter' == 0 {
			local eta = `eta'/2
			local half = `half'+1
		}
		else {
			local run = `run'+1
		}
		brain save seml$brain
	}
	di as text "RUN " as result `run'
	di as text "ETA " as result `eta'
	brain error `2' if retention == 0 
	brain think equal_brain
	di as result "training"
	brain fit equal equal_brain if retention == 0
	di as result "retention"
	brain fit equal equal_brain if retention == 1
	if r(accuracy) > $acc {
		global acc = r(accuracy)
		di as result "New Best Accuracy!!!"
		brain save seml
		qui save train, replace
		global best = $brain
	}
end

global best = 0
global brain = 0
global acc = 0

train "25"
train "25" "[pweight=weight]"
train "50"
train "50" "[pweight=weight]"
train "100"
train "100" "[pweight=weight]"
train "25 25"
train "25 25" "[pweight=weight]"
train "50 50"
train "50 50" "[pweight=weight]"
train "100 100"
train "100 100" "[pweight=weight]"

di as text "Best Brain saved in seml.brn: " as result $best

log close
