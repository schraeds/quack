<!-- #include file="ioelmsrv.vbscript.asp" -->
<!-- #include file="ioelmsrv.soda.vbscript.asp" -->

<%

Dim dbfile
dbfile = "datasource.db"
'# DB Format: 
'# fname<col/>lname<col/>street<col/>country<col/>zip<col/>state<col/>phone<col/>email<col/>hobby<col/>otherhobby<col/>haircolor<col/>eyecolor<col/>sport<col/>comment<row/>

Call wsSetName("DataSource Web Service")
Call wsSetComment("For use with DynAPI DataSource Object")

wsAddMethod "addrow",null,"object"
wsAddMethod "deleterow",Array("row:integer:0"),"object"
wsAddMethod "movefirst",null,"object"
wsAddMethod "movenext",Array("row:integer:0"),"object"
wsAddMethod "moveprev",Array("row:integer:0"),"object"
wsAddMethod "movelast",null,"object"
wsAddMethod "moveto",Array("row:integer:0"),"object"
wsAddMethod "submitrow",Array("row:integer","data:object"),"boolean"

Call wsEnableOnlineHelp(true)

Call wsDispatch()

'# Public Method -----------------------------------------

' Add Row
Function addrow()
	Dim db,row,cols(14)
	db=openDB(dbfile)
	For i=0 to 14
		If i=14 Then 
			cols(i)="images/pixel.gif" 
		Else 
			cols(i)=""
		End If
	Next 
	row=UBound(db)+1
	Set addrow = buildRowObject(cols,row,UBound(db)+1)
End Function

' Delete Row
Function deleterow(Byval row)
	Dim db,newdb()
	db=openDB(dbfile)
	ReDim newdb(UBound(db)-1)
	For i=0 to UBound(db)
		If i<row Then 
			newdb(i)=db(i)
		ElseIf i>row Then 
			newdb(i-1)=db(i)
		End If
	Next 
	Call saveDB(dbfile,newdb)
	totalRows=UBound(newdb)
	If (row>totalRows) Then row=totalRows
	Set deleterow = buildRowObject(newdb(row),row,totalRows+1)
End Function

' Move First
Function movefirst()
	Dim db
	db=openDB(dbfile)
	Set movefirst = buildRowObject(db(0),0,UBound(db)+1)
End Function

' Move Last
Function movelast()
	Dim db,row
	db=openDB(dbfile)
	row=UBound(db)
	Set movelast = buildRowObject(db(row),row,UBound(db)+1)
End Function

' Move Next
Function movenext(Byval Row)
	Dim db
	db=openDB(dbfile)
	row=row+1
	If row>UBound(db) Then row=UBound(db)
	Set movenext = buildRowObject(db(row),row,UBound(db)+1)
End Function

' Move Prev
Function moveprev(Byval Row)
	Dim db
	db=openDB(dbfile)
	row=row-1
	If row<0 Then row=0
	Set moveprev = buildRowObject(db(row),row,UBound(db)+1)
End Function

' Move To
Function moveto(ByVal row)
	Dim db
	db=openDB(dbfile)
	Set moveto = buildRowObject(db(row),row,UBound(db)+1)
End Function

' Submit Row
Function submitrow(ByVal row,ByVal data)
	Dim db,cols,totalRows
	db=openDB(dbfile)
	totalRows=ubound(db)
	If row>totalRows Then
		totalRows = totalRows+1
		ReDim Preserve db(totalRows)
		cols=Array()
		ReDim cols(14)
		db(totalRows)=cols
		row=totalRows		
	End If
	cols=db(row)
		cols(0)=data.item("fname") &""
		cols(1)=data.item("lname") &""
		cols(2)=data.item("street") &""
		cols(3)=data.item("country") &""
		cols(4)=data.item("zip") &""
		cols(5)=data.item("state") &""
		cols(6)=data.item("phone") &""
		cols(7)=data.item("email") &""
		cols(8)=data.item("hobby") &""
		cols(9)=data.item("otherhobby") &""
		cols(10)=data.item("haircolor") &""
		cols(11)=data.item("eyecolor") &""
		cols(12)=data.item("sport") &""
		cols(13)=data.item("comment") &""
		cols(14)=data.item("icon") &""
	db(row)=cols	
	submitrow=saveDB(dbfile,db) 
End Function


'# Private Method -----------------------------------------

' Build Row Object
Function buildRowObject(cols,row,rowCount)
	Dim o
	Set o = CreateObject("Scripting.Dictionary")
	o.add "dataRowIndex",row
	o.add "dataRowCount",rowCount
	o.add "fname",cols(0)
	o.add "lname",cols(1)
	o.add "street",cols(2)
	o.add "country",cols(3)
	o.add "zip",cols(4)
	o.add "state",cols(5)
	o.add "phone",cols(6)
	o.add "email",cols(7)
	o.add "hobby",cols(8)
	o.add "otherhobby",cols(9)
	o.add "haircolor",cols(10)
	o.add "eyecolor",cols(11)
	o.add "sport",cols(12)
	o.add "comment",cols(13)
	o.add "icon",cols(14)
	Set buildRowObject = o
End Function

' Open DB
Function openDB(Byval file)
	Dim text
	Dim rows
	text=openFile(dbfile)
	rows=Split(text,"<row/>")
	For i=0 to UBound(rows)
		text=rows(i)
		rows(i)=Split(text,"<col/>")
	Next
	openDB=rows
End Function

' Open file
Function openFile (Byval file) 
	Dim forReading
	Dim fso,tStream	
	forReading=1
	file=Server.MapPath(file)
	Set fso=Server.CreateObject("Scripting.FileSystemObject")
	Set tStream = fso.OpenTextFile(file, forReading)
	openFile = tStream.ReadAll()
End Function

' Save DB
Function saveDB(Byval file,db)
	Dim text, cols
	text=""
	For i=0 to UBound(db)
		If(i>0) Then text=text+"<row/>"
		cols=db(i)
		text=text + Join(cols,"<col/>")
	Next
	saveDB = saveFile(file,text) 
End Function

' Save file
Function saveFile(Byval file,Byval content) 
	Dim forWriting
	Dim fso,tStream	
	forWriting=2
	file=Server.MapPath(file)
	Set fso=Server.CreateObject("Scripting.FileSystemObject")
	Set tStream=fso.OpenTextFile(file, forWriting,true)
	Call tStream.Write(content)
	Call tStream.Close()
	saveFile=content
End Function

%>