lparameters script, para0, para1, para2, para3, para4, para5, para6, para7, para8, para9, para10, para11, para12, para13, para14, para15, para16, para17, para18, para19, para20, para21, para22, para23, para24
public engine, oldengine, engineChanged, mainForm
local path, psl, mess 
_screen.icon = "SearchFox.ico"
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
set procedure to custom, cluster, searchengine, group, sheet
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
	_screen.Width = 550
	_screen.Height = 400
	_screen.AutoCenter = .t.
	_screen.FontBold = .f.
	_screen.FontName = "Courier New"
	_screen.FontSize = 9
	_screen.Caption = "SearchEngine "+alltrim(m.script)
	_screen.ForeColor = 4977945
	_screen.BackColor = 0
	_screen.WindowType = 1
	_screen.LockScreen = .f.
	if not m.engine.run(m.script, m.para0, m.para1, m.para2, m.para3, m.para4, m.para5, m.para6, m.para7, m.para8, m.para9, m.para10, m.para11, m.para12, m.para13, m.para14, m.para15, m.para16, m.para17, m.para18, m.para19, m.para20, m.para21, m.para22, m.para23, m.para24)
		m.mess = m.engine.getMessenger()
		if m.mess.wasCanceled()
			return
		endif
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
m.engine.setLogHeader("* [version: "+version_of_searchengine()+"]["+strtran(ttoc(datetime(),3),"T"," ")+"]["+m.engine.getSlot()+"]")
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

