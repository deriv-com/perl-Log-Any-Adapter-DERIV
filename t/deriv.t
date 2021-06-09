use strict;
use warnings;

use Test::More;

use Log::Any qw($log);
use Log::Any::Adapter;
use Path::Tiny;
use JSON::MaybeUTF8 qw(:v1);
use Test::Exception;
use Sys::Hostname;

subtest "json file" => sub {
    ok(1);
    my $json_log_file = Path::Tiny->tempfile();
    Log::Any::Adapter->import('DERIV', json_log_file => "$json_log_file");
    $log->warn('this is a warn log');
    my $log_message = $json_log_file->slurp;
    chomp($log_message);
    lives_ok {$log_message = decode_json_text($log_message)} 'log message is a valid json';
    diag(explain($log_message));
    is_deeply([sort keys %$log_message], [sort qw(pid stack severity host epoch message)]);
    is($log_message->{host}, hostname(), "host name ok");
    is($log_message->{pid}, $$, "pid ok");
    is($log_message->{message}, 'this is a warn log', "message ok");
    is($log_message->{severity}, 'warning', "severity ok");
    done_testing();
};

done_testing();