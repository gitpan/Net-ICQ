package Net::ICQ;
#
# Perl interface to the ICQ server.
#
# Last updated by gossamer on Wed Jul 15 15:20:23 EST 1998
#

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

use IO::Socket;
use Sys::Hostname;
use Symbol;
use Fcntl;
use Carp;

require 'dumpvar.pl';

@ISA = qw(Exporter);
@EXPORT = qw( Default_ICQ_Port );
@EXPORT_OK = qw();

$VERSION = "0.01";

=head1 NAME

Net::ICQ - Communicate with a ICQ server

=head1 SYNOPSIS

   use Net::ICQ;
     
   $ICQ = Net::ICQ->new();
   $ICQ->signon();

=head1 DESCRIPTION

C<Net::ICQ> is a class implementing a simple ICQ client in
Perl.

=cut

###################################################################
# Some constants                                                  #
###################################################################

my $Default_ICQ_Port = 4000;
my $Default_ICQ_Host = "icq.mirabilis.com";

my $Config_File = $ENV{"HOME"} . "/.icq";

my $DEBUG = 1;

# Status types
my $STATUS_ONLINE = 0;
my $STATUS_AWAY = 1;
my $STATUS_DND = 2;
my $STATUS_INVISIBLE = 3;

# Packet types
my $ACK = 0x0A00;
my $SEND_MESSAGE = 0x0E01;
my $LOGIN = 0xE803;
my $CONTACT_LIST = 0x0604;
my $SEARCH_UIN = 0x1A04;
my $SEARCH_USER = 0x2404;
my $KEEP_ALIVE = 0x2E04;
my $SEND_TEXT_CODE = 0x3804;
my $LOGIN_1 = 0x4C04;
my $INFO_REQ = 0x6004;
my $EXT_INFO_REQ = 0x6A04;
my $CHANGE_PASSWORD = 0x9C04;
my $STATUS_CHANGE = 0xD804;
my $LOGIN_2 = 0x2805;
my $UPDATE_INFO = 0x0A05;
my $UPDATE_EXT_INFO = 0xB004;
my $ADD_TO_LIST = 0x3C05;
my $REQ_ADD_TO_LIST = 0x5604;
my $QUERY_SERVERS = 0xBA04;
my $QUERY_ADDONS = 0xC404;
my $NEW_USER_1 = 0xEC04;
my $NEW_USER_REG = 0xFC03;
my $NEW_USER_INFO = 0xA604;
my $CMD_X1 = 0x4204;
my $MSG_TO_NEW_USER = 0x5604;

###################################################################
# Functions under here are member functions                       #
###################################################################

=head1 CONSTRUCTOR

=item new ( [ USERNAME, PASSWORD [, HOST [, PORT ] ] ])

This is the constructor for a new ICQ object. 

C<USERNAME> defaults, in order, to the environment variables
C<ICQUSER>, C<USER> then C<LOGNAME>.

C<PASSWORD> defaults to the contents of the file C<$HOME/.icqpw>.

C<HOST> and C<PORT> refer to the remote host to which a ICQ connection
is required.  Leave them blank unless you want to connect to a server
other than Mirabilis.

The constructor returns the open socket, or C<undef> if an error has
been encountered.

=cut

sub new {
   my $prototype = shift;
   my $arg_username = shift;
   my $arg_password = shift;
   my $arg_host = shift;
   my $arg_port = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   warn "new\n" if $DEBUG > 1;

   # read config file first 'cause arguments override it
   my ($username, $password, $host, $port, $status, @contacts) = 
      &read_config_file;
   $self->{"username"} = $arg_username || $username || $ENV{"ICQUSER"} || $ENV{"USER"} || $ENV{"LOGNAME"} || "unknown";
   $self->{"password"} = $arg_password || $password;
   $self->{"host"} = $arg_host || $host || $Default_ICQ_Host;
   $self->{"port"} = $arg_port || $port || $Default_ICQ_Port;
   my $tty = `tty`;
   $self->{"tty"} = chomp($tty);
   $self->{"incoming_port"} = &find_incoming_port();
   $self->{"status"} = $status || $STATUS_ONLINE;

   # open the connection
   $self->{"socket"} = new IO::Socket::INET (
      PeerProto => "udp",
      PeerAddr => $self->{"host"},
      PeerPort => $self->{"port"},
   );
   croak "new: connect socket: $!" unless $self->{"socket"};

   # XXX login handshake here

   bless($self, $class);
   return $self;
}


#
# destructor
#
sub DESTROY {
   my $self = shift;

   shutdown($self->{"socket"}, 2);
   close($self->{"socket"});

   return 1;
}


=head1 send ( USERNAME, MESSAGE );

Send a message to a icq user.

=cut

sub send {
   my $self = shift;
   my $username = shift;
   my $text = shift;

   $self->build_message($SEND_MESSAGE, $username, $message);

   $self->send_message($message);
   return 1;
}

=head1 version ( );

Returns version information.

=cut

sub version {
   my $ver = "Net::ICQ version $VERSION";
   return $ver;
}


###################################################################
# Functions under here are helper functions                       #
###################################################################

sub send_message {
   my $self = shift;
   my $message = shift;

   if (!defined(syswrite($self->{"socket"}, $message, length($message)))) {
      warn "syswrite: $!";
      return 0;
   }

   return 1;
   
}

sub get_answer {
   my $self = shift;

   my $buffer = "";
   my $buff1;
   
   while (sysread($self->{"socket"}, $buff1, 999999) > 0) {
      $buffer .= $buff1;
   }

   return $buffer;

}

sub build_message {
   my $self = shift;
   my $command = shift;

   my $message = "#" . $Client_Type . $Client_Version . "," . 
          $self->{"extended_options"} . 
          $self->{"username"} . "," .
          $self->{"password"} . "," .
          $self->{"incoming_port"} . "," .
          $self->{"tty"};
  if ($command) {
     $message .= "," . $command;
  }

  return $message;
}

# Reads values from the file
sub read_config {
   my ($username, $password, $host, $port, $status, @contacts);

   open(CONFIG, $Config_File) || 
      warn "Can't open config file '$Config_File': $!"; 

   while (<CONFIG>) {
      next if /^\s*#/;
      next if /^\s*$/;

      # XXX read config file

   }
   close(CONFIG);

   return ($username, $password, $host, $port, $status, @contacts);
}

# Searches for a port that the server can use to talk to us
sub find_incoming_port {
   my $port = 0;

   return $port;
}

=pod

=head1 AUTHORS

Bek Oberin <gossamer@tertius.net.au>

=head1 COPYRIGHT

Copyright (c) 1998 Bek Oberin.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#
# End code.
#
1;
