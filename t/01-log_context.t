use strict;
use warnings;

use Test::More;

use Log::Any qw($log);
use Log::Any::Adapter;
use Path::Tiny;
use JSON::MaybeUTF8 qw(:v1);
use Test::Exception;
use Test::MockModule;

my $file_log_message;
my $json_log_file = Path::Tiny->tempfile();

sub do_context_text {
    my %args = @_;

    # Remove this line to avoid empty string initialization
    $file_log_message = '';
    $json_log_file->remove;
    Log::Any::Adapter->import('DERIV', $args{import_args}->%*);
    $log->adapter->set_context($args{context});
    $log->warn("This is a warn log");
    $file_log_message = $json_log_file->exists ? $json_log_file->slurp : '';
    chomp($file_log_message);
    lives_ok { $file_log_message = decode_json_text($file_log_message) }
    'log message is a valid json';
    # Read the log message from the file  
    is( $file_log_message->{correlation_id},     '1241421662',           "context ok" );
    $log->adapter->clear_context;
}

do_context_text(
    stderr_is_tty  => 0,
    in_container   => 0,
    import_args    => { json_log_file => "$json_log_file" },
    test_json_file => 1,
    context        => { correlation_id => "1241421662"},
);
done_testing();
