package Net::ICQ;
#
# Perl interface to the ICQ server.
#
# This program was made without any help from Mirabilis or their
# consent.  No reverse engineering or decompilation of any Mirabilis
# code took place to make this program.
#
# Copyright (c) 1998 Bek Oberin.  All rights reserved. 
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# Last updated by gossamer on Wed Sep 23 20:05:58 EST 1998
#

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

use Data::Dumper;
use IO::Socket::INET;
use IO::Select;
use Sys::Hostname;
use Symbol;
use Fcntl;

use Carp;                     # Regular Carp
#use Carp qw(verbose);         # This one's for debugging - uses line numbers

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

$VERSION = "0.04";

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

# ICQ Ver 2.0
my $ICQ_Version_Major = 2;
my $ICQ_Version_Minor = 0;

my $Default_ICQ_Port = 4000;
my $Default_ICQ_Host = "icq1.mirabilis.com";

my $Config_File = $ENV{"HOME"} . "/.net-icqrc";

my $DEBUG = 1;

# Status types
my %user_status = (
   "ONLINE" => 0x00000000,
   "AWAY" => 0x01000000,
   "DND" => 0x11000000,
   "INVISIBLE" => 0x00010000,
   );
my %user_status_bynumber = reverse %user_status;

# Packet types
my %server_commands_bynumber = (
   0x0a00 => "ACK",	
   0x5a00 => "LOGIN_REPLY",
   0x6e00 => "USER_ONLINE",
   0x7800 => "USER_OFFLINE",
   0x8C00 => "USER_FOUND",
   0xDC00 => "RECEIVE_MESSAGE",
   0xA000 => "END_OF_SEARCH",
   0x1801 => "INFO_REPLY",
   0x2201 => "EXT_INFO_REPLY",
   0xA401 => "STATUS_UPDATE",
   0x1C02 => "REPLY_X1",
   0xE600 => "REPLY_X2",
   0xE001 => "UPDATE_REPLY",
   0xC800 => "UPDATE_EXT_REPLY",
   0x4600 => "NEW_USER_UIN",
   0xB400 => "NEW_USER_REPLY",
   0x8200 => "QUERY_REPLY",
   0xC201 => "SYSTEM_MESSAGE",
   0x6400 => "BAD_LOGIN",
   0x2800 => "SILENT_TOO_LONG",
   0xF000 => "GO_AWAY",
   );
my %server_commands = reverse %server_commands_bynumber;

my %client_commands_bynumber = (
   0x0A00 => "ACK",
   0x0E01 => "SEND_MESSAGE",
   0xE803 => "LOGIN",
   0x0604 => "CONTACT_LIST",
   0x1A04 => "SEARCH_UIN",
   0x2404 => "SEARCH_USER",
   0x2E04 => "KEEP_ALIVE",
   0x3804 => "SEND_TEXT_CODE",
   0x4C04 => "LOGIN_1",
   0x6004 => "INFO_REQ",
   0x6A04 => "EXT_INFO_REQ",
   0x9C04 => "CHANGE_PASSWORD",
   0xD804 => "STATUS_CHANGE",
   0x2805 => "LOGIN_2",
   0x0A05 => "UPDATE_INFO",
   0xB004 => "UPDATE_EXT_INFO",
   0x3C05 => "ADD_TO_LIST",
   0x5604 => "REQ_ADD_TO_LIST",
   0xBA04 => "QUERY_SERVERS",
   0xC404 => "QUERY_ADDONS",
   0xEC04 => "NEW_USER_1",
   0xFC03 => "NEW_USER_REG",
   0xA604 => "NEW_USER_INFO",
   0x4204 => "CMD_X1",
   0x5604 => "MSG_TO_NEW_USER",
   );
my %client_commands = reverse %client_commands_bynumber;


###################################################################
# Functions under here are member functions                       #
###################################################################

=head1 CONSTRUCTOR

=item new ( [ USERNAME, PASSWORD [, HOST [, PORT ] ] ])

Opens a connection to the ICQ server.  Note this does not automatially
log you into the server, you'll need to call login().

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
   my $arg_uin = shift;
   my $arg_password = shift;
   my $arg_host = shift;
   my $arg_port = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   # read config file first 'cause arguments override it
   my ($uin, $password, $host, $port, $status, @contacts) = 
      &read_config_file($Config_File);
   $self->{"uin"} = $arg_uin || $uin || $ENV{"ICQUSER"} || 
      croak "Unknown ICQ UIN - please specify";
   $self->{"password"} = $arg_password || $password ||
      croak "Unknown ICQ password - please specify";
   $self->{"host"} = $arg_host || $host || $ENV{"ICQHOST"} || $Default_ICQ_Host;
   $self->{"port"} = $arg_port || $port || $ENV{"ICQPORT"} || $Default_ICQ_Port;
   chomp($self->{"tty"} = `tty`);
   $self->{"incoming_port"} = &find_incoming_port();
   $self->{"status"} = $status || $user_status{"ONLINE"};

   $DEBUG && warn "CONSTRUCTOR:  Host: " . $self->{"host"} . ", Port: " . $self->{"port"} . "\n";
   $DEBUG && warn "CONSTRUCTOR:  UIN: " . $self->{"uin"} . ", Password: " . $self->{"password"} . "\n";

   # open the connection
   $self->{"socket"} = new IO::Socket::INET (
      PeerAddr => $self->{"host"},
      PeerPort => $self->{"port"},
      Proto => "udp",
      Type => SOCK_DGRAM,
   ) || croak "new: connect socket: $!";

   $self->{"select"} = new IO::Select [$self->{"socket"}];

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


=head1 OUTGOING - HIGH LEVEL FUNCTIONS

These are correspond with things you might want to do, rather
than the actual packets in the protocol.

=item login ( );

Logs you into the ICQ server, requests saved messages and other
standard login-type things.

=cut
sub login {
   my $self = shift;

   $self->send_message($self->construct_message("LOGIN"));
   $self->send_message($self->construct_message("LOGIN_1"));
   #$self->send_message($self->construct_message("CONTACT_LIST"));
   # TODO grok messages they send back!

   return 1;
}

=pod
=item search ( TEXT );

Search for a user.  You can search by UIN, email, nickname or
realname.

=cut

sub search {
   my $self = shift;
   my $searchtext = shift;

   if ($searchtext =~ /^\d+$/) {
      # all numbers, it's a UIN
      return $self->search_uin($searchtext);

   } elsif ($searchtext =~ /@/) {
      # it's an email address
      return $self->search_user('','','',$searchtext);

   } elsif ($searchtext =~ /^(\w+)\s+(\w+)/) {
      # alpha separated by space is prob'ly Firstname Lastname
      my $first_name = $1;
      my $last_name = $2;
      return $self->search_user('',$first_name, $last_name, '');

   } else {
      # assume it's a nickname we're searching
      return $self->search_user($searchtext,'','','');
   }

}

=head1 INCOMING - HIGH LEVEL FUNCTIONS

Copes with responses from the ICQ server.

=item incoming_packet_waiting ( );

Check if there's something from the server waiting to be processed.

=cut

sub incoming_packet_waiting {
   my $self = shift;

   return $self->{"select"}->can_read(0);

}

=pod
=item incoming_process_packet ( );

Do stuff.  

=cut

sub incoming_process_packet {
   my $self = shift;

   $DEBUG && warn "INCOMING:  Waiting for incoming packet ...\n";

   my $server;
   my $message;

   #$self->{"socket"}->accept() ||
   #   croak "ERROR:  Failed to accept connection:  $!";

   #if (!defined(recv($server, $message, 9999, 0))) {
   #   carp "recv: $!";
   #}

   my $sock = $self->{"socket"};
   unless ($sock->recv($message, 2048)) {
      croak "socket:  recv:  $1";
   }
   if ($DEBUG) {
      my($port, $ipaddr) = sockaddr_in($sock->peername);
      my $hishost = gethostbyaddr($ipaddr, AF_INET);
      warn "DEBUG:  INCOMING $hishost sent '" . Dumper($message) . "'\n";
   }

   my ($version_major, $version_minor, $command, $sequence_number) = 
      unpack("CCnnC*", $message);

   $DEBUG && warn "INCOMING:  Got command " . $server_commands_bynumber{$command} . "\n";

   if ($command eq $server_commands{"ACK"}) {
      # ack is special case, we ignore it for the moment
      $DEBUG && warn "INCOMING:  Got ACK for packet $sequence_number\n";
   } else {
      $self->send_ack($sequence_number);

      # Process packet
      if ($command eq $server_commands{"LOGIN_REPLY"}) { 
         return &receive_login_reply($message);
      } elsif ($command eq $server_commands{"USER_ONLINE"}) { 
         return &receive_user_online($message);
      } elsif ($command eq $server_commands{"USER_OFFLINE"}) { 
         return &receive_user_offline($message);
      } elsif ($command eq $server_commands{"USER_FOUND"}) { 
         return &receive_user_found($message);
      } elsif ($command eq $server_commands{"RECEIVE_MESSAGE"}) { 
         return &receive_message($message);
      } elsif ($command eq $server_commands{"END_OF_SEARCH"}) { 
         return &receive_end_of_search($message);
      } elsif ($command eq $server_commands{"INFO_REPLY"}) { 
         return &receive_info_reply($message);
      } elsif ($command eq $server_commands{"EXT_INFO_REPLY"}) { 
         return &receive_ext_info_reply($message);
      } elsif ($command eq $server_commands{"STATUS_UPDATE"}) { 
         return &receive_status_update($message);
      } else {
         # TODO: can't cope!!
         #$DEBUG && "
      }
   }
}

=head1 OUTGOING - LOW LEVEL FUNCTIONS

These correspond directly with the packets available in the ICQ
protocol.

=item send_ack ( SEQUENCE_NUMBER );

Send an ACK to the server, confirming we got packet SEQUENCE_NUMBER.

=cut

sub send_ack {
   my $self = shift;
   my $seq_num = shift;

   return $self->send_message($self->construct_message("ACK", "", $seq_num));
}


=pod
=item send_keepalive ( );

Just tells the server this connection's still alive.  Send it every 
2 minutes or so.

=cut

sub send_keepalive {
   my $self = shift;
   my $uin = shift;
   my $message = shift;

   return $self->send_message($self->construct_message("KEEP_ALIVE"));

}

=pod
=item send_contactlist ( CONTACT_UIN_ARRAY );

Tell the server who we're watching for, by UIN.

=cut

sub send_contactlist {
   my $self = shift;
   my @uins = shift;

   my $data = pack("n", scalar(@uins));
   foreach (@uins) {
      $data .= pack("N", $_);
   }

   return $self->send_message($self->construct_message("CONTACT_LIST", $data));

}

=pod
=item send_message ( UIN, MESSAGE );

Send a message through the server to user UIN.

=cut

sub send_msg {
   my $self = shift;
   my $uin = shift;
   my $message = shift;

   return $self->send_message($self->construct_message("SEND_MESSAGE",
      pack("NCCna*", $uin, 1, 0, length($message) + 1, $message . "\0")));

}


=pod
=item send_url ( UIN, URL );

Send a message through the server to user UIN.

=cut

sub send_url {
   my $self = shift;
   my $uin = shift;
   my $message = shift;

   return $self->send_message($self->construct_message("SEND_MESSAGE",
      pack("NCCna*", $uin, 4, 0, length($message) + 1, $message . "\0")));

}

=pod
=item search_uin ( UIN );

Search for a user by UIN.

=cut
sub search_uin {
   my $self = shift;
   my $uin = shift;

   return $self->send_message($self->construct_message("SEARCH_UIN",
      pack("nN", ++$self->{"search_sequence_number"}, $uin)));
}

=pod
=item search_user ( UIN );

Search for a user by UIN.

=cut
sub search_user {
   my $self = shift;
   my $nick_name = shift;
   my $first_name = shift;
   my $last_name = shift;
   my $email = shift;

   return $self->send_message($self->construct_message("SEARCH_USER",
      pack("nna*na*na*na*", ++$self->{"search_sequence_number"},
            length($nick_name) + 1,
            $nick_name . "\0",
            length($first_name) + 1,
            $first_name . "\0",
            length($last_name) + 1,
            $last_name . "\0",
            length($email) + 1,
            $email . "\0")));

}

=pod
=item request_userinfo ( UIN );

Request basic information about user UIN.

=cut

sub request_userinfo {
   my $self = shift;
   my $uin = shift;

   return $self->send_message($self->construct_message("INFO_REQ",
      pack("nN", ++$self->{"info_sequence_number"}, $uin)));

}

=pod
=item request_userinfo_extended ( UIN );

Request extended information about user UIN.

=cut

sub request_userinfo_extended {
   my $self = shift;
   my $uin = shift;

   return $self->send_message($self->construct_message("EXT_INFO_REQ",
      pack("nN", ++$self->{"info_sequence_number"}, $uin)));

}

=pod
=item change_status ( STATUS );

Update your ICQ status.

=cut

sub change_status {
   my $self = shift;
   my $status = shift;

   # check it's a real status
   return undef unless defined($user_status{$status});

   return $self->send_message($self->construct_message("CHANGE_STATUS",
      $user_status{$status}));

}

=pod
=item change_password ( PASSWD );

Update your ICQ password?  What does this do?

=cut

sub change_password {
   my $self = shift;
   my $passwd = shift;

   return $self->send_message($self->construct_message("CHANGE_PASSWORD",
      pack("nna*", ++$self->{"password_change_sequence_number"},
                   length($passwd) + 1,
                   $passwd . "\0")));

}

=head1 INCOMING - LOW LEVEL FUNCTIONS

Copes with responses from the ICQ server at packet level.

=item receive_login_reply ( );

=cut
sub receive_login_reply {
   my $self = shift;

}

sub receive_user_online {
   my $self = shift;

}

sub receive_user_offline {
   my $self = shift;

}

sub receive_user_found {
   my $self = shift;

}

sub receive_message {
   my $self = shift;

}

sub receive_end_of_search {
   my $self = shift;

}

sub receive_info_reply {
   my $self = shift;

}

sub receive_ext_info_reply {
   my $self = shift;

}

sub receive_status_update {
   my $self = shift;

}


=head1 MISC FUNCTIONS

These don't correspond with anything much.

=item version ( );

Returns version information for this module.

=cut

sub version {
   return "Net::ICQ version $VERSION";
}


###################################################################
# Functions under here are helper functions                       #
###################################################################

sub send_message {
   my $self = shift;
   my $message = shift;

   if (!defined(syswrite($self->{"socket"}, $message, length($message)))) {
      carp "syswrite: $!";
      return 0;
   }

   return 1;
   
}

sub construct_message {
   my $self = shift;
   my $command = shift;
   my $data = shift || '';  # Assume data is already packed or whatever
   my $seq_num = shift || ++$self->{"sequence_number"};

   $DEBUG && warn "construct_message:  command '$command', seq_num '$seq_num', data '$data'\n";
   my $message = 
         pack("CCnnN", $ICQ_Version_Major, 
                       $ICQ_Version_Minor,
                       $client_commands{$command},
                       $seq_num,
                       $self->{"uin"})
         . $data;

  return $message;
}

# Searches for a port that the server can use to talk to us
sub find_incoming_port {
   my $port = 9381;

   return $port;
}

sub read_config_file {
   my $config_file = shift;

   my ($uin, $password, $host, $port, $status, @contacts);

   # TODO

   return ($uin, $password, $host, $port, $status, @contacts);
}

=pod

=head1 AUTHOR

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
