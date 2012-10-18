<%

'	IOElement Server SODA-RPC Library - For ASP Servers (VBScript)
'	For use with DynAPI IOElementSoda client-side JavaScript
'
'	The DynAPI Distribution is distributed under the terms of the GNU LGPL license.
'	
'	Requires: IOElement Server Library (VBScript)
'	
'	Web Service Data Types: integer, float, string, date, array, object (associative array)


Dim wso_name			'Web service name 
Dim wso_comment			'Web service comment
Dim wso_dispatch		'stores method names to be dispatch to client
Dim wso_soda			'soda object
Dim wso_params()		'stores parameter values to be past to mehtod
Dim wso_helpMode		'True if in help mode
Dim wso_enableHelp		'True if online help mode is enabled
Dim wso_iconfile		'stores icon file name and path
Dim wso_descriptions	'stores descriptions for methods and their parameters

Dim wso_eventDispatch,wso_hasDispatchEvent
Dim wso_eventLogin,wso_hasLoginEvent
Dim wso_eventLogout,wso_hasLogoutEvent

Dim wso_sodaErrorText

wso_enableHelp=false

wso_hasLoginEvent=false
wso_hasLogoutEvent=false
wso_hasDispatchEvent=false

Set wso_dispatch = Server.CreateObject("Scripting.Dictionary")
Set wso_descriptions = Server.CreateObject("Scripting.Dictionary")
Set wso_sodaErrorText = Server.CreateObject("Scripting.Dictionary")

wso_sodaErrorText.add "E1","System Error"
wso_sodaErrorText.add "E2","Method not found"
wso_sodaErrorText.add "E3","Error occurred while parsing SODA Envelope"
wso_sodaErrorText.add "E4","Connection rejected by web service"
wso_sodaErrorText.add "E5","Login Failed"


'* Add Description - Add a description to a method or its parameters *
Function wsAddDescription(ByVal name, ByVal text)
	' name = "methodname" or "methodname:parameter"
	If Not wso_descriptions.Exists(name) Then
		wso_descriptions.add name,text
	Else 
		wso_descriptions.item(name)=text
	End If
End Function

'* Add Error Code *
Function wsAddErrorCode(ByVal code,ByVal text)
	If Not wso_sodaErrorText.Exists(code) Then
		wso_sodaErrorText.add code,text
	Else
		wso_sodaErrorText.item(code)=text
	End If
End Function


'* Add Method - methods to be dispatched *
Function wsAddMethod(ByVal name,ByVal params,ByVal rtype)
	'	params = ['param1:data_type:default_value','param2:data_type:default_value',...]
	'	rtype = returned data type
	If (Not IsArray(params) Or Not IsValid(params)) Then params=Array(params)
	If Not wso_dispatch.Exists(name) Then
		wso_dispatch.add name,Array(params,rtype)
	Else
		wso_dispatch.item(name)=Array(params,rtype)
	End If
End Function


'* Capture Event  - Server-side events generated during wsDispatch() (events:dispatch,login) *
Function wsCaptureEvent(ByVal evnt,ByVal fn)
	If (evnt="dispatch") Then
		Set wso_eventDispatch=fn
		wso_hasDispatchEvent=true
	ElseIf (evnt="login") Then
		Set wso_eventLogin=fn
		wso_hasLoginEvent=true
	ElseIf evnt="logout" Then
		wso_eventLogout=fn
		wso_hasLogoutEvent=true
	End If
End Function


'* Dispatch - dispatches methods and variables *
Function wsDispatch()
	Dim continueDispatch
	Dim i,c,m,p,s,value,isoda,html
	Dim defautValue,dataType,paramName,returnDataType
	Dim envelope,soda,arr(),items,keys

	continueDispatch=false

	' get SODA-RPC envelope
	envelope=wsGetRequest("IOEnvelope")

	' get Response Type - defaults to text/html
	wso_IOResponse=wsGetRequest("IOResponse")
	If Not IsValid(wso_IOResponse) Then wso_IOResponse="text/html"

	If Not IsValid(envelope) Then
		' display help or splash screen
		Call ws__vbsAssign(ws__helpManager(false,null),soda)
		If Not IsValid(soda) Then
			Exit Function
		Else
			Set wso_soda = soda
		End If
	Else
		' parse SODA-RPC envelope
		Set wso_soda = ws__SODAParser(envelope)
		Set soda = wso_soda
		' Check if System Function - these functions begins with SYS:
		If InStr(1,soda.item("methodName"),"SYS:")=1 Then
			isoda=ws__SYSFunction()
		End If
	End If

	If (Not IsValid(isoda)) Then
		' Not System Function - continue with dispatch
		continueDispatch=true
		' trigger dispatch event
		If (wso_hasDispatchEvent) Then
			value=ws__invokeEvent("dispatch")
			If ws__vbsTypeOf(value)="boolean" Then
				If (value=false) Then
					isoda = ws__createSODAEnvelope(soda.item("methodName"),null,"E4",wso_sodaErrorText.item("E4"))
					continueDispatch=false
				End If
			Elseif ws__vbsTypeOf(value)="string" Then
				isoda = ws__createSODAEnvelope(soda.item("methodName"),null,"E1",wso_sodaErrorText.item("E1") & " : "& value &" while executing dispatch event")
				continueDispatch=false		
			End If
		End If
	End If

	' dispatch support for multiple method calls
	If (continueDispatch) Then
		Dim mn,mns,inx,evalResult,ar()
		Dim result,params,byVals

		' get method name(s) sent by client
		mn=soda.item("methodName")
		If (IsValid(mn) And InStr(1,mn,",")>0) Then 
			mns=Split(mn, ",")
		Else 
			mns=Array(mn)
		End If		

		' loop through requested methods
		For c=0 To UBound(mns)

			' look up method name in wso_dispatch
			mn=mns(c)
			m=ws__vbsGetMethodParams(mn)

			If(Not IsValid(m)) Then
				isoda = ws__createSODAEnvelope(mn,null,"E2",wso_sodaErrorText.item("E2")+" '"+mn+"'")
				Exit For
			ElseIf (Not IsValid(soda.item("value"))) Then
				isoda = ws__createSODAEnvelope(mn,null,"E3",wso_sodaErrorText.item("E3"))
				Exit For
			Else 
				' get params for the requested methods 
				byVals=null
				If(UBound(mns)=0) Then 
					byVals=soda.item("value")
				Else 
					result=soda.item("value")
					If (ws__vbsTypeOf(result)="array") Then
						If (UBound(result)>=c) Then byVals=result(c)
					End If
				End If

				' get local params and return type for the dispatched method
				params = m(0)
				returnDataType = m(1)
				ReDim wso_params(UBound(params))
				
				' build execution string
				s=mn & "("
				For i=0 To UBound(params)
					If IsValid(params(i)) Then
						value=null
						p=Split(params(i),":")
						If UBound(p)>=0 Then paramName=p(0) Else paramName=null
						If UBound(p)>=1 Then dataType=p(1) Else dataType=null
						If UBound(p)>=2 Then defaultValue=p(2) Else defaultValue=null
						If IsValid(byVals) Then
							If UBound(byVals)>=i Then
								ws__vbsAssign byVals(i),value 
								If ws__vbsTypeOf(value)="string" Then
									If InStr(1,value,"@RESULT#")=1 And IsNumeric(Mid(value,9)) Then 
										inx=CInt(Mid(value,9))
										If(inx>=0 And inx<=UBound(ar)) Then ws__vbsAssign ar(inx),value
									End If									
								End If
							End If
						End If
						If (Not IsValid(value) And IsValid(defaultValue)) Then 
							If (defaultValue="false") Then 
								value=false
							ElseIf (defaultValue="true") Then 
								value=true
							ElseIf (defaultValue="null") Then 
								value=null
							Else 
								value=defaultValue
							End If
						End If
						If IsValid(value) Then
							ws__vbsAssign ws__setDataType(value,dataType),value 
						End If
						If ws__vbsTypeOf(value)="object" Then
							Set wso_params(i)=value
						Else
							wso_params(i)=value
						End If
						If (i>0) Then s=s+","
						s=s+"wso_params(" + CStr(i) +")"
					End If
				Next 
				s=s+")"

				' execute method
				evalResult = ws__vbsEvalCode(s)	
				If Not IsValid(evalResult(0)) Then
					' store result inside an array
					ReDim Preserve ar(c)
					If returnDataType<>"object" Then 
						result = ws__setDataType(evalResult(1),returnDataType)
						ar(c) = result 
					Else
						Set result = ws__setDataType(evalResult(1),returnDataType)
						Set ar(c) = result 					
					End If
					If (UBound(mns)=0) Then
						isoda = ws__createSODAEnvelope(mn,result,null,null)
					ElseIf (c=UBound(mns)) Then
						isoda = ws__createSODAEnvelope(soda.item("methodName"),ar,null,null)
					End If
				Else
					isoda = ws__createSODAEnvelope(mn,null,"E1",wso_sodaErrorText.item("E1")+" : " & evalResult(0) & " while executing '"& mn &"()'")
					Exit For
				End If
			End If
		Next 
	End If
	
	' send response back to client
	If wso_helpMode Then
		' if in help mode helpManager will handle the returned data
		Call ws__helpManager(true,result) 	
	ElseIf (wso_IOResponse="text/xml") Then 
		Call ws__docWrite(isoda)
	Else 
		ReDim arr(wso_vars.count)
		arr(0) = "var wsSODAResponse='"+ isoda +"'"
		keys=wso_vars.keys
		items=wso_vars.items
		For i=0 to wso_vars.count-1
			v=items(i)
			arr(i+1)="var "& keys(i) &"='"& ws__Var2SODA(v,null) &"'"
		Next
		Call ws__docWrite(Join(arr,";"+vbCrLf))
	End If
End Function

'* Enable Online Help - Enables/Disables online help/debugging mode *
Function wsEnableOnlineHelp(Byval b)
	If IsValid(b) Then 
		wso_enableHelp=true
	Else
		wso_enableHelp=false
	End If	
End Function

'* Get Session ID - returns caller session id *
Function wsGetSessionId()
	If IsValid(wso_soda) Then
		wsGetSessionId = wso_soda.item("sid")
	End If
End Function

'* Is Help Mode - Returns true if in helpmode or false if not in help mode *
Function wsIsHelpMode()
	If IsValid(wso_helpMode) Then 
		wsIsHelpMode = true 
	Else 
		wso_helpMode = false
	End If
End Function

'* Raise Error - error number, error description *
Function wsRaiseError(ByVal ecode,ByVal etext)
	Dim isoda, mname
	If Not IsValid(wso_soda) Then mname="" Else mname=wso_soda.item("methodName")
	If Not IsValid(etext) Then etext=""
	If IsValid(ecode) Then etext=wso_sodaErrorText.item("ecode") & " " & etext
	isoda=ws__createSODAEnvelope(mname,null,ecode,etext)
	If(wso_IOResponse<>"text/xml") Then isoda="var wsSODAResponse='"+ isoda +"'"
	Call ws__docWrite(isoda)
	wso_endDocWrite=true
End Function

'* Set Comment - sets web service comment *
Function wsSetComment(ByVal strComment)
	wso_comment=(strComment & "")
End Function

'* Set Icon - set icon path and file name *
Function wsSetIcon(ByVal ifile) 
	wso_iconfile=ifile
End Function

'* Set Name - sets web service name *
Function wsSetName(ByVal strName)
	wso_name=(strName & "")
End Function


'# [Private] ----------------------------------------------------

'* Create SODA Envelope  *
Function ws__createSODAEnvelope(ByVal method,ByVal body,ByVal ecode,ByVal etext)
	Dim s
	s="<envelope>"
	If IsValid(method) Then s=s+"<method>"+ ws__SODAStringEncode(method & "") +"</method>"
	If IsValid(ecode) Or IsValid(etext) Then s=s+"<err>"+ ws__SODAStringEncode(ecode & "|" & etext) +"</err>"
	s=s+"<body>"+ ws__Var2SODA(body,null) +"</body>"
	s=s+"</envelope>"
	ws__createSODAEnvelope=s
End Function

'* Help Manager - display and process online help *
Function ws__helpManager(ByVal showResult,ByVal result)
	Dim soda,total,url
	Dim i,v,t,c,nv,cm,dm,params,template
	Dim serviceHeading,serviceBody
	Dim serviceIcon,serviceName,serviceComment

	' check for help mode
	c=(wso_enableHelp And wsGetRequest("help")="on")
	If (c) Then wso_helpMode=true Else wso_helpMode=false

	' get url	
	url=Request.ServerVariables("URL")
	
	' check if call or display method was requested
	cm=wsGetRequest("call")
	dm=wsGetRequest("display")

	If IsValid(wso_name) Then serviceName=wso_name Else serviceName="SODA-RPC Web service"
	If IsValid(wso_comment) Then serviceComment=wso_comment Else serviceComment="A new way to communicate via the Internet"
	If IsValid(wso_iconfile) Then 
		serviceIcon="<img src="""+wso_iconfile+""" align=""absmiddle"" width=""32"" height=""32"" />"
	Else 
		serviceIcon=""
	End If

	If showResult Then
		' show result to user
		v=ws__object2String(result,0)
		serviceHeading="<b><font face=""Arial"" size=""4"" color=""navy"">Result From Method: <font color=""blue"">"+cm+"</font><font color=""red"">()</font></font></b><br><hr>"
		serviceBody="<blockquote><font face=""Arial"" size=""3"" color=""navy""><pre>" & v &"</pre></font></blockquote><br>"
		serviceBody=serviceBody+"<hr><p align=""right""><font face=""arial"" size=""2""><a href="""+url+"?help=on&display="+cm+""">Back</a> | <a href="""+url+"?help=on"">Main</a></font></p>"
	Else 
		If wsGetRequest("help")<>"on" Then
			' Splash Screen showing service name and comment
			showResult=true
			If Not IsValid(wso_enableHelp) Then 
				serviceBody=""
			Else
				serviceBody="<p align=""right""><font face=""Arial"" size=""2"">"
				serviceBody=serviceBody+"<a href="""+url+"?help=on"">Online Help</a></font>&nbsp;</p>"
			End If
		ElseIf (IsValid(cm) And wso_helpMode) Then
			' create and return soda-object to dispatch()
			Dim ar()
			total=wsGetRequest("total") & ""			
			If Not IsNumeric(total) Then total=0 Else total=CInt(total)
			Set soda=Server.CreateObject("Scripting.Dictionary")
			soda.add "sid",""
			soda.add "methodName",cm
			
			If total>0 Then ReDim ar(total-1)
			For i=0 to total-1
				v=wsGetRequest("txt" & i)
				dt=wsGetRequest("cbo" & i)
				' convert "v" to selected data type.
				If (dt="array") Then
					v=Split((v &""),",")
				ElseIf (dt="object") Then
					t=Split(v,",")
					Set v=Server.CreateObject("Scripting.Dictionary")
					For c=0 to UBound(t)
						nv=Split(t(c),":")
						If UBound(nv)>=1 Then v.add nv(0),nv(1)
					Next
				Else
					ws__vbsAssign ws__setDataType(v,dt),v 
				End If
				If ws__vbsTypeOf(v)="object" Then
					Set ar(i)=v
				Else
					ar(i)=v
				End If
			Next	
			
			soda.add "value",ar
			Set ws__helpManager = soda
			Exit Function
		ElseIf IsValid(dm) And IsValid(wso_helpMode) Then
			' display method info
			c=0: showResult=true
			serviceHeading="<b><font face=""Arial"" size=""4"" color=""navy"">Call Method: <font color=""blue"">"+dm+"</font><font color=""red"">(</font></font></b><br><hr><font size=""2"" face=""Arial"">"
			If wso_descriptions.Exists(dm) Then
				serviceHeading=serviceHeading+wso_descriptions.item(dm)
			End If
			serviceHeading=serviceHeading+"</font>"
			serviceBody="<center><form name=""frm"" method=""post"" action="""+url+"?help=on&call="+dm+"""><input name=""dummy"" type=""hidden"" value=""for ns4 only"">"
			If Not wso_dispatch.Exists(dm) Then Exit Function
			params=wso_dispatch.Item(dm)(0)
			If Not IsValid(params(0)) Then 
				serviceBody=serviceBody+"<p><font face=""arial""><h2>No agruments required</h2></font></p>"
			Else 
				serviceBody=serviceBody+"<table cellpadding=""2"" bgcolor=""#ececec"" border=""0"" style=""font-family: Arial; font-size: 10pt"">"
				serviceBody=serviceBody+"<tr bgcolor=""#ececec""><td><b>Arguments</b></td><td><b>Data Type</b></td><td><b>Default value</b></td><td><b>Description</b></td></tr>"
				For c=0 to UBound(params)
					t=params(c)
					t=Split(t,":")
					If UBound(t)<2 Then ReDim Preserve t(2)
					serviceBody=serviceBody+"<tr>"
					serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""20%"">"+ ws__vbsIIf(IsValid(t(0)), t(0), "&nbsp;")
					serviceBody=serviceBody+":<br><input name=""txt"& c &""" type=""text"" size=""20""></td>"
					serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""20%"">"+ ws__vbsIIf(IsValid(t(1)), t(1), "&nbsp;")+ "<br>"
					serviceBody=serviceBody+"<select name=""cbo" & c &""">"
					serviceBody=serviceBody+"<option value=""null"""+ ws__vbsIIf((t(1)="null")," selected","") +">null</option>"
					serviceBody=serviceBody+"<option value=""array"""+ ws__vbsIIf((t(1)="array"), " selected","") +">array</option>"
					serviceBody=serviceBody+"<option value=""boolean"""+ ws__vbsIIf((t(1)="boolean"), " selected", "") +">boolean</option>"
					serviceBody=serviceBody+"<option value=""date"""+ ws__vbsIIf((t(1)="date"), " selected","") +">date</option>"
					serviceBody=serviceBody+"<option value=""float"""+ ws__vbsIIf((t(1)="float"), " selected","") +">float</option>"
					serviceBody=serviceBody+"<option value=""integer"""+ ws__vbsIIf((t(1)="integer"), " selected","")+">integer</option>"
					serviceBody=serviceBody+"<option value=""object"""+ ws__vbsIIf((t(1)="object"), " selected","") + ">object</option>"
					serviceBody=serviceBody+"<option value=""string"""+ ws__vbsIIf((t(1)="string"), " selected", "") +">string</option>"
					serviceBody=serviceBody+"</select></td>"
					serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""20%"" align=""center"">"+ws__vbsIIf(IsValid(t(2)), t(2),"variant") +"</td>"

					' get parameter description
					nv=dm+":"+t(0)
					t=null
					If wso_descriptions.Exists(nv) Then t = wso_descriptions.Item(nv)

					serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""40%"" valign=""top"">"+ ws__vbsIIf(IsValid(t), t,"&nbsp;") +"</td></tr>"
				Next
				serviceBody=serviceBody+"</table><input name=""total"" type=""hidden"" value="""& (UBound(params)+1) &""">"
			End If
		    serviceBody=serviceBody+"</form></center><font face=""arial"" size=""4"" color=""red""><b>)</b></font><table width=""90%""><tr><td align=""right""><font face=""arial"" size=""2""><a href="""+url+"?help=on"">Main</a> | <a href=""javascript:void(null);"" onclick=""document.forms['frm'].submit();return false;"">Execute</a></font>&nbsp;</td></tr>"
			serviceBody=serviceBody+"<tr><td><hr><font face=""arial"" size=""2""><u>Object</u> can be represented as: fname:Mary,lname:Jane,email:mj@yahoo.com<br>"
		    serviceBody=serviceBody+"<u>Arrays</u> can be represent as: red,blue,green</font></td></tr></table>"		    
		ElseIf IsValid(wso_helpMode) Then
			' display main page
			showResult=true
			serviceHeading="<font face=""Arial"" size=""4"" color=""navy""><b>Available Methods</b></font><br><hr>"
			serviceBody="<table border=""0"" width=""90%"" cellspacing=""0"" style=""font-family: Arial; font-size: 12pt"">"
			Dim bgcolor,cnt,keys
			cnt=0
			keys=wso_dispatch.keys()
			For i=0 to UBound(keys)
				v=keys(i) &""
				t=ws__vbsIIf(wso_descriptions.Exists(v), wso_descriptions.Item(v),"&nbsp;")
				cnt=cnt+1
				bgcolor=ws__vbsIIf((cnt Mod 2)=0,"#EEEEEE","#FFFFFF")
		        serviceBody=serviceBody+"<tr bgcolor="""+bgcolor+"""><td width=""25%""><font color=""blue""><b>&nbsp;"+v+"<font color=""red"">(</font></b></font></td><td width=""75%""><font face=""arial"" size=""2"">"+t+"</font></td></tr>"
		        serviceBody=serviceBody+"<tr bgcolor="""+bgcolor+"""><td width=""100%"" colspan=""2"">"
		        params=wso_dispatch(v)(0)
				If Not IsValid(params(0)) Then
					serviceBody=serviceBody+"<p>&nbsp;</p>"
				Else 
					serviceBody=serviceBody+"<br><center><table bgcolor=""#c0c0c0"" border=""0"" width=""95%"" cellpadding=""2"" cellspacing=""1"" style=""font-family: Arial; font-size: 10pt"">"
					serviceBody=serviceBody+"<tr bgcolor=""#eeeeee""><td><b>Arguments</b></td><td><b>Data Type</b></td><td><b>Default value</b></td><td><b>Description</b></td></tr>"
					For c=0 to UBound(params)
						t=params(c)
						t=Split(t,":")
						If UBound(t)<2 Then ReDim Preserve t(2)
						serviceBody=serviceBody+"<tr>"
						serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""20%"">"+ ws__vbsIIf(IsValid(t(0)), t(0), "&nbsp;") +"</td>"
						serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""20%"">"+ ws__vbsIIf(IsValid(t(1)), t(1), "&nbsp;") +"</td>"
						serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""20%"" align=""center"">"+ ws__vbsIIf(IsValid(t(2)), t(2), "variant") +"</td>"
	
						' get parameter description						
						nv=v &":"& t(0)
						t=null // reset variable
						If wso_descriptions.Exists(nv) Then t = wso_descriptions.Item(nv)
						
						serviceBody=serviceBody+"<td bgcolor=""#FFFFFF"" width=""40%"">"+ ws__vbsIIf(IsValid(t), t,"&nbsp;") +"</td></tr>"
					Next
					serviceBody=serviceBody+"</table></center><br>"
		        End If
		        serviceBody=serviceBody+"<font color=""red""><b>)</b></font><font face=""arial"" size=""2""> - Returns "+ ws__vbsIIf(IsValid(wso_dispatch(v)(1)), wso_dispatch(v)(1), "variant") +" data type</font></td></tr>"
		        serviceBody=serviceBody+"<tr><td colspan=""2"" align=""right""><font face=""arial"" size=""2""><a href="""+url+"?help=on&display="+v+""">View</a></font>&nbsp;</td></tr>"
		        serviceBody=serviceBody+"<tr><td colspan=""2""><hr size=""1"" color=""#EEEEEE""></td></tr>"
      		Next
      		serviceBody=serviceBody+"</table>"			
		End If
	End If
	
	If showResult Then		
		template="<html><head><title>service_name - (SODA-RPC)</title><style>a:hover {color:red}</style></head><body link=""#0000FF"" vlink=""#0000FF"">"
		If wsGetRequest("help")<>"on" Then
			' spash screen template
			template=template+"<p align=""center"">&nbsp;</p><p align=""center"">&nbsp;</p>"
			template=template+"<center><table border=""0""><tr>"
			template=template+"<td width=""100%"" align=""center""><b>service_icon <font face=""Arial"" size=""5"">service_name</font></b></td>"
			template=template+"</tr><tr><td width=""100%"" align=""center"" bgcolor=""#eeeeee""><font size=""2"" face=""Arial"">service_comment</font></td></tr>"
			template=template+"<tr><td width=""100%"" align=""center"">service_body</td></tr>"
			template=template+"</table><center>"
		Else
			' help/debug template
			template=template+"<table border=""0"" width=""100%"" cellpadding=""2""  bgcolor=""#E0E0E0"">"
			template=template+"<tr><td width=""100%""  bgcolor=""#FFFFFF"">"
			template=template+"<p>service_icon <b><font face=""Arial"" color=""#000000"" size=""6"">service_name</font></b></p>"
			template=template+"</td></tr><tr><td width=""100%"" bgcolor=""#EEEEEE"">"
			template=template+"<p><font face=""Arial"" size=""2"">service_comment</font></p>"
			template=template+"</td></tr></table><blockquote>"
			template=template+"<p>service_heading</p>"
			template=template+"service_body</blockquote>"
		End If
		template=template+"</body></html>"

		template=Replace(template,"service_icon",serviceIcon)
		template=Replace(template,"service_name",serviceName)
		template=Replace(template,"service_comment",serviceComment)
		template=Replace(template,"service_heading",serviceHeading)
		template=Replace(template,"service_body",serviceBody)
		
		Call Response.Write(template)
	End If
	
End Function


'* Invoke Event - Invokes the server-side events dispatch and login *
Function ws__invokeEvent(evnt)
	On error Resume Next
	If evnt="dispatch" And wso_hasDispatchEvent Then
		ws__invokeEvent=wso_eventDispatch()
	ElseIf evnt="login" And wso_hasLoginEvent Then
		Dim uid,pwd,sid
		uid=ws__vbsIIf(IsValid(wso_soda), wso_soda.item("uid"),"")
		pwd=ws__vbsIIf(IsValid(wso_soda), wso_soda.item("pwd"),"")
		sid=ws__vbsIIf(IsValid(wso_soda), wso_soda.item("sid"),"")
		ws__invokeEvent=wso_eventLogin(uid,pwd,sid)
	ElseIf evnt="logout" And wso_hasLogoutEvent Then
		ws__invokeEvent=wso_eventLogout()
	End If
	If(Err.number<>0) Then ws__invokeEvent=Err.Description	
End Function

'* Object 2 String *
Function ws__object2String(ByVal o, ByVal tablvl)
	Dim i,s,v,tabs,itabs
	
	v="":tabs="":itabs=""
	
	' set tab spaces
	tablvl=ws__vbsIIf(tablvl,tablvl,0)
	tablvl=tablvl+1
	For i=0 to tablvl-1 
		tabs=tabs+vbTab
	Next
	For i=0 to (tablvl-2)
		itabs=itabs+vbTab
	Next
	
	If ws__vbsTypeOf(o)="array" Then
		Dim ar()
		ReDim ar(UBound(o))
		For i=0 to UBound(o)
			ar(i)=ws__object2String(o(i),tablvl)
		Next
		s="[<br>"+tabs+Join(ar,",")+"<br>"+itabs+"]"
	ElseIf ws__vbsTypeOf(o)="object"  Then
		keys=o.keys()
		For i=0 to UBound(keys)
			If IsValid(v) Then v=v+",<br>"
			v=v+(tabs & keys(i) &":"& ws__object2String(o.item(keys(i)),tablvl))
		Next
		s = itabs+"{<br>"+v+"<br>"+itabs+"}"
	Else
		s=o & ""
	End If
	ws__object2String = s
End Function

'* System Function - Executes system functions such as "WebServiceConnect" *
Function ws__SYSFunction()
	Dim mn,found
	Dim i,o,rt,ec,et,keys	

	mn=ws__vbsIIf(IsValid(wso_soda),wso_soda.item("methodName"),"")

	found=false
	Set o = Server.CreateObject("Scripting.Dictionary")
	
	Select Case(mn) 		
		Case "SYS:WebServiceConnect"
			' get service name and comment 
			o.add "name",wso_name
			o.add "comment",wso_comment
			' return method names if RCF = text/xml
			If wso_IOResponse="text/xml" Then
				keys=wso_dispatch.keys()
				rt=Join(keys,",")
				o.add "methodNames",rt
			End If
			'do login
			If (wso_hasLoginEvent) Then
				rt=ws__invokeEvent("login")
				If ws__vbsTypeOf(rt)="boolean" Then
					If (rt=true) Then rt="ok" Else rt="failed"
				Else 
					If(ws__vbsTypeOf(rt)="string")  then
						'expecting errors to be string
						et=rt: ec=""
					End If
					rt="failed"
				End If
			Else
				rt="ok"
			End If
			o.add "login",rt
			found=true
		
		Case "SYS:WebServiceDisconnect"
			If (wso_hasLogoutEvent) Then
				rt=ws__invokeEvent("logout")
				If ws__vbsTypeOf(rt)="boolean" Then
					If (rt=true) Then rt="ok" Else rt="failed"
				Else 
					If(ws__vbsTypeOf(rt)="string")  then
						'expecting errors to be string
						et=rt: ec=""
					End If
					rt="failed"
				End If
			Else
				rt="ok"
			End If
			o.add "logout",rt
			found=true
		
	End Select
	
	If(found) Then
		o.add "SYSCall",true
		ws__SYSFunction = ws__createSODAEnvelope(n,o,ec,et)
	End If
End Function

'* Set Data Type *
Function ws__setDataType(ByVal value,ByVal dt)
	If Not IsValid(dt) Then 
		ws__setDataType=null
	Else
		Dim v
		If dt="string" Then 
			v=value &""
		ElseIf dt="date" And IsValid(value) Then
			If IsDate(value) Then v=CDate(value) Else v=null
		ElseIf dt="integer" And IsValid(value) Then 
			If IsNumeric(value) Then v=CInt(value) Else v=0
		ElseIf dt="float" And IsValid(value) Then
			If IsNumeric(value) Then v=CDbl(value) Else v=0.00
		ElseIf dt="boolean" Then
			If ws__vbsTypeOf(value)="boolean" Then 
				v=value
			ElseIf IsNumeric(value) Then 
				If CInt(value)>0 Then v=true Else v=false
			ElseIf ws__vbsTypeOf(value)="string" Then
				If LCase(value)="true" Then v=true Else v=false
			Else 
				v=false
			End If
		ElseIf dt="array" Then
			If ws__vbsTypeOf(value)<>"array" Then 
				v=Array(value)
			Else
				v=value
			End If
		ElseIf dt="object" Then
			If ws__vbsTypeOf(value)<>"object" Then 
				Set v = Server.CreateObject("Scripting.Dictionary")
			Else 
				Set v = value
			End If
		Else 
			v=null
		End If
		If dt<>"object" Then 
			ws__setDataType=v 
		Else 
			Set ws__setDataType=v
		End If
	End If
End Function

'# SODA Internal Data Types: U=undefined, I=integer, F=float, B=boolean, D=date/time, S=string, A=array, O=Object (Associative Array)
Function ws__Var2SODA(ByVal v, ByVal lvl)
	Dim ot,ct,i,c,data,vtype
	
	vtype=ws__vbsTypeOf(v)

	If (lvl>=0) Then lvl=lvl+1 Else lvl=0

	If (vtype="number") Then
		data="<i" & lvl & ">" & v & "</i" & lvl & ">"
	ElseIf (vtype="float") Then
		data="<f" & lvl & ">" & v & "</f" & lvl & ">"
	ElseIf (vtype="boolean") Then
		If (v=true) Then 
			data="<b" & lvl & ">true</b" & lvl & ">"
		Else 
			data="<b" & lvl & ">false</b" & lvl & ">"
		End If
	ElseIf (vtype="string") Then
		data="<s" & lvl & ">" & ws__SODAStringEncode(v) & "</s" & lvl & ">"
	ElseIf (vtype="array") Then
		data="<a" & lvl & ">"
		For i=0 to UBound(v)
			If (i>0) Then
				data=data + "<r" + CStr(lvl) + "/>" + ws__Var2SODA(v(i),lvl)
			Else
				data=data + ws__Var2SODA(v(i),lvl)
			End If
		Next
		data=data & "</a" & lvl & ">"
	ElseIf (vtype="date") Then	
		Dim dt 'Date format: mm/dd/yyyy hh:nn:ss
		dt=Month(v) &"/"& Day(v) &"/"& Year(v) &" "& Hour(v)  &":"& Minute(v) &":"& Second(v)
		data="<d" & lvl & ">" & dt & "</d" & lvl & ">"
	ElseIf (vtype="object") Then 'Dictionary Object 
		Dim ar,key,keys,values
		keys=v.keys
		values=v.items
		For i=0 to UBound(keys)
			key=keys(i)
			If (InStr(1,key,"|")>0) Then 
				key=Replace(key,"|","&s;")
				keys(i)=key
			End If
		Next
		ar=Array(Join(keys,"|"),values)
		data="<o" & lvl & ">" & ws__Var2SODA(ar,lvl) & "</o" & lvl & ">"
	Else 
		data="<u" & lvl & ">0</u" & lvl & ">"
	End If
	If (lvl=0) Then data="<soda>" & data & "</soda>"
	ws__Var2SODA=data
End Function

Function ws__SODA2Var(ByVal t, ByVal lvl)
	Dim i,vr,tag,data,elms,ar()
	Dim tagType,tagIndex

	If (lvl>=0) Then lvl=lvl+1 Else lvl=0


	If (lvl=0) Then
		If (Mid((t & ""),1,6)<>"<soda>") Then 
			ws__SODA2Var=t
			Exit Function
		End If
		Set tag = ws__getSODATag(t,"soda")
		t=tag.item("content")
	End If

	Set tag = ws__getSODATag(t,null)
	tagType=Mid(tag.item("name"),1,1)
	tagIndex=Mid(tag.item("name"),2)
	If (tagType="i") Then 
		If IsNumeric(tag.item("content")) Then 
			data=CLng(tag.item("content"))
		End If
	ElseIf (tagType="f") Then 
		If isNumeric(tag.item("content")) Then 
			data=CDbl(tag.content)
		End If
	ElseIf (tagType="b") Then 
		If IsValid(tag.item("content")) Then 
			if ws__vbsTypeOf(tag.item("content"))="string" Then
				If tag.item("content")="true" Then data=true Else data=false
			End If
		End If
	ElseIf (tagType="s") Then 
		data=ws__SODAStringDecode(tag.item("content") & "")
	ElseIf (tagType="d") Then
		If IsDate(tag.item("content")) Then data=CDate(tag.item("content"))
	ElseIf (tagType="a") Then
		If IsValid(tag.item("content")) Then
			elms=Split(tag.item("content"),"<r"+tagIndex+"/>")
			ReDim ar(UBound(elms))
			For i=0 to UBound(elms)
				vr=Array(ws__SODA2Var(elms(i),lvl))
				If ws__vbsTypeOf(vr(0))="object" Then
					Set ar(i)=vr(0)
				Else 
					ar(i)=vr(0)
				End If				
			Next
			data=ar
		End If
	ElseIf (tagType="o") Then
		elms=ws__SODA2Var(tag.item("content"),lvl)
		If ws__vbsTypeOf(elms)="array" Then 
			Dim o,key,keys,values
			Set o = Server.CreateObject("Scripting.Dictionary")
			keys=Split(elms(0) & "","|")
			values=elms(1)
			For i=0 to UBound(keys)
				key=keys(i)
				If (InStr(1,key,"&s;")>0) Then key=Replace(key,"&s;","|")
				o.add key,values(i)
			Next
			Set data = o
		End If
	ElseIf (tagType="u") Then 
		data=null
	End If
	
	If(tagType="o") Then
		Set ws__SODA2Var = data
	Else
		ws__SODA2Var = data	
	End If
	
End Function

Function  ws__SODAStringEncode(ByVal text)
	If Not IsValid(text) Then Exit Function
	' encode string for use with html/javascript
	If (wso_IOResponse<>"text/xml") Then
		text=Replace(text,"\","\\") 	'replace \ with \\
		text=Replace(text,"'","\'") 	'replace ' with \'
		text=Replace(text,vbcr,"\n")
		text=Replace(text,vblf,"\r")
	End If
	' encode string for use with both html and xml
	text=Replace(text,"&","&amp;")
	text=Replace(text,"<","&lt;")
	text=Replace(text,">","&gt;")	
	ws__SODAStringEncode = text	
End Function

Function ws__SODAStringDecode(ByVal text)
	If Not IsValid(text) Then Exit Function
	text=Replace(text,"&amp;","&")
	text=Replace(text,"&lt;","<")
	text=Replace(text,"&gt;",">")
	ws__SODAStringDecode=text
End Function

Function ws__getSODATag(t,n)
	Dim o,st,et,tag,con

	If IsValid(t) Then
		st=0:et=0
		If Not IsValid(n) Then n=""
		st=InStr(1,t,"<" & n)
		If (st>0) Then et=InStr(st,t,">")
		If(et>0) Then
			tag=Mid(t,st+1,(et-1)-st)
			st=et+1
			et=InStr(1,t,"</"+tag+">")
			con=Mid(t,st,et-st)
		End If
	End If
	Set o = Server.CreateObject("Scripting.Dictionary")
	o.add "name",tag
	o.add "content",con
	Set ws__getSODATag = o
End Function

Function ws__SODAParser(ByVal envelope)
	Dim o
	Set o = Server.CreateObject("Scripting.Dictionary")
	o.add "sid",ws__getSODATag(envelope,"sid").item("content")
	o.add "uid",ws__getSODATag(envelope,"uid").item("content")
	o.add "pwd",ws__getSODATag(envelope,"pwd").item("content")
	o.add "error",ws__SODAStringDecode(ws__getSODATag(envelope,"err").item("content"))
	o.add "methodName",ws__SODAStringDecode(ws__getSODATag(envelope,"method").item("content"))
	o.add "value",ws__SODA2Var(ws__getSODATag(envelope,"body").item("content"),null)
	If IsValid(o.item("error"))  Then
		Dim ea
		ea=Split(o.item("error"),"|")
		Set o.item("error") = Server.CreateObject("Scripting.Dictionary")
		o.item("error").add "code",ea(0)
		o.item("error").add "text",ea(1)
	ElseIf InStr(1,(envelope+""),"<envelope>")<>1 Then
		Set o.item("error") = Server.CreateObject("Scripting.Dictionary")
		o.item("error").add "code","E3"
		o.item("error").add "text",wso_sodaErrorText.item("E3")
	End If
	Set ws__SODAParser = o
End Function

'#
'# [Special VBScript Helper Method] ----------------------------
'#

'* Get Method Params - Returns the parameters for a dispatched method
Function ws__vbsGetMethodParams(ByVal mName)
	Dim r
	If wso_dispatch.Exists(mName) Then	r = wso_dispatch.item(mName)
	ws__vbsGetMethodParams = r
End Function

'* Eval Code - Execute a line of vbscript code and return the results
Function ws__vbsEvalCode(ByVal eCode)
	Dim ar
	On Error Resume Next
	ar=Array(null,eval(eCode))
	If (Err.Number<>0) Then ar=Array(Err.Description,null)
	ws__vbsEvalCode=ar
End Function

'* IIf - Inline If Returns tpart is exp is true otherwise fpart is returned
Function ws__vbsIIf(ByVal exp,ByVal tpart,ByVal fpart)
	If (IsValid(exp)) Then
		ws__vbsIIf=tpart
	Else 
		ws__vbsIIf=fpart
	End If
End Function

'* Type Of - Returns the name of the data type for vl  
Function ws__vbsTypeOf(ByVal vl)
	Select Case VarType(vl)
		Case vbInteger, vbLong, vbByte
			ws__vbsTypeOf="number"
		Case vbSingle,vbDouble, vbCurrency
			ws__vbsTypeOf="float"
		Case vbString
			ws__vbsTypeOf="string"
		Case vbBoolean
			ws__vbsTypeOf="boolean"
		Case vbDate
			ws__vbsTypeOf="date"
		Case vbArray,8204
			ws__vbsTypeOf="array"
		Case vbObject
			ws__vbsTypeOf="object"	
		Case Else
			ws__vbsTypeOf="null"
			
	End Select
End Function

' Assign a value to a variable
Function ws__vbsAssign(ByRef src, ByRef tar)
	If ws__vbsTypeOf(src)="object" Then 
		Set tar=src 
	Else 
		tar=src
	End If
End Function
%>