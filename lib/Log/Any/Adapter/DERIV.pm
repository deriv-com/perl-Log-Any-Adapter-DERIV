package Log::Any::Adapter::DERIV;
# ABSTRACT: one company's example of a standardised logging setup

use strict;
use warnings;

# AUTHORITY
our $VERSION = '0.001';

use parent qw(Log::Any::Adapter::Coderef);

use utf8;

=encoding utf8

=head1 NAME

Log::Any::Adapter::DERIV - standardised logging to STDERR and JSON file

=head1 DESCRIPTION

B<This is extremely invasive>. It does the following, affecting global state in various ways:

=over 4

=item * applies UTF-8 encoding to STDERR

=item * writes to a C<.json.log> file named for the current process

=item * overrides the default L<Log::Any::Proxy> formatter to provide data as JSON

=item * when stringifying, replaces some problematic objects with simplified versions

=back

An example of the string-replacement approach would be the event loop in asynchronous code:
it's likely to have many components attached to it, and dumping that would effectively end up
dumping the entire tree of useful objects in the process.

=cut

use Time::Moment;
use Path::Tiny;
use curry;
use JSON::MaybeUTF8 qw(:v1);
use PerlIO;
use Term::ANSIColor;

require Log::Any;
require Log::Any::Proxy;

# Used for stringifying data more neatly than Data::Dumper might offer
my $json = JSON::MaybeXS->new(
    pretty          => 1,
    canonical       => 1,
    convert_blessed => 1,
);

# The obvious way to handle this might be to provide our own proxy class:
#     $Log::Any::OverrideDefaultProxyClass = 'Log::Any::Proxy::DERIV';
# but the handling for proxy classes is somewhat opaque - and there's an ordering problem
# where `use Log::Any` before the adapter is loaded means we end up with some classes having
# the default anyway.
# Rather than trying to deal with that, we just provide our own default:
{
    no warnings 'redefine';
    *Log::Any::Proxy::_default_formatter = sub {
        my ( $cat, $lvl, $format, @params ) = @_;
        return $format->() if ref($format) eq 'CODE';

        chomp(
            my @new_params = map {
                eval { $json->encode($_) } // Log::Any::Proxy::_stringify_params($_)
            } @params
        );
        s{\n}{\n  }g for @new_params;

        # Perl 5.22 adds a 'redundant' warning if the number parameters exceeds
        # the number of sprintf placeholders.  If a user does this, the warning
        # is issued from here, which isn't very helpful.  Doing something
        # clever would be expensive, so instead we just disable warnings for
        # the final line of this subroutine.
        no warnings;
        return sprintf( $format, @new_params );
    };
}

use Log::Any qw($log);

$SIG{__WARN__} = sub {
    chomp(my $msg = shift);
    $log->warn($msg);
};

sub new {
    my ( $class, %args ) = @_;
    $args{colour} //= -t STDERR;
    my $self = $class->SUPER::new(sub { }, %args);
    $self->{in_container} = -r '/.dockerenv';
    unless($self->{in_container}) {
        $self->{fh} = path($0 . '.json.log')->opena_utf8 or die 'unable to open log file - ' . $!;
        $self->{fh}->autoflush(1);
    }
    $self->{code} = $self->curry::log_entry;
    return $self;
}

our %SEVERITY_COLOUR = (
    trace    => [qw(grey12)],
    debug    => [qw(grey18)],
    info     => [qw(green)],
    warning  => [qw(bright_yellow)],
    error    => [qw(red bold)],
    fatal    => [qw(red bold)],
    critical => [qw(red bold)],
);

sub log_entry {
    my ($self, $data) = @_;

    $self->{fh}->print(encode_json_text($data) . "\n") if $self->{fh};

    unless($self->{has_stderr_utf8}) {
        # We'd expect `encoding(utf-8-strict)` and `utf8` if someone's already applied binmode
        # for us, but implementation details in Perl may change those names slightly, and on
        # some platforms (Windows?) there's also a chance of one of the UTF16LE/BE variants,
        # so we make this check quite lax and skip binmode if there's anything even slightly
        # utf-flavoured in the mix.
        binmode STDERR, ':encoding(UTF-8)'
            unless grep /utf/i, PerlIO::get_layers(\*STDERR, output => 1);
        STDERR->autoflush(1);
        $self->{has_stderr_utf8} = 1;
    }
    my $from = $data->{stack}[-1] ? join '->', @{$data->{stack}[-1]}{qw(package method)} : 'main';
    my @details = (
        Time::Moment->from_epoch($data->{epoch})->strftime('%Y-%m-%dT%H:%M:%S%3f'),
        uc(substr $data->{severity}, 0, 1),
        "[$from]",
        $data->{message},
    );
    my $txt = $self->{colour}
    ? do {
        my @colours = ($SEVERITY_COLOUR{$data->{severity}} || die 'no severity definition found for ' . $data->{severity})->@*;
        # Colour formatting codes applied at the start and end of each line, in case something else
        # gets inbetween us and the output
        local $Term::ANSIColor::EACHLINE = "\n";
        my ($ts, $level, $from, @info) = @details;
        join ' ',
            colored(
                $ts,
                qw(bright_blue),
            ),
            colored(
                $level,
                @colours,
            ),
            colored(
                $from,
                qw(grey10)
            ),
            map {
                colored(
                    $_,
                    @colours,
                ),
            } @info
    }
    : $self->{in_container} # docker tends to prefer JSON
    ? encode_json_text($data)
    : join ' ', @details;

    # Regardless of the output, we always use newline separators
    STDERR->print(
        "$txt\n"
    );
}

1;
