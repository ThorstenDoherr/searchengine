// seml_train.do
// Trains a neural network based on meta information and a scrutinized training sample
// to identify false positives in SearchEngine results.
// Several network profiles will be trained and the best will be exported to be used in
// the script "seml_think.do".
//
// Requires:
// meta.txt or meta.dta - full meta export of the result
// *sample*.txt - scrutinized samples in ExtendedExport format, i.e. sample1.txt, export_sample.txt 
// brain package for stata available at these sources:
// - https://github.com/ThorstenDoherr/brain
// - https://github.com/ThorstenDoherr/searchengine in the SEML/brain folder
// - ssc install brain
//
// Output:
// seml_train.dta - training data
// seml.brn - neural network file with the best accuracy
// train.dta - prediction for training data of the best network
// seml_train.log - log file
//
// Remarks:
// - equal has to be 1 (match) or 9 (non-match) in samples, exports and truths
// - a value in a block header of the scrutinized data (searched not empty, found empty) is the default value for the block (reduces typing)
// - the default value in the block header is used for all missings and zeroes within a block
// - you can define a global default value in the settings (see Settings below)
// - retention will only be redrawn if seml_train.dta is deleted
// - delete seml_train.dta und meta.dta when meta data has changed
//
// AGGREGATION OF SEARCH RUNS
// The exportmeta function of the SeachEngine has the option to aggregate search runs.
// In case you omitted this option, you can use aggregation macros:
// Search runs with similar setups but only different thresholds can be aggregated.
// Search runs with low number of observations should be aggregated with similar search runs,
// i.e. runs using 3-gram preparer regardless off smoothing.
// You can add the aggregation macros after the "Settings:" (see example).
// Examples (enumerate the macros in ascending order):
// global run1 2 3 4    // to aggregate run 2, 3 and 4
// global run2 6 7 8 9  // to aggregate run 6 to 9
//
// Settings:
// batch - see "help brain" for info about neural netword batch sizes
// retention - share that will not be used for training but for out of sampe prediction
// default - global default when the "equal" in block headers is empty
global batch 8 // mini batch size
global retention 0.1 // 0.1 will retain 10% of the sample for testing
global default 0 // default value for block header equal (1 = true positive, 9 = false positive, 0 = missing) 
// Here would be your first run aggregation macro, i.e. global run1 2 3 4
// The run macros are optional.

clear all
set more off
tempfile train
cap log close
log using seml_train.log, replace

// isolates meta vars
global non_meta = "source searched found weight retention eq id equal"
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

cap use seml_train, clear
if _rc != 0 {
	
	// preparing meta data
	// SD of the string metrics by "searched" are calculated
	// representing the homogenity of a searched block.
	// The log of the block size "cnt" is added, in case the variable is skewed. 
	// This is also the place where you can aggregate dummies of related runs,
	// in case they have a low representation and you missed the export option.
	cap confirm file meta.dta
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
		cap gen float cntln = ln(cnt)
		local i = 1
		while "${run`i'}" != "" {
			aggregate_run ${run`i'}
			local i = `i'+1
		}
		save meta, replace
	}
	
	// preparing training data
	local sample : dir "." files "*sample*.txt"
	di as result `"`sample'"'
	foreach f in `sample' {
		di as text "importing " as result `"`f'"'
		qui import delimited `"`f'"', enc("latin1") clear
		keep searched found equal identity
		qui gen str source = trim(lower(`"`f'"'))
		drop if searched == . | searched == 0
		cap destring equal, force replace
		cap append using `train'
		qui save `train', replace
	}
	
	// removing duplicates in case of multiple sample files with overlap
	gen long pos = _n
	sort searched found source pos
	drop if searched == searched[_n+1] & found == found[_n+1]
	sort searched pos
	drop pos
	replace found = . if found == 0
	
	// applying the default value for every searched block and cleaning
	replace equal = $default if found == . & (equal == . | equal == 0)
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
	
	// retention
	gen byte retention = uniform() < $retention
	
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

// linear probability regression model
reg equal $meta_vars if retention == 0 
qui predict equal_base
qui replace equal_base = min(max(equal_base,0),1)
di as result "training"
brain fit equal equal_base if retention == 0
di as result "retention"
brain fit equal equal_base if retention == 1

cap program drop train
program define train
	global brain = $brain+1
	di as text "Train " as result "$brain" as text ": " as result "`1' `2'"
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
