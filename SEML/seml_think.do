// seml_think.do
// Predicts the false positives in a SearchEngine meta file based on 
// a neural network trained by a sample (see seml_train.do).
//
// Requires:
// meta.txt - full meta export of the result
// seml.brn - neural network generated by seml_train.do
// brain package for stata (https://github.com/ThorstenDoherr/brain)
//
// Output:
// think.dta, think.txt - contains searched, found, predicted equal and brain (raw neural network output)
// seml_think.log - log file
//
// Remarks:
// - equal is 1 (match) or 9 (non-match) in think files
// - brain is the "probability" for a match: [0,1]

clear all
set more off
tempfile meta
cap log close
log using seml_think.log, replace

brain // shows version number and no of CPUs; not required

// import
cap use meta, clear
if _rc != 0 {
	import delimited meta.txt, enc("latin1") clear
	sort searched found
	save meta, replace
}

// load brain and input variable names
brain load seml
global vars : colnames(input)

// thinking
brain think brain
gen byte equal = cond(brain > 0.5,1,9)
keep searched found equal brain
save think, replace
export delimited think.txt, delim(tab) noquote replace
log close
