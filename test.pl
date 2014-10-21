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

# enable debugging (this is undocumented!!!)
$icq->{_debug} = 1;

# Run the processing loop.  This well never exit.  The program exits
# when the sub disconnect (below) is called.
$icq->start;


sub pimp_neticq {
  # incoming event
  my ($event) = @_;
  # params from incoming event, and for outgoing event
  my ($in_params, $out_params);

  $in_params = $event->{params};

  # is this is a normal text message?
  if ($in_params->{type} == 1){

    # create a parameter hash for a URL message
    $out_params = {};
    $out_params->{type} = 4;

    # set the receiver to the UIN of the person who sent the message
    $out_params->{receiver_uin} = $in_params->{uin};

    # set the description to the message text
    $out_params->{description}  = $in_params->{text};

    # set the URL to the Net::ICQ website
    $out_params->{url}          = 'http://neticq.sourceforge.net/';

    # send the message back
    $icq->send_event('CMD_SEND_MESSAGE', $out_params);
  }
}


sub disconnect {
  $icq->disconnect();
  exit();
}
