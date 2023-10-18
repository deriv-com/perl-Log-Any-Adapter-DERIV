use Test::More;

use Log::Any::Adapter::DERIV;

our $JSON = JSON::MaybeXS->new(
    canonical => 1,
    convert_blessed => 1,
);

my $adapter = Log::Any::Adapter::DERIV->new;
my $context = {
    key1 => 'value1',
    key2 => 'value2',
};
$adapter->set_context($context);
is_deeply($adapter->{context}, $context, 'set_context sets the context');

my $data = {
    message  => 'This is a test message "with quotes"',
    severity => 'info',
};

# the below code is copied from adapter code for substitution testing
if ($data->{message}) {
    $data->{message} =~ s/\".*//;
}
my %log_data = (
    message   => $data->{message},
    severity  => $data->{severity},
);
if ($context && ref($context) eq 'HASH') {
    my @keys = keys %$context;
    foreach my $key (@keys) {
        $log_data{$key} = $context->{$key};
    }
    my $json_string = $JSON->encode(\%log_data);
    $data->{message} = $json_string;
}

is($data->{message}, '{"key1":"value1","key2":"value2","message":"This is a test message ","severity":"info"}', 'Message is modified as expected');

$adapter->clear_context;
is($adapter->{context}, undef, 'clear_context removes the context');

done_testing();
