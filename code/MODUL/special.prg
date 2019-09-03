*==========================================================================
* Modul:     special.prg
* Titel:     Funktionen für spezielle Operationen an und mit Tabellen
*            sowie low-level Dateifunktionen.
* Autor:     Thorsten Doherr (TDO)
* Datum:     2016.02.19
*==========================================================================

*--------------------------------------------------------------------------
* Funktion:   uniquealias
* Rueckgabe:  Eindeutiger, nicht benutzter Aliasname
*--------------------------------------------------------------------------
function uniquealias
local alias
	m.alias = sys(2015)
	do while used(m.alias)
		m.alias = sys(2015)
	enddo
	create cursor (m.alias) (dummy c(1))
	return m.alias

*--------------------------------------------------------------------------
* Funktion:   equalizer
* Parameter:  quality - Qualitätskennung der Vergleichskriterien
*             fields  - Feldnamenliste als String durch Kommas getrennt
*			  key     - Primaerer Schluessel der Tabelle
*             alias   - Aliasname eines Cursors der als Ergebnis entsteht
*             [table] - Aliasname der Tabelle auf die sich fields und key
*                       beziehen (Default ist aktueller Alias)
*             [empty] - numerischer Schalter für die Bewertung von leeren
*                       Feldern beim Vergleich (Default ist 0)
* Rueckgabe:  Die Funktion führt einen Abgleich der Tabelle table mit sich
*             selbst über die in der Feldliste fields definierten Felder
*             durch. Gleiche Datensätze werden in dem Cursor alias
*             mit den Primärschlüsseln key in den Feldern equal1 und 
*             equal2 verzeichnet. Zusätzlich wird der Vergleich mit der
*             Qualitätskennung quality gekennzeichnet. Die Funktion entfernt 
*             automatisch doppelte Vergleichspaare, wobei niedrigere
*             quality-Werte erhalten bleiben.
*             Die Funktion gibt die Qualitätskennung zurück.
* Hinweis:    Ein Vergleich ist false, wenn ein Operand leer ist. Bei
*             Zahlenfeldern gilt der Wert 0 als leer. Ist dies nicht
*             erwünscht, muss der empty-Schalter groesser 0 sein. Die
*             Auswirkung des empty-Schalters kann durch ein Minuszeichen,
*             das einem Feldnamen in der fields-Liste vorangestellt ist,
*             für dieses Feld umgekehrt werden.
*             Steht ein Minuszeichen vor dem Key, werden schlüsselgleiche
*             Datensätze ignoriert.
*--------------------------------------------------------------------------
function equalizer
lparameters quality, fields, key, alias, table, empty
local sql, i, lex, tmp, oldtalk, oldalias, nokey
	m.oldalias = alias()
	m.oldtalk = "set talk "+sys(103)
	set talk off
	if vartype(m.empty) != "N"
		if vartype(m.table) == "N"
			m.empty = m.table
		else
			m.empty = 0
		endif
	endif								
	if vartype(m.table) != "C"
		m.table = alias()
	endif
	m.add = ""
	m.alias = alltrim(m.alias)
	m.table = alltrim(m.table)		
	m.key = alltrim(m.key)
	m.tmp = uniquealias()
	if left(m.key,1) == "-"
		m.key = alltrim(substr(key,2))
		m.add = "and not a."+m.key+ " == " + "b."+m.key+" "
	endif
	m.sql = "select a."+m.key+" as equal1, b."+m.key+" as equal2, "+ltrim(str(m.quality))+" as quality from "+m.table+ " a, "+m.table+" b where "
	m.i = 1
	m.lex = _lexem(m.fields,m.i)
	do while !empty(m.lex)
		if left(m.lex,1) == "-"
			m.lex = substr(m.lex,2)
		endif			
		m.sql = m.sql + "a."+m.lex+"=="+"b."+m.lex+" "
		m.i = m.i+1
		m.lex = _lexem(m.fields,m.i)
		if !empty(m.lex)
			m.sql = m.sql + "and "
		endif			
	enddo
	m.sql = m.sql + m.add
	m.i = 1
	m.lex = _lexem(m.fields,m.i)
	do while !empty(m.lex)
		if left(m.lex,1) == "-"
			m.lex = substr(m.lex,2)
			if m.empty <= 0
				m.lex = ""
			endif					
		else
			if m.empty > 0
				m.lex = ""
			endif
		endif													
		if !empty(m.lex)				
			if inlist(type(m.table+"."+m.lex),"C","M")
				m.sql = m.sql + "and !empty(alltrim(a."+m.lex+")) "
			else			
				m.sql = m.sql + "and !empty(a."+m.lex+") "
			endif			
		endif				
		m.i = m.i+1
		m.lex = _lexem(m.fields,m.i)
	enddo
	set message to "Quality: "+ltrim(str(m.quality))
	if type(m.alias+".equal1") == "U" or type(m.alias+".equal2") == "U" or type(m.alias+".quality") == "U"
		m.sql = m.sql + "into cursor "+m.tmp
		&sql
	else
		m.sql = m.sql + "union select * from "+m.alias+" into cursor "+m.tmp
		&sql
	endif
	index on equal1 tag equal1
	select * from (m.tmp) a where not exists (select * from (m.tmp) b where a.equal1 = b.equal1 and a.equal2 = b.equal2 and b.quality < a.quality) into cursor (m.alias) 
	select (m.tmp)
	use
	if !empty(m.oldalias)
		select (m.oldalias)
	else		
		select (m.alias)
	endif		
	&oldtalk
	set message to 
	return m.quality

*--------------------------------------------------------------------------
* Funktion:    sqllocate
* Parameter:  [alias] - Aliasname der Tabelle die durchsucht werden soll.
*                       Die SQL-Abfrage sollte Bezug auf diese Tabelle
*                       nehmen. Fehlt diese Angabe, wird der aktuelle Alias
*                       verwendet.
*			   sql    - SQL-Abfrage als String.
*                       Das erste Feld der Abfrage muß dem aktiven
*                       Index der Tabelle (siehe alias gleichen).
*                       Sie muss sich in der FROM-Klausel auf den alias
*                       (siehe unten) beziehen und darf keine 
*                       ORDER-BY-Klausel oder TOP-Klausel beinhalten. 
*                       Sie muss eine WHERE Klausel haben, die allerdings 
*                       auch leer sein kann. IN- bzw. INTO-Klausel sind
*                       nicht erlaubt. GROUP-BY und HAVING sind erlaubt.
*             [dir]   - Richtung der Suche vom aktuellen Datensatz aus als
*                       positiver bzw. negativer numerischer Wert.
*                       Wenn Angabe fehlt, bzw. 0 ist, wird die Tabelle
*                       von oben nach unten durchsucht. Ist der absolute
*                       Wert grösser als 1 wird er als Schrittweite step
*                       benutzt, sofern diese nicht spezifiziert wurde.
*             [step]  - Gibt die Schrittweite in Datensätzen an, mit der
*                       Die Tabelle durchsucht wird. Default ist 1000.
* Rueckgabe:  True, wenn die SQL-Klausel erfüllt wurde. Der Satzzeiger wird
*             auf den gefundenen Datensatz positioniert.
*             False, wenn kein passender Datensatz gefunden wurde. Der 
*             Satzzeiger ist je nach Richtung der Suche in eof- bzw. bof-
*             Position.
* Hinweis:    Die SQL-Angabe wird so erweitert, das die Tabelle 
*             abschnittsweise durchsucht werden kann. Nur der erste Treffer
*             der SQL-Klausel wird benutzt. Die Abschnitte sind mindestens
*             step Datensätze gross, d.h. die SQL-Anweisung kann mehrfach
*             ausgeführt werden, bis entweder ein Datensatz gefunden wurde
*             oder das Dateiende bzw. der Dateianfang erreicht wurde.
*             Durch die Einteilung muss nicht die ganze Tabelle durchsucht
*             werden, und die temporären Dateien sind auch kleiner, so daß
*             ein deutlicher Geschwindigkeitsvorteil gegenüber einer
*             einzigen Abfrage vorliegt (sofern nur der erste Treffer von
*             Interesse ist). Der Vorteil gegenüber des LOCATE-Befehls 
*             liegt darin, daß SQL komplexere Abfragen mit Verknüpfungen
*             und Gruppierungen zulässt.
*--------------------------------------------------------------------------
function sqllocate
lparameters alias, sql, dir, step
local wpos, and, sqlexe, i, cursor, sqlerr, start, end, oldalias, key
	m.oldalias = alias()
	m.alias = upper(alltrim(m.alias))
	if left(m.alias,7) == "SELECT " and len(m.alias) > 10
		m.step = m.dir
		m.dir = m.sql
		m.sql = m.alias
		m.alias = alias()
	endif
	if empty(m.alias)
		error "SQLLOCATE: No active alias declared."
		return .F.
	endif
	m.sql = upper(alltrim(m.sql))
	if vartype(m.dir) != "N"
		m.dir = 0
		m.step = 1000
	else
		if vartype(m.step) != "N" 
			if abs(m.dir) > 1
				m.step = abs(m.dir)
			else
				m.step = 1000
			endif
		endif
	endif
	if m.dir = 0
		go top in (m.alias)
	endif
	m.step = abs(m.step)
	m.dir = iif(m.dir < 0, m.step * -1, m.step)
	m.cursor = uniquealias()
	m.sql = m.sql+" INTO CURSOR "+m.cursor
	m.i = 1
	m.wpos = at(" WHERE ",m.sql)
	do while m.wpos > 0
		m.sqlexe = stuff(m.sql,m.wpos+6,1," 1 = 0 AND ")
		m.sqlerr = .F.
		try
			&sqlexe
		catch
			m.sqlerr = .t.
		endtry
		if !sqlerr
			m.and = "AND "
			exit
		endif
		m.sqlexe = stuff(m.sql,m.wpos+6,1," 1 = 0 ")
		m.sqlerr = .F.
		try
			&sqlexe
		catch
			m.sqlerr = .t.
		endtry
		if !sqlerr
			m.and = ""
			exit
		endif
		m.i = m.i + 1
		m.wpos = at(" WHERE ",m.sql,m.i)
	enddo
	if m.wpos = 0
		select (m.cursor)
		use
		if !empty(m.oldalias)
			select (m.oldalias)
		endif
		error "SQLLOCATE: Unable to locate proper WHERE in the SQL-Statement. At least a dummy WHERE is required."
		return .F.
	endif
	m.key = field(1,m.cursor)
	m.i = 1
	do while !empty(key(m.i,m.alias)) and key(m.i,m.alias) != m.key
		m.i = m.i + 1
	enddo
	if empty(order(m.alias)) or not (order(m.alias) == tag(m.i,m.alias))
		error "SQLLOCATE: Table has to be indexed on the first field of the SQL-Statement."
		return .F.
	endif
	if m.dir > 0
		m.sql = stuff(m.sql,m.wpos+6,1, " "+m.key+" >= M.START AND "+m.key+" <= M.END "+m.and)
	else
		m.sql = stuff(m.sql,m.wpos+6,1, " "+m.key+" >= M.END AND "+m.key+" <= M.START "+m.and)
	endif
	m.sql = stuff(m.sql,at(" ",m.sql),1," TOP 1 ")
	m.sql = m.sql + " ORDER BY "+m.key+iif(m.dir > 0," ASC", " DESC")
	if bof(m.alias)
		go top in (m.alias)
	else
		if eof(m.alias)
			go bottom in (m.alias)
		endif
	endif
	m.start = evaluate(m.alias+"."+m.key)
	do while reccount(m.cursor) = 0 and !bof(m.alias) and !eof(m.alias)
		skip m.dir in (m.alias)
		do case
			case eof(m.alias)
				go bottom in (m.alias)
				m.end = evaluate(m.alias+"."+m.key)
				skip in (m.alias)
			case bof(m.alias)
				go top in (m.alias)
				m.end = evaluate(m.alias+"."+m.key)
				skip -1 in (m.alias)	
			otherwise
				m.end = evaluate(m.alias+"."+m.key)
		endcase			
		do while m.start == m.end and !bof(m.alias) and !eof(m.alias)
			skip m.dir in (m.alias)
			m.end = evaluate(m.alias+"."+m.key)
		enddo
		&sql
		m.start = m.end
	enddo
	if reccount(m.cursor) > 0
		m.key = evaluate(m.cursor+"."+m.key)
		seek m.key in (m.alias)
	else
		if m.dir > 0
			go bottom in (m.alias)
			skip in (m.alias)
		else
			go top in (m.alias)
			skip -1 in (m.alias)
		endif
	endif
	select (m.cursor)
	use
	if !empty(m.oldalias)
		select (m.oldalias)
	endif
	if !eof(m.alias) and !bof(m.alias)
		return .T.
	endif
	return .F.
	
*--------------------------------------------------------------------------
* Funktion:   _lexem
* Parameter:  str  - String
*             num  - Nummer des Lexems
* Rueckgabe:  Lexem (Wort) mit der angegebenen Nummer aus der durch Komma
*             getrennten Liste.
* Hinweis:    Diese Funktion ist eine reine Unterfunktion und sollte nicht
*             ausserhalb der in diesem Modul definierten Funktionen
*             verwendet werden. Die Funktion lexem im Modul STRING
*             erfüllt den gleichen Zweck und mehr.
*--------------------------------------------------------------------------
FUNCTION _lexem
LPARAMETERS str, num
LOCAL start, end, typ, len, beg, lex
    IF m.num = 1
        m.start = 1
    ELSE
        m.start = AT(",", m.str, m.num - 1) + 1
        IF m.start = 1
            RETURN ""
        ENDIF
    ENDIF
    m.end = AT(",", m.str, m.num)
    IF m.end = 0
        m.end = LEN(m.str) + 1
		m.beg = m.start-1
	ELSE
		m.beg = m.start
	ENDIF				        
    IF m.start = m.end
   	    RETURN ""
    ENDIF
    m.len = m.end - m.start
   	m.lex = ALLTRIM(SUBSTR(m.str, m.start, m.len))
   	RETURN m.lex
endfunc
   	
*--------------------------------------------------------------------------
* Funktion:   readline
* Parameter:  handle  - Handle auf eine Text-Datei (siehe fopen())
*             crlf    - Nur CR LF Sequenz wird als Zeilenumbruch anerkannt
* Rueckgabe:  Zeile aus der Textdatei ohne Längeneinschränkung wie sie
*             z.B. der Befehl gets() hat.
*--------------------------------------------------------------------------
function readline(handle as Integer, crlf as boolean)
local chr, buffer, line, newline, step
	m.step = iif(m.crlf,2,1)
	m.line = ""
	m.newline = chr(13)+chr(10)
	m.buffer = fgets(m.handle,8000)
	fseek(m.handle,-m.step,1)
	m.chr = fread(m.handle,m.step)
	do while not m.chr $ m.newline and not feof(m.handle)
		m.line = m.line+m.buffer
		if len(m.buffer) < 8000
			m.line = m.line+chr(10)
		endif
		m.buffer = fgets(m.handle,8000)
		fseek(m.handle,-m.step,1)
		m.chr = fread(m.handle,m.step)
	enddo
	return m.line+m.buffer
endfunc
   	