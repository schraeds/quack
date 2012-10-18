<?

require( "ioelmsrv.php" );
require( "ioelmsrv.soda.php" );

wsSetIcon( "images/calc.gif" );
wsSetName( "JScript Calculator Web Service" );
wsSetComment( "This web service is used to demonstrate the use of SODA-RPC" );

wsAddMethod( "aboutCalculator", NULL, "object" );
wsAddMethod( "add", array( "a:float:0", "b:float:0" ), "float" );
wsAddMethod( "subtract", array( "a:float:0", "b:float:0" ), "float" );
wsAddMethod( "divide", array( "a:float:0", "b:float:0" ), "float" );
wsAddMethod( "multiply", array( "a:float:0", "b:float:0" ), "float" );
wsAddMethod( "square", array( "a:float:0" ),"float" );
wsAddMethod( "fraction", array( "a:float:0" ), "float" );
wsAddMethod( "percentage", array("a:float:0"), "float" );

wsAddDescription( "aboutCalculator", "Calculator/Company Information - Name, Email, etc" );
wsAddDescription( "add", "Add two numeric values and returns the result." );
wsAddDescription( "add:a", "Numeric value" );
wsAddDescription( "add:b", "Numeric value" );

wsAddErrorCode( "024", "Add Error Message Here" ); //'You can add custom error messages here

wsCaptureEvent( "login", login );
wsCaptureEvent( "dispatch", dispatch );

wsEnableOnlineHelp( TRUE );

wsDispatch();


// Login Event Callback function
function login ( $uid, $pwd, $sid )
{
    if ( $uid == "myname" && $pwd == "mypassword" )
    {
        $_SESSION[ $sid ] = "ok";
        return( TRUE );
    }
    else
    {
        $_SESSION[ $sid ] = "failed";
    }
}

// Dispatch Event Callback function
function dispatch ()
{
    // do not check for login when in helpmode
    if ( wsIsHelpMode() == TRUE )
    {
        return;
    }

    $sid = wsGetSessionId();

    if ( $_SESSION[ $sid ] != "ok" && $_SESSION[ $sid ] != "failed" )
    {
        $t="Unable to retrieve Session Information.\n"
        ."Please make sure Cookies are enabled on your browser.\n"
        ."Some browsers include Privacy Policies that block unknown cookies.";
        wsRaiseError("",$t);
    }

    if ( $_SESSION[ $sid ] != "ok" )
    {
        return( FALSE );
    }
}

// About Calculator
function aboutCalculator ()
{
    return (
        '{
            name:"JS Calculator",
            company:"SODA-RPC Inc.",
            email:"support@soda-rpc.com",
            comment:"SODA-RPC Web Service Demo",
            specs:
            {
                buttons:"10",
                functions:"add, mmultiply, etc"
            },
            NOTE:"<font color=\"red\"><b>The following is just to demo nested arrays</b></font>",
            myArray:["Red","Blue","Green","Yellow"],
            yourArray:
            [
                ["Him","Her","She","His","Boy","Girl","etc"],
                ["Corn","Bread"]
            ]
        }'
    );
}

// Add
function add ( $a, $b )
{
    return( $a + $b );
}

// Subtract
function subtract ( $a, $b )
{
    return( $a - $b );
}

// Divide
function divide ( $a, $b)
{
    return( $a / $b );
}

// Multiple
function multiply ( $a, $b )
{
    return( $a * $b );
}

// Square
function square ( $a )
{
    return( $a * $a );
}

// Percentage
function percentage ( $a )
{
    return( $a / 100 );
}

// Fraction
function inverse( $a )
{
    return( 1 / $a );
}

?>
