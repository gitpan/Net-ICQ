#!/usr/bin/perl -w
#
# Example Goofey client using Net::Goofey
#
# Last updated by gossamer on Wed Jul 15 15:19:34 EST 1998
#

use strict;
use Net::Goofey;

sub die_nicely {
   my $signal = shift;

   print STDERR "Goofey got signal $signal, exiting.\n";
   exit;

}

my $Goofey = Net::Goofey->new();

if (!$Goofey) {
   die "Failed to connect to Goofey server.\n";
}

$Goofey->signon();
print $Goofey->who("skud");

print "Successfully signed on, backgrounding.\n";

exit;

# At this point, we have a connection
if (fork()) {
   # Parent process - die politely
   exit();
}

# This is the child process, backgrounded.  It stays alive to do stuff.

# Set the interrupt handlers
$SIG{INT} = $SIG{TERM} = \&die_nicely;

while (1) {
   # Try to accept a connection
   # If we have one, answer it properly
   # else continue

}


