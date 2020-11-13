// seml_train.do [new]
// Trains a neural network based on meta information and a scrutinized training sample
// to identify false positives in SearchEngine results.
//
// Parameter:
// new - recreates training data, e.g. to change retention, otherwise an existing train file will be used
//
// Requires:
// meta.txt or meta.dta - full meta export of the result
// sample.txt - scrutinized sample in ExtendedExport format (equal == 1 : valid match, equal == 9|0: false match)
// brain package for stata (https://github.com/ThorstenDoherr/brain)
//
// Output:
// seml_train.dta - training data
// seml.brn - neural network file
// train.dta, train.txt - prediction for training data
// seml_train.log - log file
//
// Remarks:
// - equal has to be 1 (match) or 9 (non-match) in sample.txt
// - a value in a block header of sample.txt (searched not empty, found empty) is the default value for the block (reduces typing)
// - retention == 1 will be excluded from the training only if $retention > 0
// - you can retrain the network without retention if there is no significant overfitting
// - retention will only be redrawn if the "new" parameter is specified
// - weights can be applied in case of lopsided distribution of the equal variable
//
// Settings:
global layer "50 50" // two hidden layers: inp 50 50 out
global batch 8 // mini batch size
global weight "yes" // "yes" activates weighted training
global retention 0.1 // 0.1 will retain 10% of the sample for testing
global useretention "yes" // activate retention

clear all
set more off
tempfile meta sample
cap log close
log using seml_train.log, replace

forvalue i = 1/1 { // suppresses command output
	di as text "layer:        " as result "$layer"
	di as text "batch:        " as result "$batch"
	di as text "weight:       " as result "$weight"
	di as text "retention:    " as result "$retention"
	di as text "useretention: " as result "$useretention"
}

if "`1'" == "new" {
	cap erase seml_train.dta
}
cap use seml_train, clear
if _rc != 0 {
	cap confirm file meta.dta
	if _rc != 0 {
		import delimited meta.txt, enc("latin1") clear
		sort searched found
		save meta, replace
	}
	import delimited sample.txt, enc("latin1") clear
	keep searched found equal identity
	drop if searched == .
	cap destring equal, force replace
	replace found = . if found == 0
	egen byte default = max(equal * (found == .)), by(searched)
	replace equal = default if equal == . | equal == 0
	drop default
	drop if found == .
	gen byte eq = equal
	label var eq "original equal"
	rename identity id
	label var id "original identity"
	replace equal = 1 if equal >= 1 & equal <= 5
	replace equal = 9 if equal > 5 & equal <= 9 | equal == 0 | equal == .
	drop if equal != 1 & equal != 9
	replace equal = 0 if equal == 9
	sort searched found
	merge 1:1 searched found using meta, keep(match)
	drop if _merge != 3 
	drop _merge
	
	// weights
	sum equal
	if r(mean) > 0.5 {
		gen double weight = r(mean)/(1-r(mean)) if equal == 0
		replace weight = 1 if equal == 1
	}
	else {
		gen double weight = (1-r(mean)) / r(mean) if equal == 1
		replace weight = 1 if equal == 0
	}

	// retention
	gen byte retention = uniform() < $retention
	
	// identifying meta variables
	order searched found weight retention eq id equal
	gen byte end = .
	qui des equal-end, varlist
	global vars = r(varlist)
	global vars = subinstr("[$vars","[equal "," ",1)
	global vars = subinstr("$vars]"," end]"," ",1)
	drop end
	
	// removing constants
	foreach v of varlist $vars {
		qui sum `v'
		if r(N) == 0 | r(min) == r(max) {
			qui drop `v'
			di as error "dropping " as result "`v'"
			continue
		}
	}	

	save seml_train, replace
	
}

if "$weight" == "yes" {
	global weight = "[pweight=weight]"
	tab weight equal
}
else {
	global weight = ""
}
if "$useretention" == "yes" {
	tab retention
}

// identifying meta variables
gen byte end = .
qui des equal-end, varlist
global vars = r(varlist)
global vars = subinstr("[$vars","[equal "," ",1)
global vars = subinstr("$vars]"," end]"," ",1)
drop end

// simple probit prediction
// demonstrates superiority of brain
// delete this part in case probit does not converge
cap drop equal_*
if "$useretention" == "yes" {
	probit equal $vars if retention == 0
}
else {
	probit equal $vars
}

predict equal_probit
replace equal_probit = min(max(equal_probit,0),1)
if "$useretention" == "yes" {
	di as result "training"
	brain fit equal equal_probit if retention == 0
	di as result "retention"
	brain fit equal equal_probit if retention == 1
}
else {
	brain fit equal equal_probit
}

brain // shows version number and no of CPUs; not required
brain define, input($vars) output(equal) hidden($layer) spread(0.1)
brain error // just shows the error of the untrained network

local eta = 0.5
local half = 1
local run = 1
while `run' <= 50 & `half' <= 10 {
	di as text "RUN " as result `run'
	if "$useretention" == "yes" {
		brain train $weight if retention == 0, eta(`eta') batch($batch) iter(100) report(10) best
	}
	else {
		brain train $weight, eta(`eta') batch($batch) iter(100) report(10) best
	}
	local iter = r(iter)
	brain think equal_brain
	if "$useretention" == "yes" {
		di as result "training"
		brain fit equal equal_brain if retention == 0
		di as result "retention"
		brain fit equal equal_brain if retention == 1
	}
	else {
		brain fit equal equal_brain 
	}	
	if `iter' == 0 {
		local eta = `eta'/2
		local half = `half'+1
	}
	else {
		local run = `run'+1
	}
	brain save seml
}
use seml_train, clear
brain think brain
keep searched found eq equal brain
save train, replace
export delimited train.txt, delim(tab) noquote replace
log close
