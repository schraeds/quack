<?php
session_start();
header("Cache-control: private"); 

require("ioelmsrv.php");
require("ioelmsrv.soda.php");

wsAddMethod("testBoolean",array("b:boolean:false"),"boolean");
wsAddDescription("testBoolean:b","A comment");
wsAddMethod("testInteger",array("n:integer"),"integer");
wsAddMethod("testFloat",array("n:float"),"float");
wsAddMethod("testString",array("s:string"),"string");
wsAddMethod("testDate",array("d:date"),"date");
wsAddMethod("testArray",array("a:array"),"array");
wsAddMethod("testObject",array("o:object"),"object");

wsSetName( "PHP SODA Test" );
wsSetComment( "This Web Service was created using PHP" );

//wsCaptureEvent( "login", &$login );
//wsCaptureEvent( "dispatch", &$dispatch );
$_SESSION['sid'] = "ok";

wsEnableOnlineHelp( TRUE );

wsDispatch();

//Login Event Callback function
function login( $uid, $pwd, $sid )
{
	if ($uid=="myname" && $pwd=="mypassword")
    {
        $_SESSION['sid'] = "ok";
        return TRUE;
    }
    else
    {
        $_SESSION['sid'] = "failed";
    }
}

//Dispatch Event Callback function
function dispatch()
{
	//do not check for login when in helpmode
	if( wsIsHelpMode() )
    {
        return;
    }
	
	$sid = wsGetSessionId();
	if ( $_SESSION[sid] != "ok" && $_SESSION[sid] != "failed" )
    {
		$t="Unable to retrieve Session Information.\n";
		$t=$t."Please make sure Cookies are enabled on your browser.\n";
		$t=$t."Some browsers include Privacy Policies that block unknown cookies.";
		wsRaiseError("",$t);
    }
    
	if ( $_SESSION[sid] != "ok" )
    {
        return FALSE;
    }
}

// Test Boolean
function testBoolean($b)
{
	return $b;
};

// Test Integer
function testInteger($n)
{
	return $n;
};

// Test Float
function testFloat($n)
{
	return $n;
};

// Test String
function testString($s)
{
	return $s;
};

// Test Date
function testDate($d)
{
	return $d;
};

// Test Array
function testArray($a)
{
	return $a;
};

// Test Object - Associative/Hash Array (aka Disctionary Object)
function testObject($o)
{
	return $o;
};

?>
