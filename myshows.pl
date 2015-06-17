#! /usr/bin/perl

use 5.010;
use strict;
use warnings;
no warnings 'experimental::smartmatch';

#use HTTP::Async if possible or fallback to LWP::UserAgent
my $ASYNC = eval {require HTTP::Async and HTTP::Async->import};
use LWP::UserAgent;
use Digest::MD5 qw/md5_hex/;
use JSON;
use Getopt::Long;

binmode(STDOUT, ':utf8');

my $CONFIG_PATH = "$ENV{HOME}/.myshowsrc";

my $request_type = 'unwatched';
my $output = 'stdout';

GetOptions (
    "type=s" => \$request_type,
    "output=s" => \$output
);

die "Wrong parameter: $request_type" unless $request_type ~~ ['next', 'unwatched'];
die "Wrong parameter: $output" unless $output ~~ ['stdout', 'notify-send'];

sub read_config {
    open my $fd, $CONFIG_PATH or die "Can't read $CONFIG_PATH: $!";
    my $conf;
    while (my $line = <$fd>) {
        my ($key, $val) = split '=', $line;
        chomp $val;
        $conf->{$key} = $val;
    }
    return $conf;
}

sub check_response {
    my ($response) = @_;
    die $response->status_line unless $response->is_success;
}

sub parse {
    my ($response) = @_;
    from_json $response->decoded_content();
}

sub get_series {
    my ($conf) = @_;
    my $ua = LWP::UserAgent->new;

    my $login = $conf->{login} // die "Can't find login in $CONFIG_PATH";
    my $md5_pass = md5_hex($conf->{password} // die "Can't find password in $CONFIG_PATH");

    my $response =
    $ua->get("http://api.myshows.ru/profile/login?login=$login&password=$md5_pass");
    check_response($response);

    $ua->default_header('cookie', join "\n", $response->header('set-cookie'));

    $response = $ua->get("http://api.myshows.ru/profile/episodes/$request_type/");
    check_response($response);

    return parse($response);
}

sub by_show {
    my ($episodes) = @_;
    my $by_show;
    foreach my $episode (values %$episodes) {
        push @{$by_show->{$episode->{showId}}}, $episode;
    }
    return $by_show;
}

#Color date in red if the air date is closer than 5 days to the current date
sub color_date {
    my ($date) = @_;

    my ($d1, $m1, $y1) = split '\.', $date;

    my (undef, undef, undef, $d2, $m2, $y2) = localtime;
    $m2++, $y2 += 1900;

    my $delta = 5;

    #I don't want to use DateTime module and ignore leap years
    my @m = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    if(
        $y2 - $y1 == 1 and $m1 == 12 and $m2 == 1 and (31 - $d1 + $d2) < $delta or
        $y2 == $y1 and
        (
            $m2 - $m1 == 1 and $m[$m1+1] - $d1 + $d2 < $delta or
            $m2 == $m1 and abs($d2 - $d1) < $delta
        )
    ) {
        if ($output eq 'notify-send') {
            return "<span color=\"red\">$date</span>";
        } else {
            return $date;
        }
    }

    return $date;
}

sub color_title {
    my ($title) = @_;

    if ($output eq 'notify-send') {
        return "<span color=\"#87D7FF\"><b>$title</b></span>";
    } else {
        return $title;
    }
}

sub get_show_titles {
    my @show_ids = @_;

    my $show_titles;

    if ($ASYNC) {
        my $async = HTTP::Async->new;

        foreach my $id (@show_ids) {
            $async->add(HTTP::Request->new(GET => "http://api.myshows.ru/shows/$id"));
        }

        while (my $response = $async->wait_for_next_response) {
            my $show = parse($response);
            $show_titles->{$show->{id}} = $show->{title};
        }
    } else {
        my $ua = LWP::UserAgent->new;
        foreach my $id (@show_ids) {
            my $response = $ua->get("http://api.myshows.ru/shows/$id");
            check_response($response);
            my $show = parse($response);
            $show_titles->{$show->{id}} = $show->{title};
        }
    }

    return $show_titles;
}

my $conf = read_config();

my $series = get_series($conf);

my $series_by_show = by_show($series);

my $show_titles = get_show_titles(keys %$series_by_show);

my @message;

foreach my $show_id (sort keys %$series_by_show) {
    my $episodes = $series_by_show->{$show_id};
    my $cnt = @$episodes;
    push @message, color_title("$show_titles->{$show_id} ($cnt)") . "\n";

    push @message, "\n";

    foreach (sort {$a->{seasonNumber} <=> $b->{seasonNumber} ||
                   $a->{episodeNumber} <=> $b->{episodeNumber}} @$episodes) {
        push @message, sprintf "%s S%02dE%02d %s\n",
            color_date($_->{airDate}), $_->{seasonNumber}, $_->{episodeNumber}, $_->{title};
    }

    push @message, "\n";
}

my $message = join "", @message;

$message =~ s/"/\\"/g;

if ($output eq 'notify-send') {
    system('notify-send -t 30000 "' . $message . '"');
} else {
    print $message;
}
