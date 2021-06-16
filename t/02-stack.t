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
    my $sample_stack = [
        {
            'line' => 451,
            'file' => '/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm',
            'package' => 'Future',
            'method'  => '(eval)'
        },
        {
            'package' => 'Future',
            'file' => '/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm',
            'method' => '_mark_ready',
            'line'   => 625
        },
        {
            'method'  => 'done',
            'package' => 'main',
            'file'    => 't/02-stack.t',
            'line'    => 13
        }
    ];
    my $arg_stack      = clone($sample_stack);
    my $expected_stack = clone($arg_stack);
    shift $expected_stack->@*;
    is_deeply(
        Log::Any::Adapter::DERIV->collapse_future_stack(
            { stack => $arg_stack }
        ),
        { stack => $expected_stack },
        "stack is collapsed"
    );
    $arg_stack = clone($sample_stack);
    pop $arg_stack->@*;
    $expected_stack = clone($arg_stack);
    shift $expected_stack->@*;
    is_deeply(
        Log::Any::Adapter::DERIV->collapse_future_stack(
            { stack => $arg_stack }
        ),
        { stack => $expected_stack },
        "stack is collapsed when the last one is a Future"
    );
};

subtest 'test collapse from message' => sub {
    my $get_message = sub {
        my $f             = shift;
        my $json_log_file = Path::Tiny->tempfile;
        Log::Any::Adapter->import(
            'DERIV',
            log_level     => 'debug',
            json_log_file => $json_log_file
        );
        $f->done;
        my $message = $json_log_file->slurp;
        chomp $message;
        $message = decode_json_text($message);
        return $message;
    };

    my $f1  = Future->new;
    my $f2 = $f1->then_done->then_done->then_done->then_done->then(
        sub { $log->debug("this is a debug message") } );
    my $message        = $get_message->($f1);
    my $expected_stack = decode_json_text(
'[{"method":"_mark_ready","line":625,"package":"Future","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm"},{"method":"done","file":"t/02-stack.t","package":"main","line":65},{"line":75,"package":"main","file":"t/02-stack.t","method":"__ANON__"},{"file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/Builder.pm","package":"Test::Builder","line":334,"method":"__ANON__"},{"method":"(eval)","package":"Test::Builder","line":334,"file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/Builder.pm"},{"method":"subtest","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/More.pm","package":"Test::More","line":809},{"file":"t/02-stack.t","package":"main","line":92,"method":"subtest"}]'
    );
    is_deeply( $message->{stack}, $expected_stack,
        "the stack value is correct" );

    $f1 = Future->new;
    $f2 = Future->new;
    my $f3 = $f1->then_done->then_done->then( sub { $f2->done } );
    my $f4 = $f2->then_done->then_done->then(
        sub { $log->debug("this is a debug message"); Future->done } );
    $message = $get_message->($f1);
    my $expected_stack = decode_json_text(
'[{"package":"Future","line":625,"file":"/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm","method":"_mark_ready"},{"method":"done","file":"t/02-stack.t","line":84,"package":"main"},{"method":"_mark_ready","line":625,"package":"Future","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Future.pm"},{"method":"done","package":"main","line":65,"file":"t/02-stack.t"},{"method":"__ANON__","line":87,"package":"main","file":"t/02-stack.t"},{"method":"__ANON__","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/Builder.pm","line":334,"package":"Test::Builder"},{"line":334,"package":"Test::Builder","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/Builder.pm","method":"(eval)"},{"method":"subtest","file":"/home/git/regentmarkets/cpan/local/lib/perl5/Test/More.pm","package":"Test::More","line":809},{"file":"t/02-stack.t","line":92,"package":"main","method":"subtest"}]'
    );
    is_deeply( $message->{stack}, $expected_stack, "more example" );
};
done_testing();
