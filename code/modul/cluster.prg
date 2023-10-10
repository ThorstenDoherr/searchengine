*=========================================================================*
*   Modul:      cluster.prg
*   Date:       2023.04.12
*   Author:     Thorsten Doherr
*   Required:   custom.prg
*   Function:   A TableCluster is group of table with compatible
*               structures. All tables share the same name 
*               followed by a sequential number (i.e.: tab001.dbf,
*               tab002.dbf, tab003.dbf, ...). The first table in a
*               cluster defines the starting number and the base
*               structure.
*   TODO:       adjust/spread on start name without numbers
*=========================================================================*
define class TableCluster as Custom
	cluster = .f.
	messenger = .f.
	tolerant = .f.
	careless = .f.
	offset = 0
	index = 1
	table = .f.
	start = ""
	first = 0
	path = ""
	trunc = ""
	leading0 = 0
	cursor = .f.
	pseudo = .f.
	preserve = .f.
	errorCancel = .f.
	key = ""
	keyexp = ""
	
	function init(startTable as String, tableCount as Integer, tolerant as boolean, careless as boolean)
		this.messenger = createobject("Messenger", this.errorCancel)
		this.messenger.setInterval(2)
		this.preserve = createobject("Collection")
		if vartype(m.startTable) == "O"
			if pcount() == 1
				m.tableCount = m.startTable.getTableCount()
				m.tolerant = m.startTable.isTolerant()
				m.careless = m.startTable.isCareless()
			endif
			m.startTable = m.startTable.getStartTable()
		endif
		this.build(m.startTable, m.tableCount, m.tolerant, m.careless)
	endfunc
	
	function destroy
		if this.cursor
			this.call("setCursor(.t.)")
		endif
	endfunc			
	
	protected function build(startTable as String, tableCount as Integer, tolerant as boolean, careless as boolean)
	local table, name, struc, end, start, len, num
	local dir, dircnt, i
		this.pseudo = .f.
		this.cluster = createobject("Collection")
		this.tolerant = m.tolerant
		this.careless = iif(this.tolerant, m.careless, .f.)
		if not vartype(m.startTable) == "C"
			return
		endif
		if not vartype(m.tableCount) == "N" or m.tableCount <= 0
			m.tableCount = -1
		endif
		m.table = createobject("BaseTable",m.startTable)
		m.name = m.table.getPureName()
		this.path = m.table.getPath()
		this.trunc = m.name
		this.start = m.name
		m.struc = m.table.getTableStructure()
		for m.end = len(m.name) to 1 step -1
			if substr(m.name,m.end,1) $ "0123456789"
				for m.start = m.end-1 to 1 step -1
					if not substr(m.name,m.start,1) $ "0123456789"
						exit
					endif
				endfor
				exit
			endif
		endfor
		if m.end < 1 
			if m.table.isValid()
				this.cluster.add(m.table)
				this.table = m.table
			endif
			this.pseudo = .t.
			this.trunc = this.trunc+"*"
			return
		endif
		m.table.close()
		m.len = m.end - m.start
		this.leading0 = iif(substr(m.name,m.start+1,1) == "0",m.len,0)
		m.num = int(val(substr(m.name,m.start+1,m.len)))
		this.first = m.num
		this.trunc = substr(m.name,1,m.start)+"*"+substr(m.name,m.end+1)
		m.name = substr(m.name,m.end+1)
		dimension m.dir[1]
		m.dircnt = adir(dir,this.path+this.trunc+".dbf")
		if m.dircnt <= 0
			return
		endif
		for m.i = 1 to m.dircnt
			m.dir[m.i,2] = val(substr(m.dir[m.i,1],m.start+1))
		endfor
		asort(m.dir,2)
		for m.i = 1 to m.dircnt
			if m.dir[m.i,2] < m.num
				loop
			endif
			if m.dir[m.i,2] > m.num
				exit
			endif
			m.table = ltrim(str(m.dir[m.i,2],18,0))
			if len(m.table) < this.leading0
				m.table = padl(m.table,this.leading0,"0")
			endif
			if not m.dir[m.i,1] == left(m.dir[m.i,1],m.start)+m.table+m.name+".DBF"
				loop
			endif
			m.table = createobject("BaseTable",this.path+m.dir[m.i,1])
			if this.tolerant
				if this.careless
					if not m.struc.checkNames(m.table.getTableStructure())
						exit
					endif
				else
					if not m.struc.checkCompatibility(m.table.getTableStructure())
						exit
					endif
				endif
			else
				if not m.struc.checkStructure(m.table.getTableStructure())
					exit
				endif
			endif
			this.cluster.add(m.table)
			if this.cluster.count == m.tableCount
				exit
			endif
			m.num = m.num+1
		endfor
		if this.cluster.count > 0
			this.table = this.cluster.item(1)
		endif
	endfunc
	
	function isConform()
		return right(this.trunc,1) == "*" and this.first == 1
	endfunc	
	
	function conformTrunc()
		if this.isConform()
			return this.trunc
		endif
		if isdigit(right(this.start,1))
			return this.start+"_*"
		endif
		return this.start+"*"
	endfunc
	
	function forceConformity() && forces first tables numbers to a postfix beginning with 1
	local oldtrunc, old0, i, j, table
		if right(this.trunc,1) == "*" and this.first == 1
			return .t.
		endif
		m.oldtrunc = this.trunc
		m.old0 = this.leading0
		this.trunc = this.conformTrunc()
		this.leading0 = 0
		for m.i = 1 to this.cluster.count
			if file(this.createTableName(m.i)+".dbf")
				this.trunc = m.oldtrunc
				this.leading0 = m.old0
				return .f.
			endif
		endfor
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			if not m.table.rename(this.createTableName(m.i,.t.))
				this.trunc = m.oldtrunc
				this.leading0 = m.old0
				for m.j = 1 to m.i-1
					m.table = this.cluster.item(m.i)
					m.table.rename(this.createTableName(this.first-m.i-1,.t.))
				endfor
				return .f.
			endif
		endfor
		this.start = this.createTableName(1,.t.)
		this.first = 1
		return .t.
	endfunc
	
	function createTableName(num as Integer, pure as Boolean)
		if m.num <= 0
			m.num = ""
		else
			m.num = ltrim(str(m.num,18,0))
			if this.leading0 > len(m.num)
				m.num = padl(m.num, this.leading0, "0")
			endif
		endif
		if m.pure
			return strtran(this.trunc,"*",m.num)
		endif
		return this.path+strtran(this.trunc,"*",m.num)
	endfunc
	
	function rebuild(tableCount as Integer)
		if not vartype(m.tableCount) == "N"
			m.tableCount = this.cluster.count
		endif
		this.close()
		this.cluster.remove(-1)
		this.build(this.path+this.start,m.tableCount,this.tolerant,this.careless)
	endfunc
	
	function create(struc as Object)
		return this.construct(m.struc)
	endfunc
	
	function construct(struc as Object)
		if this.cluster.count > 0
			return .f.
		endif
		return this.appendTable(m.struc)
	endfunc
	
	function appendTable(struc as Object)
	local table, i, last, key, close, newname
		if this.cluster.count == 0
			if vartype(m.struc) == "C"
				m.struc = createobject("TableStructure",m.struc)
			endif
			if not vartype(m.struc) == "O" or not m.struc.isValid()
				return .f.
			endif
			m.table = createobject("BaseTable",this.path+this.start)
			if not m.table.construct(m.struc)
				return .f.
			endif
			this.cluster.add(m.table)
			this.table = m.table
			this.offset = 0
			this.index = 1
			return .t.
		endif
		if this.cluster.count == 1 and this.first == 0
			m.newname = this.createTableName(1,.t.)
			m.table = this.cluster.item(1)
			if not m.table.rename(m.newname)
				return .f.
			endif
			this.start = m.newname
			this.pseudo = .f.
			this.first = 1
		endif
		m.last = this.cluster.item(this.cluster.count)
		m.close = select(m.last.alias) == 0
		if m.close
			m.last.useShared()
		endif
		m.struc = m.last.getTableStructure()
		m.table = createobject("BaseTable",this.createTableName(this.cluster.count+this.first))
		if m.close
			m.last.close()
		endif
		if not m.table.construct(m.struc)
			return .f.
		endif
		m.i = 1
		m.key = m.last.getKey(m.i)
		do while not empty(m.key)
			m.table.forceKey(m.key)
			m.i = m.i+1
			m.key = m.last.getKey(m.i)
		enddo
		m.key = m.last.getKey()
		m.table.forceKey(m.key)
		this.cluster.add(m.table)
		this.table = m.table
		return .t.
	endfunc
		
	function getMessenger()
		return this.messenger
	endfunc
		
	function setMessenger(messenger as Messenger)
		this.messenger = m.messenger
	endfunc

	function getTableCount()
		return this.cluster.count
	endfunc

	function isValid()
		return this.cluster.count > 0
	endfunc
		
	function getTable(index as Integer)
		return this.cluster.item(m.index)
	endfunc
	
	function getLastTable()
		return this.cluster.item(this.cluster.count)
	endfunc
	
	function getFirstTable()
		return this.cluster.item(1)
	endfunc

	function getTrunc()
		return this.trunc
	endfunc

	function getStart()
		return this.start
	endfunc

	function getPath()
		return this.path
	endfunc
	
	function getStartTable()
		return this.path+this.start
	endfunc
	
	function isTolerant()
		return this.tolerant
	endfunc

	function isCareless()
		return this.careless
	endfunc

	function getActiveTable()
		return this.table
	endfunc
	
	function getFirst()
		return this.first
	endfunc
	
	function getLast()
		return this.first+this.cluster.count-1
	endfunc
	
	function selectActiveTable()
		select (this.table.alias)
	endfunc

	function call(method as String)
		local table, com, i
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			&com
		endfor
	endfunc

	function callAnd(method as String)
		local table, com, i
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			if &com == .f.
				return .f.
			endif
		endfor
		return .t.
	endfunc

	function callOr(method as String)
		local table, com, i
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			if &com == .t.
				return .t.
			endif
		endfor
		return .f.
	endfunc

	function callAll(method as String)
		local table, com, bool, i
		m.bool = .t.
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			m.bool = &com and m.bool
		endfor
		return m.bool and (this.cluster.count > 0)
	endfunc

	function callAny(method as String)
		local table, com, bool, i
		m.bool = .f.
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			m.bool = &com or m.bool
		endfor
		return m.bool
	endfunc
	
	function callString(method as String, separator as String)
		local table, com, str, first, i
		if not vartype(m.separator) == "C"
			m.separator = ""
		endif
		str = ""
		m.first = .t.
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			if m.first
				m.first = .f.
				m.str = &com
			else
				m.str = m.str+m.separator+&com
			endif
		endfor
		return m.str
	endfunc

	function callSum(method as String)
		local table, com, sum, i
		m.sum = 0
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			m.sum = m.sum+&com
		endfor
		return m.sum
	endfunc

	function preserveKeys(stored_keys as Collection)
	local i, j, key, table
		if not vartype(m.stored_keys) == "O"
			m.stored_keys = this.preserve
		endif
		m.stored_keys.remove(-1)
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.j = 1
			m.key = m.table.getKey(m.j)
			do while not empty(m.key)
				if m.stored_keys.getKey(m.key) == 0
					m.stored_keys.add(m.key,m.key)
				endif
				m.j = m.j+1
				m.key = m.table.getKey(m.j)
			enddo
		endfor
		return m.stored_keys.count
	endfunc

	function restoreKeys(stored_keys as Collection)
	local i, cnt
		if not vartype(m.stored_keys) == "O"
			m.stored_keys = this.preserve
		endif
		m.cnt = 0
		for m.i = 1 to m.stored_keys.count
			if this.forceKey(m.stored_keys.item(m.i))
				m.cnt = m.cnt+1
			endif
		endfor
		return m.cnt
	endfunc
	
	function copyKeys(cluster as Object)
	local stored_keys
		m.stored_keys = createobject("Collection")
		m.cluster.preserveKeys(m.stored_keys)
		return this.restoreKeys(m.stored_keys)
	endfunc
	
	function select(select as String, targetAlias as String)
		local temp, tempAlias, sel, sql, first, i, table
		if not vartype(m.targetAlias) == "C"
			m.targetAlias = createobject("UniqueAlias")
			m.targetAlias = m.targetAlias.getAlias()
		endif
		m.first = .t.
		m.sel = m.select+" into cursor "+m.targetAlias+" readwrite"
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.sql = strtran(strtran(strtran(m.sel,"[CLUSTERALIAS]",m.table.alias),"[CLUSTERINDEX]",ltrim(str(m.i,18))),"[CLUSTER]",m.table.alias)
			&sql
			if m.first
				if this.cluster.count > 1
					m.first = .f.
					m.temp = createobject("UniqueAlias",.t.)
					m.tempAlias = m.temp.getAlias()
					m.sel = m.select+" into cursor "+m.tempAlias+" readwrite"
				endif
			else
				select (m.targetAlias)
				append from (dbf(m.tempAlias))
			endif
		endfor
	endfunc
	
	function csql(sql as String, tablecluster1 as Object, tablecluster2 as Object, tablecluster3 as Object, tablecluster4 as Object)
	local pa, ps1, ps2, ps3, lm, first, col, var1, var2, field1, field2, clu1, clu2, exp, tmp1, plugin, ind
	local type, combination, i, j, table, min, max, realsql, combo, c1, c2, c3, c4, alias1, alias2, alias3, alias4
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.lm = createobject("LastMessage",this.messenger)
		m.sql = alltrim(m.sql)
		m.type = lower(getwordnum(m.sql,1))
		if not inlist(m.type,"update","select","delete","alter")
			this.messenger.errorMessage("Unsupported sql command.")
			return .f.
		endif
		if not vartype(m.tablecluster1) == "O"
			m.tablecluster1 = createobject("TableCluster")
		endif
		if not vartype(m.tablecluster2) == "O"
			m.tablecluster2 = createobject("TableCluster")
		endif
		if not vartype(m.tablecluster3) == "O"
			m.tablecluster3 = createobject("TableCluster")
		endif
		if not vartype(m.tablecluster4) == "O"
			m.tablecluster4 = createobject("TableCluster")
		endif
		if m.type == "select"			
			if this.getTableCount() > 0 and not this.callAnd('isCreatable()') and not this.callAnd('erase()')
				this.messenger.errorMessage("Unable to clear table cluster.")
				return .f.
			endif
			this.cluster.remove(-1)
		else
			if m.type == "alter"
				if this.getTableCount() == 0 or not this.useExclusive()
					this.messenger.errorMessage("Unable to get exclusive access.")
					return .f.
				endif
			endif
		endif		
		m.col = this.parseForExpression(@m.sql)
		if vartype(m.col) == "O"
			for m.i = m.col.count to 1 step -1
				m.var1 = getwordnum(m.col.item(m.i),1,"&")
				m.var2 = getwordnum(m.col.item(m.i),2,"&")
				m.clu1 = getwordnum(m.var1,2,"|")
				m.clu2 = getwordnum(m.var2,2,"|")
				m.var1 = getwordnum(m.var1,1,"|")
				m.var2 = getwordnum(m.var2,1,"|")
				m.var1 = getwordnum(m.var1,getwordcount(m.var1,"."),".")
				m.var2 = getwordnum(m.var2,getwordcount(m.var2,"."),".")
				this.messenger.forceMessage("Indexing "+proper(m.var1))
				m.exp = "m.tablecluster"+m.clu1+".forceKey('"+m.var1+"')"
				&exp
				this.messenger.forceMessage("Indexing "+proper(m.var2))
				m.exp = "m.tablecluster"+m.clu2+".forceKey('"+m.var2+"')"
				&exp
			endfor
		else
			if m.col == .f.
				this.messenger.errorMessage("Invalid FOR expression.")
				return .f.
			endif
		endif		
		if not vartype(m.col) == "O"
			m.col = createobject("Collection")
		endif
		if m.col.count > 0
			m.tmp1 = createobject("UniqueAlias",.t.)
			dimension m.min[m.col.count,2]
			dimension m.max[m.col.count,2]
		endif
		this.messenger.forceMessage("Collecting combinations...")
		m.combination = createobject("Collection")
		for m.c1 = 1 to m.tablecluster1.getTableCount()
			m.table = m.tablecluster1.getTable(m.c1)
			m.alias1 = m.table.alias
			if m.tablecluster2.getTableCount() < 1
				m.combination.add(m.alias1)
			else
				for m.c2 = 1 to m.tablecluster2.getTableCount()
					m.table = m.tablecluster2.getTable(m.c2)
					m.alias2 = m.alias1+" "+m.table.alias
					if m.tablecluster3.getTableCount() < 1
						m.combination.add(m.alias2)
					else
						for m.c3 = 1 to m.tablecluster3.getTableCount()
							m.table = m.tablecluster3.getTable(m.c3)
							m.alias3 = m.alias2+" "+m.table.alias
							if m.tablecluster4.getTableCount() < 1
								m.combination.add(alias3)
							else
								for m.c4 = 1 to m.tablecluster4.getTableCount()
									m.table = m.tablecluster4.getTable(m.c4)
									m.alias4 = m.alias3+" "+m.table.alias
									m.combination.add(alias4)
								endfor
							endif
						endfor
					endif
				endfor
			endif
		endfor
		if m.combination.count == 0
			if pcount() == 1
				m.combination.add("")
			else
				this.messenger.errorMessage("No valid clusters detected.")
				return .f.
			endif
		endif
		m.combo = m.combination.item(1)
		m.combo = getwordcount(m.combo)
		m.first = this.first-1
		this.messenger.setDefault("Combination")
		this.messenger.startProgress(m.combination.count)
		this.messenger.startCancel("Cancel Operation?","Cluster SQL","Canceled.")
		for m.i = 1 to m.combination.count
			this.messenger.setProgress(m.i)
			this.messenger.forceProgress()
			if this.messenger.queryCancel()
				m.i = 1
				exit
			endif
			m.alias1 = m.combination.item(m.i)
			m.realsql = m.sql
			m.plugin = ""
			for m.j = 1 to m.col.count
				m.var1 = getwordnum(m.col.item(m.j),1,"&")
				m.var2 = getwordnum(m.col.item(m.j),2,"&")
				m.clu1 = getwordnum(m.alias1,val(getwordnum(m.var1,2,"|")))
				m.clu2 = getwordnum(m.alias1,val(getwordnum(m.var2,2,"|")))
				m.field1 = getwordnum(m.var1,1,"|")
				m.field2 = getwordnum(m.var2,1,"|")
				m.var1 = getwordnum(m.field1,getwordcount(m.field1,"."),".")
				m.var2 = getwordnum(m.field2,getwordcount(m.field2,"."),".")
				m.exp = "select min(a."+m.var1+") as min, max(a."+m.var1+") as max from "+m.clu1+" a into cursor "+m.tmp1.alias
				&exp
				m.min[m.j,1] = min
				m.max[m.j,1] = max
				m.exp = "select min(a."+m.var2+") as min, max(a."+m.var2+") as max from "+m.clu2+" a into cursor "+m.tmp1.alias
				&exp
				m.min[m.j,2] = min
				m.max[m.j,2] = max
				if m.min[m.j,2] > m.max[m.j,1] or m.max[m.j,2] < m.min[m.j,1]
					m.plugin = ".F. AND"
					exit
				endif
				m.ind = ltrim(str(m.j))
				if m.min[m.j,1] != m.min[m.j,2]
					if m.min[m.j,1] > m.min[m.j,2]
						m.plugin = m.plugin+m.field2+" >= m.min["+m.ind+",1] AND "
					else
						m.plugin = m.plugin+m.field1+" >= m.min["+m.ind+",2] AND "
					endif
				endif
				if m.max[m.j,1] != m.max[m.j,2]
					if m.max[m.j,1] < m.max[m.j,2]
						m.plugin = m.plugin+m.field2+" <= m.max["+m.ind+",1] AND "
					else
						m.plugin = m.plugin+m.field1+" <= m.max["+m.ind+",2] AND "
					endif
				endif
			endfor
			m.realsql = strtran(m.realsql,"[PLUGIN]",m.plugin)
			for m.j = 1 to m.combo
				m.realsql = strtran(m.realsql, "[CLUSTER"+ltrim(str(m.j))+"]", getwordnum(m.alias1,m.j))
			endfor
			if m.type == "select"
				m.realsql = m.realsql+' into table "'+this.createTableName(m.first+m.i)+'"'
				&realsql
				use
			else
				&realsql
			endif
		endfor
		if not m.type == "select"
			return not this.messenger.isInterrupted()
		endif
		this.messenger.sneakMessage("Cleaning...")
		m.table = createobject("TableCluster",this.createTableName(m.first+m.i))
		m.table.erase()
		this.build(this.path+this.start,m.i-1,.t.)
		return not this.messenger.isInterrupted()
	endfunc

	function cappend(cluster as Object)
	local pa, ps1, ps2, ps3, lm, first
	local table, struc, c, clustertable
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.lm = createobject("LastMessage",this.messenger)
		if m.cluster.getTableCount() == 0
			this.messenger.errorMessage("Empty TableCluster.")
			return .f.
		endif
		if this.getTableCount() == 0
			m.table = m.cluster.getActiveTable()
		else
			m.table = this.getActiveTable()
		endif
		this.forceConformity()
		m.struc = m.table.getTableStructure()
		this.messenger.forceMessage("Appending...")
		m.first = this.first-1
		this.messenger.startProgress("Appending <<0>>/"+transform(m.cluster.getTableCount()))
		for m.c = 1 to m.cluster.getTableCount()
			this.messenger.incProgress(1,1)
			this.messenger.forceProgress()
			m.clustertable = m.cluster.getTable(m.c)
			m.table = createobject("BaseTable",this.createTableName(m.first+this.getTableCount()+m.c))
			m.table.erase()
			m.table.create(m.struc)
			m.table.select()
			append from (m.clustertable.getDBF())
		endfor
		this.messenger.sneakMessage("Appending...")
		m.table = createobject("TableCluster",this.createTableName(m.first+this.getTableCount()+m.c))
		m.table.erase()
		this.tolerant = .t.
		this.rebuild(this.getTableCount()+m.cluster.getTableCount())
		return .t.
	endfunc

	function cgroup(tablecluster as Object, groupby as String, grouping as String)
	local pa, ps1, ps2, ps3, ps4, ps5, lm, first
	local table1, table2, struc, sqlbase, sql, i, j, k, list, item
	local bysize, by, change, value, match, leave
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","deleted","off")
		m.ps5 = createobject("PreservedSetting","exclusive","on")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Grouping...")
		if m.tablecluster.getTableCount() == 0
			this.messenger.errorMessage("Empty TableCluster.")
			return .f.
		endif
		if vartype(m.groupby) == "C"
			m.groupby = createobject("TableStructure",m.groupby)
		endif
		if not m.groupby.isValid()
			this.messenger.errorMessage("Invalid groupby parameter.")
			return .f.
		endif
		m.table1 = m.tablecluster.getTable(1)
		m.struc = m.table1.getTableStructure()
		if not m.groupby.checkNames(m.struc)
			this.messenger.errorMessage("Unknown groupby field.")
			return .f.
		endif
		if not vartype(m.grouping) == "C"
			grouping = ""
		endif
		m.list = createobject("StringList",m.grouping,",")
		m.grouping = createobject("Collection")
		for m.i = 1 to m.list.getItemCount()
			m.item = m.list.getItem(m.i)
			m.item = lower(alltrim(m.item))+"?"
			m.item = strtran(strtran(strtran(m.item,"("," "),")"," ")," as "," ")
			m.item = substr(m.item,1,len(m.item)-1)
			try
				m.item = createobject(getwordnum(m.item,1)+"group",getwordnum(m.item,2),getwordnum(m.item,3))
			catch
				this.messenger.errorMessage("Invalid grouping command.")
				return .f.
			endtry
			if not m.item.isValid(m.struc)
				this.messenger.errorMessage("Invalid grouping command.")
				return .f.
			endif
			m.grouping.add(m.item)
		endfor
		if this.getTableCount() > 0 and not this.callAnd('isCreatable()') and not this.callAnd('erase()')
			this.messenger.errorMessage("Unable to clear table cluster.")
			return .f.
		endif
		this.cluster.remove(-1)
		m.sqlbase = "select "+m.groupby.getFieldList("a")
		for m.i = 1 to m.grouping.count
			m.item = m.grouping.item(m.i)
			m.sqlbase = m.sqlbase+", "+m.item.sql()
		endfor
		m.sqlbase = m.sqlbase + " from ?1 a group by "+m.groupby.getFieldList("a")+' into table "?2"'
		if this.pseudo and m.tablecluster.getTableCount() > 1
			this.pseudo = .f.
			this.first = 1
			this.start = this.createTableName(1,.t.)
		endif
		m.first = this.first-1
		for m.i = 1 to m.tablecluster.getTableCount()
			this.messenger.forceMessage("Grouping into "+proper(this.createTableName(m.first+m.i,.t.)))
			m.table1 = m.tableCluster.getTable(m.i)
			m.sql = strtran(strtran(m.sqlbase,"?1",m.table1.getAlias()),"?2",this.createTableName(m.first+m.i))
			&sql
			use
		endfor
		this.messenger.forceMessage("Grouping...")
		m.tablecluster = createobject("TableCluster",this.createTableName(m.first+m.i))
		m.tablecluster.erase()
		this.rebuild(m.i-1)
		m.bysize = m.groupby.getFieldCount()
		dimension m.by[m.bysize,2]
		for m.i = 1 to m.bysize
			m.by[m.i,1] = m.groupby.getFieldStructure(m.i)
			m.by[m.i,1] = m.by[m.i,1].getName()
		endfor
		m.table1 = this.cluster.item(1)
		m.struc = m.table1.getTableStructure()
		for m.i = 1 to m.grouping.count
			m.item = m.grouping.item(m.i)
			m.item.variable = m.struc.getFieldStructure(m.i+m.bysize)
			m.item.variable = m.item.variable.getName()
		endfor
		for m.i = 1 to this.cluster.count - 1
			m.table1 = this.cluster.item(m.i)
			this.messenger.forceMessage("Grouping "+proper(m.table1.getPureName()))
			select (m.table1.alias)
			scan
				if deleted()
					loop
				endif
				for each item in m.grouping 
					m.item.set(evaluate(m.item.variable))
				endfor
				for m.j = 1 to m.bysize
					m.by[m.j,2] = evaluate(m.by[m.j,1])
				endfor
				m.change = .f.
				for m.j = m.i+1 to this.cluster.count
					m.table2 = this.cluster.item(m.j)
					select (m.table2.alias)
					if eof()
						loop
					endif
					m.match = .f.
					m.leave = .f.
					do while not eof()
						if deleted()
							skip
							loop
						endif
						for m.k = 1 to m.bysize
							m.value = evaluate(m.by[m.k,1])
							if m.value < m.by[m.k,2]
								skip
								exit
							endif
							if m.value > m.by[m.k,2]
								m.leave = .t.
								exit
							endif
						endfor
						if m.k > m.bysize
							m.match = .t.
							exit
						endif
						if m.leave
							exit
						endif
					enddo
					if m.match
						for m.k = 1 to m.grouping.count
							m.item = m.grouping.item(m.k)
							m.item.execute(evaluate(m.item.variable))
						endfor
						m.change = .t.
						delete
						skip
					endif
				endfor
				select (m.table1.alias)
				if m.change
					for m.j = 1 to m.grouping.count
						m.item = m.grouping.item(m.j)
						replace (m.item.variable) with (m.item.value)
					endfor
				endif
			endscan
			for m.j = m.i+1 to this.cluster.count
				m.table2 = this.cluster.item(m.j)
				go top in (m.table2.alias)
			endfor
		endfor
		this.messenger.forceMessage("Grouping...")
		this.pack()
		return .t.	
	endfunc

	function csort(tablecluster as Object, orderby as String)
	local pa, ps1, ps2, ps3, ps4, ps5, lm
	local sortby, struc, table, i, sortexp, sql, sorted, pos, top
	local insexp, ins, cols, col, newcol, buffer, overflowerr, item, key
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","deleted","off")
		m.ps5 = createobject("PreservedSetting","exclusive","on")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Sorting...")
		if m.tablecluster.getTableCount() == 0
			this.messenger.errorMessage("Empty TableCluster.")
			return .f.
		endif
		m.orderby = createobject("StringList",m.orderby,",")
		m.sortby = ""
		for m.i = 1 to m.orderby.getItemCount()
			m.sortby = m.sortby+","+getwordnum(m.orderby.getItem(m.i),1)
		endfor
		m.sortby = createobject("TableStructure",substr(m.sortby,2))
		if not m.sortby.isValid()
			this.messenger.errorMessage("Invalid orderby parameter.")
			return .f.
		endif
		m.struc = m.tablecluster.getTableStructure()
		if not m.sortby.checkNames(m.struc)
			this.messenger.errorMessage("Unknown orderby field.")
			return .f.
		endif
		if m.tableCluster.getTableCount() == 1
			if this.getTableCount() > 0 and not this.erase()
				this.messenger.errorMessage("Unable to clear table cluster.")
				return .f.
			endif
			m.table = m.tableCluster.getTable(1)
			this.messenger.forceMessage("Sorting "+proper(m.table.getPureName()))
			m.sql = "select * from (m.table.alias) order by "+m.orderby.getFieldList(m.table.alias)+" into table '"+this.path+this.start+"'"
			&sql
			use
			this.rebuild()
			return .t.
		endif
		this.build(this.path+this.start,m.tableCluster.getTableCount(),.t.)
		if this.getTableCount() > 0 and not this.erase()
			this.messenger.errorMessage("Unable to clear table cluster.")
			return .f.
		endif
		this.cluster.remove(-1)
		this.forceConformity()
		m.sortexp = createobject("ComposedKey",m.struc,m.sortby.getFieldList(),.t.)
		m.sortexp = m.sortexp.getExp(m.orderby.getFieldList())
		m.sorted = createobject("CursorCluster",this.path)
		for m.i = 1 to m.tableCluster.getTableCount()
			m.table = m.tableCluster.getTable(m.i)
			m.sorted.appendTable()
			this.messenger.forceMessage("Sorting "+proper(m.table.getPureName()))
			m.sql = "select * from (m.table.alias) order by "+m.orderby.getFieldList(m.table.alias)+" into table '"+m.sorted.table.dbf+"'"
			&sql
			use
			m.sorted.table.useExclusive()
		endfor
		m.struc = m.sorted.getTableStructure()
		m.insexp = "insert into ? values (m.buffer[1]"
		for m.i = 2 to m.struc.getFieldCount()
			m.insexp = m.insexp+",m.buffer["+ltrim(str(m.i))+"]"
		endfor
		m.insexp = m.insexp+")"
		dimension m.buffer[m.struc.getFieldCount()]
		this.appendTable(m.struc)
		m.ins = strtran(m.insexp,"?",this.table.alias)
		m.top = createobject("Collection")
		m.top.keysort = 2
		m.cols = createobject("CollectionStorage",m.sorted.getTableCount()*2+1)
		this.messenger.forceMessage("Sorting into "+proper(this.table.getPureName()))
		for m.i = 1 to m.sorted.getTableCount()
			m.table = m.sorted.getTable(m.i)
			select (m.table.alias)
			go top
			m.key = evaluate(m.sortexp)
			m.pos = m.top.getKey(m.key)
			if m.pos > 0
				m.newcol = m.top.item(m.pos)
			else
				m.newcol = m.cols.borrow()
				m.newcol.add(m.key)
				m.top.add(m.newcol,m.key)
			endif
			m.newcol.add(m.i)
		endfor
		do while m.top.count > 0
			for each item in m.top
				m.col = m.item
				exit
			endfor
			m.top.remove(m.col.item(1))
			m.col.remove(1)
			for each item in m.col
				m.table = m.sorted.getTable(m.item)
				select (m.table.alias)
				scatter memo to m.buffer
				m.overflowerr = .f.
				try
					&ins
				catch
					m.overflowerr = .t.
				endtry
				if m.overflowerr
					if not this.appendTable()
						this.messenger.errorMessage("Cluster overlow.")
						return .f.
					endif
					this.messenger.forceMessage("Sorting into "+proper(this.table.getPureName()))
					m.ins = strtran(m.insexp,"?",this.table.alias)
					&ins
				endif
				skip
				if not eof()
					m.key = evaluate(m.sortexp)
					m.pos = m.top.getKey(m.key)
					if m.pos > 0
						m.newcol = m.top.item(m.pos)
					else
						m.newcol = m.cols.borrow()
						m.newcol.add(m.key)
						m.top.add(m.newcol,m.key)
					endif
					m.newcol.add(m.item)
				endif
			endfor
			m.cols.return(m.col)
		enddo
		this.messenger.clearMessage()
		return .t.	
	endfunc
	
	function seek(key)
		local oldindex
		if seek(m.key,this.table.alias)
			return .t.
		endif
		m.oldindex = this.index
		this.index = 1
		this.table = this.cluster.item(1)
		this.offset = 0
		do while icase(this.index == m.oldindex, .t., not seek(m.key, this.table.alias))
			if this.index >= this.cluster.count
				return .f.
			endif
			this.offset = this.offset+reccount(this.table.alias)
			this.index = this.index+1
			this.table = this.cluster.item(this.index)
		enddo
		return .t.
	endfunc
	
	function find(key) && automatically sets focus on active table
		this.offset = 0
		this.key = m.key
		for this.index = 1 to this.cluster.count
			this.table = this.cluster.item(this.index)
			select (this.table.alias)
			if seek(m.key)
				return .t.
			endif
			this.offset = this.offset + reccount(this.table.alias)
		endfor
		return .f.
	endfunc
	
	function next() && automatically sets focus on active table
		select (this.table.alias)
		skip
		if not eof() and evaluate(this.keyexp) == this.key
			return .t.
		endif
		this.offset = this.offset + reccount()
		for this.index = this.index+1 to this.cluster.count
			this.table = this.cluster.item(this.index)
			select (this.table.alias)
			if seek(this.key)
				return .t.
			endif
			this.offset = this.offset + reccount(this.table.alias)
		endfor
		return .f.
	endfunc

	function rewind()
		this.offset = 0
		this.index = 1
		if this.cluster.count > 0
			this.table = this.cluster.item(1)
			go top in (this.table.alias)
			return .t.
		endif
		return .f.
	endfunc
	
	function selectRecord(record as Integer)
		if this.goRecord(m.record)
			this.selectActiveTable()
			return .t.
		endif
		return .f.
	endfunc
	
	function goRecord(record as Integer)
		local reccount
		if m.record > this.offset
			m.record = m.record-this.offset
			m.reccount = reccount(this.table.alias)
			if m.record <= m.reccount
				go (m.record) in (this.table.alias)
				return .t.
			endif
			if this.index >= this.cluster.count
				return .f.
			endif
			this.index = this.index + 1
			this.offset = this.offset+m.reccount
			m.record = m.record-m.reccount
			do while .t.
				this.table = this.cluster.item(this.index)
				m.reccount = reccount(this.table.alias)
				if m.record <= m.reccount
					go (m.record) in (this.table.alias)
					return .t.
				endif
				if this.index >= this.cluster.count
					return .f.
				endif
				this.index = this.index + 1
				this.offset = this.offset+m.reccount
				m.record = m.record-m.reccount
			enddo
		endif
		if this.index <= 1
			return .f.
		endif
		this.index = this.index-1
		do while .t.
			this.table = this.cluster.item(this.index)
			m.reccount = reccount(this.table.alias)
			this.offset = this.offset-m.reccount
			if m.record > this.offset
				go (m.record-this.offset) in (this.table.alias)
				return .t.
			endif
			if this.index <= 1
				return .f.
			endif
			this.index = this.index-1
		enddo
	endfunc
	
	function compress(sizeMB as Integer)
		return this.adjust(m.sizeMB)
	endfunc

	function spread(sizeMB as Integer)
		return this.adjust(m.sizeMB)
	endfunc
	
	function copy(cluster as TableCluster, sizeMB as Integer)
	local pa, ps1, ps2, ps3, ps4, i, table
		if vartype(m.sizeMB) == "L"
			m.pa = createobject("PreservedAlias")
			m.ps1 = createobject("PreservedSetting","talk","off")
			m.ps2 = createobject("PreservedSetting","escape","off")
			m.ps3 = createobject("PreservedSetting","safety","off")
			m.ps4 = createobject("PreservedSetting","exclusive","on")
			this.messenger.forceMessage("Copying...")
			if not m.cluster.isValid()
				this.messenger.forceMessage("Invalid cluster.")
				return .f.
			endif
			this.erase(.t.)
			if m.cluster.cluster.count == 1
				m.table = m.cluster.cluster.item(1)
				this.messenger.forceMessage("Copying "+proper(m.table.getPureName()))
				select (m.table.alias)
				copy to (this.path+this.start) with cdx
			else
				this.forceConformity()
				for m.i = 1 to m.cluster.cluster.count
					m.table = m.cluster.cluster.item(m.i)
					this.messenger.forceMessage("Copying "+proper(m.table.getPureName()))
					select (m.table.alias)
					copy to (this.createTableName(max(this.first,1)+m.i-1)) with cdx
				endfor
			endif
			this.rebuild(m.cluster.cluster.count)
			this.messenger.clearMessage()
			return .t.
		endif
		return this.adjust(m.sizeMB, m.cluster)
	endfunc

	function adjust(sizeMB as Integer, source as TableCluster)
	local pa, ps1, ps2, ps3, ps4, ps5, swap
	local limit, struc, buffer, target_cluster, target
	local rec_size, empty_rec_size, empty_memo_size, size, memo_size
	local max_records, records_left, i, j
	local table, start, stop
	local memos, blocksize, datasize, len, bytes
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","escape","off")
		m.ps3 = createobject("PreservedSetting","safety","off")
		m.ps4 = createobject("PreservedSetting","deleted","off")
		m.ps5 = createobject("PreservedSetting","exclusive","on")
		this.messenger.forceMessage("Adjusting...")
		if vartype(m.sizeMB) == "O"
			m.swap = m.sizeMB
			m.sizeMB = m.source
			m.source = m.swap
		endif
		if not vartype(m.source) == "O"
			m.source = this
		endif
		if not m.source.isValid()
			this.messenger.forceMessage("Invalid cluster.")
			return .f.
		endif
		if not m.source.callAnd('useExclusive()')
			this.messenger.errorMessage("Unable to get exclusive access on all tables.")
			return .f.
		endif
		if vartype(m.sizeMB) == "N" and m.sizeMB > 0
			m.limit = 1024 * 1024 * min(m.sizeMB, 2000)
		else
			m.limit = 1000 * 1000 * 1000 * 2
		endif
		m.source.setKey()
		m.struc = m.source.getTableStructure()
		m.buffer = createobject("TempAlias")
		if m.source == this
			m.target_cluster = createobject("CursorCluster",this.path)
		else
			m.target_cluster = this
			m.target_cluster.erase(.t.)
		endif
		m.target_cluster.appendTable(m.struc)
		m.target = m.target_cluster.table
		m.rec_size = m.struc.getRecordSize()
		m.empty_rec_size = m.target.getDBFsize()
		m.empty_memo_size = m.target.getFPTsize()
		m.memos = m.struc.getStructureByType("M")
		if m.memos.getFieldCount() > 0
			m.blocksize = int(val(sys(2012, m.target.alias)))
			m.datasize = m.blocksize - 8
			m.size = m.empty_rec_size
			m.memo_size = m.empty_memo_size
			for m.i = 1 to m.source.cluster.count
				m.table = m.source.cluster.item(m.i)
				this.messenger.forceMessage("Adjusting "+proper(m.table.getPureName()))
				m.start = 1
				m.table.select()
				scan
					m.size = m.size+m.rec_size
					m.bytes = 0
					for m.j = 1 to m.memos.getFieldCount()
						m.len = len(evaluate(m.memos.tstruct[m.j,1]))
						if m.len > 0
							m.bytes = m.bytes + (int((m.len - 1) / m.datasize) + 1)
						endif
					endfor
					m.memo_size = m.memo_size + m.bytes * blocksize
					if m.size > m.limit or m.memo_size > m.limit
						m.stop = recno()-1
						if m.target.reccount() > 0
							select * from (m.table.alias) where between(recno(),m.start,m.stop) into cursor (m.buffer.alias) readwrite
							select (m.target.alias)
							append from dbf(m.buffer.alias)
						else
							select * from (m.table.alias) where between(recno(),m.start,m.stop) into table (m.target.dbf)
							use
							m.target.useExclusive()
						endif
						m.target_cluster.appendTable()
						m.target = m.target_cluster.table
						m.start = m.stop+1
						m.size = m.empty_rec_size
						m.memo_size = m.empty_memo_size
					endif
				endscan
				if m.target.reccount() > 0
					select * from (m.table.alias) where recno() >= m.start into cursor (m.buffer.alias) readwrite
					select (m.target.alias)
					append from dbf(m.buffer.alias)
				else
					select * from (m.table.alias) where recno() >= m.start into table (m.target.dbf)
					use
					m.target.useExclusive()
				endif
			endfor
		else
			m.max_records = int((m.limit-m.empty_rec_size)/m.rec_size)		
			m.records_left = m.max_records
			for m.i = 1 to m.source.cluster.count
				m.table = m.source.cluster.item(m.i)
				this.messenger.forceMessage("Adjusting "+proper(m.table.getPureName()))
				m.start = 1
				do while m.start <= m.table.reccount()
					m.stop = min(m.table.reccount(),m.start+m.records_left-1)
					this.messenger.incProgress(m.stop-m.start-1,1)
					this.messenger.forceProgress()
					if m.target.reccount() > 0
						select * from (m.table.alias) where between(recno(),m.start,m.stop) into cursor (m.buffer.alias) readwrite
						select (m.target.alias)
						append from dbf(m.buffer.alias)
					else
						select * from (m.table.alias) where between(recno(),m.start,m.stop) into table (m.target.dbf)
						use
						m.target.useExclusive()
					endif
					m.records_left = m.max_records-m.target.reccount()
					if m.records_left <= 0
						m.target_cluster.appendTable()
						m.target = m.target_cluster.table
						m.records_left = m.max_records
					endif
					m.start = m.stop+1
				enddo
			endfor
		endif
		this.messenger.forceMessage("Adjusting...")
		if m.source == this
			this.erase(.t.)
			for m.i = 1 to m.target_cluster.cluster.count
				m.table = m.target_cluster.cluster.item(m.i)
				m.table.rename(this.createTableName(max(this.first,1)+m.i-1,.t.))
			endfor
			m.target_cluster.close()
			this.rebuild(m.target_cluster.cluster.count)
			m.target_cluster.cluster.remove(-1)
		endif
		this.messenger.clearMessage()
		return .t.
	endfunc
	
	function consume(template as String, reqStructure as String)
	local ps1, ps2, pa, dir, pos, cnt, i, struc, table, newname
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","safety","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		this.messenger.forceMessage("Consuming...")
		if not this.isCreatable()
			this.messenger.errorMessage("Unable to create TableCluster.")
			return .f.
		endif
		if not vartype(m.template) == "C" or empty(m.template)
			m.template = "*.dbf"
		endif
		if not "." $ m.template
			m.template = m.template+".dbf"
		endif
		if vartype(m.reqStructure) == "C" and not empty(m.reqStructure)
			m.reqStructure = createobject("TableStructure",m.reqStructure)
			if not m.reqStructure.isValid()
				this.messenger.errorMessage("Invalid table structure definition.")
				return .f.
			endif
		endif
		if not vartype(m.reqStructure) == "O"
			m.reqStructure = createobject("TableStructure")
		endif		
		dimension m.dir[1]
		m.cnt = adir(m.dir,this.getPath()+m.template)
		m.pos = this.first-1
		for m.i = 1 to m.cnt
			m.table = createobject("BaseTable",this.getPath()+m.dir[m.i,1])
			if not m.table.isValid()
				m.table.close()
				loop
			endif
			m.struc = m.table.getTableStructure()
			if not m.reqStructure.checkStructure(m.struc)
				m.table.close()
				loop
			endif
			m.table.deleteKey()
			m.table.close()
			m.pos = m.pos+1
			this.messenger.forceMessage("Consuming "+upper(m.table.getPureName()))
			m.newname = this.createTableName(m.pos)
			erase (m.newname+".dbf")
			erase (m.newname+".fpt")
			erase (m.newname+".cdx")
			rename (m.table.getDBF()) to (m.newname+".dbf")
			try
				rename (forceext(m.table.getDBF(),"fpt")) to (m.newname+".fpt")
			catch
			endtry
			try
				rename (forceext(m.table.getDBF(),"cdx")) to (m.newname+".cdx")
			catch
			endtry
		endfor
		if m.pos < this.first
			this.messenger.errorMessage("No consumable table found.")
			return .f.
		endif
		this.rebuild()
		if this.getTableCount() == 0
			this.messenger.errorMessage("Unable to build TableCluster.")
			return .f.
		endif
		this.compress()
		return .t.
	endfunc
	
	function synchronize()
		this.index = 1
		this.offset = 0
		this.table = this.cluster.item(1)
	endfunc
	
	function getTableStructure()
	local table, struc, i
		if this.cluster.count == 0
			return createobject("TableStructure")
		endif
		m.table = this.cluster.item(1)
		m.struc = m.table.getTableStructure()
		if not this.tolerant
			return m.struc
		endif
		for m.i = 2 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.struc = m.struc.adjust(m.table.getTableStructure())
		endfor
		return m.struc
	endfunc

	function toString()
		local str, tc
		m.tc = "TableCount: "+ltrim(str(this.getTableCount(),18))
		if this.getTableCount() > 0
			m.str = this.getTable(1)
			return m.str.toString(proper(this.class)+chr(10)+m.tc, this)
		endif
		return "Class: "+proper(this.class)+chr(10)+m.tc+chr(10)
	endfunc
	
	function forceKey(keyexp as String)
	local rc
		this.keyexp = ""
		this.key = .null.
		m.rc = this.callAnd("forceKey('"+m.keyexp+"')")
		if m.rc
			this.keyexp = m.keyexp
		endif
		return m.rc
	endfunc
	
	function setKey(keyexp as String)
	local rc
		this.keyexp = ""
		this.key = .null.
		if vartype(m.keyexp) == "L"
			m.rc = this.callAnd("setKey()")
		else
			m.rc = this.callAnd("setKey('"+m.keyexp+"')")
		endif
		if m.rc
			this.keyexp = m.keyexp
		endif
		return m.rc
	endfunc
	
	function deleteKey(keyexp as String)
		this.keyexp = ""
		this.key = .null.
		if vartype(m.keyexp) == "L"
			return this.callAnd("deleteKey()")
		endif
		return this.callAnd("deleteKey('"+m.keyexp+"')")
	endfunc
	
	function erase(full)
		this.call('erase()')
		if m.full
			this.cluster.remove(-1)
		endif
	endfunc
	
	function close()
		return this.callAnd('close()')
	endfunc
	
	function open()
		return this.callAnd('open()')
	endfunc

	function pack(memo)
		if m.memo == .f.
			return this.callAnd('pack()')
		endif
		return this.callAnd('pack(.t.)')
	endfunc
	
	function reccount()
		return this.callSum('reccount()')
	endfunc
	
	function goTop()
		return this.callAnd('goTop()')
	endfunc
	
	function useExclusive()
		return this.callAnd('useExclusive()')
	endfunc

	function useShared()
		return this.callAnd('useShared()')
	endfunc
	
	function use()
		return this.callAnd('use()')
	endfunc

	function lineNumber(linefield as String, offset as Integer)
	local pa, ps1, ps2, ps3
	local i, table, upd, struc, f
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","escape","off")
		m.ps3 = createobject("PreservedSetting","deleted","off")
		this.messenger.forceMessage("Numbering...")
		if not vartype(m.offset) == "N"
			m.offset = 0
		endif
		m.linefield = alltrim(m.linefield)
		m.struc = this.getTableStructure()
		m.f = m.struc.getFieldStructure(m.linefield)
		if not inlist(m.f.getType(),"I","N","B","F","Y")
			this.messenger.errorMessage("Invalid line field.")
			return .f.
		endif
		for m.i = 1 to this.cluster.count
			this.messenger.forceMessage("Numbering "+ltrim(str(m.i,10))+"/"+ltrim(str(this.cluster.count,10)))
			m.table = this.cluster.item(m.i)
			m.upd = "update "+m.table.alias+" set "+m.table.alias+"."+m.linefield+" = recno()+m.offset"
			&upd
			m.offset = m.offset+m.table.reccount()
		endfor
		this.messenger.forceMessage("")
		return this.cluster.count > 0
	endfunc

	function getRecordSize()
	local struc
		m.struc = this.getTableStructure()
		return m.struc.getRecordSize()
	endfunc

	function isCreatable()
	local cluster, i, trunc
	local array dir[1]
		if this.cluster.count > 0
			return this.callAnd("iscreatable()")
		endif
		m.trunc = this.conformTrunc()
		for m.i = 1 to adir(m.dir,this.path+m.trunc+".dbf")
			m.cluster = createobject("TableCluster",this.path+m.dir[m.i,1],1)
			if m.cluster.trunc == m.trunc and m.cluster.first >= this.first
				return .f.
			endif
		endfor
		return .t.
	endfunc

	function setCursor(cursor as Boolean)
		this.cursor = iif(vartype(m.cursor) == "L", m.cursor, .f.)
	endfunc
	
	function isCursor()
		return this.cursor
	endfunc
	
	function modifyStructure(struc as String)
		return this.callAnd('modifyStructure("'+m.struc+'")')
	endfunc

	hidden function parseForExpression(sql as String)
	local col, usql, pos, start, end, ind, lex, var1, var2, clu1, clu2, where
		m.col = createobject("Collection")
		m.usql = upper(m.sql)
		if not (" FOR " $ m.usql and not " WHERE " $ m.usql)
			return .t.
		endif
		m.start = at(" FROM ",m.usql)+6
		m.usql = substr(m.usql,m.start)
		if not " FOR " $ m.usql
			return .t.
		endif
		m.pos = at(" FOR ",m.usql)
		m.start = m.start+m.pos-1
		m.usql = substr(m.usql,m.pos+5)
		m.end = len(m.usql)+1
		m.end = min(evl(at(" GROUP ", m.usql),m.end),evl(at(" ORDER ", m.usql),m.end))
		m.usql = left(m.usql,m.end-1)
		m.end = m.start+m.end+4
		m.where = ""
		m.usql = strtran(m.usql," AND ", "&")
		m.usql = strtran(m.usql,"==", "=")
		m.ind = 1
		m.lex = getwordnum(m.usql,m.ind,"&")
		do while not empty(m.lex)
			m.var1 = strtran(getwordnum(m.lex,1,"=")," ","")
			m.var2 = strtran(getwordnum(m.lex,2,"=")," ","")
			m.clu1 = getwordnum(m.var1,getwordcount(m.var1,"."),".")
			m.clu2 = getwordnum(m.var2,getwordcount(m.var2,"."),".")
			if not m.clu1 == ltrim(str(val(m.clu1))) or not m.clu2 == ltrim(str(val(m.clu2)))
				return .f.
			endif
			m.clu1 = val(m.clu1)
			m.clu2 = val(m.clu2)
			if not between(m.clu1,1,4) or not between(m.clu2,1,4)
				return .f.
			endif
			m.var1 = left(m.var1,rat(".",m.var1)-1)
			m.var2 = left(m.var2,rat(".",m.var2)-1)
			m.where = m.where+" AND "+m.var1+" == "+m.var2
			m.var1 = m.var1+"|"+ltrim(str(m.clu1))
			m.var2 = m.var2+"|"+ltrim(str(m.clu2))
			m.col.add(m.var1+"&"+m.var2)
			m.ind = m.ind+1
			m.lex = getwordnum(m.usql,m.ind,"&")
		enddo
		m.sql = left(m.sql,m.start)+"WHERE [PLUGIN] "+substr(m.where,6)+substr(m.sql,m.end)
		return m.col
	endfunc
enddefine

define class CursorCluster as TableCluster
	hidden dummy

	function init(path)
	local file, dir, i, cnt, pa
		m.pa = createobject("PreservedAlias")
		this.setCursor(.t.)
		dimension m.dir[1]
		if not vartype(m.path) == "C"
			m.path = sys(2023)
		endif
		m.path = rtrim(strtran(m.path,"/","\"),"\")+"\"
		m.cnt = 0
		for m.i = 1 to 1000
			m.file = m.path+sys(3)
			if adir(m.dir,m.file+"_*.dbf") == 0 and not file(m.file+"_X.TMP")
				exit
			endif
		endfor
		if m.i > 1000
			TableCluster::init()
			return
		endif
		this.dummy = m.file+"_X.TMP"
		create table (this.dummy) (dummy n(1))
		use
		TableCluster::init(m.file+"_1.dbf")
	endfunc

	function appendTable(struc)
		if this.cluster.count == 0 and vartype(m.struc) == "L"
			m.struc = "dummy c(1)"
		endif
		return TableCluster::appendTable(m.struc)
	endfunc
	
	function destroy()
		if this.cursor
			this.call("setCursor(.t.)")
		endif
		erase (this.dummy)
	endfunc
enddefine


define class Grouping as Custom
	variable = ""
	as = ""
	command = "xxx(?)"
	value = .f.
	
	function init(variable, as)
		this.variable = m.variable
		this.as = m.as
	endfunc
	
	function set(value)
		this.value = m.value
	endfunc
	
	function execute(op)
		this.value = this.value+m.op
	endfunc
	
	function sql()
	local sql
		m.sql = strtran(this.command,"?",this.variable)
		if not empty(this.as)
			m.sql = m.sql+" as "+this.as
		endif
		return m.sql
	endfunc
	
	function isValid(struc as Object)
	local f
		if this.variable == "*"
			return .t.
		endif
		m.f = m.struc.getFieldStructure(this.variable)
		return m.f.isValid()
	endfunc
enddefine


define class SumGroup as Grouping
	command = "sum(?)"
enddefine

define class MaxGroup as Grouping
	command = "max(?)"

	function execute(op)
		if m.op > this.value
			this.value = m.op
		endif
	endfunc
enddefine

define class MinGroup as Grouping
	command = "min(?)"
	
	function execute(op)
		if m.op < this.value
			this.value = m.op
		endif
	endfunc
enddefine

define class CountGroup as Grouping
	command = "count(?)"
	
	function execute(op)
		this.value = this.value+m.op
	endfunc
enddefine