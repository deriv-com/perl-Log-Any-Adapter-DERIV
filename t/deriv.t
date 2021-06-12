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

    my $mocked_deriv = Test::MockModule->new('Log::Any::Adapter::DERIV');
    my $stderr_is_tty;
    $mocked_deriv->mock('_stderr_is_tty', sub{
        return $stderr_is_tty;
    });
    my $in_container;
    $mocked_deriv->mock('_in_container', sub {
        return $in_container;
    });
 

sub test_json {
    my $log_message = shift;
    chomp($log_message);
    lives_ok {$log_message = decode_json_text($log_message)} 'log message is a valid json';
    is_deeply([sort keys %$log_message], [sort qw(pid stack severity host epoch message)]);
    is($log_message->{host}, hostname(), "host name ok");
    is($log_message->{pid}, $$, "pid ok");
    is($log_message->{message}, 'This is a warn log', "message ok");
    is($log_message->{severity}, 'warning', "severity ok");
}

sub test_color_text{
    my $log_message = shift;
        chomp($log_message);
        my $expected_message = join " ", colored('2021-06-09T13:58:51', 'bright_blue'), colored('W', 'bright_yellow'),
            colored('[main->do_test]', 'grey10'), colored('This is a warn log', 'bright_yellow');
        is($log_message, $expected_message, "colored text ok");
}
sub test_text{
    my $log_message = shift;
    chomp($log_message);
        my $expected_message = join " ", '2021-06-09T13:58:51', 'W', '[main->do_test]', 'This is a warn log';
        is($log_message, $expected_message, "text message ok");
}
my $stderr_log_message;
my $file_log_message;
my $json_log_file = Path::Tiny->tempfile();
sub call_log{
    my $import_args = shift;
    
        local *STDERR;
        $stderr_log_message = '';
        $file_log_message = '';
        $json_log_file->remove;
        open STDERR, '>', \$stderr_log_message;
        Log::Any::Adapter->import('DERIV', $import_args->%*);
        $log->warn("This is a warn log");
        $file_log_message = $json_log_file->exists ? $json_log_file->slurp : '';
}
subtest "json file" => sub {
    my $json_log_file = Path::Tiny->tempfile();
    Log::Any::Adapter->import('DERIV', json_log_file => "$json_log_file");
    $log->warn('This is a warn log');
    my $log_message = $json_log_file->slurp;
    test_json($log_message);
   done_testing();
};

subtest 'log to stderr' => sub {
   my $log_message;
    my $call_log = sub {
        local *STDERR;
        $log_message = '';
        open STDERR, '>', \$log_message;
        $log->warn("This is a warn log");
    }; 

    my $test_color_log = sub {
        chomp($log_message);
        my $expected_message = join " ", colored('2021-06-09T13:58:51', 'bright_blue'), colored('W', 'bright_yellow'),
            colored('[main->subtest]', 'grey10'), colored('This is a warn log', 'bright_yellow');
        is($log_message, $expected_message, "stderr is tty, no in_container, the log is colored text format");
    };
    subtest 'stderr is tty, not in container, has stderr'  => sub {
        $stderr_is_tty = 1;
        $in_container = 0; 
        Log::Any::Adapter->import('DERIV', stderr => 1);
        $call_log->();
        subtest 'color log' => $test_color_log;
   };
   subtest 'stderr is tty, not in container, has no stderr, default should be stderr' => sub {
        $stderr_is_tty = 1;
        $in_container = 0;
        Log::Any::Adapter->import('DERIV');
        $call_log->();
        subtest 'color log' => $test_color_log;
   };
   subtest 'stderr is tty, not in container, has stderr with value text' => sub {
        $stderr_is_tty = 1;
        $in_container = 0;
        Log::Any::Adapter->import('DERIV', stderr => 'text');
        $call_log->();
        subtest 'color log' => $test_color_log;
   };
   subtest 'stderr is tty, not in container, has stderr with value json' => sub {
        $stderr_is_tty = 1;
        $in_container = 0;
        Log::Any::Adapter->import('DERIV', stderr => 'json');
        $call_log->();
        test_json($log_message);
    };
    subtest 'stderr is tty, in container, no stderr' => sub {
        $stderr_is_tty = 1;
        $in_container = 1;
        Log::Any::Adapter->import('DERIV');
        $call_log->();
        test_json($log_message);
    };
};

sub do_test{
    my %args = @_;
    subtest encode_json_text(\%args) => sub{
        $stderr_is_tty = $args{stderr_is_tty};
        $in_container = $args{in_container};
        call_log($args{import_args});
        if($args{test_json_file}){
            ok($file_log_message, 'json file has logs');
            test_json($file_log_message);
        };
        return unless $args{test_stderr};
        ok($stderr_log_message, "STDERR has logs");
        if($args{test_stderr} eq 'json'){
            test_json($stderr_log_message);
        }elsif($args{test_stderr} eq 'color_text'){
            test_color_text($stderr_log_message);
        }else{
            test_text($stderr_log_message);
        }
    }
}

do_test(stderr_is_tty => 1, in_container => 1, import_args => {stderr => 1}, test_stderr => 'json');
do_test(stderr_is_tty => 1, in_container => 1, import_args => {stderr => 'text'}, test_stderr => 'color_text');
done_testing();