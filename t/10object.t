#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More tests => 22;

###########################################################

	use Finance::Currency::Convert::XE;
	my $obj = new Finance::Currency::Convert::XE();
	isa_ok($obj,'Finance::Currency::Convert::XE');

	my @currencies = $obj->currencies;
	is(scalar(@currencies),57);
	is($currencies[0] ,'ARS');
	is($currencies[17],'GBP');
	is($currencies[56],'ZMK');

	# offset is approx 2% each way
	my ($start,$final,$offset,$value) = ('10000.00',14500,300,0);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'number');

	# have to account for currency fluctuations
	cmp_ok($value, ">", ($final - $offset));
	cmp_ok($value, "<", ($final + $offset));
	like($value,qr/^\d+\.\d+$/);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'text');
	like($value,qr/\d+\.\d+ Euro/);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start);
	# have to account for currency fluctuations
	cmp_ok($value, ">", ($final - $offset));
	cmp_ok($value, "<", ($final + $offset));
	like($value,qr/^\d+\.\d+$/);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'GBP',
                  'value'  => $start);
	is($value,$start);	# no conversion, should be the same


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

	foreach my $curr (keys %format_tests) {
		foreach my $form (keys %{$format_tests{$curr}}) {
			$value = $obj->convert(
						  'source' => $curr,
						  'target' => $curr,
						  'value'  => $start,
						  'format' => $form);
			like($value,$format_tests{$curr}->{$form});
		}
	}

###########################################################

