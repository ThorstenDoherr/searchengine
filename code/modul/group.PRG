*=========================================================================*
*   Modul:      group.prg
*   Date:       2020.09.07
*   Author:     Thorsten Doherr
*   Required:   custom.prg
*               ParallelFox classes
*   Function:   Clusters network tables by applying nested cascaded traversal
*=========================================================================*
function mp_traverse(from as Integer, to as Integer)
	mp_bracket(@m.from, @m.to)
	_screen.global1.useShared()
	_screen.global2.useShared()
	_screen.global3.useShared()
	_screen.main.traversing(m.from, m.to, _screen.global1, _screen.global2, _screen.global3, _screen.messenger)
	_screen.global1.close()
	_screen.global2.close()
	_screen.global3.close()
endfunc

define class Cascade as Custom
	filter = ""
	blackhole = 0
	valid = .f.
	
	function init(filter as String)
	local lexArray, subarray, lexcnt, i, expression, activation, pa, blackhole, cnt
		m.pa = createobject("PreservedAlias")
		m.blackhole = .f.
		this.filter = createobject("Collection")
		this.valid = .f.
		if not vartype(m.filter) == "C" or empty(m.filter)
			this.valid = .t.
			return
		endif
		dimension m.lexArray[1]
		dimension m.subArray[1]
		m.lexcnt = alines(m.lexArray,lower(m.filter),5,",")
		m.cnt = 0
		for m.i = 1 to m.lexcnt
			if alines(m.subArray,m.lexArray[m.i],5,"@") != 2
				if m.blackhole = .f. and (val(m.subArray[1]) > 0 or m.subArray[1] == "0" or rtrim(rtrim(m.subArray[1],"0"),".") == "0")
					this.blackhole = val(m.subArray[1])
					m.blackhole = .t.
					loop
				endif
				return
			endif
			m.expression = m.subArray[1]
			m.cnt = m.cnt + 1
			m.activation = val(m.subArray[2])
			if m.activation == 0 
				if not (m.subArray[2] == "0" or rtrim(rtrim(m.subArray[2],"0"),".") == "0") or m.cnt > 1
					return
				endif
			endif
			this.filter.add(createobject("FilterEnvelope", m.expression, m.activation))
		endfor
		this.valid = .t.
	endfunc
	
	function isValid(struc as TableStructure)
	local tmp, def, sql, i, ok, exp, pa
		if this.valid == .f.
			return .f.
		endif
		if vartype(m.struc) == "C" 
			m.struc = createobject("TableStructure",m.struc)
		endif
		if not m.struc.isValid()
			return .f.
		endif
		m.pa = createobject("PreservedAlias")
		m.tmp = createobject("UniqueAlias",.t.)
		m.def = createobject("UniqueAlias",.t.)
		m.sql = "select "+m.struc.getSQLDefault()+" from "+m.tmp.alias+" into cursor "+m.def.alias
		&sql
		for m.i = 1 to this.filter.count
			m.exp = this.filter.item(m.i)
			m.exp = m.exp.expression
			if "m." $ lower(m.exp) or lower(m.def.alias)+"." $ lower(m.exp) or ";" $ m.exp
				return .f.
			endif
			m.sql = "select * from "+m.def.alias+" where "+m.exp+" into cursor "+m.tmp.alias
			m.ok = .t.
			try
				&sql
			catch
				m.ok = .f.
			endtry
			if m.ok == .f.
				return .f.
			endif
		endfor
		return .t.
	endfunc
	
	function getFilter()
		return this.filter
	endfunc
	
	function setBlackhole(blackhole as Integer)
		this.blackhole = m.blackhole
	endfunc
	
	function getBlackhole()
		return this.blackhole
	endfunc
		
	function toString()
	local i, str, filter
		m.str = ""
		if this.blackhole > 0
			m.str = m.str + transform(this.blackhole)+", "
		endif
		for m.i = 1 to this.filter.count
			m.filter = this.filter.item(m.i)
			m.str = m.str+m.filter.toString()+", "
		endfor
		return rtrim(rtrim(m.str),",")
	endfunc
enddefine

define class NestedCascade as Custom
	hidden cascade

	function init(cascade as String)
		this.defineCascade(m.cascade)
	endfunc

	function defineCascade(cascade as String, add as Boolean)
	local lex, lexcnt, i, cnt
		dimension m.lex[1]
		if not m.add
			this.cascade = createobject("Collection")
		endif
		m.cnt = this.cascade.count
		if vartype(m.cascade) == "C"
			m.lexcnt = alines(m.lex,m.cascade,5,";")
			for m.i = 1 to m.lexcnt
				this.cascade.add(createobject("Cascade",m.lex[m.i]))
			endfor
		else
			if vartype(m.cascade) == "O"
				this.cascade.add(m.cascade)
			endif
		endif
		return this.cascade.count > m.cnt
	endfunc
	
	function addCascade(cascade as String)
		return this.defineCascade(m.cascade,.t.)
	endfunc
	
	function getCascade()
		return this.cascade
	endfunc
	
	function clearCascade()
		this.cascade = createobject("Collection")
	endfunc
	
	function isValid(struc as FieldStructure)
	local i, cascade
		if this.cascade.count == 0
			return .t.
		endif
		if vartype(m.struc) == "C"
			m.struc = createobject("TableStructure",m.struc)
		endif
		for m.i = 1 to this.cascade.count
			m.cascade = this.cascade.item(m.i)
			if not m.cascade.isValid(m.struc)
				return .f.
			endif
		endfor
		return .t.
	endfunc
	
	function toString()
	local i, str, cascade
		m.str = ""
		for m.i = 1 to this.cascade.count
			m.cascade = this.cascade.item(m.i)
			m.str = m.str+m.cascade.toString()+"; "
		endfor
		return rtrim(rtrim(m.str),";")
	endfunc
enddefine

define class CascadeTable as BaseTable
	hidden cascade
	pfw = .f.
	
	function init(table)
		BaseTable::init(m.table)
		this.cascade = createobject("NestedCascade")
		this.pfw = createobject("ParallelFoxWrapper")
	endfunc
	
	function setCascade(cascade as NestedCascade)
		this.cascade = m.cascade
	endfunc

	function defineCascade(cascade as String, add as Boolean)
		this.cascade.defineCascade(m.cascade, m.add)
	endfunc

	function addCascade(cascade as String)
		return this.defineCascade(m.cascade,.t.)
	endfunc
	
	function getCascade()
		return this.cascade.getCascade()
	endfunc
	
	function cascadeValid(struc as FieldStructure)
		return this.cascade.isValid(m.struc)
	endfunc
	
	function clearCascade()
		this.cascade.clearCascade()
	endfunc

	function setPFW(pfw as Object)
		this.pfw = iif(vartype(m.pfw) == "O", m.pfw, createobject("ParallelFoxWrapper"))
	endfunc
	
	function getPFW()
		return this.pfw
	endfunc
	
	function mp(mp as Integer)
		return this.pfw.mp(m.mp)
	endfunc
	
	function create(table, fromField as String, toField as String, grouping as String)
	local psl, pa, lm, nested
	local cluster, cascade, trunc, prefix, clu, clucol, rest, group, next, sql, i
		m.psl = createobject("PreservedSettingList")
		m.psl.set("escape","off")
		m.psl.set("talk","off")
		m.psl.set("safety","off")
		m.psl.set("exclusive","on")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Cascading...")
		if not this.isCreatable()
			this.messenger.errorMessage("ClusterTable is not creatable.")
			return .f.
		endif
		if vartype(m.grouping) != "C"
			m.grouping = "max"
		else
			m.grouping = lower(alltrim(m.grouping))
		endif
		if not inlist(m.grouping,"max","min","avg")
			this.messenger.errorMessage("Invalid grouping.")
			return .f.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Table is not valid.")
			return .F.
		endif
		if not this.cascadeValid(m.table.getTableStructure())
			this.messenger.errorMessage("Cascade and table do not match.")
			return .F.
		endif
		m.fromField = alltrim(m.fromField)
		m.toField = alltrim(m.toField)
		m.nested = this.getCascade()
		if m.nested.count <= 1
			m.cluster = createobject("ClusterPathTable",this.dbf)
			m.cluster.erase()
			m.cluster.setPFW(this.pfw)
			m.cluster.setMessenger(this.messenger)
			m.cascade = m.nested.item(1)
			if not m.cluster.create(m.table, m.fromField, m.toField, m.cascade)
				return .f.
			endif
			m.cluster.close()
			this.open()
			return .t.
		endif
		m.trunc = this.getPath()+this.getPureName()
		m.prefix = this.messenger.getPrefix()
		m.clu = createobject("UniqueAlias",.t.)
		m.clucol = createobject("Collection")
		m.rest = m.table.getTableStructure()
		m.rest = m.rest.getStructureWithout(m.fromField+","+m.toField)
		if m.rest.getFieldCount() > 0
			m.group = ", "+m.rest.getExpressionList(m.grouping+"(a.*) as *")
			m.rest = ", "+m.rest.getFieldList("a")
		else
			m.group = ""
			m.rest = ""
		endif
		for m.i = 1 to m.nested.count
			this.messenger.setPrefix(ltrim(rtrim(m.prefix)+"[Cascade "+ltrim(str(m.i,10)))+"] ")
			this.messenger.forceMessage("")
			m.cluster = createobject("ClusterPathTable",m.trunc+"__cascade"+ltrim(str(m.i,10)))
			m.cluster.erase()
			m.cluster.setCursor(.t.)
			m.cluster.setPFW(this.pfw)
			m.cluster.setMessenger(this.messenger)
			m.cascade = m.nested.item(m.i)
			m.clucol.add(m.cluster)
			if not m.cluster.create(m.table,m.fromField,m.toField,m.cascade)
				this.messenger.setPrefix(m.prefix)
				return .f.
			endif
			if m.i < m.nested.count
				this.messenger.forceMessage("Converting network") 
				m.next = createobject("BaseTable",m.trunc+"__path"+ltrim(str(m.i+1,10)))
				m.next.erase()
				m.next.setCursor(.t.)
				m.cluster.forceKey("to")
				m.sql = 'select b.from as '+m.fromfield+', a.'+m.toField+m.rest+' from '+m.table.alias+' a, '+m.cluster.alias+' b where a.'+m.fromfield+' == b.to into cursor '+m.clu.alias
				&sql
				m.sql = 'select a.'+m.fromfield+', b.from as '+m.toField+m.group+' from '+m.clu.alias+' a, '+m.cluster.alias+' b where a.'+m.toField+' == b.to group by 1, 2 into table '+m.next.dbf
				&sql
				use
				m.next.useExclusive()
				m.table = m.next
				this.messenger.forceMessage("") 
			endif
		endfor
		this.messenger.setPrefix(m.prefix)
		this.messenger.forceMessage("Recomposing cluster "+ltrim(str(m.clucol.count-1,10))+" using "+ltrim(str(m.clucol.count,10)))
		m.next = m.clucol.item(m.clucol.count)
		m.cluster = m.clucol.item(m.clucol.count-1)
		if m.clucol.count > 2
			select b.from, a.to from (m.cluster.alias) a, (m.next.alias) b where a.from == b.to into cursor (m.clu.alias)
			for m.i = m.clucol.count-2 to 1 step -1
				this.messenger.forceMessage("Recomposing cluster "+ltrim(str(m.i,10))+" using "+ltrim(str(m.i+1,10)))
				m.cluster = m.clucol.item(m.i)
				if m.i == 1
					select b.from, a.to from (m.cluster.alias) a, (m.clu.alias) b where a.from == b.to into table (this.dbf)
				else
					select b.from, a.to from (m.cluster.alias) a, (m.clu.alias) b where a.from == b.to into cursor (m.clu.alias)
				endif
			endfor
		else
			select b.from, a.to from (m.cluster.alias) a, (m.next.alias) b where a.from == b.to into table (this.getDBF())
		endif
		use
		this.messenger.forceMessage("Closing...")
		this.open()
		this.forceKey("from")
		this.forceKey("to")
		this.messenger.forceMessage("")
		return .t.
	endfunc
enddefine

define class FilterEnvelope as Custom
	expression = ""
	activation = 0
	
	function init(expression, activation)
		if vartype(m.expression) == "C"
			this.expression = m.expression
		endif
		if vartype(m.activation) == "N"
			this.activation = m.activation
		endif
	endfunc
	
	function isValid()
	local err, val, arr, sql
		dimension m.arr[1]
		m.sql = "select * from "+alias()+" where .f. and ("+this.expression+") into array arr"
		m.err = .f.
		try
			&sql
		catch
			m.err = .t.
		endtry
		return m.err == .f. and vartype(m.val) == "L"
	endfunc
	
	function eval()
		return evaluate(this.expression)
	endfunc
	
	function getExpression()
		return this.expression
	endfunc
	
	function toString()
		return this.expression+" @ "+transform(this.activation)
	endfunc
enddefine
	
define class TrueFilterEnvelope as Custom
	function isValid()
		return .t.
	endfunc
	
	function eval()
		return .t.
	endfunc
	
	function getExpression()
		return ".T."
	endfunc	
enddefine

define class PathEnvelope as Custom
	from = .F.
	to = .F.
	
	function init(from, to)
		this.from = m.from
		this.to = m.to
	endfunc
enddefine

define class NodeEnvelope as Custom
	node = .F.
	
	function init(node)
		this.node = m.node
	endfunc
enddefine

define class ClusterPathTable as BaseTable
	cascade = .f.
	fromField = .f.
	toField = .f.
	pfw = .f.
	
	function init(table)
	local struc
		BaseTable::init(m.table)
		if vartype(m.table) == "O"
			this.cascade = createobject("Cascade", m.table.cascade.toString())
			this.fromField = m.table.fromField
			this.toField = m.table.toField
			return
		endif
		m.struc = createobject("TableStructure","from n(1),to n(1)")
		m.struc.recast(this.getTableStructure(),.t.)
		this.setRequiredTableStructure(m.struc.toString())
		this.setRequiredKeys("from; to")
		this.pfw = createobject("ParallelFoxWrapper")
	endfunc

	function setPFW(pfw as Object)
		this.pfw = iif(vartype(m.pfw) == "O", m.pfw, createobject("ParallelFoxWrapper"))
	endfunc
	
	function getPFW()
		return this.pfw
	endfunc	
	
	function create(table, fromField, toField, cascade as Object)
	local i, wc, psl, lm, pa, pk, f1, f2, filter
	local sel, hole, tmp1, tmp2, tmp3, tmp4
	local sql, global, selcnt
		m.psl = createobject("PreservedSettingList")
		m.psl.set("escape","off")
		m.psl.set("talk","off")
		m.psl.set("exact","on")
		m.psl.set("near","off")
		m.psl.set("optimize","on")
		m.psl.set("safety","off")
		m.psl.set("exclusive","off")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Traversing...")
		if not this.isCreatable()
			this.messenger.errorMessage("ClusterPathTable is not creatable.")
			return .F.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Path table is not valid.")
			return .F.
		endif
		if not m.table.hasField(m.fromField) or not m.table.hasField(m.toField)
			this.messenger.errorMessage("Fields are not valid.")
			return .F.
		endif
		m.f1 = m.table.getFieldStructure(m.fromField)
		m.f2 = m.table.getFieldStructure(m.toField)
		if not (like(m.f1.getDefinition()+"*", m.f2.getDefinition()) or like(m.f2.getDefinition()+"*", m.f1.getDefinition()))
			this.messenger.errorMessage("FROM and TO are incompatible.")
			return .F.
		endif
		if vartype(m.cascade) == "C"
			m.cascade = createobject("Cascade", m.cascade)
		endif
		if not vartype(m.cascade) == "O"
			m.cascade = createobject("Cascade")
		endif
		select (m.table.alias)
		for m.i = 1 to m.cascade.filter.count
			m.filter = m.cascade.filter.item(m.i)
			if not m.filter.isValid()
				this.messenger.errorMessage('Filter "'+m.filter.expression+'" is not valid.')
				return .F.
			endif
		endfor
		for m.i = 2 to m.cascade.filter.count
			m.filter = m.cascade.filter.item(m.i)
			if m.filter.activation <= 0
				this.messenger.errorMessage('Only the first filter may have an activation limit lesser equal zero.')
				return .F.
			endif
		endfor
		m.f1.null = .t.
		this.setRequiredTableStructure("from "+m.f1.getDefinition()+", to "+m.f2.getDefinition())
		if not this.isCreatable()
			this.messenger.errorMessage("Unable to create ClusterPathTable.")
			return .F.
		endif
		m.pk = createobject("PreservedKey", m.table)
		if not m.table.useExclusive()
			this.messenger.errorMessage('Unable to get exclusive access on path table')
			this.erase()
			return .F.
		endif
		if not m.table.forceKey(m.toField)
			this.messenger.errorMessage('Unable to create index on TO field.')
			this.erase()
			return .F.
		endif
		if not m.table.forceKey(m.fromField)
			this.messenger.errorMessage('Unable to create index on FROM field.')
			this.erase()
			return .F.
		endif
		this.deleteKey()
		m.hole = createobject("BaseCursor",this.getPath())
		m.hole.close()
		m.tmp1 = createobject("TempAlias")
		m.tmp2 = createobject("TempAlias")
		m.tmp3 = createobject("TempAlias")
		m.tmp4 = createobject("TempAlias")
		this.messenger.forceMessage("Pathing (Origin)...")
		m.sql = "select distinct cast(.null. as "+m.f1.getDefinition()+") as origin, a."+m.fromField+" as to from "+m.table.alias+" a into table "+this.dbf
		&sql
		use
		this.useExclusive()
		m.sql = "select distinct cast(.null. as "+m.f2.getDefinition()+") as origin, a."+m.toField+" as to from "+m.table.alias+" a into cursor "+m.tmp1.alias+" readwrite"
		&sql
		select a.* from (m.tmp1.alias) a where not exists (select b.to from (this.alias) b where a.to == b.to) into cursor (m.tmp2.alias) readwrite
		select (this.alias)
		append from dbf(m.tmp2.alias)
		index on to tag to
		this.useShared()
		if m.cascade.blackhole > 0
			this.messenger.forceMessage("Pathing (Blackhole)...")
			select a.origin, cast(0 as i) as cnt, cast(0 as n(1)) as hole from (m.sel.alias) a into cursor (m.tmp4.alias) readwrite
			index on origin tag origin
			m.sql = "select a."+m.fromfield+" as origin, count(*) as cnt from "+m.table.alias+" a, "+m.tmp4.alias+" b where a."+m.fromfield+" == b.origin and not a."+m.fromfield+" == a."+m.tofield+" group by 1 into cursor "+m.tmp1.alias+" readwrite"
			&sql
			m.sql = "update "+m.tmp4.alias+" set cnt = "+m.tmp1.alias+".cnt, hole = iif("+m.tmp1.alias+".cnt > "+ltrim(str(this.blackhole,10))+",1,0) from "+m.tmp1.alias+" where "+m.tmp1.alias+".origin == "+m.tmp4.alias+".origin"
			&sql
			m.sql = "select a."+m.tofield+" as origin, count(*) as cnt from "+m.table.alias+" a, "+m.tmp4.alias+" b where a."+m.tofield+" == b.origin and b.hole == 0 and not a."+m.fromfield+" == a."+m.tofield+" group by 1 into cursor "+m.tmp1.alias+" readwrite"
			&sql
			m.sql = "update "+m.tmp4.alias+" set cnt = "+m.tmp4.alias+".cnt+"+m.tmp1.alias+".cnt, hole = iif("+m.tmp1.alias+".cnt > "+ltrim(str(this.blackhole,10))+",1,0) from "+m.tmp1.alias+" where "+m.tmp1.alias+".origin == "+m.tmp4.alias+".origin"
			&sql
			m.sql = "select a."+m.fromfield+" as from, a."+m.tofield+" as to from "+m.table.alias+" a, "+m.tmp4.alias+" b where a."+m.fromfield+" == b.origin and b.hole == 0 and b.cnt > "+ltrim(str(this.blackhole,10))+" and not a."+m.fromfield+" == a."+m.tofield+" into cursor "+m.tmp1.alias+" readwrite"
			&sql
			m.sql = "select a."+m.tofield+" as from, a."+m.fromfield+" as to from "+m.table.alias+" a, "+m.tmp4.alias+" b where a."+m.tofield+" == b.origin and b.hole == 0 and b.cnt > "+ltrim(str(this.blackhole,10))+" and not a."+m.fromfield+" == a."+m.tofield+" into cursor "+m.tmp2.alias+" readwrite"
			&sql
			m.sql = "select a.* from "+m.tmp2.alias+" a where not exists (select * from "+m.tmp1.alias+" b where a.from == b.from and a.to == b.to) into cursor "+m.tmp3.alias+" readwrite"
			&sql
			select (m.tmp1.alias)
			append from dbf(m.tmp3.alias)
			m.sql = "select a.from as origin from "+m.tmp1.alias+" a group by 1 having count(*) > "+ltrim(str(this.blackhole,10))+" into cursor (m.tmp1.alias)"
			&sql
			m.sql = "update "+m.tmp4.alias+" set hole = 1 from "+m.tmp1.alias+" where "+m.tmp1.alias+".origin == "+m.tmp4.alias+".origin"
			&sql
			select a.origin from (m.tmp4.alias) a where a.hole == 1 into table (m.hole.dbf)
			use 
			m.hole.useExclusive()
			m.hole.forceKey("origin")
			m.hole.useShared()
		endif
		m.tmp1.close()
		m.tmp2.close()
		m.tmp3.close()
		m.tmp4.close()
		this.cascade = m.cascade
		this.fromField = m.fromField
		this.toField = m.toField
		this.messenger.forceProgress("Traversing...")
		m.selcnt = this.reccount()
		m.wc = this.pfw.setOptimalWorkerCount(m.selcnt,1000)
		this.messenger.startProgress("Traversing <<0>>/"+transform(m.selcnt))
		this.messenger.startCancel("Cancel Operation?","Traversing","Canceled.")
		if m.wc > 1
			this.close()
			m.hole.close()
			m.table.close()
			m.global = createobject("Collection")
			m.global.add(this)
			m.global.add(m.hole)
			m.global.add(m.table)
			this.pfw.linkMessenger(this.messenger)
			this.pfw.startWorkers()
			this.pfw.callWorkers("mp_open", this, m.psl, .f., m.global)
			this.pfw.wait() && make sure all workers are idle, to maintain batch sequence
			this.pfw.callWorkers("mp_traverse", 1, m.selcnt)
			this.pfw.wait(.t.)
			this.pfw.stopWorkers()
			m.table.useExclusive()
			this.useExclusive()
		else
			this.useExclusive()
			m.hole.useExclusive()
			m.table.useExclusive()
			this.traversing(1, -1, this, m.hole, m.table, this.messenger)
		endif
		this.messenger.stopProgress()
		alter table (this.alias) rename column origin to from
		if this.messenger.wasCanceled()
			return
		endif
		this.forceRequiredKeys()
		return .t.
	endfunc

	function traversing(from as Integer, to as Integer, sel as Object, hole as Object, path as Object, messenger as Object)
	local i, rec, keyexp, branch, result, truefilter, blackhole, origin, target
	local init, filter, filterActivation, filterCountDown, filterindex, nextFilter, cascadeFilter
	local node, key, fromTag, toTag
		m.to = iif(m.to < 0, m.sel.reccount(), m.to) 
		if m.from > m.to
			return
		endif
		if not vartype(m.messenger) == "O"
			m.messenger = createobject("Messenger")
			m.messenger.setSilent(.t.)
		endif
		m.keyexp = m.sel.getFieldStructure("to")
		m.keyexp = m.keyexp.keyConverter("m.target")
		m.branch = createobject("Collection")
		m.result = createobject("Collection")
		m.trueFilter = createobject("TrueFilterEnvelope")
		m.blackhole = m.hole.reccount() > 0
		if m.blackhole
			m.hole.forceKey("origin")
		endif
		m.path.setKey(this.fromField)
		m.fromTag = order(m.path.alias)
		m.path.setKey(this.toField)
		m.toTag = order(m.path.alias)
		m.cascadeFilter = this.cascade.filter
		select (m.sel.alias)
		set order to tag to
		for m.rec = m.from to m.to
			m.messenger.incProgress(1,1)
			m.messenger.postProgress()
			if m.messenger.queryCancel()
				exit
			endif
			go m.rec
			m.origin = to
			if seek(m.origin) and not isnull(origin)
				loop
			endif
			select (m.path.alias)
			if m.cascadeFilter.count > 0
				m.filter = m.cascadeFilter.item(1)
				m.filterCountDown = m.filter.activation
				if m.filterCountDown > 0
					m.filterIndex = 0
					m.filter = m.trueFilter
				else
					m.filterIndex = 1
					if m.cascadeFilter.count > 1
						m.nextFilter = m.cascadeFilter.item(2)
						m.filterCountDown = m.nextfilter.activation
					endif
				endif
			else
				m.filterCountDown = 0
				m.filterIndex = 0
				m.filter = m.trueFilter
			endif
			m.init = .t.
			do while .t.
				if m.init
					m.branch.remove(-1)
					m.result.remove(-1)
					m.branch.add(m.origin)
					m.target = m.origin	
					m.key = evaluate(m.keyexp)
					m.result.add(m.origin, m.key)
					if m.blackhole and seek(m.origin,m.hole.alias)
						exit
					endif
					m.filterActivation = m.filterIndex < m.cascadeFilter.count
					m.init = .f.
				endif
				if m.filterActivation and m.result.count >= m.filterCountDown
					m.filterIndex = m.filterIndex+1
					m.filter = m.cascadeFilter.item(m.filterIndex)
					if not m.filterIndex == m.cascadeFilter.count
						m.nextFilter = m.cascadeFilter.item(m.filterIndex+1)
						m.filterCountDown = m.nextFilter.activation
					endif
					m.init = .t.
					loop
				endif
				if m.messenger.queryCancel()
					exit
				endif
				if m.branch.count <= 0
					exit
				endif
				m.node = m.branch.item(m.branch.count)
				m.branch.remove(m.branch.count)
				set order to tag (m.fromTag)
				seek(m.node)
				do while not eof() and evaluate(this.fromField) == m.node
					m.target = evaluate(this.toField)
					if not m.node == m.target
						m.key = evaluate(m.keyexp)
						if m.result.getKey(m.key) <= 0
							if m.filter.eval()
								if not (m.blackhole and seek(m.target,m.hole.alias))
									m.branch.add(m.target)
									m.result.add(m.target, m.key)
								endif
							endif
						endif
					endif
					skip
				enddo
				set order to tag (m.toTag)
				seek(m.node)
				do while not eof() and evaluate(this.toField) == m.node
					m.target = evaluate(this.fromField)
					if not m.node == m.target
						m.key = evaluate(m.keyexp)
						if m.result.getKey(m.key) <= 0
							if m.filter.eval()
								if not (m.blackhole and seek(m.target,m.hole.alias))
									m.branch.add(m.target)
									m.result.add(m.target, m.key)
								endif
							endif
						endif
					endif
					skip
				enddo
			enddo
			if this.messenger.wasCanceled()
				exit
			endif
			for m.i = 1 to m.result.count
				update (m.sel.alias) set origin = m.origin where to == m.result.item(m.i) and (isnull(origin) or m.origin < origin)
				if _tally == 0
					exit
				endif
			endfor
			select (m.sel.alias)
		endfor
		m.messenger.forceProgress()
		release m.branch
		release m.result
	endfunc
	
	function setUndirected(undirected)
		this.undirected = m.undirected
	endfunc
	
	function isUndirected()
		return this.undirected
	endfunc

	function setBlackHole(limit)
		this.blackhole = m.limit
	endfunc
	
	function getBlackHole()
		return this.blackhole
	endfunc
enddefine
