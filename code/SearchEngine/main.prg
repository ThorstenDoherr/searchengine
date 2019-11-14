parameters script, output, para
public engine, oldengine, engineChanged, mainForm
local path, psl, mess 
_screen.LockScreen = .t.
_screen.top = -5000
_screen.left = -5000
_screen.width = 100
_screen.height = 100
_screen.LockScreen = .f.
try
	erase (sys(2005))
catch
endtry
try
	erase (strtran(sys(2005)+"?",".DBF?",".FPT"))
catch
endtry
m.path = sys(16,0)
m.path = substr(m.path, rat(" ",left(m.path,at("\",m.path)))+1)
m.path = left(m.path, rat("\",m.path))
set procedure to custom, cluster, searchengine, path, sheet
set library to (m.path+"foxpro.fll")
set escape off
set resource off
set talk off
set safety off
set deleted off
set exact on
set near on
set compatible foxplus
set reprocess to 1
set optimize on
set sysformats off
set date ymd
set mark to "."
set century on
set point to
set hours to 24
if vartype(m.script) == "C"
	m.engine = createobject("SearchEngine",m.path)
	if not vartype(m.engine) == "O"
		return
	endif
	_screen.LockScreen = .t.
	_screen.Width = 600
	_screen.Height = 400
	_screen.AutoCenter = .t.
	_screen.FontBold = .f.
	_screen.FontName = "Courier New"
	_screen.FontSize = 9
	_screen.Caption = "SearchEngine "+alltrim(m.script)
	_screen.WindowType = 1
	_screen.LockScreen = .f.
	if not m.engine.run(m.script, m.output, m.para)
		m.mess = m.engine.getMessenger()
		if empty(m.mess.getErrorMessage())
			messagebox("Unknown sript error.",16,_screen.Caption)
		else
			messagebox(m.mess.getErrorMessage(),16,_screen.Caption)
		endif
	endif
	return
endif
do form blinker
m.engine = createobject("SearchEngine",m.path)
if not vartype(m.engine) == "O"
	return
endif
m.engine.writeLog("* ["+m.engine.getVersion()+"]["+strtran(ttoc(datetime(),3),"T"," ")+"]["+m.engine.getSlot()+"]")
m.engine.tag = "NEW"
m.oldengine = m.engine.toString()
m.engineChanged = .F.
do form se name m.mainForm linked
do semenu.mpr with m.mainForm, .T.
read events
release m.mainForm
if m.engineChanged
	if messagebox("Save Settings?",36,"SearchEngine") == 6
		m.engine.execute('save()')
	endif
endif

