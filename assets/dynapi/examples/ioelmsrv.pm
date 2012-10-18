package IOElement;

#
#   IOElement Server Library - For Perl Servers
#   For use with DynAPI IOElement client-side javascript
#
#   The DynAPI Distribution is distributed under the terms of the GNU LGPL license.
#
#   Returned Data type: integer, float, string, date, array, object (associative array)
#

#-----------------------------------------------------------#
# Private Variables                                         #
#-----------------------------------------------------------#

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use strict;     # Restrict unsafe variables, references, barewords
use CGI;
use Carp;

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(Version);
%EXPORT_TAGS = (all => [@EXPORT_OK]);
$VERSION = '0.0.1';

#-----------------------------------------------------------#
# Public Methods                                            #
#-----------------------------------------------------------#

# Constructor

sub new
{
    my $proto = shift;
    my $args = shift;

    my $class = ref($proto) || $proto;
    my $self =
    {
        ERROR => "",
        wso_vars => {},                # stores javascript variables to be returned to client
        wso_endDocWrite => 0,          # Prevent ws__docWrite from sending data to client
        wso_IOResponse => "text/html", # Returned Content Format:
                                       #     text/html (default) or text/xml
        wso_reqMethod => "",           # stores request method - get,post or upload -
                                       #     upload is use by dynapi when unloading files
        q_obj => new CGI,              # Instance of the CGI object, q stands for query
        q_hash => {}                   # Hash of form's field names and values
    };

    $self->{q_hash} = $self->{q_obj}->Vars();

    return( bless $self, $class );
}

sub Version
{
    return $VERSION;
}

sub q_hash_ref
{
    my $self = shift;

    return( $self->{q_hash} );
}

# Add Variables - javascript variables to be sent to client
#
#     should only be used when html content is being returned to the
#     client
#
sub wsAddVariable
{
    my $self = shift;
    my $name = shift || carp "Not enough args (0 of 2) sent to wsAddVariable: $!";
    my $value = shift || carp "Not enough args (1 of 2) sent to wsAddVariable: $!";

    return if ( ! ( $name || defined( $name ) ) );

    ${ $self->{wso_vars} }{ $name } = $value;  # add variable to be sent to client
};

# Dispatch Variables - dispatch data to the client
#
#     should only be used when html content is being returned to the
#     client
#
sub wsDispatchVariables
{
    my $self = shift;
    my( @arr );

    foreach my $key ( sort keys %{ $self->{wso_vars} } )
    {
        my $val = ${ $self->{wso_vars} }{ $key };
        push( @arr , "var " . $key . "=" . $self->ws__Var2Text( $val ) );
    }

    $self->{wso_IOResponse} = ${ $self->{q_hash} }{IOResponse};
    $self->ws__docWrite( join( ";\n" , @arr ) );
};

# End Response - prevents ws__docWrite from sending any more information
#     to the client
#
sub wsEndResponse
{
    my $self = shift;

    $self->{wso_endDocWrite} = 1;
};

# Get Request - returns a value from the submitted form
sub wsGetRequest
{
    my $self = shift;

    my( $name, $val, $mode );
    $name = shift || carp "Not enough args (0 of 1) sent to wsAddVariable: $!";

    # Using CGI.pm makes this all superfluous code.
    #$mode = $self->wsGetRequestMethod();

    #$val = ${ $self->{q_hash} }{ $name } if( $mode =~ /post/i );
    #$val = ${ $self->{q_hash} }{ $name } if( ! ( $val || defined( $val ) ) );

    $val = ${ $self->{q_hash} }{ $name };

    return( ( defined( $val ) ) ? $val : "" );
};

sub wsGetRequestMethod
{
    my $self = shift;

    if ( ! $self->{wso_reqMethod} )
    {
        # used to indicate GET, POST or UPLOAD
        # - these are use by dynapi on client-side
        my $rm = ${ $self->{q_hash} }{IOMethod};

        if ( ! ( $rm || defined( $rm ) ) )
        {
            $rm = ${ $self->{q_obj} }->request_method();
        }

        $self->{wso_reqMethod} = ( ! $rm ) ? "post" : "\L$rm\E";
    }

    return( $self->{wso_reqMethod} );
};

# -------- [Private] Functions -----------------------------------------

# Doc Write - generates an html page containing JavaScript codes that
#     will be loaded into an <IFrame> or <Layer> on the client
#
sub ws__docWrite
{
    my $self = shift;
    my( $h, $html );

    $h = shift || carp "Not enough args (0 of 1) sent to ws__docWrite: $!";

    return if ( $self->{wso_endDocWrite} );

    if ( $self->{wso_IOResponse} =~ "text/xml" )
    {
        $html = $h;
    }
    else
    {
        $html = "<html>\n" .
            "<script language=\"javascript\">\n" .
            "\n" .
            "var ioObj,dynapi = parent.dynapi;\n" .
            "\n" .
            "if ( dynapi ) { ioObj = parent.IOElement.notify(this); }\n" .
            "else alert('Error: Missing or invalid DynAPI library.');\n" .
            "\n" .
            $h . "\n" .
            "</script>\n" .
            "</html>\n";
    }

    print $html;
};

#ws__Var2Text=function(v){
#    var i,c,data,vtype=typeof(v);
#    if(!v) data='null';
#    else if(vtype=="number"||vtype=="boolean"||vtype=="function") {
#        data=v;
#    }else if(vtype=="string") {
#        data="'"+ws__Var2TextEncode(v)+"'";
#    }else if(vtype=="object") {
#        if(v.constructor==Array){ // Array Object
#            data='[';
#            for (i=0;i<v.length;i++){
#                data+=(i>0)? ','+ws__Var2Text(v[i]):ws__Var2Text(v[i])
#            }
#            data+=']';
#        }else if(v.constructor==Date){ // Date object
#            data='Date("'+v+'")'
#        }else{
#            data='{';c=0;
#            for (i in v){
#                if(c>0) data+=','
#                data+='\''+ws__Var2TextEncode(i)+'\':'+ws__Var2Text(v[i]);
#                c++;
#            }
#            data+='}';
#        }
#    }
#    return data;
#};
#

# Var2Text - used to convert a server-side variable into a javascript
#     client-side variable
#
sub ws__Var2Text
{
    my $self = shift;
    my( @v, $i, $c, $data, $vtype );

    @v = @_ || carp "Not enough args (0 of N) sent to ws__Var2Text: $!";

    $vtype = typeof( \$v[0] );

    if ( ! defined( $v[0] ) )
    {
        $data = "null";
    }
    elsif ( $vtype eq "number" )
    {
        $data = $v[0];
    }
    elsif ( $vtype eq "string" )
    {
        $data = "'" . $self->ws__Var2TextEncode( $v[0] ) . "'";
    }
    elsif ( $vtype eq "array" )
    {
        $data = "[";

        my $num_v = $#v + 1;

        for ( my $i = 0 ; $i < $num_v ; $i++ )
        {
            $data .= "," if ( $i > 0 );
            $data .= $self->ws__Var2Text( $v[$i] );
        }

        $data .= "]";

    }
    elsif ( $vtype eq "date" )
    {
        $data = "Date('" . $v[0] . "')";
    }
    else
    {
        $data = "{";
        my $c = 0;

        foreach my $i ( @v )
        {
            $data .= "," if ( $i > 0 );
            $data .= "'" . $self->ws__Var2TextEncode( $i ) . "':" . $self->ws__Var2Text( $v[$i] );
            $c++;
        }

        $data .= "}";
    }

    return( $data );
};

# Var2Text Encode - converts multiline text into single line javascript
sub ws__Var2TextEncode
{
    my $self = shift;
    my $text = shift || return; #carp "Not enough args (0 of 1) sent to ws__Var2TextEncode: $!";

    if ( $text eq "" )
    {
        return( $text );
    }

    $text =~ s#\\#\\\\#g; # replace \ with \\
    $text =~ s#'#\'#g;    # replace ' with \'
    $text =~ s#\r\n#\n#g; # replace CrLf with \n
    $text =~ s#\n#\n#g;   # replace single Lf with \n # no sense doing this?
    $text =~ s#\r#\n#g;   # replace single Cr with \n
    return( $text );
};

# typeof - used to estimate the data type
#     SCALAR (number, string), ARRAY, HASH, or CODE
#
# OutputData Types:
#     number, boolean, function, string, object, array, date, default
#
sub ws__typeof
{
    my $self = shift;
    my $ref = shift || carp "Not enough args (0 of 1) sent to ws__typeof: $!";

    if ( $ref =~ /^SCALAR/ )
    {
        if ( $$ref =~ /^\d+$/ )
        {
            return( "number" );
        }
        elsif ( $$ref =~ m/\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}/ )
        {
            return( "date" );
        }
        elsif ( $$ref =~ /^\w+([\w\d])*$/ )
        {
            return( "string" );
        }
    }
    elsif ( $ref =~ /^ARRAY/ )
    {
        return( "array" );
    }
    elsif ( $ref =~ /^HASH/ )
    {
        return( "object" );
    }
    elsif ( $ref =~ /^CODE/ )
    {
        return( "code" );
    }
}

1;

__END__
