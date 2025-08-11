/*
do seml.do
Trains a neural network based on meta information and scrutinized training samples to identify false positives in 
SearchEngine results. Several network profiles will be trained and the best in regard of the retained sub-sample 
will be used to predict false positives in the meta data. The retention represents the out-of-sample prediction to
prevent overfitting. 

Requirements:
The script will need the brain package for STATA. It can be downloaded from the ssc repository with:
ssc install brain
The most recent version of the brain module can also be found in the brain sub-directory of the SEML folder of the
SearchEngine GitHub package. Copy its contents into the current working directory or into the external STATA ado folder.

Input:
meta.txt - full meta data export of the SearchEngine result table.
*sample*.txt - scrutinized samples in ExtendedExport format, i.e. sample1.txt, export_sample.txt
               Multiple sample files matching the template *sample*.txt will be merged.
			   If there is no sample file, the skript will only conduct the prediction based on an already trained
			   network in seml.brn.
			   
All txt files have to be tab-delimited.

Output:
meta.dta - a copy of the meta data complemented by additional columns based on the raw meta data.
sample.dta - assigns the essential "equal" variable to every candidate based on the sample files and default setting.
training.dta - training data: canidate assignment (searched, found, equal), retention indicator, and the meta data.
seml.brn.log - training output of the confusion matrices if applicable.
seml.brn - neural network save file using the brain format.
seml.dta - prediction file (contains reference to sample data if applicable).
seml.txt - tab delimited prediction file for your convenience.

Labeling:
- Read the manual about efficient labeling.
- The "equal" variable has to be 1 (match) or 9 (non-match) in sample files (zeroes are considered missings).
- The data is separated into candidate blocks consisting of a header with the search term followed by candidates.
- A value in a candidate block header defines the default value for the block (reduces typing).
- The default value in the canidate block header is used for all missings and zeroes within a block.
- You can define a global default value for the candidate block header in the settings (see below). 

Script schedule:
If the file seml.brn does not exists, the script will start with the training based on the meta and the sample data.
If the seml.brn file is created or already existing, it will commence with the prediction.
It will always try to use the dta files first but will compile them from the txt files if necessary.
To retrain the network with different settings: delete the seml.brn file.
To retrain the network with different retention: additionally delete the training.dta file
To retrain the network after changes to the sample file(s): additionally delete the sample.dta file.
To retrain the network after changes to meta.txt: additionally delete the meta.dta file.

Settings:
default - global default if "equal" assignment in the candidate block header is missing:
          0 = keep missing (default), 1 = true positive, 9 = false positive
conflict - preference in case of conflicting "equal" assignments in multiple sample files:
           0 = keep first occurrence based on file order (default), 1 = true positive, 9 = false positive
retention - share that will not be used for training but for out-of-sample prediction (default 0.1)
verbose - 0 = mute (default), 1 = show blocked iterations, 2 = show all iterations
hidden - list of neural network hidden layer layouts competing for best out-of-sample accuracy:
         "[0] [25] [50] [100] [25,25] [50,50] [100,100]"
balance - balancing of true and false positives in case of heavily skewed distributions:
         0 = keep original distribution (default), 1 = balancing of true and false positives
epochs - maximum number of training iterations (will not be exhausted in case of plateau, default 5000)
eta - initial learining rate (default 0.1)
batch - batch size for training (larger than 1 will activate MP on Windows, default 8)
*/
global default = 0 // default for equal: 0 = keep missing, 1 = missing is true positive, 9 = missing is false positive
global conflict = 0 // multiple samples conflict preference: 9 = false pos., 1 = true pos., 0 = keep first occurrence  
global retention = 0.1 // 0.1 will retain 10% of the training data for out-of-sample simulation
global verbose = 0 // 0 = silent, 1 = noisy, 2 = loud
global hidden = "[0] [25] [50] [100] [25,25] [50,50] [100,100]" // remove layouts when in a hurry
global balanced = 0 // 1 to balance false & true positives, 0 to keep distribution of true/false positives
global epochs = 5000 // maximum number of iterations (will not be exhausted in case of plateau)
global eta = 0.1 // initial learning rate 
global batch = 8 // mini batch size (larger than 1 will activate MP on Windows)

clear all
set more off

cap program drop prepare_sample
program define prepare_sample
	tempfile sample
	di as text "checking " as result "sample.dta"
	cap confirm file sample.dta	
	if _rc != 0 {
		di as text "reading *sample*.txt template"
		local samples : dir "." files "*sample*.txt"
		foreach f in `samples' {
			load_a_sample `"`f'"'
			cap append using `sample'
			qui save `sample', replace
		}
		qui gen long pos = _n
		sort searched found equal
		qui count if searched == searched[_n-1] & found == found[_n-1]
		di as text "overlap " as result r(N)
		qui count if searched == searched[_n-1] & found == found[_n-1] & equal != equal[_n-1]
		if r(N) > 0 {
			di as text "conflicts " as result r(N)
			if $conflict == 1 {
				di as text "preference " as result "true" as text " positive"
				qui drop if searched == searched[_n+1] & found == found[_n+1]
			}
			else if $conflict == 9 {
				di as text "preference " as result "false" as text " positive"
				qui drop if searched == searched[_n-1] & found == found[_n-1]
			}
			else {
				di "preference file order"
				sort searched found pos
				qui drop if searched == searched[_n-1] & found == found[_n-1]
			}
		}
		else {
			di "no conflicts"
			qui drop if searched == searched[_n-1] & found == found[_n-1]
		}
		drop pos
		di as text "saving " as result "sample.dta"
		qui save sample, replace
		clear
	}
	qui des using sample
	di as text "rows " as result r(N) as text ", cols " as result r(k)
end

cap program drop load_a_sample
program define load_a_sample
	di as text "importing " as result `"`1'"'
	qui import delimited `"`1'"', enc("latin1") varnames(1) clear
	keep searched found equal
	qui drop if searched == . | searched == 0
	cap destring equal, force replace
	qui replace found = 0 if found == .
	qui gen long pos = _n
	sort searched found pos
	qui count if searched == searched[_n+1] & found == found[_n+1]
	if r(N) > 0 {
		di as text "dropping duplicates " as result r(N)
	}
	qui drop if searched == searched[_n+1] & found == found[_n+1]
	sort searched pos
	drop pos
	qui replace found = . if found == 0
	// implementing block and global defaults
	qui replace equal = $default if found == . & (equal == . | equal == 0)
	qui egen byte default = max(equal * (found == .)), by(searched)
	qui replace equal = default if equal == . | equal == 0
	drop default
	qui drop if found == .
	qui replace equal = 1 if equal >= 1 & equal <= 5
	qui replace equal = 9 if equal > 5 & equal <= 9
	qui drop if equal != 1 & equal != 9
	qui replace equal = 0 if equal == 9
end

cap program drop prepare_meta
program define prepare_meta
	di as text "checking " as result "meta.dta"
	cap confirm file meta.dta
	if _rc != 0 {
		di as text "importing " as result "meta.txt"
		qui import delimited meta.txt, enc("latin1") varnames(1) clear
		sort searched found
		cap foreach v of varlist csf* {
			egen `v'sd = sd(`v'), by(searched)
			qui replace `v'sd = 0 if `v'sd == .
		}
		cap foreach v of varlist cfs* {
			egen `v'sd = sd(`v'), by(searched)
			qui replace `v'sd = 0 if `v'sd == .
		}
		cap gen float cntln = ln(cnt)
		di as text "saving " as result "meta.dta"
		qui save meta, replace
		clear
	}
	qui des using meta
	di as text "rows " as result r(N) as text ", cols " as result r(k)
end

cap program drop compose_training
program define compose_training
	tempname frame
	di as text "checking " as result "training.dta"
	cap use training, clear
	if _rc != 0 {
		prepare_sample
		prepare_meta
		qui use sample, clear
		qui gen byte retention = uniform() <= $retention
		order searched found retention equal
		qui merge n:1 searched found using meta, keep(master match)
		qui count if _merge == 1
		if r(N) > 0 {
			di in red "sample records not found in meta: " as result r(N)
			error 999
		}
		drop _merge
		qui des, fullnames varlist
		if regexm(r(varlist),".+ equal[ ]+(.+)") {
			local meta = regexs(1)
		}
		local drop = ""
		foreach v of varlist `meta' {
			qui sum `v' if retention
			if r(max) == r(min) {
				local drop = "`drop' `v'"
			}
		}
		local drop = trim("`drop'")
		if "`drop'" != "" {
			drop `drop'
			di as text "columns without variation in training data:"
			di as result "`drop'"
		}
		di as text "saving " as result "training.dta"
		qui save training, replace
 	}
	qui des
	di as text "rows " as result r(N) as text ", cols " as result r(k)
	di as text "training and retention" _continue
	frame put retention equal, into(`frame')
	frame `frame': qui replace equal = 9 if equal == 0
	frame `frame': tab equal retention
	frame drop `frame'
end

cap program drop training
program define training
	tempfile brain
	qui des, fullnames varlist
	if regexm(r(varlist),".+ equal[ ]+(.+)") {
		local meta = regexs(1)
	}
	if "`meta'" == "" {
		di as error `"no meta variables defined after "equal""'
		error 999
	}
	local weight = ""
	local balanced = ""
	if $balanced {
		qui sum equal if retention == 0
		if r(mean) > 0.5 {
			qui gen double weight = r(mean)/(1-r(mean)) if equal == 0 & retention == 0
			qui replace weight = 1 if equal == 1 & retention == 0
		}
		else {
			qui gen double weight = (1-r(mean)) / r(mean) if equal == 1 & retention == 0
			qui replace weight = 1 if equal == 0 & retention == 0
		}
		local weight = " [pweight=weight]"
		local balanced = ", balanced"
	}
	local hidden = subinstr("$hidden"," ","",.)
	local hidden = subinstr(subinstr("`hidden'","],[","][",.),"]["," ",.)
	local hidden = subinstr(subinstr("`hidden'","[","",.),"]","",.)
	local model = 0
	local best_acc = 0
	local best_model = 0
	local best_layout = ""
	cap log close training
	qui log using seml.brn.log, name(training) text nomsg replace
	log off training
	foreach layers in `hidden' {
		if "`layers'" == "0" {
			local layers = ""
		}
		local model = `model'+1
		local layout = wordcount("`meta'")
		local layout = "`layout' `layers' 1"
		local layout = subinstr(subinstr(subinstr("`layout'","  "," ",.)," ","x",.),",","x",.)
		log on training
		di as text "model " as result `model' as text ": " as result "`layout', batch $batch`balanced'"
		log off training
		qui brain define if retention == 0, input(`meta') output(equal) hidden(`layers') spread(0.01)
		local eta = $eta
		local stop = `eta'/(2^5)
		local run = 1
		local best = 0
		local sp = ""
		local qui = "qui"
		if "`layers'" == "" {
			local sp = "sp"
		}
		if $verbose == 2 {
			local qui = ""
		}
		while `eta' >= `stop' & `run' <= $epochs {
			if $verbose {
				local epoch = `run'-1+100
				local epoch = "`run'-`epoch'"
				di as text "epoch " as result "`epoch'" as text ", eta " as result `eta' as text ": " _continue
			}
			`qui' brain train`weight' if retention == 0, eta(`eta') iter(100) report(10) batch($batch) best `sp'
			if r(iter) == 0 {
				local eta = `eta'/2
			}
			else {
				local best = `run'-1+r(iter)
			}
			if $verbose {
				di as text "loss " as result r(err) as text ", best " as result `best'
			}
			local run = `run' + 100
		}
		log on training
		brain fit equal if retention, `sp'
		local acc = r(accuracy)
		log off training
		if `acc' > `best_acc' {
			local best_acc = `acc'
			local best_model = `model'
			local best_layout = "`layout'"
			brain save `brain'
		}
	}
	qui brain load `brain'
	log on training
	di as text "best model " as result `best_model' as text ": " as result "`best_layout', batch $batch`balanced'"
	brain fit equal if retention
	log close training
	di as text "saving " as result "seml.brn"
	brain save seml.brn
end

cap program drop prediction
program define prediction
	prepare_meta
	qui use meta, clear
	di as text "predicting..."
	qui brain think brain
	keep searched found brain
	qui gen byte _equal = cond(brain > 0.5,1,9)
	cap merge 1:1 searched found using sample, keep(master match) update replace
	if _rc == 0 {
		di as text "attaching " as result "sample.dta" _continue
		drop _merge
		qui replace equal = 9 if equal == 0
		rename equal sample
		rename _equal equal
		tab equal sample
	}
	cap rename _equal equal
	order searched found brain equal
	format brain %8.6f
	di as text "saving " as result "seml.dta" as text " and " as result "seml.txt"
	qui save seml, replace
	qui export delimited seml.txt, delim(tab) noquote datafmt replace
end

cap program drop main
program define main
	cap brain load seml.brn
	if _rc != 0 {
		di as result "TRAINING"
		compose_training
		training
	}
	di as result "PREDICTION"
	prediction
	display as result "done."
	qui // STATA may have a problem with "display" as last command in sub-programs
end

main
