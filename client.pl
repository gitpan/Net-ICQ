#!/usr/bin/perl -w
#
# Example ICQ client using Net::ICQ
#
# Last updated by gossamer on Wed Sep 23 20:16:42 EST 1998
#

#
#  NOTE
#  Change the UIN-HERE and PASSWORD-HERE tokens on line 53 
#  to YOURS before you use this!
#

use strict;

use Getopt::Std;
use Net::ICQ;
use Term::ReadLine;

my $DEBUG = 1;

my %opt;

sub die_nicely {
   my $signal = shift;

   warn "ICQ got signal $signal, exiting.\n";
   exit 1;

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

# TODO: should read these params from disk
my $ICQ = new Net::ICQ "UIN_HERE", "PASSWORD_HERE";
if (!$ICQ) {
   die "Failed to connect to ICQ server: $!\n";
}

$ICQ->login() || die "Couldn't log on.";

# Set the interrupt handlers
$SIG{INT} = $SIG{TERM} = \&die_nicely;

$DEBUG && warn "DEBUG:  CLIENT:  Done connecting\n";

$ICQ->request_userinfo("15401522");
# At this point, we have a connection
if (fork()) {
   # Parent process - Get things and send them
   my $Input = new Term::ReadLine 'Net::ICQ Client';

   while ($_ = $Input->readline("> ")) {
      $DEBUG && warn "INPUT: got '$_'\n";

      if (/^p (\d+)=(.*)/i) {
         # msg to $1, text = $2;
         $ICQ->send_msg($1, $2);

      } elsif (/^search (.+)$/i) {
         # search for a user, $1 is UIN, email or name
         $ICQ->search($1);

      } elsif (/^(quit|exit)$/i) {
         # exit program
         last;

      } elsif (/^help$/i) {
         # display helptext
         print "\n";
         print "Commands:\n";
         print "p UIN=message - send a message to UIN\n";
         print "search text - search for a user\n";
         print "quit - exit program\n";
         print "\n";

      } else {
         print "Unknown command: $_\n";
         print "Use 'help' for help\n";
      }
   }

} else {
   # Child process - get replies and print them

   while ($ICQ->incoming_packet_waiting()) {
     $DEBUG && warn "DEBUG:  CLIENT:  Going to get packet ...\n";
     $ICQ->incoming_process_packet();
   }
}

print "Client exiting normally.\n";
exit;

#
# End.
#
