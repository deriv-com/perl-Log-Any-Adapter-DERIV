use strict;
use warnings;

use Test::More;

use Test::MockTime::HiRes qw(set_fixed_time);
use Log::Any qw($log);
use Log::Any::Adapter;
use Path::Tiny;
use JSON::MaybeUTF8 qw(:v1);
use Test::Exception;
use Sys::Hostname;
use Test::MockModule;
use Term::ANSIColor qw(colored);
set_fixed_time(1623247131);
subtest "json file" => sub {
    ok(1);
    my $json_log_file = Path::Tiny->tempfile();
    Log::Any::Adapter->import('DERIV', json_log_file => "$json_log_file");
    $log->warn('this is a warn log');
    my $log_message = $json_log_file->slurp;
    chomp($log_message);
    lives_ok {$log_message = decode_json_text($log_message)} 'log message is a valid json';
    is_deeply([sort keys %$log_message], [sort qw(pid stack severity host epoch message)]);
    is($log_message->{host}, hostname(), "host name ok");
    is($log_message->{pid}, $$, "pid ok");
    is($log_message->{message}, 'this is a warn log', "message ok");
    is($log_message->{severity}, 'warning', "severity ok");
    done_testing();
};

subtest 'log to stderr' => sub {
    my $mocked_deriv = Test::MockModule->new('Log::Any::Adapter::DERIV');
    $mocked_deriv->mock('_stderr_is_tty', sub{
        return 1;
    });
    $mocked_deriv->mock('_in_container', sub {
        return 0;
    });
    Log::Any::Adapter->import('DERIV', stderr => 1);
    my $log_message = '';
    {
        local *STDERR;
        open STDERR, '>', \$log_message;
        $log->warn("This is a warn log");
    } 
    chomp($log_message);
    diag(explain $log_message);
    my $expected_message = join " ", colored('2021-06-09T13:58:51', 'bright_blue'), colored('W', 'bright_yellow'),
        colored('[main->subtest]', 'grey10'), colored('This is a warn log', 'bright_yellow');
    is($log_message, $expected_message);
    ok(1);

};
done_testing();