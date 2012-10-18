<!-- #include file="ioelmsrv.vbscript.asp" -->
<!-- #include file="ioelmsrv.soda.vbscript.asp" -->

<%

Dim dbfile
dbfile = "datasource-paging.db"
'# DB Format: 
'# id,fname,lname,color\n

Call wsSetName("DataSource with Paging Support")
Call wsSetComment("For use with DynAPI DataSource Object")

wsAddMethod "addrow",null,"object"
wsAddMethod "deleterow",Array("row:integer:0"),"object"
wsAddMethod "fetchpage",Array("page:integer:1","size:integer:1","type:string:""normal"""),"object"
wsAddMethod "movefirst",null,"object"
wsAddMethod "movenext",Array("row:integer:0"),"object"
wsAddMethod "moveprev",Array("row:integer:0"),"object"
wsAddMethod "movelast",null,"object"
wsAddMethod "moveto",Array("row:integer:0"),"object"
wsAddMethod "submitrow",Array("row:integer","data:object"),"boolean"

wsAddDescription "addrow","Add a row to the database"
wsAddDescription "deleterow","Remove a row from the database"
wsAddDescription "deleterow:row","selected row to be deleted"
wsAddDescription "fetchpage","fetchs an array of rows from the database"
wsAddDescription "fetchpage:page","Selected page"
wsAddDescription "fetchpage:size","Page Size"

Call wsEnableOnlineHelp(true)

Call wsDispatch()


'# Public Methods ------------------------------------

' Add Row
Function addrow()
	Dim db,row,cols(3)
	db=openDB(dbfile)
	For i=0 to 2
		cols(i)=""
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

' Fetch Page
Function fetchpage(Byval pageNumber, ByVal pageSize, ByVal pageType)
	Dim i,cnt,page,rows()
	Dim id,fname,lname,color
	Dim db,rowStart,rowEnd
	
	'open db
	db=openDB(dbfile)
	
	' get page number
	If pageType="lastpage" Then pageNumber=Fix(UBound(db)/pageSize)+1
	If pageType="firstpage" Or pageNumber<1 Then pageNumber=1
	
	' get row start and end 
	rowStart=(pageNumber-1)*pageSize 
	rowEnd=rowStart+(pageSize-1)	
	If rowEnd>UBound(db) Then rowEnd = UBound(db)
	
	ReDim rows(rowEnd-rowStart)	

	' add rows to array
	cnt=0	
	For i = rowStart to rowEnd
		id=db(i)(0)
		fname=db(i)(1)
		lname=db(i)(2)
		color=db(i)(3)
		rows(cnt) = Array(id,fname,lname,color)
		cnt=cnt+1
	Next

	'Call wsRaiseError(null,"Row End :"& rowEnd)

	' return object to client
	Set page = CreateObject("Scripting.Dictionary")
	page.add "dataRowIndex",rowStart
	page.add "dataRowCount",UBound(db)+1
	page.add "fieldnames",Array("id","fname","lname","color")
	page.add "fieldvalues",rows
	
	Set fetchpage = page
	
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
	Set moveto = buildRowObject(db(row),row,totalRows+1)
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
		ReDim cols(3)
		db(totalRows)=cols
		row=totalRows		
	End If
	cols=db(row)
		cols(0)=data.item("id") &""
		cols(1)=data.item("fname") &""
		cols(2)=data.item("lname") &""
		cols(3)=data.item("color") &""
	db(row)=cols	
	submitrow=saveDB(dbfile,db) 
End Function



'# Private Methods ------------------------------------


' Build row object
Function buildRowObject(cols,row,rowCount)
	Dim o
	Set o = CreateObject("Scripting.Dictionary")
	If Not IsNull(row) Then o.add "dataRowIndex",row
	If Not IsNull(rowCount) Then o.add "dataRowCount",rowCount
	o.add "id",cols(0)
	o.add "fname",cols(1)
	o.add "lname",cols(2)
	o.add "color",cols(3)
	Set buildRowObject = o
End Function

' Open DB
Function openDB(Byval file)
	Dim text
	Dim rows
	text=openFile(dbfile)
	rows=Split(text,vbCrLf)
	For i=0 to UBound(rows)
		text=rows(i)
		rows(i)=Split(text,",")
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
		If(i>0) Then text=text+vbCrLf
		cols=db(i)
		text=text + Join(cols,",")
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