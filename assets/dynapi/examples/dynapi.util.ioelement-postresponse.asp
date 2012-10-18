<html>
<script>
<!--
var dynapi = parent.dynapi;
if (dynapi) {
	// run init() when this file loads
	parent.IOElement.notify(this, init);

	// find the filename to output to the debugger
	var url = this.src || this.location.href || this.document.location.href;
	url = url.substring(url.lastIndexOf('/')+1,url.indexOf('?'));
}

function init() {
	dynapi.debug.print('loaded '+url);
}

<%

'generate javascript variables from ASP Code

Response.write "var response = 'Your name is "+Request("name")+", and your favourite color is "+Request("color")+"';"

%>
//-->
</script>
<body></body>
</html>