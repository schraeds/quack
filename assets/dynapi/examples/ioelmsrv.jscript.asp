<%

/*
	IOElement Server Library - For ASP Servers (JavaScript)
	For use with DynAPI IOElement client-side javascript

	The DynAPI Distribution is distributed under the terms of the GNU LGPL license.

	Returned Data type: integer, float, string, date, array, object (associative array)
	
	Raymond Irving <xwisdom (at) yahoo (dot) com>
*/

var wso_jsCommands=[];	// stores javascript commands to be executed on client
var wso_vars=[];		// stores javascript variables to be returned to client
var wso_endDocWrite;	// Prevent ws__docWrite from sending data to client
var wso_IOResponse;		// Returned Content Format: text/html (default) or text/xml
var wso_reqMethod;		// stores request method - get,post or upload - upload is use by dynapi when unloading files

wso_IOResponse="text/html";

/* Add Variables - javascript variables to be sent to client - should only be used when html content is being returned to the client */
function wsAddVariable(name,value){
	if(!name) return;
	wso_vars[name]=value;	// add variable to be sent to client
};

/* Add JS Command - javascript command to be executed on client - should only be used when html content is being returned to the client */
function wsAddJSCommand(cmd){
	wso_jsCommands[wso_jsCommands.length]=cmd;	// add js commands to be executed on client
};

/* Dispatch Variables - dispatch data to the client - should only be used when html content is being returned to the client */
function wsDispatchVariables() {
	var i,v,arr=[];
	// variables
	for(i in wso_vars){
		v=wso_vars[i]
		arr[arr.length]="var "+i+"="+ ws__Var2Text(v);
	}
	// jscommands
	for(i=0;i<wso_jsCommands.length;i++) {
		arr[arr.length]= wso_jsCommands[i];
	}
	wso_IOResponse=wsGetRequest("IOResponse");
	ws__docWrite(arr.join(";\n"));
};

/* End Response - prevents ws__docWrite function from sending anymore information to the client */
function wsEndResponse(){
	wso_endDocWrite=true;
};

/* Get Request - returns a value from either the Request.QueryString or Request.Form Object */
function wsGetRequest(name){
	//	Get requested data sent by client via GET or POST
	//	Note: ASP Request Object returned a very strange object type.
	//	This is my only workaround
	//
	var vl;
	var mode=wsGetRequestMethod();
	if(mode=="post") vl=(""+Request.Form(name));
	if(!vl||vl=="undefined") vl=(""+Request.QueryString(name));
	return (vl!="undefined")? vl:'';
};

/* Get Request Method - returns the method used to send the data to the server from the IOElement object on the client */
function wsGetRequestMethod(){
	if(!wso_reqMethod) {
		var rm=Request.QueryString("IOMethod")+""; // used to indicate GET, POST or UPLOAD - these are use by dynapi on client-side
		if(!rm||rm=="undefined") rm=Request.ServerVariables("REQUEST_METHOD")+"";
		wso_reqMethod=(!rm)? "post":rm.toLowerCase();
	}
	return wso_reqMethod;
};

// [Private] Functions ----------------------------------------
/* Doc Write - generates an html page containing JavaScript codes that will be loaded into an <IFrame> or <Layer> on the client */
function ws__docWrite(h){
	var html;	
	if (wso_endDocWrite) return;	
	if(wso_IOResponse=="text/xml") html=h;
	else{
		html='<html><script language="javascript">\n'
		+'var ioObj,dynapi=parent.dynapi;\n'
		+'if (dynapi) ioObj=parent.IOElement.notify(this);\n'
		+'else alert(\'Error: Missing or invalid DynAPI library\');\n'
		+''+h+'\n</script></html>'
	}
	Response.Write(html);
};

/* Var2Text - used to convert a server-side variable into a javascript client-side variable */
ws__Var2Text=function(v){
	var i,c,data,vtype=typeof(v);
	if(!v) data='null';
	else if(vtype=="number"||vtype=="boolean"||vtype=="function") {
		data=v;
	}else if(vtype=="string") {
		data="'"+ws__Var2TextEncode(v)+"'";
	}else if(vtype=="object") {
		if(v.constructor==Array){ // Array Object
			data='[';
			for (i=0;i<v.length;i++){
				data+=(i>0)? ','+ws__Var2Text(v[i]):ws__Var2Text(v[i])
			}
			data+=']';
		}else if(v.constructor==Date){ // Date object
			data='Date("'+v+'")'
		}else{
			data='{';c=0;
			for (i in v){
				if(c>0) data+=','
				data+='\''+ws__Var2TextEncode(i)+'\':'+ws__Var2Text(v[i]);
				c++;
			}
			data+='}';
		}
	}
	return data;
};

/* Var2Text Encode - converts multiline text into single line javascript */
ws__Var2TextEncode=function (text){
	if (!text) return
	text=text.replace(/\\/g,"\\\\");	// replace \ with \\
	text=text.replace(/\'/g,"\\'");		// replace ' with \'
	text=text.replace(/\r\n/g,"\\n");	// replace CrLf with \n
	text=text.replace(/\n/g,"\\n");		// replace single Lf with \n
	text=text.replace(/\r/g,"\\r");		// replace single Cr with \n
	return text;
};

%>