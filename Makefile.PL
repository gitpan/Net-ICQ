#
# Skeleton Perl Makefile
#
# Last updated by gossamer on Mon Sep 21 08:57:16 EST 1998
#

require 5;
use strict;

# Check for modules we need.
$| = 1;
my $missing_modules = 0;

print "Checking for IO::Socket ...";
eval {
    require IO::Socket;
};
if ($@) {
    print " missing!\n";
    $missing_modules++;
    print "$@\n";
    sleep(2);  # Don't hurry too much
} else {
    print " got it\n";
}

print <<EOT if $missing_modules;
The missing modules can be obtained from CPAN - you'll need them to
complete the installation.  

Visit <URL:http://www.perl.com/CPAN/> to find a CPAN site near you.

EOT

use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	   => 'Net::ICQ',
    'VERSION_FROM' => 'ICQ.pm',

    'dist'         => { 
                         COMPRESS => 'gzip -9f',
                         SUFFIX => 'gz',
                      },
);

sub MY::postamble {
   package MY;

   '

WEBDIR = /home/gossamer/websrc/docs/code
WEB_FILELIST = $(WEBDIR)/file-list

webdist: dist
	@$(MKPATH) $(WEBDIR)/$(DISTNAME)/
	cp $(DISTVNAME).tar.$(SUFFIX) $(WEBDIR)/$(DISTNAME)/
	cp README $(WEBDIR)/$(DISTNAME)/$(DISTVNAME).README

'
}

