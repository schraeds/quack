<%

'	IOElement Server Library - For ASP Servers (VBScript)
'	For use with DynAPI IOElement client-side JavaScript
'
'	The DynAPI Distribution is distributed under the terms of the GNU LGPL license.
'
'	Returned Data type: integer, float, string, date, array, object (associative array)
'
'	Raymond Irving <xwisdom (at) yahoo (dot) com>

Dim wso_jsCommands()	'stores javascript commands to be executed on client
Dim wso_vars			'stores javascript variables to be returned to client
Dim wso_endDocWrite		'Prevent ws__docWrite from sending data to client
Dim wso_IOResponse		'Returned Content Format: html (default) or xml
Dim wso_reqMethod		'stores request method - get,post or upload - upload is use by dynapi when unloading files

wso_IOResponse="text/html"

Set wso_vars = Server.CreateObject("Scripting.Dictionary")

'* Add Variables - javascript variables to be sent to client - should only be used when html content is being returned to the client *
Function wsAddVariable(ByVal name,ByVal value)
	If Not IsValid(name) Then Exit Function
	If Not wso_vars.Exists(name) Then
		wso_vars.add name,value	'add variable to be sent to client
	Else
		wso_vars.item(name)=value
	End If
End Function

'* Add JS Command - javascript command to be executed on client - should only be used when html content is being returned to the client *
Function wsAddJSCommand(cmd)
	Dim ln
	ln = UBound(wso_jsCommands)+1
	ReDim Preserve wso_jsCommands(ln)
	wso_jsCommands(ln)=cmd	' add js commands to be executed on client
End Function

'* Dispatch Variables - dispatch data to the client - should only be used when html content is being returned to the client *
Function wsDispatchVariables()
	Dim i,v,cnt,keys,items
	Dim arr()
	cnt = 0
	If wso_vars.count=0 Then ReDim arr(0) Else ReDim arr(wso_vars.count+UBound(wso_jsCommands))
	keys=wso_vars.keys
	items=wso_vars.items
	' variables
	For i=0 to wso_vars.count-1
		v=items(i)
		arr(i)="var "& keys(i) &"="& ws__Var2Text(v)
	Next
	' jscommands
	For i=wso_vars.count to UBound(wso_jsCommands)+(wso_vars.count-1)
		arr(i) = wso_jsCommands(cnt)
		cnt = cnt + 1
	Next
	wso_IOResponse = wsGetRequest("IOResponse")
	Call ws__docWrite(Join(arr,";"+vbCrLf))
End Function

'* End Response - prevents ws__docWrite from send anymore information to the client *
Function wsEndResponse()
	wso_endDocWrite=true
End Function

'* Get Request - returns a value from either the Request.QueryString or Request.Form Object *
Function wsGetRequest(ByVal name)
	'#	Get requested data sent by client via GET or POST
	'#	Note: ASP Request Object returned a very strange object type.
	'#	This is my only workaround
	Dim vl, mode
	
	mode=wsGetRequestMethod()
	If (mode="post") Then vl=("" & Request.Form(name))
	If (Not IsValid(vl)) Then vl=("" & Request.QueryString(name))
	wsGetRequest = vl
End Function

'* Get Request Method - returns the method used to send the data to the server from the IOElement object on the client *
Function wsGetRequestMethod()
	Dim rm
	If Not IsValid(wso_reqMethod) Then
		rm = Request.QueryString("IOMethod") & "" ' used to indicate GET, POST or UPLOAD - these are use by dynapi on client-side
		If Not IsValid(rm) Then
			rm=Request.ServerVariables("REQUEST_METHOD") & ""
		End If
		If Not IsValid(rm) Then 
			wso_reqMethod="post"
		Else
			wso_reqMethod = LCase(rm)
		End If
	End If
	wsGetRequestMethod = wso_reqMethod
End Function


'# [Private] Functions ------------------------------------------------

'* Doc Write - generates an html page containing JavaScript codes that will be loaded into an <IFrame> or <Layer> on the client *
Function ws__docWrite(ByVal h)
	Dim html	
	If IsValid(wso_endDocWrite) Then Exit Function	
	If wso_IOResponse="text/xml" Then 
		html=h
	Else
		html="<html><script language=""javascript"">"+ vbCrLf _
		+"var ioObj,dynapi=parent.dynapi;"+ vbcrlf _
		+"if (dynapi) ioObj=parent.IOElement.notify(this);"+ vbCrLf _
		+"else alert('Error: Missing or invalid DynAPI library');"+ vbcrlf _
		+""& h & vbCrLf &"</script></html>"
	End If
	Response.Write(html)
End Function

'* Var2Text - used to convert a server-side variable into a javascript client-side variable *
Private Function ws__Var2Text(v)
	Dim i,c,data,vtype,yyyy,mm,dd,hh,nn,ss

	vtype = VarType(v)
	If(IsDate(v) AND vtype=vbstring ) Then
		If (Len(v)>=8) Then vtype=vbDate
	End If

	data="null"
	If (vtype=vbBoolean) Then
		If (v) Then data="true" Else data="false"
	ElseIf (vtype<>0 And IsNumeric(v)) Then
		data=v &""
	ElseIf (vtype=vbString) Then
		data="'"+ ws__Var2TextEncode(v)+"'"
	ElseIf (IsArray(v)) Then	'Array Object
		data="["
		For  i=0 to UBound(v)
			If (i>0) Then data = data + ","
			data = data + ws__Var2text(v(i))
		Next
		data=data+"]"
	ElseIf (vtype=vbDate) Then	'Date object - mm/dd/yyyy hh:nn:ss
		yyyy=CStr(Year(v))
		mm=Right("0"& Month(v),2)
		dd=Right("0"& Day(v),2)
		hh=Right("0"& Hour(v),2)
		nn=Right("0"& Minute(v),2)
		ss=Right("0"& Second(v),2)
		data="new Date('"+mm+"/"+dd+"/"+yyyy+" "+hh+":"+nn+":"+ss+"')"
	ElseIf (vtype=vbObject) Then 'Dictionary Object
		Dim keys,itms
		data="{"+vbcrlf
		On Error Resume Next
		keys=v.keys
		itms=v.items
		For i=0 to v.count-1
			If (i>0) Then data=data+","+vbcrlf
			data=data+"'"+ws__Var2TextEncode(keys(i))+"':"+ws__Var2Text(itms(i))
		Next
		data=data+vbcrlf+"}"
	End If
	ws__Var2Text = data		
End Function

'* Var2Text Encode - converts multiline text into single line javascript*
Private Function ws__Var2TextEncode(t)
	If (Not IsNull(t)) Then
		t=Replace(t,"\","\\")		' replace \ with \\
		t=Replace(t,"'","\'")		' replace ' with \'
		t=Replace(t,vbCrLf,"\n")	' replace CrLf with \n
		t=Replace(t,vbLf,"\n")		' replace single Lf with \n
		t=Replace(t,vbCr,"\r")		' replace single Cr with \n
		ws__Var2TextEncode = t
	End If
End Function
	

'# [Special VBScript Helper Method] ----------------------------

'* IsValid - Returns true if vl is a valid not empty or null
Function IsValid(ByVal vl)
	If VarType(vl)=vbString Then
		IsValid = Not (vl="")	
	Else
		If VarType(vl)=vbBoolean Then
			IsValid=vl
		Else 
			IsValid = Not (IsNull(vl) Or IsEmpty(vl))
		End If
	End If
End Function

%>