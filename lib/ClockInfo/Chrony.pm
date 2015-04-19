package ClockInfo::Chrony;

use strict;
use AnyEvent::Handle;
use Clients;

my($buffer) = "";
my($last_status) = "[no status yet]";
my($last_status_when) = 0;
sub chrony_text {
  my($fh) = @_;
  $buffer .= $fh->rbuf;
  $fh->rbuf = "";
  if($buffer =~ s/(.*Leap status\s+:\s+[\S ]+\n)//s) {
    my(%data) = (type => "chrony");
    $data{"text"} = $last_status = $1;
    $data{"time"} = $last_status_when = time();
    Clients::broadcast_status(\%data);
  }
}

sub status {
  return {text => $last_status, "time" => $last_status_when};
}

print STDERR "starting watch-chrony\n";
open(WATCH_CHRONY, "./watch-chrony |") or die("watch-chrony failed");
our $watch_chrony = AnyEvent::Handle->new(
  fh => \*WATCH_CHRONY,
  on_error => sub { 
    print STDERR "watch-chrony died?\n";
  },
  on_read => \&chrony_text,
  );

1;
