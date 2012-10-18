<?

require("ioelmsrv.php");

wsAddVariable( "name", $_POST["name"] );
wsAddVariable( "color", $_POST["color"] );

foreach ( $_FILES as $upload_file => $file_stats )
{
    if ( isset( $file_stats['name'] ) && $file_stats['name'] != "" )
    {
        // poor design because this will clobber the same namespace so
        // that only the last file will be shown on multiple file upload.
        wsAddVariable( "file", $file_stats['name'] );
        wsAddVariable( "size", $file_stats['size'] );

        /*
         * Code from PHP manual regarding file upload handling.
         * Should probably fold into generic upload.php to handle
         * different PHP versions.
         */

        // In PHP earlier then 4.1.0, $HTTP_POST_FILES should be used instead of
        // $_FILES.  In PHP earlier then 4.0.3, use copy() and is_uploaded_file()
        // instead of move_uploaded_file

        /*
        $uploaddir = '/var/www/uploads/';
        $uploadfile = $uploaddir . $file_stats['name'];

        print "<pre>";
        if ( move_uploaded_file( $file_stats['tmp_name'], $uploadfile ) )
        {
            print "File is valid, and was successfully uploaded. ";
            print "Here's some more debugging info:\n";
            print_r( $_FILES );
        }
        else
        {
            print "Possible file upload attack!  Here's some debugging info:\n";
            print_r( $_FILES );
        }
        print "</pre>";
        */
?>

    }
}

wsDispatchVariables();

?>
