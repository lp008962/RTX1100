package My::YAMAHA::URL_Filter;
use strict;
use warnings;
use Class::Accessor 'antlers';
use List::MoreUtils 'apply';
### use My::DNS;

my %engines = (
    "Google"    => { 
        pattern => 'google.co.jp/search\?',
        regexp  => '^.+search(\?q|.+?\&q)\=(.+?)(&.+|)$',
    },
    "Yahoo"     => { 
        pattern => 'http://search.yahoo.co.jp/',
        regexp  => '^.+?search(\?p\=|.+?\&p\=|.+?\?p=)([^&].+?)(&search.+|&.+|)$',
    },
    "Cybonet"   => { 
        pattern => '^http://search.cybozu.net/\?keywords',
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

### my $dns = My::DNS->new;

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

    # Parse  a single-URL-line. Not by file
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

    # Make regexp  to match lines
    my $str_matching = "";
    foreach my $key ( keys %engines ) {
        $str_matching = sprintf("%s|", $engines{$key}{pattern});
    }
    $str_matching = substr($str_matching, 0, -1); # Delete a last pipe.

    while (<$fh>) {
        next unless $_ =~ /$str_matching/oi;
        next if $_ eq $prev;
        $prev = $_;

        $self->parse_log($_);
    }

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
    
    # 同じIPから二度DNSを引かないように
    ### $self->{ip}{$ip} = $dns->ip2user($ip) if ( !$self->{ip}{$ip} );

   ###  $self->{result} .= sprintf("%2s %2s %5s : %-15s -> %s\n", 
   ###                            $month, $day, $time, $self->{ip}{$ip}, $query );
    $self->{result} .= sprintf("%2s %2s %5s : %-15s -> %s\n", 
                                                    $month, $day, $time, $ip, $query );

}

sub parse_url {
    my ($self, $url) = @_;
    my $query;

    foreach my $key ( keys %engines ) {
            if ($key eq 'Google' or $key eq 'Yahoo') {
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
        use URI::Escape;
        $query = uri_unescape( $query );
    }

    return $query;
}

1;
