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

	my ($start,$final,$offset,$value) = ('100.00',140,10);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'number');

	# have to account for currency fluctuations
	is($value > ($final - $offset),1);
	is($value < ($final + $offset),1);

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start,
                  'format' => 'text');
	ok(($value =~ /\d+\.\d+ Euro/ ? 1 : 0));

	$value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value'  => $start);
	# have to account for currency fluctuations
	is($value > ($final - $offset),1);
	is($value < ($final + $offset),1);

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
	ok(($value =~ /\d+\.\d+ British Pounds/ ? 1 : 0));

###########################################################

