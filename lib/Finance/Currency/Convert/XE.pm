package Finance::Currency::Convert::XE;

use 5.006;
use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '0.06';

### CHANGES ###############################################################
#   0.01   20/10/2002   Initial Release
#   0.02   08/10/2003   complete overhaul of POD and code.
#						POD updates
#   0.03   06/11/2003   Renamed upon finding a F:C:C:Yahoo distro
#   0.04   13/02/2004   Large number format bug, spotted by Alex Pavlovic
#   0.05   04/03/2004   More formatting options available
#                       Removed all non-Euro currencies for Euro adopted
#                         countries.
#                       Currency test bounds increased to +/- 2%
#                       Currency symbols use HTML entities where known.
#	0.06	19/04/2004	Test::More added as a prerequisites for PPMs
###########################################################################

#--------------------------------------------------------------------------

=head1 NAME

Finance::Currency::Convert::XE - Currency conversion module.

=head1 SYNOPSIS

  use Finance::Currency::Convert::XE;
  my $obj = new Finance::Currency::Convert::XE()	
             || die "Failed to create object\n" ;

  my $value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value' => '123.45',
                  'format' => 'text'
           ) || die "Could not convert: " . $obj->error . "\n";

  my @currencies = $obj->currencies;

=head1 DESCRIPTION

Currency conversion module using XE.com's Universal Currency Converter (tm)
site.

=cut

#--------------------------------------------------------------------------

###########################################################################
#Export Settings                                                          #
###########################################################################

require 5.004;
require Exporter;

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(currencies convert error);
@EXPORT		= qw();

###########################################################################
#Library Modules                                                          #
###########################################################################

use WWW::Mechanize;
use HTML::TokeParser;

###########################################################################
#Constants                                                                #
###########################################################################

use constant	UCC => 'http://www.xe.com/ucc/';

#--------------------------------------------------------------------------

###########################################################################
#Interface Functions                                                      #
###########################################################################

=head1 METHODS

=over 4

=item new

Creates a new Finance::Currency::Convert::XE object.

=cut

sub new {
	my ($this, @args) = @_;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;
	return undef unless( $self->_initialize(@args) );
	return $self;
}

=item currencies

Returns a plain array of the currencies available for conversion.

=cut

sub currencies {
	my $self = shift;
	return sort keys %{$self->{Currency}};
}

=item convert

Converts some currency value into another using XE.com's UCC.

An anonymous hash is used to pass parameters. Legal hash keys and values
are as follows:

  convert(
    source => $currency_from,
    target => $currency_to,
    value  => $currency_from_value,
    format => $print_format
  );

The format key is optional, and takes one of the following strings:

  'number' (returns '12.34')
  'symbol' (returns '&#163;12.34')
  'text'   (returns '12.34 British Pounds')
  'abbv'   (returns '12.34 GBP')

If format key is omitted, 'number' is assumed and the converted value 
is returned.

Note that not all countries have symbols in the standard character set.
Where known the appropriate currency symbol is used, otherwise the 
generic currency symbol is used.

It should also be noted that there is a recommendation to use only the
standardised three letter abbreviation ('abbv' above). However, for
further reading please see:

  http://www.jhall.demon.co.uk/currency/
  http://www.jhall.demon.co.uk/currency/by_symbol.html

=cut

sub convert {
	my ($self, %params) = @_;

	undef $self->{error};
	unless( exists($self->{Currency}->{$params{source}}) ){
		$_ = "Currency \"" . $params{source} . "\" is not available";
		$self->{error} = $_;
		warn(__PACKAGE__ . ": " . $_ . "\n");
		return undef;
	}

	unless( exists($self->{Currency}->{$params{target}}) ){
		$_ =  "Currency \"" . $params{target} . "\" is not available\n";
		$self->{error} = $_;
		warn(__PACKAGE__ . ': ' . $_);
		return undef;
	}

	# store later use
	$self->{code} = $params{target};
	$self->{name} = $self->{Currency}->{$params{target}}->{name};
	$self->{symbol} = $self->{Currency}->{$params{target}}->{symbol};
	$self->{format} = $self->_format($params{format});

	# This "feature" is actually useful as a pass-thru filter.
	if( $params{source} eq $params{target} ) {
		return sprintf $self->{format}, $params{value}
	}

	# get the base site
	my $web = new WWW::Mechanize;
	$web->get( UCC );
	return undef	unless($web->success());

	# complete and submit the form
	$web->submit_form(
			form_name => 'ucc',
			fields => {	'From' => $params{source}, 
						'To' => $params{target}, 
						'Amount' => $params{value} } );
	return undef	unless($web->success());

	# return the converted value
	return $self->_extract_text($web->content());
}

=item error

Returns a (hopefully) meaningful error string.

=cut

sub error {
	my $self = shift;
	return $self->{error};
}

###########################################################################
#Internal Functions                                                       #
###########################################################################

sub _initialize {
	my($self, %params) = @_;;

	# Extract the mapping of currencies and their atrributes
	while(<Finance::Currency::Convert::XE::DATA>){
		chomp;
		my ($code,$text,$symbol) = split ",";
		$self->{Currency}->{$code}->{name} = $text;
		$self->{Currency}->{$code}->{symbol} = $symbol;
	}

	return 1;
}

# Formats the return string to the requirements of the caller
sub _format {
	my($self, $form) = @_;

	my %formats = (
		'symbol' => $self->{symbol} . '%.02f',
		'abbv' => '%.02f ' . $self->{code},
		'text' => '%.02f ' . $self->{name},
		'number' => '%.02f',
	);

	return $formats{$form}	if(defined $form && $formats{$form});
	return '%.02f';
}

# Extract the text from the html we get back from UCC and return
# it (keying on the fact that what we want is in the table after
# the midmarket link).
sub _extract_text {
	my($self, $html) = @_;

	my $p = HTML::TokeParser->new(\$html);

	my $found = 0;
	my $tag;

	# look for the mid market link
	while(!$found) {
		return undef	unless($tag = $p->get_tag('a'));
		$found = 1	if(defined $tag->[1]{href} && $tag->[1]{href} =~ /midmarket/);
	}

	# jump to the next table
	$tag = $p->get_tag('table');


	# from there look for the target value
	while (my $token = $p->get_token) {
		my $text = $p->get_trimmed_text;

		my ($value) = ($text =~ /([\d\.\,]+) $self->{code}/);
		if($value) {
			$value =~ s/,//g;
			return sprintf $self->{format}, $value;
		}
	}

	# didn't find anything
	return undef;
}

1;

#--------------------------------------------------------------------------

=back

=head1 TERMS OF USE

XE.com have a Terms of Use policy that states:

  This website is for informational purposes only and is not intended to 
  provide specific commercial, financial, investment, accounting, tax, or 
  legal advice. It is provided to you solely for your own personal, 
  non-commercial use and not for purposes of resale, distribution, public 
  display or performance, or any other uses by you in any form or manner 
  whatsoever. Unless otherwise indicated on this website, you may display, 
  download, archive, and print a single copy of any information on this 
  website, or otherwise distributed from XE.com, for such personal, 
  non-commercial use, provided it is done pursuant to the User Conduct and 
  Obligations set forth herein.

As such this software is for personal use ONLY. No liability is accepted by
the author for abuse or miuse of the software herein. Use of this software
is only permitted under the terms stipulated by XE.com.

The full legal document is available at L<http://www.xe.com/legal/>

=head1 TODO

Currency symbols are currently specified with a generic symbol, if the
currency symbol is unknown. Are there any other symbols available in
Unicode? Let me know if there are.

=head1 AUTHOR

  Barbie, E<lt>barbie@cpan.orgE<gt>
  Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 SEE ALSO

  WWW::Mechanize
  HTML::TokeParser

  perl(1)

=head1 COPYRIGHT

  Copyright (C) 2002-2004 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or 
  modify it under the same terms as Perl itself.

=cut

#--------------------------------------------------------------------------

__DATA__
EUR,Euro,&#8364;
USD,United States Dollars,$
CAD,Canadian Dollars,$
GBP,British Pounds,&#163;
JPY,Japanese Yen,&#165;
DZD,Algerian Dinars,&#164;
ARS,Argentinian Pesos,&#164;
AUD,Australian Dollars,$
BSD,Bahamas Dollars,&#164;
BBD,Barbados Dollars,&#164;
BMD,Bermuda Dollars,&#164;
BRL,Brazilian Real,&#164;
BGL,Bulgarian Leva,&#164;
CLP,Chilian Pesos,&#164;
CNY,Chinese Yuan Renminbi,&#164;
CYP,Cypriot Pounds,&#164;
CZK,Czech Republic Koruny,&#164;
DKK,Denmark Kroner,&#164;
EGP,Egyptian Pounds,&#164;
FJD,Fijian Dollars,&#164;
HKD,Hong Kong Dollars,&#164;
HUF,Hungarian Forint,&#164;
ISK,Icelandic Kronur,&#164;
INR,Indian Rupees,&#8360;
IDR,Indonesian Rupiahs,&#164;
ILS,Israeli New Shekels,&#8362;
JMD,Jamaican Dollars,&#164;
JOD,Jordanian Dinars,&#164;
LBP,Lebanonese Pounds,&#164;
MYR,Malaysian Ringgits,&#164;
MXN,Mexican Pesos,&#164;
NZD,New Zealand Dollars,&#164;
NOK,Norweigan Kroner,&#164;
PKR,Pakistani Rupees,&#8360;
PHP,Philippino Pesos,&#164;
PLN,Polish Zlotych,&#164;
ROL,Romanian Lei,&#164;
RUR,Russian Rubles,&#164;
SAR,Saudi Arabian Riyals,&#164;
SGD,Singapore Dollars,&#164;
SKK,Slovakian Koruny,&#164;
ZAR,South African Rand,&#164;
KRW,South Korean Won,&#8361;
SDD,Sudanese Dinars,&#164;
SEK,Swedish Kronor,&#164;
TWD,Taiwan New Dollars,&#164;
THB,Thai Baht,&#3647;
TTD,Trinidad and Tobagoan Dollars,&#164;
TRL,Turkish Liras,&#164;
VEB,Venezuelan Bolivares,&#164;
ZMK,Zambian Kwacha,&#164;
XCD,Eastern Caribbean Dollars,&#164;
XDR,Special Drawing Right (IMF),&#164;
XAG,Silver Ounces,&#164;
XAU,Gold Ounces,&#164;
XPD,Palladium Ounces,&#164;
XPT,Platinum Ounces,&#164;
