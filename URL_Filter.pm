package YAMAHA::URL_Filter;
use strict;
use warnings;
use Class::Accessor 'antlers';
use List::MoreUtils 'apply';

my %engines = (
    "Google"    => { 
        pattern => 'google.co.jp/search\?',
        regexp  => '^.+search(\?q|.+?\&q)\=(.+?)(&.+|)$',
    },
    "Yahoo"     => { 
        pattern => 'search.yahoo.co.jp/',
        regexp  => '^.+?search(\?p|.+?\&p|.+?\?p)\=(.+?)(\&.+|)$',
    },
    "Cybonet"   => { 
        pattern => 'search.cybozu.net/\?keywords',
        regexp  => '^.+?\?keywords\=(.+?)(&.+|)$',
    },
    "Bing"      => { 
        pattern => 'bing.com/search\?',
        regexp  => '^.+search\?q\=(.+?)(&.+|)$',
    },
    "Wikipedia" => { 
        pattern => 'wikipedia.org/wiki',
        regexp  => '.+?wikipedia.org\/wiki\/(.+?)',
    },
);

# Accessor
has 'file'   => (isa => 'Str', is => 'rw');
has 'result' => (isa => 'Str', is => 'rw');
has 'ip'     => (isa => 'Str', is => 'rw');

# Constractor
sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my %args = @_;
    my $self  = { 
        file   => $args{file} || '/var/log/yamaha/rtlog',
        result => '',
        ip     => {},
    };
    return bless($self, $class);

}


sub get_searched_queries {
    my $self = shift;
    my $url  = shift;

    # Enable parse a single-line-URL, not file but argv.
    if ($url) {
        return $self->parse_url($url);
    } else {
        $self->analyze($self->file);
    }

    return $self->result;
}

sub analyze {
    my ($self, $file) = @_;

    my $prev = "";
    open my $fh, '<', $file or die "File Not Found $file: $!";

    # Make regexp strings.
    my $str_matching = &gen_regexp_engines('pattern');

    while (<$fh>) {
        next unless $_ =~ /$str_matching/o;
        next if $_ eq $prev;
        $prev = $_;

        $self->parse_log($_);
    }


}

sub gen_regexp_engines {
    my $key2 = shift || 'pattern';

    my $str_matching="";
    foreach my $key ( keys %engines ) {
        # Separate each engines by pipe, like 'google|yahoo|some_engine|'
        $str_matching .= sprintf("%s|", $engines{$key}{$key2});
    }
    $str_matching = substr($str_matching, 0, -1); # Delete a last pipe.

    return $str_matching;

}

sub parse_log {
    my ($self, $line) = @_;

    my @columns = split(' ', $line);
    my $month   = $columns[0];
    my $day     = $columns[1];
    my $time    = $columns[2];
    my $ip      = $columns[10];
    my $url     = $columns[12];
    my $result  = "";
    my $query   = "";

    $query = $self->parse_url( $url );
    return if !$query;
    
###    # Dont request same ip-address.
###    my $mymod = Make::Your::Own->new;
###    $self->{ip}{$ip} = $mymod->ip2user($ip) if ( !$self->{ip}{$ip} );

    $self->{result} .= sprintf("%2s %2s %5s : %-15s -> %s\n", 
                                $month, $day, $time, $ip, $query );  # $ip or $self->{ip}[$ip};

}

sub parse_url {
    my ($self, $url) = @_;
    my $query;

    foreach my $key ( keys %engines ) {
        next unless $url =~ /$engines{$key}{regexp}/;
        if ($key eq 'Yahoo' or $key eq 'Google') {
            $query = apply { s/$engines{$key}{regexp}/$2/g } $url;
        } else {
            $query = apply { s/$engines{$key}{regexp}/$1/g } $url;
        }

        $query = $self->decode($query);
        $query = sprintf("%s(%s)", $query, $key);

    }

    return $query;
}

sub decode { 
    my ($self, $query) = @_;
    return if $query eq "";

    if ($query =~ /%[0-9A-Fa-f]{2}/) {
        #$query =~ tr/+/ /;
        #$query =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2', $1)/eg;
        use URI::Escape;
        $query = uri_unescape( $query );
    }

    return $query;
}
