package Finance::Currency::Convert::XE;

use 5.006;
use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '0.03';

### CHANGES #########################################################
#   0.01   20/10/2002   Initial Release
#   0.02   08/10/2003   complete overhaul of POD and code.
#						POD updates
#   0.03   06/11/2003   Renamed upon finding a F:C:C:Yahoo distro
#####################################################################

#----------------------------------------------------------------------------

=head1 NAME

Finance::Currency::Convert::XE - Currency conversion module.

=head1 SYNOPSIS

  use Finance::Currency::Convert::XE;
  my $obj = new Finance::Currency::Convert::XE()	|| die "Failed to create object\n" ;

  my $value = $obj->convert(
                  'source' => 'GBP',
                  'target' => 'EUR',
                  'value' => '123.45',
                  'format' => 'text'
           ) || die "Could not convert: " . $obj->error . "\n";

  my @currencies = $obj->currencies;

=head1 DESCRIPTION

Currency conversion module using XE.com's Universal Currency Converter (tm) site.

=cut

#----------------------------------------------------------------------------

#############################################################################
#Export Settings															#
#############################################################################

require 5.004;
require Exporter;

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(currencies convert error);
@EXPORT		= qw();

#############################################################################
#Library Modules															#
#############################################################################

use WWW::Mechanize;
use HTML::TokeParser;

#############################################################################
#Constants																	#
#############################################################################

use constant	UCC => 'http://www.xe.com/ucc/';

#----------------------------------------------------------------------------

#############################################################################
#Interface Functions														#
#############################################################################

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
  'text'   (returns '12.34 British Pounds')

If format key is omitted, 'number' is assumed and the converted value 
is returned.

=cut

# The following formats are proposed for later versions:
#
# 'symbol' => '£12.34'
# 'symbol text' => '£12.34 British Pounds'
#
# However, some currencies do not format their currencies with their
# currency symbol preceeding the values, while others use commas to
# separate their large and small denominations (e.g. 23,45DM)

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
	$self->{name} = $self->{Currency}->{$params{target}};
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

#############################################################################
#Internal Functions															#
#############################################################################

sub _initialize {
	my($self, %params) = @_;;

	# Extract the mapping of currencies and their atrributes
	while(<Finance::Currency::Convert::XE::DATA>){
		chomp;
		my ($code,$text) = split ",";
		$self->{Currency}->{$code} = $text;
	}

	return 1;
}

# Formats the return string to the requirements of the caller
sub _format {
	my($self, $form) = @_;

	my %formats = (
#		'symbol' => $self->{symbol} . '%s',
#		'symbol text' => $self->{symbol} . '%s ' . $self->{name},
		'text' => '%s ' . $self->{name},
		'number' => '%s',
	);

	return $formats{$form}	if(defined $form && $formats{$form});
	return '%s';
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

		return sprintf $self->{format}, $1
			if($text =~ /([\d\.]+) $self->{code}/);
	}

	# didn't find anything
	return undef;
}

1;

#----------------------------------------------------------------------------

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

=head1 AUTHOR

  Barbie, E<lt>barbie@cpan.orgE<gt>
  Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 SEE ALSO

  WWW::Mechanize
  HTML::TokeParser

  perl(1)

=head1 COPYRIGHT

  Copyright (C) 2002-2003 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or 
  modify it under the same terms as Perl itself.

=cut

#----------------------------------------------------------------------------

__DATA__
EUR,Euro
USD,United States Dollars
CAD,Canadian Dollars
GBP,British Pounds
DEM,German Deutsche Marks
FRF,French Francs
JPY,Japanese Yen
NLG,Dutch Guilders
ITL,Italian Lire
CHF,Swiss Francs
DZD,Algerian Dinars
ARS,Argentinian Pesos
AUD,Australian Dollars
ATS,Austrian Schillings
BSD,Bahamas Dollars
BBD,Barbados Dollars
BEF,Belgium Francs
BMD,Bermuda Dollars
BRL,Brazilian Real
BGL,Bulgarian Leva
CAD,Canadian Dollars
CLP,Chilian Pesos
CNY,Chinese Yuan Renminbi
CYP,Cypriot Pounds
CZK,Czech Republic Koruny
DKK,Denmark Kroner
EGP,Egyptian Pounds
FJD,Fijian Dollars
FIM,Finnish Markkaa
GRD,Greek Drachmae
HKD,Hong Kong Dollars
HUF,Hungarian Forint
ISK,Icelandic Kronur
INR,Indian Rupees
IDR,Indonesian Rupiahs
IEP,Irish Pounds
ILS,Israeli New Shekels
JMD,Jamaican Dollars
JOD,Jordanian Dinars
KRW,Korean (South) Won
LBP,Lebanonese Pounds
LUF,Luxembourg Francs
MYR,Malaysian Ringgits
MXN,Mexican Pesos
NZD,New Zealand Dollars
NOK,Norweigan Kroner
PKR,Pakistani Rupees
PHP,Philippino Pesos
PLN,Polish Zlotych
PTE,Portugese Escudos
ROL,Romanian Lei
RUR,Russian Rubles
SAR,Saudi Arabian Riyals
SGD,Singapore Dollars
SKK,Slovakian Koruny
ZAR,South African Rand
KRW,South Korean Won
ESP,Spanish Pesetas
SDD,Sudanese Dinars
SEK,Swedish Kronor
TWD,Taiwan New Dollars
THB,Thai Baht
TTD,Trinidad and Tobagoan Dollars
TRL,Turkish Liras
VEB,Venezuelan Bolivares
ZMK,Zambian Kwacha
XCD,Eastern Caribbean Dollars
XDR,Special Drawing Right (IMF)
XAG,Silver Ounces
XAU,Gold Ounces
XPD,Palladium Ounces
XPT,Platinum Ounces
