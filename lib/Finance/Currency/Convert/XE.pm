package Finance::Currency::Convert::XE;

use 5.006;
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.13';

#--------------------------------------------------------------------------

=head1 NAME

Finance::Currency::Convert::XE - Currency conversion module.

=head1 SYNOPSIS

  use Finance::Currency::Convert::XE;
  my $obj = Finance::Currency::Convert::XE->new()   
                || die "Failed to create object\n" ;

  my $value = $obj->convert(
                    'source' => 'GBP',
                    'target' => 'EUR',
                    'value' => '123.45',
                    'format' => 'text'
            )   || die "Could not convert: " . $obj->error . "\n";

  my @currencies = $obj->currencies;

or

  use Finance::Currency::Convert::XE;
  my $obj = Finance::Currency::Convert::XE->new(
                    'source' => 'GBP',
                    'target' => 'EUR',
                    'format' => 'text'
            )   || die "Failed to create object\n" ;

  my $value = $obj->convert(
                    'value' => '123.45',
                    'format' => 'abbv'
           )   || die "Could not convert: " . $obj->error . "\n";

  $value = $obj->convert('123.45')
                || die "Could not convert: " . $obj->error . "\n";

  my @currencies = $obj->currencies;

=head1 DESCRIPTION

Currency conversion module using XE.com's Universal Currency Converter (tm)
site.

WARNING: Do not use this module for any commercial purposes, unless you have 
obtain an explicit license to use the service provided by XE.com. For further 
details please read the Terms and Conditions available at L<http://www.xe.com>.

=over

=item * http://www.xe.com/errors/noautoextract.htm

=back

=cut

#--------------------------------------------------------------------------

###########################################################################
#Library Modules                                                          #
###########################################################################

use WWW::Mechanize;
use HTML::TokeParser;

###########################################################################
#Constants                                                                #
###########################################################################

use constant    UCC => 'http://www.xe.com/ucc';

###########################################################################
#Variables                                                                #
###########################################################################

my %currencies; # only need to load once!
my @defaults = ('source', 'target', 'format');

my $web = WWW::Mechanize->new();
$web->agent_alias( 'Windows Mozilla' );

#--------------------------------------------------------------------------

###########################################################################
#Interface Functions                                                      #
###########################################################################

=head1 METHODS

=over 4

=item new

Creates a new Finance::Currency::Convert::XE object. Can be supplied with
default values for source and target currency, and the format required of the
output. These can be overridden in the convert() method.

=cut

sub new {
    my ($this, @args) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@args);
    return $self;
}

=item currencies

Returns a plain array of the currencies available for conversion.

=cut

sub currencies {
    my $self = shift;
    return sort keys %currencies;
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

If only a value is passed, it is assumed that this is the value to be 
converted and the remaining parameters will be defined by the defaults set
in the constructor. Note that no internal defaults are assumed.

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
    my $self = shift;
    my %params = @_ > 1 ? @_ : (value => $_[0]);
    $params{$_} ||= $self->{$_} for(@defaults);

    undef $self->{error};
    unless( $params{source} ){
        $self->{error} = 'Source currency is blank. This parameter is required';
        return;
    }

    unless( exists($currencies{$params{source}}) ){
        $self->{error} = 'Source currency "' . $params{source} . '" is not available';
        return;
    }

    unless( $params{target} ){
        $self->{error} = 'Target currency is blank. This parameter is required';
        return;
    }

    unless( exists($currencies{$params{target}}) ){
        $self->{error} = 'Target currency "' . $params{target} . '" is not available';
        return;
    }

    # store later use
    $self->{code} = $params{target};
    $self->{name} = $currencies{$params{target}}->{name};
    $self->{symbol} = $currencies{$params{target}}->{symbol};
    $self->{string} = $self->_format($params{format});

    # This "feature" is actually useful as a pass-thru filter.
    if( $params{source} eq $params{target} ) {
        return sprintf $self->{string}, $params{value}
    }

    # get the base site
    $web->get( UCC );
    unless($web->success()) {
        $self->{error} = 'Unable to retrieve webpage';
        return;
    }

    # complete and submit the form
    $web->submit_form(
            form_name => 'ucc',
            fields    => { 'From'   => $params{source}, 
                           'To'     => $params{target}, 
                           'Amount' => $params{value} } );
    unless($web->success()) {
        $self->{error} = 'Unable to retrieve webform';
        return;
    }

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
    my($self, %params) = @_;
    # set defaults
    $self->{$_} = $params{$_}   for(@defaults);

    return  if(keys %currencies);
    local($_);

    # Extract the mapping of currencies and their atrributes
    while(<Finance::Currency::Convert::XE::DATA>){
        chomp;
        my ($code,$text,$symbol) = split ",";
        $currencies{$code}->{name} = $text;
        $currencies{$code}->{symbol} = $symbol;
    }

    return;
}

# Formats the return string to the requirements of the caller
sub _format {
    my($self, $form) = @_;

    my %formats = (
        'symbol' => $self->{symbol} . '%.02f',
        'abbv'   => '%.02f ' . $self->{code},
        'text'   => '%.02f ' . $self->{name},
        'number' => '%.02f',
    );

    return $formats{$form}              if(defined $form && $formats{$form});
    return '%.02f';
}

# Extract the text from the html we get back from UCC and return
# it (keying on the fact that what we want is in the table after
# the faq link).
sub _extract_text {
    my($self, $html) = @_;
    my $tag;
    my $p = HTML::TokeParser->new(\$html);

    # look for the faq link
    while(1) {
        return  unless($tag = $p->get_tag('a'));
        last    if(defined $tag->[1]{href} && $tag->[1]{href} =~ /faq/);
    }

    # jump to the next table
    $tag = $p->get_tag('table');

    # from there look for the target value
    while($p->get_token) {
        my $text = $p->get_trimmed_text;

        if(my ($value) = $text =~ /([\d\.\,]+) $self->{code}/) {
            $value =~ s/,//g;
            return sprintf $self->{string}, $value;
        }
    }

    # didn't find anything
    return;
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

=head1 SEE ALSO

  WWW::Mechanize
  HTML::TokeParser

=head1 SUPPORT

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please submit a bug to the RT system (see link below). However,
it would help greatly if you are able to pinpoint problems or even supply a 
patch. 

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me by sending an email
to barbie@cpan.org .

RT: L<http://rt.cpan.org/Public/Dist/Display.html?Name=Finance-Currency-Convert-XE>

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 COPYRIGHT

  Copyright © 2002-2007 Barbie for Miss Barbell Productions.

  This library is free software; you can redistribute it and/or modify it under
  the same terms as Perl itself, using the Artistic License.

The full text of the licenses can be found in the Artistic file included with 
this distribution, or in perlartistic file as part of Perl installation, in 
the 5.8.1 release or later.

=cut

#--------------------------------------------------------------------------

__DATA__
EUR,Euro,&#8364;
USD,United States Dollars,$
CAD,Canadian Dollars,$
GBP,British Pounds,&#163;
JPY,Japanese Yen,&#165;
AED,United Arab Emirates Dirhams,#164;
AFN,Afghanistan Afghanis,#164;
ALL,Albania Leke,#164;
ARS,Argentinian Pesos,&#164;
AUD,Australian Dollars,$
BBD,Barbados Dollars,&#164;
BDT,Bangladesh Taka,#164;
BGL,Bulgarian Leva,&#164;
BGN,Bulgaria Leva,#164;
BHD,Bahrain Dinars,#164;
BMD,Bermuda Dollars,&#164;
BRL,Brazilian Real,&#164;
BSD,Bahamas Dollars,&#164;
CLP,Chilian Pesos,&#164;
CNY,Chinese Yuan Renminbi,&#164;
COP,Colombia Pesos,#164;
CRC,Costa Rica Colones,#164;
CYP,Cypriot Pounds,&#164;
CZK,Czech Republic Koruny,&#164;
DKK,Denmark Kroner,&#164;
DOP,Dominican Republic Pesos,#164;
DZD,Algerian Dinars,&#164;
EEK,Estonia Krooni,#164;
EGP,Egyptian Pounds,&#164;
FJD,Fijian Dollars,&#164;
HKD,Hong Kong Dollars,&#164;
HUF,Hungarian Forint,&#164;
IDR,Indonesian Rupiahs,&#164;
ILS,Israeli New Shekels,&#8362;
INR,Indian Rupees,&#8360;
IQD,Iraq Dinars,#164;
IRR,Iran Rials,#164;
ISK,Icelandic Kronur,&#164;
JMD,Jamaican Dollars,&#164;
JOD,Jordanian Dinars,&#164;
KES,Kenya Shillings,#164;
KRW,South Korean Won,&#8361;
KWD,Kuwait Dinars,#164;
LBP,Lebanonese Pounds,&#164;
LKR,Sri Lanka Rupees,#164;
MAD,Morocco Dirhams,#164;
MUR,Mauritius Rupees,#164;
MXN,Mexican Pesos,&#164;
MYR,Malaysian Ringgits,&#164;
NOK,Norweigan Kroner,&#164;
NZD,New Zealand Dollars,&#164;
OMR,Oman Rials,#164;
PEN,Peru Nuevos Soles,#164;
PHP,Philippino Pesos,&#164;
PKR,Pakistani Rupees,&#8360;
PLN,Polish Zlotych,&#164;
QAR,Qatar Riyals,#164;
ROL,Romanian Lei,&#164;
RON,Romania New Lei,#164;
RUR,Russian Rubles,&#164;
SAR,Saudi Arabian Riyals,&#164;
SDD,Sudanese Dinars,&#164;
SEK,Swedish Kronor,&#164;
SGD,Singapore Dollars,&#164;
SIT,Slovenia Tolars,#164;
SKK,Slovakian Koruny,&#164;
THB,Thai Baht,&#3647;
TND,Tunisia Dinars,#164;
TRL,Turkish Liras,&#164;
TRY,Turkey New Lira,#164;
TTD,Trinidad and Tobagoan Dollars,&#164;
TWD,Taiwan New Dollars,&#164;
VEB,Venezuelan Bolivares,&#164;
VND,Vietnam Dong,#164;
XAG,Silver Ounces,&#164;
XAU,Gold Ounces,&#164;
XCD,Eastern Caribbean Dollars,&#164;
XDR,Special Drawing Right (IMF),&#164;
XPD,Palladium Ounces,&#164;
XPT,Platinum Ounces,&#164;
ZAR,South African Rand,&#164;
ZMK,Zambian Kwacha,&#164;
