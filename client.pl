#!/usr/bin/perl -w
#
# Example ICQ client using Net::ICQ
#
# Last updated by gossamer on Thu Sep 24 22:56:27 EST 1998
#

#
#  NOTE
#  Change the UIN-HERE and PASSWORD-HERE tokens on line 53 
#  to YOURS before you use this!
#

use strict;

use Getopt::Std;
use Net::ICQ;

my $DEBUG = 1;

my %opt;

sub die_nicely {
   my $signal = shift;

   print STDERR "ICQ got signal $signal, exiting.\n";
   exit;

}

sub user_help {

   print "Use the source, Luke.\n";
   return 1;
}

#
# Main
#

getopts('vhw:l:s:', \%opt);

if ($opt{"h"}) {
   # help requested
   &user_help();
   exit;
} elsif ($opt{"v"}) {
   # version number
   print "Basic Net::ICQ client built with " . Net::ICQ::version() . "\n";
   exit;
}

# TODO we should use a config file to get parameters from disk

my $ICQ = new Net::ICQ "UIN-HERE", "PASSWORD-HERE";
if (!$ICQ) {
   die "Failed to connect to ICQ server: $!\n";
}

$ICQ->login() || die "Couldn't log on.";

# Set the interrupt handlers
$SIG{INT} = $SIG{TERM} = \&die_nicely;

$DEBUG && print STDERR "DEBUG:  CLIENT:  Done connecting\n";

## At this point, we have a connection
#if (fork()) {
#   # Parent process
#
#} else {
#   # Child process - get replies and print them
#
#   while ($ICQ->incoming_packet_waiting()) {
    while (1) {
      $DEBUG && print STDERR "DEBUG:  CLIENT:  Going to get packet ...\n";
      $ICQ->incoming_process_packet();
   }
#}
#
# End.
#
