package YAMAHA::URL_Filter;

use strict;
use warnings;
use Class::Accessor 'antlers';
use List::MoreUtils 'apply';

# Accessor
has 'file' => (isa => 'Str', is => 'rw');
#has 'model' => (isa => 'Str', is => 'rw'); # 他モデルのログ形式しらない
#has 'ipaddr' => (isa => 'Str', is => 'rw'); # サーチ対象を絞るなら。


# Constractor
sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my %args = @_;
    my $self = {
        file => $args{file} || '/var/log/yamaha/rtlog',
# ipaddr => $args{ipaddr} || '192.168.1.',
# model => $args{model} || 'rtx1100',
        result => '',
    };
    return bless($self, $class);

}


# Method you use
sub searched {
    my $self = shift;
    my $prev = "";

    open my $fh, '<', $self->{file};

    while (<$fh>) {
        next if $_ eq $prev;
        $prev = $_;
        next unless $_ =~ /\[URL_FILTER\]/;
# next unless $_ =~ /$self->{ipaddr}/;

        $self->analyze($_);
    }

    return $self->{result};
}


# Internal method
sub analyze {
    my ($self, $line) = @_;

    # 完全にログ形式に依存
    my @cols = split(' ', $line);
    my $m = $cols[0];
    my $d = $cols[1];
    my $time = $cols[2];
    my $ip = $cols[10];
    my $url = $cols[12]; # is query_strings.
    my $query;

    # Let's REGEXP!!!!!!!1111
    # もっとマシな書き方ェ・・・・
    if ( $url =~ q|google.co.jp/search\?|) {
        $query = apply { s/^.+search.+?q\=(.+?)(&.+|)$/$1/g } $url;
        $self->decode($m, $d, $time, $ip, $query, "Google");

    } elsif ( $url =~ q|http://search.yahoo.co.jp/|) {
        $query = apply { s/^.+?search(\?p\=|.+?\&p\=)([^&]*?)(&.+|)$/$2/g } $url;
        $self->decode($m, $d, $time, $ip, $query, "Yahoo");

    } elsif ( $url =~ q|^http://search.cybozu.net/\?keywords|) {
        $query = apply { s/^.+?\?keywords\=(.+?)(&.+|)$/$1/g } $url;
        $self->decode($m, $d, $time, $ip, $query, "Cybonet");
 
    } elsif ( $url =~ q|bing.com/search\?|) {
        $query = apply{ s/^.+search\?q\=(.+?)(&.+|)$/$1/g } $url;
        $self->decode($m, $d, $time, $ip, $query, "Bing");
 
    } elsif ( $url =~ q|wikipedia.org/wiki|) {
        $query = apply { s/.+?wikipedia.org\/wiki\/(.+?)/$1/g } $url;
        $self->decode($m, $d, $time, $ip, $query, "Wikipedia");
    }

}

sub decode {
    my ($self, $m, $d, $time, $ip, $query, $engine) = @_;
    return if $query =~ /^http/;
    return if $query eq "";

    my $msg = "";

    if ($query =~ /%[0-9A-Fa-f]{2}/) {
        $query =~ tr/+/ /;
        $query =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2', $1)/eg;

        $msg = sprintf("%s %s %s : %s \t -> %s (%s)\n", $m, $d, $time, $user, $query, $engine);

    } else {

        $msg = sprintf("%s %s %s : %s \t -> %s (%s)\n", $m, $d, $time, $user, $query, $engine);

    }

    $self->{result} .= $msg;
}

1;
