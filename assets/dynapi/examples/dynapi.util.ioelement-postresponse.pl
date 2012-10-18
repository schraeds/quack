#! C:\Perl\bin\perl.exe -w
# for windows
#
# /usr/bin/perl -w
# for unix

use CGI;
use Carp;

print <<__END_OF_TEXT__;
Content-Type: text/html; charset=iso-8859-1

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

__END_OF_TEXT__

# generate javascript variables from Perl code

my $q = new CGI;
my %q = $q->Vars();

print "var response = 'Your name is " . $q{name} . ", and your favourite color is " . $q{color} . "';";

print <<__END_OF_TEXT__;

//-->
</script>
<body></body>
</html>
__END_OF_TEXT__

1;

__END__
