*=========================================================================*
*   Modul:      custom.prg
*   Date:       2019.10.14
*   Author:     Thorsten Doherr
*   Required:   none
*   Function:   A colorful mix of base classes
*=========================================================================*
define class ParallelFoxWrapper as Custom
	hidden wc, messenger, parallel
	parallel = .f.
	messenger = .f.
	wc = -1
	canceled = .f.
	 
	function init(parallel as Object)
		if vartype(m.parallel) == "O"
			this.parallel = m.parallel
			this.setWorkerCount(1)
			this.wc = 1
			return
		endif
		try
			this.parallel = NewObject("Parallel", "ParallelFox.vcx")
			this.setWorkerCount(1)
			this.wc = 1
		catch
			this.parallel = .f.
			this.wc = -1
		endtry
	endfunc
	
	function progressEvent(rc)
		this.messenger.incProgress()
		this.messenger.postMessage()
		if this.messenger.queryCancel(.t.)
			this.stopWorkers(.t.)
		endif
	endfunc
	
	function isParallelReady()
		return this.wc >= 0
	endfunc

	function isParallel()
		return this.wc > 1
	endfunc
	
	function isSequential()
		return this.wc <= 1
	endfunc
	
	function isCanceled()
		return this.canceled
	endfunc
	
	function isRunning()
		return this.getRunningWorkerCount() > 0
	endfunc

	function setWorkerCount(wc as Integer)
		if this.wc >= 0
			this.parallel.setWorkerCount(m.wc)
			this.wc = this.getWorkerCount()
			return .t.
		endif
		return .f.
	endfunc
	
	function getWorkerCount()
		if this.wc >= 0
			this.wc = _Screen.ParPoolMgr.nWorkerCount
			return this.wc
		endif
		return -1
	endfunc
	
	function getRunningWorkerCount()
		if this.wc >= 0
			return _Screen.ParPoolMgr.workers.count
		endif
		return 0
	endfunc
	
	function getCPUcount()
		if this.wc >= 0
			return this.parallel.CPUcount
		endif
		return Evl(Val(GetEnv("NUMBER_OF_PROCESSORS")), 1)
	endfunc
	
	function startWorkers(proc as String, debug as boolean)
		this.stopWorkers()
		if this.isParallel()
			this.parallel.startWorkers(m.proc,,m.debug)
			return .t.
		endif
		set procedure to (m.proc) additive
		return .f.
	endfunc
	
	function bindProgress(messenger as Object)
		this.messenger = m.messenger
		if this.isParallel()
			this.parallel.bindEvent("Complete", this, "progressEvent")
		endif
	endfunc
	
	function unbindProgress()
		this.messenger = .f.
		if this.wc >= 0
			unbindevents(this.parallel._Events, "Complete", this, "progressEvent")
		endif
	endfunc
	
	function pepare(func as String, para01, para02, para03, para04, para05, para06, para07, para08)
		this.execute(pcount()-1, m.func, .t., m.para01, m.para02, m.para03, m.para04, m.para05, m.para06, m.para07, m.para08)
	endfunc
			
	function call(func as String, para01, para02, para03, para04, para05, para06, para07, para08)
		this.execute(pcount()-1, m.func, .f., m.para01, m.para02, m.para03, m.para04, m.para05, m.para06, m.para07, m.para08)
	endfunc

	function wait()
		if this.wc >= 0
			this.parallel.wait()
		endif
		return
	endfunc	
	
	function stopWorkers(cancel)
		this.canceled = m.cancel
		if this.wc >= 0
			this.parallel.stopWorkers(.t.)
		endif
	endfunc

	hidden function execute(pc as Integer, func as String, all as Boolean, para01, para02, para03, para04, para05, para06, para07, para08)
	local exe
		this.canceled = .f.
		if m.pc > 0
			m.exe = left(" m.para01,m.para02,m.para03,m.para04,m.para05,m.para06,m.para07,m.para08",m.pc*9)
			if this.wc > 1
				m.exe = "this.parallel.call(m.func, m.all,"+m.exe+")"
			else
				m.exe = "do "+m.func+" with"+m.exe
			endif
		else
			if this.wc > 1
				m.exe = "this.parallel.call(m.func, m.all)"
			else
				m.exe = "do "+m.func
			endif
		endif
		&exe
		if this.wc <= 1 and m.all == .f. and vartype(this.messenger) == "O"
			this.progressEvent()
		endif
	endfunc
enddefine

define class DynaPara as Custom
	list = .f.
	
	function init(list as String)
	local lexArray, subArray, i
		this.list = createobject("Collection")
		if vartype(m.list) != "C" or empty(m.list)
			return
		endif
		dimension m.lexArray[1]
		dimension m.subArray[1]
		for m.i = 1 to alines(m.lexArray,m.list,5,";")
			if alines(m.subArray,m.lexArray[m.i],5,"=") != 2
				throw "invalid list item: "+m.lexArray[m.i]
			endif
			this.dyna(m.subArray[1], m.subArray[2])
		endfor
	endfunc
	
	function dyna(tlist as String, plist as String)
	local pos, p, i, lexArray, already
		if not vartype(m.plist) == "C"
			m.plist = ""
		endif
		if not vartype(m.tlist) == "C"
			m.tlist = ""
		endif
		m.tlist = strtran(strtran(upper(m.tlist)," ",""),",","")
		m.plist = strtran(alltrim(m.plist)," ",",")
		do while ",," $ m.plist
			m.plist = strtran(m.plist,",,",",")
		enddo
		if not strtran(strtran(strtran(strtran(strtran(strtran(m.tlist,"O",""),"C",""),"N",""),"L",""),"T",""),"F","") == ""
			throw "invalid type list: "+m.tlist
		endif
		if empty(m.plist)
			m.plist = ""
			for m.i = 1 to len(m.tlist)
				m.plist = m.plist+","+ltrim(str(m.i))
			endfor
			m.plist = ltrim(m.plist,",")
		else
			m.already = " "
			dimension m.lexArray[1]
			for m.pos = 1 to alines(m.lexArray,m.plist,5,",")
				m.p = m.lexArray[m.pos]
				if not isdigit(m.p) or ltrim(str(val(m.p))) != m.p or " "+m.p+" " $ m.already
					throw "invalid position list: "+m.plist
				endif
				m.already = m.already+m.p+" "
			endfor
		endif
		if empty(m.tlist)
			m.tlist = " "
		endif
		this.list.add(m.plist,m.tlist)
	endfunc
	
	function para(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23, p24) && @m.p1, @m.p2, ...
	local i, j, tlist, plist, type, from, to, f, t, cnt, cmd, key, exp, chr
		m.tlist = ""
		for m.i = 1 to pcount()
			m.f = "m.p"+ltrim(str(m.i))
			m.type = type(m.f)
			if m.type == "L"
				m.type = iif(evaluate(m.f),"T","F")
			endif
			m.tlist = m.tlist+m.type
		endfor
		m.plist = 0
		for m.i = 1 to this.list.count
			m.key = padr(alltrim(this.list.getKey(m.i)),len(m.tlist),"F")
			m.tlist = padr(m.tlist,len(m.key),"F")
			m.exp = strtran(strtran(m.key,"L","?"),"F","?")
			if like(m.exp, m.tlist)
				for m.j = 1 to len(m.key)
					m.exp = substr(m.key,m.j,1)
					m.chr = substr(m.tlist,m.j,1)
					if m.exp == "F" and not m.chr == "F"
						exit
					endif
					if m.exp == "L" and not inlist(m.chr,"T","F")
						exit
					endif
				endfor
				if m.j > len(m.key)
					m.plist = m.i
					exit
				endif
			endif
		endfor
		if m.plist == 0
			return .f.
		endif
		m.plist = this.list.item(m.plist)
		if empty(m.plist)
			return .t.
		endif
		dimension m.to[1]
		m.cnt = aline(m.to,m.plist,5,",")
		dimension m.from[m.cnt]
		for m.i = 1 to m.cnt
			m.from[m.i] = ltrim(str(m.i))
		endfor
		for m.i = 1 to m.cnt
			m.f = m.from[m.i]
			m.t = m.to[m.i]
			if m.f != m.t
				m.cmd = textmerge("this.swap(@m.p<<m.f>>,@m.p<<m.t>>)")
				&cmd
				for m.j = m.i+1 to m.cnt
					if m.from[m.j] == m.t 
						m.from[m.j] = m.f
						exit
					endif
				endfor
			endif
		endfor
		return .t.
	endfunc
	
	function toString()
	local str, i
		m.str = ""
		for m.i = 1 to this.list.count
			m.str = m.str+";"+this.list.getKey(m.i)+"="+this.list.item(m.i)
		endfor
		return substr(m.str,2)
	endfunc
	
	hidden function swap(p1, p2)
	local swap
		m.swap = m.p2
		m.p2 = m.p1
		m.p1 = m.swap
	endfunc
enddefine

define class Messenger as custom
	hidden target, method, interval, screen, time, property, silent, errorCancel
	hidden progress, goal, goalstr, canceled
	hidden message, default, type
	hidden cancelMessage, cancelTitle, cancelQuery, canceling, psesc 
	target = .f.
	method = ""
	interval = 2
	message = ""
	onscreen = .t.
	property = .f.
	type = 0
	silent = .f.
	prefix = ""
	progress = 0
	goal = -1
	goalstr = ""
	default = ""
	errorCancel = .f.
	cancelMessage = ""
	cancelTitle = ""
	cancelQuery = ""
	canceling = .f.
	psesc = .f.
	time = 0

	function init(errorCancel as Boolean)
		this.time = seconds()
		this.errorCancel = m.errorCancel
	endfunc

	function setTarget(target, method)
		if vartype(m.target) == "O" and vartype(m.method) == "C"
			this.target = m.target
			this.method = alltrim(m.method)
			this.onscreen = .f.
			if "(" $ this.method
				this.method = left(this.method,at("(",this.method)-1)
			endif
			this.method = "this.target."+this.method
			if type(this.method) == "U"
				this.property = .f.
				this.method = this.method+"(this.message)"
			else
				this.property = .t.
				this.method = this.method+" = this.message"
			endif
		else
			this.target = .f.
			this.method = ""
			this.onscreen = .t.
			this.property = .f.
		endif
	endfunc
	
	function getErrorCancel()
		return this.errorCancel
	endfunc
	
	function setErrorCancel(errorCancel as Boolean)
		this.errorCancel = m.errorCancel
	endfunc

	function setPrefix(prefix as String)
		this.prefix = m.prefix
	endfunc

	function getPrefix()
		return this.prefix
	endfunc

	function setInterval(interval)
		this.interval = m.interval
	endfunc

	function getInterval()
		return this.interval
	endfunc
	
	function setSilent(silent as Boolean)
		this.silent = m.silent
	endfunc
	
	function isSilent()
		return this.silent
	endfunc
	
	function startProgress(goal as Integer)
		this.setProgress(0)
		if vartype(m.goal) != "N"
			this.setGoal(-1)
		else
			this.setGoal(m.goal)
		endif
	endfunc
	
	function incProgress(inc as Integer)
		this.progress = this.progress + evl(m.inc,1)
	endfunc

	function stopProgress()
		this.setGoal(-1)
		this.setProgress(-1)
	endfunc

	function setProgress(progress as Integer)
		this.progress = m.progress
	endfunc

	function getProgress()
		return this.progress
	endfunc

	function setGoal(goal as Integer)
		this.goal = m.goal
		if this.goal > 0
			this.goalstr = "/"+ltrim(str(this.goal,12))
		else
			this.goalstr = ""
		endif
	endfunc

	function getGoal()
		return this.goal
	endfunc
	
	function setDefault(message as String)
		this.default = m.message
	endfunc

	function getDefault()
		return this.default
	endfunc
	
	function startCancel(query as String, title as String, message as String)
		this.cancelQuery = iif(vartype(m.query) == "C",m.query,"")
		this.cancelTitle = iif(vartype(m.title) == "C",m.title,"")
		this.cancelMessage = iif(vartype(m.message) == "C",m.message,"")
		this.canceling = .t.
		this.psesc = createobject("PreservedSetting","escape","off")
		return .t.
	endfunc
	
	function stopCancel()
		this.cancelQuery = ""
		this.cancelTitle = ""
		this.cancelMessage = ""
		this.canceling = .f.
		this.psesc = .f.
	endfunc

	function start()
		this.time = seconds()
	endfunc

	function getMessage()
		return this.message
	endfunc
	
	function getErrorMessage()
		if this.isError()
			return this.message
		endif
		return ""
	endfunc
	
	function getWarningMessage()
		if this.isWarning()
			return this.message
		endif
		return ""
	endfunc

	function clearMessage()
		this.message = ""
		this.default = ""
		this.prefix = ""
		this.type = 0
		this.stopProgress()
		this.stopCancel()
		this.displayMessage()
	endfunc
	
	function sneakMessage(message, progress)
	local mess, type
		m.mess = this.message
		m.type = this.type
		this.forceMessage(m.message, m.progress)
		this.message = m.mess
		this.type = m.type
	endfunc
	
	function postProgress(message)
		this.postMessage(m.message, .t.)
	endfunc

	function forceProgress(message)
		this.forceMessage(m.message, .t.)
	endfunc

	function postMessage(message, progress)
		this.type = 0
		if this.interval <= 0 or this.timeMessage()
			this.buildMessage(m.message, m.progress)
			this.displayMessage()
		endif
	endfunc

	function forceMessage(message, progress)
		this.type = 1
		this.buildMessage(m.message, m.progress)
		this.displayMessage()
	endfunc

	function warningMessage(message)
		this.type = 2
		this.buildMessage(m.message)
		this.displayMessage()
	endfunc

	function specialMessage(message)
		this.type = 3
		this.buildMessage(m.message)
		this.displayMessage()
	endfunc

	function errorMessage(message)
		this.type = 4
		this.prefix = ""
		this.buildMessage(m.message)
		this.displayMessage()
		if this.errorCancel
			if empty(this.message)
				messagebox("Error!",16,"Exception")
			else
				messagebox(this.message,16,"Exception")
			endif
			cancel
		endif
	endfunc

	function queryCancel(parallelEvent as Boolean)
		if this.canceling and (m.parallelEvent or chrsaw()) and inkey("H") == 27
			if messagebox(this.cancelQuery,292,this.cancelTitle) == 6
				this.type = 5
				this.prefix = ""
				this.buildMessage(this.cancelMessage)
				this.displayMessage()
				if this.errorCancel
					if empty(this.cancelMessage)
						messagebox("Canceled!",16,"Exception")
					else
						messagebox(this.cancelMessage,16,"Exception")
					endif
					cancel
				endif
				return .t.
			endif
		endif
		return .f.
	endfunc
	
	function isPost()
		return this.type == 0
	endfunc

	function isForce()
		return this.type == 1
	endfunc

	function isStandard()
		return this.type < 2
	endfunc

	function isWarning()
		return this.type == 2
	endfunc

	function isSpecial()
		return this.type == 3
	endfun

	function isError()
		return this.type == 4
	endfunc

	function isCanceled()
		return this.type == 5
	endfunc

	function isInterrupted()
		return this.type > 3
	endfunc

	function getMessageType()
		return this.type
	endfunc

	function displayMessage()
		local prop
		if this.silent
			return
		endif
		if this.onscreen
			set message to this.message
		else
			if this.property
				m.prop = this.method
				&prop
			else
				evaluate(this.method)
			endif
		endif
	endfunc
	
	hidden function buildMessage(message, progress)
		this.message = this.prefix+iif(empty(m.message),this.default,m.message)
		if m.progress and this.progress > 0 and (this.type == 0 or this.type == 1)
			this.message = this.message+" "+ltrim(str(this.progress,12))
			if this.progress <= this.goal
				this.message = this.message+this.goalstr
			endif
		endif
	endfunc

	hidden function timeMessage()
		local newtime, elapsed
		m.newtime = seconds()
		if m.newtime < this.time
			m.elapsed = m.newtime+86400-this.time
		else
			m.elapsed = m.newtime-this.time
		endif
		if m.elapsed >= this.interval
			this.time = seconds()
			return .t.
		endif
		return .f.
	endfunc
enddefine

define class LastMessage as custom
	protected message, Messenger

	function init(Messenger, message)
		this.Messenger = m.Messenger
		this.setMessage(m.message)
	endfunc

	function setMessage(message)
		if vartype(m.message) == "C"
			this.message = m.message
		else
			this.message = ""
		endif
	endfunc

	protected function destroy
		this.messenger.stopProgress()
		this.messenger.stopCancel()
		this.messenger.setDefault("")
		if this.Messenger.isStandard()
			this.Messenger.forceMessage(this.message)
		else
			this.Messenger.displayMessage()
		endif
	endfunc
enddefine

define class Timing as custom
	hidden time, stopTime, stopped

	function init(stopped)
		if m.stopped
			this.stop()
			this.time = this.stopTime
		else
			this.start()
		endif
	endfunc

	function elapsed
		local newtime, elapsed
		m.newtime = iif(this.stopped,this.stopTime,seconds())
		if m.newtime < this.time
			m.elapsed = m.newtime+86400-this.time
		else
			m.elapsed = m.newtime-this.time
		endif
		return m.elapsed
	endfunc

	function timed
		local newtime, elapsed
		m.newtime = iif(this.stopped,this.stopTime,seconds())
		if m.newtime < this.time
			m.elapsed = m.newtime+86400-this.time
		else
			m.elapsed = m.newtime-this.time
		endif
		this.time = m.newtime
		return m.elapsed
	endfunc

	function start()
		this.time = seconds()
		this.stopped = .f.
	endfunc

	function stop()
		this.stopTime = iif(this.stopped,this.stopTime,seconds())
		this.stopped = .t.
	endfunc

	function go()
		this.time = seconds()-this.elapsed()
		if this.time < 0
			this.time = 86400+this.time
		endif
		this.stopped = .f.
	endfunc
enddefine

define class ReindexGuard as custom
	protected table, limit, ratio, changes, reindexTime, clock

	function init(table, ratio, limit)
		this.table = m.table
		if not vartype(m.ratio) == "N"
			m.ratio = 0.1
		endif
		if not vartype(m.limit) == "N"
			m.limit = 10000
		endif
		this.limit = max(10000, m.limit)
		this.ratio = abs(m.ratio)
		if this.ratio < 1 and this.ratio > 0
			this.ratio = 1/this.ratio
		endif
		this.clock = createobject("Timing")
		this.start()
	endfunc

	function start()
		this.reindexTime = 0
		this.changes = 0
		this.clock.start()
	endfunc

	function tryReindex()
		this.changes = this.changes+1
		if this.changes > this.limit and this.clock.elapsed() >= this.reindexTime
			this.clock.start()
			this.table.reindex()
			this.reindexTime = this.clock.timed()*this.ratio
			return .t.
		endif
		return .f.
	endfunc

	function stop()
		this.clock.stop()
	endfunc

	function go()
		this.clock.go()
	endfunc
enddefine

define class PreservedSetting as custom
	protected oldset, setting
	oldset = ""
	setting = ""

	function init(setting, newset, oldset)
	local para
		m.para = parameters()
		this.setting = alltrim(m.setting)
		if m.para >= 3
			this.oldset = createobject("String",m.oldset)
		else
			this.oldset = createobject("String",set(this.setting))
		endif
		if m.para < 2
			return
		endif
		m.newset = createobject("String",m.newset)
		m.newset.alltrimString()
		this.setIt(m.newset.toString())
	endfunc

	protected function destroy
		this.setIt(this.oldset.toString())
	endfunc

	protected function setIt(newset)
		local err, set
		m.set = "set "+this.setting+" to (m.newset)"
		m.err = .f.
		try
			&set
		catch
			m.err = .t.
		endtry
		if not m.err
			return
		endif
		m.set = "set "+this.setting+" to "+m.newset
		m.err = .f.
		try
			&set
		catch
			m.err = .t.
		endtry
		if not m.err
			return
		endif
		m.set = "set "+this.setting+" (m.newset)"
		m.err = .f.
		try
			&set
		catch
			m.err = .t.
		endtry
		if not m.err
			return
		endif
		m.set = "set "+this.setting+" "+m.newset
		try
			&set
		catch
		endtry
	endfunc

	function getSetting
		return this.setting
	endfunc

	function getOldSet
		return this.oldset.toString()
	endfunc
enddefine

define class PreservedSettingList as custom
	protected pslist[1], pscount
	pscount = 0

	function set(setting, newset, oldset)
		local ps, para
		m.para = parameters()
		if vartype(setting) == "O"
			this.psadd(m.setting)
		else
			if m.para > 2
				m.ps = createobject("PreservedSetting",m.setting,m.newset,m.oldset)
			else
				m.ps = createobject("PreservedSetting",m.setting,m.newset)
			endif
			this.psadd(m.ps)
		endif
	endfunc

	protected function psadd(ps)
		this.pscount = this.pscount+1
		if this.pscount > alen(this.pslist)
			dimension this.pslist[this.pscount+5]
		endif
		this.pslist[this.pscount] = m.ps
	endfunc
enddefine

define class String as custom
	protected string, upper, lower, normized
	protected separator, lexpos, eol, lexLineChange, lexPrevSep
	string = ""
	upper = .f.
	lower = .f.
	normized = .f.
	separator = " "
	lexpos = 1
	eol = .f.
	lexLineChange = .f.
	lexPrevSep = .t.

	function init(str)
		this.setString(m.str)
	endfunc

	function setString(str)
		local type
		if isnull(m.str)
			m.str = ""
		endif
		m.type = vartype(m.str)
		do case
			case m.type == "C" or m.type == "M"
				this.string = m.str
			case m.type == "N"
				this.string = ltrim(str(m.str,36,18))
				if "E" $ this.string
					this.string = rtrim(getwordnum(this.string,1,"E"),"0")+"E"+getwordnum(this.string,2,"E")
				else
					this.string = rtrim(rtrim(rtrim(this.string,"0"),"."),",")
				endif
			case m.type == "L"
				this.string = iif(m.str,".T.",".F.")
			case m.type == "D"
				this.string = dtoc(m.str,1)
			case m.type == "T"
				this.string = ttoc(m.str,1)
			case m.type == "Y"
				this.string = ltrim(str(m.str,36,4))
			otherwise
				this.string = ""
		endcase
		this.upper = .f.
		this.lower = .f.
		this.normized = .f.
		this.lexpos = 1
		this.eol = .f.
		this.lexLineChange = .f.
		this.lexPrevSep = .t.
	endfunc

	function toString()
		return this.string
	endfunc

	function getSeparator()
		return this.separator
	endfunc

	function getCutString(start, end)
		if not vartype(m.end) == "N"
			return substr(this.string, m.start)
		endif
		return substr(this.string, start, end-start+1)
	endfunc

	function cutString(start, end)
		this.string = this.getCutString(m.start, m.end)
		return this.string
	endfunc

	function at(str, n)
		if not vartype(m.n) == "N"
			m.n = 1
		endif
		return at(m.str,this.string,n)
	endfunc

	function rat(str, n)
		if not vartype(m.n) == "N"
			m.n = 1
		endif
		return rat(m.str,this.string,n)
	endfunc

	function getLine(n)
	local end, start
		if m.n > 1
			m.start = at(chr(10),this.string, m.n-1)
			if m.start == 0
				return ""
			endif
			m.start = m.start+1
		else
			m.start = 1
		endif
		m.end = at(chr(10),this.string, m.n)
		if m.end == 0
			m.end = len(this.string)
		else
			m.end = m.end-1
			if asc(this.getCutString(m.end,m.end)) == 13
				m.end = m.end-1
			endif
		endif
		return this.getCutString(m.start,m.end)
	endfunc

	function getLineCount()
		local lc
		m.lc = occurs(chr(10),this.string)
		if not right(this.string,1) == chr(10)
			return m.lc+1
		endif
		return m.lc
	endfunc

	function containsPattern(pat)
		local len, i
		m.len = len(m.pat)
		for m.i = 1 to m.len
			if substr(m.pat, m.i,1) $ this.string
				return .t.
			endif
		endfor
		return .f.
	endfunc

	function getBlankInversePattern(pat)
		local i, len, str, chr, pos
		m.str = ""
		m.pos = 1
		m.len = len(this.string)
		for m.i = 1 to m.len
			m.chr = substr(this.string, m.i, 1)
			if not m.chr $ m.pat
				m.str = m.str+" "
			else
				m.str = m.str+m.chr
			endif
		endfor
		return m.str
	endfunc

	function blankInversePattern(pat)
		this.string = this.getBlankInversePattern(m.pat)
		return this.string
	endfunc

	function getBlankPattern(pat)
		return chrtran(this.string,m.pat,padl("",len(m.pat)," "))
	endfunc

	function blankPattern(pat)
		this.string = this.getBlankPattern(m.pat)
		return this.string
	endfunc

	function getCompress()
		local str
		m.str = this.string
		do while "  " $ m.str
			m.str = strtran(m.str,"  "," ")
		enddo
		return m.str
	endfunc

	function compress()
		this.string = this.getCompress()
		return this.string
	endfunc

	function properString()
		this.string = proper(this.string)
		this.upper = .f.
		this.lower = .f.
		return this.string
	endfunc

	function upperString()
		this.string = upper(this.string)
		this.upper = .t.
		this.lower = .f.
		return this.string
	endfunc

	function lowerString()
		this.string = lower(this.string)
		this.upper = .f.
		this.lower = .t.
		return this.string
	endfunc

	function ltrimString()
		this.string = ltrim(this.string)
		return this.string
	endfunc

	function rtrimString()
		this.string = rtrim(this.string)
		return this.string
	endfunc

	function alltrimString()
		this.string = alltrim(this.string)
		return this.string
	endfunc

	function strtranString(before, after)
		this.string = strtran(this.string,m.before,m.after)
		return this.string
	endfunc

	function getDeGermanize()
		local str
		m.str = this.string
		if this.upper
			m.str = strtran(m.str, "Ä", "AE")
			m.str = strtran(m.str, "Ö", "OE")
			m.str = strtran(m.str, "Ü", "UE")
			m.str = strtran(m.str, "ß", "SS")
			return m.str
		else
			m.str = strtran(m.str, "ä", "ae")
			m.str = strtran(m.str, "ö", "oe")
			m.str = strtran(m.str, "ü", "ue")
			m.str = strtran(m.str, "ß", "ss")
		endif
		if this.lower
			return m.str
		endif
		m.str = strtran(m.str, "Ä", "Ae")
		m.str = strtran(m.str, "Ö", "Oe")
		m.str = strtran(m.str, "Ü", "Ue")
		return m.str
	endfunc

	function deGermanize()
		this.string = this.getDeGermanize()
		return this.string
	endfunc

	protected function lexem()
	local pos, loc, len, ignore, crlf, chr, lc, str
		m.len = len(this.string)
		if this.lexpos > m.len
			this.eol = .t.
			return ""
		endif
		m.crlf = chr(10)+chr(13)
		m.ignore = " "+m.crlf
		m.lc = .f.
		m.chr = substr(this.string,this.lexpos,1)
		do while this.lexpos <= m.len and m.chr $ m.ignore
			if m.chr $ m.crlf
				m.lc = .t.
			endif
			this.lexpos = this.lexpos+1
			m.chr = substr(this.string,this.lexpos,1)
		enddo
		this.lexLineChange = this.lexLineChange or m.lc
		if not this.separator == " " and m.lc
			return this.separator
		endif
		if this.lexpos > m.len
			this.eol = .t.
			return ""
		endif
		m.pos = this.lexpos
		m.str = substr(this.string,m.pos)
		m.pos = at(this.separator,m.str)
		if m.pos == 0
			m.pos = len(m.str)+1
		endif
		m.loc = at(chr(10),m.str)
		if m.loc > 0 and m.loc < m.pos
			m.pos = m.loc
		endif
		m.loc = at(chr(13),m.str)
		if m.loc > 0 and m.loc < m.pos
			m.pos = m.loc
		endif
		if m.pos == 1
			this.lexpos = this.lexpos + 1
			return this.separator
		else
			this.lexpos = this.lexpos+m.pos-1
			return alltrim(left(m.str, m.pos-1))
		endif
	endfunc
	
	function getLexem(n)
		local lex
		if not vartype(m.n) == "N"
			m.n = 1
		endif
		if m.n < 1
			m.n = 1
		endif
		this.eol = .f.
		this.lexLineChange = .f.
		m.lex = ""
		do while m.n > 0 and not this.eol
			m.lex = this.lexem()
			if m.lex == this.separator
				if this.lexPrevSep
					m.lex = ""
					m.n = m.n-1
				endif
				this.lexPrevSep = .t.
			else
				this.lexPrevSep = .f.
				m.n = m.n-1
			endif
		enddo
		return m.lex
	endfunc

	function tryLexem(n)
		local pos, str, lexPrevSep
		m.pos = this.lexpos
		m.lexPrevSep = this.lexPrevSep
		m.str = this.getLexem(m.n)
		this.lexpos = m.pos
		this.lexPrevSep = m.lexPrevSep
		return m.str
	endfunc

	function viewLexem(n)
	local lc, eol, str
		m.lc = this.lexLineChange
		m.eol = this.eol
		m.str = this.tryLexem(m.n)
		this.lexLineChange = m.lc
		this.eol = m.eol
		return m.str
	endfunc

	function getLexemLineChange()
		return this.lexLineChange
	endfunc

	function resetLexemLineChange()
		this.lexLineChange = .f.
	endfunc

	function setLexemSeparator(sep)
		if not vartype(m.sep) == "C" or m.sep == ""
			m.sep = " "
		else
			m.sep = left(m.sep,1)
		endif
		this.separator = m.sep
	endfunc

	function startLexem(sep)
		if vartype(m.sep) == "C"
			this.setLexemSeparator(m.sep)
		endif
		this.lexpos = 1
		this.eol = .f.
		this.lexLineChange = .f.
		this.lexPrevSep = .t.
	endfunc

	function endOfLexem()
		return this.eol
	endfunc

	function getLexemRemainder()
		local pos
		m.pos = this.lexpos
		this.lexpos = len(this.string)
		this.eol = .t.
		return this.getCutString(m.pos)
	endfunc

	function getLexemPosition()
		return this.lexpos
	endfunc

	function getLexemLine()
		local sep, lex
		m.sep = this.separator
		this.separator = chr(10)
		m.lex = this.getLexem()
		m.lex = strtran(m.lex,chr(13),"")
		this.separator = m.sep
		return m.lex
	endfunc

	function getLexemRestOfLine()
		this.lexLineChange = .f.
		if asc(this.getCutString(this.lexpos,this.lexpos)) == 10
			return ""
		endif
		return this.getLexemLine()
	endfunc

	function copyLexemArray(lex) && uebergabe als referenz: copyLexemArray(@var)
	local str 
		m.str = strtran(this.string, chr(13), this.separator)
		m.str = strtran(m.str, chr(10), this.separator)
		m.str = strtran(m.str, chr(9), this.separator)
		if this.separator == " "
			do while "  " $ m.str
				m.str = strtran(m.str, "  ", " ")
			enddo
			m.str = alltrim(m.str)
		endif
		dimension m.lex[1]
		alines(m.lex, m.str, 1, this.separator)
	endfunc

	function getNormize
	local norm, str, lastlen, lex
		m.norm = createobject("String",this.string)
		m.norm.upperString()
		m.norm.alltrimString()
		m.norm.deGermanize()
		m.norm.blankInversePattern(" ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")
		m.norm.compress()
		m.norm.ltrimString()
		m.lastlen = 1
		m.str = ""
		m.norm.startLexem()
		m.lex = m.norm.getLexem()
		do while not m.norm.endOfLexem()
			if len(m.lex) = 1
				if m.lastlen = 1
					m.str = m.str+m.lex
				else
					m.lastlen = 1
					m.str = m.str+" "+m.lex
				endif
			else
				m.lastlen = 0
				m.str = m.str+" "+m.lex
			endif
			m.lex = m.norm.getLexem()
		enddo
		return ltrim(m.str)
	endfunc

	function normize
		this.string = this.getNormize()
		this.normized = .t.
		this.upper = .t.
		this.lower = .f.
		return this.string
	endfunc

	function getWordReplace(oldword, newword)
		local str
		m.str = this.string
		m.oldword = alltrim(m.oldword)
		m.newword = alltrim(m.newword)
		if (m.str == m.oldword)
			return m.newword
		endif
		m.str = strtran(m.str," "+m.oldword+" "," "+m.newword+" ")
		if left(m.str,len(m.oldword)+1) == m.oldword+" "
			m.str = stuff(m.str,1,len(m.oldword),m.newword)
		endif
		if right(m.str,len(m.oldword)+1) == " "+m.oldword
			m.str = stuff(m.str,len(m.str)-len(m.oldword)+1,len(oldword),m.newword)
		endif
		return m.str
	endfunc

	function wordReplace(oldword, newword)
		this.string = this.getWordReplace(m.oldword, m.newword)
		return this.string
	endfunc

	function getCockle()
	local i, l, wl, norm, word, sep, chr, str
		m.str = alltrim(this.string)+" "
		m.l = len(m.str)
		m.wl = 0
		m.norm = ""
		m.word = ""
		m.sep = ""
		for m.i = 1 to m.l
			m.chr = substr(m.str,m.i,1)
			if m.chr == " "
				if m.wl > 0
					if m.wl > 1
						m.norm = m.norm+" "+m.word
						m.sep = " "
					else
						m.norm = m.norm+m.sep+m.word
						m.sep = ""
					endif
					m.word = ""
					m.wl = 0
				endif
			else
				m.word = m.word+m.chr
				m.wl = m.wl+1
			endif
		endfor
		return ltrim(m.norm)
	endfunc
	
	function cockle()
		this.string = this.getCockle()
		return this.string
	endfunc

	function getLeftWordReplace(oldword, newword)
		local str
		m.str = this.string
		m.oldword = alltrim(m.oldword)
		m.newword = alltrim(m.newword)
		if (m.str == m.oldword)
			return m.newword
		endif
		m.str = strtran(m.str," "+m.oldword," "+m.newword)
		if left(m.str,len(m.oldword)) == m.oldword
			m.str = stuff(m.str,1,len(m.oldword),m.newword)
		endif
		return m.str
	endfunc

	function leftWordReplace(oldword, newword)
		this.string = this.getLeftWordReplace(m.oldword, m.newword)
		return this.string
	endfunc

	function getRightWordReplace(oldword, newword)
		local str
		m.str = this.string
		m.oldword = alltrim(m.oldword)
		m.newword = alltrim(m.newword)
		if (m.str == m.oldword)
			return m.newword
		endif
		m.str = strtran(m.str,m.oldword+" ",m.newword+" ")
		if right(m.str,len(m.oldword)) == m.oldword
			m.str = stuff(m.str,len(m.str)-len(m.oldword)+1,len(oldword),m.newword)
		endif
		return m.str
	endfunc

	function rightWordReplace(oldword, newword)
		this.string = this.getRightWordReplace(m.oldword, m.newword)
		return this.string
	endfunc

	function getFileExtensionChange(ext, complement)
	local str, pos
		m.str = this.string
		m.ext = ltrim(alltrim(m.ext),".")
		m.pos = rat(".",m.str)
		if m.pos = 0 or m.pos < rat("\",m.str) or m.pos < rat("/",m.str)
			m.str = m.str+"."
			m.pos = len(m.str)
		else
			if m.complement
				return m.str
			endif
		endif
		return rtrim(left(m.str, m.pos)+m.ext,".")
	endfunc

	function fileExtensionChange(ext, complement)
		this.string  = this.getFileExtensionChange(m.ext, m.complement)
		return this.string
	endfunc
	
	function call(function, str)
		this.setString(m.str)
		m.function = "return this."+ltrim(m.function)
		&function
	endfunc
enddefine

define class FirmenStringNormizer as StringNormizer
	function normize(str)
		local norm
		m.norm = createobject("String",StringNormizer::normize(m.str))
		m.norm = m.norm.getCockle()
		m.norm = strtran(m.norm,"GESELLSCHAFT ","GES ")
		m.norm = strtran(m.norm,"GESELL ","GES ")
		m.norm = strtran(m.norm,"STRASSE ","STR ")
		m.norm = strtran(m.norm, "MIT BESCHRAENKTER HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "MIT BESCHR HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "MIT BESCH HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "MIT B HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "M BESCHRAENKTER HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "M BESCHR HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "M BESCH HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "MB HAFTUNG", "MBH")
		m.norm = strtran(m.norm, "MIT BESCHRAENKTER HAFT", "MBH")
		m.norm = strtran(m.norm, "MIT BESCHR HAFT", "MBH")
		m.norm = strtran(m.norm, "MIT BESCH HAFT", "MBH")
		m.norm = strtran(m.norm, "MIT B HAFT", "MBH")
		m.norm = strtran(m.norm, "M BESCHRAENKTER HAFT", "MBH")
		m.norm = strtran(m.norm, "M BESCHR HAFT", "MBH")
		m.norm = strtran(m.norm, "M BESCH HAFT", "MBH")
		m.norm = strtran(m.norm, "MB HAFT", "MBH")
		m.norm = strtran(m.norm, "GES MBH", "GMBH")
		m.norm = strtran(m.norm, "AKTIENGES", "AG")
		m.norm = strtran(m.norm, "KOMMANDITGES", "KG")
		return alltrim(m.norm)
	endfunc
enddefine

define class StringList as custom
	protected list[1], size, sep

	function init(list,sep)
		this.size = 0
		if parameters() > 1
			this.sep = m.sep
		else
			this.sep = ";"
		endif
		if parameters() > 0
			this.addlist(m.list)
		endif
	endfunc

	function isValid()
		return this.size > 0
	endfunc

	protected function addlist(list)
		local lex, cnt
		m.cnt = this.size
		m.list = createobject("String",m.list)
		m.list.startLexem(this.sep)
		m.lex = m.list.getLexem()
		do while not m.list.endOfLexem()
			this.additem(m.lex)
			m.lex = m.list.getLexem()
		enddo
		return this.size-m.cnt
	endfunc

	protected function additem(item)
		m.item = alltrim(upper(m.item))
		if empty(m.item)
			return .f.
		endif
		this.size = this.size+1
		if this.size > alen(this.list)
			dimension this.list[this.size+10]
		endif
		this.list[this.size] = m.item
		return .t.
	endfunc

	function getSeparator()
		return this.sep
	endfunc

	function getItemCount()
		return this.size
	endfunc

	function getItem(ind)
		if m.ind > this.size or m.ind < 1
			return ""
		endif
		return this.list[m.ind]
	endfunc

	function seekItem(item, occ)
		local i
		if not vartype(m.occ) == "N"
			m.occ = 1
		endif
		m.item = alltrim(upper(m.item))
		for m.i = 1 to this.size
			if m.item == this.list[m.i]
				m.occ = m.occ - 1
				if m.occ <= 0
					return m.i
				endif
			endif
		endfor
		return 0
	endfunc
	
	function extract(from, to)
	local i, str
		if not vartype(m.to) == "N"
			m.to = this.size
		else
			m.to = min(m.to,this.size)
		endif
		m.from = max(1,m.from)
		if m.from > m.to
			return ""
		endif
		m.str = this.list[m.from]
		for m.i = m.from+1 to m.to
			m.str = m.str+this.sep+" "+this.list[m.i]
		endfor
		return m.str
	endfunc

	function toString()
	local str, i
		m.str = ""
		if this.size > 0
			m.str = this.list[1]
		endif
		for m.i = 2 to this.size
			m.str = m.str+this.sep+" "+this.list[m.i]
		endfor
		return m.str
	endfunc
enddefine

define class LexemList as StringList
	protected function additem(item)
		m.item = alltrim(upper(m.item))
		this.size = this.size+1
		if this.size > alen(this.list)
			dimension this.list[this.size+10]
		endif
		this.list[this.size] = m.item
		return .t.
	endfunc
enddefine

define class UniqueAlias as custom
	protected autoclose
	alias = ""
	dbf = ""

	function init(autoclose as boolean)
		this.alias = sys(2015)
		do while used(this.alias)
			this.alias = sys(2015)
		enddo
		create cursor (this.alias) (dummy c(1))
		this.dbf = dbf(this.alias)
		this.autoclose = m.autoclose
	endfunc

	function toString
		return this.alias
	endfunc

	function getAlias
		return this.alias
	endfunc
	
	function close()
		try
		catch
			use in (this.alias)
		endtry
	endfunc
	
	function swap(ualias as UniqueAlias)
	local swap
		m.swap = this.alias
		this.alias = m.ualias.alias
		m.ualias.alias = m.swap
	endfunc
	
	function select()
		select (this.alias)
	endfunc
	
	protected function destroy
		if this.autoclose
			try
				use in (this.alias)
			catch
			endtry
		endif
	endfunc
enddefine

define class ProgramPath as custom
	protected path

	function init
		this.path = createobject("String",sys(16,0))
		this.path.cutString(rat(" ",left(sys(16,0),at("\",sys(16,0))))+1, rat("\",sys(16,0)))
	endfunc

	function toString
		return proper(this.path.toString())
	endfunc
enddefine

define class PreservedAlias as custom
	protected oldAlias
	oldAlias = ""

	function init
		this.oldAlias = alias()
	endfunc

	protected function destroy
		if empty(this.oldAlias) or select(this.oldAlias) <= 0
			return
		endif
		select (this.oldAlias)
	endfunc

	function restore
		this.destroy()
	endfunc

	function preserve
		this.init()
	endfunc

	function toString
		return proper(this.oldAlias)
	endfunc
enddefine

define class PreservedKey as custom
	protected oldKey, table
	oldKey = ""

	function init(table)
		this.table = m.table
		this.oldKey = this.table.getkey()
	endfunc

	protected function destroy
		this.table.setKey(this.oldKey)
	endfunc

	function toString
		return proper(this.oldAlias)+" "+proper(this.oldKey)
	endfunc
enddefine

define class FieldStructure as custom
	fname = ""
	type = "U"
	size = 0
	decimal = 0
	index = 0
	null = .f.

	function init(name, type, size, decimal, index, null)
		if not vartype(m.name) == "C"
			return
		endif
		this.fname = m.name
		this.type = m.type
		this.size = m.size
		this.decimal = m.decimal
		this.index = m.index
		this.null = m.null
	endfunc

	function isValid
		if empty(this.Name)
			return .f.
		endif
		if inlist(this.type,"M","I","Y","B","L","D","T")
			return .t.
		endif
		if this.type == "C" 
			if this.size > 0
				return .t.
			endif
			return .f.
		endif
		if inlist(this.type,"N","F")
			if this.size > 0 and this.decimal >= 0
				return .t.
			endif
		endif
		return .f.
	endfunc

	function getName
		return this.fname
	endfunc

	function getType
		return this.type
	endfunc

	function getSize
		return this.size
	endfunc

	function getDecimal
		return this.decimal
	endfunc

	function getIndex
		return this.index
	endfunc
	
	function getNull
		return this.null
	endfunc

	function getDefinition
		if this.type = "C"
			return "C("+ltrim(str(this.size))+icase(this.null,") null",")")
		endif
		if this.type == "N" or this.type == "F"
			return this.type+"("+ltrim(str(this.size))+iif(this.decimal > 0,","+ltrim(str(this.decimal)),"")+icase(this.null,") null",")")
		endif
		return this.type+icase(this.null," null","")
	endfunc

	function transform(str)
		m.str = createobject("String",m.str)
		m.str = m.str.toString()
		do case
			case this.type == "C"
				return left(m.str, this.size)
			case this.type == "M"
				return m.str
			case inlist(this.type,"N","Y","I","F","B")
				return val(m.str)
			case this.type == "D"
				m.str = strtran(strtran(strtran(m.str,".",""),":","")," ","")
				return date(val(substr(m.str,1,4)),val(substr(m.str,5,2)),val(substr(m.str,7,2)))
			case this.type == "T"
				m.str = strtran(strtran(strtran(m.str,".",""),":","")," ","")
				return datetime(val(substr(m.str,1,4)),val(substr(m.str,5,2)),val(substr(m.str,7,2)),val(substr(m.str,9,2)),val(substr(m.str,11,2)),val(substr(m.str,13,2)))
			case type.type == "L"
				return upper(alltrim(m.str)) == ".T."
		endcase
		return .f.
	endfunc
	
	function getStringSize()
		do case
			case inlist(this.type,"C", "N", "F")
				return this.size
			case this.type == "M"
				return 254
			case this.type == "I"
				return 10
			case inlist(this.type, "B", "Y")
				return 18
			case this.type == "D"
				return len(dtoc(date(),1))
			case this.type == "T"
				return len(ttoc(date(),1))
			case this.type == "L"
				return 3
		endcase
		return this.size
	endfunc
	
	function maximizeType(f as Object)
	local type
		m.type = m.f.getType()
		do case
			case this.type == m.type
				return this.type
			case this.type == "C"
				if m.type == "M"
					return "M"
				endif
			case this.type == "M"
				if m.type == "C"
					return "M"
				endif
			case this.type == "I"
				if inlist(m.type,"N","F")
					if m.f.getSize() > 9 or m.f.getDecimal() > 0
						return "N"
					endif
					return "I"
				endif
				if inlist(m.type,"B","Y")
					return "B"
				endif
			case inlist(this.type,"N","F")
				if inlist(m.type,"N","F")
					return "N"
				endif
				if inlist(m.type,"B","Y")
					return "B"
				endif
				if m.type == "I"
					if this.size > 9 or this.decimal > 0
						return "N"
					endif
					return "I"
				endif
			case inlist(this.type,"B","Y")
				if inlist(m.type,"B","Y","N","F")
					return "B"
				endif
			case this.type == "T"
				if m.type == "D"
					return "T"
				endif
		endcase
		return "U"
	endfunc
	
	function compatibleFieldStructure(f as Object, name as String)
		if not vartype(m.name) == "C"
			m.name = this.getName()
		endif
		return createobject("FieldStructure",m.name,this.maximizeType(m.f),max(this.getStringSize(),m.f.getStringSize()),max(this.decimal,m.f.getDecimal()),this.index,max(this.null,m.f.getNull()))
	endfunc
	
	function isCompatible(f as Object)
	local compatible
		m.compatible = this.compatibleFieldStructure(m.f)
		return m.compatible.isValid()
	endfunc
	
	function toString
		return proper(this.fname)+" "+this.getDefinition()
	endfunc

	function sqlConverter()
		return 'cast('+this.defaultConverter()+' as '+this.getDefinition()+') as '+proper(this.fname)
	endfunc
	
	function defaultConverter()
		return '" "'
	endfunc

	function baseConverter(field as String, sort as Boolean)
		return '""'
	endfunc

	function keyConverter(field as String, sort as Boolean)
		if this.null
			return 'NVL('+this.baseConverter(m.field, m.sort)+',"")'
		endif
		return this.baseConverter(m.field, m.sort)
	endfunc
	
	function blankConverter()
		return 'IIF(ISBLANK('+this.fname+'),"",'+this.keyConverter(this.fname)+')'
	endfunc
	
	function exportConverter()
		return this.blankConverter()
	endfunc
	
	function quotedConverter()
		return this.blankConverter()
	endfunc
enddefine

define class CFieldStructure as FieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "C", m.size, m.decimal, m.index, m.null)
	endfunc
	
	function isValid()
		return not empty(this.name) and this.size > 0
	endfunc
	
	function getDefinition()
		return "C("+ltrim(str(this.size))+icase(this.null,") null",")")
	endfunc
	
	function getStringSize()
		return this.size
	endfunc
	
	function transform(val)
		m.val = createobject("String",m.val)
		return m.val.toString()
	endfunc

	function maximizeType(f as Object)
	local type
		m.type = m.f.getType()
		if m.type == this.type
			return this.type
		endif
		if m.type == "M"
			return "M"
		endif
		return "U"
	endfunc

	function baseConverter(field as String, sort as Boolean)
		return 'RTRIM('+m.field+')'
	endfunc
	
	function blankConverter()
		return this.keyConverter(this.fname)
	endfunc
	
	function exportConverter()
		return 'STRTRAN(STRTRAN(STRTRAN(STRTRAN('+this.blankConverter()+',CHR(9),"_"),CHR(13),"_"),CHR(10),"_"),CHR(26),"_")'
	endfunc
	
	function quotedConverter()
		return 'CHR(34)+STRTRAN('+this.exportConverter()+',CHR(34),CHR(39))+CHR(34)'
	endfunc
enddefine

define class MFieldStructure as CFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "M", m.size, m.decimal, m.index, m.null)
	endfunc
	
	function isValid()
		return not empty(this.name)
	endfunc

	function getDefinition()
		return "M"+icase(this.null," null","")
	endfunc
	
	function getStringSize()
		return 254
	endfunc

	function maximizeType(f as Object)
		if inlist(m.f.getType(),"C","M")
			return "M"
		endif
		return "U"
	endfunc
enddefine

define class NFieldStructure as FieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "N", m.size, m.decimal, m.index, m.null)
	endfunc
	
	function isValid()
		return not empty(this.name) and this.size > 0 and this.decimal >= 0
	endfunc

	function getDefinition()
		return this.type+"("+ltrim(str(this.size))+iif(this.decimal > 0,","+ltrim(str(this.decimal)),"")+icase(this.null,") null",")")
	endfunc
	
	function getStringSize()
		return this.size
	endfunc

	function maximizeType(f as Object)
	local type
		m.type = m.f.getType()
		if m.type == this.type
			return this.type
		endif
		if inlist(m.type,"N","F")
			return "N"
		endif
		if inlist(m.type,"B","Y")
			return "B"
		endif
		if m.type == "I"
			if this.size > 9 or this.decimal > 0
				return "N"
			endif
			return "I"
		endif
		return "U"
	endfunc

	function transform(val)
		m.val = createobject("String",m.val)
		return val(m.val.toString())
	endfunc
	
	function baseConverter(field as String, sort as Boolean)
		if m.sort		
			return 'IIF(ISNULL('+m.field+'),.NULL.,IIF('+m.field+'>=0,"P","N")+STR('+m.field+','+ltrim(str(this.size))+','+ltrim(str(this.decimal))+'))'
		endif
		return 'IIF(ISNULL('+m.field+'),.NULL.,LTRIM(STR('+m.field+','+ltrim(str(this.size))+','+ltrim(str(this.decimal))+')))'
	endfunc
	
	function defaultConverter()
		return "1"
	endfunc
enddefine

define class FFieldStructure as NFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "F", m.size, m.decimal, m.index, m.null)
	endfunc
enddefine

define class IFieldStructure as NFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "I", m.size, m.decimal, m.index, m.null)
	endfunc

	function isValid()
		return not empty(this.name)
	endfunc

	function getDefinition()
		return this.type+icase(this.null," null","")
	endfunc
	
	function getStringSize()
		return 10
	endfunc

	function maximizeType(f as Object)
	local type
		m.type = m.f.getType()
		if m.type == this.type
			return this.type
		endif
		if inlist(m.type,"N","F")
			if m.f.getSize() > 9 or m.f.getDecimal() > 0
				return "N"
			endif
			return "I"
		endif
		if inlist(m.type,"B","Y")
			return "B"
		endif
		return "U"
	endfunc

	function baseConverter(field as String, sort as Boolean)
		if m.sort		
			return 'IIF(ISNULL('+m.field+'),.NULL.,IIF('+m.field+'>=0,"P","N")+STR('+m.field+',10))'
		endif
		return 'IIF(ISNULL('+m.field+'),.NULL.,LTRIM(STR('+m.field+')))'
	endfunc
enddefine

define class BFieldStructure as IFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "B", m.size, m.decimal, m.index, m.null)
	endfunc

	function getStringSize()
		return 18
	endfunc

	function baseConverter(field as String, sort as Boolean)
		if m.sort		
			return 'IIF(ISNULL('+m.field+'),.NULL.,IIF('+m.field+'>=0,"P","N")+STR('+m.field+',36,18))'
		endif
		return 'IIF(ISNULL('+m.field+'),.NULL.,RTRIM(RTRIM(LTRIM(STR('+m.field+',36,18)),"0"),"."))'
	endfunc
enddefine

define class YFieldStructure as BFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "Y", m.size, m.decimal, m.index, m.null)
	endfunc
enddefine

define class LFieldStructure as IFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "L", m.size, m.decimal, m.index, m.null)
	endfunc
	
	function getStringSize()
		return 3
	endfunc

	function maximizeType(f as Object)
		if this.type == m.f.getType()
			return this.type
		endif
		return "U"
	endfunc

	function transform(val)
		m.val = createobject("String",m.val)
		return upper(alltrim(m.val.toString())) == ".T."
	endfunc
	
	function baseConverter(field as String, sort as Boolean)
		return 'IIF('+m.field+',".T.",".F.")'
	endfunc

	function defaultConverter()
		return ".T."
	endfunc
enddefine

define class DFieldStructure as LFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "D", m.size, m.decimal, m.index, m.null)
	endfunc
	
	function getStringSize()
		return 8
	endfunc

	function transform(val)
		m.val = createobject("String",m.val)
		m.val = m.val.toString()
		m.val = strtran(strtran(strtran(m.val,".",""),":","")," ","")
		return date(val(substr(m.val,1,4)),val(substr(m.val,5,2)),val(substr(m.val,7,2)))
	endfunc
	
	function baseConverter(field as String, sort as Boolean)
		return 'DTOC('+m.field+',1)'
	endfunc
	
	function defaultConverter()
		return 'date(1970,1,1)'
	endfunc
enddefine

define class TFieldStructure as DFieldStructure
	function init(name, size, decimal, index, null)
		FieldStructure::init(m.name, "T", m.size, m.decimal, m.index, m.null)
	endfunc
	
	function getStringSize()
		return 14
	endfunc

	function maximizeType(f as Object)
	local type
		m.type = m.f.getType()
		if inlist(m.type,"T","D")
			return "T"
		endif
		return "U"
	endfunc
	
	function transform(val)
		m.val = createobject("String",m.val)
		m.val = m.val.toString()
		m.val = strtran(strtran(strtran(m.val,".",""),":","")," ","")
		return datetime(val(substr(m.val,1,4)),val(substr(m.val,5,2)),val(substr(m.val,7,2)),val(substr(m.val,9,2)),val(substr(m.val,11,2)),val(substr(m.val,13,2)))
	endfunc
	
	function baseConverter(field as String, sort as Boolean)
		return 'IIF(ISNULL('+m.field+'),.NULL.,TTOC('+m.field+',1))'
	endfunc
enddefine

define class ComposedKey as custom
	protected struc, sort

	function init(table, keyList, sort)
		this.sort = m.sort
		if vartype(m.table) == "C"
			m.table = createobject("TableStructure",m.table)
		endif
		m.table = m.table.getTableStructure()
		if not vartype(m.keyList) == "L"
			if vartype(m.keylist) == "C"
				m.keylist = createobject("TableStructure",m.keylist)
			endif
			this.struc = m.keylist.recast(m.table, .t.)
			return
		endif
		this.struc = m.table
	endfunc

	function getexp(keyList)
		local exp, i, f
		if parameters() > 0
			if vartype(m.keyList) == "C"
				m.keyList = createobject("StringList",m.keyList,",")
			endif
		else
			m.keyList = this.getKeys()
		endif
		if m.keyList.getItemCount() != this.struc.getFieldCount()
			return ""
		endif
		m.exp = ""
		for m.i = 1 to this.struc.getFieldCount()
			m.f = this.struc.getFieldStructure(m.i)
			m.exp = m.exp+m.f.keyConverter(m.keyList.getItem(m.i), this.sort)+'+CHR(0)+'
		endfor
		return left(m.exp,len(m.exp)-8)
	endfunc

	function getKeys()
		return createobject("StringList",this.struc.getFieldList(),",")
	endfunc

	function toString()
		return this.getexp()
	endfunc
enddefine

define class TableStructure as custom
	dimension tstruct[1,5]
	compatible = .f.

	function init(struc, alias as Boolean)
		local cursor, pa, ps, str, lex, err
		this.tstruct[1,1] = ""
		this.tstruct[1,2] = ""
		this.tstruct[1,3] = 0
		this.tstruct[1,4] = 0
		this.tstruct[1,5] = .f.
		this.compatible = .f.
		if vartype(m.struc) == "O"
			m.struc = m.struc.getAlias()
			m.alias = .t.
		endif
		if not vartype(m.struc) == "C" or empty(m.struc)
			return
		endif
		if m.alias and select(m.struc) > 0
			afields(this.tstruct,m.struc)
			m.struc = this.toString()
			this.compatible = .t.
		endif
		m.str = createobject("String",m.struc)
		m.struc = ""
		m.str.startLexem(",")
		m.lex = lower(ltrim(m.str.getLexem()))
		do while not m.str.endOfLexem()
			if not empty(m.lex)
				if not " " $ m.lex and not isdigit(m.lex)
					m.lex = m.lex+" c(1)"
				endif
				m.struc = m.struc+m.lex+", "
			endif
			m.lex = m.str.getLexem()
		enddo
		if empty(m.struc)
			this.compatible = .f.
			return
		endif
		m.struc = left(m.struc,len(m.struc)-2)
		m.ps = createobject("PreservedSetting","compatible","off")
		m.pa = createobject("PreservedAlias")
		m.alias = sys(2015)
		do while used(m.alias)
			m.alias = sys(2015)
		enddo
		m.cursor = "create cursor "+m.alias+" ("+m.struc+") "
		try
			&cursor
		catch
		endtry
		m.err = not used(m.alias)
		if m.err
			this.compatible = .f.
			return
		endif
		if not this.compatible
			this.compatible = .t.
			afields(this.tstruct)
		endif
		use
	endfunc

	function getTableStructure()
		return this
	endfunc

	function isValid
		return this.tstruct[1,3] > 0
	endfunc
	
	function isCompatible()
		return this.compatible
	endfunc

	function getFieldCount
		return iif(this.isValid(),alen(this.tstruct,1),0)
	endfunc

	function checkStructure(struc, reverse)
		local i, j, icnt, jcnt, fb, fs, base, name
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		if m.reverse
			m.base = m.struc
			m.struc = this
		else
			m.base = this
		endif
		m.icnt = m.base.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		for m.i = 1 to m.icnt
			m.fb = m.base.getFieldStructure(m.i)
			m.name = m.fb.getName()
			for m.j = 1 to m.jcnt
				m.fs = m.struc.getFieldStructure(m.j)
				if m.name == m.fs.getName() 
					if m.fb.getType() == m.fs.getType() and;
					   m.fb.getSize() <= m.fs.getSize() and;
					   (m.fb.getType() != "N" or m.fb.getDecimal() <= m.fs.getDecimal())
						exit
					else
						return .f.
					endif
				endif
			endfor
			if m.j > m.jcnt
				return .f.
			endif
		endfor
		return .t.
	endfunc

	function checkNames(struc, reverse as Boolean)
		local i, j, icnt, jcnt, fb, fs, name, base
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		if m.reverse
			m.base = m.struc
			m.struc = this
		else
			m.base = this
		endif
		m.icnt = m.base.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		for m.i = 1 to m.icnt
			m.fb = m.base.getFieldStructure(m.i)
			m.name = m.fb.getName()
			for m.j = 1 to m.jcnt
				m.fs = m.struc.getFieldStructure(m.j)
				if m.name == m.fs.getName()
					exit
				endif
			endfor
			if m.j > m.jcnt
				return .f.
			endif
		endfor
		return .t.
	endfunc

	function checkTypes(struc, reverse as Boolean)
		local i, j, icnt, jcnt, fb, fs, name, base
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		if m.reverse
			m.base = m.struc
			m.struc = this
		else
			m.base = this
		endif
		m.icnt = m.base.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		for m.i = 1 to m.icnt
			m.fb = m.base.getFieldStructure(m.i)
			m.name = m.fb.getName()
			for m.j = 1 to m.jcnt
				m.fs = m.struc.getFieldStructure(m.j)
				if m.name == m.fs.getName() 
					if m.fb.getType() == m.fs.getType()
						exit
					else
						return .f.
					endif
				endif
			endfor
			if m.j > m.jcnt
				return .f.
			endif
		endfor
		return .t.
	endfunc

	function checkCompatibility(struc, reverse as Boolean)
		local i, j, icnt, jcnt, fb, fs, name, base
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		if m.reverse
			m.base = m.struc
			m.struc = this
		else
			m.base = this
		endif
		m.icnt = m.base.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		for m.i = 1 to m.icnt
			m.fb = m.base.getFieldStructure(m.i)
			m.name = m.fb.getName()
			for m.j = 1 to m.jcnt
				m.fs = m.struc.getFieldStructure(m.j)
				if m.name == m.fs.getName() 
					if m.fb.isCompatible(m.fs)
						exit
					else
						return .f.
					endif
				endif
			endfor
			if m.j > m.jcnt
				return .f.
			endif
		endfor
		return .t.
	endfunc

	function resize(struc, inclNull as Boolean)
		local i, j, icnt, jcnt, f, str, size, dec, null, type, ftype
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		m.icnt = this.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		m.str = ""
		for m.i = 1 to m.icnt
			m.type = this.tstruct[m.i,2]
			m.size = this.tstruct[m.i,3]
			m.dec = this.tstruct[m.i,4]
			m.null = this.tstruct[m.i,5]
			for m.j = 1 to m.jcnt
				m.f = m.struc.getFieldStructure(m.j)
				m.ftype = m.f.getType()
				if this.tstruct[m.i,1] == m.f.getName()
					if m.type == m.ftype
						m.size = max(m.f.getSize(),this.tstruct[m.i,3])
						m.dec = max(m.f.getDecimal(),this.tstruct[m.i,4])
						m.null = m.null or m.f.getNull()
					else
						if m.type == "C" and m.ftype == "M"
							m.type = m.ftype
							m.size = 4
							m.null = m.null or m.f.getNull()
						endif
					endif
					exit
				endif
			endfor
			m.f = createobject("FieldStructure", this.tstruct[m.i,1], m.type, m.size, m.dec, m.i, iif(m.inclNull,m.null,this.tstruct[m.i,5]))
			m.str = m.str+m.f.toString()+iif(m.i < m.icnt,", ","")
		endfor
		return createobject("TableStructure",m.str)
	endfunc

	function recast(struc, inclNull as Boolean)
		local i, j, icnt, jcnt, f, str, type, size, dec, null
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		m.icnt = this.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		m.str = ""
		for m.i = 1 to m.icnt
			m.type = this.tstruct[m.i,2]
			m.size = this.tstruct[m.i,3]
			m.dec = this.tstruct[m.i,4]
			m.null = this.tstruct[m.i,5]
			for m.j = 1 to m.jcnt
				m.f = m.struc.getFieldStructure(m.j)
				if this.tstruct[m.i,1] == m.f.getName()
					m.type = m.f.getType()
					m.size = m.f.getSize()
					m.dec = m.f.getDecimal()
					m.null = m.f.getNull()
					exit
				endif
			endfor
			m.f = createobject("FieldStructure",this.tstruct[m.i,1], m.type, m.size, m.dec, m.i, iif(m.inclNull,m.null,this.tstruct[m.i,5]))
			m.str = m.str+m.f.toString()+iif(m.i < m.icnt,", ","")
		endfor
		return createobject("TableStructure",m.str)
	endfunc

	function adjust(struc)
		local i, j, icnt, jcnt, f1, f2, f3, str, name
		if vartype(m.struc) == "O"
			m.struc = m.struc.getTableStructure()
		else
			m.struc = createobject("TableStructure",m.struc)
		endif
		m.icnt = this.getFieldCount()
		m.jcnt = m.struc.getFieldCount()
		m.str = ""
		for m.i = 1 to m.icnt
			m.f1 = this.getFieldStructure(m.i)
			m.f3 = m.f1
			m.name = m.f1.getName()
			for m.j = 1 to m.jcnt
				m.f2 = m.struc.getFieldStructure(m.j)
				if m.name == m.f2.getName()
					m.f3 = m.f1.compatibleFieldStructure(m.f2)
					exit
				endif
			endfor
			if m.f3.isValid()
				m.str = m.str+m.f3.toString()+","
			else
				m.str = m.str+m.f1.toString()+","
			endif
		endfor
		return createobject("TableStructure",rtrim(m.str,","))
	endfunc

	function getRecordSize()
	local null, size, i, f, icnt
		m.null = 0
		m.size = 0
		m.icnt = this.getFieldCount()
		for m.i = 1 to m.icnt
			m.f = this.getFieldStructure(m.i)
			m.size = m.size+m.f.getSize()
			if m.f.getNull()
				m.null = m.null+1
			endif
		endfor
		if m.null > 0
			m.size = m.size + int(m.null/8) + 1
		endif
		if m.size > 0
			m.size = m.size + 1
		endif
		return m.size
	endfunc
	
	function getFieldStructure(ind)
	local f
		if vartype(m.ind) == "C"
			m.ind = this.getFieldIndex(m.ind)
		endif
		if m.ind > this.getFieldCount() or m.ind < 1
			return createobject("FieldStructure")
		endif
		try
			m.f = createobject(this.tstruct[m.ind,2]+"FieldStructure",this.tstruct[m.ind,1], this.tstruct[m.ind,3], this.tstruct[m.ind,4], m.ind, this.tstruct[m.ind,5])
		catch
			m.f = createobject("FieldStructure",this.tstruct[m.ind,1], this.tstruct[m.ind,2], this.tstruct[m.ind,3], this.tstruct[m.ind,4], m.ind, this.tstruct[m.ind,5])
		endtry
		return m.f
	endfunc

	function getFieldIndex(field)
		local i
		m.field = alltrim(upper(m.field))
		for m.i = 1 to this.getFieldCount()
			if m.field == this.tstruct[m.i,1]
				return m.i
			endif
		endfor
		return 0
	endfunc

	function getStructureWithout(names)
		local i, icnt, f, str
		if vartype(m.names) == "C"
			m.names = createobject("TableStructure",m.names)
		endif
		m.icnt = this.getFieldCount()
		m.str = ""
		for m.i = 1 to m.icnt
			m.f = this.getFieldStructure(m.i)
			if m.names.getFieldIndex(m.f.getName()) == 0
				m.str = m.str+", "+m.f.toString()
			endif
		endfor
		return createobject("TableStructure",substr(m.str,3))
	endfunc

	function getStructureWith(names)
		local i, icnt, f, str
		if vartype(m.names) == "C"
			m.names = createobject("TableStructure",m.names)
		endif
		m.icnt = this.getFieldCount()
		m.str = ""
		for m.i = 1 to m.icnt
			m.f = this.getFieldStructure(m.i)
			if m.names.getFieldIndex(m.f.getName()) > 0
				m.str = m.str+", "+m.f.toString()
			endif
		endfor
		return createobject("TableStructure",substr(m.str,3))
	endfunc

	function getFieldList(alias as String) 
	local str, i
		if not this.isValid()
			return ""
		endif
		m.str = ""
		if vartype(m.alias) == "C"
			m.alias = upper(alltrim(m.alias))+"."
			for m.i = 1 to alen(this.tstruct,1)
				m.str = m.str+m.alias+this.tstruct[m.i,1]+", "
			endfor
		else	
			for m.i = 1 to alen(this.tstruct,1)
				m.str = m.str+this.tstruct[m.i,1]+", "
			endfor
		endif
		return rtrim(m.str,", ")
	endfunc
	
	function getSQLDefault()
	local sql, ind, f
		if not this.isValid()
			return ""
		endif
		m.sql = ""
		for m.ind = 1 to alen(this.tstruct,1)
			try
				m.f = createobject(this.tstruct[m.ind,2]+"FieldStructure",this.tstruct[m.ind,1], this.tstruct[m.ind,3], this.tstruct[m.ind,4], m.ind, this.tstruct[m.ind,5])
			catch
				m.f = createobject("FieldStructure",this.tstruct[m.ind,1], this.tstruct[m.ind,2], this.tstruct[m.ind,3], this.tstruct[m.ind,4], m.ind, this.tstruct[m.ind,5])
			endtry
			m.sql = m.sql+", "+m.f.sqlConverter()
		endfor
		return substr(m.sql,3)
	endfunc
			

	function getExpressionList(exp as String, placeholder as String) 
	local str, i
		if not this.isValid()
			return ""
		endif
		if not vartype(m.placeholder) == "C" or empty(m.placeholder)
			m.placeholder = "*"
		endif
		m.str = ""
		for m.i = 1 to alen(this.tstruct,1)
			m.str = m.str+strtran(m.exp,m.placeholder,this.tstruct[m.i,1])+", "
		endfor
		return rtrim(m.str,", ")
	endfunc

	function toString
		local str, f, i
		if not this.isValid()
			return ""
		endif
		m.str = ""
		for m.i = 1 to alen(this.tstruct,1)
			m.f = this.getFieldStructure(m.i)
			m.str = m.str+m.f.toString()+", "
		endfor
		return left(m.str,len(m.str)-2)
	endfunc
enddefine

define class TableStructureJoin as custom
	protected structureA, structureB, joinAB[1,4], joins

	function init(strucA, strucB)
		if vartype(m.strucA) == "O"
			this.structureA = m.strucA
		else
			if vartype(m.strucA) == "C"
				this.structureA = createobject("TableStructure",m.strucA)
			else
				this.structureA = createobject("TableStructure")
			endif
		endif
		if vartype(m.strucB) == "O"
			this.structureB = m.strucB
		else
			if vartype(m.strucB) == "C"
				this.structureB = createobject("TableStructure",m.strucB)
			else
				this.structureB = createobject("TableStructure")
			endif
		endif
		this.joinAB[1,1] = ""
		this.joinAB[1,2] = ""
		this.joinAB[1,3] = 0
		this.joinAB[1,4] = 0
		this.joins = 1
	endfunc

	protected function getIndex(str,ab,cnt)
		local i
		if not vartype(m.cnt) == "N"
			m.cnt = 1
		endif
		m.str = alltrim(upper(m.str))
		for m.i = 2 to this.joins
			if this.joinAB[m.i,m.ab] == m.str
				m.cnt = m.cnt-1
				if m.cnt <= 0
					return m.i
				endif
			endif
		endfor
		return 1
	endfunc

	protected function getAB(ind,ab,cnt)
		if vartype(m.ind) == "C"
			m.ind = this.getIndex(m.ind,m.ab,m.cnt)
		else
			m.ind = m.ind+1
			if m.ind > this.joins
				m.ind = 1
			endif
		endif
		return m.ind
	endfunc

	function isValid()
		return this.structureA.isValid() and this.structureB.isValid()
	endfunc

	function getJoinCount()
		return this.joins-1
	endfunc

	function getBofA(a,cnt)
		return this.structureB.getFieldStructure(this.joinAB[this.getAB(m.a,1,m.cnt),4])
	endfunc

	function getAofB(b,cnt)
		return this.structureA.getFieldStructure(this.joinAB[this.getAB(m.b,2,m.cnt),3])
	endfunc

	function getA(a,cnt)
		return this.structureA.getFieldStructure(this.joinAB[this.getAB(m.a,1,m.cnt),3])
	endfunc

	function getB(b,cnt)
		return this.structureB.getFieldStructure(this.joinAB[this.getAB(m.b,2,m.cnt),4])
	endfunc
	
	function getTableIndexOfA(a,cnt)
		return this.joinAB[this.getAB(m.a,1,m.cnt),3]
	endfunc

	function getTableIndexOfB(b,cnt)
		return this.joinAB[this.getAB(m.b,2,m.cnt),4]
	endfunc

	function getJoinIndexOfA(a,cnt)
		return this.getAB(m.a,1,m.cnt)-1
	endfunc

	function getJoinIndexOfB(b,cnt)
		return this.getAB(m.b,2,m.cnt)-1
	endfunc

	function getJoinIndexOfAB(a,b)
	local i
		m.a = this.getA(m.a)
		m.b = this.getb(m.b)
		if not m.a.isValid() or not m.b.isValid()
			return 0
		endif
		for m.i = 2 to this.joins
			if this.joinAB[m.i,1] == m.a.getName() and this.joinAB[m.i,2] == m.b.getName()
				return m.i-1
			endif
		endfor
		return 0
	endfunc

	function getTableStructureA
		return this.structureA
	endfunc

	function getTableStructureB
		return this.structureB
	endfunc

	function getJoinedTableStructureA()
	local i, struc
		m.struc = ""
		for m.i = 2 to this.joins
			m.struc = m.struc+","+this.joinAB[m.i,1]
		endfor
		m.struc = ltrim(m.struc,",")
		return this.structureA.getStructureWith(m.struc)
	endfunc
			
	function getJoinedTableStructureB()
	local i, struc
		m.struc = ""
		for m.i = 2 to this.joins
			m.struc = m.struc+","+this.joinAB[m.i,2]
		endfor
		m.struc = ltrim(m.struc,",")
		return this.structureB.getStructureWith(m.struc)
	endfunc
	
	function join(a,b)
		local alen
		m.a = this.structureA.getFieldStructure(m.a)
		if not m.a.isValid()
			return .f.
		endif
		m.b = this.structureB.getFieldStructure(m.b)
		if not m.b.isValid()
			return .f.
		endif
		if this.getJoinIndexOfAB(m.a.getName(),m.b.getName()) > 0
			return .t.
		endif
		this.joins = this.joins+1
		m.alen = alen(this.joinAB,1)
		if this.joins > m.alen
			dimension this.joinAB[m.alen+10,4]
		endif
		this.joinAB[this.joins,1] = m.a.getName()
		this.joinAB[this.joins,2] = m.b.getName()
		this.joinAB[this.joins,3] = m.a.getIndex()
		this.joinAB[this.joins,4] = m.b.getIndex()
		return .t.
	endfunc

	function unjoin(a,b)
		local i
		if parameters() == 0
			dimension this.joinAB[1,4]
			this.joins = 1
			return .t.
		endif
		m.a = this.getA(m.a)
		m.b = this.getb(m.b)
		if not m.a.isValid() or not m.b.isValid()
			return .f.
		endif
		for m.i = 2 to this.joins
			if this.joinAB[m.i,1] == m.a.getName() and this.joinAB[m.i,2] == m.b.getName()
				adel(this.joinAB,m.i)
				this.joins = this.joins-1
				return .t.
			endif
		endfor
		return .f.
	endfunc

	function unjoinA(a)
		local i, old
		m.a = this.getA(m.a)
		if not m.a.isValid()
			return .f.
		endif
		m.old = this.joins
		m.i = 2
		do while m.i <= this.joins
			if this.joinAB[m.i,1] == m.a.getName()
				adel(this.joinAB,m.i)
				this.joins = this.joins-1
			else
				m.i = m.i+1
			endif
		enddo
		return m.old > this.joins
	endfunc

	function unjoinB(b)
		local i, old
		m.b = this.getb(m.b)
		if not m.b.isValid()
			return .f.
		endif
		m.old = this.joins
		m.i = 2
		do while m.i <= this.joins
			if this.joinAB[m.i,2] == m.b.getName()
				adel(this.joinAB,m.i)
				this.joins = this.joins-1
			else
				m.i = m.i+1
			endif
		enddo
		return m.old > this.joins
	endfunc

	function copy
		local tsj, i
		m.tsj = createobject("TableStructureJoin",this.structureA,this.structureB)
		for m.i = 2 to this.joins
			m.tsj.join(this.joinAB[m.i,1],this.joinAB[m.i,2])
		endfor
		return m.tsj
	endfunc

	function toString
		local i,f, str
		m.str = ""
		for m.i = 1 to this.getJoinCount()
			m.f = this.getA(m.i)
			m.str = m.str+proper(m.f.getName())
			m.f = this.getb(m.i)
			m.str = m.str+" = "+proper(m.f.getName())
			m.str = m.str+", "
		endfor
		return left(m.str,len(m.str)-2)
	endfunc
enddefine

define class BaseTable as custom
	protected dbf, requiredStructure, requiredKeys, optionalStructure
	protected TableStructure, validAlias, validStructure, validKeys, validOptional, valid
	protected Messenger, cursor
	alias = ""
	dbf = ""
	validAlias = .f.
	validStructure = .f.
	validKeys = .f.
	cursor = .f.
	errorCancel = .f.

	function init(table)
		this.initObjects()
		if vartype(m.table) == "O"
			this.cursor = m.table.isCursor()
			m.table = m.table.getAlias()
		endif
		if not vartype(m.table) == "C"
			return
		endif
		this.setHandle(m.table)
		this.validAlias = .f.
		this.open()
	endfunc
	
	protected function setHandle(handle)
		if select(m.handle) > 0
			this.alias = m.handle
			this.dbf = dbf(this.alias)
			this.TableStructure = createobject("TableStructure",this.alias,.t.)
			this.validAlias = .t.
			this.validStructure = this.requiredStructure.checkStructure(this.TableStructure)
			this.validOptional = this.optionalStructure.checkStructure(this.TableStructure)
			this.checkValidKeys()
			this.checkValid()
			return 
		endif
		this.validAlias = .f.
		this.validStructure = .f.
		this.validOptional = .f.
		this.validKeys = .f.
		this.valid = .f.
		this.TableStructure = createobject("TableStructure")
		this.alias = ""
		if not empty(m.handle)
			this.dbf = createobject("String",fullpath(alltrim(m.handle)))
			this.dbf = this.dbf.getFileExtensionChange("DBF",.t.)
		endif
		return
	endfunc

	protected function initObjects()
		if vartype(this.requiredStructure) != "O"
			this.requiredStructure = createobject("TableStructure")
		endif
		if vartype(this.requiredKeys) != "O"
			this.requiredKeys = createobject("StringList")
		endif
		if vartype(this.optionalStructure) != "O"
			this.optionalStructure = createobject("TableStructure")
		endif
		if vartype(this.Messenger) != "O"
			this.Messenger = createobject("Messenger",this.errorCancel)
			this.Messenger.setInterval(2)
		endif
		if vartype(this.TableStructure) != "O"
			this.TableStructure = createobject("TableStructure")
		endif
	endfunc

	protected function destroy
		this.close()
	endfunc

	protected function setRequiredTableStructure(reqStruc)
		if inlist(vartype(m.reqStruc),"C","O")
			this.requiredStructure = createobject("TableStructure", m.reqStruc)
		else
			this.requiredStructure = createobject("TableStructure")
		endif
		if this.validAlias
			this.validStructure = this.requiredStructure.checkStructure(this.tableStructure)
		else
			this.validStructure = .f.
		endif
	endfunc

	protected function setOptionalTableStructure(optStruc)
		if inlist(vartype(m.optStruc),"C","O")
			this.optionalStructure = createobject("TableStructure", m.optStruc)
		else
			this.optionalStructure = createobject("TableStructure")
		endif
		if this.validAlias
			this.validOptional = this.optionalStructure.checkStructure(this.tableStructure)
		else
			this.validOptional = .f.
		endif		
	endfunc

	protected function setRequiredKeys(reqStruc)
		if vartype(m.reqStruc) != "C"
			this.requiredKeys = createobject("StringList")
		else
			this.requiredKeys = createobject("StringList", m.reqStruc)
		endif
		this.checkValidKeys()
	endfunc

	protected function checkValidKeys
		local i, item, pos, option
		if not this.validAlias
			return .f.
		endif
		for m.i = 1 to this.requiredKeys.getItemCount()
			m.item = this.requiredKeys.getItem(m.i)
			m.pos = rat(" ", m.item)
			m.pos = evl(m.pos,len(m.item)+1)
			m.option = lower(alltrim(substr(m.item,m.pos+1)))
			if inlist(m.option,"candidate","unique")
				m.item = substr(m.item,1,m.pos-1)
			endif
			if not this.hasKey(m.item)
				this.validKeys = .f.
				return .f.
			endif
		endfor
		this.validKeys = .t.
		this.checkValid()
		return .t.
	endfunc
	
	protected function checkValid()
		this.valid = this.validAlias and this.validStructure and this.validKeys
		return this.valid
	endfunc
	
	protected function resizeRequirements
		if this.validAlias
			this.requiredStructure = this.requiredStructure.resize(this.tableStructure)
			this.validStructure = this.requiredStructure.checkStructure(this.tableStructure)
			this.checkValid()
		endif
	endfunc

	protected function recastRequirements
		if this.validAlias
			this.requiredStructure = this.requiredStructure.recast(this.tableStructure,.t.)
			this.validStructure = this.requiredStructure.checkStructure(this.tableStructure)
			this.checkValid()
		endif
	endfunc

	protected function resizeOptionals
		if this.validAlias
			this.optionalStructure = this.optionalStructure.resize(this.tableStructure)
			this.validOptional = this.optionalStructure.checkStructure(this.tableStructure)
			this.checkValid()
		endif
	endfunc

	protected function recastOptionals
		if this.validAlias
			this.optionalStructure = this.optionalStructure.recast(this.tableStructure,.t.)
			this.validOptional = this.optionalStructure.checkStructure(this.tableStructure)
			this.checkValid()
		endif
	endfunc

	function exists()
		return file(this.dbf)
	endfunc

	function create(struc)
		local create, pa, err, opt
		if not this.isCreatable()
			return .f.
		endif
		if vartype(m.struc) == "C"
			m.struc = createobject("TableStructure",m.struc)
		endif
		if not vartype(m.struc) == "O"
			m.struc = this.getRequiredTableStructure()
			m.opt = this.getOptionalTableStructure()
			if m.opt.getFieldCount() > 0
				if m.struc.getFieldCount() > 0
					m.struc = createobject("TableStructure",m.struc.toString()+","+m.opt.toString())
				else
					m.struc = m.opt
				endif
			endif
		endif
		if not m.struc.isValid()
			return .f.
		endif
		m.pa = createobject("PreservedAlias")
		m.create = 'create table "'+proper(this.dbf)+'" ('+m.struc.toString()+')'
		m.err = .f.
		try
			&create
		catch
			m.err = .t.
		endtry
		if m.err
			return .f.
		endif
		this.setHandle(alias())
		this.forceRequiredKeys()
		this.useShared()
		return .t.
	endfunc
	
	function pseudoCreate(struc)
		local rc, rk
		m.rk = this.requiredKeys
		this.requiredKeys = createobject("StringList")
		if vartype(m.struc) == "C"
			m.struc = createobject("TableStructure",m.struc)
		endif
		if not vartype(m.struc) == "O"
			if this.requiredStructure.isValid()
				m.struc = this.requiredStructure
			else
				m.struc = createobject("TableStructure","dummy n(1)")
			endif
		endif
		m.rc = BaseTable::create(m.struc)
		BaseTable::erase()
		this.requiredKeys = m.rk
		return m.rc
	endfunc

	function synchronizeDBF() && wenn externe Funktionen den Alias verändert haben (bei gleicher DBF)
		local aa, i
		dimension aa[1,2]
		for m.i = aused(m.aa) to 1 step -1
			if this.dbf == dbf(m.aa[m.i,1])
				this.setHandle(m.aa[m.i,1])
				return
			endif
		endfor
		this.setHandle(this.dbf)
	endfunc

	function synchronize() && wenn externe Funktionen die DBF verändert haben (bei gleichem Alias)
		if select(this.alias) > 0
			this.setHandle(this.alias)
			return
		endif
		this.setHandle(this.dbf)
	endfunc

	function isCreatable
		if this.validAlias or this.exists() or empty(this.getName())
			return .f.
		endif
		return .t.
	endfunc

	function erase
		local pa, str, err
		m.str = createobject("String",this.getDBF())
		if this.hasValidAlias()
			m.pa = createobject("PreservedAlias")
			select (this.alias)
			use
		endif
		m.err = .f.
		try
			erase m.str.toString()
		catch
			m.err = .t.
		endtry
		if m.err == .f.
			try
				erase m.str.fileExtensionChange("cdx")
				erase m.str.fileExtensionChange("fpt")
				erase m.str.fileExtensionChange("idx")
				erase m.str.fileExtensionChange("ndx")
			catch
			endtry
		endif
		this.setHandle(this.getDBF())
		return not this.exists()
	endfunc

	function zap
		local alias, ps, ok, shared
		m.shared = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		m.ps = createobject("PreservedSetting","safety","off")
		m.alias = this.getAlias()
		m.ok = .t.
		try
			zap in (m.alias)
		catch
			m.ok = .f.
		endtry
		if m.shared
			this.useShared()
		endif
		return m.ok
	endfunc

	function getRequiredTableStructure
		return this.requiredStructure
	endfunc

	function getRequiredKeys
		return this.requiredKeys
	endfunc
	
	function getOptionalTableStructure
		return this.optionalStructure
	endfunc

	function getCompleteTableStructure()
		return createobject("TableStructure",rtrim(this.requiredStructure.toString()+","+this.optionalStructure.toString(),","))
	endfunc

	function hasValidOptionalStructure
		return this.validOptional
	endfunc
	
	function getTableStructure
		return this.TableStructure
	endfunc

	function getFieldStructure(field)
		return this.tableStructure.getFieldStructure(m.field)
	endfunc

	function hasField(field)
		return not type(this.alias+"."+ltrim(m.field)) == "U"
	endfunc

	function isValid
		return this.valid
	endfunc
	
	function isCompatible()
		return this.tablestructure.isCompatible()
	endfunc

	function hasValidStructure
		return this.validStructure
	endfunc

	function hasValidAlias
		return this.validAlias
	endfunc

	function hasValidKeys()
		return this.validKeys
	endfunc

	function getMessenger
		return this.Messenger
	endfunc

	function setMessenger(Messenger)
		this.Messenger = m.Messenger
	endfunc

	function getAlias
		return this.alias
	endfunc

	function getDBF
		return this.dbf
	endfunc

	function getName
		local dbf, pos
		m.dbf = this.getDBF()
		m.pos = rat("\",m.dbf)
		if m.pos < 1
			return m.dbf
		endif
		return right(m.dbf,len(m.dbf)-m.pos)
	endfunc

	function getPureName
	local name, pos
		m.name = this.getName()
		m.pos = rat(".",m.name)
		if m.pos < 1
			return m.name
		endif
		return left(m.name,m.pos-1)
	endfunc

	function getPath
		return left(this.dbf,rat("\",this.dbf))
	endfunc

	function getValue(field)
		return evaluate(this.alias+"."+alltrim(m.field))
	endfunc

	function getValueAsString(field)
		local str
		m.str = createobject("String",this.getValue(m.field))
		return m.str.toString()
	endfunc

	function setValue(field,val)
		local ok
		m.ok = .t.
		try
			replace (m.field) with m.val in (this.alias)
		catch
			m.ok = .f.
		endtry
		return m.ok
	endfunc

	function setValueAsString(field, val)
	local f
		m.f = this.getFieldStructure(m.field)
		if not m.f.isValid()
			return .f.
		endif
		m.val = m.f.transform(m.val)
		return this.setValue(m.field,m.val)
	endfunc

	function getRecno()
		if this.validAlias
			return recno(this.alias)
		endif
		return 0
	endfunc

	function getReccount()
		if this.validAlias
			return reccount(this.alias)
		endif
		return 0
	endfunc

	function eof()
		if this.validAlias
			return eof(this.alias)
		endif
		return .t.
	endfunc

	function bof()
		if this.validAlias
			return bof(this.alias)
		endif
		return .t.
	endfunc

	protected function getFreeExpTag()
		local t, i, exp, maxexp
		if not this.validAlias
			return 0
		endif
		m.maxexp = 0
		m.i = 1
		m.t = tag(m.i,this.alias)
		do while not empty(m.t)
			m.t = upper(alltrim(m.t))
			if left(m.t,3) == "EXP"
				m.t = right(m.t,len(m.t)-3)
				m.exp = val(m.t)
				if ltrim(str(m.exp)) == m.t and m.exp > m.maxexp
					m.maxexp = m.exp
				endif
			endif
			m.i = m.i+1
			m.t = tag(m.i,this.alias)
		enddo
		return "EXP"+ltrim(str(m.maxexp+1))
	endfunc

	function seekKey(key)
		local k, i
		if not this.validAlias
			return 0
		endif
		m.key = upper(alltrim(m.key))
		m.i = 1
		m.k = key(m.i,this.alias)
		do while not empty(m.k)
			if upper(alltrim(m.k)) == m.key
				return m.i
			endif
			m.i = m.i+1
			m.k = key(m.i,this.alias)
		enddo
		return 0
	endfunc

	function setKey(key)
		local ok
		if not this.validAlias
			return .f.
		endif
		if vartype(m.key) == "N"
			if m.key <= 0
				return .f.
			endif
			m.key = tag(m.key,this.alias)
			if empty(m.key)
				return .f.
			endif
		else
			if not vartype(m.key) == "C" or empty(m.key)
				m.key = ""
			else
				m.key = this.seekKey(m.key)
				if m.key <= 0
					return .f.
				endif
				m.key = tag(m.key,this.alias)
			endif
		endif
		m.ok = .t.
		try
			set order to tag (m.key) in (this.alias)
		catch
			m.ok = .f.
		endtry
		return m.ok
	endfunc

	function getkey(key)
		local pa
		if not this.validAlias
			return ""
		endif
		if vartype(m.key) == "N"
			return key(m.key,this.alias)
		endif
		m.pa = createobject("PreservedAlias")
		this.select()
		return key()
	endfunc

	function hasKey(key)
		if vartype(m.key) == "N"
			m.key = key(m.key,this.alias)
		endif
		return this.seekKey(m.key) > 0
	endfunc

	function forceKey(key, options)
	local index, pa, ok, shared
		if not this.validAlias
			return .f.
		endif
		if this.setKey(m.key)
			return .t.
		endif
		m.shared = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		if not vartype(m.options) == "C"
			m.options = ""
		else
			m.options = " "+m.options
		endif
		m.index = "index on "+m.key+" tag "+m.key+m.options
		m.pa = createobject("PreservedAlias")
		this.select()
		m.ok = .t.
		try
			&index
		catch
			m.ok = .f.
		endtry
		if not m.ok
			m.ok = .t.
			m.index = "index on "+m.key+" tag "+this.getFreeExpTag()+m.options
			try
				&index
			catch
				m.ok = .f.
			endtry
		endif
		if m.ok
			this.checkValidKeys()
		endif
		if m.shared
			this.useShared()
		endif
		return m.ok
	endfunc

	function deleteKey(key)
		local ps, shared, ok, pa
		if not this.validAlias
			return .f.
		endif
		m.shared = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		m.pa = createobject("PreservedAlias")
		m.ps = createobject("PreservedSetting","safety","off")
		this.select()
		m.ok = .t.
		if not vartype(m.key) == "C" or empty(m.key)
			delete tag all
		else
			m.key = this.seekKey(m.key)
			if m.key > 0
				m.key = tag(m.key)
				try
					delete tag (m.key)
				catch
					m.ok = .f.
				endtry
			else
				m.ok = .f.
			endif
		endif
		if m.shared
			this.useShared()
		endif
		if m.ok
			this.checkValidKeys()
		endif
		return m.ok
	endfunc

	function forceRequiredKeys
	local i, ok, share, pk, item, option, pos
		m.share = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		m.pk = createobject("PreservedKey",this)
		m.ok = .t.
		for m.i = 1 to this.requiredKeys.getItemCount()
			m.item = this.requiredKeys.getItem(m.i)
			m.pos = rat(" ", m.item)
			m.pos = evl(m.pos,len(m.item)+1)
			m.option = lower(alltrim(substr(m.item,m.pos+1)))
			if inlist(m.option,"candidate","unique")
				m.item = substr(m.item,1,m.pos-1)
			else
				m.option = ""
			endif
			m.ok = m.ok and this.forceKey(m.item, m.option)
		endfor
		if m.share
			this.useShared()
		endif
		return m.ok
	endfunc

	function reindex
		local pa, share
		m.share = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		m.pa = createobject("PreservedAlias")
		this.select()
		reindex
		if m.share
			this.useShared()
		endif
		return .t.
	endfunc

	function pack(memo)
		local pa, share
		m.share = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		m.pa = createobject("PreservedAlias")
		this.select()
		if m.memo == .t.
			pack
		else
			pack dbf
		endif
		if m.share
			this.useShared()
		endif
		return .t.
	endfunc

	function select
		if not this.validAlias
			return .f.
		endif
		select (this.alias)
		return .t.
	endfunc

	function reccount()
		if not this.validAlias
			return 0
		endif
		return reccount(this.alias)
	endfunc

	function recno()
		if not this.validAlias
			return 0
		endif
		return recno(this.alias)
	endfunc

	function goTop
		if not this.validAlias
			return .f.
		endif
		go top in (this.alias)
		return .t.
	endfunc

	function goBottom
		if not this.validAlias
			return .f.
		endif
		go bottom in (this.alias)
		return .t.
	endfunc

	function goRecord(rec)
		if not this.validAlias or m.rec < 1 or m.rec > reccount(this.alias)
			return .f.
		endif
		go record m.rec in (this.alias)
		return .t.
	endfunc

	function skip(n)
		if parameters() == 0
			m.n = 1
		endif
		if m.n >= 0
			if not this.eof()
				skip m.n in (this.alias)
			endif
			return not this.eof()
		endif
		if not this.bof()
			skip m.n in (this.alias)
		endif
		return not this.bof()
	endfunc

	function trySkip(n)
	local rec, rc
		m.rec = this.getRecord()
		m.rc = this.skip(m.n)
		this.goRecord(m.rec)
		return m.rc
	endfunc
	
	function getPosition()
		if this.eof()
			return this.reccount()+1
		endif
		if this.bof()
			return -1
		endif
		return this.recno()
	endfunc
	
	function setPosition(pos)
		if m.pos <= 0
			this.goTop()
			this.skip(-1)
			return
		endif
		if m.pos > this.reccount()
			this.goBottom()
			this.skip(1)
			return
		endif
		this.goRecord(m.pos)
	endfunc
		

	function useExclusive()
		local sel, err, pa, pk, ps
		if this.isexclusive()
			return .t.
		endif
		m.pa = createobject("PreservedAlias")
		m.pk = createobject("PreservedKey", this)
		m.ps = createobject("PreservedSetting","cpdialog","off")
		if this.validAlias
			this.select()
			use
		endif
		m.sel = select(1)
		m.err = .f.
		try
			use (this.dbf) in (m.sel) exclusive again
		catch
			m.err = .t.
		endtry
		if m.err
			m.err = .f.
			try
				use (this.dbf) in (m.sel) shared again
			catch
				m.err = .t.
			endtry
			if m.err
				this.setHandle(this.alias)
				return .f.
			endif
		endif
		select (m.sel)
		this.setHandle(alias())
		return this.isexclusive()
	endfunc

	function useShared()
		local sel, pa, pk, err
		if this.isShared()
			return .t.
		endif
		m.pa = createobject("PreservedAlias")
		m.pk = createobject("PreservedKey", this)
		if this.validAlias
			this.select()
			use
		endif
		m.sel = select(1)
		m.err = .f.
		try
			use (this.dbf) in (m.sel) shared again
		catch
			m.err = .t.
		endtry
		if m.err
			this.setHandle(this.alias)
			return .f.
		endif
		select (m.sel)
		this.setHandle(alias())
		return .t.
	endfunc

	function isexclusive
		if not this.validAlias
			return .f.
		endif
		return isexclusive(this.alias)
	endfunc

	function isShared
		if not this.validAlias
			return .f.
		endif
		return not isexclusive(this.alias)
	endfunc
	
	function setCursor(cursor)
		if not vartype(m.cursor) == "L"
			return .f.
		endif
		this.cursor = m.cursor
		return .t.
	endfunc		

	function isCursor()
		return this.cursor
	endfunc

	function lockTable()
		if not this.validAlias
			return .f.
		endif
		return flock(this.alias)
	endfunc

	function lockRecord()
		if not this.validAlias
			return .f.
		endif
		return lock(this.alias)
	endfunc

	function unlock()
		if not this.validAlias
			return .f.
		endif
		unlock in (this.alias)
		return .t.
	endfunc

	function isRecordLocked()
		if not this.validAlias
			return .f.
		endif
		return isrlocked(recno(this.alias),this.alias)
	endfunc

	function isTableLocked()
		if not this.validAlias
			return .f.
		endif
		return isflock(this.alias)
	endfunc

	function copy()
		local cursor
		m.cursor = createobject("CopyCursor",this)
		this.copyKeys(m.cursor)
		return createobject(this.class,m.cursor)
	endfunc

	function copyFrame()
		local cursor
		m.cursor = createobject("StructureCursor",this)
		this.copyKeys(m.cursor)
		return createobject(this.class,m.cursor)
	endfunc

	function copyKeys(table)
		local i
		m.i = 1
		do while not empty(this.getkey(m.i))
			m.table.forceKey(this.getkey(m.i))
			m.i = m.i+1
		enddo
	endfunc

	function modifyStructure(struc)
	local alter, shared, i, pk, f, ok
		if vartype(m.struc) == "C"
			m.struc = createobject("TableStructure",m.struc)
		endif
		if not m.struc.isValid()
			return .f.
		endif
		m.shared = this.isShared()
		if not this.useExclusive()
			return .f.
		endif
		m.alter = "alter table "+this.getAlias()
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if this.hasField(m.f.getName())
				if m.f.null
					m.alter = m.alter+" alter "+m.f.toString()
				else
					m.alter = m.alter+" alter "+m.f.toString()+" NOT NULL"
				endif
			else
				m.alter = m.alter+" add "+m.f.toString()
			endif
		endfor
		m.pk = createobject("PreservedKey",this)
		m.ok = .t.
		try
			&alter
		catch
			m.ok = .f.
		endtry
		if m.ok
			this.setHandle(this.getAlias())
		endif
		if m.shared
			this.useShared()
		endif
		return m.ok
	endfunc
	
	function getRecordSize()
		if this.validAlias
			return recsize(this.alias)
		endif
		return this.tableStructure.getRecordSize()
	endfunc

	function getMemoSize()
	local size, i, f, blocksize, datasize, len
		if not this.validAlias
			return 0
		endif
		m.size = 0
		m.blocksize = int(val(sys(2012, this.alias)))
		m.datasize = m.blocksize - 8
		for m.i = 1 to this.tablestructure.getFieldCount()
			m.f = this.tablestructure.getFieldStructure(m.i)
			if m.f.getType() == "M"
				m.len = len(evaluate(this.alias+"."+m.f.getName()))
				if m.len > 0
					m.size = m.size + (int((m.len - 1) / m.datasize) + 1) * m.blocksize
				endif
			endif
		endfor
		return m.size
	endfunc

	function getDBFsize()
	local exclusive, size, comp
		if not file(this.dbf)
			return 0
		endif
		m.comp = "set compatible "+set("compatible")
		if this.validAlias
			m.exclusive = this.isExclusive()
			this.close()
			set compatible on
			m.size = fsize(this.dbf)
			&comp
			this.open()
			if m.exclusive
				this.useExclusive()
			endif
			return m.size
		else
			set compatible on
			m.size = fsize(this.dbf)
			&comp
		endif
		return m.size
	endfunc

	function getFPTsize()
	local ps, file, exclusive, size
		m.file = createobject("String",this.dbf)
		m.file = m.file.fileExtensionChange("fpt")
		if not file(m.file)
			return 0
		endif
		m.ps = createobject("PreservedSetting","compatible", "on")
		if this.validAlias
			m.exclusive = this.isExclusive()
			this.close()
			m.size = fsize(m.file)
			this.open()
			if m.exclusive
				this.useExclusive()
			endif
			return m.size
		endif
		return fsize(m.file)
	endfunc

	function close()
		local pa
		if this.isCursor()
			this.synchronizeDBF()
			this.erase()
			return .t.
		endif
		if not this.validAlias
			return .f.
		endif
		m.pa = createobject("PreservedAlias")
		this.synchronize()
		this.select()
		use
		this.setHandle(this.getDBF())
		return .t.
	endfunc

	function open()
		local sel, err
		if this.validAlias
			return .f.
		endif
		m.sel = select(1)
		m.err = .f.
		try
			use (this.dbf) in (m.sel) shared again
		catch
			m.err = .t.
		endtry
		if m.err
			this.setHandle("")
			return .f.
		endif
		this.setHandle(alias(m.sel))
		return .t.
	endfunc
		
	function toString(class)
		local str, i, s, f
		m.str = "Class: "
		if not vartype(m.class) == "C"
			m.str = m.str+proper(this.Class)
		else
			m.str = m.str+m.class
		endif
		m.str = m.str+chr(10)
		if this.validAlias
			m.str = m.str+"Alias: "+proper(this.getAlias())+chr(10)
		endif
		if empty(this.getName())
			return m.str
		endif
		m.str = m.str+"DBF: "+proper(this.getDBF())+chr(10)
		m.str = m.str+"Flags: "+iif(this.valid,"valid, ","")+iif(this.validAlias,"valid alias, ","")
		m.str = m.str+iif(this.validStructure, "valid structure, ","")
		m.str = m.str+iif(this.validKeys,"valid keys, ","")
		m.str = m.str+iif(this.isCreatable(),"creatable, ","")
		m.str = m.str+iif(this.isCursor(),"cursor, ","")+iif(this.isexclusive(),"exclusive, ","")
		m.str = m.str+iif(this.isShared(),"shared, ","")
		if right(m.str,2) == ", "
			m.str = left(m.str,len(m.str)-2)
		else
			m.str = m.str+"none"
		endif
		m.str = m.str+chr(10)
		if this.validAlias
			m.str = m.str+"Record: "+ltrim(str(this.recno()))+"/"+ltrim(str(this.reccount()))+chr(10)
		endif
		m.s = this.getRequiredTableStructure()
		if m.s.isValid()
			m.str = m.str+"RequiredStructure: "+m.s.toString()+chr(10)
		endif
		m.s = this.getRequiredKeys()
		if m.s.isValid()
			m.str = m.str+"RequiredKeys: "+proper(m.s.toString())+chr(10)
		endif
		m.s = this.getTableStructure()
		if m.s.isValid()
			m.str = m.str+"Structure: "+m.s.toString()+chr(10)
		endif
		m.f = this.getkey(1)
		if not empty(m.f)
			m.str = m.str+"Keys: "+proper(m.f)
			m.i = 2
			m.f = this.getkey(m.i)
			do while not empty(m.f)
				m.str = m.str+"; "+proper(m.f)
				m.i = m.i+1
				m.f = this.getkey(m.i)
			enddo
			m.str = m.str+chr(10)
		endif
		return m.str
	endfunc
enddefine

define class BaseCursor as BaseTable
	function init(struc,path) && can be swapped, last omitted
		local pa, t, i, swap, create
		this.cursor = .t.
		this.initObjects()
		this.setHandle("")
		if vartype(m.struc) == "C" and ("\" $ m.struc or "/" $ m.struc or ":" $ m.struc)
			m.swap = m.path
			m.path = m.struc
			m.struc = m.swap
		endif
		if vartype(m.struc) == "C"
			m.struc = createobject("TableStructure",m.struc)
		endif
		if not vartype(m.struc) == "O" or not m.struc.isValid()
			m.struc = createobject("TableStructure","dummy c(1)")
		endif
		m.pa = createobject("PreservedAlias")
		m.t = createobject("timing")
		m.i = 0
		if vartype(m.path) == "C"
			m.path = strtran(alltrim(m.path),"/","\")
			if right(m.path,1) != "\"
				m.path = m.path+"\"
			endif
			BaseTable::init(m.path+sys(3))
		else
			BaseTable::init(sys(2023)+"\"+sys(3))
		endif
		m.create = this.create(m.struc)
		do while not m.create and (m.i < 100 or m.t.elapsed() < 3)
			if vartype(m.path) == "C"
				BaseTable::init(m.path+sys(3))
			else
				BaseTable::init(sys(2023)+"\"+sys(3))
			endif
			m.create = this.create(m.struc)
			m.i = m.i+1
		enddo
		if not m.create
			this.setHandle("")
			return
		endif
		this.useExclusive()
	endfunc
enddefine

define class StructureCursor as BaseCursor
	function init(table, add)
	local create, struc, i, f
		this.initObjects()
		this.setHandle("")
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		m.table.synchronize()
		if not m.table.hasValidAlias()
			return
		endif
		m.struc = m.table.getTableStructure()
		if vartype(m.add) == "C"
			m.add = createobject("TableStructure",m.add)
		endif
		m.create = ""
		if vartype(m.add) == "O" and m.add.isValid()
			m.struc = m.struc.recast(m.add)
			for m.i = 1 to m.add.getFieldCount()
				m.f = m.add.getFieldStructure(m.i)
				if m.struc.getFieldIndex(m.f.getName()) < 1
					m.create = m.create+", "+m.f.toString()
				endif
			endfor
		endif
		m.create = m.struc.toString()+m.create
		BaseCursor::init(m.create)
	endfunc
enddefine

define class CopyCursor as StructureCursor
	function init(table, add)
		local pa
		StructureCursor::init(m.table, m.add)
		if not this.isValid()
			return
		endif
		m.pa = createobject("PreservedAlias")
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		this.select()
		try
			append from (m.table.getDBF())
		catch
		endtry
		this.goTop()
	endfunc
enddefine

define class DynamicArray as custom
	dimension data[1,1]
	rows = 0
	sortcol = 0
	sortrow = 0
	sortstart = 1
	inc = 100

	function init(width, depth, inc)
		if not vartype(m.depth) == "N"
			m.depth = 100
		else
			if vartype(m.inc) == "N"
				this.inc = m.inc
			endif
		endif
		dimension this.data[m.depth, max(m.width,1)]
	endfunc

	function append()
		this.rows = this.rows+1
		if this.rows > alen(this.data,1)
			dimension this.data[this.rows+this.inc-1,alen(this.data,2)]
		endif
	endfunc

	function sort(col,dir)
		sortcol = 0
		sortrow = 0
		sortstart = 1
		if this.rows < 1
			return
		endif
		this.sortcol = asubscript(this.data,m.col,2)
		this.sortrow = this.rows
		asort(this.data,this.sortcol,this.rows,iif(vartype(m.dir)=="N",m.dir,0))
	endfunc

	function search(key)
		local start, end, pivot, element
		m.start = this.sortstart
		m.end = this.sortrow
		do while m.start <= m.end
			m.pivot = int((m.end+m.start)/2)
			m.element = this.data[m.pivot,this.sortcol]
			if m.key == m.element
				return m.pivot
			endif
			if m.key > m.element
				m.start = m.pivot+1
			else
				m.end = m.pivot-1
			endif
		enddo
		return -m.start
	endfunc
enddefine

define class Stack as custom
	dimension elements[64]
	size = 0

	function push(element)
		this.size = this.size+1
		if this.size > alen(this.elements,1)
			dimension this.elements[this.size+64]
		endif
		this.elements[this.size] = m.element
	endfunc

	function pop()
		local e
		if this.size == 0
			return .f.
		endif
		m.e = this.elements[this.size]
		this.size = this.size-1
		return m.e
	endfunc

	function look(ind)
		if m.ind <= 0 or m.ind > this.size
			return .f.
		endif
		return this.elements[m.ind]
	endfunc

	function pushStack(Stack)
	local i, len
		m.len = m.Stack.stacked()
		for m.i = 1 to m.len
			this.push(Stack.look(m.i))
		endfor
	endfunc

	function stacked()
		return this.size
	endfunc

	function clear()
		this.size = 0
		dimension this.elements[64]
	endfunc
enddefine

define class LinearItem as Custom
	next = .null.
	prev = .null.
	item = .null.
	
	function init(item)
		this.item = m.item
	endfunc
	
	function destroy
	local release
		m.release = this
		release m.release
	endfunc
enddefine

define class LinearStack as Custom
	next = .null.
	last = .null.
	count = 0
	
	function init()
		this.last = this
	endfunc
	
	function push(item as Object)
		this.last.next = m.item
		m.item.prev = this.last
		m.item.next = .null.
		this.last = m.item
		this.count = this.count+1
	endfunc
	
	function pop()
	local item
		if this.last == this
			this.count = 0
			return .null.
		endif
		m.item = this.last
		this.last = this.last.prev
		this.last.next = .null.
		this.count = this.count-1
		m.item.next = .null.
		m.item.prev = .null.
		return m.item
	endfunc
	
	function peek()
		if this.last == this
			this.count = 0
			return .null.
		endif
		return this.last
	endfunc
	
	function pull()
	local item
		if this.last == this
			this.count = 0
			return .null.
		endif
		m.item = this.next
		if isnull(m.item.next)
			this.last = this
			this.next = .null.
		else
			this.next = m.item.next
			this.next.prev = this
		endif
		this.count = this.count - 1
		m.item.next = .null.
		m.item.prev = .null.
		return m.item
	endfunc
	
	function destroy()
	local item
		do while this.last != this
			m.item = this.last
			this.last = m.item.prev
			m.item.prev = .null.
			m.item.next = .null.
			release m.item
		enddo
		this.count = 0
		this.next = .null.
	endfunc
enddefine

define class HashItem as Custom
	hashkey = ""
	larger = .null.
	lesser = .null.
	next = .null.
	item = .null.
	
	function init(item)
		this.item = m.item
	endfunc
	
	function getKey()
		return getwordnum(this.binkey,2,chr(0))
	endfunc
	
	function destroy
	local release
		m.release = this
		release m.release
	endfunc
enddefine

define class HashTree as Custom
	root = .null.
	act = .null.
	last = .null.
	count = 0
	
	function traverse(key as String, item as Object)
	local insert, hashkey, prev, act
		m.insert = (vartype(item) == "O")
		m.hashkey = sys(2007,m.key)+chr(0)+m.key
		m.prev = this.root
		m.act = this.root
		do while not isnull(m.act)
			m.prev = m.act
			if m.hashkey == m.act.hashkey
				if m.insert
					return 0
				endif
				return m.act
			else
				if m.hashkey > m.act.hashkey
					m.act = m.act.larger
				else
					m.act = m.act.lesser
				endif
			endif
		enddo
		if m.insert
			if isnull(m.prev)
				this.root = m.item
				this.count = 1
				this.act = this.root
				this.last = this.root
			else
				if m.hashkey > m.prev.hashkey
					m.prev.larger = m.item
				else
					m.prev.lesser = m.item
				endif
				this.last.next = m.item
				this.last = m.item
				this.count = this.count+1
			endif
			m.item.hashkey = m.hashkey
			m.item.larger = .null.
			m.item.lesser = .null.
			m.item.next = .null.
			return this.count
		endif
		return .null.
	endfunc
	
	function next()
	local next
		m.next = this.act
		if isnull(m.next)
			return .null.
		endif
		this.act = m.next.next
		return m.next
	endfunc
	
	function rewind()
		this.act = this.root
	endfunc
	
	function destroy()
	local act, release
		m.act = this.root
		this.count = 0
		this.root = .null.
		this.act = .null.
		this.last = .null.
		do while not isnull(m.act)
			m.release = m.act
			m.act = m.act.next
			m.release.next = .null.
			m.release.larger = .null.
			m.release.lesser = .null.
			m.release.hashkey = .null.
			release m.release
		enddo
	endfunc
enddefine
				
define class StringNormizer as Custom
	dimension anorm[255]

	function init()
		local i
		for m.i = 1 to 191
			this.anorm[m.i] = " "
		endfor
		for m.i = 48 to 57
			this.anorm[m.i] = chr(m.i)
		endfor
		for m.i = 65 to 90
			this.anorm[m.i] = chr(m.i)
		endfor
		for m.i = 97 to 122
			this.anorm[m.i] = chr(m.i-32)
		endfor
		this.anorm[138] = "S"
		this.anorm[140] = "OE"
		this.anorm[154] = "S"
		this.anorm[156] = "OE"
		this.anorm[159] = "Y"
		this.anorm[192] = "A"
		this.anorm[193] = "A"
		this.anorm[194] = "A"
		this.anorm[195] = "A"
		this.anorm[196] = "AE"
		this.anorm[197] = "A"
		this.anorm[198] = "AE"
		this.anorm[199] = "C"
		this.anorm[200] = "E"
		this.anorm[201] = "E"
		this.anorm[202] = "E"
		this.anorm[203] = "E"
		this.anorm[204] = "I"
		this.anorm[205] = "I"
		this.anorm[206] = "I"
		this.anorm[207] = "I"
		this.anorm[208] = "T"
		this.anorm[209] = "N"
		this.anorm[210] = "O"
		this.anorm[211] = "O"
		this.anorm[212] = "O"
		this.anorm[213] = "O"
		this.anorm[214] = "OE"
		this.anorm[215] = " "
		this.anorm[216] = "O"
		this.anorm[217] = "U"
		this.anorm[218] = "U"
		this.anorm[219] = "U"
		this.anorm[220] = "UE"
		this.anorm[221] = "Y"
		this.anorm[222] = "TH"
		this.anorm[223] = "SS"
		this.anorm[224] = "A"
		this.anorm[225] = "A"
		this.anorm[226] = "A"
		this.anorm[227] = "A"
		this.anorm[228] = "AE"
		this.anorm[229] = "A"
		this.anorm[230] = "AE"
		this.anorm[231] = "C"
		this.anorm[232] = "E"
		this.anorm[233] = "E"
		this.anorm[234] = "E"
		this.anorm[235] = "E"
		this.anorm[236] = "I"
		this.anorm[237] = "I"
		this.anorm[238] = "I"
		this.anorm[239] = "I"
		this.anorm[240] = "T"
		this.anorm[241] = "N"
		this.anorm[242] = "O"
		this.anorm[243] = "O"
		this.anorm[244] = "O"
		this.anorm[245] = "O"
		this.anorm[246] = "OE"
		this.anorm[247] = " "
		this.anorm[248] = "O"
		this.anorm[249] = "U"
		this.anorm[250] = "U"
		this.anorm[251] = "U"
		this.anorm[252] = "UE"
		this.anorm[253] = "Y"
		this.anorm[254] = "TH"
		this.anorm[255] = "Y"
	endfunc
	
	function normize(str, keep)
		local i, l, norm, word, chr, nokeep
		if not vartype(m.keep) == "C"
			m.nokeep = .t.
			m.str = strtran(m.str,chr(0)," ")
		else
			m.nokeep = .f.
			if not chr(0) $ m.keep
				m.str = strtran(m.str,chr(0)," ")
			endif		
		endif
		m.str = m.str+" "
		m.l = len(m.str)
		m.norm = ""
		m.word = ""
		for m.i = 1 to m.l
			m.chr = substr(m.str,m.i,1)
			if m.nokeep or not m.chr $ m.keep
				m.chr = this.anorm[asc(m.chr)]
			endif
			if m.chr == " "
				if not m.word == ""
					m.norm = m.norm+" "+m.word
					m.word = ""
				endif
			else
				m.word = m.word+m.chr
			endif
		endfor				
		return ltrim(m.norm)
	endfunc

	function normizePositional(str, keep)
		local i, l, norm, chr, nokeep
		if not vartype(m.keep) == "C"
			m.nokeep = .t.
			m.str = strtran(m.str,chr(0)," ")
		else
			m.nokeep = .f.
			if not chr(0) $ m.keep
				m.str = strtran(m.str,chr(0)," ")
			endif		
		endif
		m.l = len(m.str)
		m.norm = ""
		for m.i = 1 to m.l
			m.chr = substr(m.str,m.i,1)
			if m.nokeep or not m.chr $ m.keep
				m.chr = left(this.anorm[asc(m.chr)],1)
			endif
			m.norm = m.norm+m.chr
		endfor				
		return m.norm
	endfunc
	
	function truncate(str as String, size as Integer)
	local pos
		m.str = rtrim(m.str)
		if len(m.str) <= m.size
			return m.str
		endif
		m.str = left(m.str, m.size)
		m.pos = rat(" ",this.normizePositional(m.str))
		if m.pos/len(m.str) <= 0.5
			return m.str
		endif
		return rtrim(left(m.str,m.pos))
	endfunc	
enddefine

define class UniDecoder as Custom
	dimension byte1[255]
	dimension byte2[16,64]
	
	function decode(str as String)
	local i, len, newstr, chr, asc, page
		m.len = len(m.str)
		m.newstr = ""
		for m.i = 1 to m.len
			m.chr = substr(m.str,m.i,1)
			m.asc = asc(m.chr)
			m.page = this.byte1[m.asc]
			if m.page > 0
				m.i = m.i+1
				m.asc = asc(substr(m.str,m.i,1))
				m.asc = m.asc-127
				if m.asc >= 1 and m.asc <= 64
					m.chr = this.byte2[m.page,m.asc]
				else
					m.i = m.i-1
				endif
			endif
			m.newstr = m.newstr+m.chr
		endfor
		return m.newstr
	endfunc

	function init()
	local i
		for m.i = 1 to 255
			this.byte1[m.i] = 0
		endfor
		this.byte1[194] = 1
		this.byte1[195] = 2
		this.byte1[196] = 3
		this.byte1[197] = 4
		this.byte1[198] = 5
		this.byte1[199] = 6
		this.byte1[200] = 7
		this.byte1[201] = 8
		this.byte1[202] = 9
		this.byte1[203] = 10
		this.byte1[206] = 11
		this.byte1[207] = 12
		this.byte1[208] = 13
		this.byte1[209] = 14
		this.byte1[210] = 15
		this.byte1[211] = 16
		
		this.byte2[1,1] = ' '
		this.byte2[1,2] = ' '
		this.byte2[1,3] = ' '
		this.byte2[1,4] = ' '
		this.byte2[1,5] = ' '
		this.byte2[1,6] = ' '
		this.byte2[1,7] = ' '
		this.byte2[1,8] = ' '
		this.byte2[1,9] = ' '
		this.byte2[1,10] = ' '
		this.byte2[1,11] = ' '
		this.byte2[1,12] = ' '
		this.byte2[1,13] = ' '
		this.byte2[1,14] = ' '
		this.byte2[1,15] = ' '
		this.byte2[1,16] = ' '
		this.byte2[1,17] = ' '
		this.byte2[1,18] = ' '
		this.byte2[1,19] = ' '
		this.byte2[1,20] = ' '
		this.byte2[1,21] = ' '
		this.byte2[1,22] = ' '
		this.byte2[1,23] = ' '
		this.byte2[1,24] = ' '
		this.byte2[1,25] = ' '
		this.byte2[1,26] = ' '
		this.byte2[1,27] = ' '
		this.byte2[1,28] = ' '
		this.byte2[1,29] = ' '
		this.byte2[1,30] = ' '
		this.byte2[1,31] = ' '
		this.byte2[1,32] = ' '
		this.byte2[1,33] = ' '
		this.byte2[1,34] = '¡'
		this.byte2[1,35] = '¢'
		this.byte2[1,36] = '£'
		this.byte2[1,37] = '¤'
		this.byte2[1,38] = '¥'
		this.byte2[1,39] = '¦'
		this.byte2[1,40] = '§'
		this.byte2[1,41] = '¨'
		this.byte2[1,42] = '©'
		this.byte2[1,43] = 'ª'
		this.byte2[1,44] = '«'
		this.byte2[1,45] = '¬'
		this.byte2[1,46] = ''
		this.byte2[1,47] = '®'
		this.byte2[1,48] = '¯'
		this.byte2[1,49] = '°'
		this.byte2[1,50] = '±'
		this.byte2[1,51] = '²'
		this.byte2[1,52] = '³'
		this.byte2[1,53] = '´'
		this.byte2[1,54] = 'µ'
		this.byte2[1,55] = '¶'
		this.byte2[1,56] = '·'
		this.byte2[1,57] = '¸'
		this.byte2[1,58] = '¹'
		this.byte2[1,59] = 'º'
		this.byte2[1,60] = '»'
		this.byte2[1,61] = '¼'
		this.byte2[1,62] = '½'
		this.byte2[1,63] = '¾'
		this.byte2[1,64] = '¿'
		this.byte2[2,1] = 'À'
		this.byte2[2,2] = 'Á'
		this.byte2[2,3] = 'Â'
		this.byte2[2,4] = 'Ã'
		this.byte2[2,5] = 'Ä'
		this.byte2[2,6] = 'Å'
		this.byte2[2,7] = 'Æ'
		this.byte2[2,8] = 'Ç'
		this.byte2[2,9] = 'È'
		this.byte2[2,10] = 'É'
		this.byte2[2,11] = 'Ê'
		this.byte2[2,12] = 'Ë'
		this.byte2[2,13] = 'Ì'
		this.byte2[2,14] = 'Í'
		this.byte2[2,15] = 'Î'
		this.byte2[2,16] = 'Ï'
		this.byte2[2,17] = 'Ð'
		this.byte2[2,18] = 'Ñ'
		this.byte2[2,19] = 'Ò'
		this.byte2[2,20] = 'Ó'
		this.byte2[2,21] = 'Ô'
		this.byte2[2,22] = 'Õ'
		this.byte2[2,23] = 'Ö'
		this.byte2[2,24] = '×'
		this.byte2[2,25] = 'Ø'
		this.byte2[2,26] = 'Ù'
		this.byte2[2,27] = 'Ú'
		this.byte2[2,28] = 'Û'
		this.byte2[2,29] = 'Ü'
		this.byte2[2,30] = 'Ý'
		this.byte2[2,31] = 'Þ'
		this.byte2[2,32] = 'ß'
		this.byte2[2,33] = 'à'
		this.byte2[2,34] = 'á'
		this.byte2[2,35] = 'â'
		this.byte2[2,36] = 'ã'
		this.byte2[2,37] = 'ä'
		this.byte2[2,38] = 'å'
		this.byte2[2,39] = 'æ'
		this.byte2[2,40] = 'ç'
		this.byte2[2,41] = 'è'
		this.byte2[2,42] = 'é'
		this.byte2[2,43] = 'ê'
		this.byte2[2,44] = 'ë'
		this.byte2[2,45] = 'ì'
		this.byte2[2,46] = 'í'
		this.byte2[2,47] = 'î'
		this.byte2[2,48] = 'ï'
		this.byte2[2,49] = 'ð'
		this.byte2[2,50] = 'ñ'
		this.byte2[2,51] = 'ò'
		this.byte2[2,52] = 'ó'
		this.byte2[2,53] = 'ô'
		this.byte2[2,54] = 'õ'
		this.byte2[2,55] = 'ö'
		this.byte2[2,56] = '÷'
		this.byte2[2,57] = 'ø'
		this.byte2[2,58] = 'ù'
		this.byte2[2,59] = 'ú'
		this.byte2[2,60] = 'û'
		this.byte2[2,61] = 'ü'
		this.byte2[2,62] = 'ý'
		this.byte2[2,63] = 'þ'
		this.byte2[2,64] = 'ÿ'
		this.byte2[3,1] = 'A'
		this.byte2[3,2] = 'a'
		this.byte2[3,3] = 'A'
		this.byte2[3,4] = 'a'
		this.byte2[3,5] = 'A'
		this.byte2[3,6] = 'a'
		this.byte2[3,7] = 'C'
		this.byte2[3,8] = 'c'
		this.byte2[3,9] = 'C'
		this.byte2[3,10] = 'c'
		this.byte2[3,11] = 'C'
		this.byte2[3,12] = 'c'
		this.byte2[3,13] = 'C'
		this.byte2[3,14] = 'c'
		this.byte2[3,15] = 'D'
		this.byte2[3,16] = 'd'
		this.byte2[3,17] = 'D'
		this.byte2[3,18] = 'd'
		this.byte2[3,19] = 'E'
		this.byte2[3,20] = 'e'
		this.byte2[3,21] = 'E'
		this.byte2[3,22] = 'e'
		this.byte2[3,23] = 'E'
		this.byte2[3,24] = 'e'
		this.byte2[3,25] = 'E'
		this.byte2[3,26] = 'e'
		this.byte2[3,27] = 'E'
		this.byte2[3,28] = 'e'
		this.byte2[3,29] = 'G'
		this.byte2[3,30] = 'g'
		this.byte2[3,31] = 'G'
		this.byte2[3,32] = 'g'
		this.byte2[3,33] = 'G'
		this.byte2[3,34] = 'g'
		this.byte2[3,35] = 'G'
		this.byte2[3,36] = 'g'
		this.byte2[3,37] = 'H'
		this.byte2[3,38] = 'h'
		this.byte2[3,39] = 'H'
		this.byte2[3,40] = 'h'
		this.byte2[3,41] = 'I'
		this.byte2[3,42] = 'i'
		this.byte2[3,43] = 'I'
		this.byte2[3,44] = 'i'
		this.byte2[3,45] = 'I'
		this.byte2[3,46] = 'i'
		this.byte2[3,47] = 'I'
		this.byte2[3,48] = 'i'
		this.byte2[3,49] = 'I'
		this.byte2[3,50] = 'i'
		this.byte2[3,51] = 'IJ'
		this.byte2[3,52] = 'ij'
		this.byte2[3,53] = 'J'
		this.byte2[3,54] = 'j'
		this.byte2[3,55] = 'K'
		this.byte2[3,56] = 'k'
		this.byte2[3,57] = 'k'
		this.byte2[3,58] = 'L'
		this.byte2[3,59] = 'l'
		this.byte2[3,60] = 'L'
		this.byte2[3,61] = 'l'
		this.byte2[3,62] = 'L'
		this.byte2[3,63] = 'l'
		this.byte2[3,64] = 'L'
		this.byte2[4,1] = 'l'
		this.byte2[4,2] = 'L'
		this.byte2[4,3] = 'l'
		this.byte2[4,4] = 'N'
		this.byte2[4,5] = 'n'
		this.byte2[4,6] = 'N'
		this.byte2[4,7] = 'n'
		this.byte2[4,8] = 'N'
		this.byte2[4,9] = 'n'
		this.byte2[4,10] = 'n'
		this.byte2[4,11] = 'N'
		this.byte2[4,12] = 'n'
		this.byte2[4,13] = 'O'
		this.byte2[4,14] = 'o'
		this.byte2[4,15] = 'O'
		this.byte2[4,16] = 'o'
		this.byte2[4,17] = 'Ö'
		this.byte2[4,18] = 'ö'
		this.byte2[4,19] = 'OE'
		this.byte2[4,20] = 'oe'
		this.byte2[4,21] = 'R'
		this.byte2[4,22] = 'r'
		this.byte2[4,23] = 'R'
		this.byte2[4,24] = 'r'
		this.byte2[4,25] = 'R'
		this.byte2[4,26] = 'r'
		this.byte2[4,27] = 'S'
		this.byte2[4,28] = 's'
		this.byte2[4,29] = 'S'
		this.byte2[4,30] = 's'
		this.byte2[4,31] = 'S'
		this.byte2[4,32] = 's'
		this.byte2[4,33] = 'S'
		this.byte2[4,34] = 's'
		this.byte2[4,35] = 'T'
		this.byte2[4,36] = 't'
		this.byte2[4,37] = 'T'
		this.byte2[4,38] = 't'
		this.byte2[4,39] = 'T'
		this.byte2[4,40] = 't'
		this.byte2[4,41] = 'U'
		this.byte2[4,42] = 'u'
		this.byte2[4,43] = 'U'
		this.byte2[4,44] = 'u'
		this.byte2[4,45] = 'U'
		this.byte2[4,46] = 'u'
		this.byte2[4,47] = 'U'
		this.byte2[4,48] = 'u'
		this.byte2[4,49] = 'Ü'
		this.byte2[4,50] = 'ü'
		this.byte2[4,51] = 'U'
		this.byte2[4,52] = 'u'
		this.byte2[4,53] = 'W'
		this.byte2[4,54] = 'w'
		this.byte2[4,55] = 'Y'
		this.byte2[4,56] = 'y'
		this.byte2[4,57] = 'Y'
		this.byte2[4,58] = 'Z'
		this.byte2[4,59] = 'z'
		this.byte2[4,60] = 'Z'
		this.byte2[4,61] = 'z'
		this.byte2[4,62] = 'Z'
		this.byte2[4,63] = 'z'
		this.byte2[4,64] = 's'
		this.byte2[5,1] = 'b'
		this.byte2[5,2] = 'B'
		this.byte2[5,3] = 'B'
		this.byte2[5,4] = 'b'
		this.byte2[5,5] = 'b'
		this.byte2[5,6] = 'b'
		this.byte2[5,7] = 'O'
		this.byte2[5,8] = 'C'
		this.byte2[5,9] = 'c'
		this.byte2[5,10] = 'D'
		this.byte2[5,11] = 'D'
		this.byte2[5,12] = 'D'
		this.byte2[5,13] = 'd'
		this.byte2[5,14] = 'd'
		this.byte2[5,15] = 'E'
		this.byte2[5,16] = 'E'
		this.byte2[5,17] = 'E'
		this.byte2[5,18] = 'F'
		this.byte2[5,19] = 'f'
		this.byte2[5,20] = 'G'
		this.byte2[5,21] = 'G'
		this.byte2[5,22] = 'hv'
		this.byte2[5,23] = 'I'
		this.byte2[5,24] = 'I'
		this.byte2[5,25] = 'K'
		this.byte2[5,26] = 'k'
		this.byte2[5,27] = 'l'
		this.byte2[5,28] = 'l'
		this.byte2[5,29] = 'M'
		this.byte2[5,30] = 'N'
		this.byte2[5,31] = 'n'
		this.byte2[5,32] = 'O'
		this.byte2[5,33] = 'O'
		this.byte2[5,34] = 'o'
		this.byte2[5,35] = 'OI'
		this.byte2[5,36] = 'oi'
		this.byte2[5,37] = 'P'
		this.byte2[5,38] = 'p'
		this.byte2[5,39] = 'YR'
		this.byte2[5,40] = 'S'
		this.byte2[5,41] = 's'
		this.byte2[5,42] = 'S'
		this.byte2[5,43] = 's'
		this.byte2[5,44] = 't'
		this.byte2[5,45] = 'T'
		this.byte2[5,46] = 't'
		this.byte2[5,47] = 'T'
		this.byte2[5,48] = 'U'
		this.byte2[5,49] = 'u'
		this.byte2[5,50] = 'U'
		this.byte2[5,51] = 'V'
		this.byte2[5,52] = 'Y'
		this.byte2[5,53] = 'y'
		this.byte2[5,54] = 'Z'
		this.byte2[5,55] = 'z'
		this.byte2[5,56] = 'Z'
		this.byte2[5,57] = 'Z'
		this.byte2[5,58] = 'z'
		this.byte2[5,59] = 'z'
		this.byte2[5,60] = 'Z'
		this.byte2[5,61] = 'Z'
		this.byte2[5,62] = 'z'
		this.byte2[5,63] = 'z'
		this.byte2[5,64] = 'p'
		this.byte2[6,1] = 'cl'
		this.byte2[6,2] = 'cl'
		this.byte2[6,3] = 'cl'
		this.byte2[6,4] = 'cl'
		this.byte2[6,5] = 'DZ'
		this.byte2[6,6] = 'Dz'
		this.byte2[6,7] = 'dz'
		this.byte2[6,8] = 'LJ'
		this.byte2[6,9] = 'Lj'
		this.byte2[6,10] = 'lj'
		this.byte2[6,11] = 'NJ'
		this.byte2[6,12] = 'Nj'
		this.byte2[6,13] = 'nj'
		this.byte2[6,14] = 'A'
		this.byte2[6,15] = 'a'
		this.byte2[6,16] = 'I'
		this.byte2[6,17] = 'i'
		this.byte2[6,18] = 'O'
		this.byte2[6,19] = 'o'
		this.byte2[6,20] = 'U'
		this.byte2[6,21] = 'u'
		this.byte2[6,22] = 'Ü'
		this.byte2[6,23] = 'ü'
		this.byte2[6,24] = 'Ü'
		this.byte2[6,25] = 'ü'
		this.byte2[6,26] = 'Ü'
		this.byte2[6,27] = 'ü'
		this.byte2[6,28] = 'Ü'
		this.byte2[6,29] = 'ü'
		this.byte2[6,30] = 'e'
		this.byte2[6,31] = 'Ä'
		this.byte2[6,32] = 'ä'
		this.byte2[6,33] = 'A'
		this.byte2[6,34] = 'a'
		this.byte2[6,35] = 'AE'
		this.byte2[6,36] = 'ae'
		this.byte2[6,37] = 'G'
		this.byte2[6,38] = 'g'
		this.byte2[6,39] = 'G'
		this.byte2[6,40] = 'g'
		this.byte2[6,41] = 'K'
		this.byte2[6,42] = 'k'
		this.byte2[6,43] = 'O'
		this.byte2[6,44] = 'o'
		this.byte2[6,45] = 'O'
		this.byte2[6,46] = 'o'
		this.byte2[6,47] = 'Z'
		this.byte2[6,48] = 'z'
		this.byte2[6,49] = 'j'
		this.byte2[6,50] = 'DZ'
		this.byte2[6,51] = 'Dz'
		this.byte2[6,52] = 'dz'
		this.byte2[6,53] = 'G'
		this.byte2[6,54] = 'g'
		this.byte2[6,55] = 'H'
		this.byte2[6,56] = 'P'
		this.byte2[6,57] = 'N'
		this.byte2[6,58] = 'n'
		this.byte2[6,59] = 'A'
		this.byte2[6,60] = 'a'
		this.byte2[6,61] = 'AE'
		this.byte2[6,62] = 'ae'
		this.byte2[6,63] = 'O'
		this.byte2[6,64] = 'o'
		this.byte2[7,1] = 'Ä'
		this.byte2[7,2] = 'ä'
		this.byte2[7,3] = 'A'
		this.byte2[7,4] = 'a'
		this.byte2[7,5] = 'E'
		this.byte2[7,6] = 'e'
		this.byte2[7,7] = 'E'
		this.byte2[7,8] = 'e'
		this.byte2[7,9] = 'I'
		this.byte2[7,10] = 'i'
		this.byte2[7,11] = 'I'
		this.byte2[7,12] = 'i'
		this.byte2[7,13] = 'Ö'
		this.byte2[7,14] = 'ö'
		this.byte2[7,15] = 'O'
		this.byte2[7,16] = 'o'
		this.byte2[7,17] = 'R'
		this.byte2[7,18] = 'r'
		this.byte2[7,19] = 'R'
		this.byte2[7,20] = 'r'
		this.byte2[7,21] = 'Ü'
		this.byte2[7,22] = 'ü'
		this.byte2[7,23] = 'U'
		this.byte2[7,24] = 'u'
		this.byte2[7,25] = 'S'
		this.byte2[7,26] = 's'
		this.byte2[7,27] = 'T'
		this.byte2[7,28] = 't'
		this.byte2[7,29] = 'Y'
		this.byte2[7,30] = 'y'
		this.byte2[7,31] = 'H'
		this.byte2[7,32] = 'h'
		this.byte2[7,33] = 'N'
		this.byte2[7,34] = 'd'
		this.byte2[7,35] = 'OU'
		this.byte2[7,36] = 'ou'
		this.byte2[7,37] = 'Z'
		this.byte2[7,38] = 'z'
		this.byte2[7,39] = 'A'
		this.byte2[7,40] = 'a'
		this.byte2[7,41] = 'E'
		this.byte2[7,42] = 'e'
		this.byte2[7,43] = 'Ö'
		this.byte2[7,44] = 'ö'
		this.byte2[7,45] = 'O'
		this.byte2[7,46] = 'o'
		this.byte2[7,47] = 'O'
		this.byte2[7,48] = 'o'
		this.byte2[7,49] = 'O'
		this.byte2[7,50] = 'o'
		this.byte2[7,51] = 'Y'
		this.byte2[7,52] = 'y'
		this.byte2[7,53] = 'l'
		this.byte2[7,54] = 'n'
		this.byte2[7,55] = 't'
		this.byte2[7,56] = 'j'
		this.byte2[7,57] = 'db'
		this.byte2[7,58] = 'qp'
		this.byte2[7,59] = 'A'
		this.byte2[7,60] = 'C'
		this.byte2[7,61] = 'c'
		this.byte2[7,62] = 'L'
		this.byte2[7,63] = 'T'
		this.byte2[7,64] = 's'
		this.byte2[8,1] = 'z'
		this.byte2[8,2] = 'H'
		this.byte2[8,3] = 'h'
		this.byte2[8,4] = 'B'
		this.byte2[8,5] = 'U'
		this.byte2[8,6] = 'V'
		this.byte2[8,7] = 'E'
		this.byte2[8,8] = 'e'
		this.byte2[8,9] = 'J'
		this.byte2[8,10] = 'j'
		this.byte2[8,11] = 'Q'
		this.byte2[8,12] = 'q'
		this.byte2[8,13] = 'R'
		this.byte2[8,14] = 'r'
		this.byte2[8,15] = 'Y'
		this.byte2[8,16] = 'y'
		this.byte2[8,17] = 'a'
		this.byte2[8,18] = 'a'
		this.byte2[8,19] = 'a'
		this.byte2[8,20] = 'b'
		this.byte2[8,21] = 'o'
		this.byte2[8,22] = 'c'
		this.byte2[8,23] = 'd'
		this.byte2[8,24] = 'd'
		this.byte2[8,25] = 'e'
		this.byte2[8,26] = 'e'
		this.byte2[8,27] = 'e'
		this.byte2[8,28] = 'e'
		this.byte2[8,29] = 'e'
		this.byte2[8,30] = 'e'
		this.byte2[8,31] = 'e'
		this.byte2[8,32] = 'j'
		this.byte2[8,33] = 'g'
		this.byte2[8,34] = 'g'
		this.byte2[8,35] = 'G'
		this.byte2[8,36] = 'g'
		this.byte2[8,37] = 'h'
		this.byte2[8,38] = 'h'
		this.byte2[8,39] = 'h'
		this.byte2[8,40] = 'h'
		this.byte2[8,41] = 'i'
		this.byte2[8,42] = 'i'
		this.byte2[8,43] = 'I'
		this.byte2[8,44] = 'l'
		this.byte2[8,45] = 'l'
		this.byte2[8,46] = 'l'
		this.byte2[8,47] = 'l'
		this.byte2[8,48] = 'm'
		this.byte2[8,49] = 'm'
		this.byte2[8,50] = 'm'
		this.byte2[8,51] = 'n'
		this.byte2[8,52] = 'n'
		this.byte2[8,53] = 'N'
		this.byte2[8,54] = 'o'
		this.byte2[8,55] = 'OE'
		this.byte2[8,56] = 'o'
		this.byte2[8,57] = 'p'
		this.byte2[8,58] = 'r'
		this.byte2[8,59] = 'r'
		this.byte2[8,60] = 'r'
		this.byte2[8,61] = 'r'
		this.byte2[8,62] = 'r'
		this.byte2[8,63] = 'r'
		this.byte2[8,64] = 'r'
		this.byte2[9,1] = 'R'
		this.byte2[9,2] = 'R'
		this.byte2[9,3] = 's'
		this.byte2[9,4] = 's'
		this.byte2[9,5] = 's'
		this.byte2[9,6] = 's'
		this.byte2[9,7] = 's'
		this.byte2[9,8] = 't'
		this.byte2[9,9] = 't'
		this.byte2[9,10] = 'u'
		this.byte2[9,11] = 'u'
		this.byte2[9,12] = 'v'
		this.byte2[9,13] = 'v'
		this.byte2[9,14] = 'w'
		this.byte2[9,15] = 'y'
		this.byte2[9,16] = 'Y'
		this.byte2[9,17] = 'z'
		this.byte2[9,18] = 'z'
		this.byte2[9,19] = 's'
		this.byte2[9,20] = 's'
		this.byte2[9,21] = 'h'
		this.byte2[9,22] = 'h'
		this.byte2[9,23] = 'h'
		this.byte2[9,24] = 'c'
		this.byte2[9,25] = 'c'
		this.byte2[9,26] = 'b'
		this.byte2[9,27] = 'e'
		this.byte2[9,28] = 'G'
		this.byte2[9,29] = 'H'
		this.byte2[9,30] = 'j'
		this.byte2[9,31] = 'k'
		this.byte2[9,32] = 'L'
		this.byte2[9,33] = 'q'
		this.byte2[9,34] = 'h'
		this.byte2[9,35] = 'h'
		this.byte2[9,36] = 'dz'
		this.byte2[9,37] = 'dz'
		this.byte2[9,38] = 'dz'
		this.byte2[9,39] = 'ts'
		this.byte2[9,40] = 'ts'
		this.byte2[9,41] = 'tc'
		this.byte2[9,42] = 'fn'
		this.byte2[9,43] = 'ls'
		this.byte2[9,44] = 'lz'
		this.byte2[9,45] = 'w'
		this.byte2[9,46] = 'n'
		this.byte2[9,47] = 'h'
		this.byte2[9,48] = 'h'
		this.byte2[9,49] = 'h'
		this.byte2[9,50] = 'h'
		this.byte2[9,51] = 'j'
		this.byte2[9,52] = 'r'
		this.byte2[9,53] = 'r'
		this.byte2[9,54] = 'r'
		this.byte2[9,55] = 'R'
		this.byte2[9,56] = 'w'
		this.byte2[9,57] = 'y'
		this.byte2[9,58] = ' '
		this.byte2[9,59] = ' '
		this.byte2[9,60] = ' '
		this.byte2[9,61] = ' '
		this.byte2[9,62] = ' '
		this.byte2[9,63] = ' '
		this.byte2[9,64] = ' '
		this.byte2[10,1] = ' '
		this.byte2[10,2] = ' '
		this.byte2[10,3] = ' '
		this.byte2[10,4] = ' '
		this.byte2[10,5] = ' '
		this.byte2[10,6] = ' '
		this.byte2[10,7] = ' '
		this.byte2[10,8] = ' '
		this.byte2[10,9] = ' '
		this.byte2[10,10] = ' '
		this.byte2[10,11] = ' '
		this.byte2[10,12] = ' '
		this.byte2[10,13] = ' '
		this.byte2[10,14] = ' '
		this.byte2[10,15] = ' '
		this.byte2[10,16] = ' '
		this.byte2[10,17] = ' '
		this.byte2[10,18] = ' '
		this.byte2[10,19] = ' '
		this.byte2[10,20] = ' '
		this.byte2[10,21] = ' '
		this.byte2[10,22] = ' '
		this.byte2[10,23] = ' '
		this.byte2[10,24] = ' '
		this.byte2[10,25] = ' '
		this.byte2[10,26] = ' '
		this.byte2[10,27] = ' '
		this.byte2[10,28] = ' '
		this.byte2[10,29] = ' '
		this.byte2[10,30] = ' '
		this.byte2[10,31] = ' '
		this.byte2[10,32] = ' '
		this.byte2[10,33] = ' '
		this.byte2[10,34] = 'l'
		this.byte2[10,35] = 's'
		this.byte2[10,36] = 'x'
		this.byte2[10,37] = ' '
		this.byte2[10,38] = ' '
		this.byte2[10,39] = ' '
		this.byte2[10,40] = ' '
		this.byte2[10,41] = ' '
		this.byte2[10,42] = ' '
		this.byte2[10,43] = ' '
		this.byte2[10,44] = ' '
		this.byte2[10,45] = ' '
		this.byte2[10,46] = ' '
		this.byte2[10,47] = ' '
		this.byte2[10,48] = ' '
		this.byte2[10,49] = ' '
		this.byte2[10,50] = ' '
		this.byte2[10,51] = ' '
		this.byte2[10,52] = ' '
		this.byte2[10,53] = ' '
		this.byte2[10,54] = ' '
		this.byte2[10,55] = ' '
		this.byte2[10,56] = ' '
		this.byte2[10,57] = ' '
		this.byte2[10,58] = ' '
		this.byte2[10,59] = ' '
		this.byte2[10,60] = ' '
		this.byte2[10,61] = ' '
		this.byte2[10,62] = ' '
		this.byte2[10,63] = ' '
		this.byte2[10,64] = ' '
		this.byte2[11,1] = ' '
		this.byte2[11,2] = ' '
		this.byte2[11,3] = ' '
		this.byte2[11,4] = ' '
		this.byte2[11,5] = ' '
		this.byte2[11,6] = ' '
		this.byte2[11,7] = 'A'
		this.byte2[11,8] = ' '
		this.byte2[11,9] = 'E'
		this.byte2[11,10] = 'I'
		this.byte2[11,11] = 'I'
		this.byte2[11,12] = ' '
		this.byte2[11,13] = 'O'
		this.byte2[11,14] = ' '
		this.byte2[11,15] = 'Y'
		this.byte2[11,16] = 'O'
		this.byte2[11,17] = 'i'
		this.byte2[11,18] = 'A'
		this.byte2[11,19] = 'B'
		this.byte2[11,20] = 'G'
		this.byte2[11,21] = 'D'
		this.byte2[11,22] = 'E'
		this.byte2[11,23] = 'Z'
		this.byte2[11,24] = 'I'
		this.byte2[11,25] = 'TH'
		this.byte2[11,26] = 'I'
		this.byte2[11,27] = 'K'
		this.byte2[11,28] = 'L'
		this.byte2[11,29] = 'M'
		this.byte2[11,30] = 'N'
		this.byte2[11,31] = 'X'
		this.byte2[11,32] = 'O'
		this.byte2[11,33] = 'P'
		this.byte2[11,34] = 'R'
		this.byte2[11,35] = ' '
		this.byte2[11,36] = 'S'
		this.byte2[11,37] = 'T'
		this.byte2[11,38] = 'Y'
		this.byte2[11,39] = 'F'
		this.byte2[11,40] = 'CH'
		this.byte2[11,41] = 'PS'
		this.byte2[11,42] = 'O'
		this.byte2[11,43] = 'I'
		this.byte2[11,44] = 'Y'
		this.byte2[11,45] = 'a'
		this.byte2[11,46] = 'e'
		this.byte2[11,47] = 'i'
		this.byte2[11,48] = 'i'
		this.byte2[11,49] = 'y'
		this.byte2[11,50] = 'a'
		this.byte2[11,51] = 'b'
		this.byte2[11,52] = 'g'
		this.byte2[11,53] = 'd'
		this.byte2[11,54] = 'e'
		this.byte2[11,55] = 'z'
		this.byte2[11,56] = 'i'
		this.byte2[11,57] = 'th'
		this.byte2[11,58] = 'i'
		this.byte2[11,59] = 'k'
		this.byte2[11,60] = 'l'
		this.byte2[11,61] = 'm'
		this.byte2[11,62] = 'n'
		this.byte2[11,63] = 'x'
		this.byte2[11,64] = 'o'
		this.byte2[12,1] = 'p'
		this.byte2[12,2] = 'r'
		this.byte2[12,3] = 's'
		this.byte2[12,4] = 's'
		this.byte2[12,5] = 't'
		this.byte2[12,6] = 'y'
		this.byte2[12,7] = 'f'
		this.byte2[12,8] = 'ch'
		this.byte2[12,9] = 'ps'
		this.byte2[12,10] = 'o'
		this.byte2[12,11] = 'i'
		this.byte2[12,12] = 'y'
		this.byte2[12,13] = 'o'
		this.byte2[12,14] = 'y'
		this.byte2[12,15] = 'o'
		this.byte2[12,16] = ' '
		this.byte2[12,17] = 'b'
		this.byte2[12,18] = 't'
		this.byte2[12,19] = 'y'
		this.byte2[12,20] = 'y'
		this.byte2[12,21] = 'y'
		this.byte2[12,22] = 'f'
		this.byte2[12,23] = 'p'
		this.byte2[12,24] = ' '
		this.byte2[12,25] = 'K'
		this.byte2[12,26] = 'k'
		this.byte2[12,27] = ' '
		this.byte2[12,28] = ' '
		this.byte2[12,29] = ' '
		this.byte2[12,30] = ' '
		this.byte2[12,31] = 'K'
		this.byte2[12,32] = 'k'
		this.byte2[12,33] = ' '
		this.byte2[12,34] = ' '
		this.byte2[12,35] = 'S'
		this.byte2[12,36] = 's'
		this.byte2[12,37] = 'F'
		this.byte2[12,38] = 'f'
		this.byte2[12,39] = 'X'
		this.byte2[12,40] = 'x'
		this.byte2[12,41] = 'H'
		this.byte2[12,42] = 'h'
		this.byte2[12,43] = 'C'
		this.byte2[12,44] = 'c'
		this.byte2[12,45] = 'K'
		this.byte2[12,46] = 'k'
		this.byte2[12,47] = 'TI'
		this.byte2[12,48] = 'ti'
		this.byte2[12,49] = 'k'
		this.byte2[12,50] = 'r'
		this.byte2[12,51] = 's'
		this.byte2[12,52] = 'j'
		this.byte2[12,53] = 'T'
		this.byte2[12,54] = 'e'
		this.byte2[12,55] = 'e'
		this.byte2[12,56] = ' '
		this.byte2[12,57] = ' '
		this.byte2[12,58] = 'S'
		this.byte2[12,59] = ' '
		this.byte2[12,60] = ' '
		this.byte2[12,61] = 'r'
		this.byte2[12,62] = 'S'
		this.byte2[12,63] = 's'
		this.byte2[12,64] = 's'
		this.byte2[13,1] = 'E'
		this.byte2[13,2] = 'YO'
		this.byte2[13,3] = 'DJ'
		this.byte2[13,4] = 'GJ'
		this.byte2[13,5] = 'E'
		this.byte2[13,6] = 'DZ'
		this.byte2[13,7] = 'I'
		this.byte2[13,8] = 'JI'
		this.byte2[13,9] = 'J'
		this.byte2[13,10] = 'LJ'
		this.byte2[13,11] = 'NJ'
		this.byte2[13,12] = 'C'
		this.byte2[13,13] = 'KJ'
		this.byte2[13,14] = 'I'
		this.byte2[13,15] = 'U'
		this.byte2[13,16] = 'DZ'
		this.byte2[13,17] = 'A'
		this.byte2[13,18] = 'B'
		this.byte2[13,19] = 'V'
		this.byte2[13,20] = 'G'
		this.byte2[13,21] = 'D'
		this.byte2[13,22] = 'E'
		this.byte2[13,23] = 'Z'
		this.byte2[13,24] = 'Z'
		this.byte2[13,25] = 'I'
		this.byte2[13,26] = 'I'
		this.byte2[13,27] = 'K'
		this.byte2[13,28] = 'L'
		this.byte2[13,29] = 'M'
		this.byte2[13,30] = 'N'
		this.byte2[13,31] = 'O'
		this.byte2[13,32] = 'P'
		this.byte2[13,33] = 'R'
		this.byte2[13,34] = 'S'
		this.byte2[13,35] = 'T'
		this.byte2[13,36] = 'U'
		this.byte2[13,37] = 'F'
		this.byte2[13,38] = 'H'
		this.byte2[13,39] = 'C'
		this.byte2[13,40] = 'C'
		this.byte2[13,41] = 'S'
		this.byte2[13,42] = 'SC'
		this.byte2[13,43] = 'H'
		this.byte2[13,44] = 'Y'
		this.byte2[13,45] = 'J'
		this.byte2[13,46] = 'E'
		this.byte2[13,47] = 'JU'
		this.byte2[13,48] = 'JA'
		this.byte2[13,49] = 'a'
		this.byte2[13,50] = 'b'
		this.byte2[13,51] = 'v'
		this.byte2[13,52] = 'g'
		this.byte2[13,53] = 'd'
		this.byte2[13,54] = 'e'
		this.byte2[13,55] = 'z'
		this.byte2[13,56] = 'z'
		this.byte2[13,57] = 'i'
		this.byte2[13,58] = 'i'
		this.byte2[13,59] = 'k'
		this.byte2[13,60] = 'l'
		this.byte2[13,61] = 'm'
		this.byte2[13,62] = 'n'
		this.byte2[13,63] = 'o'
		this.byte2[13,64] = 'p'
		this.byte2[14,1] = 'r'
		this.byte2[14,2] = 's'
		this.byte2[14,3] = 't'
		this.byte2[14,4] = 'u'
		this.byte2[14,5] = 'f'
		this.byte2[14,6] = 'h'
		this.byte2[14,7] = 'c'
		this.byte2[14,8] = 'c'
		this.byte2[14,9] = 's'
		this.byte2[14,10] = 'sc'
		this.byte2[14,11] = 'h'
		this.byte2[14,12] = 'y'
		this.byte2[14,13] = 'j'
		this.byte2[14,14] = 'e'
		this.byte2[14,15] = 'ju'
		this.byte2[14,16] = 'ja'
		this.byte2[14,17] = 'e'
		this.byte2[14,18] = 'jo'
		this.byte2[14,19] = 'dj'
		this.byte2[14,20] = 'gj'
		this.byte2[14,21] = 'e'
		this.byte2[14,22] = 'dz'
		this.byte2[14,23] = 'i'
		this.byte2[14,24] = 'ji'
		this.byte2[14,25] = 'j'
		this.byte2[14,26] = 'lj'
		this.byte2[14,27] = 'nj'
		this.byte2[14,28] = 'c'
		this.byte2[14,29] = 'kj'
		this.byte2[14,30] = 'i'
		this.byte2[14,31] = 'u'
		this.byte2[14,32] = 'dz'
		this.byte2[14,33] = 'O'
		this.byte2[14,34] = 'o'
		this.byte2[14,35] = 'J'
		this.byte2[14,36] = 'j'
		this.byte2[14,37] = 'E'
		this.byte2[14,38] = 'e'
		this.byte2[14,39] = 'Y'
		this.byte2[14,40] = 'y'
		this.byte2[14,41] = 'Y'
		this.byte2[14,42] = 'y'
		this.byte2[14,43] = 'Y'
		this.byte2[14,44] = 'y'
		this.byte2[14,45] = 'Y'
		this.byte2[14,46] = 'y'
		this.byte2[14,47] = 'CH'
		this.byte2[14,48] = 'ch'
		this.byte2[14,49] = 'PS'
		this.byte2[14,50] = 'ps'
		this.byte2[14,51] = 'TH'
		this.byte2[14,52] = 'th'
		this.byte2[14,53] = 'Y'
		this.byte2[14,54] = 'y'
		this.byte2[14,55] = 'Y'
		this.byte2[14,56] = 'y'
		this.byte2[14,57] = 'OY'
		this.byte2[14,58] = 'oy'
		this.byte2[14,59] = 'O'
		this.byte2[14,60] = 'o'
		this.byte2[14,61] = 'O'
		this.byte2[14,62] = 'o'
		this.byte2[14,63] = 'O'
		this.byte2[14,64] = 'o'
		this.byte2[15,1] = 'K'
		this.byte2[15,2] = 'k'
		this.byte2[15,3] = ' '
		this.byte2[15,4] = ' '
		this.byte2[15,5] = ' '
		this.byte2[15,6] = ' '
		this.byte2[15,7] = ' '
		this.byte2[15,8] = ' '
		this.byte2[15,9] = ' '
		this.byte2[15,10] = ' '
		this.byte2[15,11] = 'I'
		this.byte2[15,12] = 'i'
		this.byte2[15,13] = 'J'
		this.byte2[15,14] = 'j'
		this.byte2[15,15] = 'R'
		this.byte2[15,16] = 'r'
		this.byte2[15,17] = 'G'
		this.byte2[15,18] = 'g'
		this.byte2[15,19] = 'G'
		this.byte2[15,20] = 'g'
		this.byte2[15,21] = 'G'
		this.byte2[15,22] = 'g'
		this.byte2[15,23] = 'Z'
		this.byte2[15,24] = 'z'
		this.byte2[15,25] = 'Z'
		this.byte2[15,26] = 'z'
		this.byte2[15,27] = 'K'
		this.byte2[15,28] = 'k'
		this.byte2[15,29] = 'K'
		this.byte2[15,30] = 'k'
		this.byte2[15,31] = 'K'
		this.byte2[15,32] = 'k'
		this.byte2[15,33] = 'K'
		this.byte2[15,34] = 'k'
		this.byte2[15,35] = 'N'
		this.byte2[15,36] = 'n'
		this.byte2[15,37] = 'N'
		this.byte2[15,38] = 'n'
		this.byte2[15,39] = 'P'
		this.byte2[15,40] = 'p'
		this.byte2[15,41] = 'H'
		this.byte2[15,42] = 'h'
		this.byte2[15,43] = 'S'
		this.byte2[15,44] = 's'
		this.byte2[15,45] = 'T'
		this.byte2[15,46] = 't'
		this.byte2[15,47] = 'U'
		this.byte2[15,48] = 'u'
		this.byte2[15,49] = 'U'
		this.byte2[15,50] = 'u'
		this.byte2[15,51] = 'H'
		this.byte2[15,52] = 'h'
		this.byte2[15,53] = 'T'
		this.byte2[15,54] = 't'
		this.byte2[15,55] = 'C'
		this.byte2[15,56] = 'c'
		this.byte2[15,57] = 'C'
		this.byte2[15,58] = 'c'
		this.byte2[15,59] = 'H'
		this.byte2[15,60] = 'h'
		this.byte2[15,61] = 'C'
		this.byte2[15,62] = 'c'
		this.byte2[15,63] = 'C'
		this.byte2[15,64] = 'c'
		this.byte2[16,1] = ' '
		this.byte2[16,2] = 'Z'
		this.byte2[16,3] = 'z'
		this.byte2[16,4] = 'K'
		this.byte2[16,5] = 'k'
		this.byte2[16,6] = 'L'
		this.byte2[16,7] = 'l'
		this.byte2[16,8] = 'N'
		this.byte2[16,9] = 'n'
		this.byte2[16,10] = 'N'
		this.byte2[16,11] = 'n'
		this.byte2[16,12] = 'C'
		this.byte2[16,13] = 'c'
		this.byte2[16,14] = 'M'
		this.byte2[16,15] = 'm'
		this.byte2[16,16] = ' '
		this.byte2[16,17] = 'A'
		this.byte2[16,18] = 'a'
		this.byte2[16,19] = 'A'
		this.byte2[16,20] = 'a'
		this.byte2[16,21] = 'E'
		this.byte2[16,22] = 'e'
		this.byte2[16,23] = 'E'
		this.byte2[16,24] = 'e'
		this.byte2[16,25] = 'E'
		this.byte2[16,26] = 'e'
		this.byte2[16,27] = 'E'
		this.byte2[16,28] = 'e'
		this.byte2[16,29] = 'Z'
		this.byte2[16,30] = 'z'
		this.byte2[16,31] = 'Z'
		this.byte2[16,32] = 'z'
		this.byte2[16,33] = 'DZ'
		this.byte2[16,34] = 'dz'
		this.byte2[16,35] = 'I'
		this.byte2[16,36] = 'i'
		this.byte2[16,37] = 'I'
		this.byte2[16,38] = 'i'
		this.byte2[16,39] = 'O'
		this.byte2[16,40] = 'o'
		this.byte2[16,41] = 'O'
		this.byte2[16,42] = 'o'
		this.byte2[16,43] = 'O'
		this.byte2[16,44] = 'o'
		this.byte2[16,45] = 'E'
		this.byte2[16,46] = 'e'
		this.byte2[16,47] = 'U'
		this.byte2[16,48] = 'u'
		this.byte2[16,49] = 'U'
		this.byte2[16,50] = 'u'
		this.byte2[16,51] = 'U'
		this.byte2[16,52] = 'u'
		this.byte2[16,53] = 'C'
		this.byte2[16,54] = 'c'
		this.byte2[16,55] = 'G'
		this.byte2[16,56] = 'g'
		this.byte2[16,57] = 'Y'
		this.byte2[16,58] = 'y'
		this.byte2[16,59] = 'G'
		this.byte2[16,60] = 'g'
		this.byte2[16,61] = 'H'
		this.byte2[16,62] = 'h'
		this.byte2[16,63] = 'H'
		this.byte2[16,64] = 'h'
	endfunc
enddefine