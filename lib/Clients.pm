package Clients;

use strict;
use JSON;
use Time::HiRes qw(gettimeofday);

my(@clients);

sub broadcast_status {
  my($data) = @_;

  my $new_msg = JSON::encode_json($data);
  foreach my $client (@clients) {
    if(defined $client) {
      my $frame = $client->{handshake}->build_frame;
      my $framed = $frame->new($new_msg)->to_bytes();
      $client->{h}->push_write($framed);
    }
  }
}

sub dump_read {
  my($client,$h) = @_;

  my $frame = $client->{handshake}->build_frame;
  $frame->append($h->rbuf);
  $h->rbuf = "";
  while(my $message_text = $frame->next_bytes) {
    my(@now) = gettimeofday();
    if($frame->is_close()) {
      print "message closing\n";
      remove_client($client->{fh});
      $h->destroy();
    } else {
      my $msg = JSON::decode_json($message_text);
      if($msg->{"type"} eq "ping") {
        $msg->{"type"} = "reply";
        $msg->{"recv"} = $now[0]*1000 + int($now[1] / 1000);
        my $new_msg_text = JSON::encode_json($msg);
        my $reply = $frame->new($new_msg_text)->to_bytes();
        $client->{h}->push_write($reply);
      }
    }
  }
}

sub add_client {
  my($fh,$data) = @_;

  $clients[fileno($fh)] = $data;
}

sub remove_client {
  my($fh) = @_;

  delete $clients[fileno($fh)];
}

1;
