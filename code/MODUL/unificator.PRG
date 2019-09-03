*=========================================================================*
*	Modul: 		unicator.prg
*	Date:		2017.02.07
*	Author:		Thorsten Doherr
*	Required: 	custom
*	Function:	The JoinTable is the link between a base table and the
*				UniTable. The UniTable contains the unified records of
*				the base table. During unification only the first occurence
*				of each combination of specific fields in the base table
*				will be transfered into the UniTable using a unified key.
*				The other records only get a reference in the JoinTable.
*               An existing UniTable can be expanded if the specific fields
*               were omitted and the base table has a matching structure.
*				Fields in the uni table will automatically be normized
*				if the "normize" Parameter is true (.t.)
*=========================================================================*

define class JoinTable as BaseTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("basekey, unikey")
		this.setRequiredKeys("basekey; unikey")
		this.recastRequirements()
	endfunc

	function create(base, baseKey, uni, uniKey)
		local f, struc
		if vartype(m.base) == "C"
			m.base = createobject("BaseTable",m.base)
		endif
		if not m.base.hasField(m.baseKey)
			return .f.
		endif
		if vartype(m.uni) == "C"
			m.uni = createobject("BaseTable",m.uni)
		endif
		if not m.uni.hasField(m.uniKey)
			return .f.
		endif
		m.f = m.base.getFieldStructure(m.baseKey)
		m.struc = "basekey "+m.f.getDefinition()
		m.f = m.uni.getFieldStructure(m.uniKey)
		m.struc = m.struc+", unikey "+m.f.getDefinition()
		this.setRequiredTableStructure(m.struc)
		return BaseTable::create()
	endfunc
enddefine

define class UniTable as BaseTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("unikey i")
		this.setRequiredKeys("unikey")
	endfunc

	function isExpandable(base)
		local i, j, struc, f, fb
		if not this.isValid()
			return .f.
		endif
		if vartype(m.base) == "C"
			m.base = createobject("TableStructure",m.base)
		else
			m.base = m.base.getTableStructure()
		endif			
		if not m.base.isValid()
			return .f.
		endif
		m.struc = this.getTableStructure()
		m.struc = m.struc.getStructureWithout("unikey")
		m.base = m.base.getStructureWith(m.struc)
		return m.base.getFieldCount() == m.struc.getFieldCount() and m.base.checkStructure(m.struc)
	endfunc

	function build(base, join, key, struc, normize)
		local para, ps1, ps2, ps3, ps4, pa, lm, expand
		local n, chr0, exp, keyexp, lex, i, f, ck, subkey, temp
		local cnt, ind, sql, eval, newkey, ins, val, memo
		local usenorm, t, rg, rgj, oldkey, pk, ok
		local expval, unikey, basekey, msg
		m.para = parameters()
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","safety","off")
		m.ps4 = createobject("PreservedSetting","exact","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger,"")
		this.messenger.forceMessage("Unifying...")
		if vartype(m.struc) == "L"
			if m.struc == .t. and m.para < 5 
				m.normize = .t.
			endif
			m.struc = this.getTableStructure()
			m.struc = m.struc.getStructureWithout("UNIKEY")
			m.expand = .t.
		else
			if vartype(m.struc) == "C"
				m.struc = createobject("TableStructure",m.struc)
			endif
			m.expand = .f.
		endif
		if m.struc.getFieldIndex("UNIKEY") > 0
			this.messenger.errormessage('"UNIKEY" is a reserved fieldname.')
			return .f.
		endif
		if vartype(m.base) == "C"
			m.base = createobject("BaseTable",m.base)
		endif
		if not m.base.isValid()
			this.messenger.errormessage("BaseTable is not valid.")
			return .f.
		endif
		if not m.base.hasField(m.key)
			this.messenger.errormessage("Key is not valid.")
			return .f.
		endif
		if not m.struc.isValid() or not m.struc.checkNames(m.base)
			if m.expand
				this.messenger.errormessage("Expansion of UniTable is not possible.")
			else
				this.messenger.errormessage("Selected Structure is not valid.")
			endif
			return .f.
		endif
		m.struc = m.struc.recast(m.base.getTableStructure(),.t.)
		if m.expand
			if this.isCreatable() or not this.isExpandable(m.struc)
				this.messenger.errormessage("Expansion of UniTable is not possible.")
				return .f.
			endif
		else
			if not this.create("unikey i, "+m.struc.toString())
				this.messenger.errormessage("UniTable is not creatable.")
				return .f.
			endif
			this.setRequiredTableStructure("unikey i, "+m.struc.toString())
		endif
		if vartype(m.join) == "C"
			m.join = createobject("JoinTable",m.join)
		endif
		m.join.erase()
		if not m.join.create(m.base,m.key,this,"unikey")
			this.messenger.errormessage("JoinTable is not creatable.")
			return .f.
		endif
		if not m.join.useExclusive()
			this.messenger.errormessage("Exclusive usage of JoinTable permitted.")
			return .f.
		endif
		if not this.useExclusive()
			this.messenger.errormessage("Exclusive usage of UniTable permitted.")
			return .f.
		endif
		m.join.deleteKey()
		m.ck = createobject("ComposedKey",m.join,"basekey, unikey")
		if not m.join.forceKey(m.ck.getexp(),"candidate")
			this.messenger.errormessage("Unable to index JoinTable.")
			return .f.
		endif
		if m.normize
			m.n = createobject("StringNormizer")
		endif
		m.chr0 = chr(0)
		m.subKey = .t.
		m.temp = createobject("UniqueAlias", .T.)
		m.exp = ""
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if m.f.getType() == "M"
				m.exp = ""
				exit
			endif
			m.exp = m.exp+m.f.keyConverter(m.f.getName())+'+CHR(0)+'
		endfor
		if not empty(m.exp)
			m.exp = left(m.exp,len(m.exp)-8)
			m.subKey = not this.forceKey(m.exp)
		endif
		if m.subkey
			m.cnt = 0
			m.ind = 0
			if m.struc.getFieldCount() == 1
				m.ind = 1
			else
				for m.i = 1 to m.struc.getFieldCount()
					m.f = m.struc.getFieldStructure(m.i)
					this.messenger.forceMessage("Checking ("+lower(m.f.getName())+") ...")
					if m.f.getType() == "M"
						m.sql = "select distinct cast(len(alltrim("+m.f.getName()+")) as i) as len from "+m.base.alias+" into cursor "+m.temp.alias
					else
						m.sql = "select 1 from "+m.base.alias+" group by "+m.f.getName()+" into cursor "+m.temp.alias
					endif
					&sql
					if _TALLY > m.cnt
						m.cnt = _TALLY
						m.ind = m.i
						if m.cnt / m.base.reccount() >= 0.90
							exit
						endif
					endif
				endfor
			endif
			if m.ind == 0
				this.messenger.errormessage("Unable to index UniTable.")
				return .f.
			endif
			m.f = m.struc.getFieldStructure(m.ind)
			m.exp = m.f.getName()
			m.keyexp = "?1"
			m.sql = ""
			if inlist(m.f.getType(),"C","M")
				if m.f.getType() == "M" or m.f.getSize() > 230
					m.keyexp = "left(rtrim(?1),115)+right(rtrim(?1),115)"
					if m.normize
						m.sql = "select unikey from "+this.alias+" where "+strtran(m.keyexp,"?1",this.alias+"."+m.exp)+" == "+strtran(m.keyexp,"?1","m.lex["+ltrim(str(m.ind))+"]")
					endif
					m.ind = 0
				else
					if m.f.getType() == "C" and m.normize
						m.sql = "select unikey from "+this.alias+" where "+strtran(m.keyexp,"?1",this.alias+"."+m.exp)+" == left(m.lex["+ltrim(str(m.ind))+"],"+ltrim(str(m.f.getSize()))+")"
					endif
				endif
			endif
			if empty(m.sql)
				m.sql = "select unikey from "+this.alias+" where "+strtran(m.keyexp,"?1",this.alias+"."+m.exp)+" == "+strtran(m.keyexp,"?1",m.base.alias+"."+m.exp)
			endif
			for m.i = 1 to m.struc.getFieldCount()
				m.f = m.struc.getFieldStructure(m.i)
				if not m.i == m.ind
					if m.normize and inlist(m.f.getType(),"C","M")
						if m.f.getType() == "C"
							m.sql = m.sql+" and "+this.alias+"."+m.f.getName()+" == left(m.lex["+ltrim(str(m.i))+"],"+ltrim(str(m.f.getSize()))+")"
						else
							m.sql = m.sql+" and "+this.alias+"."+m.f.getName()+" == m.lex["+ltrim(str(m.i))+"]"
						endif
					else
						m.sql = m.sql+" and "+this.alias+"."+m.f.getName()+" == "+m.base.alias+"."+m.f.getName()
					endif
				endif
			endfor
			m.sql = m.sql+" into cursor "+m.temp.alias
			m.exp = strtran(m.keyexp,"?1",m.exp)
			this.messenger.forceMessage("Indexing ("+lower(m.exp)+") ...")
			if not this.forceKey(m.exp)
				this.messenger.errormessage("Unable to index UniTable.")
				return .f.
			endif
		endif
		if m.normize
			m.eval = ""
			for m.i = 1 to m.struc.getFieldCount()
				m.f = m.struc.getFieldStructure(m.i)
				if inlist(m.f.getType(),"C","M")
					if m.f.getType() == "C"
						m.eval = m.eval+'left(m.n.normize('+m.f.keyConverter(m.f.getName())+'),'+ltrim(str(m.f.getSize()))+')+CHR(0)+'
					else
						m.eval = m.eval+'m.n.normize('+m.f.keyConverter(m.f.getName())+')+CHR(0)+'
					endif
				else
					m.eval = m.eval+m.f.keyConverter(m.f.getName())+'+CHR(0)+'
				endif
			endfor
			m.eval = left(m.eval,len(m.eval)-8)
		else
			m.eval = m.exp
		endif
		select max(unikey) as maxkey from (this.alias) into cursor (m.temp.alias)
		m.newkey = nvl(maxkey,0)+1
		m.ins = ""
		m.val = ""
		m.usenorm = .f.
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if m.normize and inlist(m.f.getType(),"C","M")
				m.val = m.val+", m.lex["+ltrim(str(m.i))+"]"
				m.usenorm = .t.
			else
				m.val = m.val+", "+m.base.alias+"."+m.f.getName()
			endif
			m.ins = m.ins+", "+m.f.getName()
		endfor
		m.val = substr(m.val,3)
		m.ins = substr(m.ins,3)
		m.ins = "insert into "+this.alias+" (unikey, "+m.ins+") values (m.newkey, "+m.val+")"
		m.t = createobject("Timing")
		m.rg = createobject("ReindexGuard",this)
		m.rgj = createobject("ReindexGuard",m.join)
		m.pk = createobject("PreservedKey",m.base)
		m.ok = .t.
		m.oldkey = 0
		m.base.setKey()
		dimension m.lex[1]
		this.messenger.start()
		select (m.base.alias)
		m.msg = "Unified "+proper(strtran(m.base.getPureName()," ","_"))+" "
		scan
			if m.t.elapsed() > 2
				m.t.start()
				if inkey("H") == 27
					m.rg.stop()
					m.rgj.stop()
					if messagebox("Cancel Operation?",292,"UniTable") == 6
						m.ok = .f.
						exit
					endif
					m.rg.go()
					m.rgj.go()
				endif
			endif
			if m.subkey = .f. or m.usenorm == .t.
				m.expval = evaluate(m.eval)
				if m.usenorm = .t.
					alines(m.lex,m.expval,2,m.chr0)
				endif
			endif
			if m.subKey
				&sql
				if _TALLY == 0
					&ins
					m.unikey = m.newkey
					m.newkey = m.newkey+1
				else
					m.uniKey = evaluate(m.temp.alias+".unikey")
				endif
				select (m.base.alias)
			else
				if not seek(m.expval,this.alias)
					&ins
					m.unikey = m.newkey
					m.newkey = m.newkey+1
				else
					m.uniKey = evaluate(this.alias+".unikey")
				endif
			endif
			m.baseKey = evaluate(m.key)
			try
				insert into (m.join.alias) (baseKey, uniKey) values (m.baseKey, m.uniKey)
			catch
			endtry
			m.rg.tryReindex()
			m.rgj.tryReindex()
			this.messenger.postMessage(m.msg+ltrim(str(recno()))+"/"+ltrim(str(reccount())))
		endscan
		this.messenger.forceMessage(m.msg+ltrim(str(recno()))+"/"+ltrim(str(reccount())))
		this.messenger.forceMessage("Closing...")
		if m.ok == .f.
			this.erase()
			m.join.erase()
		else
			m.ok = this.deleteKey(m.exp) and m.ok
			m.ok = m.join.deleteKey() and m.ok
			m.ok = this.forceRequiredKeys() and m.ok
			m.ok = m.join.forceRequiredKeys() and m.ok
			m.ok = this.reindex() and m.ok
		endif
		this.messenger.forceMessage("")
		return m.ok
	endfunc
enddefine

define class UniCluster as TableCluster
	function cunify(baseCluster, joinCluster, key, struc, normize)
	local pa, ps1, ps2, ps3, t, ok
	local i, unifirst, joinfirst, base, uni, join, mess
	local j, tmp, sql, upd, unij, joinj, f, offset
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		if vartype(m.baseCluster) == "C"
			m.baseCluster = createobject("TableCluster",m.baseCluster,-1,.t.)
		endif
		if m.baseCluster.getTableCount() == 0
			this.messenger.errorMessage("BaseCluster is empty.")
			return .f.
		endif
		if this.getTableCount() > 0 and not this.isCreatable() and not this.erase()
			this.messenger.errorMessage("Unable to clear UniTable cluster.")
			return .f.
		endif
		if vartype(m.joinCluster) == "C"
			m.joinCluster = createobject("TableCluster",m.joinCluster,-1,.t.)
		endif
		if m.joinCluster.getTableCount() > 0 and not m.joinCluster.isCreatable() and not m.joinCluster.erase()
			this.messenger.errorMessage("Unable to clear JoinTable cluster.")
			return .f.
		endif
		m.joinCluster.rebuild()
		this.rebuild()
		m.unifirst = this.getFirst()-1
		m.joinfirst = m.joinCluster.getFirst()-1
		m.t = createobject("Timing")
		m.ok = .t.
		for m.i = 1 to m.baseCluster.getTableCount()
			if m.t.elapsed() > 1
				m.t.start()
				if inkey("H") == 27
					if messagebox("Cancel Operation?",292,"Cluster Unify") == 6
						this.messenger.forceMessage("Canceling...")
						m.ok = .f.
						exit
					endif
				endif
			endif
			m.base = m.baseCluster.getTable(m.i)
			m.uni = createobject("UniTable",this.createTableName(m.unifirst+m.i))
			m.join = createobject("JoinTable",m.joinCluster.createTableName(m.joinfirst+m.i))
			m.uni.setMessenger(this.messenger)
			m.join.setMessenger(this.messenger)
			if not m.uni.build(m.base,m.join,m.key,m.struc,m.normize)
				m.ok = .f.
				m.mess = m.uni.getMessenger()
				if empty(m.mess.getMessage())
					this.messenger.errorMessage("Unable to create UniCluster.")
				else
					this.messenger.errorMessage(m.mess.getMessage())
				endif
				exit
			endif
		endfor
		if m.ok == .f.
			m.i = 1
		endif
		m.uni = createobject("TableCluster",this.createTableName(m.unifirst+m.i),-1,.t.)
		m.uni.call('erase()')
		m.join = createobject("TableCluster",m.joinCluster.createTableName(m.joinfirst+m.i),-1,.t.)
		m.join.call('erase()')
		m.joinCluster.rebuild()
		this.build(this.path+this.start,m.i-1,.t.)
		if this.getTableCount() == 0 or m.ok == .f.
			return .f.
		endif
		if this.getTableCount() == 1
			return .t.
		endif
		this.call('deleteKey()')
		m.joinCluster.call('deleteKey()')
		m.tmp = createobject("UniqueAlias",.t.)
		m.struc = this.getTableStructure()
		m.struc = m.struc.getStructureWithout("Unikey")
		m.sql = ""
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			m.sql = m.sql+" and a."+m.f.getName()+" == b."+m.f.getName()
		endfor
		m.sql = substr(m.sql,6)
		m.sql = "select a.unikey, b.unikey as oldkey from (m.uni.alias) a, (m.unij.alias) b where b.unikey > 0 and "+m.sql+" into cursor (m.tmp.alias)"
		m.uni = this.getTable(1)
		m.offset = m.uni.reccount()
		for m.i = 2 to this.getTableCount()
			m.uni = this.getTable(m.i)
			m.join = m.joinCluster.getTable(m.i)
			this.messenger.forceMessage("Adjusting "+proper(m.uni.getPureName()))
			if m.t.elapsed() > 1
				m.t.start()
				if inkey("H") == 27
					if messagebox("Cancel Operation?",292,"Cluster Unify") == 6
						this.messenger.forceMessage("Canceling...")
						this.call('erase()')
						m.joinCluster.call('erase()')
						return .f.
					endif
				endif
			endif
			update (m.uni.alias) set unikey = unikey+m.offset
			update (m.join.alias) set unikey = unikey+m.offset
			m.offset = m.offset+m.uni.reccount()
		endfor
		m.offset = 0
		for m.i = 1 to this.getTableCount()
			m.uni = this.getTable(m.i)
			m.join = m.joinCluster.getTable(m.i)
			if m.i > 1
				this.messenger.forceMessage("Adjusting "+proper(m.uni.getPureName()))
				if m.t.elapsed() > 1
					m.t.start()
					if inkey("H") == 27
						if messagebox("Cancel Operation?",292,"Cluster Unify") == 6
							this.messenger.forceMessage("Canceling...")
							this.call('erase()')
							m.joinCluster.call('erase()')
							return .f.
						endif
					endif
				endif
				delete from (m.uni.alias) where unikey == 0
				m.uni.pack()
				select unikey as oldkey, unikey from (m.uni.alias) into cursor (m.tmp.alias) readwrite
				update (m.tmp.alias) set unikey = recno()+m.offset
				index on oldkey tag oldkey				
				m.upd = "update "+m.uni.alias+" set unikey = "+m.tmp.alias+".unikey from "+m.tmp.alias+" where "+m.tmp.alias+".oldkey == "+m.uni.alias+".unikey"
				&upd
				m.upd = "update "+m.join.alias+" set unikey = "+m.tmp.alias+".unikey from "+m.tmp.alias+" where "+m.tmp.alias+".oldkey == "+m.join.alias+".unikey"
				&upd				
			endif
			m.offset = m.offset+m.uni.reccount()
			for m.j = m.i+1 to this.getTableCount()
				if m.t.elapsed() > 1
					m.t.start()
					if inkey("H") == 27
						if messagebox("Cancel Operation?",292,"Cluster Unify") == 6
							this.messenger.forceMessage("Canceling...")
							this.call('erase()')
							m.joinCluster.call('erase()')
							return .f.
						endif
					endif
				endif
				m.unij = this.getTable(m.j)
				m.joinj = m.joinCluster.getTable(m.j)
				this.messenger.forceMessage("Unifying "+proper(m.unij.getPureName())+" into "+proper(m.uni.getPureName()))
				&sql
				index on oldkey tag oldkey
				m.upd = "update "+m.unij.alias+" set unikey = 0 where exists (select oldkey from "+m.tmp.alias+" where "+m.unij.alias+".unikey == "+m.tmp.alias+".oldkey)"
				&upd
				m.upd = "update "+m.joinj.alias+" set unikey = "+m.tmp.alias+".unikey from "+m.tmp.alias+" where "+m.tmp.alias+".oldkey == "+m.joinj.alias+".unikey"
				&upd
			endfor
		endfor
		this.messenger.forceMessage("Cleaning...")
		this.compress()
		m.joinCluster.compress()
		this.call('forcekey("unikey")')
		m.joinCluster.call('forcekey("unikey")')
		m.joinCluster.call('forcekey("basekey")')
		this.messenger.forceMessage("")
		return .t.
	endfunc
enddefine
				
				
		