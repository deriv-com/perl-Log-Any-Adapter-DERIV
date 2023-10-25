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

foreach my $key (keys %{$context}) {
    $data->{$key} = $context->{$key};
}

is($data->{key1}, 'value1', 'key1 is part of data');

$adapter->clear_context;
is($adapter->{context}, undef, 'clear_context removes the context');

done_testing();
