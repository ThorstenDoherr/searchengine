*==========================================================================
* Modul: 	 sheet.prg
* Date:		 2024.08.14
* Author:	 Thorsten Doherr
* Procedure: custom.prg
* Library:	 foxpro.fll
* Handles:	 17
* Function:	 Classes to import and export delimited text files in and out
*            of foxpro tables.
* VFPA:      Due to large table support table clusters will always have
*            only one table.
*==========================================================================
#define SHEETHANDLE 17

function version_of_sheet()
	return "2024.08.14"
endfunc

function mp_parse(separator as String, nonames as String, crlf as Boolean, columns as Integer)
	_screen.local1.useExclusive()
	_screen.main.parsing(_screen.global1.from(_screen.worker), _screen.global1.to(_screen.worker), _screen.global2, _screen.local1, m.separator, m.nonames, m.crlf, m.columns, _screen.messenger)
	_screen.local1.close()
	_screen.main.close()
endfunc

function mp_append(separator as String, nonames as Boolean, crlf as Boolean, advanced as Boolean)
	_screen.global3.useShared()
	_screen.main.appending(_screen.global1.from(_screen.worker), _screen.global1.to(_screen.worker), _screen.global2, _screen.global3, m.separator, m.nonames, m.crlf, m.advanced, _screen.messenger)
	_screen.global3.close()
	_screen.main.close()
endfunc

define class InsheetTableCluster as TableCluster
	invalidNames = "FOREIGN"
	original = ""
	nonames = .f.
	nomemos = .f.
	decode = .f.
	memoloss = 0.1
	foxpro = .f.
	drop = ""
	keep = ""
	noblank = .f.
	pfw = .f.
	
	function init(firsttable, tablecount, tolerant, careless)
		TableCluster::init(m.firsttable, m.tablecount, m.tolerant, m.careless)
		if vartype(m.firsttable) == "O" 
			this.nonames = m.firsttable.nonames
			this.nomemos = m.firsttable.nomemos
			this.decode = m.firsttable.decode
			this.memoloss = m.firsttable.memoloss
			this.foxpro = m.firsttable.foxpro
			this.drop = m.firsttable.drop
			this.keep = m.firsttable.keep
			this.noblank = m.firsttable.noblank
			this.original = m.firsttable.original
			return
		endif
		this.original = this.start
		this.pfw = createobject("ParallelFoxWrapper")
	endfunc
		
	function setPFW(pfw as object)
		this.pfw = m.pfw
	endfunc
	
	function getPFW()
		return this.pfw
	endfunc
	
	function mp(mp as Integer)
		return this.pfw.mp(m.mp)
	endfunc
	
	function cpu()
		return this.pfw.cpu()
	endfunc
	
	function setNoblank(noblank)
		this.noblank = m.noblank
	endfunc
	
	function setDrop(drop as String)
		this.drop = m.drop
	endfunc
	
	function setKeep(keep as String)
		this.keep = m.keep
	endfunc

	function setFoxPro(foxpro as Boolean)
		this.foxpro = m.foxpro
	endfunc

	function setNoNames(nonames as Boolean)
		this.nonames = m.nonames
	endfunc
	
	function setNoMemos(nomemos as Boolean)
		this.nomemos = m.nomemos
	endfunc
	
	function setMemoLoss(memoloss as Double)
		this.memoloss = m.memoloss
	endfunc

	function setMemoLoss(memoloss as Double)
		this.memoloss = m.memoloss
	endfunc

	function setDecode(decode as Boolean)
		this.decode = m.decode
	endfunc
	
	function getDrop()
		return this.drop
	endfunc
	
	function getKeep()
		return this.keep
	endfunc

	function getNoNames()
		return this.nonames
	endfunc
	
	function getNoMemos()
		return this.nomemos
	endfunc
	
	function getDecode()
		return this.decode
	endfunc	
		
	function getMemoLoss()
		return this.memoloss
	endfunc
	
	function getFoxpro()
		return this.foxpro
	endfunc
	
	function getNoblank()
		return this.noblank
	endfunc
	
	function create(file as String)
	local i, j, k, wc, psl, pa, lm
	local chr, structure, local, global
	local separator, firstline, forcenames, sql 
	local basecnt, cnt, linecnt, filesize
	local crlf, table, itemcnt, nonames, memos
	local array dir[1], struc[1], items[1], hist[1], namehist[1], namestruc[1]
		m.psl = createobject("PreservedSettingList")
		m.psl.set("escape","off")
		m.psl.set("safety","off")
		m.psl.set("talk","off")
		m.psl.set("blocksize","64")
		m.psl.set("compatible","off") && otherwise resizing of arrays kills content
		m.psl.set("exclusive","off")
		m.lm = createobject("LastMessage",this.messenger)
		m.pa = createobject("PreservedAlias")
		this.messenger.forceMessage("Importing...")
		if not "\FOXPRO.FLL" $ upper(set("library"))
			this.messenger.errormessage("Library foxpro.fll not installed.")
			return .f.
		endif
		if not this.isCreatable()
			this.messenger.errormessage("Unable to create the table/cluster.")
			return .f.
		endif
		if not this.isConform()
			if not (this.forceConformity() and this.isCreatable())
				this.messenger.errormessage("Unable to create the table/cluster.")
				return .f.
			endif
		endif
		if adir(m.dir,this.getPath()+this.getStart()+"___w*_t*.dbf") > 0
			this.messenger.errormessage(textmerge('Please remove/delete "<<this.getStart()+"___w*_t*.dbf">> files from directory.'))
			return .f.
		endif
		if not vartype(m.file) == "C" 
			this.messenger.errormessage("Unable to open the text file.")
			return .f.
		endif
		if FileOpenRead(SHEETHANDLE,m.file) < 0
			this.messenger.errormessage("Unable to open the text file.")
			return .f.
		endif
		adir(m.dir,fullpath(m.file))
		m.filesize = int(m.dir[1,2])
		m.crlf = this.scanCRLF()
		m.nonames = this.nonames
		m.separator = chr(9)+",;|#"
		m.columns = this.scout_separator(@m.separator, m.crlf)
		if m.columns <= 0
			FileClose(SHEETHANDLE)
			this.messenger.errormessage("Text file is empty.")
			return .f.
		endif
		this.readline(m.crlf, @m.firstline)
		m.firstline = this.skipByteOrderMark(m.firstline)
		FileRewind(SHEETHANDLE)
		this.initHistogram(@m.hist)
		m.wc = this.pfw.setOptimalWorkerCount(m.filesize, 1024*1024*8)
		this.messenger.startProgress("Parsing <<0>>/"+transform(m.filesize))
		this.messenger.startCancel("Cancel Operation","Parsing","Canceled.")
		if m.wc > 1
			FileClose(SHEETHANDLE)
			m.local = createobject("Collection")
			for m.i = 1 to m.wc
				m.table = createobject("BaseCursor", this.getPath(), "count b(0)")
				m.local.add(m.table)
			endfor
			for m.i = 1 to m.wc
				m.table = m.local.item(m.i)
				m.table.close()
			endfor
			m.global = createobject("Collection")
			m.global.add(createobject("WorkerBracket", 1, m.filesize, m.wc, 0.07)) && skipping only takes 6% of parsing time
			m.global.add(fullpath(m.file))
			this.pfw.linkMessenger(this.messenger)
			this.pfw.startWorkers()
			this.pfw.callWorkers("mp_open", this, m.psl, m.local, m.global)
			this.pfw.wait() && make sure all workers are idle to maintain batch sequence
			this.pfw.callWorkers("mp_parse", m.separator, m.nonames, m.crlf, m.columns)
			this.pfw.wait(.t.)
			this.pfw.stopWorkers()
			if this.messenger.wasCanceled()
				return .f.
			endif
			m.linecnt = 0
			for m.i = 1 to m.wc
				m.table = m.local.item(m.i)
				m.table.useExclusive()
				select (m.table.alias)
				if reccount(m.table.alias) < 254*256+1
					this.messenger.errormessage("Unable to parse the text file.")
					return .f.
				endif
				go top
				for m.j = 1 to 254
					for m.k = 1 to 255
						m.hist[m.j,m.k] = m.hist[m.j,m.k]+int(count)
						skip
					endfor
					m.chr = chr(evl(int(count),32))
					if at(m.chr,"CNDJI ") < at(m.hist[m.j,m.k],"CNDJI ")
						m.hist[m.j,m.k] = m.chr
					endif
					skip
				endfor
				m.linecnt = m.linecnt+int(count)
				m.table.erase()
			endfor
		else
			m.linecnt = this.parsing(1, m.filesize, SHEETHANDLE, @m.hist, m.separator, m.nonames, m.crlf, m.columns, this.messenger)
			FileClose(SHEETHANDLE)
			if this.messenger.wasCanceled()
				return .f.
			endif
		endif
		this.messenger.forceMessage("Importing...")
		dimension m.struc[1,5]
		if m.linecnt > 0
			this.parseHistogram(@m.hist, @m.struc, m.linecnt, iif(this.nomemos, this.memoloss, 0), this.foxpro)
		endif
		if m.linecnt == 0 or vartype(m.struc[1,2]) == "L"
			if empty(m.firstline)
				this.messenger.errormessage("Empty file.")
				return .f.
			endif
			m.itemcnt = this.separate(@m.items, m.firstline, m.separator, m.columns)
			if not this.collectHistogram(@m.hist, @m.items, m.itemcnt)
				this.messenger.errormessage("Invalid structure.")
				return .f.
			endif
			m.nonames = .t.
			m.linecnt = 1
			this.parseHistogram(@m.hist, @m.struc, m.linecnt, iif(this.nomemos, this.memoloss, 0), this.foxpro)
		endif
		m.basecnt = alen(m.struc,1)
		if m.nonames == .f.
			dimension m.namestruc[1,4]
			this.initHistogram(@m.namehist)
			m.itemcnt = this.separate(@m.items, m.firstline, m.separator, m.columns)
			this.collectHistogram(@m.namehist, @m.items, m.itemcnt)
			this.parseHistogram(@m.namehist, @m.namestruc)
			this.dropHistogram(@m.namehist)
			m.forcenames = .f.
			m.cnt = min(alen(m.namestruc,1),m.basecnt)
			for m.i = 1 to m.cnt
				if inlist(m.namestruc[m.i,2],"C","M","X") 
					if not inlist(m.struc[m.i,2],"C","M","X")
						m.forcenames = .t.
					endif
				else
					if not m.struc[m.i,2] == "X"
						m.nonames = .t.
						exit
					endif
				endif
			endfor
			if m.nonames or not this.parseNames(@m.struc, @m.items, m.forcenames)
				this.collectHistogram(@m.hist, @m.items, m.itemcnt)
				this.parseHistogram(@m.hist, @m.struc, m.linecnt+1, iif(this.nomemos, this.memoloss, 0), this.foxpro)
				m.basecnt = alen(m.struc,1)
				m.nonames = .t.
			endif
		endif
		m.sql = ""
		m.memos = .f.
		for m.i = 1 to m.basecnt
			if m.struc[m.i,2] == "x"
				loop
			endif
			if m.struc[m.i,2] == "X"
				m.struc[m.i,3] = 1
				m.struc[m.i,4] = 0
			endif
			m.sql = m.sql+","+m.struc[m.i,1]
			if inlist(m.struc[m.i,2],"C","X")
				m.sql = m.sql+" C("+ltrim(str(m.struc[m.i,3],18))+") null"
			else
				if m.struc[m.i,2] == "N"
					m.sql = m.sql+" N("+ltrim(str(m.struc[m.i,3],18))+","+ltrim(str(m.struc[m.i,4],18))+") null"
				else
					if m.struc[m.i,2] == "M"
						m.memos = .t.
					endif
					m.sql = m.sql+" "+m.struc[m.i,2]+" null"
				endif
			endif
		endfor
		if empty(m.sql)
			this.messenger.errormessage("Empty table.")
			return .f.
		endif
		m.sql = substr(m.sql,2)
		m.table = createobject("BaseTable",this.getPath()+this.getStart())
		if not m.table.construct(m.sql)
			this.messenger.errormessage("Unable to create table with following structure:"+chr(10)+m.sql)
			return .f.
		endif
		m.table.close()
		this.messenger.startProgress("Appending <<0>>/"+transform(m.linecnt))
		this.messenger.startCancel("Cancel Operation","Parsing","Canceled.")
		if m.wc > 1
			this.close()
			erase (this.getPath()+this.getStart()+"___w*_t*.dbf")
			m.structure = createobject("BaseCursor",this.getPath(), "name c(10), type c(1), size i, dec i, sum i")
			for m.i = 1 to alen(m.struc,1)
				insert into (m.structure.alias) values (m.struc[m.i,1], m.struc[m.i,2], m.struc[m.i,3], m.struc[m.i,4], m.struc[m.i,5])
			endfor
			m.structure.close()
			m.global = createobject("Collection")
			m.global.add(createobject("WorkerBracket", 1, m.filesize, m.wc, 0.04))
			m.global.add(fullpath(m.file))
			m.global.add(m.structure)
			this.pfw.linkMessenger(this.messenger)
			this.pfw.startWorkers()
			this.pfw.callWorkers("mp_open", this, m.psl, .f., m.global)
			this.pfw.wait() && make sure all workers are idle to maintain batch sequence
			this.pfw.callWorkers("mp_append", m.separator, m.nonames, m.crlf, this.advanced)
			this.pfw.wait(.t.)
			this.pfw.stopWorkers()
			m.table.erase()
			if this.messenger.wasCanceled()
				erase (this.getPath()+this.getStart()+"___w*_t*.dbf")
				erase (this.getPath()+this.getStart()+"___w*_t*.fpt")
				this.erase(.t.)
				return .f.
			endif
			this.messenger.forceMessage("Compressing...")
			m.i = 0
			for m.j = 1 to m.wc
				m.k = 1
				m.table = createobject("BaseTable",this.path+this.start+textmerge("___w<<m.j>>_t<<m.k>>"))
				do while m.table.isValid()
					m.i = m.i+1
					m.k = m.k+1
					if not m.table.rename(this.createTableName(m.i,.t.))
						this.messenger.errorMessage("Unable to create table cluster.")
						m.table.close()
						erase (this.path+this.start+"___w*_t*.dbf")
						return .f.
					endif
					m.table.close()
					m.table = createobject("BaseTable",this.path+this.start+textmerge("___w<<m.j>>_t<<m.k>>"))
				enddo
				m.table.close()
			endfor
			this.close()
			this.rebuild(m.i)
			if this.advanced or m.memos == .f. or m.i <= m.wc && compressing memos is very slow and should be avoided for large clusters unless VFPA
				this.compress()
			endif
		else
			this.rebuild(1)
			this.appending(1, m.filesize, m.file, @m.struc, m.separator, m.nonames, m.crlf, this.advanced, this.messenger)
		endif
		if this.getTableCount() == 1 and not this.original == this.start
			m.table = this.getTable(1)
			m.table.rename(this.original)
			this.close()
			this.build(this.path+this.original)
		endif
		this.messenger.forceMessage("Closing...")
		if this.getTableCount() == 0
			this.messenger.errormessage("Unable to create table cluster.")
			return .f.
		endif
		this.goTop()
		this.rewind()
		return .t.
	endfunc
	
	function parsing(from as Integer, to as Integer, file as String, histogram as Object, separator as String, nonames as boolean, crlf as boolean, columns as Integer, messenger as Object)
	local i, j, line, linecnt, items, hist, linebreak, itemcnt
		if m.to < m.from
			return
		endif
		if vartype(m.file) == "C"
			if FileOpenRead(SHEETHANDLE,m.file) < 0
				return -1
			endif
		endif
		m.linebreak = iif(m.crlf,2,1)
		m.line = this.adjust_from_range(@m.from, m.to, m.crlf, m.nonames)
		if m.from <= 0
			FileClose(SHEETHANDLE)
			return 0
		endif
		dimension m.items[1]
		this.initHistogram(@m.hist)
		m.linecnt = 0
		do while not (FileEOF(SHEETHANDLE) and empty(m.line))
			m.messenger.incProgress(len(m.line)+m.linebreak,1)
			m.messenger.postProgress()
			if m.messenger.queryCancel()
				FileClose(SHEETHANDLE)
				return 0
			endif
			m.linecnt = m.linecnt+1
			m.itemcnt = this.separate(@m.items, m.line, m.separator, m.columns)
			m.columns = max(m.itemcnt, m.columns)
			if not this.collectHistogram(@m.hist, @m.items, m.itemcnt)
				FileClose(SHEETHANDLE)
				return -1
			endif
			if m.from > m.to
				exit
			endif
			if m.crlf
				m.line = FileReadCRLF(SHEETHANDLE)
				m.from = m.from+len(m.line)+2
			else
				m.line = FileReadLF(SHEETHANDLE)				
				m.from = m.from+len(m.line)+1
			endif
		enddo
		FileClose(SHEETHANDLE)
		m.messenger.forceProgress()
		if vartype(m.histogram) == "O"
			for m.i = 1 to 254
				for m.j = 1 to 255
					insert into (m.histogram.alias) values (hist[m.i,m.j])
				endfor
				insert into (m.histogram.alias) values (asc(hist[m.i,m.j]))
			endfor
			insert into (m.histogram.alias) values (m.linecnt)
			return
		endif
		acopy(m.hist, m.histogram)
		return m.linecnt
	endfunc	

	function appending(from as Integer, to as Integer, file as String, structure as Object, separator as String, nonames as Boolean, crlf as Boolean, advanced as Boolean, messenger as Object)
	local i, line, linebreak, worker, ind, ins, cnt, val, item, len
	local table, struct, blocksize, sizerec, size, datasize, sizememo, sizelimit, basecnt
	local array struc[1], items[1], values[1]
		m.struct = this.getTableStructure()
		if vartype(_screen.worker) == "N" and _screen.worker > 0
			m.worker = int(_screen.worker)
			m.table = createobject("BaseTable",this.getPath()+this.getStart()+textmerge("___w<<m.worker>>_t1.dbf"))
			m.table.erase()
			if not m.table.construct(m.struct)
				return
			endif
			m.table.close()
			this.build(m.table.dbf)
		endif
		m.table = this.getTable(1)
		m.table.useExclusive()
		if m.to < m.from  && table will always be constructed
			return
		endif
		m.table.useExclusive()
		if vartype(m.structure) == "O"
			select (m.structure.alias)
			m.cnt = reccount()
			dimension m.struc[m.cnt, 5]
			for m.i = 1 to m.cnt
				go m.i
				m.struc[m.i,1] = name
				m.struc[m.i,2] = type
				m.struc[m.i,3] = size
				m.struc[m.i,4] = dec
				m.struc[m.i,5] = sum
			endfor
		else
			acopy(m.structure, m.struc)
		endif
		if m.advanced == .f.
			m.blocksize = val(sys(2012,m.table.alias))
			m.datasize = m.blocksize - 8
			m.sizerec = m.table.getRecordSize()
			m.size = 0
			m.sizememo = 0
			m.sizelimit = 1024 * 1024 * 1024 * 2 - 100 * 1024 * 1024
		endif
		m.basecnt = alen(m.struc,1)
		if this.noblank
			dimension m.values[m.struct.getFieldCount()]
		endif
		if vartype(m.file) == "C"
			if FileOpenRead(SHEETHANDLE,m.file) < 0
				return
			endif
		endif
		m.linebreak = iif(m.crlf,2,1)
		m.line = this.adjust_from_range(@m.from, m.to, m.crlf, m.nonames)
		if m.from <= 0
			FileClose(SHEETHANDLE)
			return 0
		endif
		if m.from == 1
			m.line = this.skipByteOrderMark(m.line)
		endif
		dimension m.items[1]
		select (m.table.alias)
		do while not (FileEOF(SHEETHANDLE) and empty(m.line))
			m.messenger.incProgress(1,1)
			m.messenger.postProgress()
			if m.messenger.queryCancel()
				exit
			endif
			m.cnt = this.separate(@m.items, m.line, m.separator, m.basecnt)
			m.cnt = min(m.basecnt, m.cnt)
			if this.noblank
				m.ind = 0
				for m.i = 1 to m.cnt
					if m.struc[m.i,2] == "x"
						loop
					endif
					m.ind = m.ind+1
					if m.struc[m.i,2] == "X"
						m.values[m.ind] = .NULL.
						loop
					endif
					m.item = m.items[m.i]
					if m.item == ".NULL." or m.item == ".null."
						m.values[m.ind] = .NULL.
						loop
					endif
					if m.struc[m.i,2] == "C"
						if this.decode
							m.item = Decode(m.item)
						endif
						if len(m.item) > m.struc[m.i,3]
							m.item = this.truncate(m.item, m.struc[m.i,3])
						endif 
						m.values[m.ind] = m.item
						loop
					endif
					if m.struc[m.i,2] == "M"
						if this.decode
							m.item = Decode(m.item)
						endif
						m.len = len(m.item)
						if m.advanced == .f. and m.len > 0
							m.sizememo = m.sizememo + (int((m.len-1) / m.datasize) + 1) * m.blocksize
						endif
						m.values[m.ind] = m.item
						loop
					endif
					if m.item == "." or empty(m.item)
						m.values[m.ind] = .NULL.
						loop
					endif
					m.values[m.ind] = val(strtran(m.item,",","."))
				endfor
			else
				m.ins = ""
				m.val = ""
				for m.i = 1 to m.cnt
					if inlist(m.struc[m.i,2],"X","x")
						loop
					endif
					m.item = m.items[m.i]
					if empty(m.item)
						loop
					endif
					if m.item == ".NULL." or m.item = ".null."
						m.items[m.i] = .NULL.
					else
						if m.struc[m.i,2] == "C"
							if this.decode
								m.item = Decode(m.item)
							endif
							if len(m.item) > m.struc[m.i,3]
								m.item = this.truncate(m.item, m.struc[m.i,3])
							endif 
							m.items[m.i] = m.item
						else
							if m.struc[m.i,2] == "M"
								if this.decode
									m.item =Decode(m.item)
								endif
								m.len = len(m.item)
								if m.advanced == .f. and m.len > 0
									m.sizememo = m.sizememo + (int((m.len-1) / m.datasize) + 1) * m.blocksize
								endif
								m.items[m.i] = m.item
							else					
								if m.item == "."
									m.items[m.i] = .NULL.
								else				
									m.items[m.i] = val(strtran(m.item,",","."))
								endif
							endif
						endif
						m.ins = m.ins+","+m.struc[m.i,1]
						m.val = m.val+",m.items["+transform(m.i)+"]"
					endif
				endfor
			endif
			if m.advanced == .f.
				m.size = m.size + m.sizerec
				if m.size > m.sizelimit or m.sizememo > m.sizelimit
					if not this.appendTable()
						exit
					endif
					m.table = this.getLastTable()
					m.table.useExclusive()
					m.size = 0
					m.sizememo = 0
					select (m.table.alias)
				endif
			endif
			if this.noblank
				append blank
				gather from m.values memo
			else
				if not empty(m.ins)
					m.ins = "insert into "+m.table.alias+" ("+substr(m.ins,2)+") values ("+substr(m.val,2)+")"
					&ins
				else
					append blank
				endif
			endif
			if m.from > m.to
				exit
			endif
			if m.crlf
				m.line = FileReadCRLF(SHEETHANDLE)
				m.from = m.from+len(m.line)+2
			else
				m.line = FileReadLF(SHEETHANDLE)				
				m.from = m.from+len(m.line)+1
			endif
		enddo
		FileClose(SHEETHANDLE)
		m.messenger.forceProgress()
	endfunc
	
	function cleanse()
	local table, i, cluster, trunc
	local array dir[1]
		this.erase(.t.)
		if not empty(this.original)
			m.table = createobject("BaseTable",this.path+this.original)
			m.table.erase()
		endif
		m.trunc = this.conformTrunc()
		for m.i = 1 to adir(m.dir,this.path+m.trunc+".dbf")
			m.cluster = createobject("TableCluster",this.path+m.dir[m.i,1],1)
			if m.cluster.trunc == m.trunc and m.cluster.first >= 1
				m.cluster.erase(.t.)
			endif
		endfor
	endfunc
	
	hidden function initHistogram(hist)
	local i, j
		dimension m.hist[254,256]
		for m.i = 1 to 254
			for m.j = 1 to 255 
				m.hist[m.i,m.j] = 0
			endfor
			m.hist[m.i,256] = " " && space not null string
		endfor
	endfunc

	hidden function dropHistogram(hist)
		dimension m.hist[1,1]
		m.hist[1,1] = .f.
	endfunc
		
	hidden function collectHistogram(hist, items, itemcnt)
	local cnt, i, val, len, item, type, corpus, e
		m.cnt = min(m.itemcnt,alen(m.hist,1))
		for m.i = 1 to m.cnt
			m.type = m.hist[m.i,256]
			m.item = m.items[m.i]
			if m.item = "." or m.item == ".NULL." or m.item == ".null."
				m.item = ""
			endif
			m.len = len(m.item)
			if m.len == 0
				loop
			endif
			if m.len > 254
				m.len = 255
			endif
			m.hist[m.i,m.len] = m.hist[m.i,m.len] + 1
			if m.type == "C"
				loop
			endif
			m.item = alltrim(m.item)
			if m.len >= 19 or isalpha(m.item) or asc(m.item) == 95
				m.hist[m.i,256] = "C"
				loop
			endif
			m.item = strtran(strtran(m.item,",","."),";"," ")
			m.corpus = lower(Squeeze(ReplaceChars(m.item, "123456789", "0", .f.), "0"))
			m.e = .f.
			if "e" $ m.corpus
				m.e = .t.
				if not inlist(getwordnum(m.corpus, 2, "e"), "0", "+0", "-0")
					m.hist[m.i,256] = "C"
					loop
				endif
				m.corpus = getwordnum(m.corpus, 1, "e")
			endif
			if not inlist(m.corpus, "0", "0.0", ".0", "-0", "-0.0", "-.0", "+0", "+0.0", "+.0")
				m.hist[m.i,256] = "C"
				loop
			endif
			m.val = val(m.item)
			if m.val == 0 and not inlist(Squeeze(iif(m.e, getwordnum(m.item, 1, "eE"), m.item), "0"), "0", "0.0", ".0", "-0", "-0.0", "-.0", "+0", "+0.0", "+.0")
				m.hist[m.i,256] = "C"
				loop
			endif
			if m.type == "N" or m.type = "D" and not m.e
				loop
			endif
			if not int(m.val) == m.val
				if m.e
					m.hist[m.i,256] = "N"
				else
					m.hist[m.i,256] = "D"
				endif
				loop
			endif
			if m.type == "D" or m.type == "J"
				loop
			endif
			if left(m.item,1) == "0" and m.val >= 1
				m.hist[m.i,256] = "J"
			else
				m.hist[m.i,256] = "I"
			endif
		endfor
		return .t.
	endfunc

	hidden function parseHistogram(hist, struc, linecnt, loss, foxpro)
	local i, j, k, cnt, sum
		if not vartype(m.linecnt) == "N" or m.linecnt < 1
			m.linecnt = 1
		endif
		if not vartype(m.loss) == "N" or not between(m.loss,0,100)
			m.loss = 0
		endif
		m.loss = m.loss / 100
		for m.cnt = alen(m.hist,1) to 1 step -1
			if not empty(m.hist[m.cnt,256])
				exit
			endif
		endfor
		if m.cnt < 1
			return .f.
		endif
		dimension m.struc[m.cnt,5]
		for m.i = 1 to m.cnt
			m.sum = 0
			for m.j = 1 to 255
				m.sum = m.sum+m.hist[m.i,m.j]
			endfor
			m.struc[m.i,5] = m.sum
		endfor
		for m.i = 1 to m.cnt
			if m.loss > 0 and m.hist[m.i,255] > 0
				m.sum = m.hist[m.i,255]
				for m.j = 254 to 1 step -1
					m.sum = m.sum + m.hist[m.i,m.j]
					if m.sum/m.linecnt > m.loss
						exit
					endif
				endfor
			else
				for m.j = 255 to 1 step -1
					if m.hist[m.i,m.j] > 0
						exit
					endif
				endfor
				for m.k = m.j-1 to 1 step -1
					if m.hist[m.i,m.k] > 0
						exit
					endif
				endfor
			endif
			m.struc[m.i,1] = "V"+ltrim(str(m.i,18))
			m.struc[m.i,4] = 0
			if m.j == 0
				m.struc[m.i,2] = "X"
				m.struc[m.i,3] = 0
				loop
			endif
			if m.j > 254
				m.struc[m.i,2] = "M"
				m.struc[m.i,3] = 4
				loop
			endif
			if m.hist[m.i,256] == "N"
				m.struc[m.i,2] = "B"
				m.struc[m.i,3] = 8
				loop
			endif
			if m.foxpro
				if m.hist[m.i,256] == "D"
					m.struc[m.i,2] = "B"
					m.struc[m.i,3] = 8
					loop
				endif
				if m.hist[m.i,256] == "J" or m.hist[m.i,256] == "I"
					if m.j > 9 
						if m.k < 1
							m.struc[m.i,2] = "C"
							m.struc[m.i,3] = m.j
						else
							m.struc[m.i,2] = "B"
							m.struc[m.i,3] = 8
						endif
					else
						if m.j < 4
							m.struc[m.i,2] = "N"
							m.struc[m.i,3] = m.j
						else
							m.struc[m.i,2] = "I"
							m.struc[m.i,3] = 4
						endif
					endif
					loop
				endif
			else
				if m.hist[m.i,256] == "D"
					m.struc[m.i,2] = "N"
					m.struc[m.i,3] = m.j+1
					m.struc[m.i,4] = m.j-1
					loop
				endif
				if m.hist[m.i,256] == "J" 
					m.struc[m.i,2] = "C"
					m.struc[m.i,3] = m.j
					loop
				endif
				if m.hist[m.i,256] == "I"
					if m.j > 9 and m.k < 1
						m.struc[m.i,2] = "C"
						m.struc[m.i,3] = m.j
					else
						m.struc[m.i,2] = "N"
						m.struc[m.i,3] = m.j
					endif
					loop
				endif
			endif
			m.struc[m.i,2] = "C"
			m.struc[m.i,3] = m.j
		endfor
	endfunc
	
	hidden function parseNames(struc, items, forcenames as Boolean)
	local cnt, basecnt, i, j, names, str, item, val, lex, lexcnt
		m.basecnt = alen(m.struc,1)
		m.cnt = min(alen(m.items),m.basecnt)
		if not empty(this.keep)
			dimension m.lex[1]
			m.lexcnt = alines(m.lex,lower(this.keep),5,",")
			for m.i = 1 to m.cnt
				m.item = lower(m.items[m.i])
				for m.j = 1 to m.lexcnt
					if like(m.lex[m.j],m.item)
						exit
					endif
				endfor
				if m.j > m.lexcnt
					m.struc[m.i,2] = "x"
				endif
			endfor
		endif
		if not empty(this.drop)
			dimension m.lex[1]
			m.lexcnt = alines(m.lex,lower(this.drop),5,",")
			for m.i = 1 to m.cnt
				m.item = lower(m.items[m.i])
				for m.j = 1 to m.lexcnt
					if like(m.lex[m.j],m.item)
						m.struc[m.i,2] = "x"
						exit
					endif
				endfor
			endfor
		endif
		if not m.forcenames
			for m.i = 1 to m.cnt
				if not m.struc[m.i,2] == "x"
					m.item = m.items[m.i]
					for m.j = m.i+1 to m.cnt
						if m.items[m.j] == m.item
							return .f.
						endif
					endfor
				endif
			endfor
		endif
		m.names = " "
		for m.i = 1 to m.basecnt
			if m.struc[m.i,2] == "x"
				m.names = m.names+"[dropped] "
				loop
			endif
			if m.i > m.cnt
				m.item = ""
			else
				m.item = left(strtran(alltrim(NormizeKeep(Decode(m.items[m.i]),"_"))," ","_"),10)
			endif
			if not (left(m.item,1) == "_" or isalpha(m.item))
				if m.forcenames
					if not empty(m.item)
						m.item = left("_"+m.item,10)
					else
						m.item = ""
					endif
				else
					return .f.
				endif
			endif
			if " "+m.item+" " $ " "+this.invalidNames+" "
				m.item = ""
			endif
			m.j = 0
			m.str = m.item
			do while empty(m.str) or " "+m.str+" " $ m.names
				m.j = m.j+1
				m.str = ltrim(str(m.j,18))
				m.val = len(m.str)+len(m.item)+1
				if m.val > 10
					m.str = substr(m.item,1, len(m.item)-m.val+10)+"_"+m.str
				else
					m.str = m.item+"_"+m.str
				endif
			enddo
			m.names = m.names+m.str+" "
		endfor
		m.names = alltrim(m.names)
		for m.i = 1 to m.basecnt
			m.struc[m.i,1] = getwordnum(m.names,m.i)
		endfor		
		return .t.
	endfunc

	&& Separates the string line according to the separator and stores the items in the target array
	&& the optional parameter columns designates the target number of columns
	&& if the separated string has more columns, quotes become relevant to obtain the specified column number 
	hidden function separate(target as Array_reference, line as String, separator as String, columns as Integer)
	local cnt, i, j, t, quote, skip, str, stop
	local array items[1]
		m.cnt = alines(m.items, m.line, 2, m.separator)
		m.columns = evl(m.columns, m.cnt)
		if alen(m.target) != m.cnt
			dimension m.target[m.cnt]
		endif
		if m.cnt <= m.columns
			for m.i = 1 to m.cnt
				m.quote = left(m.items[m.i], 1) 
				if m.quote = "'" or m.quote = '"' and right(m.items[m.i], 1) == m.quote
					m.target[m.i] = substr(m.items[m.i], 2, len(m.items[m.i])-2)
				else
					m.target[m.i] = m.items[m.i]
				endif
			endfor
			return m.cnt
		endif
		m.skip = m.cnt - m.columns && column overhead 
		m.i = 1
		m.t = 0
		do while m.i <= m.cnt
			m.quote = left(m.items[m.i], 1) 
			if m.quote = "'" or m.quote = '"' 
				if right(m.items[m.i], 1) == m.quote
					m.t = m.t+1
					m.target[m.t] = substr(m.items[m.i], 2, len(m.items[m.i])-2)
					m.i = m.i+1
				else
					m.str = m.items[m.i]
					m.stop = m.i+m.skip
					for m.j = m.i+1 to m.stop
						m.str = m.str+" "+m.items[m.j]
						if right(m.items[m.j], 1) == m.quote and not left(m.items[m.j], 1) == m.quote
							exit
						endif
					endfor
					if m.j <= m.stop
						m.t = m.t+1
						m.target[m.t] = substr(m.str, 2, len(m.str)-2)
						m.skip = m.skip - m.j + m.i
						m.i = m.j+1
					else
						m.t = m.t+1
						m.target[m.t] = m.items[m.i]
						m.i = m.i+1
					endif
				endif
			else
				m.t = m.t+1
				m.target[m.t] = m.items[m.i]
				m.i = m.i+1
			endif
		enddo
		if m.t != m.cnt
			dimension m.target[m.t]
		endif
		return m.t
	endfunc
	
	&& selects the appropriate separator from a string of separators by browsing through the top records
	&& the parameter has to be a reference and will be replaced by the best separator
	&& the function returns the (average) number of columns based on the best separator
	hidden function scout_separator(separators as String_reference, crlf as Boolean)
	local i, j, n, line, sep, mean, cv, sd, best_mean, best_cv, best_sep
	local array m.stat[100], m.items[1]
		m.best_cv = -1
		m.best_mean = 0
		m.best_sep = ""
		for m.i = 1 to len(m.separators)
			FileRewind(SHEETHANDLE)
			m.sep = substr(m.separators, m.i, 1)
			for m.j = 1 to alen(m.stat)
				this.readline(m.crlf, @m.line)
				if FileEOF(SHEETHANDLE)
					exit
				endif
				this.separate(@m.items, m.line, m.sep)
				m.stat[m.j] = alen(m.items)
			endfor
			m.n = m.j - 1
			if m.n <= 0
				m.best_sep = ""
				m.best_mean = 0
				exit
			endif
			m.mean = 0
			for m.j = 1 to m.n
				m.mean = m.mean + m.stat[m.j]
			endfor
			m.mean = m.mean / m.n
			m.sd = 0
			for m.j = 1 to m.n
				m.sd = m.sd + (m.stat[m.j]-m.mean)^2
			endfor
			m.sd = sqrt(m.sd / m.n)
			m.cv = m.sd / m.mean
			if m.best_cv < 0 or m.cv < m.best_cv and m.mean > 1 or m.best_cv == m.cv and m.mean > m.best_mean
				m.best_cv = m.cv
				m.best_mean = m.mean
				m.best_sep = m.sep
			endif
		endfor
		FileRewind(SHEETHANDLE)
		m.separators = m.best_sep
		return int(m.best_mean+0.5)
	endfunc
	
	hidden function skipByteOrderMark(str as String)
		if left(m.str,3) == chr(239)+chr(187)+chr(191)
			return substr(m.str,4)
		endif
		if inlist(left(m.str,4),chr(255)+chr(254)+chr(0)+chr(0),chr(0)+chr(0)+chr(254)+chr(255))
			return substr(m.str,5)
		endif
		if inlist(left(m.str,2),chr(255)+chr(254),chr(254)+chr(255))
			return substr(m.str,3)
		endif
		return m.str
	endfunc
	
	hidden function truncate(str as String, size as Integer)
	local pos
		m.str = rtrim(m.str)
		if len(m.str) <= m.size
			return m.str
		endif
		m.str = left(m.str, m.size)
		m.pos = rat(" ", NormizeKeepPos(m.str, ""))
		if m.pos/len(m.str) <= 0.5
			return m.str
		endif
		return rtrim(left(m.str,m.pos))
	endfunc

	hidden function scanCRLF()
	local cnt, line, cr
		m.cnt = 0
		m.cr = chr(13)
		m.line = FileReadLF(SHEETHANDLE)
		do while not FileEOF(SHEETHANDLE)
			if right(m.line,1) == m.cr
				FileRewind(SHEETHANDLE)
				return .t.
			endif
			m.cnt = m.cnt + 1
			if m.cnt > 512
				FileRewind(SHEETHANDLE)
				return .f.
			endif
			m.line = FileReadLF(SHEETHANDLE)
		enddo
		FileRewind(SHEETHANDLE)
		return .f.
	endfunc
	
	hidden function readline(crlf as Boolean, line)  && line by reference: @m.line
		if m.crlf
			m.line = FileReadCRLF(SHEETHANDLE)
		else
			m.line = FileReadLF(SHEETHANDLE)
		endif
	endfunc
	
	&& adjusts the from range and returns the first line within the range
	&& if from is within the middle of a line, the partial line will be skipped
	&& if from == 1, the header will be skipped if applicable 
	hidden function adjust_from_range(from as Integer_reference, to as Integer, crlf as Boolean, noheader as Boolean)
	local linebreak, line, cr
		m.linebreak = iif(m.crlf, chr(13)+chr(10), chr(10))
		m.line = ""
		m.cr = .f.
		if m.from > 1 or m.noheader == .f. && from == 1 and header
			if not FileGo(SHEETHANDLE, m.from-len(m.linebreak))
				return -1
			endif
			m.line = FileRead(SHEETHANDLE, len(m.linebreak))
			m.cr = right(m.line, 1) == chr(13)
			if not m.line == m.linebreak
				this.readline(m.crlf, @m.line) && skipping partial record
				m.from = m.from + len(m.line) + len(m.linebreak)
				if m.crlf and m.cr and left(m.line,1) == chr(10) && jumped right between cr and lf
					return substr(m.line,2)
				endif
				if m.from > m.to && to within partial line
					m.from = -1
					return ""
				endif
			endif
		endif
		this.readline(m.crlf, @m.line)
		m.from = m.from + len(m.line) + len(m.linebreak) + 1		
		return m.line
	endfunc
enddefine

define class OutSheetTableCluster as TableCluster
	hidden separator, header, quoted
	separator = chr(9)
	header = .t.
	quoted = .t.

	function setSeparator(sep as String)
		this.separator = m.sep
	endfunc
	
	function getSeparator()
		return this.separator
	endfunc
	
	function setHeader(header as Boolean)
		this.header = m.header
	endfunc
	
	function getHeader()
		return this.Header
	endfunc
	
	function setQuoted(quoted as Boolean)
		this.quoted = m.quoted
	endfunc
	
	function getQuoted()
		return this.quoted
	endfunc

	function outsheet(file as String, fieldlist)
	local ps1, ps2, ps3
	local outtable, i, rc 
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		this.messenger.forceMessage("Exporting...")
		if this.cluster.count == 0
			this.messenger.errorMessage("Nothing to export.")
			return .f.
		endif
		this.messenger.startProgress("Exporting <<0>>/"+ltrim(str(this.reccount(),18)))
		this.messenger.startCancel("Cancel Operation","Exporting","Canceled.")
		for m.i = 1 to this.cluster.count
			m.outtable = createobject("OutsheetTable",this.getTable(m.i))
			m.outtable.setSeparator(this.separator)
			m.outtable.setHeader(this.header)
			m.outtable.setQuoted(this.quoted)
			m.outTable.setMessenger(this.messenger)
			if m.i == 1
				m.rc = m.outtable.outsheet(m.file, m.fieldlist, .f., .t.)
			else
				m.rc = m.outtable.outsheet(m.file, m.fieldlist, .t., .t.)
			endif
			if m.rc == .f.
				return .f.
			endif
		endfor
		return .t.
	endfunc
enddefine

define class OutSheetTable as Basetable
	hidden separator, header, quoted
	separator = chr(9)
	header = .t.
	quoted = .t.
	
	function setSeparator(sep as String)
		this.separator = m.sep
	endfunc
	
	function getSeparator()
		return this.separator
	endfunc
	
	function setHeader(header as Boolean)
		this.header = m.header
	endfunc
	
	function getHeader()
		return this.Header
	endfunc
	
	function setQuoted(quoted as Boolean)
		this.quoted = m.quoted
	endfunc
	
	function getQuoted()
		return this.quoted
	endfunc
	
	function outsheet(file as String, fieldlist, append as Boolean, consecutive as Boolean)
	local ps1, ps2, ps3, pa, pk, lm, header, struc, con
	local converter, i, handle, f, s, exp, line
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.lm = createobject("LastMessage",this.messenger)
		m.pa = createobject("PreservedAlias")
		m.pk = createobject("PreservedKey",this)
		this.messenger.forceMessage("Exporting...")
		if not "\FOXPRO.FLL" $ upper(set("library"))
			this.messenger.errormessage("Library foxpro.fll not installed.")
			return .f.
		endif
		if not this.isValid()
			this.messenger.errormessage("Export table is invalid.")
			return .f.
		endif
		m.struc = this.getTablestructure()
		if vartype(m.fieldlist) == "C"
			m.fieldlist = createobject("TableStructure",m.fieldlist)
		endif
		if vartype(m.fieldlist) == "O" and m.fieldlist.getFieldCount() > 0
			m.struc = m.struc.getStructureWith(m.fieldlist)
		endif
		if m.struc.getFieldCount() == 0
			this.messenger.errormessage("No fields left to export.")
			return .f.
		endif
		if vartype(m.fieldlist) == "L" and not pcount() >= 3
			m.append = m.fieldlist
		endif
		if not vartype(m.append) == "L"  or not vartype(m.consecutive) == "L"
			this.messenger.errormessage("Invalid parameter.")
			return .f.
		endif
		m.header = this.header
		if not file(m.file)
			m.append = .f.
		endif
		if vartype(m.file) == "C"
			if m.append
				m.handle = FileOpenAppend(SHEETHANDLE,m.file)
				if m.handle > 0
					m.header = .f.
				else
					m.handle = FileOpenWrite(SHEETHANDLE,m.file)
				endif
			else
				m.handle = FileOpenWrite(SHEETHANDLE,m.file)
			endif
		else
			m.handle = FileOpenWrite(SHEETHANDLE,lower(this.getPath()+this.getPureName())+".txt")
		endif
		if m.handle <= 0
			this.messenger.errormessage("Unable to create export file.")
			return .f.
		endif
		m.s = ""
		m.exp = "m.line = "
		m.line = ""
		m.converter = ""
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if this.quoted
				m.con = m.f.quotedConverter()
			else
				m.con = m.f.exportConverter()
			endif			
			if len(m.exp)+len(m.s)+len(m.con) > 4095
				m.converter = m.converter+m.exp+chr(13)+chr(10)
				m.exp = "m.line = m.line+"
			endif
			m.exp = m.exp+m.s+m.con
			m.s = "+m.s+"
			if m.header
				m.line = m.line+this.separator+lower(m.f.getName())
			endif
		endfor
		m.converter = m.converter+m.exp+chr(13)+chr(10)
		m.exp = ""
		if not empty(m.line)
			m.line = substr(m.line,len(this.separator)+1)
			FileWriteCRLF(m.handle,m.line)
		endif
		this.setKey()
		this.select()
		if not m.consecutive
			this.messenger.startProgress("Exporting <<0>>/"+transform(reccount()))
			this.messenger.startCancel("Cancel Operation","Exporting","Canceled.")
		endif
		text to m.converter textmerge noshow flags 1 pretext 3
			parameters s, messenger
			scan
				m.messenger.incProgress(1,1)
				m.messenger.postProgress()
				if m.messenger.queryCancel()
					exit
				endif
				<<m.converter>>
				FileWriteCRLF(<<m.handle>>, m.line)
			endscan
		endtext
		execscript(m.converter, this.separator, this.messenger)
		this.messenger.forceProgress()
		FileClose(m.handle)
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc
enddefine

define class Memo2CharTable as BaseTable
	hidden potential, loss, word
	potential = 0.25
	loss = 0.01
	word = .t.
	
	
	function setMaxLoss(loss as Double)
		this.loss = min(max(m.loss,0),1)
	endfunc
	
	function getMaxLoss()
		return this.loss
	endfunc

	function getMinPotential()
		return this.potential
	endfunc

	function setMinPotential(potential as Double)
		this.potential = max(m.potential,0)
	endfunc
	
	function getMinPotential()
		return this.potential
	endfunc
	
	function setWordTruncate(truncate)
		this.word = m.truncate
	endfunc
	
	function getWordTruncate()
		return this.word
	endfunc

	function create(table as Object, keep as String)
	local ps1, ps2, ps3, pa, lm
	local i, j, struc, memo, f, tmp, stat, count
	local reccount, index, step, name, sql, pos, oldpos
	local maxsize, potential, limit, newsize, potdif
	local usePotential, newstruc, truncated
	local offset, norm, value, t, str, key
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.lm = createobject("LastMessage",this.messenger)
		m.pa = createobject("PreservedAlias")
		this.messenger.ForceMessage("Analysing...")
		if not this.iscreatable()
			this.messenger.errorMessage("Unable to create Memo2CharTable.")
			return .f.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Source table is invalid.")
			return .f.
		endif
		if vartype(m.keep) == "C"
			m.keep = createobject("TableStructure",m.keep)
		endif
		if not vartype(m.keep) == "O"
			m.keep = createobject("TableStructure")
		else
			if not m.keep.isValid()
				this.messenger.errorMessage("Keep list is invalid.")
				return .f.
			endif
		endif
		m.struc = m.table.getTableStructure()
		m.memo = createobject("Collection")
		m.index = createobject("Collection")
		m.offset = 0
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if m.f.getType() == "M" and m.keep.getFieldIndex(m.f.getName()) <= 0
				m.memo.add(createobject("Collection"),m.f.getName())
			else
				m.offset = m.offset+m.f.getSize()
			endif
		endfor
		if m.memo.count == 0
			this.messenger.errorMessage("Source table has no memo fields.")
			return .f.
		endif
		if m.struc.getFieldindex("truncated") == 0
			m.truncated = .t.
		else
			m.truncated = .f.
		endif
		m.reccount = m.table.reccount()
		m.offset = (m.offset+iif(m.truncated,2,1)) * m.reccount
		m.step = this.loss/1000
		m.count = -1
		dimension m.index[m.memo.count,2]
		m.tmp = createobject("UniqueAlias",.t.)
		for m.i = 1 to m.memo.count
			m.index[m.i,1] = 1    && stat index
			m.index[m.i,2] = 0    && potential
			m.name = m.memo.getKey(m.i)
			m.stat = m.memo.item(m.i)
			this.messenger.ForceMessage("Analysing "+lower(m.name))
			m.sql = "select nvl(len("+m.name+"),0) as len from "+m.table.alias+" order by 1 desc into cursor "+m.tmp.alias
			&sql
			m.oldpos = 0
			for m.j = 0 to this.loss step m.step
				m.pos = int(m.reccount*m.j)+1
				if m.pos == m.oldpos
					loop
				endif
				go (m.pos)
				m.stat.add(len*m.reccount)
				m.oldpos = m.pos
			endfor
			if m.count < 0
				m.count = m.stat.count
			endif
			for m.j = this.loss+0.001 to 0.999 step 0.001
				m.pos = int(m.reccount*m.j)+1
				if m.pos == m.oldpos
					loop
				endif
				go (m.pos)
				m.stat.add(len*m.reccount)
				m.oldpos = m.pos
			endfor
		endfor
		select (m.tmp.alias)
		use
		this.messenger.forceMessage("Calculating Potential...")
		m.usePotential = .t.
		m.limit = 1024*1024*1024*1.8
		m.maxsize = this.calculateSize(m.memo, @m.index, m.offset)
		m.potential = this.calculatePotential(m.memo, @m.index, m.count)
		if m.maxsize-m.potential > m.limit
			m.stat = m.memo.item(1)
			m.count = m.stat.count
			m.potential = this.calculatePotential(m.memo, @m.index, m.count)
			m.usePotential = .f.
		endif
		m.newsize = m.maxsize
		this.messenger.forceMessage("Potential "+ltrim(str(m.potential/m.maxsize*100,18,3))+"%")
		do while m.usePotential and m.potential / m.maxsize >= this.potential or m.newsize > m.limit
			m.pos = this.findMaxPotential(@m.index)
			if m.pos == 0
				exit
			endif
			m.stat = m.memo.item(m.pos)
			m.potdif = m.stat.item(m.index[m.pos,1]) - m.stat.item(m.index[m.pos,1]+1)
			m.index[m.pos,1] = m.index[m.pos,1]+1
			m.index[m.pos,2] = m.index[m.pos,2]-m.potdif
			m.potential = m.potential - m.potdif
			m.newsize = m.newsize - m.potdif
			this.messenger.forceMessage("Potential "+ltrim(str(m.potential/m.maxsize*100,18,3))+"%")
		enddo
		if m.newsize > m.limit
			this.messenger.errorMessage("Resulting table to large.")
			return .f.
		endif
		m.newstruc = ""
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			m.j = m.memo.getKey(m.f.getName())
			if m.j > 0
				m.stat = m.memo.item(m.j)
				m.newsize = min(m.stat.item(m.index[m.j,1])/m.reccount,254)
				m.newstruc = m.newstruc+","+m.f.getName()+" C("+ltrim(str(m.newsize,18))+")"
			else
				m.newstruc = m.newstruc+","+m.f.toString()
			endif
		endfor
		if m.truncated
			m.newstruc = m.newstruc+", truncated n(1)"
		endif
		m.newstruc = ltrim(m.newstruc,",")
		this.setRequiredTableStructure(m.newstruc)
		if not BaseTable::create()
			this.messenger.errorMessage("Unable to create Memo2CharTable.")
			return .f.
		endif
		m.struc = this.getTableStructure()
		for m.i = 1 to m.memo.count
			m.j = m.struc.getFieldIndex(m.memo.getKey(m.i))
			m.f = m.struc.getFieldStructure(m.j)
			m.index[m.i,1] = m.j
			m.index[m.i,2] = m.f.getSize()
		endfor
		this.messenger.forceMessage("Transfering...")
		m.norm = createobject("StringNormizer")
		dimension m.value[1]
		m.reccount = "/"+ltrim(str(m.reccount,18))
		m.t = createobject("Timing")
		select (m.table.alias)
		this.messenger.setDefault("Transfered")
		this.messenger.startProgress(m.reccount)
		this.messenger.startCancel("Cancel Operation?","Transferring","Canceled.")
		scan
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				exit
			endif
			scatter to m.value memo
			select (this.alias)
			append blank
			for m.i = 1 to m.memo.count
				m.j = m.index[m.i,1]
				m.str = m.value[m.j]
				if this.word
					m.str = this.truncate(m.str,m.index[m.i,2],m.norm)
				else
					m.str = rtrim(left(m.str,m.index[m.i,2]))
				endif
				if m.truncated
					if len(m.str) != len(rtrim(m.value[m.j]))
						replace truncated with 1
					endif
				endif
				m.value[m.j] = m.str
			endfor
			gather from m.value memo
			select (m.table.alias)
			this.messenger.postProgress()
		endscan
		this.messenger.sneakMessage("Closing...")
		m.i = 1
		m.key = m.table.getKey(m.i)
		do while not empty(m.key)
			this.forceKey(m.key)
			m.i = m.i+1
			m.key = m.table.getKey(m.i)
		enddo
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc
	
	hidden function truncate(str as String, size as Integer, norm as Object)
	local len, normstr, pos
		m.str = rtrim(m.str)
		m.len = len(m.str)
		if m.len <= m.size
			return m.str
		endif
		m.str = left(m.str, m.size)
		m.normstr = m.norm.normizePositional(m.str)
		m.pos = rat(" ",m.normstr)
		if m.pos <= 0
			return m.str
		endif
		if m.pos/m.len <= 0.5
			return m.str
		endif
		return rtrim(left(m.str,m.pos))
	endfunc

	hidden function findMaxPotential(index)
	local i, alen, maxpotential, maxindex
		m.maxpotential = 0
		m.maxindex = 0
		m.alen = alen(m.index,1)
		for m.i = 1 to m.alen
			if m.index[m.i,2] > m.maxpotential
				m.maxindex = m.i
				m.maxpotential = m.index[m.i,2]
			endif
		endfor
		return m.maxindex
	endfunc
	
	hidden function calculatePotential(memo as Collection, index, count as Integer)
	local i, potential, stat
		m.potential = 0
		if not vartype(m.count) == "N"
			m.count = -1
		endif
		for m.i = 1 to m.memo.Count
			m.stat = m.memo.Item(m.i)
			if m.count < 0
				m.index[m.i,2] = m.stat.item(m.index[m.i,1]) - m.stat.item(m.stat.count)
			else
				if m.count == 0
					m.index[m.i,2] = 0
				else
					m.index[m.i,2] = m.stat.item(m.index[m.i,1]) - m.stat.item(min(m.stat.count, m.count))
				endif
			endif
			m.potential = m.potential+m.index[m.i,2]
		endfor		
		return m.potential
	endfunc

	hidden function calculateSize(memo as Collection, index, offset as Integer)
	local i, stat
		if not vartype(m.offset) == "N"
			m.offset = 0
		endif
		for m.i = 1 to m.memo.Count
			m.stat = m.memo.Item(m.i)
			m.offset = m.offset + m.stat.item(m.index[m.i,1])
		endfor
		return m.offset		
	endfunc
enddefine				
			
		
		