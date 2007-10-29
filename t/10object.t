#!/usr/bin/perl
use strict;

use lib 't';

use Test::More tests => 36;
use Finance::Currency::Convert::XE;

###########################################################

my %format_tests = (
	'GBP' => {	'text'		=> qr/\d+\.\d+ British Pounds/,
				'symbol'	=> qr/&#163;\d+\.\d+/,
				'abbv'		=> qr/\d+\.\d+ GBP/ },
	'EUR' => {	'text'		=> qr/\d+\.\d+ Euro/,
				'symbol'	=> qr/&#8364;\d+\.\d+/,
				'abbv'		=> qr/\d+\.\d+ EUR/ },
	'ZMK' => {	'text'		=> qr/\d+\.\d+ Zambian Kwacha/,
				'symbol'	=> qr/&#164;\d+\.\d+/,
				'abbv'		=> qr/\d+\.\d+ ZMK/ },
);

# offset hopefully allows for a large degree fluctuation
my ($start,$final,$offset) = ('10000.00',14500,1000);
my ($value,$error);

###########################################################

{
	my $obj = Finance::Currency::Convert::XE->new();
	isa_ok($obj,'Finance::Currency::Convert::XE','... got the object');

	my @currencies = $obj->currencies;
	is(scalar(@currencies),82,'... correct number of currencies');
	is($currencies[0] ,'AED','... valid currency: first');
	is($currencies[27],'GBP','... valid currency: GBP');
	is($currencies[81],'ZMK','... valid currency: last');

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'number');

    $error = $obj->error;
    SKIP: {
        skip $error, 3  if(!$value && $error =~ /Unable to retrieve/);

        # have to account for currency fluctuations
        cmp_ok($value, ">", ($final - $offset),'... conversion above lower limit');
        cmp_ok($value, "<", ($final + $offset),'... conversion above upper limit');
        like($value,qr/^\d+\.\d+$/,'... conversion matches a number');
    }

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'text');

    $error = $obj->error;
    SKIP: {
        skip $error, 1  if(!$value && $error =~ /Unable to retrieve/);

    	like($value,qr/\d+\.\d+ Euro/,'... conversion matches a text pattern');
    }

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start);
    $error = $obj->error;
    SKIP: {
        skip $error, 3  if(!$value && $error =~ /Unable to retrieve/);

        # have to account for currency fluctuations
        cmp_ok($value, ">", ($final - $offset),'... default format conversion above lower limit');
        cmp_ok($value, "<", ($final + $offset),'... default format conversion above upper limit');
        like($value,qr/^\d+\.\d+$/,'... default format conversion matches a number');
    }

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'GBP',
                  'value'  => $start);
   	is($value,$start,'... no conversion, should be the same');

	foreach my $curr (keys %format_tests) {
		foreach my $form (keys %{$format_tests{$curr}}) {
			$value = $obj->convert(
						  'source' => $curr,
						  'target' => $curr,
						  'value'  => $start,
						  'format' => $form);
            $error = $obj->error;
            SKIP: {
                skip $error, 1  if(!$value && $error =~ /Unable to retrieve/);

    			like($value,$format_tests{$curr}->{$form},"... format test: $curr/$form");
            }
		}
	}
}

{
	my $obj = Finance::Currency::Convert::XE->new(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'format' => 'bogus');
	isa_ok($obj,'Finance::Currency::Convert::XE','... got the object');

	$value = $obj->convert($start);
    $error = $obj->error;
    SKIP: {
        skip $error, 3  if(!$value && $error =~ /Unable to retrieve/);

        # have to account for currency fluctuations
        cmp_ok($value, ">", ($final - $offset),'... defaults conversion above lower limit');
        cmp_ok($value, "<", ($final + $offset),'... defaults conversion above upper limit');
        like($value,qr/^\d+\.\d+$/,'... defaults conversion matches a number');
    }
}

{
	my $obj = Finance::Currency::Convert::XE->new(
                  'source' => 'GBP',
                  'target' => 'ARS',
                  'format' => 'number');
	isa_ok($obj,'Finance::Currency::Convert::XE','... got the object');

	$value = $obj->convert($start);
    $error = $obj->error;
    SKIP: {
        skip $error, 1  if(!$value && $error =~ /Unable to retrieve/);

        # Apparently ARS has been causing problems
        like($value,qr/^\d+\.\d+$/,'... defaults conversion matches a number');
    }
}

{
	my $obj = Finance::Currency::Convert::XE->new();

    $value = $obj->convert($start);
    is( $value, undef, '... blank source');
    like( $obj->error, qr/Source currency is blank/, '... blank source (error method)');

    $value = $obj->convert(value => $start, source => 'GBP');
    is( $value, undef, '... blank target');
    like( $obj->error, qr/Target currency is blank/, '... blank target (error method)');

    $value = $obj->convert(value => $start, source => 'bogus');
    is( $value, undef, '... bogus source');
    like( $obj->error, qr/is not available/, '... bogus source (error method)');

    $value = $obj->convert(value => $start, source => 'GBP', target => 'bogus');
    is( $value, undef, '... bogus target');
    like( $obj->error, qr/is not available/, '... bogus target (error method)');
}

###########################################################

