#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More tests => 12;

###########################################################

	use Finance::Currency::Convert::XE;
	my $obj = new Finance::Currency::Convert::XE();
	isa_ok($obj,'Finance::Currency::Convert::XE');

	my @currencies = $obj->currencies;
	is(scalar(@currencies),70);
	is($currencies[0] ,'ARS');
	is($currencies[24],'GBP');
	is($currencies[69],'ZMK');

	my ($start,$final,$offset,$value) = ('10000.00',14750,50);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'number');

	# have to account for currency fluctuations
	cmp_ok($value, ">", ($final - $offset));
	cmp_ok($value, "<", ($final + $offset));

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

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'GBP',
                  'value'  => $start);
	is($value,$start);	# no conversion, should be the same

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'GBP',
                  'value'  => $start,
                  'format' => 'text');
	like($value,qr/\d+\.\d+ British Pounds/);

###########################################################

