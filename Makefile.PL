use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'			=> 'Finance::Currency::Convert::XE',
    'VERSION_FROM'	=> 'lib/Finance/Currency/Convert/XE.pm', # finds $VERSION
    'PREREQ_PM'		=> {
		WWW::Mechanize		=> 0,
		HTML::TokeParser	=> 0,
		Test::More => 0,	# for testing
	},
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'An online currency conversion module.',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
