<?

/*
    IOElement Server Library - For PHP Servers
    For use with DynAPI IOElement client-side javascript

    The DynAPI Distribution is distributed under the terms of the GNU LGPL license.

    Returned Data type: integer, float, string, date, array, object (associative array)

    Cristian Grigoriu <cristian.grigoriu (at) provus (dot) ro>
    Leif Westerlind <warp-9.9 (at) usa (dot) net>
*/

$wso_vars = array();      // stores javascript variables to be returned to client
$wso_endDocWrite = FALSE; // Prevent ws__docWrite from sending data to client
$wso_IOResponse = "";     // Returned Content Format: text/html (default) or text/xml
$wso_reqMethod = "";

/* Add Variables - javascript variables to be sent to client - should only used with html RTC format */
function wsAddVariable ( $name, $value )
{
    global $wso_vars;

    if ( ! $name )
    {
        return;
    }

    $wso_vars[$name] = $value;  // add variable to be sent to client
};

/* Dispatch Variables - should only be used text/html RC format when working with SODA */
function wsDispatchVariables ( )
{
    global $wso_vars, $wso_IOResponse;

    $arr = "";

    foreach ($wso_vars as $varname => $value)
    {
        $arr .= "var $varname=" . ws__Var2Text($value) . ";\n";
    }

    $wso_IOResponse = wsGetRequest("IOResponse");
    ws__docWrite($arr);
};

/* End Response */
function wsEndResponse ( )
{
    global $wso_endDocWrite;

    $wso_endDocWrite = TRUE;
};

/* Get Request - returns a value from either $HTTP_GET_VARS or $HTTP_POST_VARS */
function wsGetRequest ( $name )
{
    // Get requested data sent by client via GET or POST

    $mode = wsGetRequestMethod();

    switch ( $mode )
    {
        case "get"  :
            global $HTTP_GET_VARS;
            $nm = $HTTP_GET_VARS[$name];
            return isset($nm) ? $nm : "";

        case "post" :
        case "upload" :
        default :
            global $HTTP_POST_VARS;
            $nm = $HTTP_POST_VARS[$name];
            return isset($nm) ? $nm : "";
    }
};

/* Get Request Method - returns the method used to send the data to the server from the IOElement object on the client */
function wsGetRequestMethod ( )
{
    global $wso_reqMethod;

    if ( empty($wso_reqMethod) )
    {
        // used to indicate GET, POST or UPLOAD - these are use by dynapi on client-side
        global $HTTP_SERVER_VARS;
        $rm = $HTTP_SERVER_VARS["REQUEST_METHOD"];

        $wso_reqMethod = isset($rm) ?  strtolower($rm) : "";
    }

    return $wso_reqMethod;
};

// [Private] Functions ----------------------------------------
/* Doc Write */
function ws__docWrite ( $h )
{
    global $wso_endDocWrite, $wso_IOResponse;

    if ( $wso_endDocWrite )
    {
        return;
    }

    if ( $wso_IOResponse == "text/xml" )
    {
        $html = "Content-Type: text/xml\n" .
                "\n".
                $h;
    }
    else
    {
        $html = "Content-Type: text/html\n" .
                "\n" .
                "<html>\n" .
                "<script language=\"javascript\" type=\"text/javascript\">\n" .
                "var ioObj,dynapi=parent.dynapi;\n" .
                "if (dynapi) ioObj=parent.IOElement.notify(this);\n" .
                "else alert('Error: Missing or invalid DynAPI library');\n" .
                "$h;\n" .
                // DEBUG
                "make.error\n" .
                "</script>\n" .
                "</html>\n";
    }

    echo $html;
};

// Var2Text
function ws__Var2Text ( $v )
{
    if ( ! isset( $v ) )
    {
        return "null";  // doesn't make much sense. I wonder how is this working in the .js version
    }
    else if ( is_string( $v ) )
    {
        return "'$v'";
    }
    else if ( is_array( $v ) )
    {
        $arr = "[";

        foreach ($v as $value)
        {
            $arr .= ws_Var2Text($value) . "'";
        }

        return substr($arr, 0, -1) . "]";
    }
    else
    {
        return $v ;
    }
}

// Var2Text Encode - converts multiline text into single line

$repltable = array(
    "\\" => "\\\\",
    "\'" => "\\'",
    "\r\n" => "\\n",
    "\n" => "\\n",
    "\r" => "\\r"
);

function ws__Var2TextEncode ( $str )
{
    global $repltable;

    if ( is_null( $str ) )
    {
        return;
    }

    foreach ( $repltable as $search => $replace )
    {
        $str = str_replace( $search, $replace, $str );
    }

    return $str;
}

/*
 * ws__typeof - used to estimate the data type
 *
 * Input Data Types (language specific):
 *     boolean, array, object, null
 *     scalar (numeric {integer, float}, string)
 *
 * Output Data Types (JavaScript / generic):
 *     number, boolean, function, string, object, array, date, default
 *
 * Takes a reference as input, determines type of reference,
 * if SCALAR, dereferences and determines format of data
 */

function ws__typeof ( $v )
{
    if ( is_bool( $v ) )
    {
        return "boolean";
    }
    else if ( is_scalar( $v ) )
    {
        if ( is_numeric( $v ) )
        {
            if ( is_integer( $v ) )
            {
                return "integer";
            }
            else if ( is_float( $v ) )
            {
                return "float";
            }
            else // imaginary?  ;-)
            {
                return "unknown number";
            }
        }
        else if ( is_string( $v ) )
        {
            if ( preg_match( "/\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}/", $v ) )
            {
                return "date";
            }
            else if ( preg_match( "/^[\w]+[\w\d\s^$.[\]|()?*+{}\\\-]*$/", $v ) )
            {
                return "string";
            }
            else
            {
                return "unknown string";
            }
        }
        else
        {
            return "unknown scalar";
        }
    }
    else if ( is_array( $v ) )
    {
        return typeof_array( $v );
    }
    else if ( is_object( $v ) )
    {
        return "object";
    }
    else if ( is_null( $v ) )
    {
        return "null";
    }
    else
    {
        return "unknown";
    }
}

////////////////////////////////////////////////////////////////
function typeof_array ( $myAry )
{
    if ( count( $myAry ) == 0 )
    {
        // causes an unknowwn / error,
        // need to raise a more verbose message
        return "empty array";
    }
    else if ( is_numeric_array( $myAry ) )
    {
        return "numeric array";
    }
    else if ( is_associative_array( $myAry ) )
    {
        return "associative array";
    }
    else
    {
        // causes an unknowwn / error,
        // need to raise a more verbose message
        return "mixed array";
    }
};

////////////////////////////////////////////////////////////////
function is_numeric_array ( $myAry, $is_numeric = FALSE )
{
    while ( list( $key, $value ) = each( $myAry ) )
    {
        if ( is_numeric( $key ) && is_integer( $key ) )
        {
            $is_numeric = TRUE;
        }
        else
        {
            return FALSE;
        }

        if ( is_array( $value ) )
        {
            $is_numeric = is_numeric_array( $value, $is_numeric );
        }
    }

    return $is_numeric;
};

////////////////////////////////////////////////////////////////
function is_associative_array ( $myAry, $is_associative = FALSE )
{
    while ( list( $key, $value ) = each( $myAry ) )
    {
        if ( is_string( $key ) )
        {
            $is_associative = TRUE;
        }
        else
        {
            return FALSE;
        }

        if ( is_array( $value ) )
        {
            $is_associative = is_associative_array( $value, $is_associative );
        }
    }

    return $is_associative;
};

?>
