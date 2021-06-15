use strict;
use warnings;
use Test::More;
use Log::Any qw($log);
use Log::Any::Adapter qw();
use Log::Any::Adapter::DERIV;
use Path::Tiny;
use Future;
use Clone qw(clone);

subtest 'collapse_future_stack' => sub {
    my $stack =  [
          {
            'line' => 451,
            'file' => '/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm',
            'package' => 'Future',
            'method' => '(eval)'
          },
          {
            'package' => 'Future',
            'file' => '/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm',
            'method' => '_mark_ready',
            'line' => 625
          },
          {
            'method' => 'done',
            'package' => 'main',
            'file' => 't/02-stack.t',
            'line' => 13
          }
        ];
        my $cloned_stack = clone($stack);
        shift $stack->@*;
        is_deeply(Log::Any::Adapter::DERIV->collapse_future_stack({stack => $cloned_stack }), {stack => $stack}, "stack is collapsed");
};


my $json_log_file = Path::Tiny->tempfile;
Log::Any::Adapter->import('DERIV', log_level => 'debug', json_log_file => $json_log_file);
my $f = Future->new;
#my $f2 = $f->then_done->then_done->then_done->then_done->then(sub{$log->debug("this is a debug message")});
my $sub = sub {$log->debug("this is a debug message"); return Future->done};
my $f2 = $f->then($sub);
$f->done;
my $message = $json_log_file->slurp;
diag(explain($message));
ok(1);
done_testing();