<%@language="javascript" %>

<!-- #include file="ioelmsrv.jscript.asp" -->
<!-- #include file="ioelmsrv.soda.jscript.asp" -->

<%

wsSetIcon("images/calc.gif");
wsSetName("JScript Calculator Web Service");
wsSetComment("This web service is used to demonstrate the use of SODA-RPC");

wsAddMethod("aboutCalculator",null,"object")
wsAddMethod("add",["a:float:0","b:float:0"],"float")
wsAddMethod("subtract",["a:float:0","b:float:0"],"float")
wsAddMethod("divide",["a:float:0","b:float:0"],"float")
wsAddMethod("multiply",["a:float:0","b:float:0"],"float")
wsAddMethod("square",["a:float:0"],"float")
wsAddMethod("fraction",["a:float:0"],"float")
wsAddMethod("percentage",["a:float:0"],"float")

wsAddDescription("aboutCalculator","Calculator/Company Information - Name, Email, etc")
wsAddDescription("add","Add two numeric values and returns the result")
wsAddDescription("add:a","Numeric value")
wsAddDescription("add:b","Numeric value")

wsAddErrorCode("024","Add Error Message Here") //'You can add custom error messages here

wsCaptureEvent("login",login);
wsCaptureEvent("dispatch",dispatch);

wsEnableOnlineHelp(true);

wsDispatch();


// Login Event Callback function
function login(uid, pwd, sid) {
	if (uid=="myname" && pwd=="mypassword") {
		Session.Contents(sid)="ok";
		return true;
	}else {
		Session.Contents(sid)="failed";
	}
};

// Dispatch Event Callback function
function dispatch() {
	var sid;
	
	// do not check for login when in helpmode
	if(wsIsHelpMode()==true) return;
	
	sid=wsGetSessionId();
	if(Session.Contents(sid)!="ok" && Session.Contents(sid)!="failed") { 
		var t="Unable to retrieve Session Information.\n"
		+"Please make sure Cookies are enabled on your browser.\n"
		+"Some browsers include Privacy Policies that block unknown cookies."
		wsRaiseError("",t);
	}	
	if (Session.Contents(sid)!="ok") return false;
};

// About Calculator
function aboutCalculator(){
	return {
		name:"JS Calculator",
		company:"SODA-RPC Inc.",
		email:"support@soda-rpc.com",
		comment:"SODA-RPC Web Service Demo",
		specs:{
			buttons:"10",
			functions:"add, mmultiply, etc"
		},
		NOTE:"<font color=\"red\"><b>The following is just to demo nested arrays</b></font>",
		myArray:["Red","Blue","Green","Yellow"],
		yourArray:[
			["Him","Her","She","His","Boy","Girl","etc"],
			["Corn","Bread"]
		]		
	}
};

// Add
function add(a,b){
	return a+b
};

// Subtract
function subtract(a,b){
	return a-b
};

// Divide
function divide(a,b){
	return a/b
};

// Multiple
function multiply(a,b){
	return a*b
};

// Square
function square(a){
	return a*a	
};

// Percentage
function percentage(a){
	return a/100
};

// Fraction
function fraction(a){
	return 1/a
};

%>