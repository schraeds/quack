<%

/*
    IOElement Server SODA-RPC Library - For ASP Servers (JavaScript)
    For use with DynAPI IOElementSoda client-side javascript

    The DynAPI Distribution is distributed under the terms of the GNU LGPL license.

    Requires: IOElement Server Library (JavaScript)

    Web Service Data Types: integer, float, string, date, array, object (associative array)
*/

var wso_name;           // Web service name
var wso_comment;        // Web service comment
var wso_dispatch=[];    // stores method names to be dispatch to client
var wso_soda;           // soda object
var wso_params;         // stores parameter values to be past to mehtod
var wso_helpMode;       // True if in help mode
var wso_enableHelp;     // True if online help mode is enabled
var wso_iconfile;       // stores icon file name and path
var wso_descriptions={};// stores descriptions for methods and their parameters

var wso_eventLogin=null;
var wso_hasLoginEvent=false;

var wso_eventLogout=null;
var wso_hasLogoutEvent=false;

var wso_eventDispatch=null;
var wso_hasDispatchEvent=false;

var wso_sodaErrorText=[];

wso_sodaErrorText["E1"]="System Error";
wso_sodaErrorText["E2"]="Method not found";
wso_sodaErrorText["E3"]="Error occurred while parsing SODA Envelope";
wso_sodaErrorText["E4"]="Connection rejected by web service";

/* Add Description - Adds a description to a method or its parameters */
function wsAddDescription(name,text){
    // name = "methodname" or "methodname:parameter"
    if(name) wso_descriptions[name]=text;
};

/* Add Error Code - Adds an error code to the error code collection - used mainly with wsRaiseError() */
function wsAddErrorCode(code,text){
    wso_sodaErrorText[code]=text;
};

/* Add Method - Adds a method to be dispatched or made a publicly available via the service */
function wsAddMethod(name,params,rtype){
    //  name  = name of method - e.g. "myMethod"
    //  params = ['param1:data_type:default_value','param2:data_type:default_value',...]
    //  rtype = returned data type
    if(typeof(params)!="object" || !params) params=[params];
    wso_dispatch[name]=[params,rtype];
};

/* Capture Event  - Server-side events to be triggered during wsDispatch() (events:dispatch,login) */
function wsCaptureEvent(evnt,fn){
    if (evnt=="dispatch") {
        wso_eventDispatch=fn;
        wso_hasDispatchEvent=true;
    } else if (evnt=="login") {
        wso_eventLogin=fn;
        wso_hasLoginEvent=true;
    } else if (evnt=="logout") {
        wso_eventLogout=fn;
        wso_hasLogoutEvent=true;
    }
};

/* Dispatch - dispatches methods and variables */
function wsDispatch(){
    var continueDispatch=false;
    var i,c,m,p,s,value,isoda,html,arr=[];
    var defautValue,dataType,paramName,returnDataType;
    var envelope,soda;

    // get SODA-RPC envelope
    envelope=wsGetRequest("IOEnvelope");

    // get Response Type - defaults to text/html
    wso_IOResponse=wsGetRequest("IOResponse");
    if(!wso_IOResponse) wso_IOResponse="text/html";

    // check if envelope is available
    if(!envelope) {
        // display help or splash screen if not evelope was sent
        soda = ws__helpManager(false);
        if(!soda) return;
        else wso_soda=soda;
    }else{
        // parse SODA-RPC envelope
        soda=wso_soda=ws__SODAParser(envelope);
        // Check if System Function - these functions begins with SYS: For Example SYS:WebServiceConnect
        if (soda.methodName.indexOf("SYS:")==0) isoda=ws__SYSFunction();
    }

    // check if internal system function returned any data
    if(!isoda) {
        // Not System Function - continue with dispatch & invoke dispatch events if created
        continueDispatch=true;
        // trigger dispatch event
        if (wso_hasDispatchEvent) {
            value=ws__invokeEvent("dispatch");
            if (value==false) {
                // send error (E4) message to client - connection rejected
                isoda = ws__createSODAEnvelope(soda.methodName,null,"E4",wso_sodaErrorText["E4"]);
                continueDispatch=false;
            }else if(typeof(value)=="string") {
                // send error (E1) message to client - system error
                isoda = ws__createSODAEnvelope(soda.methodName,null,"E1",wso_sodaErrorText["E1"]+ " : "+value+" while executing dispatch event")
                continueDispatch=false;
            }
        }
    }

    // dispatch support for multiple method calls
    if (continueDispatch) {
        var mn,mns,ar=[];
        var result,params,byVals;

        // get method name(s) sent by client
        mn=soda.methodName;
        if(mn && mn.indexOf(",")>=0) mns=mn.split(',');
        else mns=[mn];

        // loop through requested methods
        for(c=0;c<mns.length;c++){

            // look up method name in wso_dispatch
            mn=mns[c];
            m=wso_dispatch[mn];

            // check for a valid method name
            if(!m) {
                // invalid name - send error message (E2) to client - method not found
                isoda = ws__createSODAEnvelope(mn,null,"E2",wso_sodaErrorText["E2"]+" '"+mn+"'");
                break;
            }else if (!soda.value) {
                // invalid data value - send error message (E3) to client - soda format not valid
                isoda = ws__createSODAEnvelope(mn,null,"E3",wso_sodaErrorText["E3"]);
                break;
            }else {

                // get params/arguments for the requested method
                if(mns.length==1) byVals=soda.value;
                else byVals=soda.value[c];

                // get local params/arguments and the returned data type for the dispatched method
                params = m[0];
                returnDataType = m[1];
                wso_params=[];

                // build evaluation string
                s=mn+'(';
                for(i=0;i<params.length;i++){
                    if(params[i]) {
                        value=null;
                        p=params[i].split(":");
                        paramName=p[0];
                        dataType=p[1];
                        defaultValue=p[2];
                        if(byVals && byVals.length>i) {
                            value=byVals[i];
                            if (typeof(value)=="string" && value.indexOf("@RESULT#")==0) value=ar[value.substr(8)];
                        }
                        if(value==null && defaultValue) {
                            if(defaultValue=="false") value=false;
                            else if(defaultValue=="true") value=true;
                            else if(defaultValue=="null") value=null;
                            else value=defaultValue;
                        }
                        if(value!=null) value = ws__setDataType(value,dataType);
                        wso_params[i]=value;
                        s+=((i>0)? ",":"")+"wso_params["+i+"]";
                    }
                }
                s+=')';

                // execute method
                try {
                    // store result inside an array
                    result = ar[c] = ws__setDataType(eval(s),returnDataType);
                    if(mns.length==1) isoda = ws__createSODAEnvelope(mn,result);
                    else if((c+1)==mns.length) {
                        isoda = ws__createSODAEnvelope(soda.methodName,ar);
                    }
                } catch(e) {
                    isoda = ws__createSODAEnvelope(mn,null,"E1",wso_sodaErrorText["E1"]+" : "+e+" while executing '"+mn+"()'");
                    break;
                }
            }
        }
    }

    // send response back to client
    if(wso_helpMode) {
        // if in helpMode helpManager will handle the returned data
        ws__helpManager(true,result);
    }else if(wso_IOResponse=="text/xml") {
        ws__docWrite(isoda);
    }else {
        arr[arr.length] ="var wsSODAResponse='"+ isoda +"'";
        for(i in wso_vars){
            v=wso_vars[i]
            arr[arr.length]="var "+i+"='"+ ws__Var2SODA(v)+"'";
        }
        ws__docWrite(arr.join(";\n"));
    }
};


/* Enable Online Help - Enables/Disables online help/debugging mode */
function wsEnableOnlineHelp(b){
    wso_enableHelp=(b)? true:false;
};

/* Get Session ID - returns caller session id */
function wsGetSessionId(){
    if(wso_soda) return wso_soda.sid;
};

/* Is Help Mode - Returns true if in helpmode or false if not in help mode */
function wsIsHelpMode(){
    return (wso_helpMode)? true:false;
};

/* Raise Error - error number, error description */
function wsRaiseError(ecode,etext){
    var isoda;
    var mname=(!wso_soda)? "":wso_soda.methodName;
    if(ecode) etext=wso_sodaErrorText[ecode]+" "+((etext)? etext:"");
    isoda=ws__createSODAEnvelope(mname,null,ecode,etext);
    if(wso_IOResponse!="text/xml") isoda="var wsSODAResponse='"+ isoda +"'";
    ws__docWrite(isoda);
    wso_endDocWrite=true;
};

/* Set Comment - sets web service comment */
function wsSetComment(comment){
    wso_comment=comment+'';
};

/* Set Icon - set icon path and file name */
function wsSetIcon(ifile) {
    wso_iconfile=ifile;
};

/* Set Name - sets web service name */
function wsSetName(name){
    wso_name=name+'';
};



// Private Functions ------------------------------------------------

/* Create SODA Envelope */
function ws__createSODAEnvelope(method,body,ecode,etext){
    var s='<envelope>';
    if(method) s+='<method>'+ws__SODAStringEncode(method+'') +'</method>';
    if(ecode||etext) s+='<err>'+ ws__SODAStringEncode(ecode+'|'+etext) +'</err>';
    s+='<body>'+ws__Var2SODA(body) +'</body>'
    +'</envelope>';
    return s;
};

/* Help Manager - display and process online help */
function ws__helpManager(showResult,result){
    var url,soda,total;
    var i,v,t,c,dt,nv,cm,dm,params,template;
    var serviceHeading,serviceBody;
    var serviceIcon,serviceName,serviceComment;

    // check for help mode
    wso_helpMode = (wso_enableHelp && wsGetRequest("help")=="on")? true:false;

    // get url
    url=Request.ServerVariables("URL");

    // check if call or display method was requested
    cm=wsGetRequest("call");
    dm=wsGetRequest("display");

    serviceName=(wso_name)? wso_name:"SODA-RPC Web service";
    serviceComment=(wso_comment)? wso_comment:"A new way to communicate via the Internet";
    serviceIcon = (wso_iconfile)? '<img src="'+wso_iconfile+'" align="absmiddle" width="32" height="32" />':'';

    if(showResult) {
        // show result to user
        v=ws__object2String(result);
        serviceHeading='<b><font face="Arial" size="4" color="navy">Result From Method: <font color="blue">'+cm+'</font><font color="red">()</font></font></b><br><hr>';
        serviceBody='<blockquote><font face="Arial" size="3" color="navy"><pre>'+v+'</pre></font></blockquote><br>'
        +'<hr><p align="right"><font face="arial" size="2"><a href="'+url+'?help=on&display='+cm+'">Back</a> | <a href="'+url+'?help=on">Main</a></font></p>';
    }else {
        if(wsGetRequest("help")!="on"){
            // Splash Screen showing service name and comment
            showResult=true;
            if(!wso_enableHelp) serviceBody='';
            else{
                serviceBody='<p align="right"><font face="Arial" size="2">'
                +'<a href="'+url+'?help=on">Online Help</a></font>&nbsp;</p>'
            }
        }else if(cm && wso_helpMode){
            // create and return soda-object
            total=wsGetRequest("total")+'';
            total=(total==""||isNaN(total))? 0:parseInt(total);
            soda={
                sid:'',
                methodName:cm,
                value:[]
            }

            for(i=0;i<total;i++){
                v=wsGetRequest("txt"+i);
                dt=wsGetRequest("cbo"+i);
                // convert "v" to selected data type.
                if(dt=="array") v=(v+"").split(",");
                else if(dt=="object") {
                    t=v.split(',');
                    v={};
                    for(c=0;c<t.length;c++) {
                        nv=t[c].split(':');
                        v[nv[0]]=nv[1];
                    }
                }else {
                    v = ws__setDataType(v,dt);
                }
                soda.value[soda.value.length]=v;
            }
            return soda;
        }else if(dm && wso_helpMode) {
            // display method info
            c=0; showResult=true;
            serviceHeading='<b><font face="Arial" size="4" color="navy">Call Method: '
            +'<font color="blue">'+dm+'</font><font color="red">(</font></font></b><br><hr><font size="2" face="Arial">'+((wso_descriptions[dm])? wso_descriptions[dm]:"")+'</font>';
            serviceBody='<center><form name="frm" method="post" action="'+url+'?help=on&call='+dm+'"><input name="dummy" type="hidden" value="for ns4 only">';
            if(!wso_dispatch[dm]) return;
            params=wso_dispatch[dm][0];
            if(!(params.length && params[0])) serviceBody+='<p><font face="arial"><h2>No agruments required</h2></font></p>';
            else {
                serviceBody+='<table cellpadding="2" bgcolor="#ececec" border="0" style="font-family: Arial; font-size: 10pt">'
                +'<tr bgcolor="#ececec"><td><b>Arguments</b></td><td><b>Data Type</b></td><td><b>Default value</b></td><td><b>Description</b></td></tr>';
                for(c=0;c<params.length;c++){
                    t=params[c];
                    t=t.split(":");
                    serviceBody+='<tr>'
                    +'<td bgcolor="#FFFFFF" width="20%">'+((t[0]!=null)? t[0]:'&nbsp;')+':<br><input name="txt'+c+'" type="text" size="20"></td>'
                    +'<td bgcolor="#FFFFFF" width="20%">'+((t[1]!=null)? t[1]:'&nbsp;')+'<br>'
                    +'<select name="cbo'+c+'">'
                    +'<option value="null"'+((t[1]=='null')? ' selected':'')+'>null</option>'
                    +'<option value="array"'+((t[1]=='array')? ' selected':'')+'>array</option>'
                    +'<option value="boolean"'+((t[1]=='boolean')? ' selected':'')+'>boolean</option>'
                    +'<option value="date"'+((t[1]=='date')? ' selected':'')+'>date</option>'
                    +'<option value="float"'+((t[1]=='float')? ' selected':'')+'>float</option>'
                    +'<option value="integer"'+((t[1]=='integer')? ' selected':'')+'>integer</option>'
                    +'<option value="object"'+((t[1]=='object')? ' selected':'')+'>object</option>'
                    +'<option value="string"'+((t[1]=='string')? ' selected':'')+'>string</option>'
                    +'</select></td>'
                    +'<td bgcolor="#FFFFFF" width="20%" align="center">'+((t[2]!=null)? t[2]:'variant')+'</td>';

                    // get parameter description
                    t=wso_descriptions[dm+":"+t[0]];

                    serviceBody+='<td bgcolor="#FFFFFF" width="40%" valign="top">'+((t)? t:'&nbsp;')+'</td></tr>';
                }
                serviceBody+='</table><input name="total" type="hidden" value="'+params.length+'">';
            }
            serviceBody+='</form></center><font face="arial" size="4" color="red"><b>)</b></font><table width="90%"><tr><td align="right"><font face="arial" size="2"><a href="'+url+'?help=on">Main</a> | <a href="javascript:void(null);" onclick="document.forms[\'frm\'].submit();return false;">Execute</a></font>&nbsp;</td></tr>'
            +'<tr><td><hr><font face="arial" size="2"><u>Object</u> can be represented as: fname:Mary,lname:Jane,email:mj@yahoo.com<br>'
            +'<u>Arrays</u> can be represented as: red,blue,green</font></td></tr></table>';

        }else if(wso_helpMode){
            // display main page
            showResult=true;
            serviceHeading='<font face="Arial" size="4" color="navy"><b>Available Methods</b></font><br><hr>';
            serviceBody='<table border="0" width="90%" cellspacing="0" style="font-family: Arial; font-size: 12pt">';
            var bgcolor,mod=0;
            for(i in wso_dispatch){
                t=wso_descriptions[i];
                if(!t) t='&nbsp;';
                mod+=1;
                if((mod % 2)==0) bgcolor="#EEEEEE";
                else bgcolor="#FFFFFF"
                serviceBody+='<tr bgcolor="'+bgcolor+'"><td width="25%"><font color="blue"><b>&nbsp;'+i+'<font color="red">(</font></b></font></td><td width="75%"><font face="arial" size="2">'+t+'</font></td></tr>'
                +'<tr bgcolor="'+bgcolor+'"><td width="100%" colspan="2">';
                params=wso_dispatch[i][0];
                if(!(params.length && params[0])) serviceBody+='<p>&nbsp;</p>';
                else {
                    serviceBody+='<br><center><table bgcolor="#c0c0c0" border="0" width="95%" cellpadding="2" cellspacing="1" style="font-family: Arial; font-size: 10pt">'
                    serviceBody+='<tr bgcolor="#eeeeee"><td><b>Arguments</b></td><td><b>Data Type</b></td><td><b>Default value</b></td><td><b>Description</b></td></tr>'
                    for(c=0;c<params.length;c++){
                        t=params[c];
                        t=t.split(":");
                        serviceBody+='<tr>'
                        +'<td bgcolor="#FFFFFF" width="20%">&nbsp;'+((t[0]!=null)? t[0]:'&nbsp;')+'</td>'
                        +'<td bgcolor="#FFFFFF" width="20%">'+((t[1]!=null)? t[1]:'&nbsp;')+'</td>'
                        +'<td bgcolor="#FFFFFF" width="20%" align="center">'+((t[2]!=null)? t[2]:'variant')+'</td>';

                        // get parameter description
                        t=wso_descriptions[i+":"+t[0]];

                        serviceBody+='<td bgcolor="#FFFFFF" width="40%">'+((t)? t:'&nbsp;')+'</td></tr>';
                    }
                    serviceBody+='</table></center><br>'
                }
                serviceBody+='<font color="red"><b>)</b></font><font face="arial" size="2"> - Returns '+((wso_dispatch[i][1]!=null)? wso_dispatch[i][1]:'variant')+' data type</font></td></tr>'
                +'<tr><td colspan="2" align="right"><font face="arial" size="2"><a href="'+url+'?help=on&display='+i+'">View</a></font>&nbsp;</td></tr>'
                +'<tr><td colspan="2"><hr size="1" color="#EEEEEE"></td></tr>'
            }
            serviceBody+='</table>';

        }
    }

    if(showResult){
        template='<html><head><title>service_name - (SODA-RPC)</title><style>a:hover {color:red}</style></head><body link="#0000FF" vlink="#0000FF">'
        if(wsGetRequest("help")!="on"){
            // spash screen template
            template+='<p align="center">&nbsp;</p><p align="center">&nbsp;</p>'
            +'<center><table border="0"><tr>'
            +'<td width="100%" align="center"><b>service_icon <font face="Arial" size="5">service_name</font></b></td>'
            +'</tr><tr><td width="100%" align="center" bgcolor="#eeeeee"><font size="2" face="Arial">service_comment</font></td></tr>'
            +'<tr><td width="100%" align="center">service_body</td></tr>'
            +'</table><center>';
        }else{
            // help/debug template
            template+='<table border="0" width="100%" cellpadding="2"  bgcolor="#E0E0E0">'
            +'<tr><td width="100%"  bgcolor="#FFFFFF">'
            +'<p>service_icon <b><font face="Arial" color="#000000" size="6">service_name</font></b></p>'
            +'</td></tr><tr><td width="100%" bgcolor="#EEEEEE">'
            +'<p><font face="Arial" size="2">service_comment</font></p>'
            +'</td></tr></table><blockquote>'
            +'<p>service_heading</p>'
            +'service_body</blockquote>';
        }
        template+='</body></html>'

        template=template.replace(/service_icon/g,serviceIcon);
        template=template.replace(/service_name/g,serviceName);
        template=template.replace(/service_comment/g,serviceComment);
        template=template.replace(/service_heading/g,serviceHeading);
        template=template.replace(/service_body/g,serviceBody);

        Response.Write(template);
    }

};

/* Invoke Event - Invokes the server-side events dispatch and login */
function ws__invokeEvent(evnt){
    try {
        if (evnt=="dispatch" && wso_hasDispatchEvent) return wso_eventDispatch();
        else if (evnt=="login" && wso_hasLoginEvent) {
            var uid,pwd,sid;
            if(wso_soda){
                uid=wso_soda.uid;
                pwd=wso_soda.pwd;
                sid=wso_soda.sid;
            }
            return wso_eventLogin(uid,pwd,sid);
        }else if (evnt=="logout" && wso_hasLogoutEvent) {
            return wso_eventLogout();
        }
    }catch(e){
        return e.name+" - "+e.description+"";
    }
};

/* Object 2 String */
function ws__object2String(o,tablvl){
    var i,s,v="",tabs="";
    var itabs="";

    // set tab spaces
    tablvl=(tablvl)? tablvl:0;
    tablvl=tablvl+1;
    for(i=0;i<tablvl;i++) tabs+="\t";
    for(i=0;i<tablvl-1;i++) itabs+="\t";

    s=(o+"");
    if(typeof(o)=="object" && s.indexOf(",")>=0 && s.indexOf("[object")!=0){
        // assume o is an array
        var ar=[];
        for (i=0;i<o.length;i++){
            ar[i]=ws__object2String(o[i],tablvl);
        }
        s="[<br>"+tabs+ar.join(",")+"<br>"+itabs+"]";
    }else if(typeof(o)=="object"){
        for(i in o){
            if(v) v+=",<br>";
            v+=(tabs+i+":"+ws__object2String(o[i],tablvl));
        }
        s=itabs+"{<br>"+v+"<br>"+itabs+"}";
    }
    return s;
};

/* System Function - Executes system functions such as "WebServiceConnect" */
function ws__SYSFunction(){
    var found=false;
    var i,rt,ec,et,o={};
    var mn=(wso_soda)? wso_soda.methodName:'';

    switch (mn) {
        case "SYS:WebServiceConnect":{
            // get service name and comment
            o["name"]=wso_name;
            o["comment"]=wso_comment;
            // return method names if RCF = text/xml
            if (wso_IOResponse=="text/xml"){
                var a=[];
                for(i in wso_dispatch){ a[a.length]=i }
                rt=a.join(",");
                o["methodNames"]=rt;
            }
            // do login
            if (wso_hasLoginEvent) {
                rt=ws__invokeEvent("login");
                if (rt==true) rt="ok";
                else {
                    if(typeof(rt)=="string") {
                        //expecting errors to be string
                        et=rt; ec="";
                    }
                    rt="failed";
                }
            }else{
                rt="ok";
            }
            o["login"]=rt;
            found=true;
            break;
        }

        case "SYS:WebServiceDisconnect":{
            if (wso_hasLogoutEvent) {
                rt=ws__invokeEvent("logout");
                if (rt==true) rt="ok";
                else {
                    if(typeof(rt)=="string") {
                        //expecting errors to be string
                        et=rt; ec="";
                    }
                    rt="failed";
                }
            }else {
                rt="ok";
            }
            o["logout"]=rt;
            found=true;
            break;
        }
    }

    if(found){
        o["SYSCall"]=true;
        return ws__createSODAEnvelope(mn,o,ec,et);
    }
}

/* Set Data Type - convert a value to a specific data type*/
function ws__setDataType(value,dt){
    if(!dt) return null;
    else {
        var v;
        if(dt=="string") v=value+'';
        else if(dt=="date") {
            v=(value)? new Date(value):null;
            if((v+"")=="NaN") v=null;
        }else if (dt=="integer") {
            v=parseInt(value); if((v+"")=="NaN") v=0;
        }else if(dt=="float") {
            v=parseFloat(value); if((v+"")=="NaN") v=0.00;
        }else if(dt=="boolean"){
            v=(value==true||value>0||(value+"").toLowerCase()=="true")? true:false;
        }else if(dt=="array") {
            if (value && value.constructor!=Array) v=[value];
            else v=value;
        }else if(dt=="object"){
            if (typeof(value)!="object") v={};
            else v=value;
        }else {
            v=null;
        }
        return v;
    }
}

// SODA Internal Data Types: U=undefined, I=integer, F=float, B=boolean, D=date/time, S=string, A=array, O=Object (Associative Array)
ws__Var2SODA=function(v,lvl){
    var ot,ct,i,c,data,vtype=typeof(v);

    if (lvl>=0)lvl++;
    else lvl=0;

    if(vtype=="number") {
        if((v+'').indexOf('.')>=0) data='<f'+lvl+'>'+v+'</f'+lvl+'>';
        else data='<i'+lvl+'>'+v+'</i'+lvl+'>';
    }else if(vtype=="boolean") {
        if (v==true) data='<b'+lvl+'>true</b'+lvl+'>';
        else data='<b'+lvl+'>false</b'+lvl+'>';
    }else if(vtype=="string") {
        data='<s'+lvl+'>'+ws__SODAStringEncode(v)+'</s'+lvl+'>';
    }else if(vtype=="object" && v!=null) {
        if(v.constructor==Array){
            data='<a'+lvl+'>';
            for (i=0;i<v.length;i++){
                data+=(i>0)? '<r'+lvl+'/>'+ws__Var2SODA(v[i],lvl):ws__Var2SODA(v[i],lvl)
            }
            data+='</a'+lvl+'>';
        }else if(v.constructor==Date){
            //Date format: mm/dd/yyyy hh:nn:ss
            v=((v.getMonth()+1)+'/'+v.getDate()+'/'+v.getFullYear()+' '+v.getHours()+':'+v.getMinutes()+':'+v.getSeconds());
            data='<d'+lvl+'>'+v+'</d'+lvl+'>';
        }else {
            var keys=[],values=[];
            for(var key in v){
                values[values.length]=v[key];
                if (key.indexOf("|")>=0) key=key.replace(/\|/g,"&s;");
                keys[keys.length]=key;
            }
            v=[keys.join('|'),values];
            data='<o'+lvl+'>'+ws__Var2SODA(v,lvl)+'</o'+lvl+'>';
        };
    }else data='<u'+lvl+'>0</u'+lvl+'>';
    if (lvl==0) data='<soda>'+data+'</soda>'
    return data;
};
ws__SODA2Var=function(t,lvl){
    var tag,data,elms;
    var tagType,tagIndex;

    if (lvl>=0)lvl++;
    else lvl=0;

    if(lvl==0) {
        if((t+"").substr(0,6)!="<soda>") return t;
        tag=ws__getSODATag(t,"soda");t=tag.content;
    }

    tag=ws__getSODATag(t);
    tagType=tag.name.substr(0,1);
    tagIndex=tag.name.substr(1);
    if(tagType=="i") data=parseInt(tag.content);
    else if(tagType=="f") data=parseFloat(tag.content);
    else if(tagType=="b") data=(tag.content=="true")?true:false;
    else if(tagType=="s") data=ws__SODAStringDecode(tag.content+'');
    else if(tagType=="d") data= new Date(tag.content);
    else if(tagType=="a") {
        data=[];
        if(tag.content){
            elms=tag.content.split("<r"+tagIndex+"/>");
            for (var i=0;i<elms.length;i++){
                data[i]=ws__SODA2Var(elms[i],lvl);
            }
        }
    }else if(tagType=="o") {
        data={};
        elms=ws__SODA2Var(tag.content,lvl)
        if(!elms) elms=[];
        var key,keys=(elms[0]+"").split("|");
        var values=elms[1];
        for (var i=0;i<keys.length;i++) {
            key=keys[i];
            if(key.indexOf("&s;")>=0) key=key.replace(/\&s\;/g,"|");
            data[key]=values[i]
        }
    }else if(tagType=="u") data=null;

    return data;
};
ws__SODAStringEncode=function (text){
    if (!text) return "";
    // encode string for use with javascript
    if (wso_IOResponse!="text/xml") {
        text=text.replace(/\\/g,"\\\\");    // replace \ with \\
        text=text.replace(/\'/g,"\\'");     // replace ' with \'
        text=text.replace(/\n/g,"\\n");
        text=text.replace(/\r/g,"\\r");
    }
    // encode string for use with both html and xml
    text=text.replace(/\&/g,"&amp;");
    text=text.replace(/</g,"&lt;");
    text=text.replace(/>/g,"&gt;");
    return text;
};
ws__SODAStringDecode=function (text){
    if (!text) return "";
    text=text.replace(/\&amp\;/g,"&");
    text=text.replace(/\&lt\;/g,"<");
    text=text.replace(/\&gt\;/g,">");
    return text;
};
ws__getSODATag=function(t,n){
    var st,et,tag,con;
    if(!t) return {};
    n=(n)?n:'';
    st=t.indexOf('<'+n);

    // Don not look for an end tag if you did not find a start tag
    if ( st >= 0 ) {
        et=t.indexOf('>',st);
    }

    if ( et > 0 ) {
        tag=t.substr(st+1,(et-1)-st);
        st=et+1;
        et=t.indexOf('</'+tag+'>');
        con=t.substr(st,et-st)
    }
    return {name:tag,content:con};
};
ws__SODAParser=function(envelope){
    var r={
        sid:ws__getSODATag(envelope,"sid").content,
        uid:ws__getSODATag(envelope,"uid").content,
        pwd:ws__getSODATag(envelope,"pwd").content,
        error:ws__SODAStringDecode(ws__getSODATag(envelope,"err").content),
        methodName:ws__SODAStringDecode(ws__getSODATag(envelope,"method").content),
        value:ws__SODA2Var(ws__getSODATag(envelope,"body").content)
    }
    if(r.error) {
        var ea=r.error.split("|");
        r.error={code:ea[0],text:ea[1]}
    }else if((envelope+"").indexOf("<envelope>")!=0){
        r.error={code:"E3",text:wso_sodaErrorText["E3"]};
    };
    return r;
};


%>