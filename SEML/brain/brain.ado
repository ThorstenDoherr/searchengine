cap program drop brain
program define brain, rclass
	version 10.0
	local cmd = word(subinstr(`"`1'"',","," ",1),1)
	local cmdlen = length(`"`cmd'"')
	if strpos(lower("`c(os)'"),"mac") {
		local os = "mac"
	}
	else if strpos(lower("`c(os)'"),"win") {
		local os = "win"
	}
	else {
		local os = "unix"
	}
	local plugin = ""
	cap plugin call brainiac  // check plugin
	if "`plugin'" == "" {
		if "`os'" == "win" {
			cap program brainiac, plugin using("brainwin.plugin")
			if _rc != 0 { // fallback in case of non-native compiler
				qui findfile "brainwin.plugin"
				local brainpath = substr(r(fn),1,length(r(fn))-15)
				local workpath = "`c(pwd)'"
				qui cd "`brainpath'"  // required to load dlls
				cap program brainiac, plugin using("`brainpath'brainwin.plugin")
				if _rc != 0 {
					qui cd "`workpath'"
					di as error "non-natively compiled windows plugin detected, e.g. cygwin/mingw"
					di as error "unable to load " as result "brainwin.plugin" as error " from directory " as result "`brainpath'"
					di as error "perhaps additional dlls are required in that directory, e.g.:" _newline as result "brain`os'.plugin" _newline "libgomp-1.dll" _newline "libwinpthread-1.dll" _newline "libgcc_s_seh-1.dll"
					error 999
				}
				qui cd "`workpath'"
			}
		}
		else {
			program brainiac, plugin using("brain`os'.plugin")
		}
		plugin call brainiac
	}
	local version = word("`plugin'",1)
	local procs = word("`plugin'",2)
	if `cmdlen' == 0 {
		di as txt "brain`os'.plugin " as result "`version'"
		di as text "brain uses " as result "`procs'" as txt " processors"
		return local plugin = "brain`os'.plugin"
		return local version = "`version'"
		return scalar mp = `procs'
		di as text "brain matrices:"
		braindir
		braincheck easy
		exit
	}
	if `cmdlen' < 2 {
		di as error "invalid brain command"
		error 999
	}
	if `"`cmd'"' == substr("fit",1,`cmdlen') {
		syntax [anything(id=command)] [if] [in], [SP] [TH(real 0.5)]
		token `"`anything'"'
		macro shift
		local mp = cond("`sp'" == "", "MP", "SP")
		tempvar touse pred
		local wc = wordcount(`"`*'"')
		if `wc' > 2 {
			di as error "too many variables"
			error 999
		}
		if `wc' < 1 {
			di as error "specify at least the original variable"
			error 999
		}
		forvalues i = 1/`wc' {
			confirm var ``i''
		}
		marksample touse
		local true = `"`1'"'
		markout `touse' `true'
		if `wc' == 1 {
			if colsof(output) != 1 {
				di as error "predicted variable can only be omitted for univariate output"
				error 999
			}
			local inames : colnames input
			markout `touse' `inames' 
			qui gen double `pred' = .
			plugin call brainiac `inames' `pred' if `touse', think`mp'
		}
		else {
			local pred = `"`2'"'
		}
		markout `touse' `pred'
		qui sum `true' if `touse'
		if r(N) == 0 {
			di as error "no observations"
			error 999
		}
		if r(min) < 0 | r(max) > 1 {
			di as error "invalid original variable"
			error 999
		}
		qui sum `pred' if `touse'
		if r(N) == 0 {
			di as error "no observations"
			error 999
		}
		if r(min) < 0 | r(max) > 1 {
			di as error "invalid predicted variable"
			error 999
		}
		qui count if `touse'
		local N = r(N)
		qui count if `touse' & `pred' >= `th' & `true' >= `th'
		local TP = r(N)
		qui count if `touse' & `pred' >= `th' & `true' < `th'
		local FP = r(N)
		qui count if `touse' & `pred' < `th' & `true' < `th'
		local TN = r(N)
		qui count if `touse' & `pred' < `th' & `true' >= `th'
		local FN = r(N)
		local Trecall = `TP'/(`TP'+`FN') * 100
		local Frecall = `TN'/(`TN'+`FP') * 100
		local Tprecision = `TP'/(`TP'+`FP') * 100
		local Fprecision = `TN'/(`TN'+`FN') * 100
		local accuracy = (`TP'+`TN')/(`TP'+`TN'+`FP'+`FN') * 100
		local fit = string(`accuracy',"%6.2f")
		local len = 7-length("`fit'")
		di as text "{hline 11}{c TT}{hline 26}
		di as text "Acc " as result "`fit'" as text "{dup `len': }{c |}         True        False"
		di as text "{hline 11}{c +}{hline 26}
		di as text "Positive   {c |} " as result %12.0f `TP' " " %12.0f `FP'
		di as text "Negative   {c |} " as result %12.0f `TN' " " %12.0f `FN'
		di as text "{hline 11}{c +}{hline 26}
		di as text "Recall     {c |} " as result %12.2fc `Trecall' " " %12.2fc `Frecall' 
		di as text "Precision  {c |} " as result %12.2fc `Tprecision' " " %12.2fc `Fprecision' 
		di as text "{hline 11}{c BT}{hline 26}
		return scalar threshold = `th'
		return scalar accuracy = `accuracy'
		return scalar Fprecision = `Fprecision'
		return scalar Tprecision = `Tprecision'
		return scalar Frecall = `Frecall'
		return scalar Trecall = `Trecall'
		return scalar FN = `FN'
		return scalar TN = `TN'
		return scalar FP = `FP'
		return scalar TP = `TP'
		return scalar N = `N'
		exit
	}
	if `"`cmd'"' == substr("define",1,`cmdlen') {
		syntax anything(id=command) [if] [in], INput(varlist) Output(varlist) [Hidden(numlist)] [Spread(real 0.25)] [Raw] [Nonorm]
		token `"`anything'"'
		macro shift
		if `"`1'"' != "" {
			error 198
		}
		local raw = "`raw'" != ""
		local nonorm = "`nonorm'" != ""
		if `raw' & `nonorm' {
			di as error "option raw and nonorm are mutually exclusive"
			error 999
		}
		tempvar touse
		local inp = wordcount(`"`input'"')
		local out = wordcount(`"`output'"')
		local hidden = `"`inp' `hidden' `out'"'
		token `"`hidden'"'
		local layer = ""
		local i = 1
		while "``i''" != "" {
			cap confirm integer number ``i''
			if _rc > 0 {
				di as error "invalid layer number"
				error 999
			}
			if ``i'' <= 0 {
				di as error "invalid layer definition"
				error 999
			}
			local layer = `"`layer',``i''"'
			local i = `i' + 1 
		}
		local layer = "("+substr(`"`layer'"',2,.)+")"
		matrix layer = `layer'
		if wordcount(`"`input'"') != layer[1,1] {
			di as error "invalid number of input variables, " layer[1,1] " required"
			matrix drop layer
			error 999
		}
		if wordcount(`"`output'"') != layer[1,colsof(layer)] {
			di as error "invalid number of output variables, " layer[1,colsof(layer)] " required"
			matrix drop layer
			error 999
		}
		marksample touse
		local cols = layer[1,1]
		if `nonorm' {
			matrix input = J(1, `cols', 0)\J(1, `cols', 1)\J(2, `cols', 0)
		}
		else {
			local v = ""
			mata: _brainnorm("input", "`input'", "`touse'", `raw')
			forvalue i = 1/`cols' {
				if `raw' & (input[1,`i'] != 0 | input[2,`i'] != 1) | `raw' == 0 & (input[1,`i'] == . | input[2,`i'] == .) {
					local v = word("`input'", `i')
					if `raw' {
						di as error "raw input variable `v' is violating the [0,1] range"
					}
					else {
						di as error "input variable `v' is undefined"
					}
				}
			}
			if "`v'" != "" {
				matrix drop layer
				matrix drop input
				error 999
			}
		}
		matrix colnames input = `input'
		matrix rownames input = min norm value signal
		local cols = layer[1,colsof(layer)]
		if `nonorm' {
			matrix output = J(1, `cols', 0)\J(1, `cols', 1)\J(2, `cols', 0)
		}
		else {
			local v = ""
			mata: _brainnorm("output", "`output'", "`touse'", `raw')
			forvalue i = 1/`cols' {
				if `raw' & (output[1,`i'] != 0 | output[2,`i'] != 1) | `raw' == 0 & (output[1,`i'] == . | output[2,`i'] == .) {
					local v = word("`output'", `i')
					if `raw' {
						di as error "raw output variable `v' is violating the [0,1] range"
					}
					else {
						di as error "output variable `v' is undefined"
					}
				}
			}
			if "`v'" != "" {
				matrix drop layer
				matrix drop input
				matrix drop output
				error 999
			}
		}
		matrix colnames output = `output'
		matrix rownames output = min norm value signal
		braincreate `spread'
		di as text "defined matrices:"
		braindir
		exit
	}
	if `"`cmd'"' == substr("reset",1,`cmdlen') {
		syntax anything(id=command) [if] [in], [Spread(real 0.25)]
		token `"`anything'"'
		macro shift
		if `"`1'"' != "" {
			error 198
		}
		braincheck
		braincreate `spread'
		exit
	}
	if `"`cmd'"' == substr("norm",1,`cmdlen') {
		syntax anything(id=command) [if] [in], [Raw]
		token `"`anything'"'
		macro shift
		if `"`1'"' == "" {
			error 198
		}
		local raw = "`raw'" != ""
		local noskip = "`skip'" == ""
		braincheck
		tempvar touse
		tempname chk output input update
		scalar `output' = ""
		scalar `input' = ""
		foreach v of varlist `*' {
			cap matrix `chk' = input[1,"`v'"]
			if _rc != 0 {
				cap matrix `chk' = output[1,"`v'"]
				if _rc == 0 {
					scalar `output' = `output' + " `v'"
				}
			}
			else {
				scalar `input' = `input' + " `v'"
			}
		}
		local output = trim(scalar(`output'))
		local input = trim(scalar(`input'))
		if "`output'" == "" & "`input'" == "" {
			di as error "varlist does not match any input or output variables"
			error 999
		}
		marksample touse
		if "`input'" != "" {
			mata: _brainnorm("`update'", "`input'", "`touse'", `raw')
			local cols = colsof(`update')
			token `"`input'"'
			local v = ""
			forvalue i = 1/`cols' {
				if `raw' & (`update'[1,`i'] != 0 | `update'[2,`i'] != 1) | `raw' == 0 & (`update'[1,`i'] == . | `update'[2,`i'] == .) {
					local v = `"``i''"'
					if `raw' {
						di as error "raw input variable `v' is violating the [0,1] range"
					}
					else {
						di as error "input variable `v' is undefined"
					}
				}
			}
			if "`v'" != "" {
				di as error "original input layer restored"
				error 999
			}
			matrix colnames `update' = `input'
			local names : colnames input
			token `"`names'"'
			local cols = colsof(input)
			forvalue i = 1/`cols' {
				local v = "``i''"
				cap matrix `chk' = `update'[1..2,"`v'"]
				if _rc == 0 {
					matrix input[1,`i'] = `chk'[1,1]
					matrix input[2,`i'] = `chk'[2,1]
				}
			}
		}
		if "`output'" != "" {
			mata: _brainnorm("`update'", "`output'", "`touse'", `raw')
			local cols = colsof(`update')
			token `"`output'"'
			local v = ""
			forvalue i = 1/`cols' {
				if `raw' & (`update'[1,`i'] != 0 | `update'[2,`i'] != 1) | `raw' == 0 & (`update'[1,`i'] == . | `update'[2,`i'] == .) {
					local v = `"``i''"'
					if `raw' {
						di as error "raw output variable `v' is violating the [0,1] range"
					}
					else {
						di as error "output variable `v' is undefined"
					}
				}
			}
			if "`v'" != "" {
				di as error "original output layer restored"
				error 999
			}
			matrix colnames `update' = `output'
			local names : colnames output
			token `"`names'"'
			local cols = colsof(output)
			forvalue i = 1/`cols' {
				local v = "``i''"
				cap matrix `chk' = `update'[1..2,"`v'"]
				if _rc == 0 {
					matrix output[1,`i'] = `chk'[1,1]
					matrix output[2,`i'] = `chk'[2,1]
				}
			}
		}
		exit
	}
	if `"`cmd'"' == substr("save",1,`cmdlen') {
		syntax anything(id=command)
		token `"`anything'"'
		macro shift
		if `"`1'"' == "" {
			di as error "no file specified"
			error 999
		}
		if `"`2'"' != "" {
			error 198
		}
		local using = `"`1'"'
		braincheck
		tempname save
		local layer = colsof(layer)
		local size = colsof(brain)
		local isize = colsof(input)
		local osize = colsof(output)
		local using = subinstr(trim(`"`using'"'),"\","/",.)
		if regex(`"`using'?"',"\.[^/]*\?") == 0 {
			local using = `"`using'.brn"'
		}
		qui file open `save' using `"`using'"', write binary replace
		file write `save' %9s `"braindead"'
		file write `save' %4bu (`layer')
		forvalue i = 1/`layer' {
			file write `save' %4bu (layer[1,`i'])
		}
		local names : colnames input
		local len = length(`"`names'"')
		file write `save' %4bu (`len')
		file write `save' %`len's `"`names'"'
		local isize = layer[1,1]
		forvalue i = 1/`isize' {
			file write `save' %8z (input[1,`i'])
			file write `save' %8z (input[2,`i'])
		}
		local names : colnames output
		local len = length(`"`names'"')
		file write `save' %4bu (`len')
		file write `save' %`len's `"`names'"'
		local osize = layer[1,colsof(layer)]
		forvalue i = 1/`osize' {
			file write `save' %8z (output[1,`i'])
			file write `save' %8z (output[2,`i'])
		}
		forvalue i = 1/`size' {
			file write `save' %8z (brain[1,`i'])
		}
		file close `save'
		exit
	}
	if `"`cmd'"' == substr("load",1,`cmdlen') {
		syntax anything(id=command)
		token `"`anything'"'
		macro shift
		if `"`1'"' == "" {
			di as error "no file specified"
			error 999
		}
		if `"`2'"' != "" {
			error 198
		}
		local using = `"`1'"'
		tempname load bin
		local using = subinstr(trim(`"`using'"'),"\","/",.)
		if regex(`"`using'?"',"\.[^/]*\?") == 0 {
			local using = "`using'.brn"
		}
		file open `load' using `"`using'"', read binary
		file read `load' %9s str
		if `"`str'"' != "braindead" {
			di as error "invalid file format"
			file close `load'
			error 999
		}		
		file read `load' %4bu `bin'
		local layer = `bin'
		matrix layer = J(1,`layer',0)
		forvalue i = 1/`layer' {
			file read `load' %4bu `bin'
			if r(eof) {
				di as error "invalid file format"
				file close `load'
				error 999
			}
			matrix layer[1,`i'] = `bin'
		}
		file read `load' %4bu `bin'
		local len = `bin'
		file read `load' %`len's str
		local layer = layer[1,1]
		mata: _brainload("input", `layer', 4, 2, "`load'", "`bin'")
		matrix colnames input = `str'
		matrix rownames input = min norm value signal
		file read `load' %4bu `bin'
		local len = `bin'
		file read `load' %`len's str
		local layer = layer[1,colsof(layer)]
		mata: _brainload("output", `layer', 4, 2, "`load'", "`bin'")
		matrix colnames output = `str'
		matrix rownames output = min norm value signal
		braincreate `load'
		file read `load' %8z `bin'  // there should be no leftovers
		if r(eof) == 0 {
			di as error "invalid file format"
			file close `load'
			error 999
		}
		file close `load'
		di as text "loaded matrices:"
		braindir
		braincheck
		exit
	}
	if `"`cmd'"' == substr("feed",1,`cmdlen') {
		syntax anything(id=command), [RAW]
		token `"`anything'"'
		macro shift
		local raw = "`raw'" != ""
		tempname output
		local isize = colsof(input)
		local osize = colsof(output)
		local ostart = colsof(neuron)-`osize'+1
		local wc = wordcount(`"`*'"')
		if `wc' != `isize' {
			di as error "number of values does not match input neurons (`wc' <> `isize')"
			error 999
		}
		foreach v in `*' {
			cap confirm number `v'
			if _rc != 0 {
				di as error "invalid value: `v'"
				error 999
			}
		}
		mata: _brainfeed(`"`*'"', `raw')
		plugin call brainiac, forward `raw'
		matrix `output' = output[3..4,1...]
		matrix list `output', noheader format(%18.9f)
		return matrix output = `output'
		exit
	}
	if `"`cmd'"' == substr("signal",1,`cmdlen') {
		syntax anything(id=command), [RAW]
		token `"`anything'"'
		macro shift
		if "`1'" != "" {
			error 198
		}
		local raw = "`raw'" != ""
		tempname signal
		local isize = colsof(input)
		local osize = colsof(output)
		local nsize = colsof(neuron)
		local ostart = `nsize'-`osize'+1
		local raw = 3+`raw' // 3 = value, 4 = signal
		local inames : colnames input
		local onames : colnames output
		matrix `signal' = J(`isize'+1, `osize', 0)
		matrix colnames `signal' = `onames'
		matrix rownames `signal' = `inames' flatline
		matrix input[4,1] = J(1,`isize', 0)
		plugin call brainiac, forward 1
		matrix `signal'[`isize'+1,1] = output[`raw',1...]
		forvalue i = 1/`isize' {
			matrix input[4,1] = J(1,`isize', 0)
			matrix input[4,`i'] = 1
			plugin call brainiac, forward 1
			matrix `signal'[`i',1] = output[`raw',1]-`signal'[`isize'+1,1]
		}
		matrix list `signal', noheader format(%18.9f)
		return matrix signal = `signal'
		exit
	}
	if `"`cmd'"' == substr("margin",1,`cmdlen') {
		syntax anything(id=command) [pweight fweight aweight iweight/] [if] [in], [SP]
		token `"`anything'"'
		macro shift
		local mp = cond("`sp'" == "", "MP", "SP")
		tempname signal sn bn cn
		tempvar delta touse w
		local inames : colnames input
		local onames : colnames output
		local mnames = "`inames'"
		local osize = colsof(output)
		local isize = colsof(input)
		local msize = `isize'
		if `"`*'"' != "" {
			local mnames = ""
			local msize = 0
			foreach v of varlist `*' {
				if index(" `inames' ", " `v' ") == 0 {
					di as error "invalid input variable `v'"
					error 999
				}
				if index(" `mnames' "," `v' ") > 0 {
					di as error "input variable `v' already defined"
					error 999
				}
				local mnames = "`mnames' `v'"
				local msize = `msize'+1
			}
		}
		marksample touse    
		markout `touse' `inames' `onames'
		brainweight `w' `touse' `exp'
		scalar `sn' = ""		
		scalar `bn' = ""
		forvalue o = 1/`osize' {
			tempvar signal`o' base`o'
			qui gen double `signal`o'' = .
			qui gen double `base`o'' = .
			scalar `sn' = `sn' + " `signal`o''"
			scalar `bn' = `bn' + " `base`o''"
		}
		local snames = scalar(`sn')
		scalar drop `sn'
		local bnames = scalar(`bn')
		scalar drop `bn'
		qui gen double `delta' = .
		mata: st_matrix("`signal'", J(`msize',`osize', 0))
		matrix rownames `signal' = `mnames'
		scalar `cn' = ""
		forvalue o = 1/`osize' {
			local oname = word("`onames'", `o')
			scalar `cn' = `cn' + " `oname'"
		}
		local cnames = scalar(`cn')
		scalar drop `cn'
		matrix colnames `signal' = `cnames'
		di as text "unrestricted " _continue
		plugin call brainiac `inames' `bnames' if `touse', think`mp'
		local ind = 0
		foreach v of varlist `mnames' {
			forvalue i = 1/`isize' {
				local iname = word("`inames'", `i')
				if "`v'" == "`iname'" {
					di as result "`iname' " _continue
					plugin call brainiac `inames' `snames' if `touse', think`mp' `i'
					local ind = `ind' + 1
					forvalue o = 1/`osize' {
						local oname = word("`onames'", `o')
						qui replace `delta' = `base`o''-`signal`o'' if `touse'
						qui sum `delta' [aweight=`w'] if `touse'
						matrix `signal'[`ind',`o'] = r(mean)
					}
					continue, break
				}
			}
		}
		di ""
		matrix list `signal', noheader format(%18.9f)
		return matrix margin = `signal'
		exit
	}
	if `"`cmd'"' == substr("think",1,`cmdlen') {
		syntax anything(id=command) [if] [in], [SP]
		token `"`anything'"'
		macro shift
		local mp = cond("`sp'" == "", "MP", "SP")
		tempvar touse
		local wc = wordcount(`"`*'"')
		local osize = colsof(output)
		if `wc' != `osize' {
			di as error "number of target variables does not match output neurons (`wc' <> `osize')"
			error 999
		}
		foreach v in `*' {
			cap drop `v'
			qui gen double `v' = .
		}
		marksample touse    
		local inames : colnames input
		markout `touse' `inames' 
		plugin call brainiac `inames' `*' if `touse', think`mp'
		return scalar N = `plugin'
		exit
	}
	if `"`cmd'"' == substr("error",1,`cmdlen') {
		syntax anything(id=command) [pweight fweight aweight iweight/] [if] [in], [SP]
		token `"`anything'"'
		macro shift
		if "`1'" != "" {
			error 198
		}
		local mp = cond("`sp'" == "", "MP", "SP")
		tempvar touse w
		marksample touse    
		local inames : colnames input
		local onames : colnames output
		markout `touse' `inames' `onames'
		brainweight `w' `touse' `exp'
		plugin call brainiac `inames' `onames' `w' if `touse', error`mp'
		local err = word("`plugin'", 1)
		local N = word("`plugin'", 2)
		di as text "Number of obs = " as result %12.0fc `N'
		di as text "Error         = " as result %12.9f `err'
		return scalar N = `N'
		return scalar err = `err'
		exit
	}
	if `"`cmd'"' == substr("train",1,`cmdlen') {
		syntax anything(id=command) [pweight fweight aweight iweight/] [if] [in], [ITer(integer 0)] [Eta(real 0.25)] [BAtch(integer 1)] [Report(integer 10)] [BEst] [SP] [Noshuffle]
		token `"`anything'"'
		macro shift
		if "`1'" != "" {
			error 198
		}
		local mp = cond("`sp'" == "", "MP", "SP")
		local shuffle = "`noshuffle'" == ""
		local best = "`best'" != ""
		tempvar touse w
		tempname bestbrain
		if `eta' <= 0 {
			di as error "eta has to be a number larger than zero"
			error 999
		}
		if `iter' <= 0 {
			di as error "number of iterations has to be larger than zero"
			error 999
		}
		if `batch' < 1 {
			di as error "batch size has to be larger than zero"
			error 999
		}
		local mptrain = "`mp'"
		if `batch' <= 1 {
			local mptrain = "SP"  // multiprocessing only works with mini-batches
		}
		marksample touse    
		local inames : colnames input
		local onames : colnames output
		markout `touse' `inames' `onames'
		brainweight `w' `touse' `exp'
		qui count if `touse'
		local N = r(N)
		local err = 0
		local prev = .
		di as text "{hline 40}" 
		di as text "Brain{dup 7: }Number of obs = " as result %12.0fc `N'
		di as text "Train{dup 17: }eta = " as result %12.6f `eta'
		di as text "{hline 10}{c TT}{hline 14}{c TT}{hline 14}"
		di as text "Iteration {c |}        Error {c |}        Delta"
		di as text "{hline 10}{c +}{hline 14}{c +}{hline 14}"
		local miniter = 0
		if `best' {
			plugin call brainiac `inames' `onames' `w' if `touse', error`mp'
			local minerr = word("`plugin'",1)
			matrix `bestbrain' = brain
			di as result %9.0f 0 as text " {c |} " as result %12.9f `minerr' as text " {c |} " as result %12.9f .
			local prev = `minerr'
		}
		else {
			local minerr = -1
		}
		local i = 0
		while `i' < `iter' {
			local epoch = cond(`i'+`report' <= `iter',`report',`iter'-`i') 
			plugin call brainiac `inames' `onames' `w' if `touse', train`mptrain' `eta' `batch' `epoch' `shuffle'
			plugin call brainiac `inames' `onames' `w' if `touse', error`mp'
			local err = word("`plugin'",1)
			local delta = `err'-`prev'
			local prev = `err'
			local i = `i'+`epoch'
			di as result %9.0f `i' as text " {c |} " as result %12.9f `err' as text " {c |} " as result %12.9f `delta'
			if `err' < `minerr' {
				matrix `bestbrain' = brain
				local miniter = `i'
				local minerr = `err'
			}
		}
		if `best' & `err' >= `minerr' {
			matrix brain = `bestbrain'
			local delta = `minerr'-`prev'
			local err = `minerr'
			local iter = `miniter'
		}
		di as text "{hline 10}{c +}{hline 14}{c +}{hline 14}"
		di as result %9.0f `iter' as text " {c |} " as result %12.9f `err' as text " {c |} " as result %12.9f `delta'
		di as text "{hline 10}{c BT}{hline 14}{c BT}{hline 14}"
		return scalar N = `N'
		return scalar iter = `iter'
		return scalar err = `err'
		exit
	}
	di as error "invalid brain command"
	error 999
end

cap program drop braindir
program define braindir
	cap local rows = rowsof(input)
	if _rc == 0 {
		di as result " input[" `rows' ","  colsof(input) "]"
	}
	cap local rows = rowsof(output)
	if _rc == 0 {
		di as result "output[" `rows' ","  colsof(output) "]"
	}
	cap local rows = rowsof(neuron)
	if _rc == 0 {
		di as result "neuron[" `rows' ","  colsof(neuron) "]"
	}
	cap local rows = rowsof(layer)
	if _rc == 0 {
		di as result " layer[" `rows' ","  colsof(layer) "]"
	}
	cap local rows = rowsof(brain)
	if _rc == 0 {
		di as result " brain[" `rows' ","  colsof(brain) "]"
	}
end

cap program drop braincheck
program define braincheck
	local ok = 0
	foreach m in input output layer neuron brain {
		cap local rows = rowsof(`m')
		if _rc == 0 {
			local ok = `ok'+1
		}
	}
	if `ok' == 0 {
		if "`1'" != "" {
			di as text "no brain detected"
			exit 0
		}
		di as error "no brain detected"
		exit 999
	}
	if `ok' > 0 & `ok' < 5 {
		di as error "inomplete brain detected"
		exit 999
	}
	if rowsof(input) != 4 {
		di as error "invalid input matrix"
		exit 999
	}
	if rowsof(output) != 4 {
		di as error "invalid output matrix"
		exit 999
	}
	if rowsof(layer) != 1 {
		di as error "invalid layer matrix"
		exit 999
	}
	if rowsof(neuron) != 1 {
		di as error "invalid neuron matrix"
		exit 999
	}
	if rowsof(brain) != 1 {
		di as error "invalid brain matrix"
		exit 999
	}
	if colsof(input) != layer[1,1] {
		di as error "input and layer matrices are incompatible"
		exit 999
	}
	if colsof(output) != layer[1,colsof(layer)] {
		di as error "output and layer matrices are incompatible"
		exit 999
	}
	local size = 0
	local nsize = colsof(input)
	local layer = colsof(layer)
	forvalue l = 2/`layer' {
		local neurons = layer[1,`l']
		local weights = layer[1,`l'-1]
		local nsize = `nsize' + `neurons'
		local size = `size' + `neurons' * (`weights'+1)
	}
	if colsof(neuron) != `nsize' {
		di as error "neuron and layer matrices are incompatible"
		exit 999
	}
	if colsof(brain) != `size' {
		di as error "brain and layer matrices are incompatible"
		exit 999
	}
	exit 0
end

cap program drop braincreate
program define braincreate
	tempname names binary
	local handle = "`1'"
	local size = 0
	local layer = colsof(layer)
	scalar `names' = ""
	forvalue l = 2/`layer' {
		local p = `l'-1
		local neurons = layer[1,`l']
		local weights = layer[1,`p']
		local size = `size' + `neurons' * (`weights'+1)
		if `l' < `layer' {
			local prefix = "h`p'n"
		}
		else {
			local prefix = "o"
		}
		forvalue n = 1/`neurons' {
			forvalue w = 1/`weights' {
				scalar `names' = `names' + " `prefix'`n'w`w'"
			}
			scalar `names' = `names' + " `prefix'`n'b"
		}
	}
	if "`handle'" != "" {
		if real("`handle'") == . {
			mata: _brainload("brain", `size', 1, 1, "`handle'", "`binary'")
		}
		else {
			mata: _braininit(`size', `handle')
		}
	}
	else {
		mata: st_matrix("brain", J(1,`size',0))
	}
	local cnames = scalar(`names')
	scalar `names' = ""
	matrix colnames brain = `cnames'
	matrix rownames brain = weight
	local cnames = "in"
	local layer = `layer'-2
	forvalue l = 1/`layer' {
		local cnames = "`cnames' hid`l'"
	}
	local cnames = "`cnames' out"
	matrix colnames layer = `cnames'
	matrix rownames layer = neurons
	local layer = colsof(layer)
	local cnames = ""
	local size = 0
	forvalue i = 1/`layer' {
		local neurons = layer[1,`i']
		local size = `size'+`neurons'
		if `i' == 1 {
			local prefix = "in"
		}
		else if `i' == `layer' {
			local prefix = "out"
		}
		else {
			local j = `i'-1
			local prefix = "h`j'n"
		}
		forvalue j = 1/`neurons' {
			scalar `names' = `names' + " `prefix'`j'"
		}
	}
	local cnames = scalar(`names')
	scalar drop `names'
	mata: st_matrix("neuron", J(1,`size',0))
	matrix colnames neuron = `cnames'
	matrix rownames neuron = signal
end	

cap program drop brainweight
program define brainweight
	local w = "`1'"
	local touse = "`2'"
	local exp = "`3'"
	if `"`exp'"' == "" {
		qui gen double `w' = 1
	}
	else {
		qui gen `w' = `exp' if `touse'
		qui sum `w'
		if r(min) < 0 {
			di as error "negative weights encountered"
			error 999
		}
		qui replace `w' = `w'/r(max)
	}
end

mata:

void _brainload(string scalar name, real scalar cols, real scalar rows, real scalar userows, string scalar handle, string scalar bin)
{	real matrix brain
	real scalar i, j, val
	
	brain = J(rows, cols, 0)
	for (i = 1; i <= cols; i++)
	{	for (j = 1; j <= userows; j++)
		{	stata("file read "+handle+" %8z "+bin)
			brain[j,i] = st_numscalar(bin)
		}
	}
	st_matrix(name, brain)
}

void _braininit(real scalar size, real scalar spread)
{	real matrix brain
	real scalar range
	
	spread = abs(spread)
	range = spread*2
	brain = runiform(1, size) :* range :- spread
	st_matrix("brain", brain)
}

void _brainnorm(string scalar name, string scalar vars, string scalar touse, real scalar raw)
{	real matrix N, D
	real rowvector min, max
	real scalar cols
	
	cols = cols(tokens(vars))
	st_view(D=., ., vars, touse)
	N = J(4,cols,0)
	min = colmin(D)
	max = colmax(D)
	if (raw > 0)
	{	N[1,.] = min :< 0 
		N[2,.] = max :<= 1
	}
	else {
		N[1,.] = min
		N[2,.] = 1 :/ (max :- min)
	}
	st_matrix(name, N)
}

void _brainfeed(string scalar values, real scalar raw)
{	real matrix I
	
	I = st_matrix("input")
	if (raw > 0)
	{	I[4,.] = strtoreal(tokens(values))
	}
	else
	{	I[3,.] = strtoreal(tokens(values))
	}
	st_matrix("input", I)
}

end
