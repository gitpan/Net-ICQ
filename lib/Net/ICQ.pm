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
# Last updated by gossamer on Sun Nov 22 11:30:40 EST 1998
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

$VERSION = "0.08";

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

my $DEBUG = 1;

# Status types
# TODO there are new status options that I don't have
my %user_status = (
   "ONLINE" => 0x00000000,
   "AWAY" => 0x01000000,
   "DND" => 0x11000000,
   "INVISIBLE" => 0x00010000,
   "BIRTHDAY" => 0x00080000,
   );
my %user_status_bynumber = reverse %user_status;

# Packet types
my %server_commands_bynumber = (
   0x00F0 => "GO_AWAY",
   0x0a00 => "ACK",	
   0x1801 => "INFO_REPLY",
   0x1C02 => "END_CONTACTLIST_STATUS",
   0x2201 => "EXT_INFO_REPLY",
   0x2800 => "SILENT_TOO_LONG",
   0x4600 => "NEW_USER_UIN",
   0x5a00 => "LOGIN_REPLY",
   0x6400 => "BAD_LOGIN",
   0x6e00 => "USER_ONLINE",
   0x7800 => "USER_OFFLINE",
   0x8200 => "QUERY_REPLY",
   0x8C00 => "USER_FOUND",
   0xA000 => "END_OF_SEARCH",
   0xA401 => "STATUS_UPDATE",
   0xB400 => "NEW_USER_REPLY",
   0xC201 => "SYSTEM_MESSAGE",
   0xC800 => "UPDATE_EXT_REPLY",
   0xDC00 => "RECEIVE_MESSAGE",
   0xE001 => "UPDATE_REPLY",
   0xE600 => "END_OFFLINE_MESSAGES",
   0xF000 => "NOT_LOGGED_IN",
   0xFA00 => "TRY_AGAIN",
   );
my %server_commands = reverse %server_commands_bynumber;

my %client_commands_bynumber = (
   0x0604 => "CONTACT_LIST",
   0x0A00 => "ACK",
   0x0A05 => "UPDATE_INFO",
   0x0E01 => "SEND_MESSAGE",
   0x1A04 => "SEARCH_UIN",
   0x2404 => "SEARCH_USER",
   0x2805 => "LOGIN_2",
   0x2E04 => "KEEP_ALIVE",
   0x3804 => "SEND_TEXT_CODE",
   0x3C05 => "ADD_TO_LIST",
   0x4204 => "ACK_OFFLINE_MESSAGES",
   0x4C04 => "REQUEST_OFFLINE_MESSAGES",
   0x5604 => "MSG_TO_NEW_USER",
   0x5604 => "REQ_ADD_TO_LIST",
   0x6004 => "INFO_REQ",
   0x6A04 => "EXT_INFO_REQ",
   0x9C04 => "CHANGE_PASSWORD",
   0xA604 => "NEW_USER_INFO",
   0xB004 => "UPDATE_EXT_INFO",
   0xBA04 => "QUERY_SERVERS",
   0xC404 => "QUERY_ADDONS",
   0xD804 => "STATUS_CHANGE",
   0xE803 => "LOGIN",
   0xEC04 => "NEW_USER_1",
   0xFC03 => "NEW_USER_REG",
   );
my %client_commands = reverse %client_commands_bynumber;


###################################################################
# Functions under here are member functions                       #
###################################################################

=head1 CONSTRUCTOR

=item new ( [ USERNAME, PASSWORD [, STATUS [, HOST [, PORT ] ] ] ])

Opens a connection to the ICQ server.  Note this does not automatially
log you into the server, you'll need to call login().

C<USERNAME> defaults, in order, to the environment variables
C<ICQUSER>, C<USER> then C<LOGNAME>.

C<PASSWORD> defaults to the contents of the file C<$HOME/.icqpw>.

C<STATUS> defaults to C<ONLINE>.

C<HOST> and C<PORT> refer to the remote host to which a ICQ connection
is required.  Leave them blank unless you want to connect to a server
other than Mirabilis.

The constructor returns the open socket, or C<undef> if an error has
been encountered.

=cut

sub new {
   my $prototype = shift;
   my $uin = shift;
   my $password = shift;
   my $status = shift;
   my $host = shift;
   my $port = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $self->{"uin"} = $uin || $ENV{"ICQUSER"} || 
      croak "Unknown ICQ UIN - please specify";
   $self->{"password"} = $password ||
      croak "Unknown ICQ password - please specify";
   # TODO this should find the password in the .icqpw file
   $self->{"host"} = $host || $ENV{"ICQHOST"} || $Default_ICQ_Host;
   $self->{"port"} = $port || $ENV{"ICQPORT"} || $Default_ICQ_Port;
   chomp($self->{"tty"} = `tty`);
   $self->{"status"} = $status || $user_status{"ONLINE"};
   
   $self->{"sequence_number"} = 0x0100;

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

=item login ( UINs );

Logs you into the ICQ server, set contact list to UINs (reference to a
hash keyed on number, values are names, requests saved messages) and
other standard login-type things.

=cut
sub login {
   my $self = shift;
   my $uins = shift;

   my ($data_pack);

   $self->{"contactlist"} = $uins;

   # construct the login packet data
   $data_pack = pack("Nna*N2nNcN3",
		     $self->{"socket"}->sockport,	       # PORT
		     (length($self->{"password"}) + 1)<<8, # PASSWD LEN (clobbers long passwds?)
		     $self->{"password"} . "\0",	          # PASSWORD
		     $self->{"socket"}->sockaddr,	       # USER_IP
		     defined($user_status_bynumber{$self->{"status"}}) 
		          ? $self->{"status"} : $user_status{"ONLINE"}, 
                                                 # STATUS 
		     ++$self->{"login_seq_num"},	          # LOGIN_SEQ_NUM
		     0x78000000, 			                   # X1
		     0x04,				                      # X2
		     0x02000000,			                   # X3
		     0x00000000,			                   # X4
		     0x08007800);			                   # X5
		     
   $self->send_message($self->construct_message("LOGIN", $data_pack));

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

   } elsif ($searchtext =~ /^(\w+)\s+(\w+)/) {
      # alpha separated by comma is prob'ly Lastname, Firstname
      my $last_name = $1;
      my $first_name = $2;
      return $self->search_user('',$first_name, $last_name, '');

   } else {
      # assume it's a nickname we're searching
      return $self->search_user($searchtext,'','','');
   }

}

=head1 INCOMING - HIGH LEVEL FUNCTIONS

Copes with responses from the ICQ server.

=item incoming_packet_waiting ( TIMEOUT );

Check if there's something from the server waiting to be processed.

To have it block waiting for input, call it with no argument.
Otherwise the argument is the number of seconds before it times out.

=cut

sub incoming_packet_waiting {
   my $self = shift;
   my $timeout = shift;

   return $self->{"select"}->can_read($timeout);
}

=pod
=item incoming_process_packet ( );

Do stuff.  

=cut

sub incoming_process_packet {
   my $self = shift;

   my $server;
   my $message;
   
   $DEBUG && warn "INCOMING:  Reading incoming packet ...\n";

   my $sock = $self->{"socket"};

   unless ($sock->recv($message, 99999)) {
      croak "socket:  recv2:  $1";
   }

   my ($version_major, $version_minor, $command, $sequence_number) = 
      unpack("CCnn", $message);  

   if ($DEBUG) {
      my $command_hex = &decimal_to_hex($command);
      if (my $sc = $server_commands_bynumber{$command}) {
         warn "INCOMING:  Got command " .  
               $server_commands_bynumber{$command} . " ($command/$command_hex) sequence $sequence_number\n";
      } else {
         warn "INCOMING:  Got unknown command number $command/$command_hex sequence $sequence_number\n";
      }
   }

   $message = substr($message, 6); # skip over six bytes /Jah
   if ($command eq $server_commands{"ACK"}) {
      # ack is special case, we ignore it for the moment
      # TODO we should keep track of packets sent (hash, indexed
      #      by sequence number) and tick them off when they're
      #      ACK'd.  Then resend things if they aren't.  Fiddly.
      $DEBUG && warn "INCOMING:  Got ACK for packet $sequence_number\n";
   } else {
      # common packet info
      $self->{'icq_packet_info'} = [$version_major, $version_minor, $command, $sequence_number];
      $DEBUG && warn "INCOMING: Sending ACK for packet $sequence_number\n";
      $self->send_ack($sequence_number);

      my $command_name = "receive_" . lc($server_commands_bynumber{$command});
      my $coderef = $self->can($command_name);
      if ($command_name && $coderef) {
         # we've found a method that can process this type of packet
         return $self->$command_name($message);
      } else {
         # TODO: can't cope - what do we do with this packet!!
         warn "UNKNOWN PACKET TYPE: '$command/" . &decimal_to_hex($command) . "', sequence number '$sequence_number'";
         $DEBUG && warn "INCOMING: Unknown packet dump: " . Dumper($message) . "\n";
         return 0;
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

   $DEBUG && warn ">>ACK\n";
   return $self->send_message($self->construct_message("ACK", "", $seq_num));
}


=pod
=item send_keepalive ( );

Just tells the server this connection's still alive.  Send it every 
2 minutes or so.

=cut

sub send_keepalive {
   my $self = shift;

   $DEBUG && warn ">>KEEPALIVE\n";
   return $self->send_message($self->construct_message("KEEP_ALIVE"));

}

=pod
=item send_contactlist ( CONTACT_UIN_ARRAY );

Tell the server who we're watching for, by UIN.

=cut

sub send_contactlist {
   my $self = shift;
   my @uins = @_;

   $DEBUG && warn ">>CONTACTLIST UINs:" . join(", ",@uins) . "\n";
   my $data = pack("n", scalar(@uins));
   foreach (@uins) {
      $data .= pack("N", dword_to_chars($_));
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

   $DEBUG && warn ">>SEND MSG\n";
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

   $DEBUG && warn ">>SEND URL\n";
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

   $DEBUG && warn ">>SEARCH UIN\n";
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

   $DEBUG && warn ">>SEARCH USER\n";
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

   $DEBUG && warn ">>REQUEST USERINFO\n";
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

   $DEBUG && warn ">>REQUEST USERINFO EXTENDED\n";
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

   $DEBUG && warn ">>CHANGE STATUS\n";
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

   $DEBUG && warn ">>PASSWORD\n";
   return $self->send_message($self->construct_message("CHANGE_PASSWORD",
      pack("nna*", ++$self->{"password_change_sequence_number"},
                   length($passwd) + 1,
                   $passwd . "\0")));

}

=head1 INCOMING - LOW LEVEL FUNCTIONS

Copes with responses from the ICQ server at packet level.

=item receive_login_reply ( );

Receive the login packet from the ICQ socket and respond to it appropriately.

=cut
sub receive_login_reply {
   my $self = shift;
   my $message = shift;


   my ($user_uin, $user_ip, $login_seq) = unpack("N2n", $message); 
      # `unknown' fields ignored

   $DEBUG && warn "<<RECEIVE_LOGIN_REPLY user_uin=" . 
                    dword_to_chars($user_uin) . 
                    "  user_ip=$user_ip  login_seq=$login_seq\n";

   # NOW we can do the rest of the login stuff
   $self->send_message($self->construct_message("LOGIN_2", pack("C", 0)));
   $self->send_message($self->construct_message("REQUEST_OFFLINE_MESSAGES"));
   $self->send_contactlist(keys %{ $self->{"contactlist"} });
   $self->change_status($self->{"status"});

   return 1;
}

sub receive_end_offline_messages {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<END_OFFLINE_MESSAGES\n";
   $self->send_message($self->construct_message("ACK_OFFLINE_MESSAGES"));
   return 1;
}

sub receive_silent_too_long {
   my $self = shift;

   $DEBUG && warn "<<SILENT TOO LONG\n";
   # TODO or is it too late at this point?
   $self->send_keepalive();
   return 1;
}

sub receive_user_online {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<USER ONLINE\n";
   # TODO
   return 0;
}

sub receive_user_offline {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<USER OFFLINE\n";
   # TODO

   return 0;
}

sub receive_user_found {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<USER FOUND\n";
   # TODO

   return 0;
}

sub receive_receive_message {
   my $self = shift;
   my $message = shift;

   my ($remote_uin, $year, $month, $day, $hour, $minute, $type, $length, $text)=
      unpack("NnCCCCnna*", $message);  

   $DEBUG && warn "<<RECEIVE MESSAGE: From $remote_uin, at $hour:$minute on $day $month $year\n";
   $DEBUG && warn "<<RECEIVE MESSAGE: Text: $text\n";
   # TODO

   return 0;
}

sub receive_end_of_search {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<END OF SEARCH\n";
   # TODO

   return 0;
}

sub receive_info_reply {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<INFO REPLY\n";
   # TODO

   return 0;
}

sub receive_ext_info_reply {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<EXT INFO REPLY\n";
   # TODO

   return 0;
}

sub receive_status_update {
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<STATUS UPDATE\n";
   # TODO
   # NOTE:  these need to be ANDed with 0x01FF to get rid of
   #        the high-bits in the new clients that we can't decode.

   return 0;
}


sub receive_end_contactlist_status {
# NB sent during login when last contactlist status update sent
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<END CONTACTLIST STATUS\n";
   # TODO

   return 0;
}

sub receive_not_logged_in {
# NB sent during login when last contactlist status update sent
   my $self = shift;
   my $message = shift;

   $DEBUG && warn "<<NOT LOGGED IN\n";
   # TODO

   return 0;
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
   my $seq_num = @_ ? shift : ++$self->{"sequence_number"}; # fixed /Jah - seqs can be 0

   $DEBUG && warn "construct_message:  command '$command', seq_num '$seq_num'\n";

   my $message = 
         pack("CCnnN", $ICQ_Version_Major, 
                       $ICQ_Version_Minor,
                       $client_commands{$command},
                       $seq_num,
  	               dword_to_chars($self->{"uin"}))
         . $data;

  return $message;
}

=pod

=item dword_to_chars ( DWORD )

Returns the passed DWORD converted to Intel endian character sequence.

=cut

sub dword_to_chars
{
    my $num = shift;
    my @buf;
    my $buf;

    $buf[0] = ($num>>24) & 0x000000FF;
    $buf[1] = ($num>>16) & 0x000000FF;
    $buf[2] = ($num>>8) & 0x000000FF;
    $buf[3] = ($num) & 0x000000FF;

    $buf  = $buf[3];
    $buf <<= 8;
    $buf |= $buf[2];
    $buf <<= 8;
    $buf |= $buf[1];
    $buf <<= 8;
    $buf |= $buf[0];

    return($buf);
}

=pod

=item decimal_to_hex ( NUMBER )

Returns the passed NUMBER in hex representation as a string.

=cut

sub decimal_to_hex {
   return uc(sprintf("%#04x", $_[0]));
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
