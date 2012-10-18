<!-- #include file="ioelmsrv.vbscript.asp" -->
<!-- #include file="ioelmsrv.soda.vbscript.asp" -->

<%

Call wsSetIcon("images/calc.gif")
Call wsSetName("VBScript Calculator Web Service")
Call wsSetComment("This web service is used to demonstrate the use of SODA-RPC")

Call wsAddMethod("aboutCalculator",null,"object")
Call wsAddMethod("add",Array("a:float:0","b:float:0"),"float")
Call wsAddMethod("subtract",Array("a:float:0","b:float:0"),"float")
Call wsAddMethod("divide",Array("a:float:0","b:float:0"),"float")
Call wsAddMethod("multiply",Array("a:float:0","b:float:0"),"float")
Call wsAddMethod("square",Array("a:float:0"),"float")
Call wsAddMethod("fraction",Array("a:float:0"),"float")
Call wsAddMethod("percentage",Array("a:float:0"),"float")

Call wsAddDescription("aboutCalculator","Calculator/Company Information - Name, Email, etc")
Call wsAddDescription("add","Add two numeric values and returns the result")
Call wsAddDescription("add:a","Numeric value")
Call wsAddDescription("add:b","Numeric value")

wsCaptureEvent "login", GetRef("login")
wsCaptureEvent "dispatch", GetRef("dispatch")

wsAddErrorCode "024","Add Error Message Here" 'You can add custom error messages here

Call wsEnableOnlineHelp(true)

Call wsDispatch()

' Login Event Callback function
Function login(ByVal uid, ByVal pwd, ByVal sid)
	If (uid="myname" And pwd="mypassword") Then 
		Session.Contents(sid)="ok"
		login=true
	Else 
		Session.Contents(sid)="failed"
	End If
End Function

' Dispatch Event Callback function
Function dispatch()
	Dim sid

	' do not check for login when in helpmode
	If wsIsHelpMode()=true Then Exit Function 
	
	sid=wsGetSessionId()
	If (Session(sid)<>"ok" And Session(sid)<>"failed") Then 
		Dim t
		t="Unable to retrieve Session Information."+vbcrlf
		t=t+"Please make sure Cookies are enabled on your browser."+vbcrlf
		t=t+"Some browsers include Privacy Policies that block unknown cookies."
		Call wsRaiseError("",t)
	End If	
	If Session(sid)<>"ok" Then dispatch=false	
End Function

' About Calculator
Function aboutCalculator()
	Dim o,specs

	Set specs = Server.CreateObject("Scripting.Dictionary")
	specs.add "buttons","10"
	specs.add "functions","add, mmultiply, etc"

	Set o = Server.CreateObject("Scripting.Dictionary")
	o.add "name","JS Calculator"
	o.add "company","SODA-RPC Inc."
	o.add "email","support@soda-rpc.com"
	o.add "comment","SODA-RPC Web Service Demo"
	o.add "specs",specs
	o.add "NOTE","<font color=""red""><b>The following is just to demo nested arrays</b></font>"
	o.add "myArray",Array("Red","Blue","Green","Yellow")
	o.add "yourArray",Array(Array("Him","Her","She","His","Boy","Girl","etc"),Array("Corn","Bread"))
	Set aboutCalculator = o
End Function

'Add
Function add(a,b)
	add=a+b
End Function

'subtract
Function subtract(a,b) 
	subtract=a-b
End Function

'Divide
Function divide(a,b)
	divide=a/b
End Function
'
'Multiple
Function multiply(a,b)
	multiply=a*b
End Function

'Square
Function square(a)
	square=a*a	
End Function

'Percentage
Function percentage(a)
	percentage=a/100
End Function

'Fraction
Function fraction(a)
	fraction=1/a
End Function

%>