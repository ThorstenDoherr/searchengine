*=========================================================================*
*   Modul:      path.prg
*   Date:       2019.10.14
*   Author:     Thorsten Doherr
*   Required:   custom.prg
*   Function:   Analyses networks and posts information about distances
*               between nodes in a result table, the so called PathTable.
*               The distance can be measured in nodes, it can be a specific
*               distance or a percentage. Each inherited class of the base
*               class PathTable has a special functionality.
*
*               PathTable:           optimized node distance
*				ClusterPathTable:    clustering, grouping, ignores distance
*               FirstPathTable:      reachable nodes
*               CountPathTable:      opt. node dist. & number of opt. paths
*               DistancePathTable:   optimized specific distance
*               PercentPathTable:    optimized percentage distance
*               SharePathTable:      consolidated shareholder analysis
*               InterPathTable:      intermediate shareholder analysis
*
*               Following methods are public:
*
*               create(network_table, fromField, toField [, distField][, cutoff])
*                   Creates the table and starts the pathing.
*                   cutoff specifies the maximum distance for the pathing
*                   algorithm. Distance can be measured in nodes or by a
*                   specific distance dependent on the specialized
*                   sub class.
*               includeStartNode(include)
*                   Sets wether the start node is always included into 
*                   the path table or not. If there is an internal
*                   requirement for the inclusion of the start node
*                   this setting will be ignored.
*               isStartNodeIncluded()
*                   Returns .T. if the start node will always be
*                   represented in the path table.
*               setSelectorTable(selTable [, selField] [, inverseSelection])
*                   Assignes a selector table that contains fromField
*                   (selField when using a different name) values 
*                   that are used (inverseSelection = .F.) or ignored
*                   (inverseSelection = .T.) as start nodes. 
*               getSelectorTable()
*                   Returns the SelectorTable.
*               getSelectorField()
*                   Returns the SelectorField.
*               isSelectionInverse()
*                   Returns wether the selection mode for the SelectorTable
*                   is including (.F.) or excluding (.T.).
*               isDistanceRequired()
*                   Returns .T., when the specific pathing class is
*                   requires the specification of a distance field in the
*                   create method, .F. otherwise.
*               isAccumulating()
*                   Returns .T., when the specific pathing class accumulates
*                   the distance in the result table using class specific
*                   functions (required for shareholder analysis).
*               isOptimizing()
*                   Returns .T., when the specific pathing class is
*                   minimizing/maximizing the distance. If a class
*                   is not intended to optimize the distance this function
*                   will return .F.
*               setMaximizing(max)
*                   Defines whether the algorithm is maximizing (max = .T.)
*                   or minimizing (max = .F.) the distance. This setting will
*                   be ignored if the class does not optimize the distance.
*               isMaximizing()
*                   Returns .T. if the algorithm is maximizing the distance,
*                   .F. otherwise.
*               isMinimizing()
*                   Returns .T. if the algorithm is minimizing the distance,
*                   .F. otherwise.
*               isCounting()
*                   Returns .T. if the class not only determines the
*                   optimum path and its distance but also counts all 
*                   paths with the same optimal distance. The table has
*                   an additional count field. Counting requires optimizing.
*               setCycleLimit(cycleLimit)
*                   The CycleLimit defines the number of times a connection
*                   can be used in cyclic paths before it is blocked. In most
*                   cases a connection should only be traversed once for every
*                   sub path that leads to this connection. For this reason the
*                   default value is 1. If the measurement of the distance is
*                   not continuous (i.e. negative weights, percentages, shares)
*                   or the class is accumulating the distances, a higher limit
*                   limit improves the accuracy at the cost of a much higher
*                   calculation time. A cycle limit of zero (or a negative
*                   limit) forces the algorithm to simply traverse every
*                   connection exactly one time. This is the default value
*                   for the FirstPathTable.
*               getCycleLimit()
*                   Returns the cycle limit.
*               setLowRange(range [, excluded])
*                   Defines the lower boundary for a distance between
*                   two nodes to be included. If this value is not numeric
*                   (i.e. boolean) there is no distance restriction.
*                   The boundary itself can be included (default) or 
*                   excluded (excluded = .T.).
*               setHighRange(range [, excluded])
*                   Like setLowRange(), but for the upper boundary.
*               getLowRange()
*                   Returns the low range boundary.
*               getHighRange()
*                   Returns the high range boundary.
*               isLowRangeExcluded()
*                   Returns .T., when the lower boundary itself is excluded,
*                   .F. if it is included.
*               isHighRangeExcluded()
*                   Returns .T., when the higher boundary itself is excluded.
*                   .F. if it is included.
*                isLowRangeUsed()
*                   Returns .T., when the low boundary is used.
*                   This method returns .F., when the range value is not
*                   numeric or the specific class does not use distances
*                   at all.
*               isHighRangeUsed()
*                   Returns .T., when the high boundary is used.
*                   This method returns .F., when the range value is not
*                   numeric or the specific class does not use distances
*                   at all.
*               setGrouping(groupMode)
*                   Active grouping (.T.) prevents the usage of
*                   start nodes that are already elements of resolved paths.
*                   Should only be used if the distance (from, to) always 
*                   equals the distance (to, from) or the distance is of 
*                   no concern.
*               getGrouping()
*                   Returns the grouping mode (.T. grouping active, 
*                   .F. no grouping). Default is no grouping.
*					Default for ClusterPathTable is with grouping.
*               setMaxDepth(maxDepth)
*                   Defines the maximum depth in nodes regardless of
*                   a potential distance, i.e. by using a maxDepth of 1
*                   the alorithm will only observe the neighbour nodes
*                   of the start node.
*               getMaxDepth()
*                   Returns the maximum depth in nodes. Default is
*                   a negative value of -1 resulting in an unrestricted
*                   pathing.
*               addFilter(expression [,activation])
*                   The expression has to be a string defining a logic
*                   expression using the fields of the network table.
*                   The filter is only activated when the number of
*                   traversed nodes is greater than the activation number.
*                   Only the first filter rule may be active from 
*                   the start by omitting the activation parameter or by an
*                   activation limit lesser equal zero. The filters will
*                   be activated in subsequent order every time  the
*                   activation limit for the next filter is exceeded.
*                   Only one filter is active at a time (they are not 
*                   logically connected). Every activation of a new filter
*                   results in a complete reiteration for the relevant
*                   starting node. The start node is always considered the
*                   first traversed node.
*               clearFilter()
*                   Removes all Filters. 
*               getFilter()
*                   Returns the filter collection. This is not a copy
*                   of the collection so any changes to it are for real.
*               setFilter(filter)
*                   Replaces the filter collection.
*
*               Public class specific methods:
*
*               ClusterPathTable.create(network_table, fromField, toField)
*                   Replaces the create method for the class ClusterPathTable.
*                   Implements the handling of undirected graphs and blackholes.
*               ClusterPathTable.setUndirected(undirected)
*                   By default all graphs are considered directed. This 
*                   option is only used in conjunction with ClusterPathTable.
*                   A undirected graph does not differentiate between "from"
*                   and "to". No mirroring of the connections is required.
*               ClusterPathTable.isUndirected()
*                   Return .T., if the graph is considered undirected.
*					Default is undirected.
*               ClusterPathTable.setBlackHole(limit)
*                   Defines the maximum number of connections for a node.
*                   A node with more connections is considered as a black hole,
*                   an artefact whose connections should be ignored.
*               ClusterPathTable.getBlackHole()
*                   Returns the black hole limit.
*               FirstPathTable.refine(table, fromField, toField, groupSize)
*                   Requires the same parametrization as the create method.
*                   All groups exceeding the groupSize are repathed using 
*                   new specifications you can set before the run, like
*                   new range specifications (see setLowRange(), setHighRange())
*                   or new filters (see addFilter()).
*                   This method can be subsequently called to refine too 
*                   large groups by splitting them into smaller ones.
*                   Grouping should be "true" (not required).
*=========================================================================*
define class Cascade as Custom
	hidden filter, valid, blackhole
	blackhole = 0
	
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
enddefine

define class CascadeTable as BaseTable
	hidden cascade
	
	function init(table)
		BaseTable::init(m.table)
		this.cascade = createobject("NestedCascade")
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
		
	function create(table, fromField as String, toField as String, grouping as String)
	local ps1, ps2, ps3, pa, lm, nested
	local cluster, cascade, trunc, prefix, clu, clucol, rest, group, next, sql, i
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","safety","off")
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
			m.cluster = createobject("ClusterPathTable",this.getDBF())
			m.cluster.setMessenger(this.messenger)
			if m.nested.count = 1
				m.cascade = m.nested.item(1)
				m.cluster.setFilter(m.cascade.getFilter())
				m.cluster.setBlackHole(m.cascade.getBlackhole())
			endif			
			m.cluster.includeStartNode(.t.)
			if not m.cluster.create(m.table, m.fromField, m.toField)
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
			m.cluster.setMessenger(this.messenger)
			m.cascade = m.nested.item(m.i)
			m.cluster.setFilter(m.cascade.getFilter())
			m.cluster.setBlackHole(m.cascade.getBlackhole())
			m.cluster.includeStartNode(.t.)
			m.clucol.add(m.cluster)
			if not m.cluster.create(m.table,m.fromField,m.toField)
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
				m.sql = 'select a.'+m.fromfield+', b.from as '+m.toField+m.group+' from '+m.clu.alias+' a, '+m.cluster.alias+' b where a.'+m.toField+' == b.to group by 1, 2 into table '+m.next.getDBF()
				&sql
				use
				m.next.open()
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
					select b.from, a.to from (m.cluster.alias) a, (m.clu.alias) b where a.from == b.to into table (this.getDBF())
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
	distance = 0
	depth = 0
	cycle = 1
	
	function init(from, to, distance, depth)
		this.from = m.from
		this.to = m.to
		this.distance = m.distance
		this.depth = m.depth
	endfunc
enddefine

define class NodeEnvelope as Custom
	node = .F.
	depth = 0
	
	function init(node, depth)
		this.node = m.node
		this.depth = m.depth
	endfunc
enddefine

define class PathTable as BaseTable
	protected actualDistance, baseDistance, neighbourDistance, resultDistance
	protected cutoffDistance, cutoffSpecified
	protected startNodeRequired
	protected selectorTable
	protected selectorField
	protected inverseSelection
	protected grouping
	protected maxdepth
	protected counting
	protected optimizing
	protected maximizing
	protected accumulating
	protected distanceRequired
	protected lowRange
	protected highRange
	protected lowRangeUsed
	protected highRangeUsed
	protected lowRangeExcluded	
	protected highRangeExcluded
	protected cycleLimit
	protected filter

	function create(table, fromField, toField, distField, cutoff)
	local ps1, ps2, ps3, ps4, ps5, ps6, pa, lm, pk
	local f1, f2, pos, origin, rec, from, to, init
	local nodeRequired, pathDepth, depth, pe, startpe
	local ck, ckfromto, cktarget, ckto, target
	local use, key, ind, dontusemaxdepth, maxdepth
	local result, useSelector, selectorField
	local branch, branchMonitor, filter, trueFilter
	local filterActivation, filterCountDown, filterIndex, nextFilter
	local fifo
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","near","off")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.ps6 = createobject("PreservedSetting","safety","off")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger,"")
		this.messenger.forceMessage("Pathing...")
		m.branch = createobject("Collection")
		m.branchMonitor = createobject("Collection")
		m.result = createobject("Collection")
		if not this.isCreatable()
			this.messenger.errorMessage("PathTable is not creatable.")
			return .F.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Table is not valid.")
			return .F.
		endif
		if not m.table.hasField(m.fromField) or not m.table.hasField(m.toField)
			this.messenger.errorMessage("Fields are not valid.")
			return .F.
		endif
		m.useSelector = .F.
		if vartype(this.selectorTable) == "O"
			if not this.selectorTable.isValid()
				this.messenger.errorMessage("Invalid selector table.")
				return .F.
			endif
			if vartype(this.selectorField) == "C"
				m.selectorField = this.selectorField
			else
				m.selectorField = m.fromField
			endif
			m.f1 = this.selectorTable.getFieldStructure(m.selectorField)
			m.f2 = m.table.getFieldStructure(m.fromField)
			if not m.f1.isValid()
				this.messenger.errorMessage("Field "+m.selectorField+" must be defined in the selector table.")
				return .F.
			endif
			if not m.f1.getType() == m.f2.getType()
				this.messenger.errorMessage("Field "+m.selectorField+" in selector table has incompatible type.")
				return .F.
			endif
			if this.inverseSelection and not this.selectorTable.forceKey(m.selectorField)
				this.messenger.errorMessage("Unbable to create index on "+m.selectorField+" in selector table.")
				return .F.
			endif
			m.useSelector = .T.
		endif
		if this.distanceRequired
			if not vartype(m.distField) == "C"
				this.messenger.errorMessage("Distance field required.")
				return .F.
			endif
			m.f1 = m.table.getFieldStructure(m.distField)
			if not m.f1.isValid() or not inlist(m.f1.getType(),"N","I","B","Y")
				this.messenger.errorMessage("Distance field is not valid.")
				return .F.
			endif
		else
			m.cutoff = m.distField
			if not vartype(m.cutoff) == "L"
				this.messenger.errorMessage("Invalid cutoff specification")
				return .F.
			endif
		endif
		m.f1 = m.table.getFieldStructure(m.fromField)
		m.f2 = m.table.getFieldStructure(m.toField)
		if not (like(m.f1.getDefinition()+"*", m.f2.getDefinition()) or like(m.f2.getDefinition()+"*", m.f1.getDefinition()))
			this.messenger.errorMessage("FROM and TO are incompatible.")
			return .F.
		endif
		select (m.table.alias)
		for m.ind = 1 to this.filter.count
			m.filter = this.filter.item(m.ind)
			if not m.filter.isValid()
				this.messenger.errorMessage('Filter "'+m.filter.expression+'" is not valid.')
				return .F.
			endif
		endfor
		for m.ind = 2 to this.filter.count
			m.filter = this.filter.item(m.ind)
			if m.filter.activation <= 0
				this.messenger.errorMessage('Only the first filter may have an activation limit lesser equal zero.')
				return .F.
			endif
		endfor
		m.trueFilter = createobject("TrueFilterEnvelope")
		this.setRequiredTableStructure(rtrim(rtrim("from "+m.f1.getDefinition()+", to "+m.f2.getDefinition()+", distance "+this.getDistanceDefinition(m.table,m.distField)+", "+this.getAdditionalFields()),","))
		if not BaseTable::create()
			this.messenger.errorMessage("Unable to create PathTable.")
			return .F.
		endif
		if not m.table.forceKey(m.fromField)
			this.messenger.errorMessage('Unable to create index on from field.')
			this.erase()
			return .F.
		endif
		this.deleteKey()
		if this.grouping
			this.forceKey("to")
		endif		   
		m.ck = createobject("ComposedKey","from "+m.f1.getDefinition()+", to "+m.f2.getDefinition())
		m.ckfromto = m.ck.getExp("m.from, m.to")
		m.ck = createobject("ComposedKey","to "+m.f2.getDefinition())
		m.cktarget = m.ck.getExp("m.target")
		m.ckto = m.ck.getExp("m.to")
		m.pk = createobject("PreservedKey", m.table)
		this.actualDistance = 0
		this.baseDistance = 0
		this.neighbourDistance = 0
		this.resultDistance = 0
		this.cutoffDistance = 0
		if not vartype(m.cutoff) == "N"
			this.cutoffSpecified = .F.
		else
			this.cutoffSpecified = .T.
			this.cutoffDistance = m.cutoff
		endif
		if vartype(this.maxdepth) == "N" and this.maxdepth >= 0
			m.dontusemaxdepth = .F.
			m.maxdepth = this.maxdepth+1
		else
			m.dontusemaxdepth = .T.
		endif
		m.fifo = this.optimizing == .t. and this.maximizing == .f.
		if m.useSelector and not this.inverseSelection
			select (this.selectorTable.alias)
			go top
		else
			select (m.table.alias)
			go top
		endif
		m.rec = 0
		this.messenger.setDefault("Pathed")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation?","Pathing","Canceled.")
		do while not eof()
			if this.messenger.queryCancel()
				exit
			endif
	   		m.pos = recno()
			if m.useSelector
				if this.inverseSelection
					m.from = evaluate(m.fromField)
					select (this.selectorTable.alias)
					m.use = not seek(m.from)
					select (m.table.alias)
				else
					m.from = evaluate(m.selectorField)
					select (m.table.alias)
					m.use = seek(m.from)
				endif
			else
				m.use = .t.
			endif
			m.origin = evaluate(m.fromField)
			if this.grouping
				m.use = m.use and not seek(m.origin, this.alias)
			endif
			if m.use
				this.initBaseDistance()
				m.startpe = createobject("PathEnvelope")
				m.startpe.from = m.origin
				m.startpe.to = m.startpe.from
				m.startpe.distance = this.baseDistance
				m.startpe.depth = 1
				if this.filter.count > 0
					m.filter = this.filter.item(1)
					m.filterCountDown = m.filter.activation
					if m.filterCountDown > 0
						m.filterIndex = 0
						m.filter = m.trueFilter
					else
						m.filterIndex = 1
						if this.filter.count > 1
							m.nextFilter = this.filter.item(2)
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
						m.depth = 1
						m.pathDepth = 0
						m.branch.remove(-1)
						m.result.remove(-1)
						m.branchMonitor.remove(-1)
						m.branch.add(createobject("PathEnvelope",m.startpe.from,m.startpe.to,m.startpe.distance,m.startpe.depth))
						m.filterActivation = m.filterIndex < this.filter.count
						m.nodeRequired = this.startNodeRequired > 0
						m.init = .f.
					endif
					if m.filterActivation and m.filterCountDown <= 0
						m.filterIndex = m.filterIndex+1
						m.filter = this.filter.item(m.filterIndex)
						if not m.filterIndex == this.filter.count
							m.nextFilter = this.filter.item(m.filterIndex+1)
							m.filterCountDown = m.nextFilter.activation
						endif
						m.init = .t.
						loop
					endif
					if this.messenger.queryCancel()
						exit
					endif
					if m.branch.count <= 0
						exit
					endif
					if m.fifo
						m.pe = m.branch.item(1)
						m.branch.remove(1)
					else
						m.pe = m.branch.item(m.branch.count)
						m.branch.remove(m.branch.count)
					endif
					m.to = m.pe.to
					m.from = m.pe.from
					this.baseDistance = m.pe.distance
					this.actualDistance = this.baseDistance
					m.depth = m.pe.depth
					if this.cycleLimit >= 1 and m.pathDepth >= m.depth
						for m.ind = 1 to m.branchMonitor.count
							m.pe = m.branchMonitor.item(m.ind)
							if m.pe.depth >= m.depth
								if m.pe.cycle > 2
									m.pe.cycle = m.pe.cycle-1
								else
									m.pe.cycle = 1
									m.pe.depth = 0
								endif
							endif
						endfor
					endif
					m.pathDepth = m.depth
					m.key = evaluate(m.ckfromto)
					m.ind = m.branchMonitor.getKey(m.key)
					if m.ind > 0
						m.pe = m.branchMonitor.item(m.ind)
						m.pe.depth = m.depth
					else
						m.branchMonitor.add(createobject("PathEnvelope", m.from, m.to, this.basedistance, m.depth),m.key)
					endif
					m.depth = m.depth+1
					if m.dontusemaxdepth
						m.maxdepth = m.depth
					endif
					m.from = m.to
					m.target = m.from
					seek(m.from)
					do while not eof() and evaluate(m.fromField) == m.from
						m.to = evaluate(m.toField)
						if m.from == m.to
							skip
							loop
						endif
						m.key = evaluate(m.ckfromto)
						m.ind = m.branchMonitor.getKey(m.key)
						if m.ind > 0
							m.pe = m.branchMonitor.item(m.ind)
							if m.pe.depth > 0
								if m.pe.cycle >= this.cycleLimit
									skip
									loop
								else
									m.pe.cycle = m.pe.cycle+1
								endif
							endif
						endif
						if this.distanceRequired
							this.neighbourDistance = evaluate(m.distField)
							if this.isDistanceInRange() == .F.
								skip
								loop
							endif
						endif
						if m.filter.eval() == .F.
							skip
							loop
						endif
						this.recalculateDistances()
						if this.isBranchingAllowed(m.from, m.to) and m.depth <= m.maxdepth
							if this.optimizing == .F.
								if this.accumulating 
									m.branch.add(createobject("PathEnvelope", m.from, m.to, this.neighbourDistance, m.depth))
									if m.filterActivation
										m.key = evaluate(m.ckto)
										if m.result.getKey(m.key) <= 0
											m.filterCountDown = m.filterCountDown-1
										endif
									endif
								else
									m.key = evaluate(m.ckto)
									if m.result.getKey(m.key) <= 0
										m.branch.add(createobject("PathEnvelope", m.from, m.to, this.neighbourDistance, m.depth))
										m.result.add(createobject("PathEnvelope", m.origin, m.to, this.neighbourDistance),m.key)
										if m.filterActivation
											m.filterCountDown = m.filterCountDown-1
										endif
									endif
								endif
							else
								if m.ind > 0 
									if this.maximizing == .T. and this.neighbourDistance > m.pe.distance or;
									   this.maximizing == .F. and this.neighbourDistance < m.pe.distance or;
									   this.counting and this.equalDistance(this.neighbourDistance, m.pe.distance)
										m.branch.add(createobject("PathEnvelope", m.from, m.to, this.neighbourDistance, m.depth))
										m.pe.distance = this.neighbourDistance
									endif
								else
									m.branch.add(createobject("PathEnvelope", m.from, m.to, this.neighbourDistance, m.depth))
									m.branchMonitor.add(createobject("PathEnvelope", m.from, m.to, this.neighbourDistance, 0),m.key)
									if m.filterActivation
										m.key = evaluate(m.ckto)
										if m.result.getKey(m.key) <= 0
											m.filterCountDown = m.filterCountDown-1
										endif
									endif
								endif
							endif
						endif
						skip
					enddo
					if m.nodeRequired
						m.key = evaluate(m.cktarget)
						m.ind = m.result.getKey(m.key)
						if m.ind > 0
							m.pe = m.result.item(m.ind)
							this.resultDistance = m.pe.distance
							if this.resultDistanceUpdateRequired()
								this.updateResultDistance()
								m.pe.distance = this.resultDistance
								m.pe.cycle = 1
							else
								if this.counting and this.equalDistance(this.resultDistance, this.actualDistance)
									m.pe.cycle = m.pe.cycle + 1
								endif
							endif
						else
							m.result.add(createobject("PathEnvelope", m.origin, m.target, this.actualDistance),m.key)
						endif
					else
						m.nodeRequired = .T.
					endif
				enddo
				if this.messenger.isCanceled()
					exit
				endif
				if this.counting
					for m.ind = 1 to m.result.count
						m.pe = m.result.item(m.ind)
						insert into (this.alias) values (m.pe.from, m.pe.to, m.pe.distance, m.pe.cycle)
					endfor
				else
					for m.ind = 1 to m.result.count
						m.pe = m.result.item(m.ind)
						insert into (this.alias) values (m.pe.from, m.pe.to, m.pe.distance)
					endfor
				endif
			endif
			if m.useSelector and not this.inverseSelection
				select (this.selectorTable.alias)
				skip
				m.rec = m.rec+1
			else
				select (m.table.alias)
				go record m.pos
				do while not eof() and evaluate(m.fromField) == m.origin
					skip
					m.rec = m.rec+1
				enddo
			endif
			this.messener.setProgress(m.rec)
			this.messenger.postProgress()
		enddo
		this.messenger.sneakMessage("Closing...")
		release m.branch
		release m.branchMonitor
		release m.result
		this.forceRequiredKeys()
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
	endfunc	

	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure(rtrim(rtrim("from n(1), to n(1), distance n(1), "+this.getAdditionalFields()),","))
		this.setRequiredKeys("from; to")
		this.selectorTable = .F.
		this.maxDepth = -1
		this.optimizing = .T.
		this.accumulating = .F.
		this.startNodeRequired = 0
		this.cycleLimit = 1
		this.filter = createobject("Collection")
		this.grouping = .f.
	endfunc
	
	protected function reinit(table)
		BaseTable::init(m.table)
	endfunc
	
	function includeStartNode(include)
		if this.startNodeRequired == 1
			return
		endif
		this.startNodeRequired = iif(m.include == .t., 2, 0)
	endfunc
	
	function isStartNodeIncluded()
		return this.startNodeRequired > 0
	endfunc
	
	function setSelectorTable(selTable, selField, inverseSelection)
	local type
		m.type = vartype(m.selTable)
		if m.type == "C"
			this.selectorTable = createobject("BaseTable",m.selTable)
		else
			if m.type == "O"
				this.selectorTable = m.selTable
			else
				this.selectorTable = .f.
			endif
		endif
		m.type = vartype(m.selField)
		if m.type == "C"
			this.selectorField = alltrim(m.selField)
		else
			if m.type == "O"
				this.selectorField = m.selField.getName()
			else
				this.selectorField = .f.
				this.inverseSelection = m.inverseSelection
				return
			endif
		endif
		this.inverseSelection = m.inverseSelection
	endfunc

	function getSelectorTable()
		return this.selectorTable
	endfunc
	
	function getSelectorField()
		return this.selectorField
	endfunc

	function isSelectionInverse()
		return this.inverseSelection
	endfunc
	
	function isDistanceRequired()
		return this.distanceRequired
	endfunc

	function isAccumulating()
		return this.accumulating
	endfunc

	function isOptimizing()
		return this.optimizing
	endfunc

	function setMaximizing(max)
		if this.optimizing
			this.maximizing = m.max
		endif
	endfunc
	
	function isMaximizing()
		return this.optimizing and this.maximizing
	endfunc

	function isMinimizing()
		return this.optimizing and not this.maximizing
	endfunc
	
	function isCounting()
		return this.counting
	endfunc
	
	function setCycleLimit(cycleLimit)
		this.cycleLimit = m.cycleLimit
	endfunc

	function getCycleLimit()
		return this.cycleLimit
	endfunc
	
	function setLowRange(range, excluded)
		this.lowRange = m.range
		this.lowRangeExcluded = m.excluded
		this.lowRangeUsed = vartype(m.range) == "N" and this.distanceRequired
	endfunc
	
	function setHighRange(range, excluded)
		this.highRange = m.range
		this.highRangeExcluded = m.excluded
		this.highRangeUsed = vartype(m.range) == "N" and this.distanceRequired
	endfunc
	
	function getLowRange()
		return this.lowRange
	endfunc

	function getHighRange()
		return this.highRange
	endfunc

	function isHighRangeExcluded()
		return this.highRangeExcluded
	endfunc

	function isLowRangeExcluded()
		return this.lowRangeExcluded
	endfunc

	function isLowRangeUsed()
		return this.lowRangeUsed
	endfunc

	function isHighRangeUsed()
		return this.highRangeUsed
	endfunc

	function setGrouping(groupMode)
		if vartype(m.groupMode) == "L"
			this.grouping = m.groupMode
		endif
	endfunc
	
	function getGrouping()
		return this.grouping
	endfunc
	
	function setMaxDepth(maxdepth)
		this.maxDepth = m.maxDepth
	endfunc
	
	function getMaxDepth()
		return this.maxDepth
	endfunc
	
	function addFilter(expression, activation)
		this.filter.add(createobject("FilterEnvelope", m.expression, m.activation))
	endfunc
	
	function getFilter()
		return this.filter
	endfunc
	
	function setFilter(filter)
		this.filter = m.filter
	endfunc

 	function clearFilter()
		this.filter  = createobject("Collection")
	endfunc
	
	protected function initBaseDistance()
		this.baseDistance = 0
	endfunc

	protected function recalculateDistances()
		this.neighbourDistance = this.actualDistance+1
	endfunc
	
	protected function isBranchingAllowed(from, to)
		return not this.cutoffSpecified or this.neighbourDistance <= this.cutoffDistance
	endfunc

	protected function resultDistanceUpdateRequired()
		if this.maximizing
			return this.actualDistance > this.resultDistance
		endif
		return this.actualDistance < this.resultDistance
	endfunc

	protected function updateResultDistance()
		this.resultDistance = this.actualDistance
	endfunc

	protected function equalDistance(distance1, distance2)
		return m.distance1 == m.distance2
	endfunc
	
	protected function getDistanceDefinition(table, field)
		return "i"
	endfunc

	protected function getAdditionalFields()
		return ""
	endfunc 

	hidden function isFilterValid()
	local i, filter
		for m.i = 1 to this.filter.count
			m.filter = this.filter.item(m.i)
			if not m.filter.isValid()
				return .f.
			endif
		endfor
		return .t.
	endfun

	hidden function isDistanceInRange()
		if this.lowRangeUsed
			if this.lowRangeExcluded
				if this.neighbourDistance <= this.lowRange
					return .F.
				endif
			else
				if this.neighbourDistance < this.lowRange
					return .F.
				endif
			endif
		endif
		if this.highRangeUsed
			if this.highRangeExcluded
				if this.neighbourDistance >= this.highRange
					return .F.
				endif
			else
				if this.neighbourDistance > this.highRange
					return .F.
				endif
			endif
		endif
		return .T.
	endfunc
enddefine

define class ClusterPathTable as PathTable
	protected undirected
	protected blackhole
	
	protected function init(table)
		PathTable::init(m.table)
		this.optimizing = .F.
		this.cycleLimit = 0
		this.undirected = .T.
		this.blackhole = 0
		this.grouping = .T.
	endfunc

	protected function resultDistanceUpdateRequired()
		return .F.
	endfunc
	
	function create(table, fromField, toField)
	local ps1, ps2, ps3, ps4, ps5, ps6, pa, lm, pk
	local f1, f2, origin, init, sel, hole, tmp1, tmp2, tmp3
	local depth, node, sql
	local cktarget, target, useSelector, selectorField, ind
	local key, usemaxdepth, result, branch, filter, trueFilter
	local filterActivation, filterCountDown, filterIndex, nextFilter
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","near","off")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.ps6 = createobject("PreservedSetting","safety","off")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Pathing...")
		m.branch = createobject("Collection")
		m.result = createobject("Collection")
		if not this.isCreatable()
			this.messenger.errorMessage("ClusterPathTable is not creatable.")
			return .F.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Table is not valid.")
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
		m.useSelector = .F.
		if vartype(this.selectorTable) == "O"
			if not this.selectorTable.isValid()
				this.messenger.errorMessage("Invalid selector table.")
				return .F.
			endif
			if vartype(this.selectorField) == "C"
				m.selectorField = this.selectorField
			else
				m.selectorField = m.fromField
			endif
			m.f1 = this.selectorTable.getFieldStructure(m.selectorField)
			m.f2 = m.table.getFieldStructure(m.fromField)
			if not m.f1.isValid()
				this.messenger.errorMessage("Field "+m.selectorField+" must be defined in the selector table.")
				return .F.
			endif
			if not m.f1.getType() == m.f2.getType()
				this.messenger.errorMessage("Field "+m.selectorField+" in selector table has incompatible type.")
				return .F.
			endif
			m.useSelector = .T.
		endif
		select (m.table.alias)
		for m.ind = 1 to this.filter.count
			m.filter = this.filter.item(m.ind)
			if not m.filter.isValid()
				this.messenger.errorMessage('Filter "'+m.filter.expression+'" is not valid.')
				return .F.
			endif
		endfor
		for m.ind = 2 to this.filter.count
			m.filter = this.filter.item(m.ind)
			if m.filter.activation <= 0
				this.messenger.errorMessage('Only the first filter may have an activation limit lesser equal zero.')
				return .F.
			endif
		endfor
		m.trueFilter = createobject("TrueFilterEnvelope")
		this.setRequiredTableStructure("from "+m.f1.getDefinition()+", to "+m.f2.getDefinition()+", distance i")
		if not BaseTable::create()
			this.messenger.errorMessage("Unable to create PathTable.")
			return .F.
		endif
		if this.grouping
			this.forceKey("to")
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
		this.forceKey("to")
		m.sel = createobject("UniqueAlias",.t.)
		m.hole = createobject("UniqueAlias",.t.)
		m.tmp1 = createobject("UniqueAlias",.t.)
		m.tmp2 = createobject("UniqueAlias",.t.)
		m.tmp3 = createobject("UniqueAlias",.t.)
		this.messenger.forceMessage("Pathing (Origin)...")
		m.sql = "select distinct a."+m.fromField+" as origin from "+m.table.alias+" a into cursor "+m.sel.alias+" readwrite"
		&sql
		if this.undirected
			m.sql = "select distinct a."+m.toField+" as origin from "+m.table.alias+" a into cursor "+m.tmp1.alias+" readwrite"
			&sql
			select a.origin from (m.tmp1.alias) a where not exists (select b.origin from (m.sel.alias) b where a.origin == b.origin) into cursor (m.tmp2.alias) readwrite
			select (m.sel.alias)
			append from dbf(m.tmp2.alias)
		endif
		if m.useSelector 
			this.messenger.forceMessage("Pathing (Selector)...")
			if this.inverseSelection
				m.sql = "select a.origin from "+m.sel.alias+" a where not exists (select * from "+this.selectorTable.alias+" b where a.origin == b."+m.selectorField+") into cursor "+m.tmp1.alias+" readwrite"
			else
				m.sql = "select a.origin from "+m.sel.alias+" a where exists (select * from "+this.selectorTable.alias+" b where a.origin == b."+m.selectorField+") into cursor "+m.tmp1.alias+" readwrite"
			endif
			&sql
			select * from (m.tmp1.alias) into cursor (m.sel.alias)
		endif
		if this.blackhole > 0
			this.messenger.forceMessage("Pathing (Blackhole)...")
			select a.origin, cast(0 as i) as cnt, cast(0 as n(1)) as hole from (m.sel.alias) a into cursor (m.hole.alias) readwrite
			index on origin tag origin
			m.sql = "select a."+m.fromfield+" as origin, count(*) as cnt from "+m.table.alias+" a, "+m.hole.alias+" b where a."+m.fromfield+" == b.origin and not a."+m.fromfield+" == a."+m.tofield+" group by 1 into cursor "+m.tmp1.alias+" readwrite"
			&sql
			m.sql = "update "+m.hole.alias+" set "+m.hole.alias+".cnt = "+m.tmp1.alias+".cnt, hole = iif("+m.tmp1.alias+".cnt > "+ltrim(str(this.blackhole,10))+",1,0) from "+m.tmp1.alias+" where "+m.tmp1.alias+".origin == "+m.hole.alias+".origin"
			&sql
			m.sql = "select a."+m.tofield+" as origin, count(*) as cnt from "+m.table.alias+" a, "+m.hole.alias+" b where a."+m.tofield+" == b.origin and b.hole == 0 and not a."+m.fromfield+" == a."+m.tofield+" group by 1 into cursor "+m.tmp1.alias+" readwrite"
			&sql
			m.sql = "update "+m.hole.alias+" set cnt = "+m.hole.alias+".cnt+"+m.tmp1.alias+".cnt, hole = iif("+m.tmp1.alias+".cnt > "+ltrim(str(this.blackhole,10))+",1,0) from "+m.tmp1.alias+" where "+m.tmp1.alias+".origin == "+m.hole.alias+".origin"
			&sql
			m.sql = "select a."+m.fromfield+" as from, a."+m.tofield+" as to from "+m.table.alias+" a, "+m.hole.alias+" b where a."+m.fromfield+" == b.origin and b.hole == 0 and b.cnt > "+ltrim(str(this.blackhole,10))+" and not a."+m.fromfield+" == a."+m.tofield+" into cursor "+m.tmp1.alias+" readwrite"
			&sql
			m.sql = "select a."+m.tofield+" as from, a."+m.fromfield+" as to from "+m.table.alias+" a, "+m.hole.alias+" b where a."+m.tofield+" == b.origin and b.hole == 0 and b.cnt > "+ltrim(str(this.blackhole,10))+" and not a."+m.fromfield+" == a."+m.tofield+" into cursor "+m.tmp2.alias+" readwrite"
			&sql
			m.sql = "select a.* from "+m.tmp2.alias+" a where not exists (select * from "+m.tmp1.alias+" b where a.from == b.from and a.to == b.to) into cursor "+m.tmp3.alias+" readwrite"
			&sql
			select (m.tmp1.alias)
			append from dbf(m.tmp3.alias)
			m.sql = "select a.from as origin from "+m.tmp1.alias+" a group by 1 having count(*) > "+ltrim(str(this.blackhole,10))+" into cursor (m.tmp1.alias)"
			&sql
			m.sql = "update "+m.hole.alias+" set hole = 1 from "+m.tmp1.alias+" where "+m.tmp1.alias+".origin == "+m.hole.alias+".origin"
			&sql
			select a.origin from (m.hole.alias) a where a.hole == 1 into cursor (m.hole.alias) readwrite
			index on origin tag origin
		else
			m.hole.close()
		endif
		m.tmp1.close()
		m.tmp2.close()
		m.tmp3.close()
		m.cktarget = createobject("ComposedKey","to "+m.f2.getDefinition())
		m.cktarget = m.cktarget.getExp("m.target")
		m.pk = createobject("PreservedKey", m.table)
		m.usemaxdepth = (vartype(this.maxdepth) == "N" and this.maxdepth > 0)
		select (m.sel.alias)
		go top
		this.messenger.setDefault("Pathed")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation?","Pathing","Canceled.")
		do while not eof()
			if this.messenger.queryCancel()
				exit
			endif
			m.origin = origin
			if this.grouping and seek(m.origin, this.alias)
				skip
				loop
			endif
			select (m.table.alias)
			if this.filter.count > 0
				m.filter = this.filter.item(1)
				m.filterCountDown = m.filter.activation
				if m.filterCountDown > 0
					m.filterIndex = 0
					m.filter = m.trueFilter
				else
					m.filterIndex = 1
					if this.filter.count > 1
						m.nextFilter = this.filter.item(2)
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
					m.depth = 1
					m.branch.remove(-1)
					m.result.remove(-1)
					m.branch.add(createobject("NodeEnvelope",m.origin,0))
					if this.startNodeRequired > 0
						m.target = m.origin	
						m.key = evaluate(m.cktarget)
						m.result.add(createobject("NodeEnvelope",m.origin,0),m.key)
					endif
					if this.blackhole > 0 and seek(m.origin,m.hole.alias)
						exit
					endif
					m.filterActivation = m.filterIndex < this.filter.count
					m.init = .f.
				endif
				if m.filterActivation and m.result.count >= m.filterCountDown
					m.filterIndex = m.filterIndex+1
					m.filter = this.filter.item(m.filterIndex)
					if not m.filterIndex == this.filter.count
						m.nextFilter = this.filter.item(m.filterIndex+1)
						m.filterCountDown = m.nextFilter.activation
					endif
					m.init = .t.
					loop
				endif
				if this.messenger.queryCancel()
					exit
				endif
				if m.branch.count <= 0
					exit
				endif
				m.node = m.branch.item(m.branch.count)
				m.branch.remove(m.branch.count)
				m.depth = m.node.depth+1
				if m.usemaxdepth and m.depth > this.maxdepth
					loop
				endif
				seek(m.node.node)
				do while not eof() and evaluate(m.fromField) == m.node.node 
					m.target = evaluate(m.toField)
					if not m.node.node == m.target
						m.key = evaluate(m.cktarget)
						if m.result.getKey(m.key) <= 0
							if m.filter.eval()
								if not (this.blackhole > 0 and seek(m.target,m.hole.alias))
									m.branch.add(createobject("NodeEnvelope", m.target, m.depth))
									m.result.add(createobject("NodeEnvelope", m.target, m.depth),m.key)
								endif
							endif
						endif
					endif
					skip
				enddo
				if this.undirected
					m.table.setKey(m.tofield)
					seek(m.node.node)
					do while not eof() and evaluate(m.toField) == m.node.node
						m.target = evaluate(m.fromField)
						if not m.node.node == m.target
							m.key = evaluate(m.cktarget)
							if m.result.getKey(m.key) <= 0
								if m.filter.eval()
									if not (this.blackhole > 0 and seek(m.target,m.hole.alias))
										m.branch.add(createobject("NodeEnvelope", m.target, m.depth))
										m.result.add(createobject("NodeEnvelope", m.target, m.depth),m.key)
									endif
								endif
							endif
						endif
						skip
					enddo
					m.table.setKey(m.fromfield)
				endif
			enddo
			if this.messenger.isCanceled()
				exit
			endif
			for m.ind = 1 to m.result.count
				m.node = m.result.item(m.ind)
				insert into (this.alias) values (m.origin, m.node.node, m.node.depth)
			endfor
			select (m.sel.alias)
			skip
			this.messenger.setProgress(recno())
			this.messenger.postProgress()
		enddo
		this.messenger.sneakMessage("Closing...")
		release m.branch
		release m.result
		this.forceRequiredKeys()
		if this.messenger.isCanceled()
			return .f.
		endif
		return .t.
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

define class FirstPathTable as PathTable
	protected function init(table)
		PathTable::init(m.table)
		this.optimizing = .F.
		this.cycleLimit = 0
	endfunc
	
	protected function resultDistanceUpdateRequired()
		return .F.
	endfunc

	function refine(table as Object, fromField as String, toField as String, groupLimit as Integer)
	local ps1, ps2, ps3, ps4, pa, lm, f1, f2
	local shared, del, sel, sql, path, refine
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","optimize","on")
		m.ps4 = createobject("PreservedSetting","safety","off")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger,"")
		this.messenger.forceMessage("Refining...")
		if not this.isValid()
			this.messenger.errorMessage("This table is not valid.")
			return .F.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Table is not valid.")
			return .F.
		endif
		if not m.table.hasField(m.fromField) or not m.table.hasField(m.toField)
			this.messenger.errorMessage("Path fields are not valid.")
			return .F.
		endif
		if not vartype(m.groupLimit) == "N" or m.groupLimit < 1
			this.messenger.errorMessage("Group limit is not valid.")
			return .F.
		endif
		m.shared = this.isShared()
		if not this.useExclusive()
			this.messenger.errorMessage("Unable to get exclusive access to GroupTable.")
			return .F.
		endif
		m.f1 = m.table.getFieldStructure(m.fromField)
		m.f2 = this.getFieldStructure("to")
		if not m.f1.getType() == m.f2.getType()
			this.messenger.errorMessage("Field "+m.fromField+" in path table has incompatible type.")
			return .F.
		endif
		m.del = createobject("UniqueAlias",.t.)
		m.sel = createobject("UniqueAlias",.t.)
		m.path = this.getPath()
		select a.from from (this.alias) a group by 1 having count(*) > m.groupLimit into cursor (m.del.alias) readwrite
		if reccount(m.del.alias) <= 0
			return .T.
		endif
		index on from tag from
		select a.to as from from (this.alias) a, (m.del.alias) b where a.from == b.from into cursor (m.sel.alias) readwrite 
		index on from tag from
		m.sql = "delete from ?1 where exists (select * from ?2 where ?1.from == ?2.from)"
		m.sql = strtran(strtran(m.sql,"?1",this.alias),"?2",m.del.alias)
		&sql
		this.pack()
		if m.shared
			this.useShared()
		endif
		m.refine = createobject("BaseCursor","Dummy N(1)",m.path)
		m.refine.erase()
		m.refine.close()
		m.refine = createobject(this.class,m.refine.getDBF())
		m.refine.setCursor(.t.)
		m.refine.setGrouping(this.getGrouping())
		m.refine.setLowRange(this.getLowRange())
		m.refine.setHighRange(this.getHighRange())
		m.refine.setFilter(this.getFilter())
		m.refine.setMaxDepth(this.getMaxDepth())
		m.refine.setCycleLimit(this.getCycleLimit())
		m.refine.setSelectorTable(m.sel.alias, "from")
		m.refine.create(m.table,m.fromField,m.toField)
		select (this.alias)
		append from dbf(m.refine.alias)
		return .t.
	endfunc
enddefine

define class CountPathTable as PathTable
	protected function init(table)
		PathTable::init(m.table)
		this.counting = .t.
	endfunc
	
	function getAdditionalFields()
		return "count i"
	endfunc
enddefine

define class DistancePathTable as PathTable
	protected function init(table)
		PathTable::init(m.table)
		this.distanceRequired = .T.
	endfunc

	protected function recalculateDistances()
		this.neighbourDistance = this.actualDistance+this.neighbourDistance
	endfunc

	protected function getDistanceDefinition(table, field)
		return "b"
	endfunc
enddefine

define class PercentPathTable as DistancePathTable
	protected function init(table)
		DistancePathTable::init(m.table)
		this.startNodeRequired = 1
	endfunc

	protected function initBaseDistance()
		this.baseDistance = 100
	endfunc

	protected function recalculateDistances()
		this.neighbourDistance = this.actualDistance*this.neighbourDistance/100
	endfunc

	protected function isBranchingAllowed(from, to)
		return not this.cutoffSpecified or this.neighbourDistance >= this.cutoffDistance
	endfunc
enddefine

define class SharePathTable as PathTable
	protected function init(table)
		PathTable::init(m.table)
		this.optimizing = .F.
		this.accumulating = .T.
		this.startNodeRequired = 1
		this.distanceRequired = .T.
	endfunc

	protected function getDistanceDefinition(table, field)
		return "b"
	endfunc

	protected function initBaseDistance()
		this.baseDistance = 100
	endfunc

	protected function recalculateDistances()
		this.neighbourDistance = this.baseDistance*this.neighbourDistance/100
		this.actualDistance = this.actualDistance-this.neighbourDistance
	endfunc

	protected function isBranchingAllowed(from, to)
		return not this.cutoffSpecified or this.neighbourDistance >= this.cutoffDistance
	endfunc

	protected function resultDistanceUpdateRequired()
		return .T.
	endfunc

	protected function updateResultDistance()
		this.resultDistance = min(this.resultDistance+this.actualDistance,100)
	endfunc
enddefine

define class InterPathTable as SharePathTable
	protected function recalculateDistances()
		this.neighbourDistance = this.baseDistance*this.neighbourDistance/100
	endfunc
enddefine

define class UeberSetTable as BaseTable
	protected function init(table)
		BaseTable::init(m.table)
		this.setRequiredTableStructure("set n(1)")
		this.setRequiredKeys("set")
	endfunc
	
	function create(table, fromField, toField)
	local ps1, ps2, ps3, ps4, ps5, ps6, pa, lm, pk, err
	local f1, f2, from, use, sql1, sql2, set, ueberSet
	local tableAlias, useAlias, setAlias, dbf, rec
	local subfrom
		m.ps1 = createobject("PreservedSetting","escape","off")
		m.ps2 = createobject("PreservedSetting","talk","off")
		m.ps3 = createobject("PreservedSetting","exact","on")
		m.ps4 = createobject("PreservedSetting","near","off")
		m.ps5 = createobject("PreservedSetting","optimize","on")
		m.ps6 = createobject("PreservedSetting","safety","off")
		m.pa = createobject("PreservedAlias")
		m.lm = createobject("LastMessage",this.messenger)
		this.messenger.forceMessage("Collecting...")
		if not this.isCreatable()
			this.messenger.errorMessage("UeberSetTable is not creatable.")
			return .F.
		endif
		if vartype(m.table) == "C"
			m.table = createobject("BaseTable",m.table)
		endif
		if not m.table.isValid()
			this.messenger.errorMessage("Table is not valid.")
			return .F.
		endif
		if not m.table.hasField(m.fromField) or not m.table.hasField(m.toField)
			this.messenger.errorMessage("Fields are not valid.")
			return .F.
		endif
		m.fromField = alltrim(m.fromField)
		m.toField = alltrim(m.toField)
		m.tableAlias = m.table.getAlias()
		m.use = createobject("BaseCursor")
		m.sql1 = "select a."+m.fromField+" as from, count(*) as set, 1 as use from "
		m.sql1 = m.sql1+m.tableAlias+" a group by a."+m.fromField+" order by a."+m.fromField+" into table "+m.use.getDBF()
		m.err = .f.
		try
			&sql1
		catch
			m.err = .t.
		endtry
		if m.err
			this.messenger.errorMessage("Unable to create temporary Table.")
			return .F.
		endif
		m.use.synchronizeDBF()
		m.useAlias = m.use.getAlias()
		m.f1 = m.table.getFieldStructure(m.fromField)
		m.f2 = m.table.getFieldStructure(m.toField)
		if not m.f1.getDefinition() == m.f2.getDefinition()
			this.messenger.errorMessage("FROM and TO are incompatible.")
			return .F.
		endif
		this.setRequiredTableStructure("set "+f1.getDefinition())
		if not BaseTable::create()
			this.messenger.errorMessage("Unable to create UeberSetTable.")
			return .F.
		endif
		m.dbf = this.getDBF()
		m.setAlias = createobject("UniqueAlias")
		m.setAlias = m.setAlias.getAlias()
		m.sql1 = "select a."+m.toField+" as to from "+m.tableAlias
		m.sql1 = m.sql1+" a where a."+m.fromField+" == m.from into cursor "+m.setAlias
		m.sql2 = "select c.from, count(*) as subset, c.set from "+m.tableAlias+" a, "+m.setAlias+" b, "+m.useAlias+" c "
		m.sql2 = m.sql2+"where a."+m.toField+" == b.to and a."+m.fromField+" == c.from and c.use == 1 "
		m.sql2 = m.sql2+"group by c.from into cursor "+m.setAlias
		m.pk = createobject("PreservedKey",m.table)
		m.table.forceKey(m.fromField)
		select (m.useAlias)
		index on from tag from
		go top
		m.rec = 1
		this.messenger.setDefault("Collected")
		this.messenger.startProgress(reccount())
		this.messenger.startCancel("Cancel Operation?","Collecting","Canceled.")
		do while m.rec <= reccount()
			if this.messenger.queryCancel()
				exit
			endif
			go record m.rec
			if use == 0
				m.rec = m.rec+1
				loop
			endif
			m.from = from
			try
				&sql1
			catch
				m.err = .t.
			endtry
			if m.err
				this.messenger.errorMessage("Unable to create temporary Table.")
				exit
			endif
			m.set = reccount()
			index on to tag to
			try
				&sql2
			catch
				m.err = .t.
			endtry
			if m.err
				this.messenger.errorMessage("Unable to create temporary Table.")
				exit
			endif
			m.ueberSet = .F.
			select (m.setAlias)
			go top
			do while not eof()
				if subset == set
					m.subFrom = from
					update (m.useAlias) set use = 0 where from = m.subFrom
				else
					if subset < set and subset == m.set
						m.ueberSet = .T.
					endif
				endif
				skip
			enddo
			if not m.ueberSet
				update (m.useAlias) set use = 1 where from = m.from
			endif
			this.messenger.setProgress(m.rec)
			this.messenger.postProgress()
			select (m.useAlias)
			m.rec = m.rec+1
		enddo
		this.messenger.sneakMessage("Closing...")
		select (m.setAlias)
		use
		select a.from as set from (m.useAlias) a where use == 1 order by a.from into table (m.dbf)
		this.synchronizeDBF()
		this.forceRequiredKeys()
		if this.messenger.isInterrupted()
			return .f.
		endif
		return .T.
	endfunc
enddefine
