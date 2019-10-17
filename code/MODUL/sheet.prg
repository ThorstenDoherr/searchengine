*==========================================================================
*	Modul: 		sheet.prg
*	Date:		2019.10.14
*	Author:		Thorsten Doherr
*	Procedure: 	custom.prg
*	Library:	foxpro.fll
*   Handles:	17
*	Function:	Classes to import and export delimited text files
*               in and out of foxpro tables.
*==========================================================================
define class InsheetTableCluster as TableCluster
	hidden hardSeparators, potentialSeparators
	hidden nonames, nomemos, decode, foxpro, invalidNames, fast
	hidden drop, keep
	hardSeparators = chr(9)+"|"
	potentialSeparators = chr(9)+"|,;"
	nonames = .f.
	nomemos = .f.
	decode = .f.
	marginal = 0
	memoloss = 1.0
	foxpro = .f.
	invalidNames = "FOREIGN"
	fast = .f.
	drop = ""
	keep = ""
	
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
	
	function setFast(fast as Boolean)
		this.fast = m.fast
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
	
	function getFast()
		return this.fast
	endfunc

	function create(file as String)
	local ps1, ps2, ps3, ps4, pa, lm, items, struc
	local separator, handle, i, line, firstline
	local namestruc, forcenames, sql 
	local basecnt, cnt, linecnt, filesize
	local decoder, nonames, crlf, len
	local hist, namehist, norm, tablecount, table
	local modulo, maxlen, parse
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.ps4 = createobject("PreservedSetting","blocksize","64")
		m.lm = createobject("LastMessage",this.messenger)
		m.pa = createobject("PreservedAlias")
		this.messenger.forceMessage("Creating...")
		if not "\FOXPRO.FLL" $ upper(set("library"))
			this.messenger.errormessage("Library foxpro.fll not installed.")
			return .f.
		endif
		if not this.isCreatable()
			this.messenger.errormessage("Unable to create the table/cluster.")
			return .f.
		endif
		if not vartype(m.file) == "C" 
			this.messenger.errormessage("Unable to open the text file.")
			return .f.
		endif
		m.handle = FileOpenRead(17,m.file)
		if m.handle < 0
			this.messenger.errormessage("Unable to open the text file.")
			return .f.
		endif
		m.crlf = this.scanCRLF(m.handle)
		m.decoder = createobject("UniDecoder")
		m.norm = createobject("StringNormizer")
		m.nonames = this.nonames
		dimension m.items[1]
		m.separator = this.scanSeparator(m.handle,m.crlf)
		m.filesize = FileSize(m.handle)
		this.readline(m.handle, m.crlf, @m.firstline)
		if m.nonames
			FileRewind(m.handle)
		endif
		this.initHistogram(@m.hist)
		m.linecnt = 0
		m.maxlen = 0
		m.modulo = 1
		this.readline(m.handle, m.crlf, @m.line)
		this.messenger.setDefault("Parsed")
		this.messenger.startProgress(m.filesize)
		this.messenger.startCancel("Cancel Operation","Parsing","Canceled.")
		do while not (FileEOF(m.handle) and empty(m.line))
			if this.messenger.queryCancel()
				FileClose(m.handle)
				return .f.
			endif
			m.linecnt = m.linecnt+1
			if this.fast
				m.parse = .f.
				m.len = len(rtrim(m.line))
				if m.len > m.maxlen
					m.maxlen = m.len
					m.parse = .t.
				endif
				if mod(m.linecnt,m.modulo) == 0
					m.parse = .t.
					if m.linecnt > 10000
						m.modulo = 10+int(rand()*100)+1
					endif
				endif
			else
				m.parse = .t.
			endif
			if m.parse
				this.separate(@m.items, m.line, m.separator)
				this.rtrimEmptyElements(@m.items)
				if not this.collectHistogram(@m.hist, @m.items)
					this.messenger.errormessage("Invalid structure.")
					FileClose(m.handle)
					return .f.
				endif
			endif
			if m.filesize <= 0
				this.messenger.incProgress()
			else
				this.messenger.setProgress(FilePos(m.handle))
			endif
			this.messenger.postProgress()
			this.readline(m.handle, m.crlf, @m.line)
		enddo
		this.messenger.stopProgress()
		this.messenger.stopCancel()
		dimension m.struc[1,4]
		if m.linecnt > 0
			this.parseHistogram(@m.hist, @m.struc, m.linecnt, iif(this.nomemos, this.memoloss, 0), this.foxpro)
		endif
		if m.linecnt == 0 or vartype(m.struc[1,2]) == "L"
			if empty(m.firstline)
				this.messenger.errormessage("Empty file.")
				FileClose(m.handle)
				return .f.
			endif
			this.separate(@m.items, m.firstline, m.separator)
			this.rtrimEmptyElements(@m.items)
			if not this.collectHistogram(@m.hist, @m.items)
				this.messenger.errormessage("Invalid structure.")
				FileClose(m.handle)
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
			this.separate(@m.items, m.firstline, m.separator)
			this.rtrimEmptyElements(@m.items)
			this.collectHistogram(@m.namehist, @m.items)
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
			if m.nonames or not this.parseNames(@m.struc, @m.items, m.forcenames, m.norm, m.decoder)
				this.collectHistogram(@m.hist, @m.items)
				this.parseHistogram(@m.hist, @m.struc, m.linecnt+1, iif(this.nomemos, this.memoloss, 0), this.foxpro)
				m.basecnt = alen(m.struc,1)
				m.nonames = .t.
			endif
		endif
		m.sql = ""
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
					m.sql = m.sql+" "+m.struc[m.i,2]+" null"
				endif
			endif
		endfor
		if empty(m.sql)
			this.messenger.errormessage("Empty table.")
			FileClose(m.handle)
			return .f.
		endif
		m.sql = substr(m.sql,2)
		m.tablecount = 1
		m.table = createobject("BaseTable",this.getPath()+this.getStart())
		if not m.table.create(m.sql)
			this.messenger.errormessage("Unable to create table with following structure:"+chr(10)+m.sql)
			FileClose(m.handle)
			return .f.
		endif
		m.table.close()
		this.build(m.table.getDBF())
		if not this.appendfile(@m.struc, m.handle, m.separator, m.nonames, m.crlf, m.linecnt, m.norm, m.decoder)
			FileClose(m.handle)
			return .f.
		endif
		this.messenger.forceMessage("Closing...")
		FileClose(m.handle)
		if this.getTableCount() == 0
			this.messenger.errormessage("Unable to verify table cluster.")
			return .f.
		endif
		this.goTop()
		return .t.
	endfunc
	
	function append(file as String, nonames as Boolean)
	local ps1, ps2, ps3, ps4, lm, pa
	local crlf, separator, handle, struc, tstruct
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.ps4 = createobject("PreservedSetting","blocksize","64")
		m.lm = createobject("LastMessage",this.messenger,"")
		m.pa = createobject("PreservedAlias")
		this.messenger.forceMessage("Appending...")
		if not "\FOXPRO.FLL" $ upper(set("library"))
			this.messenger.errormessage("Library foxpro.fll not installed.")
			return .f.
		endif
		m.tstruct = this.getTableStructure()
		if not m.tstruct.isValid()
			this.messenger.errormessage("Unable to access cluster.")
			return .f.
		endif
		dimension m.struc[1]
		acopy(m.tstruct.tstruct,m.struc)
		m.handle = FileOpenRead(17,m.file)
		if m.handle < 0
			this.messenger.errormessage("Unable to open the text file.")
			return .f.
		endif
		m.crlf = this.scanCRLF(m.handle)
		m.separator = this.scanSeparator(m.handle,m.crlf)
		if m.separator == ""
			this.messenger.errormessage("Unable to identify separator.")
			FileClose(m.handle)
			return .f.
		endif
		if not this.appendfile(@m.struc, m.handle, m.separator, m.nonames, m.crlf)
			FileClose(m.handle)
			return .f.
		endif
		FileClose(m.handle)
		this.messenger.forceMessage("")
		return .t.
	endfunc	
	
	function iscreatable()
	local cluster
		if not TableCluster::isCreatable()
			return .f.
		endif
		m.cluster = createobject("TableCluster",this.getPath()+this.getFirstClusterName())
		return m.cluster.iscreatable()
	endfunc
	
	function erase()
	local cluster, rc
		m.rc = TableCluster::erase()
		m.cluster = createobject("TableCluster",this.getPath()+this.getFirstClusterName())
		if m.cluster.getTableCount() > 0
			m.rc = m.rc or m.cluster.erase()
		endif
		return m.rc
	endfunc

	hidden function initHistogram(hist)
	local i, j
		dimension m.hist[254,256]
		for m.i = 1 to 254
			for m.j = 1 to 255 
				m.hist[m.i,m.j] = 0
			endfor
			m.hist[m.i,256] = ""
		endfor
	endfunc

	hidden function dropHistogram(hist)
		dimension m.hist[1,1]
		m.hist[1,1] = .f.
	endfunc
		
	hidden function collectHistogram(hist, items)
	local cnt, i, val, len, item, type, err, numtype
		m.cnt = min(alen(m.items),alen(m.hist,1))
		for m.i = 1 to m.cnt
			m.type = m.hist[m.i,256]
			m.item = m.items[m.i]
			if m.item = "." or upper(m.item) == ".NULL."
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
			if m.len >= 19 
				m.hist[m.i,256] = "C"
				loop
			endif
			m.item = strtran(m.item,",",".")
			m.err = .f.
			try
				m.val = val(m.item)
			catch
				m.err = .t.
			endtry
			if m.err
				m.hist[m.i,256] = "C"
				loop
			endif
			if m.item == "-" or m.item == "+"
				m.hist[m.i,256] = "C"
				loop
			endif
			if ltrim(ltrim(ltrim(rtrim(rtrim(str(m.val,m.len+1,m.len),0,"0"),0,".")),0,"-"),0,".") == ltrim(ltrim(ltrim(ltrim(rtrim(rtrim(m.item,0,"0"),0,"."),0,"-"),0,"+"),0,"0"),0,".")
				m.numtype = 1
			else
				if this.parseNumber(m.item)
					m.numtype = 2
				else
					m.hist[m.i,256] = "C"
					loop
				endif
			endif
			if m.type == "N"
				loop
			endif
			if m.type == "D"
				if m.numtype == 2
					m.hist[m.i,256] = "N"
				endif
				loop
			endif
			if not m.type == "D" and int(m.val) == m.val
				if not m.type == "J"
					if left(m.item,1) == "0" and m.val >= 1
						m.hist[m.i,256] = "J"
					else
						m.hist[m.i,256] = "I"
					endif
				endif
			else
				if m.numtype == 2
					m.hist[m.i,256] = "N"
				else
					m.hist[m.i,256] = "D"
				endif
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
	
	hidden function parseNames(struc, items, forcenames as Boolean, norm as Object, decoder as Object)
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
				m.names = m.names+"dropped "
				loop
			endif
			if m.i > m.cnt
				m.item = ""
			else
				m.item = left(strtran(alltrim(m.norm.normize(m.decoder.decode(m.items[m.i]),"_"))," ","_"),10)
			endif
			if not (left(m.item,1) == "_" or isalpha(m.item))
				if m.forcenames
					if not empty(m.item)
						m.item = "_"+m.item
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
	
	hidden function parseNumber(str as String)
	local items
		dimension m.items[1]
		alines(m.items, upper(m.str), 17, "+", "-", ".", "E")
		return this.subParseNumber(@m.items, 1)
	endfunc
	
	hidden function subParseNumber(items, pos)
	local lex, cnt, point
		m.cnt = alen(m.items)
		m.lex = m.items[m.pos]
		m.point = .f.
		if m.lex == "+" or m.lex == "-" 
			m.pos = m.pos+1
			if m.pos > m.cnt
				return .f.
			endif
			m.lex = m.items[m.pos]
			if not (isdigit(m.lex) or m.lex == ".")
				return .f.
			endif
		else
			if m.lex == "."
				m.pos = m.pos+1
				if m.pos > m.cnt
					return .f.
				endif
				m.point = .t.
				m.lex = m.items[m.pos]
			else
				if left(m.lex,1) == "0" and isdigit(substr(m.lex,2,1))
					return .f.
				endif
			endif
			if not isdigit(m.lex)
				return .f.
			endif
		endif
		m.lex = chrtran(m.lex,"0123456789","")
		if m.lex == "E"
			if m.pos >= m.cnt
				return .f.
			endif
			return this.subParseNumber(@m.items,m.pos+1)
		endif
		if m.lex == "."
			if m.point
				return .f.
			endif
			m.pos = m.pos+1
			if m.pos > m.cnt
				return .f.
			endif
			m.lex = m.items[m.pos]
			if not isdigit(m.lex)
				return .f.
			endif
			m.lex = chrtran(m.lex,"0123456789","")
			if m.lex == "E"
				if m.pos >= m.cnt
					return .f.
				endif
				return this.subParseNumber(@m.items,m.pos+1)
			endif
		endif
		if not m.lex == ""
			return .f.
		endif
		return .t.
	endfunc

	hidden function separate(itemarray, line as String, separator as String)
	local items, cnt, open, i, str, ind, item, quote
		dimension m.items[1]
		m.cnt = alines(m.items, m.line, 2, m.separator)
		dimension m.itemarray[m.cnt]		
		if m.separator $ this.hardSeparators
			for m.i = 1 to m.cnt
				m.item = m.items[m.i]
				m.quote = left(m.item,1)
				if inlist(m.quote,'"',"'") and right(m.item,1) == m.quote and len(m.item) > 1
					m.items[m.i] = alltrim(substr(m.item,2,len(m.item)-2))
				endif
			endfor
			acopy(m.items,m.itemarray)
			return m.cnt
		endif
		m.str = ""
		m.open = .f.
		m.ind = 0
		m.i = 1
		do while m.i <= m.cnt
			m.item = m.items[m.i]
			if m.open
				m.str = m.str+m.separator+m.item
				if right(m.item,1) == m.quote
					m.open = .f.
					m.ind = m.ind+1
					m.itemarray[m.ind] = alltrim(left(m.str,len(m.str)-1))
				endif
			else
				m.quote = left(m.item,1)
				if inlist(m.quote,'"',"'")
					if right(m.item,1) == m.quote and len(m.item) > 1
						m.ind = m.ind+1
						m.itemarray[m.ind] = alltrim(substr(m.item,2,len(m.item)-2))
					else
						if mod(occurs(m.quote,m.item),2) == 0
							m.ind = m.ind+1
							m.itemarray[m.ind] = m.item
						else
							m.str = substr(m.item,2)
							m.open = .t.
						endif
					endif
				else
					m.ind = m.ind+1
					m.itemarray[m.ind] = m.item
				endif
			endif
			m.i = m.i+1
		enddo
		if m.open 
			m.ind = m.ind+1
			m.itemarray[m.ind] = m.str
		endif
		if m.ind > 0
			dimension m.itemarray[m.ind]
		else
			dimension m.itemarray[1]
			m.itemarray[1] = ""
		endif
		if m.ind < m.cnt
			dimension m.itemarray[m.ind]
		endif
		return m.ind
	endfunc
	
	hidden function rtrimEmptyElements(itemarray)
	local cnt
		for m.cnt = alen(m.itemarray) to 1 step -1
			if not empty(m.itemarray[m.cnt])
				dimension m.itemarray[m.cnt]
				return m.cnt
			endif
		endfor
		return m.cnt
	endfunc
	
	hidden function truncate(str as String, size as Integer, norm as Object)
	local pos
		m.str = rtrim(m.str)
		if len(m.str) <= m.size
			return m.str
		endif
		m.str = left(m.str, m.size)
		m.pos = rat(" ",m.norm.normizePositional(m.str))
		if m.pos/len(m.str) <= 0.5
			return m.str
		endif
		return rtrim(left(m.str,m.pos))
	endfunc

	hidden function scanCRLF(handle)
	local cnt, line, cr
		m.cnt = 0
		m.cr = chr(13)
		m.line = FileReadLF(m.handle)
		do while not FileEOF(m.handle)
			if right(m.line,1) == m.cr
				FileRewind(m.handle)
				return .t.
			endif
			m.cnt = m.cnt + 1
			if m.cnt > 512
				FileRewind(m.handle)
				return .f.
			endif
		enddo
		FileRewind(m.handle)
		return .f.
	endfunc
	
	hidden function scanSeparator(handle, crlf)
	local dif, separator, basecnt, i, col, sep
		m.dif = -1
		m.separator = ""
		m.basecnt = 0
		for m.i = 1 to len(this.potentialSeparators)
			m.sep = substr(this.potentialSeparators,m.i,1)
			m.col = this.evaluateSeparator(m.handle, m.sep, m.crlf)
			if m.col.count != 3
				loop
			endif
			if m.col.item(2) > 1
				if m.dif < 0 or m.col.item(3) < m.dif
					m.dif = m.col.item(3)
					m.basecnt = m.col.item(1)
					m.separator = m.sep
				endif
			endif
		endfor
		if len(m.separator) == 0 or inlist(m.separator,",",";") and m.dif > 0.05
			m.separator = chr(13)
		endif
		return m.separator
	endfunc
	
	hidden function evaluateSeparator(handle, sep, crlf)
	local i, sepcnt, items, cnt, avg, sum, dif, col, line, max
		dimension m.sepcnt[100]
		dimension m.items[1]
		m.cnt = 0
		m.avg = 0
		m.sum = 0
		m.dif = 0
		m.max = 0
		m.col = createobject("Collection")
		FileRewind(m.handle)
		for m.i = 1 to 100
			this.readline(m.handle, m.crlf, @m.line)
			if FileEOF(m.handle)
				exit
			endif
			m.cnt = this.separate(@m.items, m.line, m.sep)
			m.sum = m.sum+m.cnt
			m.sepcnt[m.i] = m.cnt
			if m.cnt > m.max
				m.max = m.cnt
			endif
		endfor
		FileRewind(m.handle)
		if m.sum == 0 
			return m.col
		endif
		m.cnt = m.i-1
		m.avg = m.sum/m.cnt
		for m.i = 1 to m.cnt
			m.dif = m.dif+abs(m.sepcnt[m.i]-m.avg)
		endfor
		m.col.add(m.max)
		m.col.add(m.avg)
		m.col.add(m.dif/m.sum)
		return m.col
	endfunc

	hidden function readline(handle as Integer, crlf as Boolean, line)  && line by reference: @m.line
		if m.crlf
			m.line = FileReadCRLF(m.handle)
		else
			m.line = FileReadLF(m.handle)
		endif
	endfunc
	
	hidden function getFirstClusterName()
		if this.getFirst() == 1
			return this.getStart()
		endif
		return this.getStart()+iif(isdigit(right(this.getStart(),1)),"_1","1")
	endfunc
	
	hidden function appendfile(struc, handle, separator, nonames, crlf, linecnt, norm, decoder)
	local table, blocksize, datasize, size, sizememo, sizelimit
	local line, basecnt, cnt, ins, val, i, err, len
	local item, items, sizerec, tablecount, fresh, hasmemo, struct
		m.tablecount = this.getTableCount()
		m.table = this.getTable(m.tablecount)
		m.struct = m.table.getTableStructure()
		m.blocksize = val(sys(2012,m.table.alias))
		m.datasize = m.blocksize - 8
		m.sizerec = m.table.getRecordSize()
		m.fresh = (m.tablecount == 1 and m.table.reccount() == 0)
		m.size = 0
		m.sizememo = 0
		m.sizelimit = 1024 * 1024 * 1024 * 2 - 100 * 1024 * 1024
		m.basecnt = alen(m.struc,1)
		m.hasmemo = .f.
		for m.i = 1 to m.basecnt
			if m.struc[m.i,2] == "M"
				m.hasmemo = .t.
				exit
			endif
		endfor
		if not vartype(m.norm) == "O"
			m.norm = createobject("StringNormizer")
		endif
		if not vartype(m.decoder) == "O"
			m.decoder = createobject("UniDecoder")
		endif
		dimension m.items[1]
		FileRewind(m.handle)
		if m.nonames == .f.
			this.readline(m.handle, m.crlf, @m.line)
		endif
		m.linecnt = evl(m.linecnt,0)
		this.readline(m.handle, m.crlf, @m.line)
		this.messenger.setDefault("Appended")
		this.messenger.startProgress(m.linecnt)
		this.messenger.startCancel("Cancel Operation","Appending","Canceled.")
		do while not (FileEOF(m.handle) and empty(m.line))
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				return .f.
			endif
			m.cnt = this.separate(@m.items, m.line, m.separator)
			m.cnt = min(m.basecnt, m.cnt)
			m.ins = ""
			m.val = ""
			for m.i = 1 to m.cnt
				if inlist(m.struc[m.i,2],"X","x")
					loop
				endif
				m.item = m.items[m.i]
				if not empty(m.item)
					if upper(m.item) == ".NULL."
						if m.struc[m.i,5] == .t.
							m.items[m.i] = .NULL.
						else
							loop
						endif
					else
						if m.struc[m.i,2] == "C"
							if this.decode
								m.items[m.i] = m.decoder.decode(m.item)
							endif
							if len(m.items[m.i]) > m.struc[m.i,3]
								m.items[m.i] = this.truncate(m.items[m.i], m.struc[m.i,3], m.norm)
							endif 
						else
							if m.struc[m.i,2] == "M"
								if this.decode
									m.items[m.i] = m.decoder.decode(m.item)
								endif
								m.len = len(m.items[m.i])
								if m.len > 0
									m.sizememo = m.sizememo + (int((m.len-1) / m.datasize) + 1) * m.blocksize
								endif
							else					
								if m.item == "."
									m.items[m.i] = .NULL.
								else				
									m.items[m.i] = val(strtran(m.item,",","."))
								endif
							endif
						endif
					endif
					m.ins = m.ins+","+m.struc[m.i,1]
					m.val = m.val+",m.items["+ltrim(str(m.i,18))+"]"
				endif
			endfor
			m.size = m.size + m.sizerec
			if m.size > m.sizelimit or m.sizememo > m.sizelimit
				m.table.close()
				if m.fresh
					m.fresh = .f.
					if not this.getfirst() == 1
						m.err = .f.
						try
							rename (m.table.getDBF()) to (this.getPath()+this.getFirstClusterName()+".dbf")
							if m.hasmemo
								rename (this.getPath()+this.getStart()+".fpt") to (this.getPath()+this.getFirstClusterName()+".fpt")
							endif
						catch
							m.err = .t.
						endtry
						if m.err
							this.messenger.errormessage("Unable to define first cluster table.")
							return .f.
						endif
						this.build(this.getPath()+this.getFirstClusterName(),1)
					endif
				endif
				m.table = createobject("BaseTable",this.createTableName(this.getFirst()+m.tablecount))
				m.tablecount = m.tablecount + 1
				if not m.table.create(m.struct)
					this.messenger.errormessage("Unable to create cluster table.")
					return .f.
				endif
				this.rebuild(m.tablecount)
				m.size = 0
				m.sizememo = 0
			endif
			if not empty(m.ins)
				m.ins = "insert into "+m.table.alias+"("+substr(m.ins,2)+") values ("+substr(m.val,2)+")"
				&ins
			else
				append blank in (m.table.alias)
			endif
			this.messenger.postProgress()
			this.readline(m.handle, m.crlf, @m.line)
		enddo
		return .t.
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
	local outtable, i, rc, mess
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		this.messenger.forceMessage("Exporting...")
		if this.cluster.count == 0
			this.messenger.errorMessage("Nothing to export.")
			return .f.
		endif
		for m.i = 1 to this.cluster.count
			m.outtable = createobject("OutsheetTable",this.getTable(m.i))
			this.messenger.forceMessage("Exporting "+proper(m.outtable.getPureName()))
			m.outtable.setSeparator(this.separator)
			m.outtable.setHeader(this.header)
			m.outtable.setQuoted(this.quoted)
			m.mess = m.outtable.getMessenger()
			m.mess.setSilent(.t.)
			if m.i == 1
				m.rc = m.outtable.outsheet(m.file, m.fieldlist)
			else
				m.rc = m.outtable.outsheet(m.file, m.fieldlist, .t.)
			endif
			if m.rc == .f.
				if m.mess.isError()
					this.messenger.errorMessage(m.mess.getMessage())
				else
					this.messenger.errorMessage("Unable to export.")
				endif
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
	
	function outsheet(file as String, fieldlist, append as Boolean)
	local ps1, ps2, ps3, pa, pk, lm, header, struc, con
	local converter, cnt, i, handle, f, sep, exp, line
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
		if not vartype(m.append) == "L" 
			this.messenger.errormessage("Invalid parameter.")
			return .f.
		endif
		m.header = this.header
		if not file(m.file)
			m.append = .f.
		endif
		if vartype(m.file) == "C"
			if m.append
				m.handle = FileOpenAppend(17,m.file)
				if m.handle > 0
					m.header = .f.
				else
					m.handle = FileOpenWrite(17,m.file)
				endif
			else
				m.handle = FileOpenWrite(17,m.file)
			endif
		else
			m.handle = FileOpenWrite(17,lower(this.getPath()+this.getPureName())+".txt")
		endif
		if m.handle <= 0
			this.messenger.errormessage("Unable to create export file.")
			return .f.
		endif
		m.exp = ""
		m.sep = this.separator
		m.line = ""
		m.converter = createobject("Collection")
		m.cnt = m.struc.getFieldCount()
		for m.i = 1 to m.cnt
			m.f = m.struc.getFieldStructure(m.i)
			if this.quoted
				m.con = m.f.quotedConverter()
			else
				m.con = m.f.exportConverter()
			endif			
			if len(m.exp)+len(m.con) > 4096
				m.converter.add(substr(m.exp,8))
				m.exp = ""
			endif
			m.exp = m.exp+'+m.sep+'+m.con
			if m.header
				m.line = m.line+m.sep+lower(m.f.getName())
			endif
		endfor
		if not empty(m.exp)
			m.converter.add(substr(m.exp,8))
		endif
		m.exp = ""
		if not empty(m.line)
			m.line = substr(m.line,len(m.sep)+1)
			FileWriteCRLF(m.handle,m.line)
		endif
		this.setKey()
		this.select()
		this.messenger.setDefault("Exported")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation","Exporting","Canceled.")
		scan
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				exit
			endif
			m.line = evaluate(m.converter.item(1))
			for m.i = 2 to m.converter.count
				m.line = m.line+m.sep+evaluate(m.converter.item(m.i))
			endfor		
			FileWriteCRLF(m.handle, m.line)
			this.messenger.postProgress()
		endscan
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
			
		
		