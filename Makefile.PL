#
# Skeleton Perl Makefile
#
# Last updated by jmuhlich on Sun Oct 8 09:0950 EST 2000
#

use strict;

# Check for modules we need.
$| = 1;
my $missing_modules = 0;


print "Checking for Perl 5.6.0 ...";
eval {
    require 5.6.0;
};
if ($@) {
    print " missing!\n";
    $missing_modules++;
    print "$@\n";
    sleep(2);  # Don't hurry too much
} else {
    print " got it\n";
}

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

print "Checking for IO::Select ...";
eval {
    require IO::Select;
};
if ($@) {
    print " missing!\n";
    $missing_modules++;
    print "$@\n";
    sleep(2);  # Don't hurry too much
} else {
    print " got it\n";
}

print "Checking for Time::Local ...";
eval {
    require IO::Select;
};
if ($@) {
    print " missing!\n";
    $missing_modules++;
    print "$@\n";
    sleep(2);  # Don't hurry too much
} else {
    print " got it\n";
}

print "Checking for Math::BigInt ...";
eval {
    require Math::BigInt;
};
if ($@) {
    print " missing!\n";
    $missing_modules++;
    print "$@\n";
    sleep(2);  # Don't hurry too much
} else {
    print " got it\n";
}

print "Checking for Carp ...";
eval {
    require Carp;
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
    'VERSION_FROM' => 'lib/Net/ICQ.pm',

    'dist'         => {
                         COMPRESS => 'gzip -9f',
                         SUFFIX => 'gz',
                      },
);

#sub MY::postamble {
#   package MY;
#
#   '
#
#WEBDIR = /home/gossamer/public_html/netizen/code
#WEB_FILELIST = $(WEBDIR)/file-list
#
#webdist: dist
#	@$(MKPATH) $(WEBDIR)/$(DISTNAME)/
#	cp $(DISTVNAME).tar.$(SUFFIX) $(WEBDIR)/$(DISTNAME)/
#	cp README $(WEBDIR)/$(DISTNAME)/$(DISTVNAME).README
#
#'
#}



