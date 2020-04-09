*=========================================================================*
*   Modul:      cluster.prg
*   Date:       2020.03.15
*   Author:     Thorsten Doherr
*   Required:   custom.prg
*   Function:   A TableCluster is group of table with compatible
*               structures. All tables share the same name 
*               followed by a sequential number (i.e.: tab001.dbf,
*               tab002.dbf, tab003.dbf, ...). The first table in a
*               cluster defines the starting number and the base
*               structure.
*=========================================================================*
define class TableCluster as Custom
	protected cluster, offset, index, start, trunc, path, tolerant, messenger
	protected start, leading0, first, cursor, pseudo, preserve
	tolerant = .f.
	careless = .f.
	offset = 0
	index = 1
	table = .f.
	start = ""
	first = 0
	path = ""
	leading0 = 0
	cursor = .f.
	pseudo = .f.
	preserve = .f.
	errorCancel = .f.
	
	function init(startTable as String, tableCount as Integer, tolerant as boolean, careless as boolean)
		this.messenger = createobject("Messenger", this.errorCancel)
		this.messenger.setInterval(2)
		this.preserve = createobject("Collection")
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
		m.num = val(substr(m.name,m.start+1,m.len))
		this.first = m.num
		dimension m.dir[1]
		this.trunc = substr(m.name,1,m.start)+"*"+substr(m.name,m.end+1)
		m.name = substr(m.name,m.end+1)
		m.dircnt = adir(m.dir,this.path+this.trunc+".dbf")
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
	
	function createTableName(num as Integer, pure as Boolean)
		if this.pseudo and m.num <= 0
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
		this.build(this.path+this.start,m.tableCount,this.tolerant,this.careless)
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
	
	function getTable(index as Integer)
		return this.cluster.item(m.index)
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

	function getActiveTable()
		return this.table
	endfunc
	
	function getIndex()
		return this.index
	endfunc
	
	function getFirst()
		return this.first
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

	function callAnd(method as String)
		local table, com, i
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.com = "m.table."+m.method
			if &com == .f.
				return .f.
			endif
		endfor
		return this.cluster.count > 0
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
	
	function preserveKeys()
	local i, j, key, table
		this.preserve.remove(-1)
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			m.j = 1
			m.key = m.table.getKey(m.j)
			do while not empty(m.key)
				if this.preserve.getKey(m.key) == 0
					this.preserve.add(m.key,m.key)
				endif
				m.j = m.j+1
				m.key = m.table.getKey(m.j)
			enddo
		endfor
		return this.preserve.count
	endfunc

	function restoreKeys()
	local i, cnt
		m.cnt = 0
		for m.i = 1 to this.preserve.count
			if this.forceKey(this.preserve.item(m.i))
				m.cnt = m.cnt+1
			endif
		endfor
		return m.cnt
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
		if not inlist(m.type,"update","select","delete")
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
			this.messenger.errorMessage("No valid clusters detected.")
			return .f.
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
		m.struc = m.table.getTableStructure()
		this.messenger.forceMessage("Appending...")
		m.first = this.first-1
		this.messenger.setDefault("Appending")
		this.messenger.startProgress(m.cluster.getTableCount())
		this.messenger.startCancel("Cancel Operation?","Cluster Append","Canceled.")
		for m.c = 1 to m.cluster.getTableCount()
			this.messenger.setProgress(m.c)
			this.messenger.forceProgress()
			if this.messenger.queryCancel()
				m.c = this.getTableCount()+1
				exit
			endif
			m.clustertable = m.cluster.getTable(m.c)
			m.table = createobject("BaseTable",this.createTableName(m.first+this.getTableCount()+m.c))
			m.table.erase()
			m.table.create(m.struc)
			m.table.select()
			append from (m.clustertable.getDBF())
		endfor
		this.messenger.sneakMessage("Cleaning...")
		m.table = createobject("TableCluster",this.createTableName(m.first+this.getTableCount()+m.c))
		m.table.erase()
		this.build(this.path+this.start,this.getTableCount()+m.cluster.getTableCount(),.t.)
		return not this.messenger.isInterrupted()
	endfunc

	function cgroup(tablecluster as Object, groupby as String, grouping as String)
	local pa, ps1, ps2, ps3, ps4, lm, first
	local table1, table2, struc, sqlbase, sql, i, j, k, list, item
	local bysize, by, change, cnt, value
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","deleted","off")
		m.lm = createobject("LastMessage",this.messenger)
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
		this.messenger.setDefault("Grouping")
		this.messenger.startProgress(m.tablecluster.getTableCount())
		this.messenger.startCancel("Cancel Operation?","Cluster Grouping","Canceled.")
		for m.i = 1 to m.tablecluster.getTableCount()
			this.messenger.setProgress(m.i)
			this.messenger.forceProgress()
			if this.messenger.queryCancel()
				this.messenger.sneakMessage("Canceling...")
				m.tablecluster = createobject("TableCluster",this.createTableName(m.first+1))
				m.tablecluster.erase()
				return .f.
			endif
			m.table1 = m.tableCluster.getTable(m.i)
			m.sql = strtran(strtran(m.sqlbase,"?1",m.table1.getAlias()),"?2",this.createTableName(m.first+m.i))
			&sql
			use
		endfor
		m.tablecluster = createobject("TableCluster",this.createTableName(m.first+m.i))
		m.tablecluster.erase()
		this.rebuild(-1)
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
		this.messenger.setDefault("Collecting")
		this.messenger.startProgress(this.cluster.count - 1)
		for m.i = 1 to this.cluster.count - 1
			this.messenger.setProgress(m.i)
			this.messenger.forceProgress()
			if this.messenger.queryCancel()
				this.messenger.sneakMessage("Canceling...")
				this.erase()
				this.cluster.remove(-1)
				return .f.
			endif
			m.table1 = this.cluster.item(m.i)
			select (m.table1.alias)
			scan
				if deleted()
					loop
				endif
				for m.j = 1 to m.grouping.count
					m.item = m.grouping.item(m.j)
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
					m.k = 0
					do while m.k <= m.bysize and not eof()
						if deleted()
							skip
							loop
						endif
						m.cnt = 0
						for m.k = 1 to m.bysize
							m.value = evaluate(m.by[m.k,1])
							if m.value < m.by[m.k,2]
								skip
								exit
							endif
							if m.value > m.by[m.k,2]
								m.k = m.bysize+1
								exit
							endif
							m.cnt = m.cnt+1
						endfor
					enddo
					if not eof() and m.cnt == m.bysize
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
		this.messenger.forceMessage("Cleaning...")
		this.pack()
		return .t.	
	endfunc

	function csort(tablecluster as Object, sortby as String)
	local pa, ps1, ps2, ps3, ps4, lm
	local struc, table, tables, i, sortexp, sql, sorted, pos, top
	local insexp, ins, col, target, tarind, buffer, overflowerr, item, key
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","safety","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","deleted","off")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Sorting...")
		if m.tablecluster.getTableCount() == 0
			this.messenger.errorMessage("Empty TableCluster.")
			return .f.
		endif
		if vartype(m.sortby) == "C"
			m.sortby = createobject("TableStructure",m.sortby)
		endif
		if not m.sortby.isValid()
			this.messenger.errorMessage("Invalid sortby parameter.")
			return .f.
		endif
		m.struc = m.tablecluster.getTableStructure()
		if not m.sortby.checkNames(m.struc)
			this.messenger.errorMessage("Unknown sortby field.")
			return .f.
		endif
		if m.tableCluster.getTableCount() == 1
			if this.getTableCount() > 0 and not this.erase()
				this.messenger.errorMessage("Unable to clear table cluster.")
				return .f.
			endif
			m.table = m.tableCluster.getTable(1)
			this.messenger.forceMessage("Sorting "+proper(m.table.getPureName()))
			m.sql = "select * from (m.table.alias) order by "+m.sortby.getFieldList()+" into table "+this.path+this.start
			&sql
			use
			this.rebuild()
			return .t.
		endif
		this.build(this.path+this.start,m.tableCluster.getTableCount()*2,.t.)
		if this.getTableCount() > 0 and not this.erase()
			this.messenger.errorMessage("Unable to clear table cluster.")
			return .f.
		endif
		this.cluster.remove(-1)
		m.sortexp = createobject("ComposedKey",m.struc,m.sortby.getFieldList(),.t.)
		m.sortexp = m.sortexp.getExp()
		for m.i = 1 to m.tableCluster.getTableCount()
			m.table = m.tableCluster.getTable(m.i)
			this.messenger.forceMessage("Sorting "+proper(m.table.getPureName()))
			m.sql = "select * from (m.table.alias) order by "+m.sortby.getFieldList()+" into table "+this.createTableName(this.first+m.i+m.tableCluster.getTableCount()-1)
			&sql
			use
		endfor
		m.sorted = createobject("TableCluster",this.createTableName(this.first+m.tableCluster.getTableCount()),m.tableCluster.getTableCount())
		for m.i = 1 to m.tableCluster.getTableCount()
			m.table = m.sorted.getTable(m.i)
			m.struc = m.table.getTableStructure()
			m.table = createobject("BaseTable",this.createTableName(this.first+m.i-1))
			this.messenger.forceMessage("Creating "+proper(m.table.getPureName()))
			if not m.table.create(m.struc)
				this.messenger.errorMessage("Unable to create cluster table.")
				return .f.
			endif
			m.table.close()
		endfor
		this.build(this.path+this.start,m.tableCluster.getTableCount(),.t.)
		m.struc = this.getTableStructure()
		m.insexp = "insert into ? values (m.buffer[1]"
		for m.i = 2 to m.struc.getFieldCount()
			m.insexp = m.insexp+",m.buffer["+ltrim(str(m.i))+"]"
		endfor
		m.insexp = m.insexp+")"
		dimension m.buffer[m.struc.getFieldCount()]
		m.tarind = 1
		m.target = this.getTable(m.tarind)
		m.ins = strtran(m.insexp,"?",m.target.alias)
		m.top = createobject("Collection")
		m.top.keysort = 2
		this.messenger.forceMessage("Filling "+proper(m.target.getPureName()))
		for m.i = 1 to m.sorted.getTableCount()
			m.table = m.sorted.getTable(m.i)
			select (m.table.alias)
			go top
			m.key = evaluate(m.sortexp)
			m.pos = m.top.getKey(m.key)
			if m.pos > 0
				m.col = m.top.item(m.pos)
			else
				m.col = createobject("Collection")
				m.col.add(m.key)
				m.col.add(createobject("Collection"))
				m.top.add(m.col,m.key)
			endif
			m.col = m.col.item(2)
			m.col.add(m.table)
		endfor
		do while m.top.count > 0
			for each item in m.top
				m.col = m.item
				exit
			endfor
			m.top.remove(m.col.item(1))
			m.tables = m.col.item(2)
			for each item in m.tables
				select (m.item.alias)
				scatter memo to m.buffer
				m.overflowerr = .f.
				try
					&ins
				catch
					m.overflowerr = .t.
				endtry
				if m.overflowerr
					m.tarind = m.tarind + 1
					if m.tarind > this.getTableCount()
						m.sorted.call('erase()')
						this.messenger.errorMessage("Cluster overlow.")
						return .f.
					endif
					m.target = this.getTable(m.tarind)
					this.messenger.forceMessage("Filling "+proper(m.target.getPureName()))
					m.ins = strtran(m.insexp,"?",m.target.alias)
					&ins
				endif
				skip
				if not eof()
					m.key = evaluate(m.sortexp)
					m.pos = m.top.getKey(m.key)
					if m.pos > 0
						m.col = m.top.item(m.pos)
					else
						m.col = createobject("Collection")
						m.col.add(m.key)
						m.col.add(createobject("Collection"))
						m.top.add(m.col,m.key)
					endif
					m.col = m.col.item(2)
					m.col.add(m.item)
				endif
			endfor
		enddo
		this.messenger.forceMessage("Cleaning...")
		m.sorted.call('erase()')
		for m.i = this.getTableCount() to 1 step -1
			m.table = this.getTable(m.i)
			if m.table.getReccount() > 0
				exit
			endif
			m.table.erase()
			this.cluster.remove(m.i)
		endfor
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
	local target, targetnr, source, sourcenr, struc, i, f, memo
	local dbfsize, fptsize, recsize, limit, records, buffer, full
	local ps1, ps2, ps3, ps4, pa, combined
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","deleted","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","safety","off")
		this.messenger.forceMessage("Compressing...")
		if not this.callAnd('useExclusive()')
			this.messenger.errorMessage("Unable to get exclusive access on all tables.")
			return .f.
		endif
		this.call('deleteKey()')
		m.buffer = createobject("UniqueAlias",.t.)
		m.targetnr = 1
		m.target = this.cluster.item(m.targetnr)
		m.struc = m.target.getTableStructure()
		m.memo = .f.
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if m.f.getType() == "M"
				m.memo = .t.
				exit
			endif
		endfor
		m.dbfsize = m.target.getDBFsize()
		m.fptsize = m.target.getFPTsize()
		m.recsize = m.target.getRecordSize()
		if vartype(m.sizeMB) == "N" and m.sizeMB > 0
			m.limit = 1024 * 1024 * min(m.sizeMB, 2000)
			m.combined = .t.
		else
			m.limit = 1000 * 1000 * 1000 * 2
			m.combined = .f.
		endif
		m.struc = m.target.getTableStructure()
		m.target.select()
		m.sourcenr = 2
		do while m.sourcenr <= this.cluster.count
			m.source = this.cluster.item(m.sourcenr)
			this.messenger.forceMessage("Compressing "+proper(m.source.getPureName())+" into "+proper(m.target.getPureName()))
			m.full = .f.
			if m.memo
				m.records = 0
				select (m.source.alias)
				if m.combined
					scan
						m.dbfsize = m.dbfsize + m.recsize
						m.fptsize = m.fptsize + m.source.getMemoSize()
						if m.dbfsize+fptsize > m.limit
							m.full = .t.
							m.dbfsize = m.dbfsize - m.recsize
							m.fptsize = m.fptsize - m.source.getMemoSize()
							exit
						endif
						m.records = m.records+1
					endscan
				else
					scan
						m.dbfsize = m.dbfsize + m.recsize
						m.fptsize = m.fptsize + m.source.getMemoSize()
						if m.dbfsize > m.limit or m.fptsize > m.limit
							m.full = .t.
							m.dbfsize = m.dbfsize - m.recsize
							m.fptsize = m.fptsize - m.source.getMemoSize()
							exit
						endif
						m.records = m.records+1
					endscan
				endif
			else
				m.records = int((m.limit-m.dbfsize)/m.recsize)
				if m.records <= reccount(m.source.alias)
					m.full = .t.
				else
					m.records = reccount(m.source.alias)
				endif
				m.dbfsize = m.dbfsize + m.records * m.recsize
			endif
			if m.records > 0
				if m.records == reccount(m.source.alias)
					select (m.target.alias)
					append from (dbf(m.source.alias))
					zap in m.source.alias
				else
					select * from (m.source.alias) where recno() <= m.records into cursor (m.buffer.alias) readwrite
					select (m.target.alias)
					append from (dbf(m.buffer.alias))
					delete while recno() <= m.records in (m.source.alias)
					pack in (m.source.alias)
				endif 
			endif
			if m.full
				m.targetnr = m.targetnr+1
				m.target = this.cluster.item(m.targetnr)
				m.dbfsize = m.target.getDBFsize()
				m.fptsize = m.target.getFPTsize()
				m.recsize = m.target.getRecordSize()				
				if m.targetnr >= m.sourcenr
					m.sourcenr = m.targetnr+1
				endif
			else
				m.sourcenr = m.sourcenr+1
			endif
		enddo
		this.messenger.forceMessage("Closing...")
		do while this.cluster.count > m.targetnr
			m.target = this.cluster.item(this.cluster.count)
			m.target.erase()
			this.cluster.remove(this.cluster.count)
		enddo
		this.messenger.forceMessage("")
		return .t.
	endfunc

	function spread(sizeMB as Integer)
	local target, targetnr, struc, i, f, memo, recsize, emptysize, maxrec
	local table, chunksize, start, stop, cut, first, buffer
	local ps1, ps2, ps3, ps4, pa, limit, targetsize
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","deleted","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","safety","off")
		this.messenger.forceMessage("Spreading...")
		if not this.callAnd('useExclusive()')
			this.messenger.errorMessage("Unable to get exclusive access on all tables.")
			return .f.
		endif
		if not (vartype(m.sizeMB) == "N" and m.sizeMB > 0)
			m.sizeMB = 500
		endif
		m.limit = 1024 * 1024 * min(m.sizeMB, 2000)
		this.call('deleteKey()')
		m.first = this.first-1
		m.buffer = createobject("UniqueAlias",.t.)
		m.table = this.cluster.item(1)
		m.recsize = m.table.getRecordSize()
		m.struc = m.table.getTableStructure()
		m.memo = .f.
		for m.i = 1 to m.struc.getFieldCount()
			m.f = m.struc.getFieldStructure(m.i)
			if m.f.getType() == "M"
				m.memo = .t.
				exit
			endif
		endfor
		m.targetnr = this.cluster.count+1
		m.target = createobject("BaseTable",this.createTableName(m.first+m.targetnr))
		m.target.erase()
		m.target.create(m.struc)
		m.emptysize = m.target.getDBFsize()+ m.target.getFPTsize()
		if m.memo
			m.targetsize = m.emptysize
		else
			m.targetsize = 0
			m.maxrec = int((m.limit-m.emptysize)/m.recsize)
		endif
		for m.i = 1 to this.cluster.count
			m.table = this.cluster.item(m.i)
			this.messenger.forceMessage("Spreading "+proper(m.table.getPureName()))
			if m.table.getDBFsize()+ m.table.getFPTsize() <= m.limit
				loop
			endif
			if m.memo
				m.chunksize = m.emptysize
				m.table.select()
				go top
				do while not eof()
					m.chunksize = m.chunksize+m.recsize+m.table.getMemoSize()
					if m.chunksize > m.limit
						exit
					endif
					skip
				enddo
				m.chunksize = 0
				m.start = recno()
				m.cut = m.start
				do while not eof()
					m.chunksize = m.chunksize+m.recsize+m.table.getMemoSize()
					if m.targetsize+m.chunksize > m.limit
						this.messenger.forceMessage("Spreading "+proper(m.table.getPureName())+" into "+proper(m.target.getPureName()))
						m.stop = recno()-1
						select * from (m.table.alias) where between(recno(),m.start,m.stop) into cursor (m.buffer.alias) readwrite
						select (m.target.alias)
						append from (dbf(m.buffer.alias))
						select (m.table.alias)
						m.start = recno()
						m.chunksize = 0
						m.targetnr = m.targetnr+1
						m.target = createobject("BaseTable",this.createTableName(m.first+m.targetnr))
						m.target.erase()
						m.target.create(m.struc)
						m.targetsize = m.emptysize
						loop
					endif
					skip
				enddo
				m.stop = reccount()
				select * from (m.table.alias) where between(recno(),m.start,m.stop) into cursor (m.buffer.alias) readwrite
				select (m.target.alias)
				append from (dbf(m.buffer.alias))
				select (m.table.alias)
				m.targetsize = m.targetsize+m.chunksize
				delete from (m.table.alias) where recno() >= m.cut
			else
				m.start = m.maxrec+1
				m.cut = m.start
				select (m.table.alias)
				do while m.start <= reccount()
					this.messenger.forceMessage("Spreading "+proper(m.table.getPureName())+" into "+proper(m.target.getPureName()))
					m.stop = min(m.start+m.maxrec-1-m.targetsize,reccount())
					select * from (m.table.alias) where between(recno(),m.start,m.stop) into cursor (m.buffer.alias) readwrite
					select (m.target.alias)
					append from (dbf(m.buffer.alias))
					select (m.table.alias)
					m.targetsize = m.targetsize+m.stop-m.start+1
					m.start = m.stop+1
					if m.targetsize >= m.maxrec
						m.targetnr = m.targetnr+1
						m.target = createobject("BaseTable",this.createTableName(m.first+m.targetnr))
						m.target.erase()
						m.target.create(m.struc)
						m.targetsize = 0
					endif
				enddo
				delete from (m.table.alias) where recno() >= m.cut
			endif
			m.table.pack()
		endfor
		this.messenger.forceMessage("Cleaning...")
		m.target.close()
		this.call('close()')
		m.table = createobject("TableCluster",this.createTableName(m.first+m.targetnr+1))
		m.table.call('erase()')
		m.table = createobject("BaseTable",this.createTableName(m.first+m.targetnr))
		if m.table.getReccount() == 0
			m.table.erase()
		endif
		this.build(this.path+this.start,m.targetnr)
		this.messenger.forceMessage("")
		return .t.
	endfunc
	
	function copy(cluster as TableCluster, sizeMB as Integer)
	local target, targetnr, struc, i, f, memo, recsize, emptysize, maxrec
	local table, chunksize, start, stop
	local ps1, ps2, ps3, ps4, pa, limit
		m.pa = createobject("PreservedAlias")
		m.ps1 = createobject("PreservedSetting","talk","off")
		m.ps2 = createobject("PreservedSetting","deleted","off")
		m.ps3 = createobject("PreservedSetting","escape","off")
		m.ps4 = createobject("PreservedSetting","safety","off")
		this.messenger.forceMessage("Copying...")
		if m.cluster.getTableCount() == 0
			this.messenger.forceMessage("Empty cluster.")
			return .f.
		endif
		if not vartype(m.sizeMB) == "N" 
			m.limit = -1
		else
			m.limit = 1024 * 1024 * max(min(m.sizeMB, 2000),1)
		endif
		if this.getTableCount() > 0 and not this.callAnd('isCreatable()') and not this.callAnd('erase()')
			this.messenger.errorMessage("Unable to clear table cluster.")
			return .f.
		endif
		this.cluster.remove(-1)
		if m.limit <= 0
			for m.i = 1 to m.cluster.getTableCount()
				m.table = m.cluster.getTable(m.i)
				m.target = createobject("BaseTable",this.createTableName(this.first+m.i-1))
				this.messenger.forceMessage("Copying "+proper(m.table.getPureName())+" into "+proper(m.target.getPureName()))
				if not (m.target.isCreatable() or m.target.erase())
					this.messenger.errorMessage("Unable to clear table space.")
					return .f.
				endif
				m.table.select()
				copy to (m.target.getDBF())
			endfor
			m.targetnr = m.cluster.getTableCount()
		else
			m.table = m.cluster.getTable(1)
			m.recsize = m.table.getRecordSize()
			m.struc = m.table.getTableStructure()
			m.memo = .f.
			for m.i = 1 to m.struc.getFieldCount()
				m.f = m.struc.getFieldStructure(m.i)
				if m.f.getType() == "M"
					m.memo = .t.
					exit
				endif
			endfor
			m.target = createobject("BaseTable",this.createTableName(this.first))
			m.target.erase()
			if not m.target.create(m.struc)
				this.messenger.errorMessage("Unable to clear table space.")
				return .f.
			endif
			m.emptysize = m.target.getDBFsize() + m.target.getFPTsize()
			m.target.erase()
			if m.memo == .f.
				m.maxrec = max(int((m.limit-m.emptysize)/m.recsize),1)
			endif
			m.targetnr = 0
			for m.i = 1 to m.cluster.getTableCount()
				m.table = m.cluster.getTable(m.i)
				select (m.table.alias)
				m.start = 1
				m.chunksize = m.emptysize
				if m.memo
					scan
						m.chunksize = m.chunksize + m.recsize + m.table.getMemoSize()
						if m.memo
							m.chunksize = m.chunksize + m.table.getMemoSize()
						endif
						if m.chunksize > m.limit
							m.stop = max(recno(m.table.alias)-1,m.start)
							m.target = createobject("BaseTable",this.createTableName(this.first+m.targetnr))
							if not (m.target.isCreatable() or m.target.erase())
								this.messenger.errorMessage("Unable to clear table space.")
								return .f.
							endif
							this.messenger.forceMessage("Copying "+proper(m.table.getPureName())+" into "+proper(m.target.getPureName()))
							select * from (m.table.alias) where between(recno(),m.start,m.stop) into table (m.target.getDBF())
							use
							m.targetnr = m.targetnr+1
							m.start = m.stop+1
							m.chunksize = m.emptysize
						endif
					endscan
					if m.start <= reccount(m.table.alias)
						m.target = createobject("BaseTable",this.createTableName(this.first+m.targetnr))
						if not (m.target.isCreatable() or m.target.erase())
							this.messenger.errorMessage("Unable to clear table space.")
							return .f.
						endif
						this.messenger.forceMessage("Copying "+proper(m.table.getPureName())+" into "+proper(m.target.getPureName()))
						m.stop = reccount(m.table.alias)
						select * from (m.table.alias) where between(recno(),m.start,m.stop) into table (m.target.getDBF())
						use
						m.targetnr = m.targetnr+1
					endif
				else
					do while m.start <= reccount(m.table.alias)
						m.stop = m.start+m.maxrec-1
						m.target = createobject("BaseTable",this.createTableName(this.first+m.targetnr))
						if not (m.target.isCreatable() or m.target.erase())
							this.messenger.errorMessage("Unable to clear table space.")
							return .f.
						endif
						this.messenger.forceMessage("Copying "+proper(m.table.getPureName())+" into "+proper(m.target.getPureName()))
						select * from (m.table.alias) where between(recno(),m.start,m.stop) into table (m.target.getDBF())
						use
						m.targetnr = m.targetnr+1
						m.start = m.stop+1
					enddo
				endif
			endfor
		endif
		this.messenger.forceMessage("Cleaning...")
		m.table = createobject("TableCluster",this.createTableName(this.first+m.targetnr))
		m.table.erase()
		this.build(this.path+this.start,m.targetnr)
		this.messenger.forceMessage("")
		return .t.
	endfunc
	
	function adjust(sizeMB as Integer)
		if this.compress()
			return this.spread(m.sizeMB)
		endif
		return .f.
	endfunc

	function consume(template as String, reqStructure as String)
	local ps1, ps2, pa, dir, pos, cnt, i, struc, table
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
			erase (this.createTableName(m.pos))
			rename (m.table.getDBF()) to (this.createTableName(m.pos)+".dbf")
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
			return m.str.toString(proper(this.class)+chr(10)+m.tc)
		endif
		return "Class: "+proper(this.class)+chr(10)+m.tc+chr(10)
	endfunc
	
	function forceKey(keyexp as String)
		return this.callAnd("forceKey('"+m.keyexp+"')")
	endfunc
	
	function setKey(keyexp as String)
		if vartype(m.keyexp) == "L"
			return this.callAnd("setKey()")
		endif
		return this.callAnd("setKey('"+m.keyexp+"')")
	endfunc
	
	function deleteKey(keyexp as String)
		if vartype(m.keyexp) == "L"
			return this.callAnd("deleteKey()")
		endif
		return this.callAnd("deleteKey('"+m.keyexp+"')")
	endfunc
	
	function erase()
		this.call('erase()')
	endfunc
	
	function close()
		return this.callAnd('close()')
	endfunc
	
	function open()
		return this.callAnd('open()')
	endfunc

	function pack()
		return this.callAnd('pack()')
	endfunc
	
	function reccount()
		return this.callSum('reccount()')
	endfunc
	
	function goTop()
		return this.callAnd('goTop()')
	endfunc
	
	function erase()

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
	local table
		if this.cluster.count > 0
			return this.callAnd("iscreatable()")
		endif
		m.table = createobject("BaseTable",this.path+this.start)
		return m.table.isCreatable()
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
		m.end = m.start+m.end+5
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