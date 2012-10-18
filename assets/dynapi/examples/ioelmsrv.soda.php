<?php

/*
 * IOElement Server SODA-RPC Library - For PHP Servers
 * For use with DynAPI IOElementSoda client-side javascript
 *
 * The DynAPI Distribution is distributed under the terms of the GNU LGPL license.
 *
 * Requires: IOElement Server Library (JavaScript)
 *
 * Web Service Data Types: integer, float, string, date, array, object (associative array)
 */

$wso_name     = ""; // Web service name
$wso_comment  = ""; // Web service comment
$wso_iconfile = ""; // stores icon file name and path

$wso_helpMode   = FALSE; // True if in help mode
$wso_enableHelp = FALSE; // True if online help mode is enabled

$wso_dispatch     = array(); // stores method names to be dispatch to client
$wso_soda         = array(); // soda object
$wso_params       = array(); // stores parameter values to be passed to mehtod
$wso_descriptions = array(); // stores descriptions for methods and their parameters

$wso_eventLogin    = NULL;
$wso_eventLogout   = NULL;
$wso_eventDispatch = NULL;

$wso_hasLoginEvent    = FALSE;
$wso_hasLogoutEvent   = FALSE;
$wso_hasDispatchEvent = FALSE;

$wso_sodaErrorText = array(
    "E1" => "System Error",
    "E2" => "Method not found",
    "E3" => "Error occurred while parsing SODA Envelope",
    "E4" => "Connection rejected by web service"
);

/* Add Description - Adds a description to a method or its parameters */
function wsAddDescription ( $name, $text )
{
    global $wso_descriptions;

    // name = "methodname" or "methodname:parameter"
    if ( $name )
    {
        $wso_descriptions[ $name ] = $text;
    }
};

/* Add Error Code - Adds an error code to the error code collection - used mainly with wsRaiseError() */
function wsAddErrorCode ( $code, $text )
{
    global $wso_sodaErrorText;

    $wso_sodaErrorText[ $code ] = $text;
};

/* Add Method - Adds a method to be dispatched or made a publicly available via the service */
function wsAddMethod( $name, $params, $rtype )
{
    //  name = name of method - e.g. "myMethod"
    //  params = ['param1:data_type:default_value','param2:data_type:default_value',...]
    //  rtype = returned data type

    global $wso_dispatch;

    if ( ! is_array( $params ) || ! $params )
    {
        $params = array( $params );
    }

    $wso_dispatch[ $name ] = array( $params, $rtype );
};

/* Capture Event - Server-side events to be triggered during wsDispatch() (events:dispatch,login,logout) */
function wsCaptureEvent ( $evnt, $fn )
{
    global $wso_eventDispatch, $wso_hasDispatchEvent, $wso_eventLogin,
        $wso_hasLoginEvent, $wso_eventLogout, $wso_hasLogoutEvent;

    switch ( $evnt )
    {
        case "dispatch":
            $wso_eventDispatch    = $fn;
            $wso_hasDispatchEvent = TRUE;
            break;

        case "login":
            $wso_eventLogin    = $fn;
            $wso_hasLoginEvent = TRUE;
            break;

        case "logout":
            $wso_eventLogout    = $fn;
            $wso_hasLogoutEvent = TRUE;
            break;

        default:
    }
};

/* Dispatch - dispatches methods and variables */
function wsDispatch ()
{
    // from ioelmsrv.php
    global $wso_IOResponse, $wso_vars;

    // from ioelmsrv.soda.php
    global $wso_soda, $wso_hasDispatchEvent, $wso_sodaErrorText,
           $wso_dispatch, $wso_params, $wso_helpMode;

    $continueDispatch = FALSE;
    $m = NULL;
    $p = NULL;
    $s = NULL;
    $value = NULL;
    $isoda = NULL;
    $html = NULL;
    $arr = array();
    $defaultValue = NULL;
    $dataType = NULL;
    $paramName = NULL;
    $returnDataType = NULL;
    $envelope = NULL;
    $soda = NULL;

    // get SODA-RPC envelope
    $envelope = wsGetRequest( "IOEnvelope" );

    // get Response Type - defaults to text/html
    $wso_IOResponse = wsGetRequest( "IOResponse" );

    if( ! $wso_IOResponse )
    {
        $wso_IOResponse = "text/html";
    }

    // check if envelope is available
    if( ! $envelope )
    {
        // display help or splash screen if no evelope was sent
        $soda = ws__helpManager( FALSE, NULL );

        if( ! $soda )
        {
            return;
        }
        else
        {
            $wso_soda = $soda;
        }
    }
    else
    {
        // parse SODA-RPC envelope
        $soda = $wso_soda = ws__SODAParser( $envelope );

        // Check if System Function - these functions begins with SYS: For Example SYS:WebServiceConnect
        if ( strpos( $soda[ "methodName" ], "SYS:" ) === 0 )
        {
            $isoda = ws__SYSFunction();
        }
    }

    // check if internal system function returned any data
    if ( ! $isoda )
    {
        // Not System Function - continue with dispatch & invoke dispatch events if created
        $continueDispatch = TRUE;

        // trigger dispatch event
        if ( $wso_hasDispatchEvent )
        {
            $value = ws__invokeEvent( "dispatch" );
            $mn = $soda[ "methodName" ];

            if ( $value == FALSE )
            {
                // send error (E4) message to client - connection rejected
                $isoda = ws__createSODAEnvelope( $mn, NULL, "E4", $wso_sodaErrorText[ "E4" ] );
                $continueDispatch = FALSE;
            }
            else if ( is_string( $value ) )
            {
                // send error (E1) message to client - system error
                $isoda = ws__createSODAEnvelope( $mn, NULL, "E1", $wso_sodaErrorText[ "E1" ] . " : " . $value . " while executing dispatch event" );
                $continueDispatch = FALSE;
            }
        }
    }

    // dispatch support for multiple method calls
    if ( $continueDispatch )
    {
        $mn = NULL;
        $mns = NULL;
        $ar = array();
        $result = NULL;
        $params = NULL;
        $byVals = NULL;

        // get method name(s) sent by client
        $mn = $soda[ "methodName" ];
        $pos = strpos( $mn, "," );

        if ( $mn && $pos !== FALSE && $pos >= 0 )
        {
            $mns = explode( ",", $mn );
        }
        else
        {
            $mns = array( $mn );
        }

        $mns_length = count( $mns );

        // loop through requested methods
        for ( $c = 0; $c < $mns_length; $c++ )
        {
            // look up method name in wso_dispatch
            $mn = $mns[ $c ];
            $m  = $wso_dispatch[ $mn ];

            // check for a valid method name
            if ( ! $m )
            {
                // invalid name - send error message (E2) to client - method not found
                $isoda = ws__createSODAEnvelope( $mn, NULL, "E2", $wso_sodaErrorText[ "E2" ] . " '" . $mn . "'" );
                break;
            }
            else if ( ! $soda[ $value ] )
            {
                // invalid data value - send error message (E3) to client - soda format not valid
                $isoda = ws__createSODAEnvelope( $mn, NULL, "E3", $wso_sodaErrorText[ "E3" ] );
                break;
            }
            else
            {
                // get params/arguments for the requested method
                if ( $mns_length == 1 )
                {
                    $byVals = $soda[ "value" ];
                }
                else
                {
                    $byVals = $soda[ "value" ][ $c ];
                }

                // get local params/arguments and the returned data type for the dispatched method
                $params         = $m[0];
                $returnDataType = $m[1];

                // build evaluation string
                $s = $mn . "(";

                $params_length = count( $params );
                $byVals_length = count( $byVals );
                for ( $i = 0; $i < $params_length; $i++ )
                {
                    if ( $params[ $i ] )
                    {
                        $value        = NULL;
                        $p            = explode( ":", $params[ $i ] );
                        $paramName    = $p[0];
                        $dataType     = $p[1];
                        $defaultValue = $p[2];

                        if ( $byVals && $byVals_length > $i )
                        {
                            $value = $byVals[ $i ];

                            if ( is_string( $value ) && strpos( "@RESULT#", $value ) === 0 )
                            {
                                // $ar is currently NULL!
                                $value = $ar[ substr( $value, 8 ) ];
                            }
                        }

                        if ( $value == NULL && $defaultValue )
                        {
                            if ( $defaultValue == "false" ) $value = FALSE;
                            else if ( $defaultValue == "true" ) $value = TRUE;
                            else if ( $defaultValue == "null" ) $value = NULL;
                            else $value = $defaultValue;
                        }

                        if ( $value != NULL )
                        {
                            $value = ws__setDataType( $value, $dataType );
                        }

                        $wso_params[ $i ] = $value;
                        $s .= ( ( $i > 0 ) ? "," : "" ) . "\$wso_params[" . $i . "]";
                    }
                }

                $s .= ");";

/*
                // execute method
                try
                {
                    // store result inside an array
                    result = ar[ c ] = ws__setDataType( eval( s ), returnDataType );

                    if ( mns.length == 1 )
                    {
                        isoda = ws__createSODAEnvelope( mn, result );
                    }
                    else if ( ( c + 1 ) == mns.length )
                    {
                        isoda = ws__createSODAEnvelope( soda.methodName, ar );
                    }
                }
                catch( e )
                {
                    isoda = ws__createSODAEnvelope( mn, null, "E1", wso_sodaErrorText[ "E1" ] + " : " + e + " while executing '" + mn + "()'" );
                    break;
                }
 */

                // execute method
                // store result inside an array
                // This is VERY UGLY in PHP4, probably won't even work right.
                // PHP5 has try...catch...throw builtin, but isn't stable yet.

                $try_code = "$result = \$ar[ $c ] = ws__setDataType( eval( $s ), $returnDataType );" .
                            "$mns_length = count( $mns );" .
                            "if ( $mns_length == 1 )" .
                            "{" .
                            "    $isoda = ws__createSODAEnvelope( $mn, $result );" .
                            "}" .
                            "else if ( ( $c + 1 ) == $mns_length )" .
                            "{" .
                            "    $isoda = ws__createSODAEnvelope( \$soda[ 'methodName' ], $ar );" .
                            "}";
                $catch_code = '$isoda = ws__createSODAEnvelope( ' . $mn . ', NULL, "E1", ' . $wso_sodaErrorText[ "E1" ] . ' : $php_errormsg while executing ' . $mn . '() );' .
                            'break;';

                try_catch( $try_code, $catch_code );
            }
        }
    }

    // send response back to client
    if ( $wso_helpMode )
    {
        // if in helpMode helpManager will handle the returned data
        ws__helpManager( TRUE, $result );
    }
    else if ( $wso_IOResponse == "text/xml" )
    {
        ws__docWrite( $isoda );
    }
    else
    {
        $arr[ 0 ] = "var wsSODAResponse='" . $isoda . "'";

        $i = 1;
        foreach ( $wso_vars as $key => $value )
        {
            $arr[ $i ] = "var " . $key . "='" . ws__Var2SODA( $value, NULL ) . "'";
            $i++;
        }

        ws__docWrite( implode( ";\n", $arr ) );
    }
};

/* Enable Online Help - Enables/Disables online help/debugging mode */
function wsEnableOnlineHelp ( $b )
{
    global $wso_enableHelp;

    $wso_enableHelp = ( $b ) ? TRUE : FALSE;
};

/* Get Session ID - returns caller session id */
function wsGetSessionId ()
{
    global $wso_soda;

    if ( $wso_soda )
    {
        return $wso_soda[ "sid" ];
    }
};

/* Is Help Mode - Returns true if in helpmode or false if not in help mode */
function wsIsHelpMode ()
{
    global $wso_helpMode;

    return ( $wso_helpMode ) ? TRUE : FALSE;
};

/* Raise Error - error number, error description */
function wsRaiseError ( $ecode, $etext )
{
    global $wso_soda, $wso_sodaErrorText, $wso_IOResponse, $wso_endDocWrite;

    $isoda;
    $mname = ( ! $wso_soda ) ? "" : $wso_soda[ "methodName" ];

    if ( $ecode )
    {
        $etext = $wso_sodaErrorText[ $ecode ] . " " . ( ( $etext ) ? $etext : "" );
    }

    $isoda = ws__createSODAEnvelope( $mname, NULL, $ecode, $etext );

    if ( $wso_IOResponse != "text/xml" )
    {
        $isoda = "var wsSODAResponse='" . $isoda . "'";
    }

    ws__docWrite( $isoda );
    $wso_endDocWrite = TRUE;
};

/* Set Comment - sets web service comment */
function wsSetComment ( $comment )
{
    global $wso_comment;

    $wso_comment = $comment;
};

/* Set Icon - set icon path and file name */
function wsSetIcon ( $ifile )
{
    global $wso_iconfile;

    $wso_iconfile = $ifile;
};

/* Set Name - sets web service name */
function wsSetName ( $name )
{
    global $wso_name;

    $wso_name = "$name";
};


// Private Functions ------------------------------------------------

/* Create SODA Envelope */
function ws__createSODAEnvelope ( $method, $body, $ecode, $etext )
{
    $s = "<envelope>";

    if ( $method )
    {
        $s .= "<method>" . ws__SODAStringEncode( $method ) . "</method>";
    }

    if ( $ecode || $etext )
    {
        $s .= "<err>" . ws__SODAStringEncode( "$ecode|$etext" ) . "</err>";
    }

    $s .= "<body>" . ws__Var2SODA( $body, NULL ) . "</body>"
        . "</envelope>";

    return $s;
};

/* Help Manager - display and process online help */
function ws__helpManager ( $showResult, $result )
{
    global $wso_helpMode, $wso_enableHelp, $wso_name, $wso_comment,
           $wso_descriptions, $wso_dispatch, $wso_iconfile;

    /*
    $url, $soda, $total;
    $i, $v, $t, $c, $dt, $nv, $cm, $dm, $params, $template;
    $serviceHeading, $serviceBody;
    $serviceIcon, $serviceName, $serviceComment;
     */

    // check for help mode
    $wso_helpMode = ( $wso_enableHelp && wsGetRequest( "help" ) == "on" ) ? TRUE : FALSE;

    // get url
    $url = "http://" . $_SERVER[ 'SERVER_NAME' ] . $_SERVER[ 'PHP_SELF' ];

    // check if call or display method was requested
    $cm = wsGetRequest( "call" );
    $dm = wsGetRequest( "display" );

    $serviceName = ( $wso_name ) ? $wso_name : "SODA-RPC Web service";
    $serviceComment = ( $wso_comment ) ? $wso_comment : "A new way to communicate via the Internet";
    $serviceIcon = ( $wso_iconfile ) ? '<img src="' . $wso_iconfile . '" align="absmiddle" width="32" height="32" />' : "";

    if ( $showResult )
    {
        // show result to user
        $v = ws__object2String( $result, 0 );
        $serviceHeading = '<B><FONT FACE="Arial" SIZE="4" COLOR="navy">Result From Method: <FONT COLOR="blue">' . $cm . '</FONT><FONT COLOR="red">()</FONT></FONT></B><br /><hr />';
        $serviceBody = '<blockquote><font face="Arial" size="3" color="navy"><pre>' . $v . '</pre></font></blockquote><br />' .
            '<hr /><p align="right"><font face="arial" size="2"><a href="' . $url . '?help=on&display=' . $cm . '">Back</a> | <a href="' . $url . '?help=on">Main</a></font></p>';
    }
    else
    {
        if ( wsGetRequest( "help" ) != "on" )
        {
            // Splash Screen showing service name and comment
            $showResult = TRUE;

            if ( ! $wso_enableHelp )
            {
                $serviceBody = "";
            }
            else
            {
                $serviceBody = '<p align="right"><font face="Arial" size="2">' .
                    '<a href="' . $url . '?help=on">Online Help</a></font>&nbsp;</p>';
            }
        }
        else if ( $cm && $wso_helpMode )
        {
            // create and return soda-object
            $total = wsGetRequest( "total" ) . "";
            $total = ( $total == "" || is_nan( $total ) ) ? 0 : sprintf( "%d", $total );
            $soda = array(
                "sid" => "",
                "methodName" => $cm,
                "value" => array()
            );

            for ( $i = 0; $i < $total; $i++ )
            {
                $v = wsGetRequest( "txt$i" );
                $dt = wsGetRequest( "cbo$i" );

                // convert "v" to selected data type.
                if( $dt == "array" )
                {
                    $v = explode( ",", "$v" );
                }
                else if ( $dt == "object")
                {
                    $t = explode( ",", $v );
                    $v = array();

                    $t_length = count($t);
                    for ( $c = 0; $c < $t_length; $c++ )
                    {
                        $nv = explode( ":", $t[ $c ] );
                        $v[ $nv[0] ] = $nv[1];
                    }
                }
                else
                {
                    $v = ws__setDataType( $v, $dt );
                }

                array_push( $soda, $v );
            }

            return $soda;

        }
        else if ( $dm && $wso_helpMode )
        {
            // display method info
            $c = 0;
            $showResult = TRUE;
            $serviceHeading = '<b><font face="Arial" size="4" color="navy">Call Method: ' .
                '<font color="blue">' . $dm . '</font><font color="red">(</font></font></b><br /><hr /><font size="2" face="Arial">' . ( ( $wso_descriptions[ $dm ] ) ? $wso_descriptions[ $dm ] : "" ) . '</font>';
            $serviceBody = '<center><form name="frm" method="post" action="' . $url . '?help=on&call=' . $dm . '"><input name="dummy" type="hidden" value="for ns4 only">';

            if ( ! $wso_dispatch[ $dm ] )
            {
                return;
            }

            $params = $wso_dispatch[ $dm ][0];

            $params_length = count( $params );
            if ( ! ( $params_length && $params[0] ) )
            {
                $serviceBody .= '<p><font face="arial"><h2>No agruments required</h2></font></p>';
            }
            else
            {
                $serviceBody .= '<table cellpadding="2" bgcolor="#ececec" border="0" style="font-family: Arial; font-size: 10pt">' .
                    '<tr bgcolor="#ececec"><td><b>Arguments</b></td><td><b>Data Type</b></td><td><b>Default value</b></td><td><b>Description</b></td></tr>';

                for( $c = 0; $c < $params_length; $c++ )
                {
                    $t = $params[ $c ]; // This is overwritten by the next line?
                    $t = explode( ":", $t );
                    $serviceBody .= '<tr>'
                        . '<td bgcolor="#FFFFFF" width="20%">' . ( ( $t[0] != NULL ) ? $t[0] : '&nbsp;' ) . ':<br /><input name="txt' . $c . '" type="text" size="20"></td>'
                        . '<td bgcolor="#FFFFFF" width="20%">' . ( ( $t[1] != NULL ) ? $t[1] : '&nbsp;' ) . '<br />'
                        . '<select name="cbo' . $c . '">'
                        . '<option value="null"' . ( ( $t[1] == 'null' ) ? ' selected' : '' ) . '>null</option>'
                        . '<option value="array"' . ( ( $t[1] == 'array' ) ? ' selected' : '' ) . '>array</option>'
                        . '<option value="boolean"' . ( ( $t[1] == 'boolean' ) ? ' selected' : '' ) . '>boolean</option>'
                        . '<option value="date"' . ( ( $t[1] == 'date' ) ? ' selected' : '' ) . '>date</option>'
                        . '<option value="float"' . ( ( $t[1] == 'float' ) ? ' selected' : '' ) . '>float</option>'
                        . '<option value="integer"' . ( ( $t[1] == 'integer' ) ? ' selected' : '' ) . '>integer</option>'
                        . '<option value="object"' . ( ( $t[1] == 'object' ) ? ' selected' : '' ) . '>object</option>'
                        . '<option value="string"' . ( ( $t[1] == 'string' ) ? ' selected' : '') . '>string</option>'
                        . '</select></td>'
                        . '<td bgcolor="#FFFFFF" width="20%" align="center">' . ( ( $t[2] != NULL ) ? $t[2] : 'variant' ) . '</td>';

                    // get parameter description
                    $t = $wso_descriptions[ $dm . ":" . $t[0] ];

                    $serviceBody .= '<td bgcolor="#FFFFFF" width="40%" valign="top">' . ( ( $t ) ? $t : '&nbsp;' ) . '</td></tr>';
                }

                $serviceBody .= '</table><input name="total" type="hidden" value="' . $params_length . '">';
            }

            $serviceBody .= '</form></center><font face="arial" size="4" color="red"><b>)</b></font><table width="90%"><tr><td align="right"><font face="arial" size="2"><a href="' . $url . '?help=on">Main</a> | <a href="javascript:void(null);" onclick="document.forms[\'frm\'].submit();return false;">Execute</a></font>&nbsp;</td></tr>'
                . '<tr><td><hr /><font face="arial" size="2"><u>Object</u> can be represented as: fname:Mary,lname:Jane,email:mj@yahoo.com<br />'
                . '<u>Arrays</u> can be represented as: red,blue,green</font></td></tr></table>';

        }
        else if ( $wso_helpMode )
        {
            // display main page
            $showResult = TRUE;
            $serviceHeading = '<font face="Arial" size="4" color="navy"><b>Available Methods</b></font><br /><hr />';
            $serviceBody = '<table border="0" width="90%" cellspacing="0" style="font-family: Arial; font-size: 12pt">';

            $bgcolor = 0;
            $mod = 0;

            foreach ( $wso_dispatch as $key => $value)
            {
                if ( ! $value )
                {
                    $value = '&nbsp;';
                }

                $mod += 1;
                $bgcolor = ( ( $mod % 2 ) == 0 ) ? "#EEEEEE" : "#FFFFFF";
                $serviceBody .= '<tr bgcolor="' . $bgcolor . '"><td width="25%"><font color="blue"><b>&nbsp;' . $key . '<font color="red">(</font></b></font></td><td width="75%"><font face="arial" size="2">' . $value . '</font></td></tr>'
                    . '<tr bgcolor="' . $bgcolor . '"><td width="100%" colspan="2">';
                $params = $wso_dispatch[ $key ][0];

                $params_length = count( $params );

                if ( ! ( $params_length && $params[0] ) )
                {
                    $serviceBody .= '<p>&nbsp;</p>';
                }
                else
                {
                    $serviceBody .= '<br /><center><table bgcolor="#c0c0c0" border="0" width="95%" cellpadding="2" cellspacing="1" style="font-family: Arial; font-size: 10pt">'
                        . '<tr bgcolor="#eeeeee"><td><b>Arguments</b></td><td><b>Data Type</b></td><td><b>Default value</b></td><td><b>Description</b></td></tr>';

                    for ( $c = 0; $c < $params_length; $c++ )
                    {
                        $t = $params[ $c ]; // This is overwritten by the next line?
                        $t = explode( ":", $value );
                        $serviceBody .= '<tr>'
                            . '<td bgcolor="#FFFFFF" width="20%">&nbsp;' . ( ( isset( $t[0] ) && $t[0] != NULL ) ? $t[0] : '&nbsp;' ) . '</td>'
                            . '<td bgcolor="#FFFFFF" width="20%">' . ( ( isset( $t[1] ) && $t[1] != NULL ) ? $t[1] : '&nbsp;') . '</td>'
                            . '<td bgcolor="#FFFFFF" width="20%" align="center">' . ( ( isset( $t[2] ) && $t[2] != NULL ) ? $t[2] : 'variant' ) . '</td>';

                        // get parameter description
                        $t = $wso_descriptions[ $key . ":" . $t[0] ];
                        $serviceBody .= '<td bgcolor="#FFFFFF" width="40%">' . ( ( $t ) ? $t : '&nbsp;' ) . '</td></tr>';
                    }

                    $serviceBody .= '</table></center><br />';
                }

                $serviceBody .= '<font color="red"><b>)</b></font><font face="arial" size="2"> - Returns ' . ( ( $wso_dispatch[ $key ][1] != NULL ) ? $wso_dispatch[ $key ][1] : 'variant' ) . ' data type</font></td></tr>'
                    . '<tr><td colspan="2" align="right"><font face="arial" size="2"><a href="' . $url . '?help=on&display=' . $key . '">View</a></font>&nbsp;</td></tr>'
                    . '<tr><td colspan="2"><hr SIZE="1" COLOR="#EEEEEE" /></TD></TR>';
            }

            $serviceBody .= '</table>';
        }
    }

    if ( $showResult )
    {
        $template = '<html><head><title>service_name - (SODA-RPC)</title><style>a:hover {color:red}</style></head><body link="#0000FF" vlink="#0000FF">';

        if ( wsGetRequest( "help" ) != "on" )
        {
            // splash screen template
            $template .= '<p align="center">&nbsp;</p><p align="center">&nbsp;</p>'
                . '<center><table border="0"><tr>'
                . '<td width="100%" align="center"><b>service_icon <font face="Arial" size="5">service_name</font></b></td>'
                . '</tr><tr><td width="100%" align="center" bgcolor="#eeeeee"><font size="2" face="Arial">service_comment</font></td></tr>'
                . '<tr><td width="100%" align="center">service_body</td></tr>'
                . '</table><center>';
        }
        else
        {
            // help/debug template
            $template .= '<table border="0" width="100%" cellpadding="2"  bgcolor="#E0E0E0">'
                . '<tr><td width="100%"  bgcolor="#FFFFFF">'
                . '<p>service_icon <b><font face="Arial" color="#000000" size="6">service_name</font></b></p>'
                . '</td></tr><tr><td width="100%" bgcolor="#EEEEEE">'
                . '<p><font face="Arial" size="2">service_comment</font></p>'
                . '</td></tr></table><blockquote>'
                . '<p>service_heading</p>'
                . 'service_body</blockquote>';
        }

        $template .= '</body></html>';

        // global replace or not?  should only be once each?
        $template = str_replace( "service_icon", $serviceIcon, $template );
        $template = str_replace( "service_name", $serviceName, $template );
        $template = str_replace( "service_comment", $serviceComment, $template );
        $template = str_replace( "service_heading", $serviceHeading, $template );
        $template = str_replace( "service_body", $serviceBody, $template );

        echo $template;
    }
};

/* Invoke Event - Invokes the server-side events dispatch and login */
function ws__invokeEvent( $evnt )
{
/*
    global $wso_hasDispatchEvent, $wso_hasLoginEvent, $wso_soda, $wso_hasLogoutEvent;
    try
    {
        if ( $evnt == "dispatch" && $wso_hasDispatchEvent )
        {
            return wso_eventDispatch();
        }
        else if ( $evnt == "login" && $wso_hasLoginEvent )
        {
            if ( $wso_soda )
            {
                $uid = $wso_soda["uid"];
                $pwd = $wso_soda["pwd"];
                $sid = $wso_soda["sid"];
            }

            return wso_eventLogin( $uid, $pwd, $sid );
        }
        else if ( $evnt == "logout" && $wso_hasLogoutEvent )
        {
            return wso_eventLogout();
        }
    }
    catch( $e )
    {
        return $e["name"] ." - " . e["description"];
    }
*/
    // This is VERY UGLY in PHP4, probably won't even work right.
    // PHP5 has try...catch...throw builtin, but isn't stable yet.

    $globals = '$wso_hasDispatchEvent, $wso_hasLoginEvent, $wso_soda, $wso_hasLogoutEvent, $php_errormsg';

    $try_code =
          "if ( $evnt == \"dispatch\" && $wso_hasDispatchEvent )"
        . "{"
        . "    return wso_eventDispatch();"
        . "}"
        . "else if ( $evnt == \"login\" && $wso_hasLoginEvent )"
        . "{"
        . "    if ( $wso_soda )"
        . "    {"
        . "        $uid = \$wso_soda[\"uid\"];"
        . "        $pwd = \$wso_soda[\"pwd\"];"
        . "        $sid = \$wso_soda[\"sid\"];"
        . "    }"
        . ""
        . "    return wso_eventLogin( $uid, $pwd, $sid );"
        . "}"
        . "else if ( $evnt == \"logout\" && $wso_hasLogoutEvent )"
        . "{"
        . "    return wso_eventLogout();"
        . "}";

    $catch_code = 'return $php_errormsg;';

    try_catch( $try_code, $catch_code, $globals );
};

/* Object 2 String */
function ws__object2String ( $o, $tablvl )
{
    $v     = "";
    $tabs  = "";
    $itabs = "";

    // set tab spaces
    $tablvl = ( $tablvl ) ? $tablvl : 0;
    $tablvl++;

    for ( $i = 0; $i < $tablvl; $i++ )
    {
        $tabs .= "\t";
    }

    for ( $i = 1; $i < $tablvl; $i++ )
    {
        $itabs .= "\t";
    }

    if ( is_array( $o ) ) // pointless, it's got to be an array
    {
        // assume o is an array
        $ar = array();
        $o_length = count( $o );
        for ( $i = 0; $i < $o_length; $i++ )
        {
            $ar[ $i ] = ws__object2String( $o[ $i ], $tablvl );
        }

        $s = "[<br />" . $tabs . implode( ",", $ar ) . "<br />" . $itabs . "]";
    }
    else if ( is_object( $o ) ) // pointless, it's got to be an array
    {
        foreach ( $o as $key => $value )
        {
            if ( $v ) // pointless, always an empty string, so false
            {
                $v .= ",<br />";
            }

            $v .= ( $tabs . $key . ":" . ws__object2String( $value, $tablvl ) );
        }

        $s = "$itabs{<br />$v<br />$itabs}";
    }
    else
    {
        $s = $o;
    }

    return $s;
};

/* System Function - Executes system functions such as "WebServiceConnect" */
function ws__SYSFunction ( )
{
    global $wso_soda, $wso_name, $wso_comment, $wso_IOResponse,
           $wso_dispatch, $wso_hasLoginEvent, $wso_hasLogoutEvent;

    $found = FALSE;
    $o = array();
    $mn = ( $wso_soda ) ? $wso_soda[ "methodName" ] : "";
    $ec = $et = "";

    switch ( $mn )
    {
        case "SYS:WebServiceConnect" :

            // get service name and comment
            $o[ "name" ]    = $wso_name;
            $o[ "comment" ] = $wso_comment;

            // return method names if RCF = text/xml
            if ( $wso_IOResponse == "text/xml" )
            {
                $a = array();

                foreach ( $wso_dispatch as $key => $value )
                {
                    array_push( $a, $key );
                }

                $rt = implode( ",", $a ); // used later?
                $o[ "methodNames" ] = $rt;
            }

            // do login
            if ( $wso_hasLoginEvent )
            {
                $rt = ws__invokeEvent( "login" );

                if ( $rt == TRUE )
                {
                    $rt = "ok";
                }
                else
                {
                    if ( is_string( $rt ) )
                    {
                        //expecting errors to be string
                        $et = $rt;
                        $ec = "";
                    }

                    $rt = "failed";
                }
            }
            else
            {
                $rt = "ok";
            }

            $o[ "login" ] = $rt;
            $found = TRUE;
            break;

        case "SYS:WebServiceDisconnect" :

            if ( $wso_hasLogoutEvent )
            {
                $rt = ws__invokeEvent( "logout" );

                if ( $rt == TRUE )
                {
                    $rt = "ok";
                }
                else
                {
                    if ( is_string( $rt ) )
                    {
                        //expecting errors to be string
                        $et = $rt;
                        $ec = "";
                    }

                    $rt = "failed";
                }
            }
            else
            {
                $rt = "ok";
            }

            $o[ "logout" ] = $rt;
            $found = TRUE;
            break;

        default:
            // do nothing
    }

    if ( $found )
    {
        $o[ "SYSCall" ] = TRUE;

        return ws__createSODAEnvelope( $mn, $o, $ec, $et );
    }
};

/* Set Data Type - convert a value to a specific data type */
function ws__setDataType ( $value, $dt )
{
    if ( ! $dt )
    {
        return NULL;
    }
    else
    {
        if ( $dt == "string" )
        {
            $v = $value;
        }
        else if ( $dt == "date" )
        {
            $v = ( $value && is_numeric( $value ) ) ? $value : NULL;
        }
        else if ( $dt == "integer" )
        {
            $v = $value + 0;
        }
        else if ( $dt == "float" )
        {
            $v = $value + 0.0;
        }
        else if ( $dt == "boolean" )
        {
            $v = ( $value == TRUE || $value > 0 || preg_match( "/true/i" , $value ) ) ? TRUE : FALSE;
        }
        else if ( $dt == "array" )
        {
            if ( $value && ! is_array( $value ) )
            {
                $v = array( $value );
            }
            else
            {
                $v = $value;
            }
        }
        else if ( $dt == "object" )
        {
            if ( ! is_object( $value ) )
            {
                $v = (object) $value;
            }
            else
            {
                $v = value;
            }
        }
        else
        {
            $v = NULL;
        }

        return $v;
    }
};

// SODA Internal Data Types: U=undefined, I=integer, F=float, B=boolean, D=date/time, S=string, A=array, O=Object (Associative Array)
function ws__Var2SODA ( $v, $lvl )
{
    $vtype = ws__typeof( $v );  // ws__typeof from ioelmsrv.php
    $ot    = NULL;
    $ct    = NULL;
    $i     = NULL;
    $c     = NULL;
    $data  = NULL;

    if ( $lvl >= 0 )
    {
        $lvl++;
    }
    else
    {
        $lvl = 0;
    }

    if ( $vtype == "float" )
    {
        $data = "<f$lvl>$v</f$lvl>";
    }
    else if ( $vtype == "integer" )
    {
        $data = "<i$lvl>$v</i$lvl>";
    }
    else if ( $vtype == "unknown number" ) // imaginary?  ;-)
    {
        $data = "<u$lvl>$v</u$lvl>";
    }
    else if ( $vtype == "boolean" )
    {
        if ( $v === TRUE )
        {
            $data = "<b$lvl>true</b$lvl>";
        }
        else
        {
            $data = "<b$lvl>false</b$lvl>";
        }
    }
    else if ( $vtype == "date" )
    {
        // Date format: mm/dd/yyyy hh:nn:ss
        $data = "<d$lvl>$v</d$lvl>";
    }
    else if ( $vtype == "string" )
    {
        $data = "<s$lvl>" . ws__SODAStringEncode( $v ) . "</s$lvl>";
    }
    else if ( $vtype == "unknown string" )
    {
        $data = "<u$lvl>" . ws__SODAStringEncode( $v ) . "</u$lvl>";
    }
    else if ( $vtype == "numeric array" )
    {
        $data = "<a$lvl>";

        $i = 0;
        foreach ( $v as $value )
        {
            $data .= ( ( $i > 0 ) ? "<r$lvl/>" : "" ) . ws__Var2SODA( $value, $lvl );
            $i++;
        }

        $data .= "</a$lvl>";
    }
    else if ( $vtype == "associative array" )
    {
        $keys = array();
        $values = array();

        foreach ( $v as $key => $value )
        {
            array_push( $values, $value );

            if ( strpos( $key, "|" ) >= 0 )
            {
                $key = str_replace( "|", "&s;", $key );
            }

            array_push( $keys, $key );
        }

        $v = array( implode( "|", $keys ), $values );
        $data = "<o$lvl>" . ws__Var2SODA( $v, $lvl ) . "</o$lvl>";
    }
    else if ( $vtype == "object" && $v != NULL )
    {
        $keys = array();
        $values = array();

        foreach ( $v as $key => $value )
        {
            array_push( $values, $value );

            if ( strpos( $key, "|" ) >= 0 )
            {
                $key = str_replace( "|", "&s;", $key );
            }

            array_push( $keys, $key );
        }

        $v = array( implode( "|", $keys ), $values );
        $data = "<o$lvl>" . ws__Var2SODA( $v, $lvl ) . "</o$lvl>";
    }
    else
    {
        $data = "<u$lvl>0</u$lvl>";
    }

    $lvl--;

    if ( $lvl == 0 )
    {
        $data = "<soda>$data</soda>";
    }

    return $data;
};

function ws__SODA2Var ( $t, $lvl )
{
    echo "********\n";
    print_r( $t );
    echo "********\n";

    if ( $lvl < 0 || ! isset( $lvl ) )
    {
        $lvl = 0;
    }
    else
    {
        $lvl++;
    }

    if ( $lvl == 0 )
    {
        if ( substr( $t, 0, 6 ) != "<soda>" )
        {
            return $t;
        }

        $tag = ws__getSODATag( $t, "soda" );
        $t = $tag[ "content" ];
    }

    $tag = ws__getSODATag( $t, NULL );
    $tagType  = substr( $tag[ "name" ], 0, 1 );
    $tagIndex = substr( $tag[ "name" ], 1 );

    if ( $tagType == "i" )
    {
        $data = $tag[ "content" ] + 0;
    }
    else if ( $tagType == "f" )
    {
        $data = $tag[ "content" ] + 0.0;
    }
    else if ( $tagType == "b" )
    {
        $data = ( $tag[ "content" ] == "true" ) ? TRUE : FALSE;
    }
    else if ( $tagType == "s" )
    {
        $data = ws__SODAStringDecode( $tag[ "content" ] . "" );
    }
    else if ( $tagType == "d" )
    {
        $data = $tag[ "content" ]; // mm/dd/yyyy hh:nn:ss, not sure this will work
    }
    else if ( $tagType == "a" )
    {
        $data = array();

        if ( $tag[ "content" ] )
        {
            $elms = explode( $tag[ "content" ], "<r$tagIndex/>" );

            $elms_length = count( $elms );
            for ( $i = 0; $i < $elms_length; $i++ )
            {
                $data[ $i ] = ws__SODA2Var( $elms[ $i ], $lvl );
            }
        }
    }
    else if ( $tagType == "o" )
    {
        $elms = ws__SODA2Var( $tag[ "content" ], $lvl );

        if ( is_array( $elms ) && count( $elms ) > 0 )
        {
            $o = array();
            $keys = explode( "|", $elms[0] );
            $values = $elms[1];

            $keys_length = count( $keys );
            for ( $i = 0; $i < keys_length; $i++ )
            {
                $key = $keys[ $i ];

                if ( strpos( $key, "&s;" ) >= 0 )
                {
                    $key = str_replace( "&s;", "|", $key );
                }

                $o[ $key ] = $values[ $i ];
            }

            $data = $o;
        }
        else
        {
            $data = NULL;
        }
    }
    else if ( $tagType == "u" )
    {
        $data = NULL;
    }

    return $data;
};

function ws__SODAStringEncode ( $text )
{
    global $wso_IOResponse;

    if ( ! $text )
    {
        return "";
    }

    // encode string for use with javascript
    if ( $wso_IOResponse != "text/xml" )
    {
        $text = str_replace( "\\", "\\\\", $text ); // replace \ with \\
        $text = str_replace( "\'", "\\'", $text );  // replace ' with \'
        $text = str_replace( "\n", "\\n", $text );  // replace LF with \n
        $text = str_replace( "\r", "\\r", $text );  // replace CR with \r
    }

    // encode string for use with both html and xml
    $text = str_replace( "\&", "&amp;", $text);
    $text = str_replace( "<",  "&lt;", $text );
    $text = str_replace( ">",  "&gt;", $text );

    return $text;
};

function ws__SODAStringDecode ( $text )
{
    if ( ! $text )
    {
        return "";
    }

    $text = str_replace( "\&amp\;", "&", $text );
    $text = str_replace( "\&lt\;",  "<", $text );
    $text = str_replace( "\&gt\;",  ">", $text );

    return $text;
};

function ws__getSODATag ( $t, $n )
{
    if ( ! $t )
    {
        return array();
    }

    $n = ( $n ) ? $n : "";
    $st = strpos( $t , "<$n" );
    $et = FALSE;

    // Don't look for an end tag if you didn't find a start tag
    if ( is_int( $st ) && $st >= 0 )
    {
        $et = strpos( $t, ">", $st );
    }

    $tag = $con = "";
    if ( is_int( $et ) && $et > 0 )
    {
        $tag = substr( $t, $st + 1, ( $et - 1 ) - $st );
        $st  = $et + 1;
        $et  = strpos( $t, "</$tag>" );
        $con = substr( $t, $st, $et - $st );
    }

    return array( "name" => $tag, "content" => $con );
};

function ws__SODAParser ( $envelope )
{
    global $wso_sodaErrorText;

    $sid_content  = ws__getSODATag( $envelope, "sid" );
    $uid_content  = ws__getSODATag( $envelope, "uid" );
    $pwd_content  = ws__getSODATag( $envelope, "pwd" );
    $err_content  = ws__getSODATag( $envelope, "err" );
    $mn_content   = ws__getSODATag( $envelope, "method" );
    $body_content = ws__getSODATag( $envelope, "body" );

    $r = array(
        "sid"        => $sid_content[ "content" ],
        "uid"        => $uid_content[ "content" ],
        "pwd"        => $pwd_content[ "content" ],
        "error"      => $err_content[ "content" ],
        "methodName" => ws__SODAStringDecode( $mn_content[ "content" ] ),
        "value"      => ws__SODA2Var( $body_content[ "content" ], NULL )
    );

    if ( $r[ "error" ] )
    {
        $ea = explode( $r[ "error" ], "|" );
        $r[ "error" ] = array( "code" => $ea[0], "text" => $ea[1] );
    }
    else if ( strpos( "$envelope", "<envelope>" ) != 0 )
    {
        $r[ "error" ] = array( "code" => "E3", "text" => $wso_sodaErrorText[ "E3" ] );
    };

    return $r;
};

/*
 * helper function for PHP4 try...catch syntax.
 * PHP5 has try...catch...throw builtin :)
 */
function try_catch( $try_code, $catch_code, $globals )
{
    global $globals;

    //echo "try_code: $try_code<br />\n" .
    //     "catch_code: $catch_code<br />\n";

    eval( "function catcher () { global $globals; $catch_code };" );

    // Set new track_errors value and save old value
    $old_ini_track_errors = ini_set( "track_errors", "1" );

    // Activate assert and make it quiet
    assert_options( ASSERT_ACTIVE, 1 );
    assert_options( ASSERT_WARNING, 0 );
    assert_options( ASSERT_QUIET_EVAL, 1 );
    // Set up the callback
    assert_options( ASSERT_CALLBACK, 'catcher' );
    // Make an assertion that may succeed or fail
    assert( $try_code );

    // Restore old values
    assert_options( ASSERT_ACTIVE, 0 );
    ini_set( "track_errors", $old_ini_track_errors );
}

?>
