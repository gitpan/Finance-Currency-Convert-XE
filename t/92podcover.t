#/usr/bin/perl -w
use strict;

use Test::More;
use File::Find;

# only for developing, ignore otherwise
eval "use Test::Pod::Coverage";

if ($@) {
    plan skip_all => "Test::Pod::Coverage required for evaluating POD";

} else {
	Test::Pod::Coverage->import;

    # find me some modules
    my @files;
    my $blib = 'blib/lib';
    find(	sub {
				return unless /\.p(l|m|od)$/;
				my ($dist) = ($File::Find::name =~ m!.*$blib.(.*)\.\w+$!);
				$dist =~ s!/!::!g;
				push @files, $dist
			}, $blib);

	Test::Pod::Coverage->import(plan tests => scalar @files);
    pod_coverage_ok($_,"Coverage for $_")	for @files;
}
