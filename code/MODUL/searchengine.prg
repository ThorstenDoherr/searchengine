*=========================================================================*
*    Modul:      searchengine.prg
*    Date:       2020.01.15
*    Author:     Thorsten Doherr
*    Procedure:  custom.prg
*                cluster.prg
*                path.prg (only for SearchEngine.groupedExport())
*                sheet.prg (only for SearchEngine.import())
*   Library:     foxpro.fll
*   Handles:     11, 12, 13, 14, 15
*   Function:    The SearchEngine executes a heuristic search using special
*                tables containing all the words of the base table, their
*                occurencies, references to the original base table and a
*                control table with heuristical parameters. The result table
*                includes the key of the searched record, the key of the
*                found record and an identity percentage.
*=========================================================================*
#define DEFSEARCHDEPTH  262144
#define MAXSEARCHDEPTH 1048576
#define MAXWORDCOUNT 2048
#define DEFLRCPDSCOPE 12
#define LOGHANDLE 11
#define RUNHANDLE 12
#define EXPORTHANDLE 13
#define OUTHANDLE 14
#define INHANDLE 15
#define TOLERANCE 0.000001

define class LexArray as Custom
	dimension lex[1]
	size = 0
	
	function init(str as String)
		this.size = alines(this.lex,m.str,5," ")
	endfunc
enddefine

define class LRCPD as Custom  && Least Character Position Delta
	hidden ala, bla, alen, blen, dynamic, weight, astr, bstr
	dynamic = .f.
	alen = -1
	blen = -1
	weight = 1
	scope = DEFLRCPDSCOPE
	
	function init()
		this.setA("")
		this.setB("")
	endfunc
	
	function setDynamic(dynamic as Boolean)
		this.dynamic = m.dynamic
	endfunc
	
	function setWeight(weight as Double)
		this.weight = m.weight
	endfun
	
	function setScope(scope as Integer)
		this.scope = m.scope
	endfunc
	
	function setA(a as String)
		this.astr = strtran(m.a," ","")
		this.alen = len(this.astr)
		this.ala = createobject("LexArray",m.a)
	endfunc
	
	function setB(b as String)
		this.bstr = strtran(m.b," ","")
		this.blen = len(this.bstr)
		this.bla = createobject("LexArray",m.b)
	endfunc
	
	function compare()
		if this.dynamic and this.blen > this.alen
			return this._compare(this.bla,this.blen,this.ala)*this.weight
		endif
		return this._compare(this.ala,this.alen,this.bla)*this.weight
	endfunc
	
	hidden function _compare(ala, alen, bla)
	local ai, aw, bi, bw
	local sum, score, len, comp
	local test
		if m.alen <= 0
			if m.bla.size == 0
				return 1
			endif
			return 0
		endif
		m.sum = 0
		for m.ai = 1 to m.ala.size
			m.aw = m.ala.lex[m.ai]
			m.len = len(m.aw)
			m.score = 0
			for m.bi = 1 to m.bla.size
				m.bw = m.bla.lex[m.bi]
				m.comp = compare(m.aw,m.bw,this.scope) && set library to foxpro.fll
				if m.comp > m.score
					m.test = m.bw
					m.score = m.comp
					if m.score == 1
						exit
					endif
				endif
			endfor
			m.sum = m.sum+m.score*m.len
		endfor
		return max(m.sum/m.alen, compare(this.astr, this.bstr, this.scope))
	endfunc	
enddefine

define class RunFilter as Custom
	hidden run[256], valid, start, filtering
	
	function init(filter as String)
	local i, j, lexcnt, lexArray, subcnt, subArray, val, runset
		this.start = -1
		this.valid = .f.
		this.filtering = .f.
		m.runset = .f.
		if empty(m.filter)
			for m.i = 1 to 255
				this.run[m.i] = .t.
			endfor
			this.run[256] = .f.
			this.valid = .t.
			return
		endif
		if vartype(m.filter) == "N"
			m.filter = ltrim(str(m.filter))
		endif
		if not vartype(m.filter) == "C"
			return
		endif
		dimension m.lexArray[1]
		dimension m.subArray[1]
		m.lexcnt = alines(m.lexArray,m.filter,5,",")
		for m.i = 1 to m.lexcnt
			if like("start *",m.lexArray[m.i])
				m.val = val(getwordnum(m.lexArray[m.i],2," "))
				if m.val <= 0
					return
				endif
				this.start = m.val
				loop
			endif
			m.subcnt = alines(m.subArray,m.lexArray[m.i],5,"-")
			if m.subcnt > 2
				return
			endif
			for m.j = 1 to m.subcnt
				m.val = val(m.subArray[m.j])
				if m.val <= 0 or m.val > 255 or not (ltrim(str(m.val,3)) == m.subArray[m.j])
					return
				endif
				m.subArray[m.j] = m.val
			endfor
			if m.subcnt == 1
				this.run[m.subArray[1]] = .t.
				m.runset = .t.
			else
				if m.subArray[1] > m.subArray[2]
					return
				endif
				m.runset = .t.
				for m.j = m.subArray[1] to m.subArray[2]
					this.run[m.j] = .t.
				endfor
			endif
		endfor
		if this.start < 0 and m.runset == .f.
			return
		endif
		if m.runset == .f.
			for m.i = 1 to 255
				this.run[m.i] = .t.
			endfor
		endif
		this.valid = .t.
		this.filtering = this.start > 0 or m.runset == .t.
	endfunc
	
	function isValid()
		return this.valid
	endfunc
	
	function isFiltering()
		return this.filtering
	endfunc
	
	function isFiltered(run as Integer)
		if m.run <= 0 or m.run > 255
			return .f.
		endif
		return this.run[m.run]
	endfunc

	function inRange(run as Integer, record as Integer)
		return this.isFiltered(m.run) and m.record >= this.start
	endfunc
	
	function getRunFilter(exp as String)
	local filter, i, start
		m.filter = ""
		m.exp = alltrim(m.exp)
		m.start = 0
		for m.i = 1 to 256
			if this.run[m.i] == .f.
				if m.start <= 0
					loop
				endif
				if m.i-m.start > 1
					m.filter = m.filter+" and "+m.exp+" >= "+ltrim(str(m.start))+" and "+m.exp+" <= "+ltrim(str(m.i-1))
				else
					m.filter = m.filter+" and "+m.exp+" == "+ltrim(str(m.start))
				endif
				m.start = 0
			else
				if m.start == 0
					m.start = m.i
				endif
			endif
		endfor
		return substr(m.filter, 6)
	endfunc
	
	function getStart()
		return this.start
	endfunc
enddefine

define class MetaFilter as Custom
	count = 0
	size = 0
	dimension meta[1]
	
	function init(filter as String, types as SearchTypes)
	local lexArray, lexcnt, subArray, subcnt, auxArray, auxcnt
	local count, val, i, j, start, stop, default
		if vartype(m.types) == "N"
			m.count = m.types
		else
			m.count = m.types.getSearchTypeCount()
		endif
		if m.count <= 0
			return
		endif
		dimension this.meta[m.count]
		dimension m.lexArray[1]
		dimension m.subArray[1]
		dimension m.auxArray[1]
		m.default = 5
		if vartype(m.filter) == "C" and not empty(m.filter)
			m.lexcnt = alines(m.lexArray,m.filter,5,";")
			for m.i = 1 to m.lexcnt
				m.subcnt = alines(m.subArray,m.lexArray[m.i],5,"=")
				if m.subcnt != 2
					return
				endif
				m.val = val(m.subArray[m.subcnt])
				if m.val < 0 or not ltrim(str(m.val)) == m.subArray[m.subcnt]
					return
				endif
				m.subcnt = alines(m.subArray,m.subArray[1],5,",")
				for m.j = 1 to m.subcnt
					m.auxcnt = alines(m.auxArray,m.subArray[m.j],5,"-")
					if m.auxcnt > 2
						return
					endif
					m.start = val(m.auxArray[1])
					if m.start < 1 or m.start > m.count or not ltrim(str(m.start)) == m.auxArray[1]
						return
					endif
					if m.auxcnt == 2
						m.stop = val(m.auxArray[2])
						if m.stop < m.start or not ltrim(str(m.stop)) == m.auxArray[2]
							return
						endif
						if m.stop > m.count
							m.stop = m.count
						endif
					else
						m.stop = m.start
					endif
					for m.start = m.start to m.stop
						this.meta[m.start] = m.val
					endfor
				endfor
			endfor
		endif
		for m.i = 1 to m.count
			if not vartype(this.meta[m.i]) == "N"
				this.meta[m.i] = m.default
			endif
			this.size = this.size+this.meta[m.i]
		endfor
		this.count = m.count
	endfunc
		
	function isValid()
		return vartype(this.count) == "N" and this.count == alen(this.meta)
	endfunc
enddefine

define class PhonoRule as Custom
	protected phono, code
	
	function init(code as String, phono as String)
		this.phono = m.phono
		this.code = m.code
	endfunc
	
	function evaluate(str as String, pos as Integer)
		return this.code
	endfunc
enddefine

define class PhonoRuleNext as PhonoRule
	function evaluate(str as String, pos as Integer)
		if substr(m.str,m.pos+1,1) $ this.phono
			return this.code
		endif
		return .f.
	endfunc
enddefine

define class PhonoRulePrev as PhonoRule
	function evaluate(str as String, pos as Integer)
		if substr(m.str,m.pos-1,1) $ this.phono
			return this.code
		endif
		return .f.
	endfunc
enddefine

define class PhonoRuleWordStart as PhonoRule
	function evaluate(str as String, pos as Integer)
		if empty(substr(m.str,m.pos-1,1)) and substr(m.str,m.pos+1,1) $ this.phono
			return this.code
		endif
		return .f.
	endfunc
enddefine

define class PhonoRuleWordStop as PhonoRule
	function evaluate(str as String, pos as Integer)
		if empty(substr(m.str,m.pos+1,1)) and substr(m.str,m.pos-1,1) $ this.phono
			return this.code
		endif
		return .f.
	endfunc
enddefine

define class PhonoRulePattern as PhonoRule
	hidden pattern[1,3], cnt
	function init(code as String, phono as String, char as Character)
	local i, word
		this.cnt = getwordcount(m.phono)
		if this.cnt > 0
			dimension this.pattern[this.cnt,3]
		endif
		for m.i = 1 to this.cnt
			m.word = getwordnum(m.phono,m.i)
			this.pattern[m.i,1] = strtran(m.word,"*",m.char)
			this.pattern[m.i,2] = at("*", m.word)-1
			this.pattern[m.i,3] = len(m.word)
		endfor
		this.code = m.code
	endfunc

	function evaluate(str as String, pos as Integer)
	local i, word
		for m.i = 1 to this.cnt
			m.word = substr(m.str, m.pos-this.pattern[m.i,2],this.pattern[m.i,3])
			if m.word == this.pattern[m.i,1]
				return this.code
			endif
		endfor
		return .f.
	endfunc
enddefine

define class PhonoRuleExp as PhonoRule
	hidden rules[10,3], cnt, position, length
	function init(code as String, phono as String, char as Character)
	local i, word
		m.phono = strtran(m.phono,"["," [")
		m.phono = strtran(m.phono,"]","] ")
		m.phono = strtran(m.phono,"{"," {")
		m.phono = strtran(m.phono,"}","} ")
		this.cnt = getwordcount(m.phono)
		if this.cnt > 0
			dimension this.rules[this.cnt,3]
		endif
		this.length = 0
		for m.i = 1 to this.cnt
			m.word = getwordnum(m.phono,m.i)
			do case
				case left(m.word,1) == "["
					m.word = strtran(m.word,"[","")
					m.word = strtran(m.word,"]","")
					this.rules[m.i,2] = 1
					this.rules[m.i,3] = 2
				case left(m.word,1) == "{"
					m.word = strtran(m.word,"}","")
					m.word = strtran(m.word,"{","")
					this.rules[m.i,2] = 1
					this.rules[m.i,3] = 3
				case "*" $ m.word
					this.position = at("*", m.word)-1+this.length
					m.word = strtran(m.word,"*",m.char)
					this.rules[m.i,2] = len(m.word)
					this.rules[m.i,3] = 1
				otherwise
					this.rules[m.i,2] = len(m.word)
					this.rules[m.i,3] = 1
			endcase
			this.rules[m.i,1] = m.word
			this.length = this.length+this.rules[m.i,2]
		endfor
		this.code = m.code
	endfunc

	function evaluate(str as String, pos as Integer)
	local i, word
		m.pos = m.pos-this.position
		for m.i = 1 to this.cnt
			m.word = substr(m.str, m.pos, this.rules[m.i,2])
			do case
				case this.rules[m.i,3] == 2
					if not m.word $ this.rules[m.i,1]
						return .f.
					endif
				case this.rules[m.i,3] == 3
					if m.word $ this.rules[m.i,1]
						return .f.
					endif
				otherwise
					if not m.word == this.rules[m.i,1]
						return .f.
					endif
			endcase
			m.pos = m.pos+this.rules[m.i,2]
		endfor
		return this.code
	endfunc
enddefine

define class Phonetic as Custom
	protected rules[26], normizer

	function init(normizer as Object)
	local i
		if not vartype(m.normizer) == "O"
			this.normizer = createobject("StringNormizer")
		else
			this.normizer = m.normizer
		endif
		for m.i = 1 to 26
			this.rules[m.i] = createobject("Collection")
		endfor
	endfunc

	function getNormizer()
		return this.normizer
	endfunc

	function normizedEncode(str as String)
		return this.directEncode(this.normizer.normize(m.str))
	endfunc
	
	function directEncode(str as String)
		return m.str
	endfunc
	
	protected function encode(str as String)
	local pos, ind, i, phono, len, code, rule
		m.phono = ""
		m.len = len(m.str)
		for m.pos = 1 to m.len
			m.ind = asc(substr(m.str,m.pos,1))-64
			if m.ind < 1 or m.ind > 26
				loop
			endif
			m.rule = this.rules[m.ind]
			for m.i = 1 to m.rule.count
				m.code = m.rule.item(m.i).evaluate(@m.str, m.pos)
				if vartype(m.code) == "C"
					m.phono = m.phono+m.code
					exit
				endif
			endfor
		endfor
		return m.phono
	endfunc
	
	protected function compress(str as String)
	local len, i, newstr, chr, last
		m.len = len(m.str)
		m.newstr = substr(m.str,1,1)
		m.last = m.newstr
		for m.i = 2 to m.len
			m.chr = substr(m.str,m.i,1)
			if not m.chr == m.last
				m.last = m.chr
				m.newstr = m.newstr + m.chr
			endif
		endfor
		return m.newstr
	endfunc	
enddefine

define class Cologne as Phonetic
	function init(normizer as Object)
		Phonetic::init(m.normizer)
		this.rules[1].add(createobject("PhonoRule","0",""))  && A
		this.rules[2].add(createobject("PhonoRule","1",""))  && B
		this.rules[3].add(createobject("PhonoRulePrev","8","SZ"))  && C
		this.rules[3].add(createobject("PhonoRuleNext","4","AHKOQUX"))  && C
		this.rules[3].add(createobject("PhonoRuleWordStart","4","LR"))  && C
		this.rules[3].add(createobject("PhonoRule","8",""))  && C
		this.rules[4].add(createobject("PhonoRuleNext","8","CSZ"))  && D
		this.rules[4].add(createobject("PhonoRule","2",""))  && D
		this.rules[5] = this.rules[1]  && E
		this.rules[6].add(createobject("PhonoRule","3",""))  && F
		this.rules[7].add(createobject("PhonoRule","4",""))  && G
		this.rules[8].add(createobject("PhonoRule","",""))  && H
		this.rules[9] = this.rules[1]  && I
		this.rules[10] = this.rules[1]  && J
		this.rules[11] = this.rules[7]  && K
		this.rules[12].add(createobject("PhonoRule","5",""))  && L
		this.rules[13].add(createobject("PhonoRule","6",""))  && M
		this.rules[14] = this.rules[13]  && N
		this.rules[15] = this.rules[1]  && O
		this.rules[16].add(createobject("PhonoRuleNext","3","H"))  && P
		this.rules[16].add(createobject("PhonoRule","1",""))  && P
		this.rules[17] = this.rules[7]  && Q
		this.rules[18].add(createobject("PhonoRule","7","")) && R
		this.rules[19].add(createobject("PhonoRule","8",""))  && S
		this.rules[20] = this.rules[4]  && T
		this.rules[21] = this.rules[1]  && U
		this.rules[22] = this.rules[6]  && V
		this.rules[23] = this.rules[6]  && W
		this.rules[24].add(createobject("PhonoRulePrev","8","CKQ")) && X
		this.rules[24].add(createobject("PhonoRule","48","")) && X
		this.rules[25] = this.rules[1]  && Y
		this.rules[26] = this.rules[19]  && Z		
	endfunc
		
	function directEncode(str as String)
	local cologne
		m.cologne = this.compress(this.encode(m.str))
		return left(m.cologne,1)+strtran(substr(m.cologne,2),"0","")
	endfunc
enddefine
			
define class Metaphone as Phonetic
	function init(normizer as Object)
		Phonetic::init(m.normizer)
		&& A
		this.rules[2].add(createobject("PhonoRuleWordStop","","M"))  && B
		this.rules[2].add(createobject("PhonoRule","B",""))  && B
		this.rules[3].add(createobject("PhonoRulePattern","K","S*H","C"))  && C
		this.rules[3].add(createobject("PhonoRulePattern","X","*IA *H","C"))  && C
		this.rules[3].add(createobject("PhonoRulePattern","","S*I S*E S*Y","C"))  && C
		this.rules[3].add(createobject("PhonoRuleNext","S","IEY"))  && C
		this.rules[3].add(createobject("PhonoRule","K",""))  && C
		this.rules[4].add(createobject("PhonoRulePattern","J","*GE *GY *GI","D"))  && D
		this.rules[4].add(createobject("PhonoRule","T",""))  && D
		&& E
		this.rules[6].add(createobject("PhonoRule","F",""))  && F
		this.rules[7].add(createobject("PhonoRuleWordStop","K","H"))  && G
		this.rules[7].add(createobject("PhonoRuleExp","K","*H[AEIOU]","G"))  && G
		this.rules[7].add(createobject("PhonoRuleNext","","HN"))  && G
		this.rules[7].add(createobject("PhonoRulePattern","","D*E D*Y D*I","G"))  && G
		this.rules[7].add(createobject("PhonoRuleNext","J","IEY"))  && G
		this.rules[7].add(createobject("PhonoRule","K",""))  && G
		this.rules[8].add(createobject("PhonoRulePrev","","CSPTG"))  && H
		this.rules[8].add(createobject("PhonoRuleExp","","[AEIOU]*{AEIOU}","H"))  && H
		this.rules[8].add(createobject("PhonoRule","H",""))  && H
		&& I
		this.rules[10].add(createobject("PhonoRule","J",""))  && J
		this.rules[11].add(createobject("PhonoRulePrev","","C"))  && K
		this.rules[11].add(createobject("PhonoRule","K",""))  && K
		this.rules[12].add(createobject("PhonoRule","L",""))  && L
		this.rules[13].add(createobject("PhonoRule","M",""))  && M
		this.rules[14].add(createobject("PhonoRule","N",""))  && N
		&& O
		this.rules[16].add(createobject("PhonoRuleNext","F","H"))  && P
		this.rules[16].add(createobject("PhonoRule","P",""))  && P
		this.rules[17].add(createobject("PhonoRule","K",""))  && Q
		this.rules[18].add(createobject("PhonoRule","R","")) && R
		this.rules[19].add(createobject("PhonoRulePattern","X","*H *IO *IA","S"))  && S
		this.rules[19].add(createobject("PhonoRule","S","")) && S
		this.rules[20].add(createobject("PhonoRuleNext","0","H"))  && T
		this.rules[20].add(createobject("PhonoRulePattern","X","*IA *IO","T"))  && T
		this.rules[20].add(createobject("PhonoRulePattern","","*CH","T"))  && T
		this.rules[20].add(createobject("PhonoRule","T",""))  && T
		&& U
		this.rules[22].add(createobject("PhonoRule","F",""))  && V
		this.rules[23].add(createobject("PhonoRuleExp","W","*[AEIOU]","W"))  && W
		this.rules[24].add(createobject("PhonoRule","KS","")) && X
		this.rules[25].add(createobject("PhonoRuleExp","Y","*[AEIOU]","Y"))  && Y
		this.rules[26].add(createobject("PhonoRule","S",""))  && Z		
	endfunc
		
	function directEncode(str as String)
	local meta
		m.str = alltrim(m.str)
		do case
			case left(m.str,1) == "X"
				m.str = "S"+substr(m.str,2)
			case left(m.str,2) == "WH"
				m.str = "W"+substr(m.str,3)
			case inlist(left(m.str,2),"AE", "GN", "KN", "PN", "WR")
				m.str = substr(m.str,2)
		endcase
		if "GG" $ m.str
			m.str = strtran(m.str,"GGE","G?I")
			m.str = strtran(m.str,"GGI","G?E")
			m.str = strtran(m.str,"GGY","G?Y")
		endif
		m.str = this.compress(m.str)
		m.meta = this.encode(m.str)
		if substr(m.str,1,1) $ "AEIOU"
			m.meta = substr(m.str,1,1)+m.meta
		endif
		return m.meta
	endfunc
enddefine

define class Soundex as Phonetic
	function init(normizer as Object)
		Phonetic::init(m.normizer)
		this.rules[1].add(createobject("PhonoRule","0",""))  && A
		this.rules[2].add(createobject("PhonoRule","1",""))  && B
		this.rules[3].add(createobject("PhonoRule","2",""))  && C
		this.rules[4].add(createobject("PhonoRule","3",""))  && D
		this.rules[5] = this.rules[1]  && E
		this.rules[6]= this.rules[2]  && F
		this.rules[7] = this.rules[3]  && G
		this.rules[8] = this.rules[1]  && H
		this.rules[9] = this.rules[1]  && I
		this.rules[10] = this.rules[3]  && J
		this.rules[11] = this.rules[3]  && K
		this.rules[12].add(createobject("PhonoRule","4",""))  && L
		this.rules[13].add(createobject("PhonoRule","5",""))  && M
		this.rules[14] = this.rules[13]  && N
		this.rules[15] = this.rules[1]  && O
		this.rules[16] = this.rules[2]  && P
		this.rules[17] = this.rules[3]  && Q
		this.rules[18].add(createobject("PhonoRule","6","")) && R
		this.rules[19] = this.rules[3]  && S
		this.rules[20] = this.rules[4]  && T
		this.rules[21] = this.rules[1]  && U
		this.rules[22] = this.rules[2]  && V
		this.rules[23] = this.rules[1]  && W
		this.rules[24] = this.rules[3]  && X
		this.rules[25] = this.rules[1]  && Y
		this.rules[26] = this.rules[3]  && Z		
	endfunc

	function directEncode(str as String)
	local sound, first
		m.first = left(m.str,1)
		m.sound = this.compress(this.encode(substr(m.str,2)))
		return m.first+strtran(m.sound,"0","")
	endfunc
enddefine

define class ExtendedSoundex as Soundex
	function init(normizer as Object)
		Phonetic::init(m.normizer)
		this.rules[1].add(createobject("PhonoRule","0",""))  && A
		this.rules[2].add(createobject("PhonoRule","1",""))  && B
		this.rules[3].add(createobject("PhonoRule","3",""))  && C
		this.rules[4].add(createobject("PhonoRule","6",""))  && D
		this.rules[5] = this.rules[1]  && E
		this.rules[6].add(createobject("PhonoRule","2",""))  && F
		this.rules[7] = this.rules[4]  && G
		this.rules[8].add(createobject("PhonoRule","0",""))  && H
		this.rules[9] = this.rules[1]  && I
		this.rules[10] = this.rules[7]  && J
		this.rules[11] = this.rules[3]  && K
		this.rules[12].add(createobject("PhonoRule","7",""))  && L
		this.rules[13].add(createobject("PhonoRule","8",""))  && M
		this.rules[14] = this.rules[13]  && N
		this.rules[15] = this.rules[1]  && O
		this.rules[16] = this.rules[2]  && P
		this.rules[17].add(createobject("PhonoRule","5",""))  && Q
		this.rules[18].add(createobject("PhonoRule","9","")) && R
		this.rules[19] = this.rules[3]  && S
		this.rules[20] = this.rules[4]  && T
		this.rules[21] = this.rules[1]  && U
		this.rules[22] = this.rules[6]  && V
		this.rules[23] = this.rules[1]  && W
		this.rules[24] = this.rules[17]  && X
		this.rules[25] = this.rules[1]  && Y
		this.rules[26] = this.rules[17]  && Z		
	endfunc
enddefine

define class SearchType as Custom
	hidden prepList, preparer
	hidden priority, field, priority, share, offset, maxocc, avgocc, log, softmax, typeIndex
	prepList = .f.
	preparer = .f.
	field = ""
	share = 0
	priority = -1
	offset = 0
	maxocc = 1
	avgocc = 1
	log = .f.
	softmax = 0
	typeIndex = 1
	
	function init(str, preparer)
	local lexArray, cnt, i, val
		this.prepList = createobject("Collection")
		this.preparer = m.preparer
		dimension m.lexArray[1]
		m.str = strtran(m.str,"("," ")
		m.str = strtran(m.str,")"," ")
		m.str = strtran(m.str,"["," ")
		m.str = strtran(m.str,"]"," ")
		m.str = strtran(m.str,":"," ")
		m.cnt = alines(m.lexArray,m.str,5," ")
		this.field = proper(m.lexArray[1])
		m.i = 2
		do while m.i <= m.cnt and (isdigit(m.lexArray[m.i]) or inlist(left(m.lexArray[m.i],1),"-","+","#"))
			if right(m.lexArray[m.i],1) == "%"
				this.setShare(val(m.lexArray[m.i]))
			else
				if inlist(left(m.lexArray[m.i],1),"-","+")
					this.setOffset(val(m.lexArray[m.i]))
				else
					if left(m.lexArray[m.i],1) == "#"
						m.val = substr(m.lexArray[m.i],2)
						if isdigit(m.val) or left(m.val,1) == "."
							this.setSoftmax(val(m.val))
						else
							if empty(m.val)
								m.i = m.i+1
								if m.i > m.cnt
									exit
								endif
								if isdigit(m.lexArray[m.i]) or left(m.lexArray[m.i],1) == "."
									this.setSoftmax(val(m.lexArray[m.i]))
								else
									m.i = m.i-1
								endif
							endif
						endif
					else
						if this.priority < 0
							this.setPriority(val(m.lexArray[m.i]))
						else
							if this.offset == 0
								this.setOffset(val(m.lexArray[m.i]))
							endif
						endif
					endif
				endif
			endif
			m.i = m.i+1
		enddo 
		if this.priority < 0
			this.priority = 100
		endif
		if m.i > m.cnt
			return
		endif
		if m.lexArray[m.i] == "as"
			m.i = m.i+1
			if m.i > m.cnt
				return
			endif
		endif
		if m.lexArray[m.i] == "log" or m.lexArray[m.i] == "ln"
			this.log = .t.
			m.i = m.i+1
			if m.i > m.cnt
				return
			endif
		endif
		for m.i = m.i to m.cnt
			this.prepList.add(upper(strtran(m.lexArray[m.i],"!","")))
		endfor
		if vartype(this.preparer) == "O"
			this.activatePreparer()
		endif
	endfunc
	
	hidden function activatePreparer()
	local i, prepList, preparerType, preparerName
		m.prepList = createobject("Collection")
		for m.i = 1 to this.prepList.count
			m.preparerName = this.prepList.item(m.i)
			m.preparerType = this.preparer.getPreparerType(m.preparerName)
			if not vartype(m.preparerType) == "O"
				m.preparerType = createobject("PreparerType",m.preparerName)
			endif
			m.prepList.add(m.preparerType)
		endfor
		this.prepList = m.prepList
	endfunc
	
	function isValid(baseTable)
		if vartype(m.baseTable) == "C"
			m.baseTable = createobject("BaseTable",m.baseTable)
		endif
		if vartype(m.baseTable) == "O" and not m.baseTable.hasField(this.field)
			return .f.
		endif
		return not empty(this.field)
	endfunc
	
	function isPreparerReady()
		if not vartype(this.preparer) == "O"
			return .f.
		endif
		return .t.
	endfunc
	
	function getInvalidPreparer()
	local i, invalid, preparerType
		m.invalid = " "
		for m.i = 1 to this.prepList.count
			m.preparerType = this.prepList.item(m.i)
			if not m.preparerType.isValid()
				if not " "+m.preparerType.getType()+" " $ m.invalid
					m.invalid = m.invalid+m.preparerType.getType()+" "
				endif
			endif
		endfor
		return alltrim(m.invalid)
	endfunc
	
	function removeDestructivePreparer()
	local i, preparerType
		m.i = 1
		do while m.i <= this.prepList.count
			m.preparerType = this.prepList.item(m.i)
			if m.preparerType.isDestructive()
				this.prepList.remove(m.i)
			else
				m.i = m.i + 1
			endif
		enddo
	endfunc
	
	function isDestructive()
	local i, preparerType
		for m.i = 1 to this.prepList.count
			m.preparerType = this.prepList.item(m.i)
			if m.preparerType.isDestructive()
				return .t.
			endif
		endfor
		return .f.
	endfunc
	
	function prepare(str)
	local i, preparerType
		m.str = this.preparer.openPrepare(m.str)
		for m.i = 1 to this.prepList.count
			m.preparerType = this.prepList.item(m.i)
			m.str = m.preparerType.execute(m.str)
		endfor
		return this.preparer.closePrepare(m.str)
	endfunc
	
	function setPriority(priority)
		this.priority = int(max(m.priority,0))
	endfunc

	function getPriority()
		return this.priority
	endfunc

	function getField()
		return this.field
	endfunc
	
	function setShare(share)
		this.share = max(m.share,0)
	endfunc
	
	function getShare()
		return this.share
	endfunc

	function setMaxOcc(maxOcc)
		this.maxOcc = max(m.maxOcc,0)
	endfunc
	
	function getMaxOcc()
		return this.maxOcc
	endfunc

	function setAvgOcc(avgOcc)
		this.avgOcc = max(m.avgOcc,0)
	endfunc
	
	function getAvgOcc()
		return this.avgOcc
	endfunc

	function setOffset(offset)
		this.offset = m.offset
	endfunc

	function getOffset()
		return this.offset
	endfunc
	
	function setLog(log as Boolean)
		this.log = m.log
	endfunc
	
	function getLog()
		return this.log
	endfunc
	
	function setSoftmax(softmax as Double)
		this.softmax = min(m.softmax,30)
	endfunc
	
	function getSoftmax()
		return this.softmax
	endfunc
	
	function setTypeIndex(index)
		this.typeIndex = max(m.index,1)
	endfunc
	
	function getTypeIndex
		return this.typeIndex
	endfunc
	
	function getPreparer()
		return this.preparer
	endfunc
	
	function getPreparerCount()
		return this.prepList.count
	endfunc
	
	function getPreparerName(index)
	local preparerType
		m.preparerType = this.prepList.item(m.index)
		if vartype(m.preparerType) == "O"
			return m.preparerType.getType()
		endif
		return m.preparerType
	endfunc
	
	function getPreparerList()
	local i, preparerType, str
		m.str = ""
		for m.i = 1 to this.prepList.count
			m.str = m.str+" "+this.getPreparerName(m.i)
			m.preparerType = this.getPreparerType(m.i)
			if vartype(m.preparerType) == "O" and m.preparerType.isDestructive()
				m.str = m.str+"!"
			endif
		endfor
		return ltrim(m.str)
	endfunc
	
	function getPreparerType(index)
		return this.prepList.item(m.index)
	endfunc

	function toString(simple as Boolean)
	local str
		if m.simple
			m.str = this.field+" "+ltrim(str(this.priority,18))
			if this.offset != 0
				m.str = m.str+" "+ltrim(str(this.offset,18))
			endif
			if this.softmax > 0
				m.str = m.str+" #"+rtrim(rtrim(ltrim(str(this.softmax,18,9)),"0"),".")
			endif
			if this.log
				m.str = m.str+" log"
			endif
			return m.str
		endif
		m.str = this.field+" ["+ltrim(str(this.priority,18))
		if this.share > 0
			m.str = m.str+":"+ltrim(str(this.share,18,2))+"%"
		endif
		m.str = m.str+"]"
		if this.offset != 0
			m.str = m.str+"["+iif(this.offset>0,"+","")+ltrim(str(this.offset,18))+"]"
		endif
		if this.softmax > 0
			m.str = m.str+"[#"+rtrim(rtrim(ltrim(str(this.softmax,18,9)),"0"),".")+"]"
		endif
		if this.log
			m.str = m.str+"[log]"
		endif
		return rtrim(m.str+" "+this.getPreparerList())
	endfunc
enddefine

define class SearchTypes as Custom
	hidden searchFields, searchTypes
	
	function init(str, preparer)
	local lexArray, cnt, i, type, index, searchtypes
		this.searchFields = createobject("Collection")
		this.searchTypes = createobject("Collection")
		if not vartype(m.str) == "C" or empty(m.str)
			return
		endif
		dimension m.lexArray[1]
		m.cnt = alines(m.lexArray,m.str,5,",")
		for m.i = 1 to m.cnt
			m.type = createobject("SearchType",m.lexArray[m.i],m.preparer)
			m.index = this.searchFields.getKey(m.type.getField())
			if m.index = 0
				m.searchTypes = createobject("Collection")
				this.searchFields.add(m.searchTypes,m.type.getField())
			else
				m.searchTypes = this.searchFields.item(m.index)
			endif
			m.searchTypes.add(m.type)
			this.searchTypes.add(m.type)
			m.type.setTypeIndex(this.searchTypes.count)
		endfor
	endfunc
	
	function isValid(baseTable)
	local i, searchType
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			if not m.searchType.isValid(m.baseTable)
				return .f.
			endif
		endfor
		return this.searchTypes.count > 0
	endfunc
	
	function getPreparer()
	local searchType
		if this.searchTypes.count <= 0
			return .f.
		endif
		m.searchType = this.searchTypes.item(1)
		return m.searchType.getPreparer()
	endfunc
	
	function getInvalidPreparer()
	local i, searchType, invalid, inv, word, j, cnt
		m.invalid = " "
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			m.inv = m.searchType.getInvalidPreparer()
			m.cnt = getwordcount(m.inv)
			for m.j = 1 to m.cnt
				m.word = getwordnum(m.inv,m.j)
				if not " "+m.word+" " $ m.invalid
					m.invalid = m.invalid+m.word+" "
				endif
			endfor
		endfor
		return alltrim(m.invalid)
	endfunc
	
	function getSearchFieldCount()
		return this.searchFields.count
	endfunc
	
	function getSearchField(index)
		if vartype(m.index) == "C"
			m.index = proper(m.index)
		endif
		return this.searchFields.getKey(m.index)
	endfunc
	
	function getSearchTypeCount(searchField)
	local searchTypes
		if vartype(m.searchField) == "L"
			return this.searchTypes.count
		endif
		if vartype(m.searchField) == "C"
			m.searchField = proper(m.searchField)
		endif
		m.searchTypes = this.searchFields.item(m.searchField)
		return m.searchTypes.count
	endfunc

	function getSearchTypeByField(searchField, index)
	local searchTypes, searchType
		if vartype(m.searchField) == "C"
			m.searchField = proper(m.searchField)
		endif
		m.searchTypes = this.searchFields.item(m.searchField)
		m.searchType = m.searchTypes.item(m.index)
		return m.searchType
	endfunc
	
	function getSearchTypeByIndex(index)
		return this.searchTypes.item(m.index)
	endfunc

	function getSearchType(type, index)
		if vartype(m.type) == "N"
			return this.getSearchTypeByIndex(m.type)
		endif
		return this.getSearchTypeByField(m.type, m.index)
	endfunc

	function recalculateShares(prioritySum as Integer)
	local i, searchType, sum
		if not vartype(m.prioritySum) == "N"
			m.prioritySum = 0
		else
			m.prioritySum = int(m.prioritySum)
		endif
		m.sum = max(this.getPrioritySum(),m.prioritySum)
		if m.sum == 0
			m.sum = 1
		endif
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			m.searchType.setShare(m.searchType.getPriority()/m.sum*100)
		endfor
	endfunc
	
	function getPrioritySum()
	local sum, i, searchType
		m.sum = 0
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			m.sum = m.sum+m.searchType.getPriority()
		endfor
		return m.sum
	endfunc
	
	function getSearchFieldsAsTableStructure()
	local i, struc
		m.struc = ""
		for m.i = 1 to this.searchFields.count
			m.struc = m.struc+", "+this.searchFields.getKey(m.i)+" C(10)"
		endfor
		return createobject("TableStructure",substr(m.struc,3))
	endfunc
	
	function mergeSearchTypeData(searchTypes)
	local i, j, cnt, field, searchType1, searchType2, index
		if not vartype(m.searchTypes) == "O"
			m.searchTypes = createobject("SearchTypes",m.searchTypes)
		endif
		for m.i = 1 to m.searchTypes.getSearchFieldCount()
			m.field = m.searchTypes.getSearchField(m.i)
			m.index = this.getSearchField(m.field)
			if m.index > 0
				m.cnt = min(m.searchTypes.getSearchTypeCount(m.i),this.getSearchTypeCount(m.index))
				for m.j = 1 to m.cnt
					m.searchType1 = this.getSearchTypeByField(m.index, m.j)
					m.searchType2 = m.searchTypes.getSearchTypeByField(m.i, m.j)
					m.searchType1.setPriority(m.searchType2.getPriority())
					m.searchType1.setOffset(m.searchType2.getOffset())
					m.searchType1.setShare(m.searchType2.getShare())
					m.searchType1.setLog(m.searchType2.getLog())
					m.searchType1.setSoftmax(m.searchType2.getSoftmax())
				endfor
			endif
		endfor
	endfunc
	
	function filterByDestructive(destructive as Boolean, keep as Boolean)
	local i, con, searchType, old
		m.con = ""
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			if m.searchType.isDestructive() == m.destructive
				m.con = m.con+","+m.searchType.toString()
			else
				if m.keep
					m.old = m.searchType.getPriority()
					m.searchType.setPriority(0)
					m.con = m.con+","+m.searchType.toString()
					m.searchType.setPriority(m.old)
				endif
			endif
		endfor
		return createobject("SearchTypes",ltrim(m.con,","),this.getPreparer())
	endfunc
	
	function consolidateByFields(keep as Boolean)
	local i, j, k, priority, preparer, prep, con
	local searchTypes, searchType
		m.con = ""
		for m.i = 1 to this.searchFields.count
			m.searchTypes = this.searchFields.item(m.i)
			m.priority = 0
			m.preparer = " "
			for m.j = 1 to m.searchTypes.count
				m.searchType = m.searchTypes.item(m.j)
				if m.searchType.getPriority() > 0
					m.priority = m.priority+m.searchType.getPriority()
					for m.k = 1 to m.searchType.getPreparerCount()
						m.prep = m.searchType.getPreparerName(m.k)
						if not " "+m.prep+" " $ m.preparer
							m.preparer = m.preparer+m.prep+" "
						endif
					endfor
				endif
			endfor
			if m.priority > 0 or m.keep == .t.
				m.preparer = ltrim(m.preparer)
				m.con = m.con+","+this.getSearchField(m.i)+" ["+ltrim(str(m.priority,18))+rtrim("] "+m.preparer)
			endif
		endfor
		return createobject("SearchTypes",ltrim(m.con,","),this.getPreparer())
	endfunc
	
	function consolidate()
	local i, con, searchType
		m.con = ""
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			if m.searchType.getPriority() > 0
				m.con = m.con+","+m.searchType.toString()
			endif
		endfor
		return createobject("SearchTypes",ltrim(m.con,","),this.getPreparer())
	endfunc
	
	function filter(fields as Object)
	local i, filtered, searchType
		m.filtered = ""
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			if m.fields.getFieldIndex(m.searchType.getField()) > 0
				m.filtered = m.filtered+","+m.searchType.toString()
			endif
		endfor
		return createobject("SearchTypes",ltrim(m.filtered,","),this.getPreparer())
	endfunc
	
	function sumShare()
	local i, sum, searchType
		m.sum = 0
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			m.sum = m.sum + m.searchType.getShare()
		endfor
		return m.sum
	endfunc
	
	function removeDestructivePreparer()
	local i, searchType
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			m.searchType.removeDestructivePreparer()
		endfor
	endfunc

	function hasDestructivePreparer(searchField as String)
	local i, searchTypes, searchType
		if vartype(m.searchField) == "C"
			m.searchTypes = this.searchFields.item(m.searchField)
		else
			m.searchTypes = this.searchTypes
		endif
		for m.i = 1 to m.searchTypes.count
			m.searchType = m.searchTypes.item(m.i)
			if m.searchType.isDestructive()
				return .t.
			endif
		endfor
		return .f.
	endfunc

	function toString(simple as boolean)
	local i,  searchType, str
		m.str = ""
		for m.i = 1 to this.searchTypes.count
			m.searchType = this.searchTypes.item(m.i)
			m.str = m.str+", "+m.searchType.toString(m.simple)
		endfor
		return substr(m.str,3)
	endfunc
enddefine

define class Preparer as Custom
	hidden normizer, types, metaphone, soundex, cologne
	xmlerror = ""
	function init(xml)
		local tmp1, tmp2, tmp3, err, type, com, key, pa, i, j, default
		m.pa = createobject("PreservedAlias")
		this.types = createobject("Collection")
		this.normizer = createobject("StringNormizer")
		m.tmp1 = createobject("UniqueAlias",.t.)
		m.tmp2 = createobject("UniqueAlias",.t.)
		m.tmp3 = createobject("UniqueAlias",.t.)
		m.default = "<SearchEngine>"
		m.default = m.default+"<line><type>NOABBREV</type><com>cockle</com></line>"
		m.default = m.default+"<line><type>NOUMLAUT</type><com>replace</com><para1></para1><para2>UE</para2><para3>U</para3></line>"
		m.default = m.default+"<line><type>NOUMLAUT</type><com>replace</com><para1></para1><para2>AE</para2><para3>A</para3></line>"
		m.default = m.default+"<line><type>NOUMLAUT</type><com>replace</com><para1></para1><para2>OE</para2><para3>O</para3></line>"
		m.default = m.default+"<line><type>SEPNUM</type><com>cockle</com></line>"
		m.default = m.default+"<line><type>SEPNUM</type><com>separate</com><para1>0123456789</para1><para2>ABCDEFGHIJKLMNOPQRSTUVWXYZ</para2></line>"
		m.default = m.default+"<line><type>GRAM2</type><com>gram</com><para1>2</para1></line>"
		m.default = m.default+"<line><type>GRAM2</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>GRAM3</type><com>gram</com><para1>3</para1></line>"
		m.default = m.default+"<line><type>GRAM3</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>GRAM4</type><com>gram</com><para1>4</para1></line>"
		m.default = m.default+"<line><type>GRAM4</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>GRAM5</type><com>gram</com><para1>5</para1></line>"
		m.default = m.default+"<line><type>GRAM5</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>METAPHONE</type><com>encode</com><para1>METAPHONE</para1></line>"
		m.default = m.default+"<line><type>METAPHONE</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>SOUNDEX</type><com>encode</com><para1>SOUNDEX</para1></line>"
		m.default = m.default+"<line><type>SOUNDEX</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>COLOGNE</type><com>encode</com><para1>COLOGNE</para1></line>"
		m.default = m.default+"<line><type>COLOGNE</type><com>destructive</com></line>"
		m.default = m.default+"<line><type>MAXLENGTH1</type><com>limit</com><para1>LENGTH</para1><para2>1</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH2</type><com>limit</com><para1>LENGTH</para1><para2>2</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH3</type><com>limit</com><para1>LENGTH</para1><para2>3</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH4</type><com>limit</com><para1>LENGTH</para1><para2>4</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH5</type><com>limit</com><para1>LENGTH</para1><para2>5</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH6</type><com>limit</com><para1>LENGTH</para1><para2>6</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH7</type><com>limit</com><para1>LENGTH</para1><para2>7</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH8</type><com>limit</com><para1>LENGTH</para1><para2>8</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH9</type><com>limit</com><para1>LENGTH</para1><para2>9</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH10</type><com>limit</com><para1>LENGTH</para1><para2>10</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH11</type><com>limit</com><para1>LENGTH</para1><para2>11</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH12</type><com>limit</com><para1>LENGTH</para1><para2>12</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH13</type><com>limit</com><para1>LENGTH</para1><para2>13</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH14</type><com>limit</com><para1>LENGTH</para1><para2>14</para2></line>"
		m.default = m.default+"<line><type>MAXLENGTH15</type><com>limit</com><para1>LENGTH</para1><para2>15</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS1</type><com>limit</com><para1>COUNT</para1><para2>1</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS2</type><com>limit</com><para1>COUNT</para1><para2>2</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS3</type><com>limit</com><para1>COUNT</para1><para2>3</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS4</type><com>limit</com><para1>COUNT</para1><para2>4</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS5</type><com>limit</com><para1>COUNT</para1><para2>5</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS6</type><com>limit</com><para1>COUNT</para1><para2>6</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS7</type><com>limit</com><para1>COUNT</para1><para2>7</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS8</type><com>limit</com><para1>COUNT</para1><para2>8</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS9</type><com>limit</com><para1>COUNT</para1><para2>9</para2></line>"
		m.default = m.default+"<line><type>MAXWORDS10</type><com>limit</com><para1>COUNT</para1><para2>10</para2></line>"
		m.default = m.default+"<line><type>SKIPWORDS1</type><com>limit</com><para1>COUNT</para1><para2>1</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS2</type><com>limit</com><para1>COUNT</para1><para2>2</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS3</type><com>limit</com><para1>COUNT</para1><para2>3</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS4</type><com>limit</com><para1>COUNT</para1><para2>4</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS5</type><com>limit</com><para1>COUNT</para1><para2>5</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS6</type><com>limit</com><para1>COUNT</para1><para2>6</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS7</type><com>limit</com><para1>COUNT</para1><para2>7</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS8</type><com>limit</com><para1>COUNT</para1><para2>8</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS9</type><com>limit</com><para1>COUNT</para1><para2>9</para2><para3>SKIP</para3></line>"
		m.default = m.default+"<line><type>SKIPWORDS10</type><com>limit</com><para1>COUNT</para1><para2>10</para2><para3>SKIP</para3></line>"
		m.default = m.default+"</SearchEngine>"
		xmltocursor(m.default,m.tmp2.alias)
		if vartype(m.xml) == "C" and not empty(m.xml)
			m.xml = proper(alltrim(m.xml))
			m.err = .f.
			try
				xmltocursor(m.xml,m.tmp1.alias,512)
			catch to m.err
			endtry
			if vartype(m.err) == "O"
				this.xmlerror = m.xml+" is not a valid XML file."
				if not empty(m.err.message)
					this.xmlerror = this.xmlerror+chr(10)+m.err.message
				endif
				m.tmp1 = createobject("UniqueAlias",.t.)
			else
				m.err = .f.
				try
					update (m.tmp1.alias) set type = upper(alltrim(type))
				catch
					m.err = .t.
				endtry
				if m.err
					this.xmlerror = m.xml+" has invalid structure."
					m.tmp1 = createobject("UniqueAlias",.t.)
				else
					select distinct a.type from (m.tmp1.alias) a, (m.tmp2.alias) b where a.type == b.type into cursor (m.tmp3.alias)
					if _tally > 0
						select (m.tmp3.alias)
						this.xmlerror = ""
						scan
							this.xmlerror = this.xmlerror + alltrim(type) + " "
						endscan
						this.xmlerror = "Conflicts with default preparer names: "+rtrim(this.xmlerror)
						select * from (m.tmp1.alias) a where not exists (select * from (m.tmp2.alias) b where a.type == b.type) into cursor (m.tmp1.alias)
					endif
				endif
			endif
		endif
		for m.i = 1 to 2
			if m.i = 1
				select (m.tmp1.alias)
			else
				select (m.tmp2.alias)
			endif
			if reccount() == 0
				loop
			endif
			scan
				m.key = this.normizer.normize(type,"_")
				if " " $ m.key or isdigit(m.key)
					this.xmlerror = "Invalid preparer name: "+type
					return
				endif
				m.err = .f.
				try
					m.type = this.types.item(m.key)
				catch
					m.err = .t.
				endtry
				if m.err
					m.type = createobject("PreparerType", m.key)
					this.types.add(m.type,m.type.getType())
				endif
				m.err = .f.
				try
					m.com = createobject(alltrim(com), this)
				catch
					m.err = .t.
				endtry
				if m.err or not this.isComClass(m.com)
					this.xmlerror = "Invalid XML block: "+chr(10)+this.lineToXML()
					return
				endif
				m.type.addCom(m.com)
			endscan
		endfor
		for m.i = 1 to this.types.count
			m.type = this.types.item(m.i)
			m.type.activate(this)
		endfor
		for m.i = 1 to this.types.count
			m.key = this.types.getKey(m.i)
			m.type = this.types.item(m.i)
			for m.j = 1 to m.type.getComCount()
				m.com = m.type.getCom(m.j)
				if not m.com.isValid()
					this.xmlerror = "Invalid XML block: "+chr(10)+"<type>"+m.key+"</type>"+chr(10)+m.com.toString()
					return
				endif
			endfor
			m.type.removePassive()
		endfor
	endfunc

	function getKey(type)
		if vartype(m.type) == "C"
			m.type = upper(alltrim(m.type))
		endif
		return this.types.getKey(m.type)
	endfunc
	
	function normize(str, keep)
		return this.normizer.normize(m.str, m.keep)
	endfunc
	
	function getMetaphone()
		if vartype(this.metaphone) == "O"
			return this.metaphone
		endif
		this.metaphone = createobject("Metaphone",this.normizer)
		return this.metaphone
	endfunc

	function getSoundex()
		if vartype(this.soundex) == "O"
			return this.soundex
		endif
		this.soundex = createobject("ExtendedSoundex",this.normizer)
		return this.soundex
	endfunc

	function getCologne()
		if vartype(this.cologne) == "O"
			return this.cologne
		endif
		this.cologne = createobject("Cologne",this.normizer)
		return this.cologne
	endfunc

	function getCount()
		return this.types.count
	endfunc
	
	function getPreparerType(type)
		if vartype(m.type) == "C"
			m.type = this.types.getKey(upper(alltrim(m.type)))
		endif
		if m.type <= 0
			return .f.
		endif
		return this.types.item(m.type)
	endfunc
	
	function openPrepare(str)
		return this.normizer.normize(m.str)
	endfunc
	
	function closePrepare(str)
		return strtran(strtran(m.str,"[",""),"]","")
	endfunc

	hidden function lineToXML()
		local str, i, field
		m.str = ""
		for m.i = 1 to fcount()
			m.field = evaluate(field(m.i))
			if not vartype(m.field) == "C"
				m.field = createobject("String", m.field)
				m.field = m.field.toString()
			endif
			m.field = alltrim(m.field)
			if not empty(m.field)
				m.str = m.str+"<"+lower(field(m.i))+">"+m.field+"</"+lower(field(m.i))+">"+chr(10)
			endif
		endfor
		return left(m.str,len(m.str)-1)
	endfunc

	hidden function isComClass(com)
		local ancestors, i
		dimension m.ancestors[1]
		if aclass(ancestors, m.com) <= 0
			return .f.
		endif
		for m.i = 1 to alen(m.ancestors)
			if upper(m.ancestors[m.i]) == "COM"
				return .t.
			endif
		endfor
		return .f.
	endfunc
enddefine

define class PreparerType as Custom
	hidden coms, type, destructive
	
	function init(type)
		this.coms = createobject("Collection")
		this.type = alltrim(upper(m.type))
		this.destructive = .f.
	endfunc
	
	function getType()
		return this.type
	endfunc
	
	function addCom(com)
		this.coms.add(m.com)
	endfunc
	
	function getCom(index)
		return this.coms.item(m.index)
	endfunc
	
	function removeCom(index)
		this.coms.remove(m.index)
	endfunc
	
	function getComCount()
		return this.coms.count
	endfunc
	
	function execute(str)
	local i, com
		for m.i = 1 to this.coms.count
			m.com = this.coms.item(m.i)
			m.str = m.com.execute(m.str)
		endfor
		return m.str
	endfunc
	
	function activate(preparer)
	local i, com
		for m.i = 1 to this.coms.count
			m.com = this.coms.item(m.i)
			m.com.activate(m.preparer, this)
		endfor
	endfunc
	
	function removePassive()
	local i, com
		m.i = 1
		do while m.i <= this.coms.count
			m.com = this.coms.item(m.i)
			if m.com.isPassive()
				this.coms.remove(m.i)
			else
				m.i = m.i+1
			endif
		enddo
	endfunc
	
	function isDestructive()
		return this.destructive
	endfunc
	
	function setDestructive(destructive)
		this.destructive = m.destructive
	endfunc
	
	function isValid()
		return this.coms.count > 0
	endfunc
enddefine

define class Com as Custom
	protected paracnt
	paracnt = 0
	dimension parax[1]
	function init(preparer)
	local i
		if this.paracnt > 0
			dimension this.parax[this.paracnt]
		endif
		for m.i = 1 to this.paracnt
			this.parax[m.i] = evaluate("para"+ltrim(str(m.i)))
			if not vartype(this.para[m.i]) == "C"
				this.parax[m.i] = createobject("String",this.parax[m.i])
				this.parax[m.i] = this.parax[m.i].toString()
			endif
			this.parax[m.i] = m.preparer.normize(this.parax[m.i],"[]")
		endfor
	endfunc

	function execute(str)
		return m.str
	endfunc
	
	function isPassive()
		return .f.
	endfunc
	
	function activate(preparer, preparerType)
		return
	endfunc
	
	function isValid()
		return .t.
	endfunc
	
	function toString()
		local str, i
		m.str = "<com>"+upper(this.Class)+"</com>"+chr(10)
		for m.i = 1 to this.paracnt
			m.str = m.str+"<para"+ltrim(str(m.i,18))+">"+this.parax[m.i]+"</para"+ltrim(str(m.i,18))+">"+chr(10)
		endfor
		return left(m.str,len(m.str)-1)
	endfunc
enddefine

define class Call as Com
	protected preparerType
	paracnt = 1
	function init(preparer)
		Com::init(m.preparer)
		this.preparerType = this.parax[1]
	endfunc
	
	function execute(str)
		return this.preparerType.execute(m.str)
	endfunc
	
	function activate(preparer, preparerType)
		this.preparerType = m.preparer.getPreparerType(this.preparerType)
	endfunc
	
	function isValid()
		return vartype(this.preparerType) == "O"
	endfunc
enddefine

define class Replace as Com
	paracnt = 3
	function init(preparer)
		Com::init(m.preparer)
		if this.parax[1] = "LEFT"
			this.parax[2] = " "+this.parax[2]
			this.parax[3] = " "+this.parax[3]
			return
		endif
		if this.parax[1] = "RIGHT"
			this.parax[2] = this.parax[2]+" "
			this.parax[3] = this.parax[3]+" "
			return
		endif
		if this.parax[1] = "WORD"
			this.parax[2] = " "+this.parax[2]+" "
			this.parax[3] = " "+this.parax[3]+" "
		endif
	endfunc
	
	function isValid()
		return inlist(this.parax[1],"LEFT","RIGHT","WORD","")
	endfunc

	function execute(str)
		return alltrim(strtran(" "+m.str+" ",this.parax[2],this.parax[3]))
	endfunc
enddefine

define class Change as Com
	paracnt = 3
	function init(preparer)
		Com::init(m.preparer)
		if this.parax[1] = "LEFT"
			this.parax[2] = " "+this.parax[2]
			this.parax[3] = " ["+this.parax[3]+"]"
			return
		endif
		if this.parax[1] = "RIGHT"
			this.parax[2] = this.parax[2]+" "
			this.parax[3] = "["+this.parax[3]+"] "
			return
		endif
		if this.parax[1] = "WORD"
			this.parax[2] = " "+this.parax[2]+" "
			this.parax[3] = " ["+this.parax[3]+"] "
			return
		endif
		this.parax[3] = "["+this.parax[3]+"]"
	endfunc

	function isValid()
		return inlist(this.parax[1],"LEFT","RIGHT","WORD","")
	endfunc

	function execute(str)
		return alltrim(strtran(" "+m.str+" ",this.parax[2],this.parax[3]))
	endfunc
enddefine

define class Reset as Com
	function execute(str)
		return strtran(strtran(m.str,"[",""),"]","")
	endfunc
enddefine

define class Cockle as Com
	function execute(str)
		local cockle
		m.cockle = createobject("String",m.str)
		return m.cockle.getCockle()
	endfunc
enddefine

define class Split as Com
	paracnt = 2
	function init(preparer)
		Com::init(m.preparer)
		if this.parax[1] = "LEFT"
			this.parax[2] = " "+this.parax[2]
			return
		endif
		if this.parax[1] = "RIGHT"
			this.parax[2] = this.parax[2]+" "
			return
		endif
	endfunc
	
	function isValid()
		return inlist(this.parax[1],"LEFT","RIGHT","")
	endfunc

	function execute(str)
		m.str = alltrim(strtran(" "+m.str+" ",this.parax[2]," "+alltrim(this.parax[2])+" "))
		do while "  " $ m.str
			m.str = strtran(m.str,"  "," ")
		enddo
		return m.str
	endfunc
enddefine

define class Cut as Com
	hidden paralen, mode
	paracnt = 2
	function init(preparer)
		Com::init(m.preparer)
		this.mode = 0
		if this.parax[1] = "LEFT"
			this.parax[2] = " "+this.parax[2]
			this.mode = 1
		else
			if this.parax[1] = "RIGHT"
				this.parax[2] = this.parax[2]+" "
				this.mode = 2
			else
				if this.parax[1] = ""
					this.mode = 3
				endif
			endif
		endif
		this.paralen = len(this.parax[2])
	endfunc

	function isValid()
		return this.mode > 0
	endfunc

	function execute(str)
		local left, right, n, pos
		m.str = " "+m.str+" "
		m.n = 1
		m.pos = at(this.parax[2],m.str)
		do while m.pos > 0
			do case
				 case this.mode == 1
					m.left = substr(m.str,1,m.pos+this.paralen-1)
					m.right = substr(m.str,m.pos+this.paralen)
					m.str = m.left+substr(m.right,at(" ",m.right))
				case this.mode == 2
					m.right = substr(m.str,m.pos)
					m.left = substr(m.str,1,m.pos-1)
					m.str = substr(m.left,1,rat(" ",m.left))+m.right
				otherwise
					m.left = substr(m.str,1,m.pos-1)
					m.right = substr(m.str,m.pos+this.paralen)
					m.str = substr(m.left,1,rat(" ",m.left))+this.parax[2]+substr(m.right,at(" ",m.right))
			endcase
			m.n = m.n+1
			m.pos = at(this.parax[2],m.str,m.n)
		enddo
		return alltrim(m.str)
	endfunc
enddefine
	
define class Separate as Com
	paracnt = 2
	function init(preparer)
		Com::init(m.preparer)
		this.parax[1]  = strtran(this.parax[1]," ","")
		this.parax[2]  = strtran(this.parax[2]," ","")
	endfunc
	
	function execute(str)
		local sep, chr, len, i, oldtype, type
		m.len = len(m.str)
		m.oldtype = 0
		m.sep = ""
		for m.i = 1 to m.len
			m.chr = substr(m.str,m.i,1)
			m.type = iif(m.chr $ this.parax[1],1,iif(m.chr $ this.parax[2],2,0))
			if m.type == 0 or m.oldtype == 0 or m.type == m.oldtype
				m.sep = m.sep+m.chr
			else
				m.sep = m.sep+" "+m.chr
			endif
			m.oldtype = m.type
		endfor
		return m.sep
	endfunc
enddefine

define class Blank as Com
	paracnt = 1
	function init(preparer)
		Com::init(m.preparer)
		this.parax[1]  = strtran(this.parax[1]," ","")
	endfunc
	
	function execute(str)
		local len, i
		m.len = len(this.parax[1])
		for m.i = 1 to m.len
			m.str = strtran(m.str,substr(this.parax[1],m.i,1)," ")
		endfor
		do while "  " $ m.str
			m.str = strtran(m.str,"  "," ")
		enddo
		return alltrim(m.str)
	endfunc
enddefine

define class Gram as Com
	paracnt = 1
	function init(preparer)
		Com::init(m.preparer)
		this.parax[1]  = int(val(this.parax[1]))
	endfunc
	
	function isValid()
		if this.parax[1] <= 1
			return .f.
		endif
	endfunc
	
	function execute(str)
	local len, gram, subgram, pos, new, blank
		m.str = m.str+" "
		m.len = len(m.str)
		m.gram = ""
		m.new = .t.
		m.pos = 1
		do while m.pos <= m.len
			m.subgram = substr(m.str,m.pos,this.parax[1])
			m.blank = at(" ",m.subgram)
			if m.blank <= 0
				m.gram = m.gram+" "+m.subgram
				m.new = .f.
				m.pos = m.pos+1
			else
				m.pos = m.pos + m.blank
				if m.new
					m.gram = m.gram+" "+left(m.subgram,m.blank-1)
				endif
				m.new = .t.
			endif
		enddo
		return ltrim(m.gram)
	endfunc
enddefine

define class Encode as Com
	hidden phono
	paracnt = 1
	function init(preparer)
		Com::init(m.preparer)
		if this.parax[1] == "METAPHONE"
			this.phono = m.preparer.getMetaphone()
		else
			if this.parax[1] == "SOUNDEX"
				this.phono = m.preparer.getSoundex()
			else
				if this.parax[1] == "COLOGNE"
					this.phono = m.preparer.getCologne()
				endif
			endif
		endif
	endfunc

	function isValid()
		return vartype(this.phono) == "O"
	endfunc

	function execute(str)
		local lex, cnt, i
		dimension m.lex[1]
		m.cnt = alines(m.lex, m.str, 1, " ")
		m.str = ""
		for m.i = 1 to m.cnt
			m.str = m.str+" "+this.phono.directEncode(m.lex[m.i])
		endfor
		return m.str
	endfunc
enddefine

define class Limit as Com
	hidden mode, skip
	paracnt = 3
	function init(preparer)
		Com::init(m.preparer)
		this.mode = 0
		if this.parax[1] = "LENGTH"
			this.mode = 1
		else
			if this.parax[1] = "COUNT"
				this.mode = 2
			endif
		endif
		this.parax[2] = int(val(this.parax[2]))
		this.skip = .f.
		if this.parax[3] = "SKIP"
			this.skip = .t.
			this.parax[2] = this.parax[2]+1
		endif
	endfunc
	
	function isValid()
		return this.mode > 0 and this.parax[2] > 0
	endfunc

	function execute(str)
		local limit, cnt, lex, i 
		m.limit = this.parax[2]
		dimension m.lex[1]
		m.cnt = alines(m.lex, m.str, 1, " ")
		if this.skip
			if this.mode = 1
				m.str = ""
				for m.i = 1 to m.cnt
					if len(m.lex[m.i]) >= m.limit
						m.str = m.str+" "+substr(m.lex[m.i],m.limit)
					endif
				endfor
			else
				if m.cnt < m.limit
					return ""
				endif
				m.str = ""
				for m.i = m.limit to m.cnt
					m.str = m.str+" "+m.lex[m.i]
				endfor
			endif			
		else
			if this.mode = 1
				m.str = ""
				for m.i = 1 to m.cnt
					m.str = m.str+" "+left(m.lex[m.i],m.limit)
				endfor
			else
				if m.cnt <= m.limit
					return m.str
				endif
				m.str = ""
				for m.i = 1 to m.limit
					m.str = m.str+" "+m.lex[m.i]
				endfor
			endif
		endif
		return m.str
	endfunc
enddefine

define class Destructive as Com
	function activate(preparer, preparerType)
		m.preparerType.setDestructive(.t.)
	endfunc
	
	function isPassive()
		return .t.
	endfunc
enddefine

define class CollectorCursor as BaseCursor
	protected function init(path)
		BaseCursor::init("base i, reg i",m.path)
		this.setRequiredTableStructure("base i, reg i")
	endfunc
enddefine

define class VectorTable as BaseTable
	handle = -1
	
	function switchToFile()
		if this.close()
			this.handle = fopen(this.getDBF(),0)
		endif
		return this.handle > 0	
	endfunc
	
	function switchToTable()
		if fclose(this.handle)
			this.handle = -1
			return this.open()
		endif
		return .f.
	endfunc
	
	function isValid()
		return this.handle > 0 or BaseTable::isValid()
	endfunc
	
	function erase()
		if this.handle > 0
			if not this.switchToTable()
				return .f.
			endif
		endif
		return BaseTable::erase()
	endfunc
	
	function close()
		if this.handle <= 0
			BaseTable::close()
			return
		endif
		fclose(this.handle)
	endfunc
enddefine

define class IndexTable as VectorTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("index i")
	endfunc
enddefine

define class TargetTable as VectorTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("target i")
	endfunc
enddefine

define class IndexCluster as Custom
	hidden targetStub, indexStub, messenger
	target = .f.
	index = .f.
	targetStub = .f.
	indexStub = .f.
	dimension continuum[1]
	
	function init(indexStub as String, targetStub as String)
		this.target = createobject("Collection")
		this.index = createobject("Collection")
		this.indexStub = m.indexStub
		this.targetStub = m.targetStub
		this.openCluster(this.target, this.targetStub, "TargetTable")
		this.openCluster(this.index, this.indexStub, "IndexTable")
		this.createContinuum()
		this.messenger = createobject("Messenger")
		this.messenger.setInterval(2)
	endfunc
	
	function setMessenger(messenger as Object)
		this.messenger = m.messenger
	endfunc
	
	function getMessenger()
		return this.messenger
	endfunc
	
	function switchTargetToFile()
	local i, table
		for m.i = 1 to this.target.count
			m.table = this.target.item(m.i)
			if not m.table.switchToFile()
				return .f.
			endif
		endfor
		return .t.
	endfunc
		
	function switchTargetToTable()
	local i, table
		for m.i = 1 to this.target.count
			m.table = this.target.item(m.i)
			if not m.table.switchToTable()
				return .f.
			endif
		endfor
		return .t.
	endfunc
	
	function isTargetFile()
	local i, table
		for m.i = 1 to this.target.count
			m.table = this.target.item(m.i)
			if m.table.handle <= 0
				return .f.
			endif
		endfor
		return .t.
	endfunc		
	
	function erase()
	local table, i
		for m.i = 1 to this.target.count
			m.table = this.target.item(m.i)
			m.table.erase()
		endfor
		for m.i = 1 to this.index.count
			m.table = this.index.item(m.i)
			m.table.erase()
		endfor
		this.target.remove(-1)
		this.index.remove(-1)
		this.eraseStub(this.targetStub)
		this.eraseStub(this.indexStub)
		return .t.
	endfunc

	function close()
	local table, i
		for m.i = 1 to this.target.count
			m.table = this.target.item(m.i)
			m.table.close()
		endfor
		for m.i = 1 to this.index.count
			m.table = this.index.item(m.i)
			m.table.close()
		endfor
		this.target.remove(-1)
		this.index.remove(-1)
		return .t.
	endfunc

	function isValid()
	local table, i
		if this.target.count == 0 or not this.index.count == this.target.count
			return .f.
		endif
		for m.i = 1 to this.target.count
			m.table = this.target.item(m.i)
			if not m.table.isValid()
				return .f.
			endif
		endfor
		for m.i = 1 to this.index.count
			m.table = this.index.item(m.i)
			if not m.table.isValid()
				return .f.
			endif
		endfor
		return .t.
	endfunc
	
	function isCreatable()
	local table
		if this.target.count > 0 or this.index.count > 0
			return .f.
		endif
		m.table = createobject("TargetTable",this.targetStub)
		if not m.table.isCreatable()
			return .f.
		endif
		m.table = createobject("IndexTable",this.indexStub)
		if not m.table.isCreatable()
			return .f.
		endif
		return .t.
	endfunc				

	function create(collector as Collection, indexField as String, targetField as String, continuous as Boolean)
		local ps1, ps2, ps3, pa, lm, pk
		local sort, err, sql, table, struc, i
		local name, f, ok, target, index
		local oldIndex, actIndex, actTarget, targetCount
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		m.name = createobject("BaseTable",this.indexStub)
		m.name = proper(m.name.getPureName())
		this.messenger.forceMessage("Creating "+m.name+"...")
		if not this.isCreatable()
			if not this.target.isCreatable()
				this.messenger.errormessage("IndexCluster is not creatable.")
				return .f.
			endif
		endif
		this.erase()
		m.sort = createobject("UniqueAlias",.t.)
		m.ok = .t.
		m.oldIndex = 0
		for m.i = 1 to m.collector.Count
			m.table = m.collector.item(m.i)
			m.struc = m.table.getTableStructure()
			m.f = m.table.getFieldStructure(m.indexField)
			if not m.f.getType() == "I"
				this.messenger.errormessage("Invalid index field. Integer required.")
				return .f.
			endif
			m.f = m.table.getFieldStructure(m.targetField)
			if not m.f.getType() == "I"
				this.messenger.errormessage("Invalid target field. Integer required.")
				return .f.
			endif
			m.pk = createobject("PreservedKey",m.table)
			m.sql = "select * from "+m.table.alias+" order by "+m.indexField+", "+m.targetField+" into cursor "+m.sort.alias
			m.err = .f.
			try
				&sql
			catch
				m.err = .t.
			endtry
			if m.err
				this.messenger.errormessage("Unable to create SortCursor")
				return .f.
			endif
			if m.collector.Count == 1
				m.target = createobject("TargetTable",this.targetStub)
			else
				m.target = createobject("TargetTable",this.targetStub+ltrim(str(m.i,18)))
			endif
			m.target.erase()
			if not m.target.create()
				this.messenger.errormessage("Unable to create TargetTable.")
				this.erase()
				return .f.
			endif
			this.target.add(m.target)
			if m.collector.Count == 1
				m.index = createobject("IndexTable",this.indexStub)
			else
				m.index = createobject("IndexTable",this.indexStub+ltrim(str(m.i,18)))
			endif
			m.index.erase()
			if not m.index.create()
				this.messenger.errormessage("Unable to create IndexTable.")
				this.erase()
				return .f.
			endif
			this.index.add(m.index)
			if not m.continuous
				m.oldIndex = 0
			endif
			m.targetCount = 0
			select (m.sort.alias)
			this.messenger.setDefault("Created")
			this.messenger.startProgress(reccount())
			this.messenger.startCancel("Cancel Operation?","Creating","Canceled.")
			scan
				if this.messenger.queryCancel()
					this.erase()
					return .f.
				endif
				m.actTarget = evaluate(m.targetField)
				m.actIndex = evaluate(m.indexField)
				insert into (m.target.alias) values (m.actTarget)
				m.targetCount =	m.targetCount+1
				do while m.actindex > m.oldindex
					insert into (m.index.alias) values (m.targetCount)
					m.oldIndex = m.oldindex+1
				enddo
				this.messenger.setProgress(m.targetCount)
				this.messenger.postProgress()
			endscan
			insert into (m.index.alias) values (m.targetCount+1)
		endfor
		this.messenger.forceMessage("Closing...")
		for m.i = 1 to this.target.count
			m.table = this.target.item(1)
			m.table.useShared()
		endfor
		for m.i = 1 to this.index.count
			m.table = this.index.item(1)
			m.table.useShared()
		endfor
		m.target = createobject("TargetTable",this.targetStub+ltrim(str(this.target.count+1,18)))
		m.index = createobject("IndexTable",this.indexStub+ltrim(str(this.index.count+1,18)))
		m.target.erase()
		m.index.erase()
		this.createContinuum()
		return .t.
	endfunc

	hidden function openCluster(collection as Collection, stub as String, class as String)
	local table, i 
		m.table = createobject(m.class,m.stub)
		if m.table.isValid()
			m.collection.add(m.table)
			return
		endif
		m.i = 1
		m.table = createobject(m.class,m.stub+"1")
		do while m.table.isValid()
			m.collection.add(m.table)
			m.i = m.i+1
			m.table = createobject(m.class,m.stub+ltrim(str(m.i,18)))
		enddo
	endfunc
	
	hidden function createContinuum()
	local i, index
		if this.index.count < 1
			dimension this.continuum[1]
			this.continuum[1] = 0
			return
		endif
		dimension this.continuum[this.index.count]
		m.index = this.index.item(1)
		this.continuum[1] = reccount(m.index.alias)-1
		for m.i = 2 to this.index.count
			m.index = this.index.item(m.i)
			this.continuum[m.i] = this.continuum[m.i-1]+reccount(m.index.alias)-1
		endfor
	endfunc
		
	hidden function eraseStub(stub as String)
	local dir, dircnt, i, table, pure, path, file
		m.table = createobject("BaseTable",m.stub)
		m.pure = m.table.getPureName()
		m.path = m.table.getPath()
		dimension m.dir[1]
		m.dircnt = adir(m.dir,m.stub+"*"+".dbf")
		for m.i = 1 to m.dircnt
			m.file = m.dir[m.i,1]
			m.file = substr(m.file,len(m.pure)+1)
			m.file = substr(m.file,1,len(m.file)-4)
			if m.file == "" or ltrim(str(val(m.file),18)) == m.file
				m.file = m.path+m.dir[m.i,1]
				erase (m.file)
			endif
		endfor
	endfunc
enddefine

define class ControlTable as BaseTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("maxocc i, avgocc b")
		this.resizeRequirements()
	endfunc

	function create(registry as Object, searchTypes as Object)
		local ps1, i
		m.ps1 = createobject("PreservedSetting","decimals","6")
		if not this.isCreatable()
			return .f.
		endif
		if not BaseTable::create()
			return .f.
		endif
		for m.i = 1 to m.searchTypes.getSearchTypeCount()
			insert into (this.alias) values (1, 1)
		endfor
		if not this.refresh(m.registry)
			return .f.
		endif
		if not this.refreshOccurrences(m.searchTypes)
			return .f.
		endif
		this.useShared()
		return .t.
	endfunc

	function refresh(registry as Object)
		local pa, ps1, err, ctrl, i
		m.ps1 = createobject("PreservedSetting","decimals","6")
		m.pa = createobject("PreservedAlias")
		if not this.isValid()
			return .f.
		endif
		dimension m.ctrl[1,3]
		m.ctrl[1,1] = ""
		m.err = .f.
		try
			select type, cast(max(occurs) as b) as maxocc, cast(avg(occurs) as b) as avgocc from (m.registry.alias) where occurs > 1 group by type into array ctrl
		catch
			m.err = .t.
		endtry
		if m.err 
			return .f.
		endif
		select (this.alias)
		replace maxocc with 1, avgocc with 1 for .t.
		if empty(m.ctrl[1,1])
			return .t.
		endif
		for m.i = 1 to alen(m.ctrl,1)
			goto m.ctrl[m.i,1]
			replace maxocc with m.ctrl[m.i,2], avgocc with m.ctrl[m.i,3]
		endfor
		return .t.
	endfunc

	function refreshOccurrences(searchTypes as Object)
	local pa, cnt, searchtype
		m.pa = createobject("PreservedAlias")
		if not this.isValid()
			return .f.
		endif
		select (this.alias)
		m.cnt = m.searchTypes.getSearchTypeCount()
		select (this.alias)
		scan
			if recno() > m.cnt
				return .f.
			endif
			m.searchType = m.searchTypes.getSearchTypeByIndex(recno())
			m.searchType.setMaxOcc(maxocc)
			m.searchType.setAvgOcc(avgocc)
		endscan
		return .t.
	endfunc
enddefine

define class RegistryTable as BaseTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("type i, entry c(30), occurs i")
		this.setRequiredKeys('ltrim(str(type))+" "+entry candidate')
		this.resizeRequirements()
	endfunc

	function forceRegistryKey()
		this.forceKey('ltrim(str(type))+" "+entry',"candidate")
	endfunc

	function buildRegistryKey(type, entry)
		return ltrim(str(m.type))+" "+left(m.entry,30)
	endfunc
enddefine

define class EngineTable as BaseTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("slot c(40), modified t, engine m")
	endfunc

	function recreate()
		if not this.hasValidAlias()
			return .f.
		endif
		if this.hasValidStructure()
			return .t.
		endif
		if this.modifyStructure(this.getRequiredTableStructure())
			if this.reccount() >= 1
				this.goTop()
				if empty(this.getValue("slot"))
					this.setValue("slot","Default")
				endif
				if empty(this.getValue("modified"))
					this.setValue("modified",datetime())
				endif
			endif
			return .t.
		endif
		return .f.
	endfunc

	function getActualSlot()
		local max
		local array slot[1]
		if not this.isValid() or this.reccount() < 1
			return "Default"
		endif
		select max(modified) from (this.alias) into array slot
		m.max = m.slot[1]
		m.slot[1] = "Default"
		select slot from (this.alias) where modified == m.max into array slot
		return m.slot[1]
	endfunc

	function load(slot)
		local array engine[1]
		if not this.isValid() or this.reccount() < 1
			return ""
		endif
		if not vartype(m.slot) == "C"
			m.slot = this.getActualSlot()
		else
			m.slot = alltrim(m.slot)
		endif
		m.engine[1] = ""
		m.slot = alltrim(m.slot)
		select engine from (this.alias) where slot == m.slot into array engine
		return m.engine[1]
	endfunc

	function remove(slot)
		if not this.isValid() or not vartype(m.slot) == "C"
			return .f.
		endif
		delete from (this.alias) where slot == m.slot
		if _tally > 0
			this.pack()
			return .t.
		endif
		return .f.
	endfunc

	function save(str,slot,system)
		local err
		if not this.isValid()
			return .f.
		endif
		if not vartype(m.slot) == "C"
			m.slot = "Default"
		else
			m.slot = alltrim(m.slot)
		endif
		m.err = .f.
		try
			if m.system
				update (this.alias) set engine = m.str where slot == m.slot
			else
				update (this.alias) set engine = m.str, modified = datetime() where slot == m.slot
			endif
		catch
			m.err = .t.
		endtry
		if m.err
			return .f.
		endif
		if _tally > 0
			return .t.
		endif
		m.err = .f.
		try
			if m.system
				insert into (this.alias) (slot, engine) values (m.slot, m.str)
			else
				insert into (this.alias) (slot, modified, engine) values (m.slot, datetime(), m.str)
			endif
		catch
			m.err = .t.
		endtry
		return not m.err
	endfunc
enddefine

define class ResultTable as BaseTable
	searchKey = ""
	foundKey = ""
	engine = .f.
	
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("searched i, found i, identity b, equal n(1), score b, run c(1)")
		this.setRequiredKeys("searched; found")
		this.resizeRequirements()
	endfunc

	function create(engine as SearchEngine, shuffle as Double, low as Double, high as Double, runFilter as String, newrun as boolean)
		if pcount() == 0
			if BaseTable::create()
				insert into (this.alias) (searched, found, identity, score, run) values (0, 0, -1, -1, chr(0))
				return .t.
			endif
			return .f.
		endif
		local ps1, ps2, pa, lm, pk
		local result, search, searched
		local array content[1]
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Exporting...")
		if not vartype(m.engine) == "O"
			this.messenger.errorMessage("Engine object is invalid.")
			return .f.
		endif
		if m.engine.idontcare()
			this.erase()
		endif
		if not this.iscreatable()
			this.messenger.errorMessage("Unable to shuffle ResultTable.")
			return .f.
		endif
		m.result = m.engine.getResultTable()
		if not m.result.isValid()
			this.messenger.errorMessage("Invalid source ResultTable.")
			return .f.
		endif
		if not vartype(m.shuffle) == "N"
			m.shuffle = -1
		endif
		if not inlist(vartype(m.low),"N","L")
			this.messenger.errormessage("Invalid low range.")
			return .f.
		endif
		if not inlist(vartype(m.high),"N","L") 
			this.messenger.errormessage("Invalid high range.")
			return .f.
		endif
		m.low = iif(vartype(m.low) == "N", max(m.low,0), 0)
		m.high = iif(vartype(m.high) == "N", max(m.high,0), 999)
		if m.high <= m.low
			m.high = m.low+1
		endif
		if not inlist(vartype(m.runFilter),"O","C","L")
			this.messenger.errormessage("Invalid runFilter setting.")
			return .f.
		endif
		if not vartype(m.runFilter) == "O"
			m.runFilter = createobject("RunFilter",m.runFilter)
		endif
		if not m.runFilter.isValid()
			this.messenger.errormessage("Run filter expression is invalid.")
			return .f.
		endif
		if not vartype(m.newrun) == "L"
			this.messenger.errormessage("Invalid setting.")
			return .f.
		endif
		if not this.create()
			this.errorMessage("Unable to create ResultTable.")
			return .f.
		endif
		m.result.select()
		go top
		scatter to m.content
		this.select()
		gather from m.content
		m.pk = createobject("PreservedKey",m.result)
		if not m.result.forceKey("searched")
			this.messenger.errorMessage("Unable to index source ResultTable.")
			return .f.
		endif
		m.search = createobject("UniqueAlias",.t.)
		select distinct searched from (m.result.alias) where searched > 0 into cursor (m.search.alias) readwrite
		if m.shuffle > 0
			select searched, cast(rand() as b) as rnd from (m.search.alias) order by 2 into cursor (m.search.alias) readwrite
			if m.shuffle < 1
				m.shuffle = int(reccount(m.search.alias) * m.shuffle + 0.5)
			endif
		else
			m.shuffle = reccount()
		endif
		select (m.search.alias)
		go top
		this.messenger.setDefault("Exported")
		this.messenger.startProgress(m.shuffle)
		this.messenger.startCancel("Cancel Operation?","Exporting ResultTable","Canceled.")
		scan
			if this.messenger.getProgress() >= m.shuffle
				exit
			endif
			if this.messenger.queryCancel()
				exit
			endif
			m.searched = searched
			select * from (m.result.alias) where searched == m.searched and identity >= m.low and identity < m.high and m.runFilter.isFiltered(asc(run)) into array content
			if _tally > 0
				select (this.alias)
				append from array m.content
				this.messenger.incProgress()
				this.messenger.postProgress()
			endif
		endscan
		this.messenger.sneakMessage("Closing...")
		this.forceRequiredKeys()
		if this.messenger.isCanceled()
			return .f.
		endif
		if m.newrun
			this.compressRun()
		endif
		return .t.
	endfunc
	
	function isValid()
		return this.hasValidStructure() and this.hasValidAlias()
	endfunc
	
	function isFunctional()
		if not this.isValid()
			return .f.
		endif
		return this.reccount() > 1
	endfunc

	function setRun(run as Integer)
	local pos, pk
		if not this.isValid()
			return .f.
		endif
		if m.run < 0 or m.run > 255
			return .f.
		endif
		if this.reccount() == 0
			return .f.
		endif
		m.pk = createobject("PreservedKey",this)		
		m.pos = this.getPosition()
		this.setKey()
		this.goTop()
		if this.getValue("searched") > 0
			this.setPosition(m.pos)
			return .f.
		endif
		replace run with chr(m.run) in (this.alias)
		this.setPosition(m.pos)
		return .t.
	endfunc
		
	function getRun()
	local pos, run, pk
		if not this.isValid()
			if this.isCreatable()
				return 0
			else
				return -1
			endif
		endif
		if this.reccount() == 0
			return -1
		endif
		m.pk = createobject("PreservedKey",this)
		m.pos = this.getPosition()
		this.setKey()
		this.goTop()
		if this.getValue("searched") <= 0
			m.run = asc(this.getValue("run"))
		else
			m.run = -1
		endif
		this.setPosition(m.pos)
		return m.run
	endfunc
	
	function mimicExportTable(m.searchkey, m.foundkey, m.engine)
		this.searchKey = m.searchKey
		this.foundKey = m.foundKey
		this.engine = m.engine
	endfunc
	
	function getSearchKey()
		return this.searchKey
	endfunc

	function getFoundKey()
		return this.foundKey
	endfunc
	
	function getEngine()
		return this.engine
	endfunc

	function analyse(type, ignore, from, to, step)
		return this.analyseResult(.f., m.type, m.ignore, m.from, m.to, m.step)
	endfunc
	
	function compressRun()
	local ps1, run, sql
		if not this.isValid()
			return .f.
		endif
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.run = createobject("UniqueAlias",.t.)
		select distinct run, cast(" " as c(1)) as newrun from (this.alias) into cursor (m.run.alias) readwrite
		update (m.run.alias) set newrun = chr(recno())
		index on run tag run
		m.sql = "update "+this.alias+" set run = "+m.run.alias+".newrun from "+m.run.alias+" where "+this.alias+".run == "+m.run.alias+".run"
		&sql
		return .t.
	endfunc
	
	function check(type, ignore, perc)
		local ps1, ps2, ps3, pa, lm, pk
		local pos, rec, complete, key
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Checking...")
		if not this.isValid()
			this.messenger.errormessage("ResultTable is not valid.")
			return .f.
		endif
		if m.type > 3 or m.type < 1
			this.messenger.errormessage("Illegal check type.")
			return .f.
		endif
		if m.perc > 100 or m.perc < 0
			this.messenger.errormessage("Illegal percentage.")
			return .f.
		endif
		m.pk = createobject("PreservedKey",this)
		this.setKey()
		m.rec = 0
		this.select()
		this.goTop()
		if searched <= 0
			skip
		endif
		this.messenger.setDefault("Checked")
		this.messenger.startProgress(reccount()-recno()+1)
		this.messenger.startCancel("Cancel Operation?","Checking","Canceled.")
		do while not eof()
			if this.messenger.queryCancel()
				return .f.
			endif
			m.pos = recno()
			m.key = searched
			m.complete = .t.
			do while not eof() and searched == m.key
				if equal <= 0
					m.complete = .f.
				endif
				this.messenger.incProgress()
				skip
			enddo
			if m.ignore or m.complete == .f.
				goto m.pos
				do case
					case m.type == 1
						do while not eof() and searched == m.key
							if identity >= m.perc
								replace equal with 2
							else
								replace equal with 8
							endif
							skip
						enddo
					case m.type == 2
						do while not eof() and searched == m.key
							if identity >= m.perc
								replace equal with 2
							endif
							skip
						enddo
					otherwise
						do while not eof() and searched == m.key
							if identity < m.perc
								replace equal with 8
							endif
							skip
						enddo
				endcase
			endif
			this.messenger.postProgress()
		enddo
		return .t.
	endfunc
	
	function toString()
		local str
		m.str = BaseTable::toString()
		m.str = m.str+"Run: "+ltrim(str(this.getRun()))+chr(10)
		return m.str
	endfunc

	hidden function analyseResult(usekey, type, ignore, from, to, step)
		local ps1, ps2, ps3, pa, lm, pk
		local pos, key, err, oldkey
		local tigs, i, base, complete, table, perc, equal
		local array stat(1,7), act(1,4)
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Analysing...")
		if vartype(m.from) == "L"
			m.from = 100
		endif
		if vartype(m.to) == "L"
			m.to = 0
		endif
		if vartype(m.type) == "L"
			m.type = 1
		endif
		if vartype(m.step) == "L"
			m.step = 1
		endif
		m.table = createobject("BaseCursor","percent n(6,2), comp i, comphit i, compnohit i, incomp i, hits i, nohits i, missing i, error n(8,4), unobserved n(8,4)")
		if not this.isValid()
			this.messenger.errormessage("ResultTable is not valid.")
			return m.table
		endif
		if m.type < 1 or m.type > 3
			this.messenger.errormessage("Illegal check type.")
			return m.table
		endif
		if not vartype(m.to) == "N"
			m.to = m.from
		endif
		if m.from > 100 or m.from < 0 or m.to > 100 or m.to < 0
			this.messenger.errormessage("Illegal percentage.")
			return m.table
		endif
		if vartype(m.step) == "N"
			if m.step < 0.1
				this.messenger.errormessage("Illegal step width.")
				return m.table
			endif
		else
			m.step = 1
		endif
		if m.from <= m.to
			m.tigs = int((m.to-m.from)/m.step)+2
		else
			m.tigs = 1
		endif
		dimension stat[m.tigs,7]
		dimension act[m.tigs,4]
		for m.i = 1 to m.tigs
			stat[m.i,1] = 0
			stat[m.i,2] = 0
			stat[m.i,3] = 0
			stat[m.i,4] = 0
			stat[m.i,5] = 0
			stat[m.i,6] = 0
			stat[m.i,7] = 0
		endfor
		m.pk = createobject("PreservedKey",this)
		if m.usekey
			this.forceKey("searched")
		else
			this.setKey()
		endif
		m.complete = 0
		m.oldkey = 0
		this.select()
		go top
		if searched <= 0
			skip
		endif
		this.messenger.setDefault("Analysed")
		this.messenger.startProgress(reccount()-recno()+1)
		this.messenger.startCancel("Cancel Operation?","Analysing ResultTable","Canceled.")
		do while not eof()
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				exit
			endif
			m.pos = recno()
			m.key = searched
			if m.oldkey >= m.key
				if not m.usekey
					if messagebox("Unable to analyse the ResultTable using the physical order."+chr(10)+"Restart analysis using an index?",36,"Analyse ResultTable") == 7
						exit
					endif
					return this.analyseResult(.t., m.type, m.ignore, m.from, m.to, m.step)
				endif
			endif
			m.oldkey = m.key
			for m.i = 1 to m.tigs
				act[m.i,1] = 0
				act[m.i,2] = 0
				act[m.i,3] = 0
				act[m.i,4] = 0
			endfor
			do while not eof() and searched == m.key
				do case
					case equal >= 8
						m.act[1,2] = m.act[1,2]+1
					case equal > 0
						m.act[1,1] = m.act[1,1]+1
					otherwise
						m.act[1,3] = m.act[1,3]+1
				endcase
				skip
			enddo
			if m.act[1,3] == 0
				m.complete = m.complete+act[1,1]+act[1,2]
			endif
			goto m.pos
			do while not eof() and searched == m.key
				for m.i = 2 to m.tigs
					m.perc = m.from+m.step*(m.i-2)
					do case
						case equal > 8
							m.base = 9
						case equal > 0
							m.base = 1
						otherwise
							m.base = 0
					endcase
					m.equal = m.base
					do case
						case m.type == 1
							if identity >= m.perc
								m.equal = 1
							else
								m.equal = 9
							endif
						case m.type == 2
							if identity >= m.perc
								m.equal = 1
							endif
						otherwise
							if identity < m.perc
								m.equal = 9
							endif
					endcase
					if m.act[1,3] == 0
						if m.base != m.equal
							m.act[m.i,4] = m.act[m.i,4]+1
						endif
						if not m.ignore
							m.equal = m.base
						endif
					endif
					do case
						case m.equal == 9
							m.act[m.i,2] = m.act[m.i,2]+1
						case m.equal > 0
							m.act[m.i,1] = m.act[m.i,1]+1
						otherwise
							m.act[m.i,3] = m.act[m.i,3]+1
					endcase
				endfor
				skip
			enddo
			this.messenger.incProgress(m.act[1,1]+m.act[1,2]+m.act[1,3])
			for m.i = 1 to m.tigs
				m.stat[m.i,1] = m.stat[m.i,1]+m.act[m.i,1]
				m.stat[m.i,2] = m.stat[m.i,2]+m.act[m.i,2]
				m.stat[m.i,3] = m.stat[m.i,3]+m.act[m.i,3]
				m.stat[m.i,4] = m.stat[m.i,4]+m.act[m.i,4]
				if m.act[m.i,3] == 0
					m.stat[m.i,5] = m.stat[m.i,5]+1
					if m.act[m.i,1] > 0
						m.stat[m.i,6] = m.stat[m.i,6]+1
					endif
				else
					m.stat[m.i,7] = m.stat[m.i,7]+1
				endif
			endfor
			this.messenger.postProgress()
		enddo
		this.messenger.sneakMessage("Closing...")
		for m.i = 1 to m.tigs
			if m.i == 1
				m.perc = -1
			else
				m.perc = m.from+m.step*(m.i-2)
			endif
			m.err = m.stat[m.i,4]/m.complete*100
			insert into (m.table.alias) values (m.perc,m.stat[m.i,5],m.stat[m.i,6],m.stat[m.i,5]-m.stat[m.i,6],m.stat[m.i,7],m.stat[m.i,1],m.stat[m.i,2],m.stat[m.i,3],m.err,m.err*m.stat[m.i,5]/(m.stat[m.i,5]+m.stat[m.i,7]))
		endfor
		m.table.synchronize()
		m.table.goTop()
		return m.table
	endfunc
enddefine

define class ExportTable as BaseTable
	hidden searchKey, foundKey, export
	searchKey = ""
	foundKey = ""
	engine = .f.

	protected function init(table)
		local struc, substruc, s
		BaseTable::init(m.table)
		m.struc = this.getTableStructure()
		m.substruc = m.struc.getStructureWith("searched, found")
		if m.substruc.getFieldCount() == 2
			m.s = m.substruc.toString()
		else
			m.s = "searched i, found i"
		endif
		if m.struc.checkCompatibility("identity b, equal n(1), score b, run n(3)", .t.)
			m.substruc = m.struc.getStructureWith("identity, equal, score, run")
			m.s = m.s+", "+m.substruc.toString()
		else
			m.s = m.s+", identity b, equal n(1), score b, run n(3)"
		endif
		this.setRequiredTableStructure(m.s)
		this.setRequiredKeys("searched; found")
		this.resizeRequirements()
	endfunc

	function getSearchKey()
		return this.searchKey
	endfunc

	function getFoundKey()
		return this.foundKey
	endfunc
	
	function getEngine()
		return this.engine
	endfunc

	function create(engine, searchKey, foundKey, low, high, exclusive, runFilter, text)
		local pa, ps1, ps2, ps3, ps4, pk, lm
		local f, result, search, found, identity, equal, score
		local stxt, ftxt, skey, fkey, srec, oldsrec, struc, err
		local run, buffer, skip, max
		local txt, line, exp, converter, con, handle, i, f1
		local array data[1]
		local searchRec, foundRec, idc
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","decimals","6")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Exporting...")
		if not vartype(m.engine) == "O"
			this.messenger.errormessage("Engine object is invalid.")
			return .f.
		endif
		m.idc = m.engine.idontcare()
		if not m.engine.isSearchedSynchronized()
			this.messenger.errormessage("Engine is not synchronized with SearchTable.")
			return .f.
		endif
		m.searchRec = not vartype(m.searchKey) == "C" or empty(m.searchKey)
		m.foundRec = not vartype(m.foundKey) == "C" or empty(m.foundKey)
		m.search = m.engine.getSearchTable()
		if m.searchRec == .f.
			m.f = m.search.getFieldStructure(m.searchKey)
			if not m.f.isValid()
				this.messenger.errormessage("SearchKey does not exist in SearchTable.")
				return .f.
			endif
			m.searchKey = m.f.getName()
		else
			m.searchKey = "searched"
		endif
		m.found = m.engine.getBaseTable()
		if m.foundRec == .f.
			m.f = m.found.getFieldStructure(m.foundKey)
			if not m.f.isValid()
				this.messenger.errormessage("FoundKey does not exist in BaseTable.")
				return .f.
			endif
			m.foundKey = m.f.getName()
		else
			m.foundKey = "found"
		endif
		if not inlist(vartype(m.low),"N","L")
			this.messenger.errormessage("Invalid low range.")
			return .f.
		endif
		if not inlist(vartype(m.high),"N","L") 
			this.messenger.errormessage("Invalid high range.")
			return .f.
		endif
		m.low = iif(vartype(m.low) == "N", max(m.low,0), 0)
		m.high = iif(vartype(m.high) == "N", max(m.high,0), 999)
		if m.high <= m.low
			m.high = m.low+1
		endif
		if not vartype(m.exclusive) == "L"
			this.messenger.errormessage("Invalid exclusive setting.")
			return .f.
		endif
		if not inlist(vartype(m.runFilter),"O","C","L")
			this.messenger.errormessage("Invalid runFilter setting.")
			return .f.
		endif
		if not vartype(m.text) == "L"
			this.messenger.errormessage("Invalid text setting.")
			return .f.
		endif
		if not vartype(m.runFilter) == "O"
			m.runFilter = createobject("RunFilter",m.runFilter)
		endif
		if not m.runFilter.isValid()
			this.messenger.errormessage("Run filter expression is invalid.")
			return .f.
		endif
		if m.text and not m.engine.isSearchedSynchronized()
			this.messenger.errormessage("SearchTable is not synchronized.")
			return .f.
		endif
		if m.text and not m.engine.isFoundSynchronized()
			this.messenger.errormessage("BaseTable is not synchronized.")
			return .f.
		endif
		if m.idc
			this.erase()
		endif
		if not this.isCreatable()
			this.messenger.errormessage("ExportTable is not creatable.")
			return .f.
		endif
		m.result = m.engine.getResultTable()
		m.struc = ""
		if m.searchRec
			m.f = m.result.getFieldStructure(m.searchKey)
		else
			m.f = m.search.getFieldStructure(m.searchKey)
		endif
		m.struc = "searched "+m.f.getDefinition()
		if m.foundRec
			m.f = m.result.getFieldStructure(m.foundKey)
		else
			m.f = m.found.getFieldStructure(m.foundKey)
		endif
		m.struc = m.struc + ",found "+m.f.getDefinition()
		m.struc = m.struc + ",identity b(6), equal n(1), score b(6), run n(3)"
		this.setRequiredTableStructure(m.struc)
		if m.text
			this.setOptionalTableStructure("searchtxt m, foundtxt m")
		endif
		m.struc = this.getCompleteTableStructure()
		dimension m.data[m.struc.getFieldCount()]
		m.buffer = createobject("UniqueAlias",.t.)
		m.txt = .f.
		if like("*.txt",lower(this.getDBF()))
			m.txt = .t.
			m.handle = FileOpenWrite(EXPORTHANDLE,this.getDBF())
			if m.handle <= 0
				this.messenger.errormessage("Unable to create ExportFile.")
				return .f.
			endif
			m.converter = createobject("Collection")
			m.exp = ""
			m.line = ""
			for m.i = 1 to m.struc.getFieldCount()
				m.f1 = m.struc.getFieldStructure(m.i)
				m.line = m.line+chr(9)+lower(m.f1.getName())
				m.con = m.f1.exportConverter()
				if len(m.exp)+len(m.con) > 4096
					m.converter.add(substr(m.exp,9))
					m.exp = ""
				endif
				m.exp = m.exp+'+chr(9)+'+m.con
			endfor
			if not empty(m.exp)
				m.converter.add(substr(m.exp,9))
			endif
			FileWriteCRLF(m.handle,substr(m.line,2))
			m.exp = createobject("BaseCursor",m.struc)
			select * from (m.exp.alias) where .f. into cursor (m.buffer.alias) readwrite
			m.exp.erase()
		else
			if not BaseTable::create()
				this.messenger.errormessage("Unable to create ExportTable.")
				return .f.
			endif
			select * from (this.alias) where .f. into cursor (m.buffer.alias) readwrite
		endif
		m.pk = createobject("PreservedKey",m.result)
		this.searchKey = iif(m.searchRec,"",m.searchKey)
		this.foundKey = iif(m.foundRec,"",m.foundKey)
		this.engine = m.engine
		this.deleteKey()
		m.search = this.engine.getSearchCluster()
		m.found = this.engine.getBaseCluster()
		m.result.forceKey("searched")
		m.result.setKey("searched")
		m.result.select()
		go top
		m.oldsrec = -1
		m.skip = .f.
		m.err = .f.
		this.messenger.setDefault("Exported")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation?","Exporting","Canceled.")
		try
			scan
				this.messenger.incProgress()
				if this.messenger.queryCancel()
					exit
				endif
				m.run = asc(run)
				if searched == 0 or not m.runFilter.isFiltered(m.run)
					this.messenger.incProgress()
					this.messenger.postProgress()
					loop
				endif
				m.srec = searched
				m.fkey = found
				m.identity = identity
				m.equal = equal
				m.score = score
				if not m.srec == m.oldsrec
					if reccount(m.buffer.alias) > 0 
						if m.skip == .f.
							if m.txt
								this.write(m.handle, m.converter, m.buffer.alias)
							else
								select (this.alias)
								append from dbf(m.buffer.alias)
							endif
						endif
						select * from (m.buffer.alias) where .f. into cursor (m.buffer.alias) readwrite
					endif
					m.oldsrec = m.srec
					m.max = m.identity
					m.skip = .f.
					if m.text or m.searchRec == .f.
						m.search.goRecord(m.srec)
						m.search.selectActiveTable()
					endif
					if m.searchRec
						m.skey = m.srec
					else
						m.skey = evaluate(m.searchKey)
					endif
					if m.text
						m.stxt = m.engine.extractSearchedText()
					endif
				else
					if m.identity > m.max
						m.max = m.identity
					endif
				endif
				if m.exclusive and m.max >= m.high
					m.skip = .t.
				endif
				if m.skip == .f. and m.identity >= m.low and m.identity < m.high
					if m.text or m.foundRec == .f.		
						m.found.goRecord(m.fkey)
						m.found.selectActiveTable()
					endif
					if m.foundRec == .f.
						m.fkey = evaluate(m.foundKey)
					endif
					if m.text
						m.ftxt = m.engine.extractFoundText()
						insert into (m.buffer.alias) (searched, found, identity, equal, score, run, searchtxt, foundtxt) values (m.skey, m.fkey, m.identity, m.equal, m.score, m.run, m.stxt, m.ftxt)
					else
						insert into (m.buffer.alias) (searched, found, identity, equal, score, run) values (m.skey, m.fkey, m.identity, m.equal, m.score, m.run)
					endif
				endif
				this.messenger.postProgress()
			endscan
			if m.skip == .f. and reccount(m.buffer.alias) > 0 
				if m.txt
					this.write(m.handle, m.converter, m.buffer.alias)
				else
					select (this.alias)
					append from dbf(m.buffer.alias)
				endif
			endif
		catch
			m.err = .t.
		endtry
		if m.err
			this.messenger.errormessage("ResultTable is not synchronized.")
			return .f.
		endif
		this.messenger.sneakMessage("Closing...")
		if m.txt
			FileClose(m.handle)
		else
			this.forceRequiredKeys()
		endif
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc
	
	hidden function write(handle as Integer, converter as Collection, alias as String)
	local line, i
		select (m.alias)
		scan
			m.line = evaluate(m.converter.item(1))
			for m.i = 2 to m.converter.Count
				m.line = m.line+chr(9)+evaluate(m.converter.item(m.i))
			endfor
			FileWriteCRLF(m.handle, m.line)
		endscan
	endfunc
enddefine

define class ExtendedExportTable as BaseTable
	protected function init(table)
		local struc, substruc, s
		BaseTable::init(m.table)
		m.struc = this.getTableStructure()
		m.substruc = m.struc.getStructureWith("searched, found")
		if m.substruc.getFieldCount() == 2
			m.s = m.substruc.toString()
		else
			m.s = "searched n(10), found n(10)"
		endif
		m.substruc = m.struc.getStructureWith("group")
		if m.substruc.getFieldCount() == 1
			m.s = m.substruc.toString()+", "+m.s
		endif
		if m.struc.checkCompatibility("identity n(6,2), equal n(1), score n(10,2), cnt n(10), run n(3)", .t.) or m.struc.checkCompatibility("identity n(6,2), equal c(1), score n(10,2), cnt n(10), run n(3)", .t.)
			m.substruc = m.struc.getStructureWith("identity, equal, score, cnt, run")
			m.s = m.s+", "+m.substruc.toString()
		else
			m.s = m.s+", identity n(6,2), equal n(1), score n(10,2), cnt n(10), run n(3)"
		endif
		this.setRequiredTableStructure(m.s)
		this.resizeRequirements()
	endfunc

	function create(export, searchedGroupKey, foundGroupKey)
		local pa, ps1, ps2, ps3, ps4, ps5, lm, pk1
		local searchKey, foundKey, search, found, sql, engine
		local i, j, struc, list, ins, f1, f2, name, join
		local joinCount, val, str
		local sort, searchedGrouping, foundGrouping, filter
		local temp, oldGroup, err, exportAlias
		local txt, blank, handle, converter, con, idontcare
		local array data[1]
		local searchRec, foundRec, runasc
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","null","on")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Extending...")
		if not vartype(m.export) == "O" or not m.export.isValid()
			this.messenger.errormessage("ExportTable is invalid.")
			return .f.
		endif
		m.engine = m.export.getEngine()
		if not vartype(m.engine) == "O" or not m.engine.isValid()
			this.messenger.errormessage("Engine object is invalid.")
			return .f.
		endif
		m.idontcare = m.engine.idontcare()
		m.searchKey = m.export.getSearchKey()
		m.foundKey = m.export.getFoundKey()
		m.engine = m.export.getEngine()
		if not vartype(m.searchKey) == "C" or empty(m.searchKey)
			m.searchKey = "searched"
			m.searchRec = .t.
		endif
		if not vartype(m.foundKey) == "C" or empty(m.foundKey)
			m.foundKey = "found"
			m.foundRec = .t.
		endif
		if not m.engine.isFoundSynchronized()
			this.messenger.errormessage("Engine is not synchronized with BaseTable.")
			return .f.
		endif
		if not m.engine.isSearchedSynchronized()
			this.messenger.errormessage("Engine is not synchronized with SearchTable.")
			return .f.
		endif
		m.search = m.engine.getSearchTable()
		if m.searchRec == .f.
			m.f1 = m.search.getFieldStructure(m.searchKey)
			if not m.f1.isValid()
				this.messenger.errormessage("SearchKey does not exist in SearchTable.")
				return .f.
			endif
		endif
		m.found = m.engine.getBaseTable()
		if m.foundRec == .f.
			m.f1 = m.found.getFieldStructure(m.foundKey)
			if not m.f1.isValid()
				this.messenger.errormessage("FoundKey does not exist in BaseTable.")
				return .f.
			endif
		endif
		m.searchedGrouping = .f.
		if vartype(m.searchedGroupKey) == "C" and not empty(m.searchedGroupKey)
			m.f1 = m.search.getFieldStructure(m.searchedGroupKey)
			if not m.f1.isValid()
				this.messenger.errormessage("GroupKey does not exist in SearchTable.")
				return .f.
			endif
			m.searchedGroupKey = m.f1.getName()
			m.searchedGrouping = .t.
		endif
		m.foundGrouping = .f.
		if vartype(m.foundGroupKey) == "C" and not empty(m.foundGroupKey)
			m.f1 = m.found.getFieldStructure(m.foundGroupKey)
			if not m.f1.isValid()
				this.messenger.errormessage("GroupKey does not exist in BaseTable.")
				return .f.
			endif
			m.foundGroupKey = m.f1.getName()
			m.foundGrouping = .t.
		endif
		if m.idontcare
			this.erase()
		endif
		if not this.isCreatable()
			this.messenger.errormessage("ExtendedExportTable is not creatable.")
			return .f.
		endif
		m.f1 = m.export.getFieldStructure("run")
		if m.f1.getType() == "C" and m.f1.getLength() == 1
			m.runasc = .t.
		endif
		m.struc = ""
		if m.searchedGrouping
			m.f1 = m.search.getFieldStructure(m.searchedgroupKey)
			if m.f1.getType() == "I"
				m.struc = "GROUP N(10)"
			else
				if m.f1.getType() == "B"
					m.struc = "GROUP N(18,9)"
				else
					m.struc = "GROUP "+m.f1.getDefinition()
				endif
			endif
			m.struc = m.struc+", "
		endif
		m.f1 = m.export.getFieldStructure("Searched")
		if m.f1.getType() == "I"
			m.struc = m.struc+"SEARCHED N(10)"
		else
			if m.f1.getType() == "B"
				m.struc = m.struc+"SEARCHED N(18,9)"
			else
				m.struc = m.struc+m.f1.toString()
			endif
		endif
		m.struc = m.struc+", "
		if m.foundGrouping
			m.f1 = m.found.getFieldStructure(m.foundGroupKey)
		else
			m.f1 = m.export.getFieldStructure("Found")
		endif
		if m.f1.getType() == "I"
			m.struc = m.struc+"FOUND N(10)"
		else
			if m.f1.getType() == "B"
				m.struc = m.struc+"FOUND N(18,9)"
			else
				m.struc = m.struc+"FOUND "+m.f1.getDefinition()
			endif
		endif
		m.struc = m.struc+", IDENTITY N(6,2), EQUAL N(1)"
		m.struc = createobject("TableStructure",m.struc)
		m.list = m.struc.getFieldList()
		m.list = ", "+m.list+", SCORE, CNT, RUN"
		m.list = upper(m.list)
		m.ins = "m.data[2], m.data[3], m.data[4], m.data[5]"
		if m.searchedGrouping
			m.ins = "m.data[1], "+m.ins
		endif
		m.struc = m.struc.toString()
		m.join = m.engine.getSearchFieldJoin()
		m.joinCount = m.join.getJoinCount()
		for m.i = 1 to m.joinCount
			m.f1 = m.join.getA(m.i)
			m.f2 = m.join.getB(m.i)
			m.name = upper(m.f1.getName())
			m.j = 0
			do while ", "+m.name+"," $ m.list
				m.j = m.j+1
				if m.j > 999
					this.messenger.errormessage("Unresolvable name conflict.")
					return .f.
				endif
				m.name = "f"+padl(ltrim(str(m.j)),3,"0")
			enddo
			m.ins = m.ins+", m.data["+ltrim(str(m.i+5))+"]"
			m.struc = m.struc+", "+m.name+" C("+ltrim(str(max(m.f1.getStringSize(),m.f2.getStringSize())))+")"
		endfor
		m.ins = m.ins+", m.data["+ltrim(str(m.joinCount+6))+"], m.data["+ltrim(str(m.joinCount+7))+"], m.data["+ltrim(str(m.joinCount+8))+"]"
		m.struc = m.struc+", score n(10,2), cnt n(10), run n(3)"
		m.ins = "INSERT INTO (this.alias) VALUES ("+m.ins+")"
		dimension data[8+m.joinCount]
		this.setRequiredTableStructure(m.struc)
		if m.searchRec == .f. and not m.engine.setKey(m.search, m.searchKey)
			this.messenger.errormessage("Unable to index SearchTable.")
			return .f.
		endif
		if m.foundRec == .f. and not m.engine.setKey(m.found, m.foundKey)
			this.messenger.errormessage("Unable to index BaseTable.")
			return .f.
		endif
		m.pk1 = createobject("PreservedKey",m.export)
		if not m.engine.setKey(m.export, "searched")
			this.messenger.errormessage("Unable to index ExportTable.")
			return .f.
		endif
		m.txt = .f.
		if like("*.txt",lower(this.getDBF()))
			m.txt = .t.
			m.handle = FileOpenWrite(EXPORTHANDLE,this.getDBF())
			if m.handle <= 0
				this.messenger.errormessage("Unable to create ExtendedExportFile.")
				return .f.
			endif
			m.struc = this.getRequiredTableStructure()
			m.converter = createobject("Collection")
			m.j = iif(m.searchedGrouping,1,2)
			m.ins = ""
			m.list = ""
			m.blank = ""
			for m.i = 1 to m.struc.getFieldCount()
				m.f1 = m.struc.getFieldStructure(m.i)
				m.list = m.list+chr(9)+lower(m.f1.getName())
				m.blank = m.blank+chr(9)
				m.f1.fname = "m.data["+ltrim(str(m.j))+"]"
				m.con = m.f1.exportConverter()
				if len(m.ins)+len(m.con) > 4096
					m.converter.add(substr(m.ins,9))
					m.ins = ""
				endif
				m.ins = m.ins+'+chr(9)+'+m.con
				m.j = m.j+1
			endfor
			if not empty(m.ins)
				m.converter.add(substr(m.ins,9))
			endif
			m.blank = substr(m.blank,2)
			FileWriteCRLF(m.handle,substr(m.list,2))
			m.ins = "this.write(m.handle,m.converter,@m.data)"
		else
			if not BaseTable::create()
				if not empty(this.messenger.getMessage())
					this.messenger.errormessage(this.messenger.getMessage())
				else
					this.messenger.errormessage("Unable to create ExtendedExportTable.")
				endif
				return .f.
			endif
		endif
		m.sort = createobject("UniqueAlias",.t.)
		m.temp = createobject("UniqueAlias",.t.)
		m.filter = createobject("UniqueAlias",.t.)
		m.search = m.engine.getSearchCluster()
		m.found = m.engine.getBaseCluster()
		m.exportAlias = m.export.alias
		m.err = .f.
		try
			if m.foundGrouping
				this.messenger.forceMessage("Filtering...")
				if m.foundrec
					m.struc = m.found.getTableStructure()
					m.f1 = m.struc.getFieldStructure(m.foundGroupKey)
					m.f1.null = .t.
					m.sql = "SELECT cast(0 as i) as rec, cast(.NULL. as "+m.f1.getDefinition()+") as group, a.searched, a.found, a.identity, a.score, a.equal, a.run FROM "+m.exportAlias+" a into cursor "+m.sort.alias+" readwrite"
					&sql
					m.f1 = m.f1.getName()
					scan
						if m.found.goRecord(found)
							replace group with evaluate(m.found.table.alias+"."+m.f1)
						endif
					endscan
					select * from (m.sort.alias) where not isnull(group) order by 2, 3, 5, 6, 4 into cursor (m.sort.alias) readwrite
				else
					m.found.select("SELECT cast(0 as i) as rec, b."+m.foundGroupKey+" as group, a.searched, a.found, a.identity, a.score, a.equal, a.run FROM "+m.exportAlias+" a, [CLUSTERALIAS] b WHERE a.found == b."+m.foundKey+" order by 2, 3, 5, 6, 4", m.sort.alias)
				endif
				update (m.sort.alias) set rec = recno()
				index on group tag group
				m.sql = "select a.searched, a.found, a.identity, a.score, a.equal, a.run from (m.sort.alias) a where not exists (select b.group from (m.sort.alias) b where a.group == b.group and a.searched == b.searched and b.rec > a.rec) into cursor (m.filter.alias) readwrite"
				&sql
				m.exportAlias = m.filter.alias
				if m.searchedGrouping
					index on searched tag searched
				endif
			endif
			if m.searchedGrouping
				this.messenger.forceMessage("Filtering...")
				if m.searchrec
					m.struc = m.search.getTableStructure()
					m.f1 = m.struc.getFieldStructure(m.searchedGroupKey)
					m.f1.null = .t.
					m.sql = "SELECT cast(0 as i) as rec, cast(.NULL. as "+m.f1.getDefinition()+") as group, a.searched, a.found, a.identity, a.score, a.equal, a.run FROM "+m.exportAlias+" a into cursor "+m.sort.alias+" readwrite"
					&sql
					m.f1 = m.f1.getName()
					scan
						if m.search.goRecord(searched)
							replace group with evaluate(m.search.table.alias+"."+m.f1)
						endif
					endscan
					select * from (m.sort.alias) where not isnull(group) order by 2, 4, 5, 6, 3 into cursor (m.sort.alias) readwrite
				else
					m.search.select("SELECT cast(0 as i) as rec, b."+m.searchedGroupKey+" as group, a.searched, a.found, a.identity, a.score, a.equal, a.run FROM "+m.exportAlias+" a, [CLUSTERALIAS] b WHERE a.searched == b."+m.searchKey+" order by 2, 4, 5, 6, 3", m.sort.alias)
				endif
				update (m.sort.alias) set rec = recno()
				index on group tag group
				m.sql = "select a.group, a.searched, a.found, a.identity, a.score, a.equal, a.run from (m.sort.alias) a where not exists (select b.group from (m.sort.alias) b where a.group == b.group and a.found == b.found and b.rec > a.rec) into cursor (m.filter.alias) readwrite"
				&sql
				m.exportAlias = m.filter.alias
				index on searched tag searched
				this.messenger.forceMessage("Sorting...")
				select group, count(*) as cnt, max(score) as score from (m.filter.alias) group by 1 into cursor (m.temp.alias) readwrite
				index on group tag group
				select group, searched, max(score) as score, count(*) as cnt from (m.filter.alias) group by 1, 2 into cursor (m.sort.alias)
				select a.group, a.searched, a.score, b.cnt from (m.sort.alias) a, (m.temp.alias) b where a.group == b.group order by b.cnt desc, b.score, a.group, a.cnt, a.score desc, a.searched into cursor (m.sort.alias)
			else
				this.messenger.forceMessage("Sorting...")
				select searched, count(*) as cnt, max(score) as score from (m.exportAlias) group by 1 order by 2 desc, 3, 1 into cursor (m.sort.alias)
			endif
			if m.runasc
				m.sql = "select searched, found, identity, score, equal, cast(asc(run) as n(3)) as run from (m.exportAlias) order by 1, 3 desc, 4 desc, 2 into cursor (m.temp.alias) readwrite"
			else
				m.sql = "select searched, found, identity, score, equal, run from (m.exportAlias) order by 1, 3 desc, 4 desc, 2 into cursor (m.temp.alias) readwrite"
			endif
			&sql
			m.exportAlias = m.temp.alias
			index on searched tag searched
		catch
			m.err = .t.
		endtry
		if m.err
			this.messenger.errormessage("Unable to create temporary Cursor.")
			return .f.
		endif
		release m.filter
		m.str = createobject("String")
		select (m.sort.alias)
		m.oldGroup = .null.
		this.messenger.setDefault("Extended")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation?","Extending","Canceled.")
		scan
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				exit
			endif
			m.data[2] = searched
			m.data[3] = .null.
			m.data[4] = .null.
			m.data[5] = .null.
			m.data[m.joinCount+8] = .null.
			if this.navigate(m.search, searched, m.searchRec)
				m.search.selectActiveTable()
				for m.i = 1 to m.joinCount
					m.f1 = m.join.getA(m.i)
					m.val = evaluate(m.f1.getName())
					if vartype(m.val) == "C"
						m.data[m.i+5] = m.val
					else
						m.str.setString(m.val)
						m.data[m.i+5] = m.str.toString()
					endif
				endfor
				select (m.sort.alias)
				m.data[m.joinCount+6] = score
				m.data[m.joinCount+7] = cnt
				if m.searchedGrouping
					m.data[1] = group
					if group == m.oldGroup
						if m.txt == .f.
							replace group with m.data[1] in (this.alias)
						endif
					endif
					m.oldGroup = group
				endif
				&ins
				if seek(m.data[2], m.exportAlias)
					select (m.exportAlias)
					do while not eof() and searched == m.data[2]
						if this.navigate(m.found, found, m.foundRec)
							m.found.selectActiveTable()
							for m.i = 1 to m.joinCount
								m.f1 = m.join.getb(m.i)
								m.val = evaluate(m.f1.getName())
								if vartype(m.val) == "C"
									m.data[m.i+5] = m.val
								else
									m.str.setString(m.val)
									m.data[m.i+5] = m.str.toString()
								endif
							endfor
							if m.foundGrouping
								m.data[3] = evaluate(m.foundGroupKey)
								select (m.exportAlias)
							else
								select (m.exportAlias)
								m.data[3] = evaluate("found")
							endif
							m.data[4] = identity
							m.data[5] = iif(empty(equal),.null.,equal)
							m.data[m.joinCount+8] = run
							&ins
						endif
						skip
					enddo
					select (m.sort.alias)
				endif
				if m.txt
					FileWriteCRLF(m.handle, m.blank)
				else
					append blank in (this.alias)
				endif
			endif
			this.messenger.postProgress()
		endscan
		this.messenger.sneakMessage("Closing...")
		if m.txt
			FileClose(m.handle)
		else
			select (this.alias)
			blank fields equal for isnull(equal)
			m.sql = "blank fields found, identity, run for isnull(found)"
			&sql
		endif
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc
	
	hidden function navigate(cluster, keyrec, isrec)
		if m.isrec
			return m.cluster.goRecord(m.keyrec)
		endif
		return m.cluster.seek(m.keyrec)
	endfunc

	hidden function write(handle as Integer, converter as Collection, data)
	local line, i
		m.line = evaluate(m.converter.item(1))
		for m.i = 2 to m.converter.count
			m.line = m.line+chr(9)+evaluate(m.converter.item(m.i))
		endfor
		FileWriteCRLF(m.handle, m.line)
	endfunc
enddefine

define class GroupedExportTable as BaseTable
	protected function init(table)
		local struc, substruc, s
		BaseTable::init(m.table)
		m.struc = this.getTableStructure()
		m.substruc = m.struc.getStructureWith("group, member")
		if m.substruc.getFieldCount() == 2
			m.s = m.substruc.toString()
		else
			m.s = "group n(10), member n(10)"
		endif
		if m.struc.checkCompatibility("cnt n(10)", .t.)
			m.substruc = m.struc.getStructureWith("cnt")
			m.s = m.s+", "+m.substruc.toString()
		else
			m.s = m.s+", cnt n(10)"
		endif
		this.setRequiredTableStructure(m.s)
		this.resizeRequirements()
	endfunc

	function create(export, cascade, notext, nosingle)
		local pa, ps1, ps2, ps3, ps4, ps5, lm
		local searchKey, foundKey, searchRec, found, engine
		local i, j, struc, ins, f1, name, join, joinCount, val, str
		local err, group, oldGroup, sort, temp
		local txt, converter, con, handle, line, blank, rc
		local score, perc, prev, percent, rcnt, idontcare
		local text, single
		local array data(1)
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","null","on")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Grouping...")
		if not vartype(m.export) == "O" or not m.export.isValid()
			this.messenger.errormessage("ExportTable is invalid.")
			return .f.
		endif
		m.engine = m.export.getEngine()
		if not vartype(m.engine) == "O" or not m.engine.isValid()
			this.messenger.errormessage("Engine object is invalid.")
			return .f.
		endif
		m.idontcare = m.engine.idontcare()
		m.searchKey = m.export.getSearchKey()
		m.foundKey = m.export.getFoundKey()
		m.text = not m.notext
		m.single = not m.nosingle
		if not m.searchKey == m.foundKey
			this.messenger.errormessage("SearchKey and FoundKey are not identical.")
			return .f.
		endif
		if empty(m.searchKey)
			m.searchRec = .t.
		endif
		if not vartype(m.engine) == "O" or not m.engine.isValid()
			this.messenger.errormessage("Engine Object is invalid.")
			return .f.
		endif
		if not m.engine.isMono()
			this.messenger.errormessage("Engine is not mono.")
			return .f.
		endif
		if not vartype(m.cascade) == "O"
			m.cascade = createobject("NestedCascade",m.cascade)
		endif
		m.score = .f.
		m.perc = .f.
		if not m.cascade.isValid("min b, max b")
			if not m.cascade.isValid("min b, max b, s b")
				if not m.cascade.isValid("min b, max b, p b")
					if not m.cascade.isValid("min b, max b, p b, s b")
						this.messenger.errormessage("Invalid cascade definition.")
						return .f.
					else
						m.perc = .t.
						m.score = .t.
					endif
				else
					m.perc = .t.
				endif
			else
				m.score = .t.
			endif
		endif
		m.found = m.engine.getBaseTable()
		if m.searchRec == .f.
			m.f1 = m.found.getFieldStructure(m.searchKey)
			if not m.f1.isValid()
				this.messenger.errormessage("SearchKey does not exist in BaseTable.")
				return .f.
			endif
		endif
		m.f1 = m.export.getFieldStructure("Searched")
		if m.f1.getType() == "I"
			m.struc = "GROUP N(10), MEMBER N(10)"
		else
			if m.f1.getType() == "B"
				m.struc = "GROUP N(18,9), MEMBER N(18,9)"
			else
				m.struc = "GROUP "+m.f1.getDefinition()+", MEMBER "+m.f1.getDefinition()
			endif
		endif
		m.ins = "m.data[1], m.data[2]"
		if m.text
			m.struc = m.struc+", subgroup N(3)"
			m.ins = m.ins+", m.data[3]"
			m.struc = ", CNT , "+m.struc
			m.struc = upper(m.struc)
			m.join = m.engine.getSearchFieldJoin()
			m.joinCount = m.join.getJoinCount()
			for m.i = 1 to m.joinCount
				m.f1 = m.join.getA(m.i)
				m.name = upper(m.f1.getName())
				m.j = 0
				do while ", "+m.name+" " $ m.struc
					m.j = m.j+1
					if m.j > 999
						this.messenger.errormessage("Unresolvable name conflict.")
						return .f.
					endif
					m.name = "f"+padl(ltrim(str(m.j)),3,"0")
				enddo
				m.ins = m.ins+", m.data["+ltrim(str(m.i+3))+"]"
				m.struc = m.struc+", "+m.name+" C("+ltrim(str(m.f1.getStringSize()))+")"
			endfor
			m.ins = m.ins+", m.data["+ltrim(str(m.i+3))+"]"
			dimension data[m.i+3]
			m.struc = substr(m.struc, 9)
		else
			m.ins = m.ins+", m.data[3]"
			dimension data[3]
		endif
		m.struc = m.struc+", CNT N(10)"
		m.ins = "INSERT INTO (this.alias) VALUES ("+m.ins+")"
		this.setRequiredTableStructure(m.struc)
		if m.text and m.searchRec == .f. and not m.engine.setKey(m.found, m.searchKey)
			this.messenger.errormessage("Unable to index BaseTable.")
			return .f.
		endif
		if not (m.export.forceKey("searched") and m.export.forceKey("found"))
			this.messenger.errormessage("Unable to index ExportTable.")
			return .f.
		endif
		if m.idontcare
			this.erase()
		endif
		if not this.isCreatable()
			this.messenger.errormessage("GroupedExportTable is not creatable.")
			return .f.
		endif
		m.sort = createobject("UniqueAlias",.t.)
		m.temp = createobject("UniqueAlias",.t.)
		m.found = m.engine.getBaseCluster()
		m.err = .f.
		try
			this.messenger.forceMessage("Reflecting...")
			if m.score or m.perc
				if not m.perc
					select searched, found, cast(max(identity) as b(6)) as identity, cast(max(score) as b(6)) as s from (m.export.alias) group by 1, 2 into cursor (m.temp.alias) readwrite
				else
					if m.score
						select searched, found, cast(max(identity) as b(6)) as identity, cast(max(score) as b(6)) as p, cast(max(score) as b(6)) as s from (m.export.alias) group by 1, 2 order by 4 into cursor (m.temp.alias) readwrite
					else				
						select searched, found, cast(max(identity) as b(6)) as identity, cast(max(score) as b(6)) as p from (m.export.alias) group by 1, 2 order by 4 into cursor (m.temp.alias) readwrite
					endif
				endif
				if m.perc
					this.messenger.forceMessage("Percentiling...")
					select (m.temp.alias)
					m.rcnt = reccount()
					m.prev = p
					m.percent = 1/m.rcnt * 100
					scan
						if p != m.prev
							m.prev = p
							m.percent = recno()/m.rcnt * 100
						endif
						replace p with m.percent
					endscan
					this.messenger.forceMessage("Reflecting...")
				endif
				if not m.perc	
					select a.searched, a.found, cast(iif(a.identity > nvl(b.identity,0),nvl(b.identity,0),a.identity) as b(6)) as min, cast(iif(a.identity > nvl(b.identity,0),a.identity,nvl(b.identity,0)) as b(6)) as max, cast(iif(a.s >= nvl(b.s,0),nvl(b.s,a.s),a.s) as b(6)) as s from (m.temp.alias) a left join (m.temp.alias) b on a.searched == b.found and a.found == b.searched where a.searched <= a.found or a.identity == 0 or nvl(b.identity,0) == 0 into cursor (m.sort.alias) readwrite
				else
					if m.score
						select a.searched, a.found, cast(iif(a.identity > nvl(b.identity,0),nvl(b.identity,0),a.identity) as b(6)) as min, cast(iif(a.identity > nvl(b.identity,0),a.identity,nvl(b.identity,0)) as b(6)) as max, cast(iif(a.p >= nvl(b.p,0),nvl(b.p,a.p),a.p) as b(6)) as p, cast(iif(a.s >= nvl(b.s,0),nvl(b.s,a.s),a.s) as b(6)) as s from (m.temp.alias) a left join (m.temp.alias) b on a.searched == b.found and a.found == b.searched where a.searched <= a.found or a.identity == 0 or nvl(b.identity,0) == 0 into cursor (m.sort.alias) readwrite
					else
						select a.searched, a.found, cast(iif(a.identity > nvl(b.identity,0),nvl(b.identity,0),a.identity) as b(6)) as min, cast(iif(a.identity > nvl(b.identity,0),a.identity,nvl(b.identity,0)) as b(6)) as max, cast(iif(a.p >= nvl(b.p,0),nvl(b.p,a.p),a.p) as b(6)) as p from (m.temp.alias) a left join (m.temp.alias) b on a.searched == b.found and a.found == b.searched where a.searched <= a.found or a.identity == 0 or nvl(b.identity,0) == 0 into cursor (m.sort.alias) readwrite
					endif
				endif				
			else
				select searched, found, cast(max(identity) as b(6)) as identity from (m.export.alias) group by 1, 2 into cursor (m.temp.alias) readwrite
				select a.searched, a.found, cast(iif(a.identity > nvl(b.identity,0),nvl(b.identity,0),a.identity) as b(6)) as min, cast(iif(a.identity > nvl(b.identity,0),a.identity,nvl(b.identity,0)) as b(6)) as max from (m.temp.alias) a left join (m.temp.alias) b on a.searched == b.found and a.found == b.searched where a.searched <= a.found or a.identity == 0 or nvl(b.identity,0) == 0 into cursor (m.sort.alias) readwrite
			endif
		catch
			m.err = .t.
		endtry
		if m.err
			this.messenger.errormessage("Unable to create temporary Cursor.")
			return .f.
		endif
		m.group = createobject("CascadeTable",this.getDBF())
		m.group.setCursor(.t.)
		m.group.setCascade(m.cascade)
		m.group.setMessenger(this.messenger)
		try
			m.rc = m.group.create(m.sort.alias,"searched","found")
		catch
			m.err = .t.
		endtry
		if m.err
			this.messenger.errormessage("Grouping exceeded system limits.")
			return .f.
		endif
		if m.rc == .f.
			return .f.
		endif
		if not m.group.forceKey("from")
			this.messenger.errormessage("Unable to index GroupCursor.")
			return .f.
		endif
		try
			this.messenger.forceMessage("Sorting...")
			if m.single
				select a.from, count(*) as cnt from (m.group.alias) a group by 1 into cursor (m.temp.alias) nofilter
			else
				select a.from, count(*) as cnt from (m.group.alias) a group by 1 having cnt > 1 into cursor (m.temp.alias) nofilter
			endif
			index on from tag from
			select a.from as group, a.to as member, b.cnt from (m.group.alias) a, (m.temp.alias) b where a.from == b.from order by 3 desc, 1, 2 into cursor (m.sort.alias)
			select (m.temp.alias)
			use
		catch
			m.err = .t.
		endtry
		m.group.erase()
		m.group.setCursor(.f.)
		if m.err
			this.messenger.errormessage("Unable to create temporary SortCursor.")
			return .f.
		endif
		m.txt = .f.
		if like("*.txt",lower(this.getDBF()))
			m.txt = .t.
			m.handle = FileOpenWrite(EXPORTHANDLE,this.getDBF())
			if m.handle <= 0
				this.messenger.errormessage("Unable to create GroupedExportFile.")
				return .f.
			endif
			m.struc = this.getRequiredTableStructure()
			m.converter = createobject("Collection")
			m.ins = ""
			m.line = ""
			m.blank = ""
			for m.i = 1 to m.struc.getFieldCount()
				m.f1 = m.struc.getFieldStructure(m.i)
				m.line = m.line+chr(9)+lower(m.f1.getName())
				m.blank = m.blank+chr(9)
				m.f1.fname = "m.data["+ltrim(str(m.i))+"]"
				m.con = m.f1.exportConverter()
				if len(m.ins)+len(m.con) > 4096
					m.converter.add(substr(m.ins,9))
					m.ins = ""
				endif
				m.ins = m.ins+'+chr(9)+'+m.con
			endfor
			if not empty(m.ins)
				m.converter.add(substr(m.ins,9))
			endif
			m.blank = substr(m.blank,2)
			FileWriteCRLF(m.handle, substr(m.line,2))
			m.ins = "this.write(m.handle,m.converter,@m.data)"
		else
			if not BaseTable::create()
				if not empty(this.messenger.getMessage())
					this.messenger.errormessage(this.messenger.getMessage())
				else
					this.messenger.errormessage("Unable to create GroupedExportTable.")
				endif
				return .f.
			endif
		endif
		m.str = createobject("String")
		select (m.sort.alias)
		go top
		m.oldGroup = group
		this.messenger.setDefault("Extended")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation?","Extending","Canceled.")
		scan
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				exit
			endif
			m.data[1] = group
			m.data[2] = member
			m.data[3] = .null.
			if m.text
				if this.navigate(m.found, member, m.searchRec)
					m.found.selectActiveTable()
					for m.i = 1 to m.joinCount
						m.f1 = m.join.getA(m.i)
						m.val = evaluate(m.f1.getName())
						if vartype(m.val) == "C"
							m.data[m.i+3] = m.val
						else
							m.str.setString(m.val)
							m.data[m.i+3] = m.str.toString()
						endif
					endfor
					select (m.sort.alias)
					m.data[m.i+3] = cnt
					if not group == m.oldGroup
						if m.txt
							FileWriteCRLF(m.handle, m.blank)
						else
							append blank in (this.alias)
						endif
					endif
					m.oldGroup = group
					&ins
				endif
			else
				m.data[3] = cnt
				&ins
			endif
			this.messenger.postProgress()
		endscan
		this.messenger.sneakMessage("Closing...")
		if m.txt
			if m.text and reccount(m.sort.alias) > 0
				FileWriteCRLF(m.handle, m.blank)
			endif
			FileClose(m.handle)
		else
			select (this.alias)
			if m.text and reccount() > 0
				append blank
				blank fields subgroup for .t.
			endif
		endif
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc
	
	hidden function navigate(cluster, keyrec, isrec)
		if m.isrec
			return m.cluster.goRecord(m.keyrec)
		endif
		return m.cluster.seek(m.keyrec)
	endfunc

	hidden function write(handle as Integer, converter as Collection, data)
	local line, i
		m.line = evaluate(m.converter.item(1))
		for m.i = 2 to m.converter.count
			m.line = m.line+chr(9)+evaluate(m.converter.item(m.i))
		endfor
		FileWriteCRLF(m.handle, m.line)
	endfunc
enddefine

define class MetaExportTable as BaseTable
	protected function init(table)
	local struc, substruc, s
		BaseTable::init(m.table)
		m.struc = this.getTableStructure()
		m.substruc = m.struc.getStructureWith("searched, found")
		if m.substruc.getFieldCount() == 2
			m.s = m.substruc.toString()
		else
			m.s = "searched n(10), found n(10)"
		endif
		if m.struc.checkCompatibility("identity n(6,2), score n(10,2)", .t.)
			m.substruc = m.struc.getStructureWith("identity, score")
			m.s = m.s+", "+m.substruc.toString()
		else
			m.s = m.s+", identity n(6,2), score n(10,2)"
		endif
		this.setRequiredTableStructure(m.s)
		this.resizeRequirements()
	endfunc
		
	function create(engine, meta, raw, low, high, runFilter)
		local pa, ps1, ps2, ps3, ps4, ps5, ps6, ps7, lm
		local result, foundtypes, searchedtypes, handle1, handle2, line
		local foundreg, searchedreg, stype, ftype, type, typeindex
		local searched, found, identity, score, run, join, runmax
		local entrylen, base2reg, target, searchcluster
		local cluster, index, start, end, table
		local sx, fx, mx, sxcnt, fxcnt, mxcnt
		local lex, lexarray, already, idc, count, cnt
		local i, j, k, f, s, m, fa, fb, txt, chr9
		local norm, header, ind, val, sql, struc, temp
		local tmp, ipos, icnt, pos
		local normalize
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","decimals","6")
		m.ps5 = createobject("PreservedSetting","century","on")
		m.ps6 = createobject("PreservedSetting","date","ansi")
		m.ps7 = createobject("PreservedSetting","hours","24")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Exporting Meta...")
		if not vartype(m.engine) == "O"
			this.messenger.errormessage("Engine object is invalid.")
			return .f.
		endif
		m.idc = m.engine.idontcare()
		if not m.engine.isValid()
			this.messenger.errormessage("Engine is invalid.")
			return .f.
		endif
		if not m.engine.isSearchReady()
			this.messenger.errormessage("Engine is not synchronized.")
			return .f.
		endif
		if not m.engine.isResultTableReady()
			this.messenger.errormessage("ResultTable is invalid.")
			return .f.
		endif
		if m.idc
			this.erase()
		endif
		if not this.isCreatable()
			this.messenger.errormessage("MetaExportTable is not creatable.")
			return .f.
		endif
		m.result = m.engine.getResultTable()
		m.foundtypes = m.engine.getSearchTypes()
		if not m.foundtypes.isValid()
			this.messenger.errormessage("SearchTypes are invalid.")
			return .f.
		endif
		if not m.engine.isSearchedSynchronized()
			this.messenger.errormessage("SearchTable is not synchronized.")
			return .f.
		endif
		if not m.engine.isFoundSynchronized()
			this.messenger.errormessage("BaseTable is not synchronized.")
			return .f.
		endif
		if not inlist(vartype(m.meta),"C","L")
			this.messenger.errormessage("Invalid meta filter.")
			return .f.
		endif
		if vartype(m.raw) == "N"
			m.runfilter = m.high
			m.high = m.low
			m.low = m.raw
		endif
		m.meta = createobject("MetaFilter",m.meta,m.foundtypes)
		if not m.meta.isValid()
			this.messenger.errormessage("Invalid meta filter.")
			return .f.
		endif
		if not inlist(vartype(m.low),"N","L")
			this.messenger.errormessage("Invalid low range.")
			return .f.
		endif
		if not inlist(vartype(m.high),"N","L") 
			this.messenger.errormessage("Invalid high range.")
			return .f.
		endif
		m.low = iif(vartype(m.low) == "N", max(m.low,0), 0)
		m.high = iif(vartype(m.high) == "N", max(m.high,0), 999)
		if m.high <= m.low
			m.high = m.low+1
		endif
		if not inlist(vartype(m.runFilter),"O","C","L")
			this.messenger.errormessage("Invalid runFilter setting.")
			return .f.
		endif
		if not vartype(m.runFilter) == "O"
			m.runFilter = createobject("RunFilter",m.runFilter)
		endif
		if not m.runFilter.isValid()
			this.messenger.errormessage("Run filter expression is invalid.")
			return .f.
		endif
		if not vartype(m.raw) == "L"
			this.messenger.errormessage("Raw setting invalid.")
			return .f.
		endif
		m.normalize = m.raw == .f.
		m.runmax = m.result.getRun()
		m.s = 7
		if like("*.txt",lower(this.getDBF()))
			m.txt = .t.
			m.chr9 = chr(9)
			m.line = "SEARCHED"+m.chr9+"FOUND"+m.chr9+"IDENTITY"+m.chr9+"SCORE"+m.chr9+"CNT"+m.chr9+"ICNT"+m.chr9+"IPOS"
			for m.i = 1 to m.runmax
				if m.runFilter.isFiltered(m.i)
					m.line = m.line+m.chr9+"RUN"+ltrim(str(m.i))
					m.s = m.s+1
				endif
			endfor
			if m.s == 7
				this.messenger.errormessage("Run filter yields no results.")
				return .f.
			endif				
			for m.i = 1 to m.foundtypes.getSearchTypeCount()
				for m.j = 1 to 3
					m.f = substr("MFS",m.j,1)+ltrim(str(m.i))+"_"
					for m.k = 1 to m.meta.meta[m.i]
						m.line = m.line+m.chr9+m.f+ltrim(str(m.k))
						m.s = m.s+1
					endfor
				endfor
			endfor
			if m.normalize
				m.temp = createobject("BaseTable",this.getPath()+this.getPureName()+".tmp")
				m.temp.erase()
				m.temp.setCursor(.t.)
				m.handle1 = FileOpenWrite(OUTHANDLE,m.temp.getDBF())
				if m.handle1 <= 0
					this.messenger.errormessage("Unable to create temporary file: "+m.temp.getDBF())
					return .f.
				endif
			else
				m.handle1 = FileOpenWrite(OUTHANDLE,this.getDBF())
				if m.handle1 <= 0
					this.messenger.errormessage("Unable to create MetaExportTable.")
					return .f.
				endif
			endif
			FileWriteCRLF(m.handle1,m.line)
			m.header = m.line
		else
			m.chr9 = ","
			m.line = "searched i, found i, identity b(6), score b(6), cnt b(6), icnt b(6), ipos b(6)"
			for m.i = 1 to m.runmax
				if m.runFilter.isFiltered(m.i)
					m.line = m.line+", RUN"+ltrim(str(m.i))+" n(1)"
					m.s = m.s+1
				endif
			endfor
			if m.s == 7
				this.messenger.errormessage("Run filter yields no results.")
				return .f.
			endif				
			for m.i = 1 to m.foundtypes.getSearchTypeCount()
				for m.j = 1 to 3
					m.f = substr("MFS",m.j,1)+ltrim(str(m.i))+"_"
					for m.k = 1 to m.meta.meta[m.i]
						m.line = m.line+", "+m.f+ltrim(str(m.k))+" b(6)"
						m.s = m.s+1
					endfor
				endfor
			endfor
			if m.s > 254
				this.messenger.errormessage('Too many fields for MetaExportTable. Try ".txt" export.')
				return .f.
			endif
			this.setRequiredTableStructure(m.line)
			if not BaseTable::create()
				this.messenger.errormessage('Unable to create MetaExportTable.')
				return .f.
			endif
		endif
		if m.normalize
			dimension m.norm[m.s,2]
			for m.i = 1 to m.s
				m.norm[m.i,1] = 9999999999
				m.norm[m.i,2] = -1
			endfor
		endif
		m.searchcluster = m.engine.getSearchCluster()
		m.foundreg = m.engine.getRegistryTable()
		m.table = m.searchCluster.getTable(1)
		m.searchedreg = createobject("RegistryTable", m.table.getPath()+m.table.getPureName()+"_registry.dbf")
		if m.searchedreg.isCreatable() or fdate(m.searchedreg.getDBF(),1) < fdate(m.table.getDBF(),1)
			m.searchedreg.close()
			m.searchedreg.erase()
			m.searchedreg = m.engine.expand(m.searchedreg, m.meta) && meta[type] == 0 will be excluded
		endif
		if not (vartype(m.searchedreg) == "O" and m.searchedreg.isValid())
			this.messenger.errormessage("Unable to create SearchTable Registry.")
			if m.txt
				FileClose(m.handle1)
			endif
			this.erase()
			if vartype(m.searchedreg) == "O"
				m.searchedreg.erase()
			endif
			return .f.
		endif
		m.searchedtypes = createobject("SearchTypes",m.foundtypes.toString())
		m.count = createobject("UniqueAlias",.t.)
		select type, cast(max(occurs) as i) as max from (m.searchedreg.alias) where occurs > 0 group by 1 into cursor (m.count.alias) readwrite
		scan
			m.stype = m.searchedtypes.getSearchTypeByIndex(type)
			m.stype.setMaxOcc(max)
		endscan
		select searched, cast(count(*) as i) as cnt from (m.result.alias) group by 1 into cursor (m.count.alias) readwrite
		index on searched tag searched
		m.tmp = createobject("UniqueAlias",.t.)
		m.ipos = createobject("UniqueAlias",.t.)
		select distinct searched, identity, cast(0 as b) as pos, cast(0 as i) as cnt from (m.result.alias) into cursor (m.tmp.alias) readwrite
		update (m.tmp.alias) set pos = recno()
		select searched, min(pos) as pos, count(*) as cnt from (m.tmp.alias) group by 1 into cursor (m.ipos.alias) readwrite
		index on searched tag searched
		m.sql = "update "+m.tmp.alias+" set pos = ("+m.tmp.alias+".pos-"+m.ipos.alias+".pos+1)/"+m.ipos.alias+".cnt, cnt = "+m.ipos.alias+".cnt from "+m.ipos.alias+" where "+m.tmp.alias+".searched == "+m.ipos.alias+".searched"
		&sql
		select (m.tmp.alias)
		index on searched tag searched
		select a.searched, a.found, b.pos, b.cnt from (m.result.alias) a, (m.tmp.alias) b where a.searched == b.searched and a.identity == b.identity into cursor (m.ipos.alias) readwrite
		index on ltrim(str(searched))+" "+ltrim(str(found)) tag key
		m.tmp.close()
		m.join = m.engine.getSearchFieldJoin()
		dimension m.sx[MAXWORDCOUNT,3]
		dimension m.fx[MAXWORDCOUNT,3]	
		dimension m.mx[MAXWORDCOUNT*2,4]	
		m.entrylen = m.searchedreg.getTableStructure()
		m.entrylen = m.entrylen.getFieldStructure("entry")
		m.entrylen = m.entrylen.getSize()
		m.searchedreg.forceRegistryKey()
		m.base2reg = m.engine.getBase2RegistryCluster()
		dimension m.lexarray[1]
		m.result.select()
		m.searched = -1
		m.found = -1
		m.cnt = 1
		m.icnt = 1
		this.messenger.setDefault("Exported")
		this.messenger.startProgress(m.result.reccount())
		this.messenger.startCancel("Cancel Operation?","Exporting Meta","Canceled.")
		scan
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				exit
			endif
			m.run = asc(run)
			m.identity = identity
			if searched <= 0 or not m.runFilter.isFiltered(m.run) or m.identity < m.low or m.identity >= m.high
				this.messenger.postProgress()
				loop
			endif
			m.found = found
			m.score = score
			m.pos = 0
			if seek(ltrim(str(searched))+" "+ltrim(str(found)),m.ipos.alias)
				m.pos = evaluate(m.ipos.alias+".pos")
				m.icnt = evaluate(m.ipos.alias+".cnt")
			endif
			if searched != m.searched
				m.searched = searched
				if seek(m.searched, m.count.alias)
					m.cnt = evaluate(m.count.alias+".cnt")
				endif
				m.sxcnt = 0
				m.searchCluster.goRecord(m.searched)
				m.table = m.searchCluster.getActiveTable()
				for m.i = 1 to m.join.getJoinCount()
					m.fa = m.join.getA(m.i)
					m.fb = m.join.getB(m.i)
					m.fa = m.fa.getName()
					m.fb = m.fb.getName()
					for m.j = 1 to m.foundtypes.getSearchTypeCount(m.fb)
						m.ftype = m.foundtypes.getSearchTypeByField(m.fb,m.j)
						m.typeindex = m.ftype.getTypeIndex()
						if m.meta.meta[m.typeindex] == 0
							loop
						endif
						m.stype = m.searchedtypes.getSearchTypeByIndex(m.typeindex)
						if alines(m.lexArray,m.ftype.prepare(m.table.getValueAsString(m.fa)),5," ") == 0
							loop
						endif
						m.already = " "
						for m.k = 1 to alen(m.lexarray)
							m.lex = left(m.lexarray[m.k], m.entrylen)
							if not (" "+m.lex+" " $ m.already)
								m.already = m.already+m.lex+" "
								select (m.searchedreg.alias)
								if seek(m.searchedreg.buildRegistryKey(m.typeindex, m.lex))
									m.sxcnt = m.sxcnt+1
									m.sx[m.sxcnt,1] = recno()
									m.sx[m.sxcnt,2] = m.typeindex
									m.sx[m.sxcnt,3] = 1-(occurs-1)/m.stype.getMaxOcc()
									if recno() <= reccount(m.foundreg.alias)
										select (m.foundreg.alias)
										go recno(m.searchedreg.alias)
										m.f = 1-(occurs-1)/m.ftype.getMaxOcc()
										if m.f < m.sx[m.sxcnt,3]
											m.sx[m.sxcnt,3] = m.f
										endif
									endif
								endif
								if m.sxcnt == MAXWORDCOUNT
									exit
								endif
							endif
						endfor
					endfor
				endfor
				asort(m.sx,1,m.sxcnt)
			endif
			m.fxcnt = 0
			m.cluster = 1
			m.index = m.base2reg.index.item(m.cluster)
			m.start = 0
			m.end = reccount(m.index.alias)-1
			do while m.found > m.end
				m.cluster = m.cluster+1
				m.index = m.base2reg.index.item(m.cluster)
				m.start = m.end
				m.end = m.end+reccount(m.index.alias)-1
			enddo
			select (m.index.alias)
			go m.found-m.start
			m.start = index
			skip
			m.end = min(index-1, m.start+MAXWORDCOUNT-1)
			m.target = m.base2reg.target.item(m.cluster)
			for m.i = m.start to m.end
				select (m.target.alias)
				go m.i
				m.fxcnt = m.fxcnt+1
				m.fx[m.fxcnt,1] = target
				select (m.foundreg.alias)
				go m.fx[m.fxcnt,1]
				m.fx[m.fxcnt,2] = type
				m.ftype = m.foundtypes.getSearchTypeByIndex(type)
				m.fx[m.fxcnt,3] = 1-(occurs-1)/m.ftype.getMaxOcc()
			endfor
			m.f = 1
			m.s = 1
			m.mxcnt = 0
			do while m.s <= m.sxcnt or m.f <= m.fxcnt
				m.mxcnt = m.mxcnt+1
				if m.f <= m.fxcnt and (m.s > m.sxcnt or m.fx[m.f,1] < m.sx[m.s,1])
					m.mx[m.mxcnt,1] = "F"
					m.mx[m.mxcnt,2] = m.fx[m.f,2]
					m.mx[m.mxcnt,3] = m.fx[m.f,3]
					m.mx[m.mxcnt,4] = str(m.fx[m.f,2],10,0)+"F"+str(2-m.fx[m.f,3],11,9)
					m.f = m.f+1
					loop
				endif
				if m.s <= m.sxcnt and (m.f > m.fxcnt or m.sx[m.s,1] < m.fx[m.f,1])
					m.mx[m.mxcnt,1] = "S"
					m.mx[m.mxcnt,2] = m.sx[m.s,2]
					m.mx[m.mxcnt,3] = m.sx[m.s,3]
					m.mx[m.mxcnt,4] = str(m.sx[m.s,2],10,0)+"S"+str(2-m.sx[m.s,3],11,9)
					m.s = m.s+1
					loop
				endif
				m.mx[m.mxcnt,1] = "M"
				m.mx[m.mxcnt,2] = m.fx[m.f,2]
				m.mx[m.mxcnt,3] = m.fx[m.f,3]
				m.mx[m.mxcnt,4] = str(m.fx[m.f,2],10,0)+"B"+str(2-m.fx[m.f,3],11,9)
				m.s = m.s+1
				m.f = m.f+1
			enddo
			asort(m.mx,4,m.mxcnt)
			m.line = ltrim(str(m.searched))+chr9+ltrim(str(m.found))+chr9+ltrim(str(m.identity,18,9))+chr9+ltrim(str(m.score,18,9))+chr9+ltrim(str(m.cnt,10))+chr9+ltrim(str(m.icnt,10))+chr9+ltrim(str(m.pos,18,9))
			if m.normalize
				if m.identity < m.norm[3,1]
					m.norm[3,1] = m.identity
				else
					if m.identity > m.norm[3,2]
						m.norm[3,2] = m.identity
					endif
				endif
				if m.score < m.norm[4,1]
					m.norm[4,1] = m.score
				else
					if m.score > m.norm[4,2]
						m.norm[4,2] = m.score
					endif
				endif
				if m.cnt < m.norm[5,1]
					m.norm[5,1] = m.cnt
				else
					if m.cnt > m.norm[5,2]
						m.norm[5,2] = m.cnt
					endif
				endif
				if m.cnt < m.norm[6,1]
					m.norm[6,1] = m.icnt
				else
					if m.cnt > m.norm[6,2]
						m.norm[6,2] = m.icnt
					endif
				endif
			endif
			m.ind = 9   && 7 base fields + run? == 1 + first index
			for m.i = 1 to m.runmax
				if m.i = m.run
					m.line = m.line+chr9+"1"
				else
					if m.runFilter.isFiltered(m.i)
						m.line = m.line+chr9+"0"
						m.ind = m.ind+1    && run? == 1 is already considered
					endif
				endif
			endfor
			if m.normalize
				m.m = 1
				for m.i = 1 to m.foundtypes.getSearchTypeCount()
					for m.j = 1 to 3
						m.f = substr("MFS",m.j,1)
						if not m.f == "S"
							m.type = m.foundtypes.getSearchTypeByIndex(m.i)
						else
							m.type = m.searchedtypes.getSearchTypeByIndex(m.i)
						endif
						m.type = m.type.getMaxOcc()
						for m.k = 1 to m.meta.meta[m.i]
							if m.m <= m.mxcnt and m.mx[m.m,1] == m.f and m.mx[m.m,2] == m.i
								m.val = m.mx[m.m,3]
								m.line = m.line+chr9+ltrim(str(m.val,18,9))
								m.m = m.m+1
							else
								m.val = 0
								m.line = m.line+chr9+"0"
							endif
							if m.val < m.norm[m.ind,1]
								m.norm[m.ind,1] = m.val
							else
								if m.val > m.norm[m.ind,2]
									m.norm[m.ind,2] = m.val
								endif
							endif
							m.ind = m.ind+1
						endfor
						do while m.m <= m.mxcnt and m.mx[m.m,1] == m.f and m.mx[m.m,2] == m.i
							m.m = m.m+1
						enddo
					endfor
				endfor
			else
				m.m = 1
				for m.i = 1 to m.foundtypes.getSearchTypeCount()
					for m.j = 1 to 3
						m.f = substr("MFS",m.j,1)
						if not m.f == "S"
							m.type = m.foundtypes.getSearchTypeByIndex(m.i)
						else
							m.type = m.searchedtypes.getSearchTypeByIndex(m.i)
						endif
						m.type = m.type.getMaxOcc()
						for m.k = 1 to m.meta.meta[m.i]
							if m.m <= m.mxcnt and m.mx[m.m,1] == m.f and m.mx[m.m,2] == m.i
								m.val = m.mx[m.m,3]
								m.line = m.line+chr9+ltrim(str(m.val,18,9))
								m.m = m.m+1
							else
								m.line = m.line+chr9+"0"
							endif
						endfor
						do while m.m <= m.mxcnt and m.mx[m.m,1] == m.f and m.mx[m.m,2] == m.i
							m.m = m.m+1
						enddo
					endfor
				endfor
			endif
			if m.txt
				FileWriteCRLF(m.handle1,m.line)
			else
				m.line = "insert into "+this.alias+" values ("+m.line+")"
				&line
			endif
			this.messenger.postProgress()
		endscan
		if m.txt
			FileClose(m.handle1)
		endif
		if this.messenger.isCanceled()
			return .f.
		endif
		if m.normalize == .f.
			return .t.
		endif
		for m.i = 1 to alen(m.norm,1)
			if m.norm[m.i,1] == 9999999999
				m.norm[m.i,2] = -1
				loop
			endif
			if m.norm[m.i,2] == 0 or (m.norm[m.i,1] == 0 and m.norm[m.i,2] == 1)
				m.norm[m.i,2] = -1
				loop
			endif
			if m.norm[m.i,2] == -1 or m.norm[m.i,1] == m.norm[m.i,2]
				if m.norm[m.i,1] > 0
					m.norm[m.i,1] = m.norm[m.i,1]-1
				endif
				m.norm[m.i,2] = 1
				loop
			endif
			m.norm[m.i,2] = m.norm[m.i,2]-m.norm[m.i,1]
		endfor
		dimension m.lex[1]
		this.messenger.forceMessage("Normalizing...")
		if m.txt
			m.handle1 = FileOpenRead(OUTHANDLE,m.temp.getDBF())
			m.handle2 = FileOpenWrite(EXPORTHANDLE,this.getDBF())
			m.line = FileReadCRLF(m.handle1)
			FileWriteCRLF(m.handle2,m.line)
			m.line = FileReadCRLF(m.handle1)
			do while not (FileEOF(m.handle1) and empty(m.line))
				m.cnt = alines(m.lex,m.line,m.chr9)
				m.line = ""
				for m.i = 1 to m.cnt
					if m.norm[m.i,2] <= 0
						m.val = m.lex[m.i]
					else
						m.val = ltrim(str((val(m.lex[m.i])-m.norm[m.i,1])/m.norm[m.i,2],18,9))
					endif
					if m.val == "0.000000000"
						m.val = "0"
					else
						if m.val == "1.000000000"
							m.val = "1"
						endif
					endif
					m.line = m.line+m.chr9+m.val
				endfor
				FileWriteCRLF(m.handle2,ltrim(m.line,m.chr9))
				m.line = FileReadCRLF(m.handle1)
			enddo
			FileClose(m.handle1)
			FileClose(m.handle2)
		else
			m.struc = this.getTableStructure()
			m.sql = "update "+this.alias+" set "
			for m.i = 1 to alen(m.norm,1)
				if m.norm[m.i,2] <= 0
					loop
				endif
				m.f = m.struc.getFieldStructure(m.i)
				m.sql = m.sql + m.f.getName() + " = (" + m.f.getName() + "-m.norm["+ltrim(str(m.i))+",1])/m.norm["+ltrim(str(m.i))+",2], "
			endfor
			m.sql = rtrim(rtrim(m.sql),",")
			&sql
		endif
		return .t.
	endfunc
enddefine

define class SearchEngine as custom
	hidden engine, baseCluster, registry, result
	hidden reg2base, base2reg
	hidden searchFieldJoin, searchTypes
	hidden searchCluster, ControlTable, limit, threshold, zealous, depth, darwin
	hidden ignorant, messenger, info, relative
	hidden activation, cutoff, lrcpdscope
	hidden baseClusterReady, searchClusterReady, resultTableReady
	hidden searchReady, searchedSynchronized, foundSynchronized
	hidden expanded, expandable, searchedFieldsValid, foundFieldsValid
	hidden changed, slot, feedback, mono
	hidden preparer, preparermsg
	hidden searchTable, baseTable
	hidden logfile, notcaring
	hidden txt
	hidden version
	version = "19.11"
	tag = ""
	notcaring = .f.
	txt = .f.

	protected function init(path, slot)
		local ps, progpath, err
		m.ps = createobject("PreservedSetting","reprocess",1)
		m.path = fullpath(m.path)
		if not inlist(right(m.path,1),"\","/")
			m.path = m.path+"\"
		endif
		this.engine = createobject("EngineTable",m.path+"engine")
		if not this.engine.create()
			this.engine.recreate()
		endif
		if not "\FOXPRO.FLL" $ upper(set("library"))
			messagebox("Library foxpro.fll not installed.",16,"SearchEngine")
			return .f.
		endif
		m.err = .f.
		try
			if FoxproVersion() < 101
				m.err = .t.
			endif
		catch
			m.err = .t.
		endtry
		if m.err
			messagebox("Library foxpro.fll version not supported.",16,"SearchEngine")
			return .f.
		endif
		m.path = this.engine.getPath()
		m.progpath = createobject("ProgramPath")
		m.progpath = m.progpath.toString()
		this.txt = lower(alltrim(this.getConfig("txt"))) == "true"
		this.ControlTable = createobject("ControlTable",m.path+"control")
		this.registry = createobject("RegistryTable",m.path+"registry")
		this.reg2base = createobject("IndexCluster",m.path+"regindex",m.path+"base")
		this.reg2base.switchTargetToFile()
		this.base2reg = createobject("IndexCluster",m.path+"baseindex",m.path+"reg")
		this.result = createobject("ResultTable")
		this.baseCluster = createobject("TableCluster")
		this.searchCluster = createobject("TableCluster")
		this.baseTable = createobject("BaseTable")
		this.searchTable = createobject("BaseTable")
		this.searchTypes = createobject("SearchTypes")
		this.searchFieldJoin = createobject("TableStructureJoin")
		this.logfile = m.path+"SearchEngine.log"
		if file(m.path+"SearchEngine.xml",1)
			this.preparer = createobject("Preparer",m.path+"SearchEngine.xml")
		else
			if not file(m.progpath+"SearchEngine.xml",1)
				this.preparer = createobject("Preparer")
			else
				this.preparer = createobject("Preparer",m.progpath+"SearchEngine.xml")
			endif
		endif
		this.messenger = createobject("Messenger")
		this.messenger.setInterval(2)
		this.ControlTable.setMessenger(this.messenger)
		this.registry.setMessenger(this.messenger)
		this.reg2base.setMessenger(this.messenger)
		this.base2reg.setMessenger(this.messenger)
		this.preparermsg = ""
		this.loadEngine(m.slot)
	endfunc
	
	function getVersion()
		return this.version
	endfunc
	
	function isTxtDefault()
		return this.txt
	endfunc
	
	function setTxtDefault(txt)
		this.txt = m.txt
	endfunc

	function getTmpPath()
		return sys(2023)
	endfunc
	
	function getMaxSearchDepth()
		return MAXSEARCHDEPTH
	endfunc

	function getDefaultSearchDepth()
		return DEFSEARCHDEPTH
	endfunc

	function getWordCount()
		return MAXWORDCOUNT
	endfunc

	function setKey(table, key)
		local ok
		if not m.table.hasField(m.key)
			return .f.
		endif
		if (m.table = this.baseTable)	
			if this.baseCluster.callAnd("forceKey('"+m.key+"')")
				return .t.
			endif
		else
			if (m.table = this.searchTable)		
				if this.searchCluster.callAnd("forceKey('"+m.key+"')")
					return .t.
				endif
			else
				if m.table.setKey(m.key)
					return .t.
				endif
			endif
		endif
		m.ok = .f.
		if (m.table = this.baseTable or m.table == this.searchTable)
			if (this.ismono())
				this.searchCluster.call("close()")
				m.ok = this.baseCluster.callAnd("forceKey('"+m.key+"')")
				this.searchCluster.call("open()")
				this.searchCluster.call("setKey('"+m.key+"')")
			else
				if m.table == this.SearchTable
					m.ok = this.searchCluster.callAnd("forceKey('"+m.key+"')")
				else
					m.ok = this.baseCluster.callAnd("forceKey('"+m.key+"')")
				endif
			endif						
		else
			m.ok = m.table.forceKey(m.key)
		endif
		return m.ok
	endfunc

	function setMessenger(messenger)
		this.messenger = m.messenger
	endfunc

	function getMessenger()
		return this.messenger
	endfunc

	function getControlTable()
		return this.controlTable
	endfunc

	function getRegistry2BaseCluster()
		return this.reg2base
	endfunc

	function getBase2RegistryCluster()
		return this.base2reg
	endfunc

	function getRegistryTable()
		return this.registry
	endfunc

	function getEngineTable()
		return this.engine
	endfunc

	function getEnginePath()
		return this.engine.getPath()
	endfunc

	function getSlot()
		return this.slot
	endfunc

	function setLimit(limit)
		this.limit = min(max(m.limit,0),100)
		this.threshold = this.limit-TOLERANCE
	endfunc

	function getLimit()
		return this.limit
	endfunc
	
	function setThreshold(threshold)
		this.setLimit(m.threshold)
	endfunc
	
	function getThreshold()
		return this.getLimit()
	endfunc	

	function setDepth(depth)
		this.depth = min(max(m.depth,0),MAXSEARCHDEPTH)
	endfunc
	
	function getDepth()
		return this.depth
	endfunc
	
	function setDarwinistic(darwin)
		this.darwin = m.darwin
	endfunc

	function isDarwinistic()
		return this.darwin
	endfunc

	function isExpanded()
		return this.expanded
	endfunc

	function setRelative(relative)
		this.relative = m.relative
	endfunc

	function isRelative()
		return this.relative
	endfunc

	function setIgnorant(ignorant)
		this.ignorant = m.ignorant
	endfunc

	function isIgnorant()
		return this.ignorant
	endfunc

	function setZealous(zealous)
		this.zealous = m.zealous
	endfunc

	function isZealous()
		return this.Zealous
	endfunc

	function setFeedback(fb)
		this.feedback = max(m.fb,0)
	endfunc

	function getFeedback()
		return this.feedback
	endfunc

	function setCutoff(co)
		this.cutoff = int(max(m.co,0))
	endfunc

	function getCutoff()
		return this.cutoff
	endfunc

	function setActivation(act)
		this.activation = int(max(m.act,0))
	endfunc

	function getActivation()
		return this.activation
	endfunc

	function setLrcpdScope(scope)
		this.lrcpdscope = int(max(m.scope,0))
	endfunc

	function getLrcpdScope()
		return this.lrcpdscope
	endfunc

	function setInfo(info)
		this.info = alltrim(m.info)
	endfunc

	function getInfo()
		return this.info
	endfunc

	function setOffset(type, offset, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		m.searchType.setOffset(m.offset)
	endfunc

	function getOffset(type, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		return m.searchType.getOffset()
	endfunc

	function setSoftmax(type, softmax, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		m.searchType.setSoftmax(m.softmax)
	endfunc

	function getSoftmax(type, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		return m.searchType.getSoftmax()
	endfunc

	function setLog(type, log, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		m.searchType.setLog(m.log)
	endfunc

	function getLog(type, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		return m.searchType.getLog()
	endfunc

	function setPriority(type, prio, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		m.searchType.setPriority(m.prio)
		this.searchTypes.recalculateShares()
	endfunc

	function getPriority(type, index)
	local searchType
		m.searchType = this.searchTypes.getSearchType(m.type,m.index)
		return m.searchType.getPriority()
	endfunc
	
	function mergeSearchTypes(searchtypes)
		if not vartype(m.searchTypes) == "O"
			m.searchTypes = createobject("SearchTypes",m.searchTypes)
		endif
		this.searchTypes.mergeSearchTypeData(m.searchtypes)
		this.searchTypes.recalculateShares()
	endfunc

	function getSearchTypes()
		return this.searchTypes
	endfunc

	function getPreparer()
		return this.preparer
	endfunc
	
		
	function setBaseCluster(bc)
		this.baseCluster = m.bc
		this.syncBaseCluster()
	endfunc		

	function setBaseTable(bt, maxTableCount)
		if not vartype(m.maxTableCount) == "N"
			m.maxTableCount = 1
		endif
		if vartype(m.bt) == "C"
			this.baseCluster = createobject("TableCluster",m.bt, m.maxTableCount, .t.)
		else
			if vartype(m.bt) == "O"
				this.baseCluster = createobject("TableCluster",m.bt.getDBF(), m.maxTableCount, .t.)
			else
				this.baseCluster = createobject("TableCluster")
			endif
		endif
		this.syncBaseCluster()
	endfunc
	
	hidden function syncBaseCluster()
		local oldjoin, fa, fb, strucA, strucB, i
		if this.baseCluster.getTableCount() > 0
			this.baseTable = this.BaseCluster.getTable(1)
		else
			this.baseTable = createobject("BaseTable")
		endif
		m.strucB = this.searchFieldJoin.getTableStructureB()
		m.strucB = m.strucB.recast(this.baseCluster.getTableStructure())
		m.strucA = this.searchFieldJoin.getTableStructureA()
		m.oldjoin = this.searchFieldJoin
		this.searchFieldJoin = createobject("TableStructureJoin",m.strucA, m.strucB)
		if m.oldjoin.isValid()
			for m.i = 1 to m.oldjoin.getJoinCount()
				m.fa = m.oldjoin.getA(m.i)
				m.fb = m.oldjoin.getB(m.i)
				this.joinSearchField(m.fa.getName(),m.fb.getName())
			endfor
		endif
		this.changed = .t.
	endfunc
	
	function getBaseTable()
		return this.baseTable
	endfunc

	function getBaseCluster()
		return this.baseCluster
	endfunc

	function isBaseTableReady()
		this.confirmChanges()
		return this.baseClusterReady
	endfunc
	
	function isBaseTableValid()
		return this.baseCluster.callAnd("isValid()")
	endfunc

	hidden function checkBaseClusterReady()
	local struc, f, types, i
		this.baseClusterReady = .f.
		if not this.baseCluster.callAnd("isValid()")
			return .f.
		endif
		m.struc = this.baseTable.getTableStructure()
		m.types = this.searchFieldJoin.getTableStructureB()
		for m.i = 1 to m.types.getFieldCount()
			m.f = m.types.getFieldStructure(m.i)
			if m.struc.getFieldIndex(m.f.getName()) < 1
				return .f.
			endif
		endfor
		this.baseClusterReady = .t.
		return .t.
	endfunc

	function setSearchCluster(sc)
		this.searchCluster = m.sc
		this.syncsearchCluster()
	endfunc		

	function setSearchTable(st, maxTableCount)
		if not vartype(m.maxTableCount) == "N"
			m.maxTableCount = 1
		endif
		if vartype(m.st) == "C"
			this.searchCluster = createobject("TableCluster",m.st,m.maxTableCount,.t.)
		else
			if vartype(m.st) == "O"
				this.searchCluster = createobject("TableCluster",m.st.getDBF(),m.maxTableCount,.t.)
			else
				this.searchCluster = createobject("TableCluster")
			endif
		endif
		this.syncSearchCluster()
	endfunc
	
	hidden function syncSearchCluster()
		local oldjoin, fa, fb, strucA, strucB, i
		if this.searchCluster.getTableCount() > 0
			this.searchTable = this.searchCluster.getTable(1)
		else
			this.searchTable = createobject("BaseTable")
		endif
		m.strucA = this.searchCluster.getTableStructure()
		m.strucB = this.searchFieldJoin.getTableStructureB()
		m.oldjoin = this.searchFieldJoin
		this.searchFieldJoin = createobject("TableStructureJoin",m.strucA, m.strucB)
		if m.oldjoin.isValid()
			for m.i = 1 to m.oldjoin.getJoinCount()
				m.fa = m.oldjoin.getA(m.i)
				m.fb = m.oldjoin.getB(m.i)
				this.joinSearchField(m.fa.getName(),m.fb.getName())
			endfor
		endif
		this.changed = .t.
	endfunc

	function getSearchTable()
		return this.searchTable
	endfunc
	
	function getSearchCluster()
		return this.searchCluster
	endfunc
	
	function isSearchTableReady()
		this.confirmChanges()
		return this.searchClusterReady
	endfunc

	hidden function checkSearchClusterReady()
		this.searchClusterReady = this.searchCluster.callAnd("isValid()")
		return this.searchClusterReady
	endfunc

	function setResultTable(rt)
		if vartype(m.rt) == "C"
			this.result = createobject("ResultTable",m.rt)
		else
			this.result = createobject("ResultTable",m.rt.getDBF())
		endif
		this.result.useShared()
		this.changed = .t.
	endfunc

	function getResultTable()
		return this.result
	endfunc

	function isResultTableReady()
		this.confirmChanges()
		return this.resultTableReady
	endfunc

	hidden function checkResultTableReady()
	local s, pos
		if this.result.hasValidAlias()
			this.resultTableReady = .f.
			m.s = this.result.getRequiredTableStructure()
			if not m.s.checkNames(this.result)
				return .f.
			endif
			m.pos = this.result.getPosition()
			if not this.result.useExclusive()
				this.result.setPosition(m.pos)
				return .f.
			endif
			this.result.useShared()
			this.result.setPosition(m.pos)
			this.resultTableReady = .t.
			return .t.
		endif
		this.resultTableReady = this.result.isCreatable()
		return this.resultTableReady
	endfunc

	function isResultTableValid()
		return this.result.isFunctional()
	endfunc
	
	function isMono()
		this.confirmChanges()
		return this.mono
	endfunc

	hidden function testMono()
		local fa, fb, i
		this.mono = .f.
		if not this.isSearchedSynchronized() or not this.isFoundSynchronized()
			return .f.
		endif
		if not this.searchTable.getDBF() == this.baseTable.getDBF()
			return .f.
		endif
		if not this.searchCluster.getTableCount() == this.baseCluster.getTableCount()
			return .f.
		endif
		for m.i = 1 to this.searchFieldJoin.getJoinCount()
			m.fa = this.searchFieldJoin.getA(m.i)
			m.fb = this.searchFieldJoin.getb(m.i)
			if not m.fa.getName() == m.fb.getName()
				return .f.
			endif
		endfor
		this.mono = .t.
		return .t.
	endfunc

	function joinSearchField(field, searchField)
		local rc
		if vartype(m.searchField) == "C"
			m.rc = this.searchFieldJoin.join(m.field,m.searchField)
		else
			m.rc = this.searchFieldJoin.join(m.field,m.field)
		endif
		if m.rc
			this.changed = .t.
		endif
		return m.rc
	endfunc

	function unjoinSearchField(field, searchField)
		local rc
		if vartype(m.searchField) == "C"
			m.rc = this.searchFieldJoin.unjoin(m.field,m.searchField)
		else
			if vartype(m.field) == "C"
				m.rc = this.searchFieldJoin.unjoinA(m.field)
			else
				m.rc = this.searchFieldJoin.unjoin()
			endif
		endif
		if m.rc
			this.changed = .t.
		endif
		return m.rc
	endfunc
	
	function autoJoinSearchFields()
	local struc, i, rc, f
		m.rc = .t.
		m.struc = this.searchTypes.getSearchFieldsAsTableStructure()
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if this.joinSearchField(m.f.getName())
				this.changed = .t.
			else
				m.rc = .f.
			endif
		endfor
		return m.rc and m.i > 1
	endfunc
	
	function getActiveJoin(destructiveMode as Integer)
	local activeJoin, joinCount, i, searchTypes, field, searchtype
		if not vartype(m.destructiveMode) == "N" or m.destructiveMode == 0
			m.searchTypes = this.searchTypes.consolidateByFields(.t.)
		else
			if m.destructiveMode > 0
				m.searchTypes = this.searchTypes.filterByDestructive(.f.,.t.)
			else
				m.searchTypes = this.searchTypes.filterByDestructive(.t.,.t.)
			endif
		endif
		m.activeJoin = this.searchFieldJoin.copy()
		m.joinCount = m.activeJoin.getJoinCount()
		m.searchTypes = m.searchTypes.consolidateByFields(.t.)
		m.i = 1
		do while m.i <= m.joinCount
			m.field = m.activeJoin.getB(m.i)
			m.searchType = m.searchTypes.getSearchTypeByField(m.field.getName(),1)
			if m.searchType.getPriority() <= 0
				m.activeJoin.unjoinB(m.field.getName())
				m.joinCount = m.activeJoin.getJoinCount()
			else
				m.i = m.i+1
			endif
		enddo
		return m.activeJoin
	endfunc

	function getSearchFieldJoin()
		return this.searchFieldJoin
	endfunc

	function isValid()
		return this.controlTable.isValid() and this.reg2base.isValid() and this.base2reg.isValid() and this.registry.isValid()
	endfunc

	function isCreatable()
		return this.baseCluster.callAnd("hasValidAlias()") and this.ControlTable.isCreatable() and this.base2reg.isCreatable() and this.reg2base.isCreatable() and this.registry.isCreatable()
	endfunc

	function isSearchReady()
		this.confirmChanges()
		return this.searchReady
	endfunc

	hidden function testSearchReady()
		this.searchReady = .f.
		if not this.isValid() or not this.isSearchTableReady()
			return .f.
		endif
		this.searchReady = this.areSearchedFieldsValid()
		return this.searchReady
	endfunc

	function isExpandable()
		this.confirmChanges()
		return this.expandable
	endfunc

	hidden function testExpandable()
		this.expandable = .f.
		if not this.isValid() or not this.isSearchTableReady()
			return .f.
		endif
		this.expandable = this.areSearchedFieldsValid()
		return this.expandable
	endfunc

	function isSearchedSynchronized()
		this.confirmChanges()
		return this.searchedSynchronized
	endfunc

	hidden function testSearchedSynchronized()
		this.searchedSynchronized = .f.
		if not this.isResultTableValid()
			return .f.
		endif
		this.searchedSynchronized = this.areSearchedFieldsValid()
		return this.searchedSynchronized
	endfunc

	function isFoundSynchronized()
		this.confirmChanges()
		return this.foundSynchronized
	endfunc

	hidden function testFoundSynchronized()
		this.foundSynchronized = .f.
		if not this.isResultTableValid()
			return .f.
		endif
		this.foundSynchronized = this.areFoundFieldsValid()
		return this.foundSynchronized
	endfunc

	function areSearchedFieldsValid()
		this.confirmChanges()
		return this.searchedFieldsValid
	endfunc

	hidden function checksearchedFieldsValid()
		local i, f1
		this.searchedFieldsValid = .f.
		if this.searchFieldJoin.getJoinCount() < 1
			return .f.
		endif
		for m.i = 1 to this.searchFieldJoin.getJoinCount()
			m.f1 = this.searchFieldJoin.getA(m.i)
			if not this.searchTable.hasField(m.f1.getName())
				return .f.
			endif
		endfor
		this.searchedFieldsValid = .t.
		return .t.
	endfunc

	function areFoundFieldsValid()
		this.confirmChanges()
		return this.foundFieldsValid
	endfunc

	hidden function checkfoundFieldsValid()
		local i, f1
		this.foundFieldsValid = .f.
		if this.searchFieldJoin.getJoinCount() < 1
			return .f.
		endif
		for m.i = 1 to this.searchFieldJoin.getJoinCount()
			m.f1 = this.searchFieldJoin.getB(m.i)
			if not this.baseTable.hasField(m.f1.getName())
				return .f.
			endif
		endfor
		this.foundFieldsValid = .t.
		return .t.
	endfunc

	hidden function confirmChanges()
		if not this.changed
			return
		endif
		this.changed = .f.
		this.checkBaseClusterReady()
		this.checkSearchClusterReady()
		this.checkResultTableReady()
		this.checksearchedFieldsValid()
		this.checkfoundFieldsValid()
		this.testSearchedSynchronized()
		this.testFoundSynchronized()
		this.testExpandable()
		this.testMono()
		this.testSearchReady()
	endfunc

	function synchronize()
		this.changed = .t.
		this.confirmChanges()
	endfunc

	function getSearchedText()
		if not this.isSearchedSynchronized()
			return ""
		endif
		if not this.searchCluster.goRecord(this.result.getValue("searched"))
			return ""
		endif
		return this.extractSearchedText()
	endfunc

	function extractSearchedText()
	local txt, str, i, searchTable, f
		m.txt = ""
		m.searchTable = this.searchCluster.getActiveTable()
		for m.i = 1 to this.searchFieldJoin.getJoinCount()
			m.f = this.searchFieldJoin.getA(m.i)
			m.str = strtran(alltrim(m.searchTable.getValueAsString(m.f.getName())),"|"," ")
			if not empty(m.str)
				m.txt = m.txt+m.str+" | "
			else
				m.txt = m.txt+"| "
			endif
		endfor
		return left(m.txt,len(m.txt)-3)
	endfunc

	function getFoundText()
		if not this.isFoundSynchronized()
			return ""
		endif
		if not this.baseCluster.goRecord(this.result.getValue("found"))
			return ""
		endif
		return this.extractFoundText()
	endfunc

	function extractFoundText()
	local txt, str, i, baseTable, f
		m.txt = ""
		m.baseTable = this.baseCluster.getActiveTable()
		for m.i = 1 to this.searchFieldJoin.getJoinCount()
			m.f = this.searchFieldJoin.getb(m.i)
			m.str = strtran(alltrim(m.baseTable.getValueAsString(m.f.getName())),"|"," ")
			if not empty(m.str)
				m.txt = m.txt+m.str+" | "
			else
				m.txt = m.txt+"| "
			endif
		endfor
		return left(m.txt,len(m.txt)-3)
	endfunc

	function getSearchedHeuristics()
		return this.getHeuristics(.f.)
	endfunc

	function getFoundHeuristics()
		return this.getHeuristics(.t.)
	endfunc

	function toString()
		local str
		this.confirmChanges()
		m.str = "[Engine]"+chr(10)
		m.str = m.str+"Class: "+proper(this.class)+chr(10)
		m.str = m.str+"Version: "+this.getVersion()+chr(10)
		m.str = m.str+"EnginePath: "+lower(this.engine.getPath())+chr(10)
		m.str = m.str+"Slot: "+this.getSlot()+chr(10)
		m.str = m.str+"Flags: "
		m.str = m.str+iif(this.isValid(),"valid, ","")
		m.str = m.str+iif(this.isCreatable(),"creatable, ","")
		m.str = m.str+iif(this.isDarwinistic(),"darwinistic, ","")
		m.str = m.str+iif(this.isRelative(),"relative, ","")
		m.str = m.str+iif(this.isIgnorant(),"ignorant, ","")
		m.str = m.str+iif(this.isZealous(),"zealous, ","")
		m.str = m.str+iif(this.isMono(),"mono, ","")
		m.str = m.str+iif(this.isExpanded(),"expanded, ","")
		if right(m.str,2) == ", "
			m.str = left(m.str,len(m.str)-2)
		else
			m.str = m.str+"none"
		endif
		m.str = m.str+chr(10)
		m.str = m.str+"Synchronized: "
		m.str = m.str+iif(this.isSearchedSynchronized(),"searched, ","")
		m.str = m.str+iif(this.isFoundSynchronized(),"found, ","")
		if right(m.str,2) == ", "
			m.str = left(m.str,len(m.str)-2)
		else
			m.str = m.str+"none"
		endif
		m.str = m.str+chr(10)
		m.str = m.str+"Ready: "
		m.str = m.str+iif(this.isSearchReady(),"Search, ","")
		m.str = m.str+iif(this.isBaseTableReady(),"BaseTable, ","")
		m.str = m.str+iif(this.isSearchTableReady(),"SearchTable, ","")
		m.str = m.str+iif(this.isResultTableReady(),"ResultTable, ","")
		if right(m.str,2) == ", "
			m.str = left(m.str,len(m.str)-2)
		else
			m.str = m.str+"none"
		endif
		m.str = m.str+chr(10)
		if this.searchTypes.isValid()
			m.str = m.str+"Types: "+this.searchTypes.toString()+chr(10)
		endif
		if this.depth > 0 and this.depth != DEFSEARCHDEPTH
			m.str = m.str+"Depth: "+ltrim(str(this.depth,18))+chr(10)
		endif
		if this.limit > 0 and this.limit <= 100
			m.str = m.str+"Limit: "+ltrim(str(this.limit,6,2))+"%"+chr(10)
		endif
		if this.cutoff > 0
			m.str = m.str+"Cutoff: "+ltrim(str(this.cutoff,18))+chr(10)
		endif
		if this.feedback > 0
			m.str = m.str+"Feedback: "+ltrim(str(this.feedback,14,2))+"%"+chr(10)
		endif
		if this.activation > 0
			m.str = m.str+"Activation: "+ltrim(str(this.activation,18))+chr(10)
		endif
		if this.lrcpdscope != DEFLRCPDSCOPE
			m.str = m.str+"LrcpdScope: "+ltrim(str(this.lrcpdscope,18))+chr(10)
		endif
		if not (empty(this.preparer.xmlerror) and empty(this.preparermsg))
			m.str = m.str+"PreparerMessage: "+chr(10)
			if not empty(this.preparer.xmlerror)
				m.str = m.str+this.preparer.xmlerror+chr(10)
			endif
			if not empty(this.preparermsg)
				m.str = m.str+this.preparermsg+chr(10)
			endif
		endif
		m.str = m.str+chr(10)+"[ResultTable]"+chr(10)
		m.str = m.str+this.result.toString()
		m.str = m.str+chr(10)+"[BaseTable]"+chr(10)
		m.str = m.str+this.baseCluster.toString()
		m.str = m.str+chr(10)+"[SearchTable]"+chr(10)
		m.str = m.str+this.searchCluster.toString()
		if this.searchFieldJoin.getJoinCount() > 0
			m.str = m.str+"SearchFieldJoin: "+proper(this.searchFieldJoin.toString())+chr(10)
		endif
		if !empty(this.info)
			m.str = m.str+chr(10)+"[Info]"+chr(10)+this.info+chr(10)
		endif
		return m.str
	endfunc

	function erase()
		this.changed = .t.
		this.expanded = .f.
		this.registry.erase()
		this.reg2base.erase()
		this.base2reg.erase()
		this.ControlTable.erase()
		this.searchFieldJoin = createobject("TableStructureJoin")
		if this.ControlTable.exists() or this.registry.exists()
			this.messenger.errorMessage("Unable to erase the engine.")
			return .f.
		endif
		return .t.
	endfunc

	function removeEngine(slot)
		if not vartype(m.slot) == "C" or empty(m.slot) or m.slot == "Default"
			return .f.
		endif
		if not this.engine.remove(m.slot)
			this.messenger.errorMessage("Unable to remove engine slot.")
			return .f.
		endif
		return .t.
	endfunc
	
	function save(slot)
		return this.saveEngine(m.slot)
	endfunc

	function saveEngine(slot)
		if vartype(m.slot) == "L" 
			if m.slot == .t.
				return this.engine.save(this.toString(),"Default",.t.)
			endif
			m.slot = ""
		endif
		if empty(m.slot)
			m.slot = this.slot
		endif
		if empty(m.slot)
			return this.engine.save(this.toString(),"Default")
		endif
		this.slot = alltrim(m.slot)
		if not this.engine.save(this.toString(),this.slot)
			this.messenger.errorMessage("Unable to save engine slot.")
			return .f.
		endif
		return .t.
	endfunc
	
	function loadEngine(slot)
	local str, lex, lax, lux, ps, l, path
	local lineCount, line, invalid, rc
		m.ps = createobject("PreservedSetting","reprocess",1)
		m.path = this.engine.getPath()
		this.limit = 90
		this.zealous = .f.
		this.depth = 0
		this.relative = .f.
		this.darwin = .f.
		this.ignorant = .f.
		this.feedback = 0
		this.activation = 0
		this.cutoff = 0
		this.info = ""
		this.expanded = .f.
		this.changed = .t.
		this.lrcpdscope = 12
		m.rc = .t.
		m.str = this.engine.load("Default")
		if not empty(m.str)
			m.str = createobject("String",m.str)
			m.lineCount = m.str.getLineCount()
			for m.l = 1 to m.lineCount
				m.line = m.str.getLine(m.l)
				do case
					case upper(left(m.line,6)) == "TYPES:"
						this.searchTypes = createobject("SearchTypes",ltrim(substr(m.line,7)),this.preparer)
						this.searchTypes.recalculateShares()
						this.searchFieldJoin = createobject("TableStructureJoin",this.SearchTable.getTableStructure(),this.searchTypes.getSearchFieldsAsTableStructure())
						m.invalid = this.searchTypes.getInvalidPreparer()
						if not empty(m.invalid)
							if not empty(this.preparermsg)
								this.preparermsg = this.preparermsg+chr(10)
							endif
							this.preparermsg = this.preparermsg+"Invalid Preparer: "+strtran(m.invalid," ",", ")
						endif
					case upper(left(m.line,6)) == "FLAGS:"
						m.line = strtran(m.line,","," ")
						m.line = m.line+" "
						if " expanded " $ m.line
							this.expanded = .t.
						endif
					case like("[BaseTable]*",m.line) or like("[ResultTable]*",m.line) or like("[SearchTable]*",m.line)
						exit
				endcase
			endfor
		endif
		if not vartype(m.slot) == "C" or empty(m.slot)
			m.slot = this.engine.getActualSlot()
		endif
		m.str = this.engine.load(m.slot)
		if empty(m.str)
			m.rc = .f.
			this.messenger.errorMessage("Engine slot does not exists.")
			m.slot = this.engine.getActualSlot()
			m.str = this.engine.load(m.slot)
		endif
		this.slot = alltrim(m.slot)
		if not empty(m.str)
			m.str = createobject("String",m.str)
			m.lineCount = m.str.getLineCount()
			for m.l = 1 to m.lineCount
				m.line = m.str.getLine(m.l)
				if upper(left(m.line,6)) == "TYPES:"
					this.searchTypes.mergeSearchTypeData(alltrim(substr(m.line,7)))
					this.searchTypes.recalculateShares()
					this.searchFieldJoin = createobject("TableStructureJoin",this.SearchTable.getTableStructure(),this.searchTypes.getSearchFieldsAsTableStructure())
					exit
				endif
			endfor
			m.str.blankPattern(";,="+chr(9))
			m.str.startLexem(" ")
			m.lex = m.str.getLexem()
			do while not m.str.endOfLexem()
				m.lex = upper(m.lex)
				m.lax = upper(m.str.viewLexem())
				do case
					case m.lex == "[BASETABLE]"
						m.lux = 1
						m.lex = upper(m.str.getLexem(3))
						if m.lex = "TABLECOUNT:"
							m.lux = max(val(m.str.getLexem()),1)
							m.lex = upper(m.str.getLexem())
						endif
						if m.lex == "ALIAS:"
							m.lex = upper(m.str.getLexem(2))
						endif
						if m.lex == "DBF:"
							m.lax = ""
							m.lex = m.str.getLexem()
							do while not m.str.getLexemLineChange() and not m.str.endOfLexem()
								m.lax = m.lax+m.lex+" "
								m.lex = m.str.getLexem()
							enddo
							if not empty(m.lax)
								this.setBaseTable(m.lax,m.lux)
							endif
						endif
					case m.lex == "[RESULTTABLE]"
						m.lex = upper(m.str.getLexem(3))
						if m.lex == "ALIAS:"
							m.lex = upper(m.str.getLexem(2))
						endif
						if m.lex == "DBF:"
							m.lax = ""
							m.lex = m.str.getLexem()
							do while not m.str.getLexemLineChange() and not m.str.endOfLexem()
								m.lax = m.lax+m.lex+" "
								m.lex = m.str.getLexem()
							enddo
							if not empty(m.lax)
								this.setResultTable(m.lax)
								m.lex = m.str.getLexem()
							endif
						endif
					case m.lex == "[SEARCHTABLE]"
						m.lux = 1
						m.lex = upper(m.str.getLexem(3))
						if m.lex = "TABLECOUNT:"
							m.lux = max(val(m.str.getLexem()),1)
							m.lex = upper(m.str.getLexem())
						endif
						if m.lex == "ALIAS:"
							m.lex = upper(m.str.getLexem(2))
						endif
						if m.lex == "DBF:"
							m.lax = ""
							m.lex = m.str.getLexem()
							do while not m.str.getLexemLineChange() and not m.str.endOfLexem()
								m.lax = m.lax+m.lex+" "
								m.lex = m.str.getLexem()
							enddo
							if not empty(m.lax)
								this.setSearchTable(m.lax,m.lux)
							endif
						endif
					case m.lex == "SEARCHFIELDJOIN:" or m.lex == "SEARCHFIELDS:"
						m.lex = m.str.getLexem()
						m.lax = m.str.viewLexem()
						do while not m.str.endOfLexem() and not m.str.getLexemLineChange()
							this.joinSearchField(m.lex,m.lax)
							m.lex = m.str.getLexem(2)
							m.lax = m.str.viewLexem()
						enddo
					case m.lex == "LIMIT:"
						m.lex = m.str.getLexem()
						if isdigit(m.lex)
							this.setLimit(val(m.lex))
							m.lex = m.str.getLexem()
						endif
					case m.lex == "DEPTH:"
						m.lex = m.str.getLexem()
						if isdigit(m.lex)
							this.setDepth(val(m.lex))
							m.lex = m.str.getLexem()
						endif
					case m.lex == "FEEDBACK:"
						m.lex = m.str.getLexem()
						if isdigit(m.lex)
							this.setFeedback(val(m.lex))
							m.lex = m.str.getLexem()
						endif
					case m.lex == "CUTOFF:"
						m.lex = m.str.getLexem()
						if isdigit(m.lex)
							this.setCutoff(val(m.lex))
							m.lex = m.str.getLexem()
						endif
					case m.lex == "ACTIVATION:"
						m.lex = m.str.getLexem()
						if isdigit(m.lex)
							this.setActivation(val(m.lex))
							m.lex = m.str.getLexem()
						endif
					case m.lex == "LRCPDSCOPE:"
						m.lex = m.str.getLexem()
						if isdigit(m.lex)
							this.setLrcpdScope(val(m.lex))
							m.lex = m.str.getLexem()
						endif
					case m.lex == "FLAGS:"
						m.lex = m.str.getLexem()
						do while not m.str.getLexemLineChange() and not m.str.endOfLexem()
							do case
								case m.lex == "darwinistic"
									this.setDarwinistic(.t.)
								case m.lex == "relative"
									this.setRelative(.t.)
								case m.lex == "ignorant"
									this.setIgnorant(.t.)
								case m.lex == "zealous"
									this.setZealous(.t.)
							endcase
							m.lex = m.str.getLexem()
						enddo
					case m.lex == "INFO:" or m.lex == "[INFO]"
						m.lex = m.str.getLexem()
						this.setInfo(m.lex+m.str.getLexemRemainder())
					otherwise
						m.lex = m.str.getLexem()
				endcase
			enddo
		endif
		this.controlTable.refreshOccurrences(this.searchTypes)
		if empty(this.result.getDBF())
			this.setResultTable(m.path+"result")
		endif
		this.confirmChanges()
		return m.rc
	endfunc

	function export(table, searchKey, foundKey, low, high, exclusive, runFilter, text)
		local oldmes, rc, dp
		if vartype(m.table) == "C"
			m.table = createobject("ExportTable",this.properExt(m.table))
		endif
		m.dp = createobject("DynaPara")
		m.dp.dyna("OCCNNLCL")
		m.dp.dyna("O")
		m.dp.dyna("OCC")
		m.dp.dyna("OCCNN")
		m.dp.dyna("ONN","1,4,5,6,7,8")
		m.dp.dyna("ONNCL","1,4,5,7,8")
		m.dp.dyna("ONNLCL","1,4,5,6,7,8")
		m.dp.dyna("OC","1,7,8")
		m.dp.dyna("OCCNNCL","1,2,3,4,5,7,8")
		m.dp.dyna("OCCCL","1,2,3,7,8")
		m.dp.dyna("OT","1,8")
		m.dp.dyna("OCCT","1,2,3,8")
		m.dp.dyna("ONNLT","1,4,5,6,8")
		m.dp.dyna("OCCNNLT","1,2,3,4,5,6,8")
		if m.dp.para(@m.table, @m.searchKey, @m.foundKey, @m.low, @m.high, @m.exclusive, @m.runFilter, @m.text) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		m.oldmes = m.table.getMessenger()
		m.table.setMessenger(this.getMessenger())
		try
			m.rc = m.table.create(this, m.searchKey, m.foundKey, m.low, m.high, m.exclusive, m.runFilter, m.text)
		catch
			m.rc = .f.
		endtry
		m.table.setMessenger(m.oldmes)
		return m.rc
	endfunc

 	function extendedExport(table, searchKey, foundKey, searchedGroupKey, foundGroupKey, low, high, exclusive, runFilter)
		local oldmes, exp, rc, idc, dp
		if vartype(m.table) == "C"
			m.table = createobject("ExtendedExportTable",this.properExt(m.table))
		endif
		if not m.table.isCreatable()
			if not this.idontcare(.t.)
				this.messenger.errorMessage("Unable to create ExtendedExportTable.")
				return .f.
			endif
		else
			if not m.table.pseudoCreate()
				this.messenger.errorMessage("Unable to create ExtendedExportTable.")
				return .f.
			endif
		endif
		m.exp = createobject("BaseCursor")
		if not m.exp.isValid()
			return .f.
		endif
		m.dp = createobject("DynaPara")
		m.dp.dyna("OCCCCNNLC")
		m.dp.dyna("O")
		m.dp.dyna("OCC")
		m.dp.dyna("OCCCC")
		m.dp.dyna("ONNLC","1,6,7,8,9")
		m.dp.dyna("ONNC","1,6,7,9,8")
		m.dp.dyna("ONNL","1,6,7,8,9")
		m.dp.dyna("OC","1,9")
		m.dp.dyna("OCCNNLC","1,2,3,6,7,8,9")
		m.dp.dyna("OCCNNC","1,2,3,6,7,9,8")
		m.dp.dyna("OCCNNL","1,2,3,6,7,8,9")
		m.dp.dyna("OCCC","1,2,3,9")
		m.dp.dyna("OCCCCNNL","1,2,3,4,5,6,7,8,9")
		m.dp.dyna("OCCCCNNC","1,2,3,4,5,6,7,9,8")
		m.dp.dyna("OCCCCC","1,2,3,4,5,9")
		if m.dp.para(@m.table, @m.searchKey, @m.foundKey, @m.searchedGroupKey, @m.foundGroupKey, @m.low, @m.high, @m.exclusive, @m.runFilter) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		m.idc = this.idontcare()
		m.exp.erase()
		m.exp = createobject("ExportTable",m.exp.getDBF())
		m.exp.setCursor(.t.)
		m.exp.setMessenger(this.getMessenger())
		try
			m.rc = m.exp.create(this, m.searchKey, m.foundKey, m.low, m.high, m.exclusive, m.runFilter, .f.)
		catch
			m.rc = .t.
		endtry
		if not m.rc
			m.exp.erase()
			return .f.
		endif
		m.oldmes = m.table.getMessenger()
		m.table.setMessenger(this.getMessenger())
		if m.idc
			this.dontcare()
		endif
		try
			m.rc = m.table.create(m.exp, m.searchedGroupKey, m.foundGroupKey)
		catch
			m.rc = .f.
		endtry
		m.table.setMessenger(m.oldmes)
		return m.rc
	endfunc

	function groupedExport(table, cascade, baseKey, low, high, exclusive, runFilter, notext, nosingle)
		local ps1, swap, dp
		local oldmes, exp, rc, i, sql, clutable, offset, idc, f
		m.ps1 = createobject("PreservedSetting","deleted", "off")
		if vartype(m.table) == "C"
			m.table = createobject("GroupedExportTable",this.properExt(m.table))
		endif
		if not m.table.isCreatable()
			if not this.idontcare(.t.)
				this.messenger.errorMessage("Unable to create GroupedExportTable.")
				return .f.
			endif
		else
			if not m.table.pseudoCreate()
				this.messenger.errorMessage("Unable to create GroupedExportTable.")
				return .f.
			endif
		endif
		m.dp = createobject("DynaPara")
		m.dp.dyna("OCCNNLCLL")
		m.dp.dyna("O")
		m.dp.dyna("ONNLLL","1,4,5,6,8,9")
		m.dp.dyna("ONNCLL","1,4,5,7,8,9")
		m.dp.dyna("ONNLCLL","1,4,5,6,7,8,9")
		m.dp.dyna("OCNNLLL","1,2,4,5,6,8,9")
		m.dp.dyna("OCNNCLL","1,2,4,5,7,8,9")
		m.dp.dyna("OCNNLCLL","1,2,4,5,6,7,8,9")
		m.dp.dyna("OCCNNLLL","1,2,3,4,5,6,8,9")
		m.dp.dyna("OCCNNCLL","1,2,3,4,5,7,8,9")
		m.dp.dyna("OCCLL","1,2,3,8,9")
		m.dp.dyna("OCCCLL","1,2,3,7,8,9")
		m.dp.dyna("OCCCNN","1,2,3,7,4,5,6,8,9")
		m.dp.dyna("OCCCNNLLL","1,2,3,7,4,5,6,8,9")
		m.dp.dyna("OCLL","1,2,8,9")
		m.dp.dyna("OLL","1,8,9")
		if m.dp.para(@m.table, @m.cascade, @m.baseKey, @m.low, @m.high, @m.exclusive, @m.runFilter, @m.notext, @m.nosingle) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		if vartype(m.cascade) == "C" and not vartype(m.basekey) == "O" and not "@" $ m.cascade and not ltrim(str(val(m.cascade))) == alltrim(m.cascade)
			m.swap = m.cascade
			m.cascade = m.basekey
			m.basekey = m.swap
		endif
		if vartype(m.basekey) == "C" and isdigit(ltrim(m.basekey)) and not vartype(m.runFilter) == "O"
			m.swap = m.basekey
			m.basekey = m.runFilter
			m.runFilter = m.swap
		endif
		if vartype(m.cascade) == "L"
			m.cascade = createobject("NestedCascade")
		else
			if vartype(m.cascade) == "C"
				m.cascade = createobject("NestedCascade",m.cascade)
			endif
		endif
		if not vartype(m.cascade) == "O" or not m.cascade.isValid("min b, max b, s b, p b")
			this.messenger.errorMessage("Invalid cascade definition.")
			return .f.
		endif
		if vartype(m.runFilter) == "C"
			m.runFilter = createobject("RunFilter",m.runFilter)
		endif
		if not vartype(m.runFilter) == "O"
			m.runFilter = createobject("RunFilter")
		endif
		m.idc = this.idontcare()
		if not ((vartype(m.low) == "N" and m.low > 0 or vartype(m.high) == "N" and m.high <= 100) or m.runFilter.isFiltering())
			if not vartype(m.baseKey) == "C" or empty(m.basekey)
				m.exp = this.result
				m.exp.mimicExportTable("", "", this)
			else
				m.f = this.baseCluster.getTableStructure()
				m.f = m.f.getFieldStructure(m.basekey)
				if this.result.reccount()/this.baseCluster.reccount() > 0.1 and inlist(m.f.getType(),"N","I","B") and (vartype(m.runFilter) != "C" or empty(m.runFilter)) and (vartype(m.low) != "N" or m.low <= 0) and (vartype(m.high) != "N" or m.high > 100)
					this.messenger.forceMessage("Verifying sequential key...")
					m.offset = 0
					m.sql = "locate for "+m.basekey+" != recno()+m.offset"
					for m.i = 1 to this.baseCluster.getTableCount()
						m.clutable = this.baseCluster.getTable(m.i)
						m.clutable.select()
						&sql
						if not eof()
							exit
						endif
						m.offset = m.offset+m.clutable.reccount()
					endfor
					if m.i > this.baseCluster.getTableCount()
						m.exp = this.result
						m.exp.mimicExportTable(m.basekey, m.basekey, this)
					endif
					this.messenger.forceMessage("")
				endif
			endif
		endif
		if not vartype(m.exp) == "O"		
			m.exp = createobject("BaseCursor")
			if not m.exp.isValid()
				return .f.
			endif
			m.exp.erase()
			m.exp = createobject("ExportTable",m.exp.getDBF())
			m.exp.setCursor(.t.)
			m.exp.setMessenger(this.getMessenger())
			try
				m.rc = m.exp.create(this, m.baseKey, m.baseKey, m.low, m.high, m.exclusive, m.runFilter, .f.)
			catch
				m.rc = .f.
			endtry
			if not m.rc
				m.exp.erase()
				return .f.
			endif
		endif
		m.oldmes = m.table.getMessenger()
		m.table.setMessenger(this.getMessenger())
		if m.idc
			this.dontcare()
		endif
		try
			m.rc = m.table.create(m.exp, m.cascade, m.notext, m.nosingle)
		catch
			m.rc = .f.
		endtry
		m.table.setMessenger(m.oldmes)
		return m.rc
	endfunc

	function metaExport(table, meta, raw, low, high, runFilter)
		local oldmes, rc, dp, swap
		if vartype(m.table) == "C"
			m.table = createobject("MetaExportTable",this.properExt(m.table))
		endif
		m.dp = createobject("DynaPara")
		m.dp.dyna("OCLNNC")
		m.dp.dyna("O")
		m.dp.dyna("OC")
		m.dp.dyna("OCL")
		m.dp.dyna("OCLNN")
		m.dp.dyna("OCNN","1,2,4,5")
		m.dp.dyna("OCNNC","1,2,4,5,6")
		m.dp.dyna("OCC","1,2,6")
		m.dp.dyna("OL","1,3")
		m.dp.dyna("OLNN","1,3,4,5")
		m.dp.dyna("OLNNC","1,3,4,5,6")
		m.dp.dyna("OLC","1,3,6")
		m.dp.dyna("ONN","1,4,5")
		m.dp.dyna("ONNC","1,4,5,6")
		if m.dp.para(@m.table, @m.meta, @m.raw, @m.low, @m.high, @m.runFilter) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		if vartype(m.meta) == "C" and not vartype(m.runFilter) == "O" and not "=" $ m.meta
			m.swap = m.meta
			m.meta = m.runFilter
			m.runFilter = m.swap
		endif
		m.oldmes = m.table.getMessenger()
		m.table.setMessenger(this.getMessenger())
		try
			m.rc = m.table.create(this, m.meta, m.raw, m.low, m.high, m.runFilter)
		catch
			m.rc = .f.
		endtry
		m.table.setMessenger(m.oldmes)
		return m.rc
	endfunc

	function resultExport(table, shuffle, low, high, runFilter, newrun)
	local dp, rc, oldmes
		if vartype(m.table) == "C"
			m.table = createobject("ResultTable",m.table)
		endif
		m.dp = createobject("DynaPara")
		m.dp.dyna("ONNNCL")
		m.dp.dyna("O")
		m.dp.dyna("ONNNL","1,2,3,4,6")
		m.dp.dyna("ONNL","1,3,4,6")
		m.dp.dyna("ONNCL","1,3,4,5,6")
		m.dp.dyna("ONCL","1,2,5,6")
		m.dp.dyna("ONL","1,2,6")
		m.dp.dyna("OCL","1,5,6")
		m.dp.dyna("OL","1,6")
		if m.dp.para(@m.table, @m.shuffle, @m.low, @m.high, @m.runfilter, @m.newrun) == 0
			this.messenger.errorMessage("Invalid cascade definition.")
			return .f.
		endif
		m.oldmes = m.table.getMessenger()
		m.table.setMessenger(this.getMessenger())
		try
			m.rc = m.table.create(this, m.shuffle, m.low, m.high, m.runFilter, m.newrun)
		catch
			m.rc = .f.
		endtry
		m.table.setMessenger(m.oldmes)
		return m.rc
	endfunc

	function create(searchTypesDefinition as String)
		local ps1, ps2, ps3, lm, rg
		local collection, collector, invalid, searchtype
		local entrylen, i, j, base, field, already, lex
		local lexArray, tmp, limit, basecnt, alen
		local newreg, fromArray, toArray, rec, err, cnt, baseTable
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.lm = createobject("LastMessage",this.messenger,"")
		this.messenger.forceMessage("Collecting...")
		this.confirmChanges()
		this.searchTypes = createobject("SearchTypes",m.searchTypesDefinition,this.preparer)
		this.searchTypes.recalculateShares()
		if not this.searchTypes.isValid(this.baseTable)
			this.messenger.errormessage("SearchTypes are invalid.")
			return .f.
		endif
		m.invalid = this.searchTypes.getInvalidPreparer()
		if not empty(m.invalid)
			this.messenger.errormessage("Invalid Preparer "+getwordnum(m.invalid,1)+".")
			return .f.
		endif		
		m.collection = createobject("Collection")
		m.collector = createobject("CollectorCursor",this.getEnginePath())
		if not m.collector.isValid()
			this.messenger.errormessage("Unable to create the collector.")
			return .f.
		endif
		if this.idontcare()
			this.erase()
		endif
		if not this.isCreatable()
			this.messenger.errormessage("SearchEngine is not creatable.")
			return .f.
		endif
		m.collection.add(m.collector)
		this.registry.create()
		this.registry.useExclusive()
		this.registry.forceRegistryKey()
		if not this.registry.isValid()
			this.registry.erase()
			this.messenger.errormessage("Unable to create the registry.")
			return .f.
		endif
		m.entrylen = this.registry.getTableStructure()
		m.entrylen = m.entrylen.getFieldStructure("entry")
		m.entrylen = m.entrylen.getSize()
		m.rg = createobject("ReindexGuard",this.registry)
		dimension m.lexArray[1]
		this.baseCluster.call("setKey()")
		m.limit = 100000000
		m.base = 1
		m.basecnt = this.baseCluster.callSum("reccount()")
		this.messenger.setDefault("Created")
		this.messenger.startProgress(m.basecnt)
		this.messenger.startCancel("Cancel Operation?","Creating","Canceled.")
		do while this.baseCluster.goRecord(m.base)
			if this.messenger.queryCancel()
				this.registry.erase()
				return .f.
			endif
			if reccount(m.collector.alias) > m.limit
				m.collector = createobject("CollectorCursor",this.getEnginePath())
				if not m.collector.isValid()
					this.registry.erase()
					this.messenger.errormessage("Unable to create the collector.")
					return .f.
				endif
				m.collection.add(m.collector)
			endif
			for m.i = 1 to this.searchTypes.getSearchTypeCount()
				m.baseTable = this.baseCluster.getActiveTable()
				m.searchType = this.searchTypes.getSearchTypeByIndex(m.i)
				m.field = m.searchType.getField()
				m.already = " "
				if alines(m.lexArray,m.searchType.prepare(m.baseTable.getValueAsString(m.field)),5," ") == 0
					loop
				endif
				select (this.registry.alias)
				m.alen = min(alen(m.lexArray), MAXWORDCOUNT)
				for m.j = 1 to m.alen
					m.lex = left(m.lexArray[m.j], m.entrylen)
					if seek(this.registry.buildRegistryKey(m.i, m.lex))
						if occurs > 0 and not (" "+m.lex+" " $ m.already)
							replace occurs with occurs+1
							insert into (m.collector.alias) values (m.base,recno(this.registry.alias))
							m.already = m.already+m.lex+" "
						endif
					else
						insert into (this.registry.alias) values (m.i,m.lex,1)
						insert into (m.collector.alias) values (m.base,reccount(this.registry.alias))
						m.rg.tryReindex()
						m.already = m.already+m.lex+" "
					endif
				endfor
			endfor
			select (m.collector.alias)
			if base != m.base
				insert into (m.collector.alias) values (m.base,0)
			endif
			this.messenger.setProgress(m.base)
			this.messenger.postProgress()
			m.base = m.base+1
		enddo
		this.messenger.forceMessage("Optimizing...")
		m.tmp = createobject("UniqueAlias",.t.)
		select (this.registry.alias)
		m.err = .f.
		try
			select cast(0 as i) as newreg, cast(recno() as i) as oldreg from (this.registry.alias) order by occurs, type, entry into cursor (m.tmp.Alias) readwrite
			update (m.tmp.alias) set newreg = recno()
			select newreg, cast(0 as n(1)) as ok from (m.tmp.alias) order by oldreg into cursor (m.tmp.alias) readwrite
		catch
			m.err = .t.
		endtry
		if m.err
			this.registry.erase()
			this.messenger.errormessage("Unable to create temporary Cursor.")
			return .f.
		endif
		this.registry.deleteKey()
		dimension m.toArray[1]
		dimension m.fromArray[1]
		select (m.tmp.alias)
		m.rec = 1
		m.cnt = 0
		this.messenger.setDefault("Optimized")
		this.messenger.startProgress(reccount())
		do while not eof()
			if this.messenger.queryCancel()
				this.registry.erase()
				return .f.
			endif
			if ok == 1
				skip
				m.rec = m.rec+1
				loop
			endif
			select (this.registry.alias)
			goto m.rec
			scatter to m.fromArray
			do while .t.
				m.cnt = m.cnt+1
				this.messenger.setProgress(m.cnt)
				this.messenger.postProgress()
				select (m.tmp.alias)
				replace ok with 1
				m.newreg = newreg
				goto m.newreg
				if ok == 1
					select (this.registry.alias)
					goto m.newreg
					gather from m.fromArray
					exit
				else
					select (this.registry.alias)
					goto m.newreg
					scatter to m.toArray
					gather from m.fromArray
					acopy(m.toArray, m.fromArray)
				endif
			enddo
			select (m.tmp.Alias)
			goto m.rec
			skip
			m.rec = m.rec+1
		enddo
		for m.i = 1 to m.collection.count
			m.collector = m.collection.item(m.i)
			select (m.collector.alias)
			if m.collection.count > 1
				this.messenger.setDefault("Optimized (Collector"+ltrim(str(m.i,18))+")")
			else
				this.messenger.setDefault("Optimized (Collector)")
			endif
			this.messenger.startProgress(reccount())
			scan
				if this.messenger.queryCancel()
					this.registry.erase()
					return .f.
				endif
				m.newreg = reg
				if m.newreg > 0
					select (m.tmp.Alias)
					goto m.newreg
					m.newreg = newreg
					select (m.collector.alias)
					replace reg with m.newreg
				endif
				this.messenger.setProgress(recno())
				this.messenger.postProgress()
			endscan
		endfor
		this.messenger.forceMessage("Optimizing...")
		this.registry.forceRegistryKey()
		if not this.base2reg.create(m.collection,"base","reg",.t.)
			this.registry.erase()
			return .f.
		endif
		if not this.reg2base.create(m.collection,"reg","base")
			this.base2reg.erase()
			this.registry.erase()
			return .f.
		endif
		this.messenger.forceMessage("Closing...")
		this.registry.reindex()
		this.registry.forceRegistryKey()
		this.controlTable.create(this.registry, this.searchTypes)
		this.searchFieldJoin = createobject("TableStructureJoin",this.searchCluster.getTableStructure(),this.searchTypes.getSearchFieldsAsTableStructure())
		this.syncSearchCluster()
		this.registry.useShared()
		this.preparermsg = ""
		this.expanded = .f.
		this.reg2base.switchTargetToFile()
		this.save(.t.)
		if not this.isValid()
			this.messenger.errorMessage("SearchEngine not valid.")
			return .f.
		endif
		return .t.
	endfunc

	function expand(expandMode as Integer, new as Object, meta as Object)
		local pa, ps1, ps2, ps3, lm, rg
		local entrylen, i, j, base, fa, fb, lex
		local lexArray, table, already
		local searchType, typeIndex, type, cnt
		local occ, occurs, rec, index, start, end
		local copy, registry, dp
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Expanding...")
		m.dp = createobject("DynaPara")
		m.dp.dyna("NOO")
		m.dp.dyna("NCC")
		m.dp.dyna("NOC")
		m.dp.dyna("NCO")
		m.dp.dyna("")
		m.dp.dyna("N")
		m.dp.dyna("O","2")
		m.dp.dyna("C","2")
		m.dp.dyna("OO","2,3")
		m.dp.dyna("CC","2,3")
		m.dp.dyna("OC","2,3")
		m.dp.dyna("CO","2,3")
		if m.dp.para(@m.expandMode, @m.new, @m.meta) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		if not vartype(m.expandMode) == "N"
			m.expandMode = 0 && reset Registry or create external Registry
		endif
		if m.expandMode < 0 or m.expandMode > 6
			this.messenger.errormessage("Invalid expand mode.")
			return .f.
		endif
		if vartype(m.new) == "C" 
			if empty(m.new)
				this.messenger.errormessage("Invalid Registry specification.")
				return .f.
			endif
			m.new = createobject("RegistryTable", m.new)
		endif
		m.copy = .f.
		if vartype(m.new) == "O"
			m.copy = .t.
			if not m.new.isCreatable()
				this.messenger.errormessage("Unable to create external Registry.")
				return .f.
			endif
		endif
		if vartype(m.meta) == "C"
			m.meta = createobject("MetaFilter",m.meta,this.searchTypes)
		endif
		if vartype(m.meta) == "O"
			if not m.meta.isValid()
				this.messenger.errormessage("MetaFilter is invalid.")
				return .f.
			endif
		else
			m.meta = createobject("MetaFilter","",this.searchTypes)
		endif
		this.confirmChanges()
		if m.copy and m.meta.size == 0
			this.registry.setKey()
			this.registry.select()
			copy structure to (m.new.getDBF()) with cdx
			m.new.open()
			return m.new
		endif			
		if m.expandMode > 0 and not this.isExpandable()
			this.messenger.errormessage("SearchEngine is not expandable.")
			return .f.
		endif
		if m.copy == .f. and m.expandMode == 0 and not this.isValid()
			this.messenger.errormessage("Registry cannot be rebuild.")
			return .f.
		endif
		if not this.registry.useExclusive()
			this.messenger.errormessage("Registry is in use.")
			return .f.
		endif
		this.registry.setKey()
		this.registry.select()
		if m.copy
			copy to (m.new.getDBF()) with cdx
			m.new.open()
			m.registry = m.new
			m.occ = m.new
			update (m.occ.alias) set occurs = 0
		else
			m.occ = createobject("UniqueAlias",.t.)
			select cast(0 as i) as occurs from (this.registry.alias) into cursor (m.occ.alias) readwrite
			m.registry = this.registry
		endif
		this.messenger.setDefault("Collected")
		this.messenger.startCancel("Cancel Operation?","Expanding","Canceled.")
		if m.expandMode == 0 and m.copy == .f.
			select (m.occ.alias)
			this.messenger.startProgress(reccount())
			this.messenger.setDefault("Collected")
			scan
				this.messenger.incProgress()
				if this.messenger.queryCancel()
					exit
				endif
				m.rec = recno()
				m.occurs = 0
				for m.i = 1 to this.reg2base.index.count
					m.index = this.reg2base.index.item(m.i)
					select (m.index.alias)
					goto m.rec
					m.start = index
					skip
					m.end = index
					m.occurs = m.occurs+(m.end-m.start)
				endfor
				select (m.occ.alias)
				replace occurs with m.occurs
				this.messenger.postProgress()
			endscan
		else
			m.entrylen = this.registry.getTableStructure()
			m.entrylen = m.entrylen.getFieldStructure("entry")
			m.entrylen = m.entrylen.getSize()
			m.registry.forceRegistryKey()
			dimension m.lexArray[1]
			this.searchCluster.call("setKey()")
			m.base = 1
			this.messenger.startProgress(this.searchCluster.reccount())
			if m.copy
				m.rg = createobject("ReindexGuard",m.registry)
			endif
			do while this.searchCluster.goRecord(m.base)
				this.messenger.incProgress()
				if this.messenger.queryCancel()
					exit
				endif
				m.table = this.searchCluster.getActiveTable()
				for m.i = 1 to this.searchFieldJoin.getJoinCount()
					m.fa = this.searchFieldJoin.getA(m.i)
					m.fb = this.searchFieldJoin.getB(m.i)
					m.fa = m.fa.getName()
					m.fb = m.fb.getName()
					m.cnt = this.searchTypes.getSearchTypeCount(m.fb)
					for m.type = 1 to m.cnt
						m.searchType = this.searchTypes.getSearchTypeByField(m.fb,m.type)
						m.typeIndex = m.searchType.getTypeIndex()
						if m.meta.meta[m.typeIndex] == 0
							loop
						endif
						if alines(m.lexArray,m.searchType.prepare(m.table.getValueAsString(m.fa)),5," ") == 0
							loop
						endif
						m.already = " "
						for m.j = 1 to alen(m.lexArray)
							m.lex = left(m.lexArray[m.j], m.entrylen)
							if not (" "+m.lex+" " $ m.already)
								m.already = m.already+m.lex+" "
								select (m.registry.alias)
								if m.copy
									if seek(m.registry.buildRegistryKey(m.typeIndex, m.lex))
										replace occurs with occurs+1
									else
										insert into (m.registry.alias) values (m.typeIndex,m.lex,1)
										m.rg.tryReindex()
									endif
								else
									if seek(m.registry.buildRegistryKey(m.typeIndex, m.lex))
										m.rec = this.registry.recno()
										select (m.occ.alias)
										go m.rec
										replace occurs with occurs+1
									endif
								endif
							endif
						endfor
					endfor
				endfor
				this.messenger.postProgress()
				m.base = m.base+1
			enddo
		endif
		if this.messenger.isCanceled()
			this.registry.useShared()
			if m.copy
				m.new.erase()
			endif
			return .f.
		endif
		if m.expandMode == 0 and m.copy
			this.registry.useShared()
			return m.new
		endif			
		select (m.occ.alias)
		this.messenger.stopCancel()
		this.messenger.startProgress(reccount())
		if m.expandMode == 0
			this.messenger.setDefault("Rebuilt")
			scan
				this.messenger.incProgress()
				m.occurs = occurs
				m.rec = recno()
				select (this.registry.alias)
				go m.rec
				if occurs != m.occurs
					replace occurs with m.occurs
				endif
				this.messenger.postProgress()
			endscan
		else
			this.messenger.setDefault("Transferred")
			if m.copy
				this.registry.select()
				this.messenger.startProgress(reccount())
				scan
					this.messenger.incProgress()
					m.occurs = occurs
					m.rec = recno()
					select (m.registry.alias)
					go m.rec
					if occurs == 0
						replace occurs with m.occurs
						this.messenger.postProgress()
						loop
					endif
					do case && occurs -> new registry; m.occurs -> original registry
						case m.expandMode == 1 && always replace
						case m.expandMode == 2 && maximize
							if occurs < m.occurs
								replace occurs with m.occurs
							endif
						case m.expandMode == 3 && minimize
							if occurs > m.occurs
								replace occurs with m.occurs
							endif
						case m.expandMode == 4 && additive
							replace occurs with occurs+m.occurs
						case m.expandMode == 5 && mean
							replace occurs with int((occurs+m.occurs)/2 + 0.51)
					endcase
					this.messenger.postProgress()
				endscan
			else
				scan
					this.messenger.incProgress()
					m.occurs = occurs
					m.rec = recno()
					if m.occurs == 0
						this.messenger.postProgress()
						loop
					endif
					select (this.registry.alias)
					go m.rec
					do case
						case m.expandMode == 1  && always replace
							replace occurs with m.occurs
						case m.expandMode == 2 && maximize
							if m.occurs > occurs
								replace occurs with m.occurs
							endif
						case m.expandMode == 3 && minimize
							if m.occurs < occurs
								replace occurs with m.occurs
							endif
						case m.expandMode == 4 && additive
							replace occurs with occurs+m.occurs
						case m.expandMode == 5 && mean
							replace occurs with int((occurs+m.occurs)/2 + 0.51)
					endcase
					this.messenger.postProgress()
				endscan
			endif
		endif
		this.messenger.forceMessage("Closing...")
		this.registry.useShared()
		if m.copy
			return m.new
		endif
		this.expanded = m.expandMode > 0
		this.ControlTable.refresh(this.registry)
		this.controlTable.refreshOccurrences(this.searchTypes)
		this.save(.t.)
		return .t.
	endfunc

	function search(increment as Number, refineMode as Number, refineForce as Boolean, refineLimit as Number)
		local pa, ps1, ps2, ps3, ps4, ps5, ps6, ps7, lm,  pk1
		local limit, invlimit, depth, fa, fb
		local i, j, k, lexArray, type, fback, fbackinv, start, end
		local sum, old, sharesum, lorange, hirange
		local searchrec, score, offset, occurs, found, share
		local searchTable, reccount, dynamicDepth
		local tmp1, tmp2, tmp1rows, tmp2rows
		local typx, typxrows, log, logs, softmax, max
		local searchType, typeIndex, cnt
		local index, target, cluster, tar, run, runchr
		local activeJoin, joinCount
		local sizerec, sizelimit, resultsize, resultstart
		local cleaning, research, dp
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.ps4 = createobject("PreservedSetting","exact","on")
		m.ps5 = createobject("PreservedSetting","near","off") 
		m.ps6 = createobject("PreservedSetting","optimize","on")
		m.ps7 = createobject("PreservedSetting","decimals","6")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Searching...")
		m.dp = createobject("DynaPara")
		m.dp.dyna("NNLN")
		m.dp.dyna("")
		m.dp.dyna("N")
		m.dp.dyna("NN","1,2")
		m.dp.dyna("NNL","1,2,3")
		m.dp.dyna("NNN","1,2,4")
		if m.dp.para(@m.increment, @m.refineMode, @m.refineForce, @m.refineLimit) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		this.confirmChanges()
		if not this.isSearchReady()
			this.messenger.errormessage("Search is not Ready.")
			return .f.
		endif
		if not vartype(m.refineMode) == "N"
			m.refineMode = 0
		endif
		if not vartype(m.refineLimit) == "N"
			m.refineLimit = this.threshold
		endif
		m.refineLimit = min(max(m.refineLimit,0),100)
		m.cleaning = .f.
		m.research = .f.
		if m.refineMode > 0
			m.cleaning = .t.
			if m.refineForce == .f.
				m.activeJoin = this.getActiveJoin(-1)
				if m.activeJoin.getJoinCount() == 0
					m.cleaning = .f.
				else
					m.activeJoin = this.getActiveJoin(1)
					if m.activeJoin.getJoinCount() > 0
						m.research = .t.
					endif
				endif
			endif
		endif
		m.activeJoin = this.getActiveJoin()
		m.joinCount = m.activeJoin.getJoinCount()
		if m.joinCount <= 0
			this.messenger.errormessage("No active SearchField.")
			return .f.
		endif
		if not this.result.iscreatable() and not this.result.useExclusive()
			this.messenger.errormessage("Unable to get exclusive access on ResultTable.")
			return .f.
		endif
		m.run = max(this.result.getRun(),0)
		m.runchr = chr(m.run)
		if not vartype(m.increment) == "N" or m.run <= 0 or this.result.reccount() == 0
			m.increment = 0
		endif
		if inlist(m.increment,-1,-2)
			this.messenger.forceMessage("Removing run "+ltrim(str(m.run,10)))
			m.increment = abs(m.increment)
			this.result.setKey()
			delete from (this.result.alias) where run == m.runchr
			go top in (this.result.alias)
			recall in (this.result.alias)
			this.result.pack()
			m.run = m.run-1
			this.result.setRun(m.run)
			this.messenger.forceMessage("Searching...")
		endif
		m.reccount = this.searchCluster.reccount()
		m.searchrec = 1
		m.found = 0
		do case
			case m.increment == 1 && complete
				if not this.result.forceKey("searched")
					this.messenger.errormessage("Unable to increment ResultTable.")
					return .f.
				endif
				m.run = m.run+1
			case m.increment = 2 && merge
				if not this.result.forceKey('ltrim(str(searched))+" "+ltrim(str(found))')
					this.messenger.errormessage("Unable to increment ResultTable.")
					return .f.
				endif
				m.run = m.run+1
			case m.increment = 3 && continue
				if not this.result.forceKey("searched")
					this.messenger.errormessage("Unable to increment ResultTable.")
					return .f.
				endif
				dimension m.tmp2[1]
				select max(searched) from (this.result.alias) where run = m.runchr into array tmp2
				m.searchrec = m.tmp2[1]
				if m.searchrec == m.reccount
					return .t.
				endif
				if m.searchrec > m.reccount
					this.messenger.errormessage("Unable to increment ResultTable.")
					return .f.
				endif
				m.searchrec = m.searchrec+1
				this.result.deleteKey()
				m.found = reccount(this.result.alias)
			otherwise && new result table
				m.increment = 0
				this.result.erase()
				if not this.result.create()
					this.messenger.errormessage("Unable to create ResultTable.")
					return .f.
				endif
				this.result.deleteKey()
				m.run = 1
		endcase
		m.run = min(m.run,255)
		this.result.setRun(m.run)
		m.run = chr(m.run)
		m.pk1 = createobject("PreservedKey",this.registry)
		this.registry.forceRegistryKey()
		m.typxrows = this.SearchTypes.getSearchTypeCount()
		if this.depth <= 0
			m.depth = DEFSEARCHDEPTH
		else
			m.depth = min(this.depth,MAXSEARCHDEPTH)
		endif
		OpenArray(1,MAXWORDCOUNT,6)
		OpenArray(2,m.depth,2)
		OpenArray(3,m.depth,3)
		dimension m.tmp1[MAXWORDCOUNT,7]
		dimension m.tmp2[MAXWORDCOUNT,2]		
		dimension m.typx[m.typxrows,4]
		m.fback = this.feedback/100
		m.fbackinv = 1-m.fback
		this.changed = .t.
		m.invlimit = 100-this.threshold
		dimension m.lexArray[1]
		m.sizerec = this.result.getRecordSize()
		m.sizelimit = 2*1024*1024*1024 - 50*1024*1024
		m.resultsize = this.result.reccount() * m.sizerec
		m.resultstart = this.result.reccount()+1
		this.searchCluster.call("setKey()")
		m.reccount = "/"+ltrim(str(m.reccount,18,0))
		this.messenger.startCancel("Cancel Operation?","Searching","Canceled.")
		do while this.searchCluster.goRecord(m.searchrec)
			if this.messenger.queryCancel()
				exit
			endif
			if m.increment == 1 and seek(m.searchrec, this.result.alias)
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				this.messenger.postProgress()
				m.searchrec = m.searchrec + 1
				loop
			endif
			m.searchTable = this.searchCluster.getActiveTable()
			m.tmp2rows = 0
			for m.i = 1 to m.joinCount
				m.fa = m.activeJoin.getA(m.i)
				m.fb = m.activeJoin.getB(m.i)
				m.fa = m.fa.getName()
				m.fb = m.fb.getName()
				m.cnt = this.searchTypes.getSearchTypeCount(m.fb)
				for m.type = 1 to m.cnt
					m.searchType = this.searchTypes.getSearchTypeByField(m.fb,m.type)
					if m.searchType.getShare() > 0
						m.typeIndex = m.searchType.getTypeIndex()
						if alines(m.lexArray,m.searchType.prepare(m.searchTable.getValueAsString(m.fa)),5," ") > 0
							m.end = min(alen(m.lexArray),MAXWORDCOUNT-m.tmp2rows) 				
							for m.j = 1 to m.end
								m.tmp2rows = m.tmp2rows+1
								m.tmp2[m.tmp2rows,1] = m.typeIndex
								m.tmp2[m.tmp2rows,2] = this.registry.buildRegistryKey(m.typeIndex, m.lexArray[m.j])
							endfor
						endif
					endif
				endfor
			endfor
			if m.tmp2rows <= 0
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				m.searchrec = m.searchrec + 1
				loop
			endif
			asort(m.tmp2,2,m.tmp2rows,0)
			m.old = ""
			m.tmp1rows = 0
			for m.i = 1 to m.tmp2rows
				if not m.old == m.tmp2[m.i,2]
					m.old = m.tmp2[m.i,2]
					m.searchType = this.searchTypes.getSearchTypeByIndex(m.tmp2[m.i,1])
					m.tmp1rows = m.tmp1rows+1
					m.tmp1[m.tmp1rows,1] = m.old
					m.tmp1[m.tmp1rows,2] = m.tmp2[m.i,1]
					m.tmp1[m.tmp1rows,3] = m.searchType.getShare()
					m.tmp1[m.tmp1rows,4] = m.searchType.getAvgOcc() && replaced with rIP
					m.tmp1[m.tmp1rows,5] = m.searchType.getMaxOcc()	&& replaced with occur
					m.tmp1[m.tmp1rows,6] = 0 && active / inactive
					m.tmp1[m.tmp1rows,7] = 0 && in case of softmax: IP without softmax for feedback
				endif
			endfor
			if this.relative
				m.sum = 0
				m.old = 0
				for m.i = 1 to m.tmp1rows
					if not m.old == m.tmp1[m.i,2]
						m.sum = m.sum+m.tmp1[m.i,3]
						m.old = m.tmp1[m.i,2]
					endif
				endfor
				for m.i = 1 to m.tmp1rows
					m.tmp1[m.i,3] = m.tmp1[m.i,3]*100/m.sum
				endfor
			endif
			m.score = 0
			m.old = 0
			m.softmax = 0
			select (this.registry.alias)
			for m.i = 1 to m.tmp1rows
				if not m.old = m.tmp1[m.i,2]
					if m.softmax > 0
						m.softmax = 1/m.max * m.softmax
						for m.k = m.j to m.i-1
							if m.tmp1[m.k,4] > 0
								m.tmp1[m.k,7] = m.tmp1[m.k,4]
								m.tmp1[m.k,4] = exp(m.tmp1[m.k,4]*m.softmax)
							endif
						endfor
					endif
					m.searchType = this.searchTypes.getSearchTypeByIndex(m.tmp1[m.i,2])
					m.offset = m.searchType.getOffset()
					m.logs = m.searchType.getLog()
					m.softmax = m.searchType.getSoftmax()
					m.old = m.tmp1[m.i,2]
					m.j = m.i
					m.max = 1
				endif
				if seek(m.tmp1[m.i,1])
					m.score = m.score + m.tmp1[m.i,3] / occurs
					m.occurs = max(occurs+m.offset,1)
					m.log = max(m.tmp1[m.i,5]+m.offset,1) / m.occurs
					m.tmp1[m.i,1] = recno()
					m.tmp1[m.i,5] = occurs
					if m.logs
						m.tmp1[m.i,4] = max(log(m.log),1)
					else
						m.tmp1[m.i,4] = m.log
					endif
				else
					if this.ignorant
						m.tmp1[m.i,4] = 0
					else
						m.log = max(m.tmp1[m.i,5]+m.offset,1) / max(m.tmp1[m.i,4]+m.offset,1)
						if m.logs
							m.tmp1[m.i,4] = max(log(m.log),1)
						else
							m.tmp1[m.i,4] = m.log
						endif
					endif
					m.tmp1[m.i,1] = 0
				endif
				if m.softmax > 0
					m.max = max(m.max, m.tmp1[m.i,4])
				endif
			endfor
			if m.softmax > 0
				m.softmax = 1/m.max * m.softmax
				for m.k = m.j to m.i-1
					if m.tmp1[m.k,4] > 0
						m.tmp1[m.k,7] = m.tmp1[m.k,4]
						m.tmp1[m.k,4] = exp(m.tmp1[m.k,4]*m.softmax)
					endif
				endfor
			endif
			if this.feedback > 0
				for m.i = 1 to m.typxrows
					m.typx[m.i,1] = 0
					m.typx[m.i,4] = 0
				endfor
				for m.i = 1 to m.tmp1rows
					m.typx[m.tmp1[m.i,2],1] = m.typx[m.tmp1[m.i,2],1]+m.tmp1[m.i,4]
					m.typx[m.tmp1[m.i,2],4] = m.typx[m.tmp1[m.i,2],4]+evl(m.tmp1[m.i,7], m.tmp1[m.i,4]) 
				endfor
			else
				for m.i = 1 to m.typxrows
					m.typx[m.i,1] = 0
				endfor
				for m.i = 1 to m.tmp1rows
					m.typx[m.tmp1[m.i,2],1] = m.typx[m.tmp1[m.i,2],1]+m.tmp1[m.i,4]
				endfor
			endif
			for m.i = 1 to m.tmp1rows
				if m.typx[m.tmp1[m.i,2],1] == 0
					m.tmp1[m.i,4] = 0
					m.tmp1[m.i,3] = 0
				else
					m.tmp1[m.i,4] = m.tmp1[m.i,3] * m.tmp1[m.i,4] / m.typx[m.tmp1[m.i,2],1]
					m.tmp1[m.i,3] = m.tmp1[m.i,4]
				endif
			endfor
			asort(m.tmp1,1,m.tmp1rows,1)
			for m.i = m.tmp1rows to 1 step -1
				if m.tmp1[m.i,1] > 0
					exit
				endif
			endfor
			m.tmp1rows = m.i
			if m.tmp1rows <= 0
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				m.searchrec = m.searchrec + 1
				loop
			endif
			m.shareSum = 0
			asort(m.tmp1,4,m.tmp1rows,1)
			for m.i = 1 to m.tmp1rows
				if m.tmp1[m.i,4] <= 0
					exit
				endif
				m.tmp1[m.i,6] = 1  && active
				m.shareSum = m.shareSum+m.tmp1[m.i,4]	
			endfor
			m.tmp1rows = m.i-1
			if m.tmp1rows <= 0 or m.shareSum <= 0 or not this.zealous and m.shareSum < this.threshold
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				m.searchrec = m.searchrec + 1
				loop
			endif
			if this.expanded
				for m.i = 1 to m.tmp1rows
					m.tmp1[m.i,5] = 0
					for m.cluster = 1 to this.reg2base.index.count
						m.index = this.reg2base.index.item(m.cluster)
						select (m.index.alias)
						goto m.tmp1[m.i,1]
						m.start = index
						skip
						m.end = index
						m.tmp1[m.i,5] = m.tmp1[m.i,5]+(m.end-m.start)
					endfor
				endfor
			endif
			if m.tmp1[1,5] > m.depth
				for m.i = 1 to m.tmp1rows
					if m.tmp1[m.i,5] > m.depth
						m.tmp1[m.i,3] = 0
					endif
				endfor
				asort(m.tmp1,3,m.tmp1rows,1)				
			endif
			m.dynamicdepth = 0
			m.sum = 0
			for m.i = 1 to m.tmp1rows
				m.dynamicdepth = m.dynamicdepth+m.tmp1[m.i,5]
				m.sum = m.sum+m.tmp1[m.i,4]
				if m.sum > m.invlimit or m.dynamicdepth >= m.depth
					exit
				endif
			endfor			
			m.dynamicdepth = min(m.dynamicDepth,m.depth)
			m.tmp2rows = 0
			for m.i = 1 to m.tmp1rows
				if m.tmp2rows+m.tmp1[m.i,5] > m.dynamicDepth
					exit
				endif
				m.share = m.tmp1[m.i,4]
				m.tmp1[m.i,6] = 0  && inactive
				m.sharesum = m.sharesum-m.share
				for m.cluster = 1 to this.reg2base.index.count
					m.index = this.reg2base.index.item(m.cluster)
					m.target = this.reg2base.target.item(m.cluster)
					select (m.index.alias)
					if m.tmp1[m.i,1] >= reccount()
						loop
					endif
					goto m.tmp1[m.i,1]
					m.start = index
					skip
					m.end = index-m.start
					m.tmp2rows = m.tmp2rows+1
					CopyVector(2,m.target.handle,m.start,m.tmp2rows,m.end,1)
					m.tmp2rows = FillArray(2,m.share,m.tmp2rows,m.end,2)
				endfor
			endfor
			if m.tmp2rows <= 0
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				m.searchrec = m.searchrec + 1
				loop
			endif
			m.limit = max(this.threshold - m.sharesum,0)
			if m.i > 2
				SortArrayAsc(2,1,m.tmp2rows)
				CollectSumArray(2,m.tmp2rows,1,2,-2)
				SortArrayDesc(2,2,m.tmp2rows)
				m.tmp2rows = (-BinarySearchDescArray(2,-1,1,m.tmp2rows,2))-1
				if not this.zealous
					m.i = BinarySearchDescArray(2,m.limit,1,m.tmp2rows,2)
					if m.i < 0
						m.tmp2rows = (-m.i)-1
					else
						m.tmp2rows = LimitDescArray(2,m.limit,m.i,m.tmp2rows,2,1)
					endif
				endif
				if m.tmp2rows > 0
					if this.darwin or this.zealous and GetArrayElement(2,1,2) < m.limit
						m.limit = GetArrayElement(2,1,2) - m.sharesum - TOLERANCE
						if m.limit > 0
							m.i = BinarySearchDescArray(2,m.limit,1,m.tmp2rows,2)
							if m.i < 0
								m.tmp2rows = (-m.i)-1
							else
								m.tmp2rows = LimitDescArray(2,m.limit,m.i,m.tmp2rows,2,1)
							endif
						endif
					endif
					SortArrayAsc(2,1,m.tmp2rows)
				endif
			else
				if not this.zealous and GetArrayElement(2,1,2) < m.limit
					m.tmp2rows = 0
				endif
			endif
			if m.tmp2rows <= 0
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				m.searchrec = m.searchrec + 1
				loop
			endif
			asort(m.tmp1,1,m.tmp1rows,0)
			m.tmp1[m.tmp1rows,3] = m.tmp1[m.tmp1rows,4]*m.tmp1[m.tmp1rows,6]
			for m.i = m.tmp1rows-1 to 1 step -1
				m.tmp1[m.i,3] = m.tmp1[m.i+1,3]+m.tmp1[m.i,4]*m.tmp1[m.i,6]
			endfor
			if this.zealous
				m.limit = 0
			else
				m.limit = this.threshold
			endif
			ImportArray(@m.tmp1,1,m.tmp1rows,7)
			m.i = 1
			for m.cluster = 1 to this.reg2base.index.count
				m.index = this.reg2base.index.item(m.cluster)
				m.target = this.reg2base.target.item(m.cluster)
				m.i = BinarySearchEngine(1,2,m.tmp1rows,m.tmp2rows,m.i,m.limit,this.darwin,select(m.index.alias),m.target.handle,.t.)
			endfor
			m.tmp2rows = this.limitResultArray(2, m.tmp2rows)
			if m.tmp2rows <= 0
				this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
				m.searchrec = m.searchrec + 1
				loop
			endif
			if this.feedback > 0 and (this.activation <= 0 or m.tmp2rows >= this.activation)
				SortArrayAsc(2,1,m.tmp2rows)
				CopyArray(2,3,1,1,1,1,m.tmp2rows,2)
				CopyArray(2,3,1,2,1,3,m.tmp2rows,1)
				m.cluster = 1
				m.index = this.base2reg.index.item(m.cluster)
				m.target = this.base2reg.target.item(m.cluster)
				m.lorange = 0
				m.hirange = reccount(m.index.alias)-1
				for m.i = 1 to m.tmp2rows
					for m.j = 1 to m.typxrows
						m.typx[m.j,2] = 0
						m.typx[m.j,3] = 0
					endfor
					m.k = 1
					select (m.index.alias)
					do while GetArrayElement(3,m.i,1) > m.hirange
						m.cluster = m.cluster+1
						m.index = this.base2reg.index.item(m.cluster)
						m.target = this.base2reg.target.item(m.cluster)
						select (m.index.alias)
						m.lorange = m.hirange
						m.hirange = m.hirange+reccount()-1
					enddo
					go GetArrayElement(3,m.i,1)-m.lorange
					m.start = index
					skip
					m.end = min(index-1, m.start+MAXWORDCOUNT-1)
					select (m.target.alias)
					for m.j = m.start to m.end
						go m.j
						m.tar = target
						if m.k <= m.tmp1rows
							m.k = BinarySearchAscArray(1,m.tar,m.k,m.tmp1rows,1)
							if m.k > 0
								m.type = GetArrayElement(1,m.k,2)
								m.typx[m.type,2] = m.typx[m.type,2] + GetArrayElement(1,m.k,4)
								m.k = m.k+1
								loop
							else
								m.k = -m.k
							endif
						endif
						select (this.registry.alias)
						go m.tar
						if m.typx[type,4] <= 0
							select (m.target.alias)
							loop
						endif
						m.searchType = this.searchTypes.getSearchTypeByIndex(type)
						m.log = max(m.searchType.getMaxOcc()+m.searchType.getOffset(),1) / max(occurs+m.searchType.getOffset(),1)
						if m.searchType.getLog()
							m.typx[type,3] = m.typx[type,3] + max(log(m.log),1)
						else
							m.typx[type,3] = m.typx[type,3] + m.log
						endif
						select (m.target.alias)
					endfor
					m.sum = 0
					for m.j = 1 to m.typxrows
						if m.typx[m.j,2] > 0
							m.sum = m.sum + m.typx[m.j,2] * (m.fbackinv + m.typx[m.j,4] / (typx[m.j,1] + m.typx[m.j,3]) * m.fback)
						endif
					endfor
					SetArrayElement(3,m.i,2,m.sum)
				endfor
				if this.activation > 0 and this.cutoff > 0
					m.tmp2rows = this.limitResultArray(3, m.tmp2rows, .t.)
					CopyArray(3,2,1,1,1,1,m.tmp2rows,1)
					CopyArray(3,2,1,3,1,2,m.tmp2rows,1)
				else
					m.tmp2rows = this.limitResultArray(3, m.tmp2rows, .f.)
					CopyArray(3,2,1,1,1,1,m.tmp2rows,2)
				endif
			endif
			for m.i = 1 to m.tmp2rows
				if m.increment == 2 and seek(ltrim(str(m.searchrec))+" "+ltrim(str(GetArrayElement(2,m.i,1))),this.result.alias)
					loop
				endif
				insert into (this.result.alias) (searched, found, identity, score, run) values (m.searchrec,GetArrayElement(2,m.i,1),GetArrayElement(2,m.i,2),m.score, m.run)
				m.resultsize = m.resultsize+m.sizerec
				m.found = m.found+1
			endfor
			this.messenger.postMessage("Searched (Found) "+ltrim(str(m.searchrec))+m.reccount+" ("+ltrim(str(m.found))+")")
			m.searchrec = m.searchrec+1
			if m.resultsize >= m.sizelimit
				if m.cleaning
					CloseArray(1)
					CloseArray(2)
					CloseArray(3)
					if not this.cleanResult(m.refineMode, "start "+ltrim(str(m.resultstart,18)), m.research, m.refineLimit)
						if this.messenger.isCanceled()
							this.messenger.errorMessage("Unable to clean ResultTable.")
						endif
						exit
					endif
					OpenArray(1,MAXWORDCOUNT,6)
					OpenArray(2,m.depth,2)
					OpenArray(3,m.depth,3)
					m.resultstart = this.result.reccount() + 1
					m.resultsize = this.result.reccount() * m.sizerec
				endif
				if m.resultsize >= m.sizelimit
					this.messenger.errorMessage("ResultTable is too large.")
					exit
				endif
			endif
		enddo
		CloseArray(1)
		CloseArray(2)
		CloseArray(3)
		if not this.messenger.isError()
			if m.cleaning and m.resultstart <= this.result.reccount()
				if not this.cleanResult(m.refineMode, "start "+ltrim(str(m.resultstart,18)), m.research, m.refineLimit) and empty(this.messenger.getErrorMessage())
					this.messenger.errorMessage("Unable to finalize ResultTable.")
				endif
			endif
		endif
		this.messenger.sneakMessage("Closing...")
		this.result.deleteKey()
		this.result.forceRequiredKeys()
		this.result.useShared()
		if this.messenger.isInterrupted()
			return .f.
		endif
		return .t.
	endfunc
	
	function research(identityMode as Number, scoreMode as Number, runFilter as String, nonDestructiveOnly as Boolean)
		local lm, pa, ps1, ps2, ps3, ps4, ps5, ps6
		local pk1, pk2
		local i, j, k, fa, fb, lexArray, start, end 
		local sum, old, fback, fbackinv
		local offset, occurs, searchTable, score
		local tmp1, tmp2, tmp1rows, tmp2rows, typx, typxrows
		local searchType, typeIndex, type, cnt, log, logs, softmax, max
		local index, target, cluster, tar, found, searched, continuum
		local activeJoin, joinCount, searchTypes, dp
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.ps4 = createobject("PreservedSetting","exact","on")
		m.ps5 = createobject("PreservedSetting","near","off")
		m.ps6 = createobject("PreservedSetting","optimize","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Researching...")
		m.dp = createobject("DynaPara")
		m.dp.dyna("NNCL")
		m.dp.dyna("")
		m.dp.dyna("NN")
		m.dp.dyna("NNL","1,2,4")
		m.dp.dyna("CL","3,4")
		m.dp.dyna("L","4")
		if m.dp.para(@m.identityMode, @m.scoreMode, @m.runFilter, @m.nonDestructiveOnly) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		this.confirmChanges()
		if not this.isValid()
			this.messenger.errormessage("SearchEngine is not valid.")
			return .f.
		endif
		if not this.isResultTableValid()
			this.messenger.errormessage("ResultTable is not valid.")
			return .f.
		endif
		if not this.isSearchedSynchronized()
			this.messenger.errormessage("SearchTable is not synchronized.")
			return .f.
		endif
		if not vartype(m.identityMode) == "N"
			m.identityMode = 1
		endif
		if not vartype(m.scoreMode) == "N"
			m.scoreMode = 1
		endif
		if m.identityMode < 0 or m.identityMode > 5
			this.messenger.errormessage("Invalid identity mode.")
			return .f.
		endif
		if m.scoreMode < 0 or m.scoreMode > 3
			this.messenger.errormessage("Invalid score mode.")
			return .f.
		endif
		if m.scoreMode < 1 and m.identityMode < 1
			this.messenger.errormessage("Invalid research mode.")
			return .f.
		endif
		m.runFilter = createobject("RunFilter",m.runFilter)
		if not m.runFilter.isValid()
			this.messenger.errormessage("Run filter expression is invalid.")
			return .f.
		endif
		m.activeJoin = this.getActiveJoin(iif(m.nonDestructiveOnly,1,0))
		m.joinCount = m.activeJoin.getJoinCount()
		if m.joinCount <= 0
			this.messenger.errormessage("No active SearchField.")
			return .f.
		endif
		if m.nonDestructiveOnly
			m.searchTypes = this.searchTypes.filterByDestructive(.f.,.t.)
			m.searchTypes.recalculateShares(this.searchTypes.getPrioritySum())
		else
			m.searchTypes = this.searchTypes
		endif
		m.pk1 = createobject("PreservedKey",this.registry)
		m.pk2 = createobject("PreservedKey",this.result)
		this.result.setKey()
		this.registry.forceRegistryKey()
		m.fback = this.feedback/100
		m.fbackinv = 1 - m.fback
		m.typxrows = this.SearchTypes.getSearchTypeCount()
		dimension m.tmp1[MAXSEARCHDEPTH,6]
		dimension m.tmp2[MAXSEARCHDEPTH,3]
		dimension m.typx[m.typxrows,4]
		dimension m.lexArray[1]
		dimension m.continuum[1]
		acopy(this.base2reg.continuum, m.continuum)
		m.searched = 0
		this.messenger.start()
		select (this.result.alias)
		if between(m.runFilter.getStart(),1,reccount())
			go m.runFilter.getStart()
		else
			go top
		endif
		if recno() == 1 and searched <= 0
			skip
		endif
		this.messenger.setDefault("Researched")
		this.messenger.startProgress(reccount()-recno()+1)
		this.messenger.startCancel("Cancel Operation?","Researching","Canceled.")
		do while not eof()
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				return .f.
			endif
			if not m.runFilter.inRange(asc(run), recno())
				this.messenger.postProgress()
				skip
				loop
			endif
			m.found = found
			m.cluster = abs(InternalBinarySearchAscArray(@m.continuum,m.found,1,this.base2reg.index.count,1))
			if m.cluster > this.base2reg.index.count
				this.messenger.postProgress()
				skip
				loop
			endif
			if m.cluster > 1
				m.found = m.found-m.continuum[m.cluster-1]
			endif
			m.index = this.base2reg.index.item(m.cluster)
			m.target = this.base2reg.target.item(m.cluster)
			if searched != m.searched
				m.tmp2rows = 0
				m.tmp1rows = 0
				m.searched = searched
				if not this.searchCluster.goRecord(searched)
					this.messenger.postProgress()
					skip
					loop
				endif
				m.searchTable = this.searchCluster.getActiveTable()
				for m.i = 1 to m.joinCount
					m.fa = m.activeJoin.getA(m.i)
					m.fb = m.activeJoin.getB(m.i)
					m.fa = m.fa.getName()
					m.fb = m.fb.getName()
					m.cnt = m.searchTypes.getSearchTypeCount(m.fb)
					for m.type = 1 to m.cnt
						m.searchType = m.searchTypes.getSearchTypeByField(m.fb,m.type)
						if m.searchType.getShare() > 0
							m.typeIndex = m.searchType.getTypeIndex()
							if alines(m.lexArray,m.searchType.prepare(m.searchTable.getValueAsString(m.fa)),5," ") > 0
								m.end = min(alen(m.lexArray),MAXSEARCHDEPTH) 				
								for m.j = 1 to m.end
									m.tmp2rows = m.tmp2rows+1
									m.tmp2[m.tmp2rows,1] = m.typeIndex
									m.tmp2[m.tmp2rows,2] = this.registry.buildRegistryKey(m.typeIndex, m.lexArray[m.j])
								endfor
							endif
						endif
					endfor
				endfor
				if m.tmp2rows <= 0
					this.messenger.postProgress()
					skip
					loop
				endif
				asort(m.tmp2,2,m.tmp2rows,0)
				m.old = ""
				m.tmp1rows = 0
				for m.i = 1 to m.tmp2rows
					if not m.old == m.tmp2[m.i,2]
						m.old = m.tmp2[m.i,2]
						m.searchType = m.searchTypes.getSearchTypeByIndex(m.tmp2[m.i,1])
						m.tmp1rows = m.tmp1rows+1
						m.tmp1[m.tmp1rows,1] = m.old
						m.tmp1[m.tmp1rows,2] = m.tmp2[m.i,1]
						m.tmp1[m.tmp1rows,3] = m.searchType.getShare()
						m.tmp1[m.tmp1rows,4] = m.searchType.getAvgOcc() && replaced with rIP
						m.tmp1[m.tmp1rows,5] = m.searchType.getMaxOcc() && replaced with occurs
						m.tmp1[m.tmp1rows,6] = 0 && in case of softmax: IP without softmax for feedback
					endif
				endfor
				if this.relative
					m.sum = 0
					m.old = 0
					for m.i = 1 to m.tmp1rows
						if not m.old == m.tmp1[m.i,2]
							m.sum = m.sum+m.tmp1[m.i,3]
							m.old = m.tmp1[m.i,2]
						endif
					endfor
					for m.i = 1 to m.tmp1rows
						m.tmp1[m.i,3] = m.tmp1[m.i,3]*100/m.sum
					endfor
				endif
				m.score = 0
				m.old = 0
				m.softmax = 0
				select (this.registry.alias)
				for m.i = 1 to m.tmp1rows
					if not m.old = m.tmp1[m.i,2]
						if m.softmax > 0
							m.softmax = 1/m.max * m.softmax
							for m.k = m.j to m.i-1
								if m.tmp1[m.k,4] > 0
									m.tmp1[m.k,6] = m.tmp1[m.k,4]
									m.tmp1[m.k,4] = exp(m.tmp1[m.k,4]*m.softmax)
								endif
							endfor
						endif
						m.searchType = this.searchTypes.getSearchTypeByIndex(m.tmp1[m.i,2])
						m.offset = m.searchType.getOffset()
						m.logs = m.searchType.getLog()
						m.softmax = m.searchType.getSoftmax()
						m.old = m.tmp1[m.i,2]
						m.j = m.i
						m.max = 1
					endif
					if seek(m.tmp1[m.i,1])
						m.score = m.score + m.tmp1[m.i,3] / occurs
						m.occurs = max(occurs+m.offset,1)
						m.log = max(m.tmp1[m.i,5]+m.offset,1) / m.occurs
						m.tmp1[m.i,1] = recno()
						m.tmp1[m.i,5] = occurs
						if m.logs
							m.tmp1[m.i,4] = max(log(m.log),1)
						else
							m.tmp1[m.i,4] = m.log
						endif
					else
						if this.ignorant
							m.tmp1[m.i,4] = 0
						else
							m.log = max(m.tmp1[m.i,5]+m.offset,1) / max(m.tmp1[m.i,4]+m.offset,1)
							if m.logs
								m.tmp1[m.i,4] = max(log(m.log),1)
							else
								m.tmp1[m.i,4] = m.log
							endif
						endif
						m.tmp1[m.i,1] = 0
					endif
					if m.softmax > 0
						m.max = max(m.max, m.tmp1[m.i,4])
					endif
				endfor
				if m.softmax > 0
					m.softmax = 1/m.max * m.softmax
					for m.k = m.j to m.i-1
						if m.tmp1[m.k,4] > 0
							m.tmp1[m.k,6] = m.tmp1[m.k,4]
							m.tmp1[m.k,4] = exp(m.tmp1[m.k,4]*m.softmax)
						endif
					endfor
				endif
				if this.feedback > 0 and this.activation <= 0 
					for m.i = 1 to m.typxrows
						m.typx[m.i,1] = 0
						m.typx[m.i,4] = 0
					endfor
					for m.i = 1 to m.tmp1rows
						m.typx[m.tmp1[m.i,2],1] = m.typx[m.tmp1[m.i,2],1]+m.tmp1[m.i,4]
						m.typx[m.tmp1[m.i,2],4] = m.typx[m.tmp1[m.i,2],4]+evl(m.tmp1[m.i,6], m.tmp1[m.i,4]) 
					endfor
				else
					for m.i = 1 to m.typxrows
						m.typx[m.i,1] = 0
					endfor
					for m.i = 1 to m.tmp1rows
						m.typx[m.tmp1[m.i,2],1] = m.typx[m.tmp1[m.i,2],1]+m.tmp1[m.i,4]
					endfor
				endif
				for m.i = 1 to m.tmp1rows
					if m.typx[m.tmp1[m.i,2],1] == 0
						m.tmp1[m.i,5] = 0
						m.tmp1[m.i,4] = 0
					else
						m.tmp1[m.i,5] = m.tmp1[m.i,4] / m.typx[m.tmp1[m.i,2],1]
						m.tmp1[m.i,4] = m.tmp1[m.i,3] * m.tmp1[m.i,5]
					endif
				endfor					
				asort(m.tmp1,1,m.tmp1rows,1)
				for m.i = m.tmp1rows to 1 step -1
					if m.tmp1[m.i,1] > 0
						exit
					endif
				endfor
				m.tmp1rows = m.i
				if m.tmp1rows <= 0
					this.messenger.postProgress()
					select (this.result.alias)
					skip
					loop
				endif
				asort(m.tmp1,1,m.tmp1rows,0)
			endif
			m.sum = 0
			select (m.index.alias)
			go m.found
			m.start = index
			skip
			m.end = index-1
			m.j = 1
			select (m.target.alias)
			if this.feedback <= 0 or this.activation > 0
				for m.i = m.start to m.end
					goto m.i
					m.tar = target
					m.j = InternalBinarySearchAscArray(@m.tmp1,m.tar,m.j,m.tmp1rows,1)
					if m.j > 0
						m.sum = m.sum+m.tmp1[m.j,4]
						m.j = m.j+1
					else
						m.j = -m.j
					endif
				endfor
			else
				for m.i = 1 to m.typxrows
					m.typx[m.i,2] = 0
					m.typx[m.i,3] = 0
				endfor
				m.end = min(m.end, m.start+MAXSEARCHDEPTH-1)
				for m.i = m.start to m.end
					goto m.i
					m.tar = target
					m.j = InternalBinarySearchAscArray(@m.tmp1,m.tar,m.j,m.tmp1rows,1)
					if m.j > 0
						m.type = m.tmp1[m.j,2]
						m.typx[m.type,2] = m.typx[m.type,2] + m.tmp1[m.j,4]
						m.j = m.j+1
					else
						m.j = -m.j
						select (this.registry.alias)
						goto m.tar
						if m.typx[type,1] == 0
							select (m.target.alias)
							loop
						endif
						m.searchType = m.searchTypes.getSearchTypeByIndex(type)
						m.log = max(m.searchType.getMaxOcc()+m.searchType.getOffset(),1) / max(occurs+m.searchType.getOffset(),1)
						if m.searchType.getLog()
							m.typx[type,3] = m.typx[type,3] + max(log(m.log),1)
						else
							m.typx[type,3] = m.typx[type,3] + m.log
						endif
						select (m.target.alias)
					endif
				endfor
				m.sum = 0
				for m.j = 1 to m.typxrows
					if m.typx[m.j,2] > 0
						m.sum = m.sum + m.typx[m.j,2] * (m.fbackinv + m.typx[m.j,4] / (typx[m.j,4] + m.typx[m.j,3]) * m.fback)
					endif
				endfor
			endif
			select (this.result.alias)
			do case
				case m.identityMode == 1 
					replace identity with round(m.sum,6)
				case m.identityMode == 2 
					if m.sum > identity
						replace identity with round(m.sum,6)
					endif
				case m.identityMode == 3 
					if m.sum < identity
						replace identity with round(m.sum,6)
					endif
				case m.identityMode == 4 
					replace identity with round(min(identity+m.sum,100),6)
				case m.identityMode == 5 
					replace identity with round(min((identity+m.sum)/2,100),6)
			endcase
			do case
				case m.scoreMode == 1 
					replace score with m.score
				case m.scoreMode == 2 
					if m.score > score
						replace score with m.score
					endif
				case m.scoreMode == 3 
					if m.score < score
						replace score with m.score
					endif
			endcase
			this.messenger.postProgress()
			skip
		enddo
		return .t.
	endfunc

	function refine(identityMode as Number, compareMode as Number, runFilter as String, destructiveOnly as Boolean)
		local lm, pa, ps1, ps2, ps3, ps4, ps5, ps6, pk1, i, obj
		local searchTypes, joincount
		local searched, found, rcpd, searchField, foundType
		local foundtable, searchtable, identity, str
		local activeJoin, prioritySum, dp
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.ps4 = createobject("PreservedSetting","exact","on")
		m.ps5 = createobject("PreservedSetting","near","off")
		m.ps6 = createobject("PreservedSetting","optimize","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger,"")
		this.messenger.forceMessage("Refining...")
		m.dp = createobject("DynaPara")
		m.dp.dyna("NNCL")
		m.dp.dyna("")
		m.dp.dyna("NN")
		m.dp.dyna("NNL","1,2,4")
		m.dp.dyna("CL","3,4")
		m.dp.dyna("L","4")
		if m.dp.para(@m.identityMode, @m.compareMode, @m.runFilter, @m.destructiveOnly) == 0
			this.messenger.errorMessage("Invalid parametrization.")
			return .f.
		endif
		
		this.confirmChanges()
		if not this.isValid()
			this.messenger.errormessage("SearchEngine is not valid.")
			return .f.
		endif
		if not this.isResultTableValid()
			this.messenger.errormessage("ResultTable is not valid.")
			return .f.
		endif
		if not this.isSearchedSynchronized()
			this.messenger.errormessage("SearchTable is not synchronized.")
			return .f.
		endif
		if not this.isFoundSynchronized()
			this.messenger.errormessage("BaseTable is not synchronized.")
			return .f.
		endif
		if not vartype(m.identityMode) == "N"
			m.identityMode = 1
		endif
		if not vartype(m.compareMode) == "N"
			m.compareMode = 1
		endif
		if m.identityMode < 1 or m.identityMode > 5
			this.messenger.errormessage("Invalid identity mode.")
			return .f.
		endif
		if m.compareMode < 1 or m.compareMode > 3
			this.messenger.errormessage("Invalid compare mode.")
			return .f.
		endif
		m.runFilter = createobject("RunFilter",m.runFilter)
		if not m.runFilter.isValid()
			this.messenger.errormessage("Run filter expression is invalid.")
			return .f.
		endif
		m.activeJoin = this.getActiveJoin(iif(m.destructiveOnly,-1,0))
		m.joinCount = m.activeJoin.getJoinCount()
		if m.joinCount <= 0
			this.messenger.errormessage("No active SearchField.")
			return .f.
		endif
		if m.destructiveOnly
			m.searchTypes = this.searchTypes.filterByDestructive(.t.,.f.)
			m.prioritySum = this.searchTypes.getPrioritySum()
		else
			m.searchTypes = this.searchTypes
			m.prioritySum = 0
		endif
		m.searchTypes = m.searchTypes.consolidateByFields()
		m.searchTypes.recalculateShares(m.prioritySum)
		m.searchTypes.removeDestructivePreparer()
		m.pk1 = createobject("PreservedKey",this.result)
		this.result.setKey()
		m.searched = 0
		m.found = 0
		dimension m.rcpd[m.joinCount]
		dimension m.searchField[m.joinCount]
		dimension m.foundType[m.joinCount]
		for m.i = 1 to m.joinCount
			m.foundType[m.i] = m.activeJoin.getB(m.i)
			m.foundType[m.i] = m.searchTypes.getSearchTypeByField(m.foundType[m.i].getName(),1)
			m.searchField[m.i] = m.activeJoin.getA(m.i)
			m.searchField[m.i] = m.searchField[m.i].getName()
			m.obj = createobject("LRCPD")
			m.obj.setDynamic(m.compareMode == 2)
			m.obj.setWeight(m.foundType[m.i].getShare()/100)
			m.obj.setScope(this.LrcpdScope)
			m.rcpd[m.i] = m.obj
		endfor
		select (this.result.alias)
		if between(m.runFilter.getStart(),1,reccount())
			go m.runFilter.getStart()
		else
			go top
		endif
		if recno() == 1 and searched <= 0
			skip
		endif
		this.messenger.setDefault("Refined")
		this.messenger.startProgress(reccount()-recno()+1)
		this.messenger.startCancel("Cancel Operation?","Refining","Canceled.")
		do while not eof()
			this.messenger.incProgress()
			if this.messenger.queryCancel()
				return .f.
			endif
			if not m.runFilter.inRange(asc(run), recno())
				this.messenger.postProgress()
				skip
				loop
			endif
			if not searched == m.searched
				m.searched = searched
				this.searchCluster.goRecord(m.searched)
				m.searchTable = this.searchCluster.getActiveTable()
				for m.i = 1 to m.joinCount
					m.obj = m.rcpd[m.i]
					m.str = m.foundType[m.i].prepare(m.searchTable.getValueAsString(m.searchField[m.i]))
					if m.compareMode == 3
						m.obj.setB(m.str)
					else
						m.obj.setA(m.str)
					endif
				endfor
			endif
			if not found == m.found
				m.found = found
				this.baseCluster.goRecord(m.found)
				m.foundTable = this.baseCluster.getActivetable()
				for m.i = 1 to m.joinCount
					m.obj = m.rcpd[m.i]
					m.str = m.foundType[m.i].prepare(m.foundTable.getValueAsString(m.foundType[m.i].getField()))
					if m.compareMode == 3
						m.obj.setA(m.str)
					else
						m.obj.setB(m.str)
					endif
				endfor
			endif
			m.identity = 0
			for m.i = 1 to m.joinCount
				m.obj = m.rcpd[m.i]
				m.identity = m.identity+m.obj.compare()
			endfor
			m.identity = min(m.identity*100,100)
			select (this.result.alias)
			do case
				case m.identityMode == 1 && replace
					replace identity with round(m.identity,6)
				case m.identityMode == 2 && maximize
					if m.identity > identity
						replace identity with round(m.identity,6)
					endif
				case m.identityMode == 3 && minimize
					if m.identity < identity
						replace identity with round(m.identity,6)
					endif
				case m.identityMode == 4 && add
					replace identity with round(min(identity+m.identity,100),6)
				case m.identityMode == 5 && average
					replace identity with round(min((identity+m.identity)/2,100),6)
			endcase
			this.messenger.postProgress()
			skip
		enddo
		return .t.
	endfunc
	
	function mirror(runFilter as String)
		local lm, pa, ps1, ps2, ps3, ps4, ps5
		local pos, searched, found, msg, t, stop, run, mirror, cancel, chrrun, idontcare
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","talk","off")
		m.ps4 = createobject("PreservedSetting","exact","on")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Mirroring...")
		this.confirmChanges()
		m.idontcare = this.idontcare()
		if not this.isValid()
			this.messenger.errormessage("SearchEngine is not valid.")
			return .f.
		endif
		if not this.isMono()
			this.messenger.errormessage("SearchEngine is not mono.")
			return .f.
		endif
		m.run = min(max(this.result.getRun(),0)+1,255)
		if not this.isResultTableValid() or m.run == 1
			this.messenger.errormessage("ResultTable is not valid.")
			return .f.
		endif
		m.runFilter = createobject("RunFilter",m.runFilter)
		if not m.runFilter.isValid()
			this.messenger.errormessage("Run filter expression is invalid.")
			return .f.
		endif
		if not this.result.forceKey('ltrim(str(searched))+" "+ltrim(str(found))')
			this.messenger.errormessage("Unable to mirror ResultTable.")
			return .f.
		endif
		m.cancel = .f.
		m.t = createobject("Timing")
		m.chrrun = chr(m.run)
		this.result.select()
		m.stop = reccount()
		m.msg = "/"+ltrim(str(m.stop,12))
		if between(m.runFilter.getStart(),1,reccount())
			m.pos = m.runFilter.getStart()
		else
			m.pos = 2
		endif
		m.mirror = 0
		this.messenger.startCancel("Cancel Operation?","Mirroring","Canceled.")
		do while m.pos <= m.stop
			if this.messenger.queryCancel()
				exit
			endif
			go m.pos
			if not m.runFilter.inRange(asc(run), m.pos)
				this.messenger.postMessage("Mirrored "+ltrim(str(m.pos,12))+m.msg+" ("+ltrim(str(m.mirror,12))+")")
				m.pos = m.pos+1
				loop
			endif
			m.found = found
			m.searched = searched
			if not seek(ltrim(str(m.found))+" "+ltrim(str(m.searched)))
				insert into (this.result.alias) (searched, found, run) values (m.found, m.searched, m.chrrun)
				m.mirror = m.mirror+1
			endif
			this.messenger.postMessage("Mirrored "+ltrim(str(m.pos,12))+m.msg+" ("+ltrim(str(m.mirror,12))+")")
			m.pos = m.pos+1
		enddo
		this.messenger.sneakMessage("Closing...")
		this.result.deleteKey()
		this.result.forceRequiredKeys()
		this.result.useShared()
		if m.mirror > 0 or m.idontcare
			this.result.setRun(m.run)
		endif
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc
	
	function setConfig(item as String, content as String)  && e.g. setConfig("tmpfiles","d:\temp\")
		local lines, line, handle, i, changed, low
		m.lines = createobject("Collection")
		m.item = lower(strtran(m.item," ",""))
		if empty(m.item)
			return
		endif
		if not vartype(m.content) == "C"
			m.content = ""
		endif
		m.content = alltrim(m.content)
		if " " $ m.content and not (like("'*'",m.content) or like('"*"',m.content))
			if '"' $ m.content
				m.content = "'"+m.content+"'"
			else
				m.content = '"'+m.content+'"'
			endif
		endif
		m.handle = FileOpenRead(INHANDLE, this.getEnginePath()+"config.fpw")
		m.changed = .f.
		if m.handle > 0
			m.line = FileReadLF(m.handle)
			do while not (empty(m.line) and FileEOF(m.handle))
				if right(m.line,1) == chr(13)
					m.line = left(m.line,len(m.line)-1)
				endif
				m.low = lower(alltrim(m.line))
				if not (alltrim(getwordnum(m.line,1,"=")) == m.item)
					m.lines.add(m.line)
				else
					if m.changed == .f.
						if not empty(m.content)
							m.lines.add(m.item+"="+m.content)
						endif
						m.changed = .t.
					endif
				endif
				m.line = FileReadLF(m.handle)
			enddo
			FileClose(m.handle)
		endif
		if m.changed == .f. and not empty(m.content)
			m.lines.add(m.item+"="+m.content)
		endif
		if m.lines.count == 0
			erase (this.getEnginePath()+"config.fpw")
			return
		endif
		m.handle = FileOpenWrite(OUTHANDLE, this.getEnginePath()+"config.fpw")
		for m.i = 1 to m.lines.count
			FileWriteCRLF(m.handle,m.lines.item(m.i))
		endfor
		FileClose(m.handle)
	endfunc

	function getConfig(item as String)
		local line, handle, content
		m.item = lower(strtran(m.item," ",""))
		if empty(m.item)
			return ""
		endif
		m.handle = FileOpenRead(INHANDLE, this.getEnginePath()+"config.fpw")
		if m.handle <= 0
			return ""
		endif
		m.content = ""
		m.line = FileReadLF(m.handle)
		do while not (empty(m.line) and FileEOF(m.handle))
			if alltrim(getwordnum(m.line,1,"=")) == m.item and "=" $ m.line
				if right(m.line,1) == chr(13)
					m.line = left(m.line,len(m.line)-1)
				endif
				m.content = alltrim(substr(m.line,at("=",m.line)+1))
				if like("'*'",m.content) or like('"*"',m.content)
					m.content = substr(m.content,2,len(m.content)-2)
					exit
				endif
			endif
			m.line = FileReadLF(m.handle)
		enddo
		FileClose(m.handle)
		return m.content
	endfunc

	function properExt(file as String)
	local ext
		m.file = alltrim(m.file)
		m.ext = lower(rtrim(m.file,"."))
		if not like("*.dbf",m.ext) and not like("*.txt",m.ext) and not like("*\",m.ext) and not like("*/",m.ext) and not like("*:",m.ext)
			if this.isTxtDefault()
				m.file = rtrim(m.file,".")+".txt"
			else
				m.file = rtrim(m.file,".")+".dbf"
			endif
		endif
		return m.file
	endfunc

	function importBase(file as String, decode as Boolean, nomemos as Boolean, fast as Boolean)
		this.setBaseCluster(this.import(m.file, m.decode, m.nomemos, m.fast))
		if this.BaseCluster.getTableCount() <= 0 and not this.messenger.isError()
			this.messenger.errorMessage("BaseTable invalid.")
		endif
		return not this.messenger.isError()
	endfunc
	
	function importSearch(file as String, decode as Boolean, nomemos as Boolean, fast as Boolean)
		this.setSearchCluster(this.import(m.file, m.decode, m.nomemos, m.fast))
		if this.SearchCluster.getTableCount() <= 0 and not this.messenger.isError()
			this.messenger.errorMessage("SearchTable invalid.")
		endif
		return not this.messenger.isError()
	endfunc
	
	function dontcare()
		this.notcaring = .t.
	endfunc
	
	function idontcare(keep as boolean)
	local idc
		if m.keep
			return this.notcaring
		endif
		m.idc = this.notcaring
		this.notcaring = .f.
		return m.idc
	endfunc
	
	function writelog(line as String)
	local handle
		if empty(this.logfile)
			return
		endif
		m.handle = FileOpenAppend(LOGHANDLE,this.logfile)
		FileWriteCRLF(m.handle, m.line)
		FileClose(m.handle)
	endfunc
	
	function execute(method as String, force as Boolean, catch as Boolean)
	local handle, return
		m.method = alltrim(m.method)
		if not empty(this.logfile)
			m.handle = FileOpenAppend(LOGHANDLE,this.logfile)
			FileWriteCRLF(m.handle,iif(m.catch,"catch ","")+iif(m.force,"force ","")+m.method)
			FileClose(m.handle)
		endif
		if m.force
			this.dontcare()
		endif
		m.method = "m.return = this._"+m.method
		&method
		this.idontcare()
		return m.return
	endfunc
		
	function run(file as String, output as String, para as string)
	local line, quiet, force, catch, silent, loud, word, rc, rec
		if not vartype(m.para) == "C"
		 	m.para = ""
		endif
		if not vartype(m.output) == "C"
		 	m.output = ""
		endif
		?? m.file+" "+m.output+" "+m.para
		if not empty(m.output)
			if m.para == "append"
				if FileOpenAppend(OUTHANDLE, m.output) <= 0
					this.messenger.errormessage("Unable to append to file: "+m.output)
					return .f.
				endif
			else
				if FileOpenWrite(OUTHANDLE, m.output) <= 0
					this.messenger.errormessage("Unable to append to file: "+m.output)
					return .f.
				endif
			endif
		endif
		if FileOpenRead(RUNHANDLE, m.file) <= 0
			this.messenger.errormessage("Unable to open file: "+m.file)
			return .f.
		endif
		m.quiet = .f.
		m.line = alltrim(strtran(FileReadLF(RUNHANDLE),chr(13),""))
		m.rec = 1
		do while not FileEOF(RUNHANDLE)
			if left(m.line,1) == "*" or empty(m.line)
				m.line = alltrim(strtran(FileReadLF(RUNHANDLE),chr(13),""))
				m.rec = m.rec+1
				loop
			endif
			m.line = m.line+" "
			m.force = .f.
			m.catch = .f.
			m.silent = .f.
			m.loud = .f.
			m.word = lower(getwordnum(m.line,1))
			if m.word = "exit"
				FileClose(RUNHANDLE)
				FileClose(OUTHANDLE)
				return .t.
			endif
			if m.word == "force"
				m.force = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "catch"
				m.catch = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "silent"
				m.loud = .f.
				m.silent = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "loud"
				m.loud = .t.
				m.silent = .f.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			m.word = lower(getwordnum(m.line,1))
			if m.word == "force"
				m.force = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "catch"
				m.catch = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "silent"
				m.loud = .f.
				m.silent = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "loud"
				m.loud = .t.
				m.silent = .f.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			m.word = lower(getwordnum(m.line,1))
			if m.word == "force"
				m.force = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "catch"
				m.catch = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "silent"
				m.loud = .f.
				m.silent = .t.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			if m.word == "loud"
				m.loud = .t.
				m.silent = .f.
				m.line = ltrim(substr(m.line,at(" ",m.line)+1))
			endif
			m.line = rtrim(m.line)
			if empty(m.line) and (m.silent or m.loud)
				m.quiet = m.silent
			endif
			this.shout(". "+iif(m.silent,"silent ","")+iif(m.loud,"loud ","")+iif(m.catch,"catch ","")+iif(m.force,"force ","")+m.line, (m.quiet or m.silent) and not m.loud)
			if empty(m.line)
				m.line = alltrim(strtran(FileReadLF(RUNHANDLE),chr(13),""))
				m.rec = m.rec+1
				loop
			endif
			m.line = "this._"+m.line
			this.messenger.clearMessage()
			m.rc = .t.
			if m.force
				this.dontcare()
			endif
			try
				&line
			catch
				m.rc = .f.
			endtry
			this.idontcare()
			if this.messenger.isCanceled()
				this.messenger.errorMessage("Canceled in line "+ltrim(str(m.rec,18))+".")
				this.shout(this.messenger.getErrorMessage())
				FileClose(RUNHANDLE)
				FileClose(OUTHANDLE)
				return .f.
			endif
			if m.catch == .f. and (m.rc == .f. or this.messenger.isError())
				this.messenger.errorMessage(ltrim(this.messenger.getErrorMessage()+chr(13)+chr(10)+"Error in line "+ltrim(str(m.rec,18))+".",chr(13)+chr(10)))
				this.shout(this.messenger.getErrorMessage())
				FileClose(RUNHANDLE)
				FileClose(OUTHANDLE)
				return .f.
			endif
			m.line = alltrim(strtran(FileReadLF(RUNHANDLE),chr(13),""))
			m.rec = m.rec+1
		enddo
		FileClose(RUNHANDLE)
		FileClose(OUTHANDLE)
		return .t.
	endfunc
	
	hidden function shout(text, quiet)
		? m.text
		if m.quiet
			return
		endif
		FileWriteCRLF(OUTHANDLE,m.text)
	endfunc

	hidden function import(file as String, decode as Boolean, nomemos as Boolean, fast as Boolean)
	local cluster, table, txt
		this.messenger.clearMessage()
		m.file = alltrim(m.file)
		if this.isTxtDefault()
			m.txt = not like("*.dbf",lower(m.file))
			if not like("*.txt",lower(m.file)) and not file(m.file)
				m.file = rtrim(m.file,".")+".txt"
			endif
		else
			m.txt = like("*.txt",lower(m.file))
		endif
		m.file = createobject("String",m.file)
		m.table = m.file.getFileExtensionChange("")
		if m.txt
			m.cluster = createobject("TableCluster",m.table,1)
			if m.cluster.getTableCount() == 0
				if isdigit(right(m.table,1))
					m.cluster = createobject("TableCluster",m.table+"_1",-1)
				else
					m.cluster = createobject("TableCluster",m.table+"1",-1)
				endif
			endif
		else
			if right(m.table,1) == "1" and (not isdigit(right(m.table,2)) or len(m.table) == 1)
				m.cluster = createobject("TableCluster",m.table,-1)
			else
				m.cluster = createobject("TableCluster",m.table,1)
			endif
		endif
		if m.cluster.getTableCount() > 0
			return m.cluster
		endif
		m.table = m.file.getFileExtensionChange("dbf")
		m.cluster = createobject("InsheetTableCluster",m.table)
		m.cluster.setNomemos(m.nomemos)
		m.cluster.setDecode(m.decode)
		m.cluster.setFast(m.fast)
		m.cluster.setFoxpro(.t.)
		m.cluster.setMessenger(this.messenger)
		if not m.cluster.create(m.file.toString())
			if not this.messenger.isError() 
				this.messenger.errorMessage("Canceled.")
			endif
		endif
		return m.cluster
	endfunc

	hidden function cleanResult(refineMode as Number, runFilter as String, research as Boolean, refineLimit as Number)
		local sql
		if not this.refine(1, m.refineMode, m.runFilter, m.research)
			return .f.
		endif		
		if m.research and not this.research(4, 0, m.runFilter, m.research)
			return .f.
		endif
		this.messenger.forceMessage("Cleaning...")
		m.sql = ""
		m.runFilter = createobject("RunFilter",m.runFilter)
		if m.runFilter.getStart() > 1
			m.sql =  "and recno() >= "+ltrim(str(m.runfilter.getStart(),18))
		endif
		m.runFilter = m.runFilter.getRunFilter("asc(run)")
		if not empty(m.runFilter)
			m.sql = m.sql+" and "+m.runFilter
		endif
		m.sql = "delete from "+this.result.alias+" where identity < "+ltrim(str(m.refineLimit,18,7))+m.sql
		&sql
		if _TALLY > 0
			this.result.pack()
		endif
		this.messenger.forceMessage("")
		return .t.
	endfunc

	hidden function getHeuristics(foundHeuristics as Boolean)
		local pa, ps1, ps2, ps3, ps4, ps5, ps6, pk1
		local heu, type, i, j, k, fa, fb, lexArray
		local sum, old, local, global, fback, fbackinv
		local start, end, target, offset, occurs, searchTable
		local tmp1, tmp2, tmp1rows, tmp2rows, sortrows
		local typx, typxrows, searchType, typeIndex, cnt, log
		local logs, softmax, max
		local index, cluster, tar, found, continuum		
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","near","off")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.ps6 = createobject("PreservedSetting","decimals","6")
		m.pa = createobject("PreservedAlias")
		this.confirmChanges()
		m.fa = this.registry.getFieldStructure("entry")
		m.fb = this.registry.getFieldStructure("occurs")
		m.heu = createobject("BaseCursor","type c(10), "+m.fa.toString()+", "+m.fb.toString()+", local b(6), localsum b(6), global b(6), globalsum b(6)")
		if not m.heu.isValid() or not this.isValid() or not this.isSearchedSynchronized()
			return m.heu
		endif
		m.pk1 = createobject("PreservedKey",this.registry)
		this.registry.forceRegistryKey()
		if not this.searchCluster.goRecord(this.result.getValue("searched"))
			return m.heu
		endif
		m.searchTable = this.searchCluster.getActiveTable()
		if m.foundHeuristics
			dimension m.continuum[1]
			acopy(this.base2reg.continuum,m.continuum)
			m.found = this.result.getValue("found")
			m.cluster = abs(InternalBinarySearchAscArray(@m.continuum,m.found,1,this.base2reg.index.count,1))
			if m.cluster > this.base2reg.index.count
				return m.heu
			endif
			if m.cluster > 1
				m.found = m.found-m.continuum[m.cluster-1]
			endif
			m.index = this.base2reg.index.item(m.cluster)
			m.target = this.base2reg.target.item(m.cluster)
		endif
		m.fback = this.feedback/100
		m.fbackinv = 1 - m.fback
		m.typxrows = this.SearchTypes.getSearchTypeCount()
		dimension m.lexArray[1]
		dimension m.tmp1[MAXWORDCOUNT,9]
		dimension m.tmp2[MAXWORDCOUNT,4]
		dimension m.typx[m.typxrows,4]
		m.tmp2rows = 0
		for m.i = 1 to this.searchFieldJoin.getJoinCount()
			m.fa = this.searchFieldJoin.getA(m.i)
			m.fb = this.searchFieldJoin.getB(m.i)
			m.fa = m.fa.getName()
			m.fb = m.fb.getName()
			m.cnt = this.searchTypes.getSearchTypeCount(m.fb)
			for m.type = 1 to m.cnt
				m.searchType = this.searchTypes.getSearchTypeByField(m.fb,m.type)
				if m.searchType.getShare() > 0
					m.typeIndex = m.searchType.getTypeIndex()
					if alines(m.lexArray,m.searchType.prepare(m.searchTable.getValueAsString(m.fa)),5," ") > 0
						m.end = min(alen(m.lexArray),MAXSEARCHDEPTH) 				
						for m.j = 1 to m.end
							m.tmp2rows = m.tmp2rows+1
							m.tmp2[m.tmp2rows,1] = m.typeIndex
							m.tmp2[m.tmp2rows,2] = this.registry.buildRegistryKey(m.typeIndex, m.lexArray[m.j])
							m.tmp2[m.tmp2rows,3] = m.lexArray[m.j]
						endfor
					endif
				endif
			endfor
		endfor
		if m.tmp2rows <= 0
			return m.heu
		endif
		asort(m.tmp2,2,m.tmp2rows,0)
		m.old = ""
		m.tmp1rows = 0
		for m.i = 1 to m.tmp2rows
			if not m.old == m.tmp2[m.i,2]
				m.old = m.tmp2[m.i,2]
				m.searchType = this.searchTypes.getSearchTypeByIndex(m.tmp2[m.i,1])
				m.tmp1rows = m.tmp1rows+1
				m.tmp1[m.tmp1rows,1] = m.old
				m.tmp1[m.tmp1rows,2] = m.tmp2[m.i,1]
				m.tmp1[m.tmp1rows,3] = m.searchType.getShare()
				m.tmp1[m.tmp1rows,4] = m.searchType.getMaxOcc()
				m.tmp1[m.tmp1rows,5] = m.searchType.getAvgOcc()
				m.tmp1[m.tmp1rows,6] = m.tmp2[m.i,3]
				m.tmp1[m.tmp1rows,8] = not m.foundHeuristics
				m.tmp1[m.tmp1rows,9] = 0		
			endif
		endfor
		if this.relative
			m.sum = 0
			m.old = 0
			for m.i = 1 to m.tmp1rows
				if not m.old == m.tmp1[m.i,2]
					m.sum = m.sum+m.tmp1[m.i,3]
					m.old = m.tmp1[m.i,2]
				endif
			endfor
			for m.i = 1 to m.tmp1rows
				m.tmp1[m.i,3] = m.tmp1[m.i,3]*100/m.sum
			endfor
		endif
		m.old = 0
		m.softmax = 0
		select (this.registry.alias)
		for m.i = 1 to m.tmp1rows
			if not m.old = m.tmp1[m.i,2]
				if m.softmax > 0
					m.softmax = 1/m.max * m.softmax
					for m.k = m.j to m.i-1
						if m.tmp1[m.k,4] > 0
							m.tmp1[m.k,9] = m.tmp1[m.k,4]
							m.tmp1[m.k,4] = exp(m.tmp1[m.k,4]*m.softmax)
						endif
					endfor
				endif
				m.searchType = this.searchTypes.getSearchTypeByIndex(m.tmp1[m.i,2])
				m.offset = m.searchType.getOffset()
				m.logs = m.searchType.getLog()
				m.softmax = m.searchType.getSoftmax()
				m.old = m.tmp1[m.i,2]
				m.j = m.i
				m.max = 1
			endif
			if seek(m.tmp1[m.i,1])
				m.occurs = max(occurs+m.offset,1)
				m.tmp1[m.i,1] = recno()
				m.tmp1[m.i,7] = occurs
				m.log = max(m.tmp1[m.i,4]+m.offset,1)/m.occurs
				if m.logs
					m.tmp1[m.i,4] = max(log(m.log),1)
				else
					m.tmp1[m.i,4] = m.log
				endif
			else
				if this.ignorant
					m.tmp1[m.i,4] = 0
				else
					m.log = max(m.tmp1[m.i,4]+m.offset,1) / max(m.tmp1[m.i,5]+m.offset,1)
					if m.logs
						m.tmp1[m.i,4] = max(log(m.log),1)
					else
						m.tmp1[m.i,4] = m.log
					endif
				endif
				m.tmp1[m.i,1] = 0
				m.tmp1[m.i,7] = 0
			endif
			if m.softmax > 0
				m.max = max(m.max, m.tmp1[m.i,4])
			endif
		endfor
		if m.softmax > 0
			m.softmax = 1/m.max * m.softmax
			for m.k = m.j to m.i-1
				if m.tmp1[m.k,4] > 0
					m.tmp1[m.k,9] = m.tmp1[m.k,4]
					m.tmp1[m.k,4] = exp(m.tmp1[m.k,4]*m.softmax)
				endif
			endfor
		endif
		for m.i = 1 to m.tmp1rows		
			if m.tmp1[m.i,9] <= 0
				m.tmp1[m.i,9] = m.tmp1[m.i,4]
			endif
		endfor
		for m.i = 1 to m.typxrows
			m.typx[m.i,1] = 0
			m.typx[m.i,4] = 0
		endfor
		for m.i = 1 to m.tmp1rows
			m.typx[m.tmp1[m.i,2],1] = m.typx[m.tmp1[m.i,2],1]+m.tmp1[m.i,4]
			m.typx[m.tmp1[m.i,2],4] = m.typx[m.tmp1[m.i,2],4]+m.tmp1[m.i,9]
		endfor
		for m.i = 1 to m.tmp1rows
			if m.typx[m.tmp1[m.i,2],1] == 0
				m.tmp1[m.i,4] = 0
				m.tmp1[m.i,5] = 0
			else			
				m.tmp1[m.i,5] = m.tmp1[m.i,4]/m.typx[m.tmp1[m.i,2],1]
				m.tmp1[m.i,4] = 100*m.tmp1[m.i,5]
				m.tmp1[m.i,5] = m.tmp1[m.i,3]*m.tmp1[m.i,5]
			endif
		endfor
		if m.foundHeuristics
			m.j = 1
			asort(m.tmp1,1,m.tmp1rows,0)
			select (m.index.alias)
			go m.found
			m.start = index
			skip
			m.end = index-1
			select (m.target.alias)
			if this.feedback <= 0 or this.activation > 0
				for m.i = m.start to m.end
					goto m.i
					m.tar = target
					m.j = InternalBinarySearchAscArray(@m.tmp1,m.tar,m.j,m.tmp1rows,1)
					if m.j > 0
						m.tmp1[m.j,8] = .t.
					else
						m.j = -m.j
					endif
				endfor
			else
				m.sortrows = m.tmp1rows
				for m.i = 1 to m.typxrows
					m.typx[m.i,2] = 0
					m.typx[m.i,3] = 0
				endfor
				for m.i = m.start to m.end
					goto m.i
					m.tar = target
					m.j = InternalBinarySearchAscArray(@m.tmp1,m.tar,m.j,m.sortrows,1)
					if m.j > 0
						m.tmp1[m.j,8] = .t.
						m.typx[m.tmp1[m.j,2],2] = m.typx[m.tmp1[m.j,2],2] + m.tmp1[m.j,4]
					else
						m.j = -m.j
						select (this.registry.alias)
						goto m.tar
						if m.typx[type,1] <= 0
							select (m.target.alias)
							loop
						endif
						m.searchType = this.searchTypes.getSearchTypeByIndex(type)
						m.tmp1rows = m.tmp1rows+1
						m.tmp1[m.tmp1rows,2] = type
						m.tmp1[m.tmp1rows,3] = m.searchType.getShare()
						m.tmp1[m.tmp1rows,4] = -1
						m.tmp1[m.tmp1rows,5] = -1
						m.tmp1[m.tmp1rows,6] = entry
						m.tmp1[m.tmp1rows,7] = max(occurs+m.searchType.getOffset(),1)
						m.tmp1[m.tmp1rows,8] = .t.
						m.tmp1[m.tmp1rows,9] = max(m.searchType.getMaxOcc()+m.searchType.getOffset(),1) / m.tmp1[m.tmp1rows,7]
						if m.searchType.getLog()
							m.typx[type,3] = m.typx[type,3] + max(log(m.tmp1[m.tmp1rows,9]),1)
						else
							m.typx[type,3] = m.typx[type,3] + m.tmp1[m.tmp1rows,9]
						endif
						select (m.target.alias)
					endif
				endfor
				for m.i = 1 to m.typxrows
					if m.typx[m.i,2] > 0
						m.typx[m.i,2] = m.typx[m.i,2] - m.typx[m.i,2] * (m.fbackinv + m.typx[m.i,4] / (m.typx[m.i,4] + m.typx[m.i,3]) * m.fback)
					endif
				endfor
				for m.i = 1 to m.tmp1rows
					if m.tmp1[m.i,4] < 0
						m.tmp1[m.i,4] = m.tmp1[m.i,9] / m.typx[m.tmp1[m.i,2],3] * -m.typx[m.tmp1[m.i,2],2]
						m.tmp1[m.i,5] = m.tmp1[m.i,3] * m.tmp1[m.i,4] / 100
					endif
				endfor
			endif
		endif
		for m.i = 1 to m.tmp1rows
			m.tmp1[m.i,1] = str(m.tmp1[m.i,3],25,18)+str(m.tmp1[m.i,2],10,0)+iif(m.tmp1[m.i,4]>=0,"Z","A")+str(abs(m.tmp1[m.i,4]),25,18)
		endfor
		asort(m.tmp1,1,m.tmp1rows,1)
		m.old = 0
		m.local = 0
		m.global = 0
		for m.i = 1 to m.tmp1rows
			if not m.tmp1[m.i,8]
				loop
			endif
			if m.tmp1[m.i,2] == m.old
				m.local = m.local + m.tmp1[m.i,4]
			else
				m.local = m.tmp1[m.i,4]
				m.old = m.tmp1[m.i,2]
				m.searchType = this.searchTypes.getSearchTypeByIndex(m.tmp1[m.i,2])
				m.type = m.searchType.getField()
			endif
			m.global = m.global + m.tmp1[m.i,5]
			insert into (m.heu.alias) values (m.type,m.tmp1[m.i,6],m.tmp1[m.i,7],m.tmp1[m.i,4],m.local,m.tmp1[m.i,5],m.global)
		endfor
		m.heu.goTop()
		return m.heu
	endfunc

	hidden function limitResultArray(ra, rows, activated)
	local limit, i
		SortArrayDesc(m.ra,2,m.rows)
		if m.activated == .f. or this.cutoff <= 0
			if this.zealous and GetArrayElement(m.ra,1,2) < this.limit
				m.limit = GetArrayElement(m.ra,1,2)
			else
				if this.darwin
					m.limit = max(GetArrayElement(m.ra,1,2),this.limit)
				else
					m.limit = this.limit
				endif
			endif
			m.limit = m.limit - TOLERANCE
			m.i = BinarySearchDescArray(m.ra,m.limit,1,m.rows,2)
			if m.i < 0
				m.rows = (-m.i)-1
			else
				m.rows = LimitDescArray(m.ra,m.limit,m.i,m.rows,2,1)
			endif
		endif
		if this.cutoff <= 0 or m.rows <= this.cutoff
			return m.rows
		endif
		m.limit = GetArrayElement(m.ra,this.cutoff+1,2) + TOLERANCE
		if GetArrayElement(m.ra,1,2) <= m.limit
			m.limit = m.limit - TOLERANCE*2 
			return LimitDescArray(m.ra,m.limit,this.cutoff,m.rows,2,1)
		endif
		return LimitDescArray(m.ra,m.limit,1,this.cutoff,2,-1)
	endfunc

	hidden function ExportArray(ar, rows, cols, dbf) && Debug-Funktion f?r externe/interne Arrays
	local sql, ins, i, j, pa, ps, alen
		m.pa = createobject("PreservedAlias")
		m.ps = createobject("PreservedSetting", "safety", "off")
		m.sql = "rec i"
		m.ins = "m.i"
		try
			m.alen = alen(m.ar)
		catch
			m.alen = 0
		endtry
		if m.alen == 0
			for m.j = 1 to m.cols
				m.sql = m.sql+", col"+ltrim(str(m.j))+" b(9)"
				m.ins = m.ins+", GetArrayElement(m.ar,m.i,"+ltrim(str(m.j))+")"
			endfor
		else
			for m.j = 1 to m.cols
				m.sql = m.sql+", col"+ltrim(str(m.j))+" b(9)"
				m.ins = m.ins+", iif(vartype(m.ar[m.i,"+ltrim(str(m.j))+"]) == 'N',m.ar[m.i,"+ltrim(str(m.j))+"],0)"
			endfor
		endif
		m.sql = "create table "+m.dbf+" ("+m.sql+")"
		&sql
		m.ins = "insert into "+alias()+" values ("+m.ins+")"
		for m.i = 1 to m.rows
			&ins
		endfor
	endfunc
	
	hidden function _mirror(runFilter as String)
		return this.mirror(m.runFilter)
	endfunc
	
	hidden function _refine(identityMode as Number, compareMode as Number, runFilter as String, destructiveOnly as Boolean)
		return this.refine(m.identityMode, m.compareMode, m.runFilter, m.destructiveOnly)
	endfunc
	
	hidden function _research(identityMode as Number, scoreMode as Number, runFilter as String, nonDestructiveOnly as Boolean)
		return this.research(m.identityMode, m.scoreMode, m.runFilter, m.nonDestructiveOnly)
	endfunc

	hidden function _search(increment as Number, refineMode as Number, refineForce as Boolean, refineLimit as Number)
		return this.search(m.increment, m.refineMode, m.refineForce, m.refineLimit)
	endfunc

	hidden function _expand(expandMode as Integer)
		return this.expand(m.expandMode)
	endfunc

	hidden function _create(searchTypesDefinition as String)
		return this.create(m.searchTypesDefinition)
	endfunc
	
	hidden function _configtmp(path as String)
		return this.setConfig("tmpfiles", m.path)
	endfunc

	hidden function _importBase(file as String, decode as Boolean, nomemos as Boolean, fast as Boolean)
		return this.importBase(m.file, m.decode, m.nomemos, m.fast)
	endfunc
	
	hidden function _importSearch(file as String, decode as Boolean, nomemos as Boolean, fast as Boolean)
		return this.importSearch(m.file, m.decode, m.nomemos, m.fast)
	endfunc

	hidden function _result(result)
		return this.setResultTable(m.result)
	endfunc

	hidden function _exportGrouped(table, cascade, basekey, low, high, exclusive, runFilter, notext, nosingle)
		return this.groupedExport(m.table, m.cascade, m.basekey, m.low, m.high, m.exclusive, m.runFilter, m.notext, m.nosingle)
	endfunc
	
	hidden function _exportExtended(table, searchKey, foundKey, searchedGroupKey, foundGroupKey, low, high, exclusive, runFilter)
		return this.extendedExport(m.table, m.searchKey, m.foundKey, m.searchedGroupKey, m.foundGroupKey, m.low, m.high, m.exclusive, m.runFilter)
	endfunc
	
	hidden function _exportMeta(table, meta, m.raw, low, high, runFilter)
		return this.metaExport(m.table, m.meta, m.raw, m.low, m.high, m.runFilter)
	endfunc

	hidden function _exportResult(table, shuffle, low, high, runFilter, newrun)
		return this.resultExport(m.table, m.shuffle, m.low, m.high, m.runFilter, m.newrun)
	endfunc

	hidden function _export(table, searchKey, foundKey, low, high, exclusive, runFilter, text)
		return this.export(m.table, m.searchKey, m.foundKey, m.low, m.high, m.exclusive, m.runFilter, m.text)
	endfunc
	
	hidden function _load(slot)
		return this.loadEngine(m.slot)
	endfunc

	hidden function _save(slot)
		return this.saveEngine(m.slot)
	endfunc
	
	hidden function _remove(slot)
		return this.removeEngine(m.slot)
	endfunc
	
	hidden function _erase()
		return this.erase()
	endfunc
	
	hidden function _limit(limit)
		this.setLimit(m.limit)
	endfunc

	hidden function _threshold(threshold)
		this.setThreshold(m.threshold)
	endfunc

	hidden function _cutoff(cutoff)
		this.setCutoff(m.cutoff)
	endfunc
	
	hidden function _feedback(feedback)
		this.setFeedback(m.feedback)
	endfunc
	
	hidden function _activation(activation)
		this.setActivation(m.activation)
	endfunc

	hidden function _relative(relative)
		m.relative = iif(m.relative,.t.,.f.) && invalid type forces exception
		this.setRelative(m.relative)
	endfunc
	
	hidden function _darwinistic(darwin)
		m.darwin = iif(m.darwin,.t.,.f.) && invalid type forces exception
		this.setDarwinistic(m.darwin)
	endfunc
	
	hidden function _ignorant(ignorant)
		m.ignorant = iif(m.ignorant,.t.,.f.) && invalid type forces exception
		this.setIgnorant(m.ignorant)
	endfunc
	
	hidden function _zealous(zealous)
		m.zealous = iif(m.zealous,.t.,.f.) && invalid type forces exception
		this.setZealous(m.zealous)
	endfunc
	
	hidden function _scope(scope)
		this.setLrcpdScope(m.scope)
	endfunc

	hidden function _depth(depth)
		this.setDepth(m.depth)
	endfunc
	
	hidden function _join(field, searchField)
		if not this.joinSearchField(m.field, m.searchField)
			throw
		endif
		return .t.
	endfunc

	hidden function _unjoin(field, searchField))
		if not this.unjoinSearchField(m.field, m.searchField)
			throw
		endif
		return .t.
	endfunc
	
	hidden function _types(searchtypes)
		if not this.mergeSearchTypes(m.searchtypes)
			throw
		endif
		return .t.
	endfunc

	hidden function _show()
		this.shout(strtran(rtrim(this.toString(),chr(10)),chr(10),chr(13)+chr(10))) 
	endfunc	
	
	hidden function _say(hello)
		if not vartype(m.hello) == "C"
			throw
		endif
		this.shout(m.hello)
	endfunc
	
	hidden function _wait(seconds)
		m.seconds = m.seconds+0 && invalid type forces exception
		wait "Waiting..." timeout m.seconds
	endfunc

	hidden function _message(text)
		messagebox(m.text,64,"SearchEngine")
	endfunc
	
	hidden function _time()
		this.shout(strtran(ttoc(datetime(),3),"T"," "))
	endfunc

	hidden function _info(info)
		this.setInfo(strtran(m.info,"<br>",chr(10)))
	endfunc

	hidden function _note(info)
		this.setInfo(rtrim(this.getInfo(),chr(10))+chr(10)+strtran(m.info,"<br>",chr(10)))
	endfunc

	hidden function _slot()
		this.shout(this.getSlot())
	endfunc
	
	hidden function _run()
		this.shout(ltrim(str(max(this.result.getRun(),0),18)))
	endfunc

	hidden function _version()
		this.shout(this.getVersion())
	endfunc
enddefine
