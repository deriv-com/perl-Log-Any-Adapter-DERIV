use strict;
use warnings;
use Test::More;
use Log::Any qw($log);
use Log::Any::Adapter qw();
use Log::Any::Adapter::DERIV;
use Path::Tiny;
use Future;
use JSON::MaybeUTF8 qw(:v1);
use Clone qw(clone);

subtest 'collapse_future_stack' => sub {
    my $sample_stack =  [
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
        my $arg_stack = clone($sample_stack);
        my $expected_stack = clone($arg_stack);
        shift $expected_stack->@*;
        is_deeply(Log::Any::Adapter::DERIV->collapse_future_stack({stack => $arg_stack }), {stack => $expected_stack}, "stack is collapsed");
        $arg_stack = clone($sample_stack);
        pop $arg_stack->@*;
        $expected_stack = clone($arg_stack);
        shift $expected_stack->@*;
        is_deeply(Log::Any::Adapter::DERIV->collapse_future_stack({stack => $arg_stack }), {stack => $expected_stack}, "stack is collapsed when the last one is a Future");
};

subtest 'test collapse from message' => sub {
  my $json_log_file = Path::Tiny->tempfile;
  Log::Any::Adapter->import('DERIV', log_level => 'debug', json_log_file => $json_log_file);
  my $f = Future->new;
  my $f2 = $f->then_done->then_done->then_done->then_done->then(sub{$log->debug("this is a debug message")});
  $f->done;
  my $message = $json_log_file->slurp;
  chomp $message;
  $message = decode_json_text($message);
  my $expected_stack = decode_json_text('[{"line":625,"package":"Future","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm","method":"_mark_ready"},{"method":"done","package":"main","file":"t/02-stack.t","line":49},{"package":"Test::Builder","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/Builder.pm","line":334,"method":"__ANON__"},{"method":"(eval)","line":334,"package":"Test::Builder","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/Builder.pm"},{"line":809,"package":"Test::More","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/More.pm","method":"subtest"},{"line":55,"package":"main","file":"t/02-stack.t","method":"subtest"}]');
  is_deeply($message->{stack}, $expected_stack, "the stack value is correct");
};
done_testing();