*==========================================================================
* Modul:     STRING.PRG
* Titel:     Funktionen fuer Stringverarbeitung und Stringvergleiche
* Author:    Thorsten Doherr (TDO)
* Datum:     2019.08.06
*==========================================================================

*--------------------------------------------------------------------------
* Funktion:   FirmNorm
* Parameter:  firmname - Firmenname als String
* Rueckgabe:  Standardisierter Firmennamen
*--------------------------------------------------------------------------
FUNCTION FirmNorm(firmname as String)
    m.firmname = ALLTRIM(m.firmname)
    m.firmname = Compress(m.firmname)
    m.firmname = Disentangle(m.firmname, "für")
    m.firmname = Disentangle(m.firmname, "und")
    m.firmname = Disentangle(m.firmname, "u.")
    m.firmname = Disentangle(m.firmname, "&")
    m.firmname = ClrMinus(m.firmname)
    m.firmname = STRTRAN(m.firmname, "(Deutschland)", "Deutschland")
    m.firmname = STRTRAN(m.firmname, "(Europe)", "Europe")
    m.firmname = STRTRAN(m.firmname, "(Europa)", "Europa")
    m.firmname = STRTRAN(m.firmname, " - und ", "- und ")
    m.firmname = STRTRAN(m.firmname, " - u. ", "- u. ")
    m.firmname = STRTRAN(m.firmname, "##**##", "")
    m.firmname = STRTRAN(m.firmname, "in Aufbau", "")
    m.firmname = STRTRAN(m.firmname, "in Gründung", "")
    m.firmname = STRTRAN(m.firmname, "in Gruendung", "")
    m.firmname = STRTRAN(m.firmname, "in Liquidation", "i.L.")
    m.firmname = STRTRAN(m.firmname, " fuer ", " für ")
    m.firmname = STRTRAN(m.firmname, "(Deutschland)", "Deutschland")
    m.firmname = STRTRAN(m.firmname, "m.b.H.", "mbH")     
    m.firmname = STRTRAN(m.firmname, "mit beschr. Haftung", "mbH")
    m.firmname = STRTRAN(m.firmname, "m. beschr. Haftung", "mbH")
    m.firmname = STRTRAN(m.firmname, "m. beschränkter Haftung", "mbH")    
    m.firmname = STRTRAN(m.firmname, "m. beschraenkter Haftung", "mbH")   
    m.firmname = STRTRAN(m.firmname, "mit beschraenkter Haftung", "mbH")
    m.firmname = STRTRAN(m.firmname, "mit beschränkter Haftung", "mbH")
    m.firmname = Separate(m.firmname, "mbH")
    m.firmname = STRTRAN(m.firmname, "Gesellschaft mbH", "GmbH")
    m.firmname = STRTRAN(m.firmname, "Gesell. mbH", "GmbH")
    m.firmname = STRTRAN(m.firmname, "Ges. mbH", "GmbH")
    m.firmname = STRTRAN(m.firmname, "G. mbH", "GmbH")
    m.firmname = Separate(m.firmname, "GmbH") 
    m.firmname = STRTRAN(m.firmname, "Aktiengesellschaft", "AG")
    m.firmname = STRTRAN(m.firmname, "AKTIENGESELLSCHAFT", "AG")
    m.firmname = STRTRAN(m.firmname, "Aktiengesell.", "AG")
    m.firmname = STRTRAN(m.firmname, "Aktienges.", "AG")
    m.firmname = STRTRAN(m.firmname, "Kommanditgesellschaft", "KG")
    m.firmname = STRTRAN(m.firmname, "Kommanditgesell.", "KG")
    m.firmname = STRTRAN(m.firmname, "Kommanditges.", "KG")
    m.firmname = ClrBrackets(m.firmname, "GmbH & Co")
    m.firmname = ClrBrackets(m.firmname, "i.L.")
    m.firmname = DelBrackets(m.firmname)
    m.firmname = NoStar(m.firmname)
    RETURN m.firmname
endfunc

*--------------------------------------------------------------------------
* Funktion:   StreetNorm
* Parameter:  str - Strassenname als String
* Rueckgabe:  Standardisierter Strassenname. Achtung: Umsetzung in 
*             Grossbuchstaben
*--------------------------------------------------------------------------
FUNCTION StreetNorm(str as String)
    RETURN STRTRAN(TermPrep(m.str), "STR ", "STRASSE ")
endfunc
	
*--------------------------------------------------------------------------
* Funktion:   FirmComp
* Parameter:  firm1 - Firmenname als String
*             firm2 - Firmenname als String
*             depth - Verschachtelungstiefe (siehe TermComp)
* Rueckgabe:  Heuristischer Wert fuer Vergleichbarkeit der beiden Firmen-
*             namen zwischen 0 und 1, wobei 1 Gleichheit bedeuted.
*--------------------------------------------------------------------------
FUNCTION FirmComp(firm1 as String, firm2 as String)
    m.firm1 = FirmNorm(m.firm1)
    m.firm2 = FirmNorm(m.firm2)
    m.firm1 = TermPrep(m.firm1)
    m.firm2 = TermPrep(m.firm2)
   	RETURN TermComp(m.firm1, m.firm2,3)
endfunc

*--------------------------------------------------------------------------
* Funktion:   StreetComp
* Parameter:  str1 - Strassenname als String
*             str2 - Strassenname als String
* Rueckgabe:  Heuristischer Wert fuer Vergleichbarkeit der beiden Strassen-
*             namen zwischen 0 und 1, wobei 1 Gleichheit bedeutet.
*             Der Strassenname wird mit 70% und die Hausnummer mit 30%
*             gewichtet.
*--------------------------------------------------------------------------
FUNCTION StreetComp(str1 as String, str2 as String)
LOCAL hnr1, hnr2
    m.hnr1 = FilterPattern(m.str1, "1234567890")
    m.hnr2 = FilterPattern(m.str2, "1234567890")
    m.str1 = DeletePattern(m.str1, "1234567890")
    m.str2 = DeletePattern(m.str2, "1234567890")
    RETURN ROUND(StringComp(m.str1,m.str2,3)*0.7+StringComp(m.hnr1,m.hnr2,2)*0.3,2)
endfunc
         
*--------------------------------------------------------------------------
* Funktion:   TermComp
* Parameter:  str1  - String
*             str2  - String
*             range - Nachbarschaftsbereich (siehe StringComp) 
* Rueckgabe:  Heuristischer Wert fuer Vergleichbarkeit der beiden Strings
*             zwischen 0 und 1, wobei 1 Gleichheit bedeutet.
*             Die Strings werden als Sätze interpretiert, wobei die Worte
*             durch Blanks getrennt sind. Da für den Vergleich nur die
*             Worte und deren Positionen innerhalb des Satzes von Bedeutung
*             sind, spielt die Anzahl der Blanks zwischen den Worten keine 
*             Rolle.
*--------------------------------------------------------------------------
FUNCTION TermComp(str1 as String, str2 as String, range as Integer)
LOCAL i, j, ind, max, lex1, lex2, anz, wscore, pscore, highscore
    IF m.str1 == m.str2
        RETURN 1
    ENDIF
    m.str1 = Compress(alltrim(m.str1))
    m.str2 = Compress(alltrim(m.str2))
    m.anz = 0
    m.ind = 0
    m.max = 40
    DIMENSION heuristic[m.max,3]
    m.i = 1   
    m.lex1 = Lexem(m.str1,1)
    DO WHILE !EMPTY(m.lex1)
    	m.j = 1
	    m.lex2 = Lexem(m.str2,1)
    	DO WHILE !EMPTY(m.lex2)
    		m.ind = m.ind+1
    		IF m.ind > m.max
    			m.max = m.max+20
    			DIMENSION heuristic[m.max,3]
    		ENDIF
    		heuristic[m.ind,1] = m.i	
    		heuristic[m.ind,2] = m.j
    		heuristic[m.ind,3] = stringcomp(m.lex1,m.lex2,m.range)
			m.j = m.j+1
			m.lex2 = Lexem(m.str2,m.j)
		ENDDO
	    m.i = m.i+1
    	m.lex1 = Lexem(m.str1,m.i)
	ENDDO					
	m.highscore = MAX(m.j-1,m.i-1)
    m.wscore = 0
    m.pscore = 0
    DO WHILE m.max >= 0
    	m.max = -1  
    	FOR m.i = 1 TO m.ind
    		IF heuristic[m.i,3] > m.max
    			m.max = heuristic[m.i,3]
				m.j = m.i
			ENDIF
		ENDFOR
		IF m.max >= 0
			m.wscore = m.wscore+m.max
			m.pscore = m.pscore+(m.highscore-ABS(heuristic[m.j,1]-heuristic[m.j,2]))*m.max
			FOR m.i = 1 TO m.ind
				IF heuristic[m.i,1] = heuristic[m.j,1] OR heuristic[m.i,2] = heuristic[m.j,2]
					heuristic[m.i,3] = -2
				ENDIF
			ENDFOR
		ENDIF												
	ENDDO
    RETURN ROUND(IIF(m.highscore > 0, (m.wscore/m.highscore+m.pscore/m.highscore/m.highscore)/2, 0),2)   
endfunc

*--------------------------------------------------------------------------
* Funktion:   TermPrep
* Parameter:  term - String
* Rueckgabe:  Standardisierter String fuer Stringvergleich mit Normierung
*             von Firmennamen und Strassen
*--------------------------------------------------------------------------
FUNCTION TermPrep(term as String)
LOCAL i, newterm, lex, lastlen
    m.term = ALLTRIM(UPPER(m.term))
    m.term = STRTRAN(m.term, "Ä", "AE")
    m.term = STRTRAN(m.term, "Ö", "OE")
    m.term = STRTRAN(m.term, "Ü", "UE")
    m.term = STRTRAN(m.term, "ß", "SS")
    m.term = STRTRAN(m.term, "&", "UND")
    m.term = BlankInversePattern(m.term, " ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")
    m.term = LTRIM(Compress(m.term))
    m.newterm = ""
    m.i = 1
    m.lex = Lexem(m.term,1)
    m.lastlen = 1
    DO WHILE !EMPTY(m.lex)
    	IF LEN(m.lex) = 1
    		IF m.lastlen = 1
    			m.newterm = m.newterm+m.lex
			ELSE    			
				m.lastlen = 1
    			m.newterm = m.newterm+" "+m.lex
			ENDIF			
		ELSE
			m.lastlen = 0
			m.newterm = m.newterm+" "+m.lex
		ENDIF	
		m.i = m.i + 1
		m.lex = Lexem(m.term,m.i)
	ENDDO
    m.newterm = righttran(m.newterm, "GESELLSCHAFT", "GES")
    m.newterm = righttran(m.newterm, "GESELL", "GES")
    m.newterm = righttran(m.newterm, "STRASSE", "STR")
    m.newterm = alltran(m.newterm, "MIT BESCHRAENKTER HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "MIT BESCHR HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "MIT BESCH HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "MIT B HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "M BESCHRAENKTER HAFTUNG", "MBH")    
    m.newterm = alltran(m.newterm, "M BESCHR HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "M BESCH HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "MB HAFTUNG", "MBH")
    m.newterm = alltran(m.newterm, "MIT BESCHRAENKTER HAFT", "MBH")
    m.newterm = alltran(m.newterm, "MIT BESCHR HAFT", "MBH")
    m.newterm = alltran(m.newterm, "MIT BESCH HAFT", "MBH")
    m.newterm = alltran(m.newterm, "MIT B HAFT", "MBH")
    m.newterm = alltran(m.newterm, "M BESCHRAENKTER HAFT", "MBH")    
    m.newterm = alltran(m.newterm, "M BESCHR HAFT", "MBH")
    m.newterm = alltran(m.newterm, "M BESCH HAFT", "MBH")
    m.newterm = alltran(m.newterm, "MB HAFT", "MBH")
    m.newterm = alltran(m.newterm, "GES MBH", "GMBH")
    m.newterm = alltran(m.newterm, "AKTIENGES", "AG")
    m.newterm = alltran(m.newterm, "KOMMANDITGES", "KG")
	RETURN LTRIM(m.newterm)
endfunc
          
*--------------------------------------------------------------------------
* Prozedur:   StringComp
* Parameter:  string1  - 1. Vergleichsstring
*             string2  - 2. Vergleichsstring
*             range    - Nachbarschaftsbereich
* Rueckgabe:  Heuristischer Wert zwischen 1 (gleich) und 0 (ungleich) für
*             die Gleichheit der Strings.
*             Der Nachbarschaftsbereich regelt, wie weit ein Zeichen 
*             verschoben sein darf, um noch als vorhanden identifiziert
*             zu werden. Je kleiner dieser Bereich ist, desto wichtiger ist
*             die Position der Buchstaben zwischen den Vergleichstrings
*             zueinander.
*-------------------------------------------------------------------------
FUNCTION StringComp(str1 as String, str2 as String, range as Integer)
local len1, len2
	m.len1 = LEN(m.str1)
	m.len2 = LEN(m.str2)
	IF m.len1 = 0 OR m.len2 = 0
		IF m.len1 > 0 OR m.len2 > 0
			RETURN 0
		ENDIF
		RETURN 1
	ENDIF					
	IF m.len1 < m.len2
		IF TYPE("m.range") != "N"
			m.range = m.len1
		ENDIF				
		RETURN 1 - orthocomp(m.str2, m.str1, m.len2, m.len1, m.range)/len2/(len1+1)
	ENDIF
	IF TYPE("m.range") != "N"
		m.range = m.len2
	ENDIF
	RETURN 1 - orthocomp(m.str1, m.str2, m.len1, m.len2, m.range)/(len2+1)/len1
endfunc

*--------------------------------------------------------------------------
* Prozedur:   OrthoComp
* Parameter:  str1  - 1. Vergleichsstring
*             str2  - 2. Vergleichsstring
*             range - Nachbarschaftsbereich
* Rueckgabe:  Summe der abweichenden Zeichenpositionen.
* Hinweis:    Diese Funktion ist eine Unterfunktion von StringComp.
*--------------------------------------------------------------------------
FUNCTION OrthoComp(str1 as String, str2 as String, range as Integer)
local len1, len2, chr1, pos1, pos2, rate, dif
	m.rate = m.len2/m.len1
	m.range = INT(m.range*m.rate+0.5)
	m.pos2 = 0
	m.dif = 0
	FOR m.pos1 = 1 TO m.len1
		m.pos2 = m.pos2 + m.rate
		m.chr1 = SUBSTR(m.str1,m.pos1,1)
		m.dif = m.dif + orthorange(m.chr1,@m.str2,MAX(INT(m.pos2+0.5),1),m.len2,m.range)
	ENDFOR
	RETURN m.dif
endfunc

*--------------------------------------------------------------------------
* Prozedur:   OrthoRange
* Parameter:  chr   - gesuchtes Zeichen
*             str   - String
*             pos   - zentrale Startposition im String
*             len   - Stringlänge
*             range - Nachbarschaftsbereich
* Rueckgabe:  Position des gesuchten Zeichens relativ zur Startposition
*             im String. Wenn das Zeichen nicht innerhalb des Nachbar-
*             schaftsbereich liegt, wird die Stringlänge + 1 zurückgegeben.
* Hinweis:    Diese Funktion ist eine Unterfunktion von OrthoComp.
*--------------------------------------------------------------------------
FUNCTION OrthoRange(chr as String, str as String, pos as Integer, len as Integer, range as Integer)
LOCAL plus, minus, max, min
	IF RIGHT(LEFT(m.str,m.pos),1) == m.chr
		m.str = STUFF(m.str,m.pos,1,CHR(0))
		RETURN 0
	ENDIF
	m.plus = m.pos+1
	m.minus = m.pos-1
	m.min = MAX(m.pos-m.range,1)
	m.max = MIN(m.pos+m.range,m.len)
	DO WHILE m.plus <= m.max OR m.minus >= m.min
		IF m.minus >= m.min
			IF RIGHT(LEFT(m.str,m.minus),1) == m.chr
				m.str = STUFF(m.str,m.minus,1,CHR(0))
				RETURN m.pos - m.minus
			ENDIF
			m.minus = m.minus - 1
		ENDIF
		IF m.plus <= m.max
			IF RIGHT(LEFT(m.str,m.plus),1) == m.chr
				m.str = STUFF(m.str,m.plus,1,CHR(0))
				RETURN m.plus - m.pos
			ENDIF
			m.plus = m.plus + 1
		ENDIF
	ENDDO
	RETURN m.len + 1
endfunc
	
*--------------------------------------------------------------------------
* Funktion:   FirstDif
* Parameter:  str1  - Vergleichsstring 1
*             str2  - Vergleichsstring 2
* Rueckgabe:  Position des Ersten Unterschieds in den Strings
*--------------------------------------------------------------------------
FUNCTION FirstDif(str1 as String, str2 as String)
LOCAL pos, len1, len2
	m.len1 = LEN(m.str1)
	m.len2 = LEN(m.str2)
	m.pos = 1
    DO WHILE m.pos <= m.len1 AND m.pos <= m.len2
        IF NOT SUBSTR(m.str1, m.pos, 1) == SUBSTR(m.str2, m.pos, 1)
            RETURN m.pos
        ENDIF
        m.pos = m.pos + 1
    ENDDO
	IF m.len1 = m.len2
		RETURN 0
	ENDIF
	RETURN -1

*--------------------------------------------------------------------------
* Funktion:   Disentangle
* Parameter:  str - String
*             sep - zu separierender String
* Rueckgabe:  <str>, in dem <sep> von den angrenzenden Zeichen durch Blanks 
*             getrennt ist, wenn es vor einem Grossbuchstaben steht und 
*             vor ihm kein Buchstabe steht. Die Funktion dient dazu, 
*             Trennwörter wie z.B. "und" oder "bzw." in unsauberen Texten 
*             zu separieren.   
*--------------------------------------------------------------------------
FUNCTION Disentangle(str as String, sep as String)
LOCAL lenstr, lensep, num, pos, next, prev
    m.lenstr = LEN(m.str)
    m.lensep = LEN(m.sep)
    m.num  = 1
    m.pos  = AT(m.sep, m.str, m.num)
    m.next = m.pos + m.lensep
    m.prev = m.pos - 1
    DO WHILE m.pos > 1 AND m.next <= m.lenstr
        IF !ISALPHA(SUBSTR(m.str, m.prev, 1))
            IF RIGHT(m.sep, 1) = "." OR !ISLOWER(SUBSTR(m.str, m.next, 1))
                IF SUBSTR(m.str, m.next, 1) != " "
                    m.str = STUFF(m.str, m.next, 0, " ") 
                    m.lenstr = m.lenstr + 1
                ENDIF
                IF SUBSTR(m.str, m.prev, 1) != " "
                    m.str =  STUFF(m.str, m.pos, 0, " ")
                    m.lenstr = m.lenstr + 1
                ENDIF
            ENDIF
        ENDIF
        m.num  = m.num + 1
        m.pos  = AT(m.sep, m.str, m.num)
        m.next = m.pos + m.lensep
        m.prev = m.pos - 1
    ENDDO
    RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   Separate
* Parameter:  str - String
*             sep - zu separierender String
* Rueckgabe:  <str>, in dem <sep> von den angrenzenden Zeichen durch Blanks 
*             getrennt ist, wenn es sich bei diesen Zeichen um Buchstaben
*             handelt. Die Funktion dient dazu, Wörter, die nicht
*             Bestandteil anderer Wörter sein können, zu separieren 
*             (z.B.: GmbH).   
*--------------------------------------------------------------------------
FUNCTION Separate(str as String, sep as String)
LOCAL lenstr, num, pos, prev, chr, next, lensep
    m.lenstr = LEN(m.str)
    m.lensep = LEN(m.sep)
    m.num  = 1
    m.pos  = AT(m.sep, m.str, m.num)
    m.next = m.pos + m.lensep
    m.prev = m.pos - 1
    DO WHILE m.pos > 1
        IF m.prev > 0
            m.chr = SUBSTR(m.str, m.prev, 1)
            IF ISLOWER(chr) OR chr = "."
                m.str = STUFF(m.str, m.pos, 0, " ") 
                m.lenstr = m.lenstr + 1
                m.next = m.next + 1
            ENDIF
        ENDIF
        IF m.next <= m.lenstr
            chr = SUBSTR(m.str, m.next, 1)
            IF ISUPPER(chr)                    
                m.str =  STUFF(m.str, m.next, 0, " ")
                m.lenstr = m.lenstr + 1            
            ENDIF                              
        ENDIF
        m.num  = m.num + 1
        m.pos  = AT(m.sep, m.str, m.num)
        m.next = m.pos + m.lensep
        m.prev = m.pos - 1
    ENDDO
    RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   ClrMinus
* Parameter:  str - String mit Trennzeichen "-"
* Rueckgabe:  Gesaeuberter String ohne ueberfluessige Trennzeichen
*             Trennzeichen sind nicht überflüssig...
*             - vor Verknuepfungswoertern wie "und" oder "sowie"
*             - wenn kein angrenzendes Blank vorhanden ist
*             - wenn keine angrenzenden Buchstaben vorhanden sind
*             - wenn sie komplett separat stehen (zwischen Blanks)
*             - vor Großbuchstaben 
*             Trifft keine der obigen Bedingungen zu, und folgt ein Klein-
*             buchstabe, so wird das Trennzeichen entfernt. Sonst werden
*             angrenzende Blanks entfernt, wenn kein Blank vorangestellt
*             ist. 
*--------------------------------------------------------------------------
FUNCTION ClrMinus(str as String)
LOCAL len, num, pos, prev, next, tnext, tprev, utnext, utprev
    m.num = 1
    m.len = LEN(m.str)
    m.pos = AT("-", m.str, m.num)
    DO WHILE m.pos > 1 AND m.pos < m.len
        m.next = RIGHT(m.str, m.len - m.pos)
        m.prev = LEFT(m.str, m.pos - 1)
		m.tnext = LTRIM(m.next)
		m.tprev = RTRIM(m.prev)
		m.utnext = UPPER(LEFT(m.tnext,6))+" "
		m.utprev = UPPER(RIGHT(m.tprev,6))
        DO CASE
            CASE NOT(LEFT(m.next,1) == " " OR RIGHT(m.prev,1) == " ")
            CASE LEFT(m.next,1) == " " AND RIGHT(m.prev,1) == " "
			CASE NOT (ISALPHA(RIGHT(m.tprev,1)) AND ISALPHA(m.tnext))
            CASE LEFT(m.utnext, 2) == "U."
            CASE INLIST(LEFT(m.utnext, 4), "UND ", "BZW ")
            CASE INLIST(LEFT(m.utnext, 5), "ODER ", "BZW. ")
            CASE LEFT(m.utnext, 6) == "SOWIE "
            CASE INLIST(RIGHT(m.utprev, 4), " UND", " BZW")
            CASE RIGHT(m.utprev, 5) == " ODER"
            CASE RIGHT(m.utprev, 6) == " SOWIE"
            CASE ISLOWER(m.tnext)   
                m.str = m.tprev + m.tnext   
                m.len = LEN(m.str)
                m.num = m.num - 1
            CASE RIGHT(m.prev,1) != " "
                m.str = m.tprev + "-" + m.tnext
                m.len = LEN(m.str)
        ENDCASE  
        m.num = m.num + 1
        m.pos = AT("-", m.str, m.num)
    ENDDO
    RETURN m.str
   endfunc
    
*--------------------------------------------------------------------------
* Funktion:   Compress
* Parameter:  str - String
* Rueckhabe:  <str> ohne Mehrfachleerzeichen 
*--------------------------------------------------------------------------
FUNCTION Compress(str as String)
LOCAL len
    m.len = len(m.str)
    m.str = strtran(m.str,"  ", " ")
    do while len(m.str) != m.len
    	m.len = len(m.str)
	    m.str = strtran(m.str,"  ", " ")
    enddo
    return m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   DelBrackets
* Parameter:  str - String
* Rueckhabe:  <str> ohne Klammerausdruecke
*             Achtung: geschachtelte Klammerausdruecke fuehren zu Fehlern 
*--------------------------------------------------------------------------
FUNCTION DelBrackets(str as String)
LOCAL start, len
    m.start = AT("(", m.str)
    DO WHILE m.start > 0
        m.len = AT(")", SUBSTR(m.str, m.start)) 
        IF m.len = 0
            EXIT
        ENDIF
        m.str = STUFF(m.str, m.start, m.len, "")
        IF SUBSTR(m.str, m.start - 1, 2) = "  "
            m.str = STUFF(m.str, m.start, 1, "")
        ENDIF
        m.start = AT("(", m.str)
    ENDDO
    RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   ClrBrackets
* Parameter:  str - String
*             inh - String (Klammerinhalt)
* Rueckhabe:  Alle Klammern die <inh> beinhalten werden entfernt
*             Achtung: geschachtelte Klammerausdruecke fuehren zu Fehlern 
*--------------------------------------------------------------------------
FUNCTION ClrBrackets(str as String, inh as String)
LOCAL num, start, ende
    m.num = 1
    m.start = AT("(", m.str, m.num)
    DO WHILE m.start > 0
        m.ende = AT(")", SUBSTR(m.str, m.start)) + m.start - 1  
        IF m.ende < m.start
            EXIT
        ENDIF
        IF m.inh $ SUBSTR(m.str, m.start + 1, m.ende - m.start - 1)
            m.str = STUFF(m.str, m.start, 1, "")
            m.str = STUFF(m.str, m.ende - 1, 1, "")
        ELSE
            m.num = m.num + 1
        ENDIF
        m.start = AT("(", m.str, m.num)
    ENDDO
    RETURN m.str
endfunc
                            
*--------------------------------------------------------------------------
* Prozedur:   Changed
* Parameter:  chg1  - Referenz auf einen String
*             chg2  - Referenz auf einen String
* Aufgabe:    Die Strings werden miteinander verglichen.
*             Weichen sie voneinander ab, wird der jeweilige Unterschied
*             in den Strings auf Wortgrenze referenziert.
*--------------------------------------------------------------------------
PROCEDURE Changed(chg1, chg2)
LOCAL len1, len2, str1, str2, pos, pos1, pos2
	m.str1 = m.chg1
	m.str2 = m.chg2
    m.len1 = LEN(m.str1)
    m.len2 = LEN(m.str2)
	m.chg1 = ""
	m.chg2 = ""
    m.pos = 1
    DO WHILE m.pos <= m.len1 AND m.pos <= m.len2
        IF SUBSTR(m.str1, m.pos, 1) <> SUBSTR(m.str2, m.pos, 1)
            EXIT
        ENDIF
        m.pos = m.pos + 1
    ENDDO
	IF m.pos > m.len1 AND m.pos > m.len2
		RETURN
	ENDIF		
	DO CASE
		CASE m.pos > m.len1
		    m.pos = RAT(" ", LEFT(m.str2, m.pos)) + 1 
		    IF m.pos <= m.len1
			    m.chg1 = SUBSTR(m.str1, m.pos)
			ENDIF			    
			m.chg2 = SUBSTR(m.str2, m.pos)
			RETURN  	
		CASE m.pos > m.len2
		    m.pos = RAT(" ", LEFT(m.str1, m.pos)) + 1 
		    IF m.pos <= m.len2
			    m.chg2 = SUBSTR(m.str2, m.pos)
			ENDIF			    
			m.chg1 = SUBSTR(m.str1, m.pos)
			RETURN  	
		OTHERWISE
		    m.pos = RAT(" ", LEFT(m.str1, m.pos - 1)) + 1 
	ENDCASE		    
    m.chg1 = SUBSTR(m.str1, m.pos)
    m.chg2 = SUBSTR(m.str2, m.pos)
    m.len1 = LEN(m.chg1)
    m.len2 = LEN(m.chg2)
    m.pos1 = m.len1
    m.pos2 = m.len2
    DO WHILE m.pos1 > 0 AND m.pos2 > 0
        IF SUBSTR(m.chg1, m.pos1, 1) != SUBSTR(m.chg2, m.pos2, 1)
             EXIT
        ENDIF
        m.pos1 = m.pos1 - 1
        m.pos2 = m.pos2 - 1
    ENDDO
    IF m.pos1 = m.len1
        RETURN
    ENDIF
    DO CASE
    	CASE m.pos1 = 0
	    	m.pos = AT(" ", SUBSTR(m.chg2, m.pos2)) - 1
		CASE m.pos2 = 0				
	    	m.pos = AT(" ", SUBSTR(m.chg1, m.pos1)) - 1
		OTHERWISE	    	
		    m.pos = AT(" ", SUBSTR(m.chg1, m.pos1+1)) - 1
	ENDCASE		    
    IF m.pos < 0
        RETURN
    ENDIF
	IF m.pos1 != 0 OR m.pos != 0
	    m.chg1 = LEFT(m.chg1, m.pos1 + m.pos)
	ELSE
		m.chg1 = ""
	ENDIF			    
	IF m.pos2 != 0 OR m.pos != 0
	    m.chg2 = LEFT(m.chg2, m.pos2 + m.pos)           
	ELSE
		m.chg2 = ""
	ENDIF			    
    return
endfunc

*--------------------------------------------------------------------------
* Prozedur:   StringDif
* Parameter:  chg1  - Referenz auf einen String
*             chg2  - Referenz auf einen String
* Aufgabe:    Die Strings werden miteinander verglichen.
*             Weichen sie voneinander ab, wird der jeweilige Unterschied
*             in den Strings referenziert.
*--------------------------------------------------------------------------
PROCEDURE StringDif(chg1, chg2)
LOCAL len1, len2, str1, str2, pos, pos1, pos2
	m.str1 = m.chg1
	m.str2 = m.chg2
    m.len1 = LEN(m.str1)
    m.len2 = LEN(m.str2)
	m.chg1 = ""
	m.chg2 = ""
    m.pos = 1
    DO WHILE m.pos <= m.len1 AND m.pos <= m.len2
        IF SUBSTR(m.str1, m.pos, 1) <> SUBSTR(m.str2, m.pos, 1)
            EXIT
        ENDIF
        m.pos = m.pos + 1
    ENDDO
	IF m.pos > m.len1 AND m.pos > m.len2
		RETURN
	ENDIF		
	DO CASE
		CASE m.pos > m.len1
			m.chg2 = SUBSTR(m.str2, m.pos)
			RETURN  	
		CASE m.pos > m.len2
		    m.chg1 = SUBSTR(m.str1, m.pos)
			RETURN  	
	ENDCASE	
    m.chg1 = SUBSTR(m.str1, m.pos)
    m.chg2 = SUBSTR(m.str2, m.pos)
    m.len1 = LEN(m.chg1)
    m.len2 = LEN(m.chg2)
    m.pos1 = m.len1
    m.pos2 = m.len2
    DO WHILE m.pos1 > 0 AND m.pos2 > 0
        IF SUBSTR(m.chg1, m.pos1, 1) != SUBSTR(m.chg2, m.pos2, 1)
             EXIT
        ENDIF
        m.pos1 = m.pos1 - 1
        m.pos2 = m.pos2 - 1
    ENDDO
	m.chg1 = IIF(m.pos1 > 0, LEFT(m.chg1, pos1), "")
	m.chg2 = IIF(m.pos2 > 0, LEFT(m.chg2, pos2), "")
    return
endfunc
    
*--------------------------------------------------------------------------
* Prozedur:   EqualWords
* Parameter:  str1   - Referenz auf einen String
*             str2   - Referenz auf einen String
* Rueckgabe:  Wörter die in beiden Vergleichstrings vorkommen (Häufigkeiten
*             werden brücksichtigt). In den Referenzen werden die
*             ungleichen Wörter abgelegt.
*--------------------------------------------------------------------------
FUNCTION EuqalWords(str1 as String, str2 as String)
LOCAL num1, num2, lex1, lex2, equ 
	m.equ = ""
	m.num1 = 1
	m.lex1 = Lexem((m.str1), m.num1)
	DO WHILE !EMPTY(m.lex1)
		m.num2 = 1
		m.lex2 = Lexem((m.str2), m.num2)
		DO WHILE !EMPTY(m.lex2)
			IF m.lex1 == m.lex2
				m.equ = m.equ + m.lex1 + " "
				= Lexem(@m.str1, m.num1)
				= Lexem(@m.str2, m.num2)				
				m.num1 = m.num1 - 1
				EXIT
			ELSE
				m.num2 = m.num2+1
	    		m.lex2 = Lexem((m.str2), m.num2)
			ENDIF
		ENDDO
		m.num1 = m.num1+1		
   		m.lex1 = Lexem((m.str1), m.num1)
	ENDDO
	RETURN RTRIM(m.equ)
endfunc

*--------------------------------------------------------------------------
* Prozedur:   NoStar
* Parameter:  str - String
* Aufgabe:    Loeschen aller mit Sternchen geklammerten Kommentare
*--------------------------------------------------------------------------
FUNCTION NoStar(str as String)
LOCAL pos1, pos2
    m.pos1 = AT("*", m.str)
    m.pos2 = RAT("*", m.str)
    IF m.pos2 > m.pos1
        m.str = STUFF(m.str, m.pos1, m.pos2-m.pos1+1, "")
    ENDIF
    RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   BlankInversePattern
* Parameter:  str  - String
*             pat  - Muster mit erlaubten Zeichen
* Rueckgabe:  <str>, wobei alle Zeichen, die nicht in <pat> enthalten
*             sind, durch Leerzeichen ersetzt wurden.
*--------------------------------------------------------------------------
FUNCTION BlankInversePattern(str as String, pat as String)
LOCAL pos, strlen
    m.pos = 1
    m.strlen = LEN(m.str)
    DO WHILE m.pos <= m.strlen
        IF NOT SUBSTR(m.str, m.pos, 1) $ m.pat
            m.str = STUFF(m.str, m.pos, 1, " ")
        ENDIF
        m.pos = m.pos + 1
    ENDDO
	RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   BlankPattern
* Parameter:  str  - String
*             pat  - Muster mit erlaubten Zeichen
* Rueckgabe:  <str>, wobei alle Zeichen, die <pat> enthalten
*             sind, durch Leerzeichen ersetzt wurden.
*--------------------------------------------------------------------------
FUNCTION BlankPattern(str as String, pat as String)
LOCAL len, i
	m.len = len(m.pat)
    for m.i = 1 to m.len
		m.str = strtran(m.str,substr(m.pat,m.i,1)," ")
	endfor
	return m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   FilterPattern
* Parameter:  str  - String
*             pat  - Muster mit erlaubten Zeichen
* Rueckgabe:  <str>, wobei alle Zeichen die nicht in <pat> enthalten
*             sind entfernt wurden.
*--------------------------------------------------------------------------
FUNCTION FilterPattern(str as String, pat as String)
LOCAL pos, strlen
    m.pos = 1
    m.strlen = LEN(m.str)
    DO WHILE m.pos <= m.strlen
        IF AT(SUBSTR(m.str, m.pos, 1), m.pat) = 0
            m.str = STUFF(m.str, m.pos, 1, "")
            m.strlen = strlen - 1
        ELSE
            m.pos = m.pos + 1
        ENDIF
    ENDDO
	RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   DeletePattern
* Parameter:  str  - String
*             pat  - Muster mit ungueltigen Zeichen
* Rueckgabe:  <str>, wobei alle Zeichen die in <pat> enthalten
*             sind entfernt wurden.
*--------------------------------------------------------------------------
FUNCTION DeletePattern(str as String, pat as String)
LOCAL pos, strlen
    m.pos = 1
    m.strlen = LEN(m.str)
    DO WHILE m.pos <= m.strlen
        IF AT(SUBSTR(m.str, m.pos, 1), m.pat) > 0
            m.str = STUFF(m.str, m.pos, 1, "")
            m.strlen = m.strlen - 1
        ELSE
            m.pos = m.pos + 1
        ENDIF
    ENDDO
	RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   FirstPattern
* Parameter:  str   - String
*             pat   - Muster mit gesuchten Zeichen
*             start - Startposition (optional)
* Rueckgabe:  Position im String des ersten Auftrettens eines Zeichens
*             aus dem Suchmuster ab der Startposition nach rechts. 
*--------------------------------------------------------------------------
FUNCTION FirstPattern(str as String, pat as String, start as Integer)
LOCAL pos, strlen
	IF PARAMETERS() < 3
		m.start = 1
	ELSE		
		IF m.start < 1 
			RETURN 0
		ENDIF		
	ENDIF		
    m.strlen = LEN(m.str)
    FOR m.pos = m.start to m.strlen
        IF AT(SUBSTR(m.str, m.pos, 1), m.pat) != 0
            RETURN m.pos
        ENDIF
    ENDFOR
	RETURN 0
endfunc

*--------------------------------------------------------------------------
* Funktion:   LastPattern
* Parameter:  str  - String
*             pat  - Muster mit gesuchten Zeichen
*             start - Startposition (optional)
* Rueckgabe:  Position in String des ersten Auftrettens eines Zeichens
*             aus dem Suchmuster ab der Startposition nach links.
*--------------------------------------------------------------------------
FUNCTION LastPattern(str as String, pat as String, start as Integer)
LOCAL pos, m.strlen
    m.strlen = LEN(m.str)
	IF PARAMETERS() < 3
		m.start = m.strlen
	ELSE		
		IF m.start < 1 
			RETURN 0
		ENDIF		
	ENDIF		
	FOR m.pos = m.start TO 1 STEP -1
        IF AT(SUBSTR(m.str, m.pos, 1), m.pat) <> 0
            RETURN m.pos
        ENDIF
    ENDFOR
	RETURN 0
endfunc

*--------------------------------------------------------------------------
* Funktion:   RightPattern
* Parameter:  str   - String
*             pat   - Muster mit gesuchten Zeichen
*             start - Startposition (optional)
* Rueckgabe:  Position in String des zuletzt im Muster enthaltenen
*             Zeichens. Der String wird also bis zum ersten nicht im 
*             Muster enthaltenen Zeichen durchsucht. Die Suche verläuft
*             von links nach rechts ab der Startposition.
*--------------------------------------------------------------------------
FUNCTION RightPattern(str as String, pat as String, start as Integer)
LOCAL pos, strlen
    m.strlen = LEN(m.str)
	IF PARAMETERS() < 3
		m.start = 1
	ELSE
		IF m.start < 1 OR m.start > m.strlen
	    	RETURN 0
		ENDIF    	
	ENDIF		
    FOR m.pos = m.start TO m.strlen
        IF AT(SUBSTR(m.str, m.pos, 1), m.pat) = 0
            RETURN iif(m.pos = m.start,0,m.pos-1)
        ENDIF
    ENDFOR
	RETURN m.strlen
endfunc

*--------------------------------------------------------------------------
* Funktion:   LeftPattern
* Parameter:  str   - String
*             pat   - Muster mit gesuchten Zeichen
*             start - Startposition (optional)
* Rueckgabe:  Position in String des zuletzt im Muster enthaltenen
*             Zeichens. Der String wird also bis zum ersten nicht im 
*             Muster enthaltenen Zeichen durchsucht. Die Suche verläuft
*             von rechts nach links ab der Startposition.
*--------------------------------------------------------------------------
FUNCTION LeftPattern(str as String, pat as String, start as Integer)
LOCAL pos, strlen
    m.strlen = LEN(m.str)
	IF PARAMETERS() < 3
		m.start = m.strlen
	ELSE
		IF m.start < 1 OR m.start > m.strlen
			RETURN 0
		ENDIF		
	ENDIF	
    FOR m.pos = m.start TO 1 STEP -1
        IF AT(SUBSTR(m.str, m.pos, 1), m.pat) = 0
            RETURN iif(m.pos = m.start,0,m.pos+1)          
        ENDIF
    ENDFOR
	RETURN 1
endfunc

*--------------------------------------------------------------------------
* Funktion:   Lexem
* Parameter:  str  - String
*             num  - Nummer des Lexems
*             sep  - Separator
* Rueckgabe:  Lexem (Wort) mit der angegebenen Nummer aus dem durch
*             Separatoren getrennten String (Default ist Blank).
*             Das Lexem wird as dem String entfernt, wenn der String als 
*             Referenz (@stringname) übergeben wird.
*--------------------------------------------------------------------------
FUNCTION Lexem(str as String, num as Integer, sep as String)
LOCAL start, end, typ, len, beg, lex
	m.typ = TYPE("m.sep")
	IF TYPE("m.sep") != "C"
		m.sep = " "				
	ENDIF		
    IF m.num = 1
        m.start = 1
    ELSE
        m.start = AT(m.sep, m.str, m.num - 1) + 1
        IF m.start = 1
            RETURN ""
        ENDIF
    ENDIF
    m.end = AT(m.sep, m.str, m.num)
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
   	m.str = STUFF(m.str, m.beg, m.len+1,"")
   	RETURN m.lex
endfunc

*--------------------------------------------------------------------------
* Funktion:   cutstr
* Parameter:  str   - String
*             start - Startposition im String
*             ende  - Endeposition im String
* Rueckgabe:  Stringsegment von der Startposition bis zur Endposition.
*             Wird der String als Referenz übergeben, wird das Segment
*             aus dem String entfernt. Die Funktion ist fehlertolerant
*             und gibt einen Leerstring zurück, wenn die Positionsangaben
*             Stringgrenzen verletzen.
*--------------------------------------------------------------------------
FUNCTION cutstr(str as String, start as Integer, ende as Integer)
LOCAL cut, len
	IF PARAMETERS() < 3
		m.ende = LEN(m.str)
	ENDIF		
	m.len = m.ende-m.start+1
	m.cut = RIGHT(LEFT(m.str,m.ende),m.len)
	m.str = STUFF(m.str,m.start,m.len,"")
	RETURN m.cut	
endfunc	
	
*--------------------------------------------------------------------------
* Funktion:   righttran
* Parameter:  str   - String
*             from  - zu ersetzende Stringkomponente
*             to    - Ersatzstring
* Rueckgabe:  String bei dem alle from-Komponenten in to-Komponenten
*             ersetzt wurden. Dabei werden nur Komponenten ausgetauscht, 
*             an die sich rechts kein Zeichen anschliesst.
*--------------------------------------------------------------------------
FUNCTION righttran(str as String, from as String, to as String)
LOCAL i, pos, end, len, strlen, inc
	IF m.from $ m.to
		m.inc = 1
	ELSE
		m.inc = 0
	ENDIF
	m.len = LEN(m.from)
	m.strlen = LEN(m.str)
	m.i = 1
	m.pos = AT(m.from,m.str,m.i)
	DO WHILE m.pos > 0
		m.end = m.pos+m.len
		IF m.end > m.strlen OR EMPTY(substr(m.str,m.end,1))
			m.str = STUFF(m.str,m.pos,m.len,m.to)
			m.strlen = LEN(m.str)
			m.i = m.i + m.inc
		ELSE
			m.i = m.i + 1
		ENDIF
		m.pos = AT(m.from,m.str,m.i)
	ENDDO
	RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   lefttran
* Parameter:  str   - String
*             from  - zu ersetzende Stringkomponente
*             to    - Ersatzstring
* Rueckgabe:  String bei dem alle from-Komponenten in to-Komponenten
*             ersetzt wurden. Dabei werden nur Komponenten ausgetauscht, 
*             an die sich links kein Zeichen anschliesst.
*--------------------------------------------------------------------------
FUNCTION lefttran(str as String, from as String, to as String)
LOCAL i, pos, len, strlen, inc
	IF m.from $ m.to
		m.inc = 1
	ELSE
		m.inc = 0
	ENDIF
	m.len = LEN(m.from)
	m.i = 1
	m.pos = AT(m.from,m.str,m.i)
	DO WHILE m.pos > 0
		IF m.pos == 1 OR EMPTY(substr(m.str,m.pos-1,1))
			m.str = STUFF(m.str,m.pos,m.len,m.to)
			m.strlen = LEN(m.str)
			m.i = m.i + m.inc
		ELSE
			m.i = m.i + 1
		ENDIF
		m.pos = AT(m.from,m.str,m.i)
	ENDDO
	RETURN m.str	
endfunc
		
*--------------------------------------------------------------------------
* Funktion:   alltran
* Parameter:  str   - String
*             from  - zu ersetzende Stringkomponente
*             to    - Ersatzstring
* Rueckgabe:  String bei dem alle from-Komponenten in to-Komponenten
*             ersetzt wurden. Dabei werden nur Komponenten ausgetauscht, 
*             an die ohne angrenzende Zeichen sind.
*--------------------------------------------------------------------------
FUNCTION alltran(str as String, from as String, to as String)
LOCAL i, pos, end, len, strlen, inc
	IF m.from $ m.to
		m.inc = 1
	ELSE
		m.inc = 0
	ENDIF
	m.len = LEN(m.from)
	m.strlen = LEN(m.str)
	m.i = 1
	m.pos = AT(m.from,m.str,m.i)
	DO WHILE m.pos > 0
		m.end = m.pos+m.len
		IF (m.pos == 1 OR EMPTY(substr(m.str,m.pos-1,1))) AND;
		   (m.end > m.strlen OR EMPTY(substr(m.str,m.end,1)))
			m.str = STUFF(m.str,m.pos,m.len,m.to)
			m.strlen = LEN(m.str)
			m.i = m.i + m.inc
		ELSE
			m.i = m.i + 1
		ENDIF
		m.pos = AT(m.from,m.str,m.i)
	ENDDO
	RETURN m.str
endfunc
	
*--------------------------------------------------------------------------
* Funktion:   umltran
* Parameter:  str   - String
* Rueckgabe:  String bei dem alle Umlaute durch entsprechende Phoneme 
*             ersetzt wurden.
*--------------------------------------------------------------------------
FUNCTION umltran(str as String)
    m.str = STRTRAN(m.str, "Ä", "Ae")
    m.str = STRTRAN(m.str, "Ö", "Oe")
    m.str = STRTRAN(m.str, "Ü", "Ue")
    m.str = STRTRAN(m.str, "ß", "ss")
    m.str = STRTRAN(m.str, "ä", "ae")
    m.str = STRTRAN(m.str, "ö", "oe")
    m.str = STRTRAN(m.str, "ü", "ue")
	RETURN m.str
endfunc

*--------------------------------------------------------------------------
* Funktion:   num2str
* Parameter:  num   - Numerischer Wert oder Waehrung
* Rueckgabe:  String des Zahlenwertes
*--------------------------------------------------------------------------
function num2str(num as Double)
local str, pos, start, i, chr
	m.str = ltrim(str(m.num,36,18))
	m.pos = at(".",m.str)
	m.start = rat("E",m.str)
	if m.start > 0
		m.start = m.start - 1
	else
		m.start = len(m.str)
	endif
	for m.i = m.start to m.pos step -1
		m.chr = substr(m.str,m.i,1)	
		if not m.chr == "0"
			if m.chr == "."
				m.i = m.i-1
			endif
			exit
		endif
	endfor
	return left(m.str,m.i)+right(m.str,len(m.str)-m.start)
endfunc

*--------------------------------------------------------------------------
* Funktion:   variants
* Parameter:  str    - String mit zusammengesetzten Woertern (z.B.: BioTec)
*                      oder durch Bindestrich getrennten Woertern
*             [start]- Startposition im String (wird nur für die 
*                      Rekursion benötigt und sollte nicht
*                      angegeben werden)
* Rueckgabe:  collection mit allen potentiellen Varianten des Strings
*             So wird z.B. aus "Pharma-Chem BioTec" folgende Collection:
*             PharmaChem BioTec
*             Pharma-Chem Bio Tec
*             PharmaChem Bio Tec
*--------------------------------------------------------------------------
function variants(str as String, start as Integer)
	local col, prev, act, next, rest
	m.col = createobject("Collection")
	if not vartype(m.start) == "N"
		m.start = -1
	endif
	m.prev = substr(m.str, m.start, 1)
	m.start = m.start+1
	m.act = substr(m.str, m.start, 1)
	m.next = substr(m.str, m.start+1,1)
	do while .t.
		if m.start > len(m.str)
			return m.col
		endif
		if isupper(m.act) and islower(m.prev) and not empty(m.next)
			m.col.add(substr(m.str,1,m.start-1)+" "+substr(m.str,m.start))
			m.next = m.start+1
			exit
		endif
		if m.act == "-" and isalpha(m.prev) and isalpha(next)
			m.col.add(substr(m.str,1,m.start-1)+substr(m.str,m.start+1))
			m.next = m.start
			m.start = m.start+1
			exit
		endif
		m.prev = m.act
		m.act = m.next
		m.start = m.start+1
		m.next = substr(m.str, m.start+1, 1)
	enddo		
	m.rest = variants(@m.str,m.start)
	for m.act = 1 to m.rest.count
		m.col.add(m.rest.item(m.act))
	endfor
	m.str = m.col.item(1)
	m.rest = variants(@m.str,m.next)
	for m.act = 1 to m.rest.count
		m.col.add(m.rest.item(m.act))
	endfor
	return m.col
endfunc

*--------------------------------------------------------------------------
* Funktion:   separateHiTec
* Parameter:  str   - Strng mit zusammengesetzten Woertern (z.B.: HiTec)
* Rueckgabe:  Getrennte Schreibweise fuer alle zusammengesetzten Woerter
*--------------------------------------------------------------------------
function separateHiTec(str)
local len, newstr, next, act, i, prev
	m.len = len(m.str)
	m.newstr = ""
	m.next = substr(m.str,1,1)
	m.act = ""
	for m.i = 1 to m.len
		m.prev = m.act
		m.act = m.next
		m.next = substr(m.str,m.i+1,1)
		if isupper(m.act) and islower(m.prev) and not empty(m.next)
			m.newstr = m.newstr+" "+m.act
		else	
			m.newstr = m.newstr+m.act
		endif
	endfor
	return m.newstr
endfunc

*--------------------------------------------------------------------------
* Funktion:   hexcode
* Parameter:  str   - String mit hexdecimal maskiertem unicode
* Rueckgabe:  String mit Unicode-Sonderzeichen
*--------------------------------------------------------------------------
function hexcode(str as String)
local newstr, end, start, ind, chr, hex1, hex2
	m.str = nvl(m.str,"")
	m.newstr = ""
	m.ind = 1
	m.start = 1
	m.end = at("%", m.str, m.ind)
	do while m.end > 0
		m.hex1 = asc(upper(substr(m.str,m.end+1,1)))
		m.hex2 = asc(upper(substr(m.str,m.end+2,1)))
		m.hex1 = icase(m.hex1 >= 48 and m.hex1 <= 57,m.hex1-48,m.hex1 >= 65 and m.hex1 <= 70,m.hex1-55,-1)
		m.hex2 = icase(m.hex2 >= 48 and m.hex2 <= 57,m.hex2-48,m.hex2 >= 65 and m.hex2 <= 70,m.hex2-55,-1)
		if m.hex1 >= 0 and m.hex2 >= 0
			m.chr = 16*m.hex1+m.hex2
			m.newstr = m.newstr+substr(m.str,m.start,m.end-m.start)+chr(m.chr)
			m.start = m.end+3
		else
			m.newstr = m.newstr+substr(m.str,m.start,m.end-m.start+1)
			m.start = m.end+1
		endif
		m.ind = m.ind+1
		m.end = at("%", m.str, m.ind)
	enddo
	return m.newstr+substr(m.str,m.start)
endfunc

*--------------------------------------------------------------------------
* Funktion:   xcompare
* Parameter:  a      - Vergleichsstring
*             b      - Vergleichsstring
* Rueckgabe:  Heuristischer Wert zwischen 1 (gleich) und 0 (ungleich) für
*             die Gleichheit der Strings. Der Wert wird über die relative
*             Entfernung passender Zeichen zwischen beiden Strings
*             ermittelt. Es handelt sich um die langsamere Umsetzung der
*             compare-Funktion aus der Library foxpro.fll, welche mit
*             "set library" verknuepft wird.
*--------------------------------------------------------------------------
function xcompare(a as String, b as String)
local i, swap, amax, bmax, score, achr, apos
local num, min, pos, dif, alen
	if len(m.a) < len(m.b)
		m.swap = m.b
		m.b = m.a
		m.a = m.swap
	endif
	m.alen = len(m.a)
	if m.alen == 0 
		return 0
	endif
	m.amax = max(m.alen-1,1)
	m.bmax = max(len(m.b)-1,1)
	m.score = 0
	for m.i = 1 to m.alen
		m.achr = substr(m.a,m.i,1)
		m.apos = (m.i-1)/m.amax
		m.num = 1
		m.min = 2
		m.pos = at(m.achr, m.b)
		do while m.pos > 0
			m.dif = abs(m.apos - (m.pos-1)/m.bmax)
			if m.dif == 0
				m.min = 0
				exit
			endif
			if m.dif >= m.min
				exit
			endif
			m.min = m.dif
			m.num = m.num+1
			m.pos = at(m.achr, m.b, m.num)
		enddo
		m.score = m.score+min(m.min,1)
	endfor
	return 1-m.score/m.alen
endfunc

*--------------------------------------------------------------------------
* Funktion:   comparePhrase
* Parameter:  a         - Vergleichsstring
*             b         - Vergleichsstring
*             [scope]   - maximaler Vergleichsbereich (default = 12)
*             [dynamic] - dynamische Vergleichsrichtung
* Rueckgabe:  Heuristischer Wert zwischen 1 (gleich) und 0 (ungleich) für
*             die Gleichheit der Strings. Der Abgleich findet auf Wortebene
*             statt wobei die Position der Woerter keine Rolle spielt. Es
*             wird fuer jedes Wort nach dem besten Treffer mittels 
*             der compare-Funktion gesucht, welche in der Library
*             foxpro.fll definiert ist. Diese muss dazu mit 
*             "set library" geöffnet werden. Standardmäßig wird die Phrase
*             a mit der Phrase b verglichen. Ist dynamic .t., wird die
*             laengere mit der kuerzeren Phrase verglichen. Mit dem scope
*             Parameter kann die maximale Vergleichsreichweite angegeben
*             werden. Je größer diese ist umso ähnlicher werden lange
*             Zeichenketten. In der Regel liefert der Standardwert 12 
*             die am besten nachvollziehbaren Resultate.
*--------------------------------------------------------------------------
function comparePhrase(a as String, b as String, scope as Integer, dynamic as Boolean)
local al, ac, ai, aw, bl, bc, bi, bw
local sum, score, alen, blen, len, comp
	dimension m.al[1]
	dimension m.bl[1]
	if vartype(m.scope) == "L"
		if m.scope == .t.
			m.dynamic = .t.
		endif
	endif
	if not vartype(m.scope) == "N" or m.scope <= 0
		m.scope = 12
	endif
	m.alen = len(strtran(m.a," ",""))
	if m.dynamic == .f.
		m.blen = -1
	else
		m.blen = len(strtran(m.b," ",""))
	endif
	if m.alen > m.blen
		m.ac = alines(m.al,m.a,5," ")
		m.bc = alines(m.bl,m.b,5," ")
	else
		m.ac = alines(m.al,m.b,5," ")
		m.bc = alines(m.bl,m.a,5," ")
		m.alen = m.blen
	endif
	m.sum = 0
	for m.ai = 1 to m.ac
		m.aw = m.al[m.ai]
		m.len = len(m.aw)
		m.score = 0
		for m.bi = 1 to m.bc
			m.bw = m.bl[m.bi]
			m.comp = 0.5
			m.comp = compare(m.aw,m.bw,m.scope)
			if m.comp > m.score
				m.score = m.comp
				if m.score == 1
					exit
				endif
			endif
		endfor
		m.sum = m.sum+m.score*m.len
	endfor
	if m.alen <= 0
		if m.bc == 0
			return 1
		endif
		return 0
	endif
	return m.sum/m.alen
endfunc	

*--------------------------------------------------------------------------
* Funktion:   parentdir
* Parameter:  path - Pfadangabe als String
* Rueckgabe:  Übergeordneter Pfad als String. Achtung: es handelt sich nur
*             um eine String-Funktion und keine echte Pfadtraversierung.
*             Gibt es keinen übergordneten Pfad wird der unveränderte
*             Pfadparameter zurückgegeben.
*--------------------------------------------------------------------------
function parentdir(path as String)
local parent, pos
	m.parent = strtran(alltrim(m.path),"/","\")
	do while right(m.parent,1) == "\"
		m.parent = left(m.parent,len(m.parent)-1)
	enddo
	m.pos = rat("\",m.parent)
	if m.pos == 0
		return m.path
	endif
	return left(m.parent,m.pos)
endfunc

*--------------------------------------------------------------------------
* Funktion:   reverse
* Parameter:  str - String
* Rueckgabe:  String in umgedrehter Reihenfolge 
*--------------------------------------------------------------------------
function reverse(str as String)
local newstr, len, i
	m.newstr = ""
	m.len = len(m.str)
	for m.i = m.len to 1 step -1
		m.newstr = m.newstr+substr(m.str,m.i,1)
	endfor
	return m.newstr
endfunc

*--------------------------------------------------------------------------
* Funktion:   reverselist
* Parameter:  str    - String
*             sep    - Separator (Character)
* Rueckgabe:  Dreht die Reihenfolge einer separierten Liste um.
*--------------------------------------------------------------------------
function reverselist(str as String, sep as String)
local rev, cnt, reverse, i
	dimension rev[1]
	m.cnt = alines(m.rev, m.str, m.sep)
	m.reverse = ""
	for m.i = m.cnt to 1 step -1
		m.reverse = m.reverse+m.sep+m.rev[m.i]
	endfor
	return substr(m.reverse,len(m.sep)+1)
endfunc

*--------------------------------------------------------------------------
* Funktion:   memokey
* Parameter:  str    - String
*			  keylen - maximale Laenge des Schluessels
* Rueckgabe:  String in einer zum indizieren geeigneten Form
*--------------------------------------------------------------------------
function memokey(str as String, m.keylen as Integer)
local memokey, len, half, partlen, rest
	m.len = len(m.str)
	if m.len <= m.keylen
		m.keylen = m.len
	endif
	m.partlen = int(m.keylen/6)
	m.rest = m.keylen-6*m.partlen
	m.half = m.partlen+int((m.len-m.rest-m.partlen-m.partlen)/2)+1
	m.memokey = reverse(right(m.str,m.partlen*2+m.rest))
	m.memokey = m.memokey+reverse(substr(m.str,m.half,m.partlen))
	m.memokey = m.memokey+substr(m.str,m.half-m.partlen,m.partlen)
	m.memokey = m.memokey+substr(m.str,1,m.partlen*2)
	return m.memokey
endfunc

*--------------------------------------------------------------------------
* Funktion:   buildExec
* Parameter:  sql    - String
* Rueckgabe:  Mit Macroaufruf "&" ausfuehrbares Script. Variablennamen im
*             Parameter sql, die in geschweiften Klammern stehen (z.B.:
*             {m.table.alias}) werden entsprechen substituiert, so dass
*             insbesonders die SQL-Kommandos "Update" und "Delete" mit
*             der BaseTable- bzw. UniqueAlias-Klasse leichter definiert
*             werden koennen.
* Beispiel:   m.sql = buildExec("update {m.base.alias) set 
*                     {m.base.alias}.group = {m.upd.alias}.unikey from
*                     {m.upd.alias} where {m.upd.alias}.basekey == 
*                     {m.base.alias}.id"}
*             &sql
*--------------------------------------------------------------------------
function buildExec(sql as String)
local col, str, cnt, i, key, lex
	m.col = createobject("Collection")
	m.sql = strtran(m.sql,'"',"'")
	m.str = ""
	dimension m.lex[1]
	m.cnt = alines(m.lex, m.sql, 16, "{","}")
	for m.i = 1 to m.cnt
		if right(m.lex[m.i],1) == "}"
			m.key = lower(alltrim(left(m.lex[m.i],len(m.lex[m.i])-1)))
			m.str = m.str+m.key+"}"
			if not empty(m.key) and m.col.getKey(m.key) < 1
				m.col.add(m.key,m.key)
			endif
		else
			m.str = m.str+m.lex[m.i]
		endif
	endfor
	if m.col.count == 0
		return m.str
	endif
	m.sql = 'strtran("'+m.str+'","{'+m.col.item(1)+'}",'+m.col.item(1)+')'
	for m.i = 2 to m.col.count
		m.sql = 'strtran('+m.sql+',"{'+m.col.item(m.i)+'}",'+m.col.item(m.i)+')'
	endfor
	return 'execscript('+m.sql+')'
endfunc
