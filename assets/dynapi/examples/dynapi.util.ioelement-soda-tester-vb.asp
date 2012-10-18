<!-- #include file="ioelmsrv.vbscript.asp" -->
<!-- #include file="ioelmsrv.soda.vbscript.asp" -->

<%

Call wsAddMethod("testBoolean",Array("b:boolean:false"),"boolean")
Call wsAddMethod("testInteger",Array("n:integer"),"integer")
Call wsAddMethod("testFloat",Array("n:float"),"float")
Call wsAddMethod("testString",Array("s:string"),"string")
Call wsAddMethod("testDate",Array("d:date"),"date")
Call wsAddMethod("testArray",Array("a:array"),"array")
Call wsAddMethod("testObject",Array("o:object"),"object")

'wsCaptureEvent "login", GetRef("CheckLogin")
'wsCaptureEvent "dispatch", GetRef("BeforeDispatch")

wsSetName "VBScript SODA Test"
wsSetComment "This Web Service was created using VBScript"

Call wsEnableOnlineHelp(true)

Call wsDispatch()

Function CheckLogin(ByVal uid, ByVal pwd, ByVal sid)
	If (uid="myname" And pwd="mypassword") Then 
		Session(sid)="ok"
		CheckLogin=true
	Else 
		Session.Contents(sid)="failed"
	End If
End Function

Function BeforeDispatch()
	Dim sid
	sid=wsGetSessionId()
	If (Session(sid)<>"ok" And Session(sid)<>"failed") Then 
		Dim t
		t="Unable to retrieve Session Information."+vbcrlf
		t=t+"Please make sure Cookies are enabled on your browser."+vbcrlf
		t=t+"Some browsers include Privacy Policies that block unknown cookies."
		Call wsRaiseError("",t)
	End If		
	If (Session(sid)<>"ok") Then BeforeDispatch=false
End Function

'// Test Boolean
Function testBoolean(b)
	testBoolean=b
End Function

'// Test Integer
Function testInteger(n)
	testInteger=n
End Function

'// Test Float
Function testFloat(n)
	testFloat=n
End Function

'// Test String
Function testString(s)
	testString=s
End Function

'// Test Date
Function testDate(d)
	testDate=d
End Function

'// Test Array
Function testArray(a)
	testArray=a
End Function

'// Test Object - Associative/Hash Array (aka Disctionary Object)
Function testObject(o)
	Set testObject=o
End Function

%>