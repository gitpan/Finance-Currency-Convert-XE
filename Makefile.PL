use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Finance::Currency::Convert::XE',
    'VERSION_FROM'	=> 'lib/Finance/Currency/Convert/XE.pm', # finds $VERSION
    'PREREQ_PM'		=> {

		WWW::Mechanize		=> 0,
		HTML::TokeParser	=> 0,

	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/Finance/Currency/Convert/XE.pm', # retrieve abstract from module
       AUTHOR     => 'Barbie <barbie@cpan.org>') : ()),
    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    'INC'		=> '', # e.g., '-I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);
