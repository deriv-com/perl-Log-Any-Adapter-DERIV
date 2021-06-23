use strict;
use warnings;
use Test::More;
use Log::Any qw($log);
use Log::Any::Adapter ('DERIV', log_level => 'info');
use Log::Any::Adapter::DERIV;
diag($log->{adapter}{log_level}); # 6
$log->info("hello");
ok(1);
done_testing();