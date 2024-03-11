use strict;
use warnings;

use Test::More;

use Log::Any qw($log);
use Log::Any::Adapter;
use Path::Tiny;
use JSON::MaybeUTF8 qw(:v1);
use Test::Exception;
use Test::MockModule;
use Try::Tiny;

my $file_log_message;
# create a temporary file to store the log message
my $json_log_file = Path::Tiny->tempfile();

sub do_sensitive_mask_test {
    my %args = @_;

    $file_log_message = '';
    $json_log_file->remove;
    Log::Any::Adapter->import('DERIV', $args{import_args}->%*);
    
    my $email = 'abc@gmail.com';
    my $api_key = '23892jsjdkajdad';
    my $api_token = 'jsahjdasdpdpadka';
    my $oauth_token = 'a1-Mr3GSXISsKGOeDYzvacEbSwC2mk0w';

    $log->warn("User $email is logged in");
    $log->warn("The API key: $api_key");
    $log->warn("The API token = $api_token");
    $log->warn("The OAuth token is $oauth_token");
    
    my @expected_masked_messages = (
        "User $email is logged in",
        "The API key: " . '*' x length($api_key),
        "The API token = " . '*' x length($api_token),
        "The OAuth token is " . '*' x length($oauth_token),
    );

    $file_log_message = $json_log_file->exists ? $json_log_file->slurp : '';
    chomp($file_log_message);

    my @log_entries = map { decode_json_text($_) } split("\n", $file_log_message);

    foreach my $index (0 .. $#expected_masked_messages) {
        my $expected_message = $expected_masked_messages[$index];
        my $actual_message = $log_entries[$index]{message};

        is($actual_message, $expected_message, "Message $index is masked correctly");
    }
}


do_sensitive_mask_test(
    stderr_is_tty  => 0,
    in_container   => 0,
    import_args    => {json_log_file => "$json_log_file"},
    test_json_file => 1,
);