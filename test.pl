#!/usr/bin/perl

# Net::ICQ test script
#
# Pass it a UIN and password on the command line.  (You can also set
# the environment variable ICQ_PASS instead of passing the password on
# the commandline) It will go online as that user, and act as an echo
# service.  Any normal message that is sent to it will be echoed back
# as a URL, with the message text in the description field, and the URL
# of the Net::ICQ website.  Hit ctrl-c to stop it.


use strict;
use Net::ICQ;


my ($icq);

# Remember that Net::ICQ tries to pull a UIN and password from the
# environment if either value here is empty (evaluates as false).
$icq = Net::ICQ->new($ARGV[0], $ARGV[1]);

# add a handler for incoming messages, to call the sub pimp_neticq
$icq->add_handler("SRV_SYS_DELIVERED_MESS", \&pimp_neticq);
# register a SIGINT handler, so ctrl-c will trigger a clean shutdown
$SIG{INT} = \&disconnect;

# Run the processing loop.  This well never exit.  The program exits
# when the sub disconnect (below) is called.
$icq->start;


sub pimp_neticq {
  my ($parsedevent) = @_;

  # set the receiver to the UIN of the person who sent the message
  $parsedevent->{params}{receiver_uin}  = $parsedevent->{params}{uin};

  # if this is a normal text message, modify it to be a
  # URL message with the original text as the description,
  # and the Net::ICQ website as the URL.
  if ($parsedevent->{params}{type} == 1){
    $parsedevent->{params}{type}        = 4;
    $parsedevent->{params}{url}         = 'http://neticq.sourceforge.net/';
    $parsedevent->{params}{description} = $parsedevent->{params}{text};
  }
  # send the message back
  $icq->send_event('CMD_SEND_MESSAGE', $parsedevent->{params});
}


sub disconnect {
  $icq->disconnect();
  exit();
}
