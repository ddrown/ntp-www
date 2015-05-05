package ClockInfo::GPS;

use strict;

my($gps_buffer) = "";
my($last_gps) = ("[no status yet]");
my($last_gps_when) = 0;
sub gpspipe_text {
  my($fh) = @_;

  $gps_buffer .= $fh->rbuf;
  $fh->rbuf = "";
  if($gps_buffer =~ s/(.*\$GPZDA,[^\n]+\n)//s) {
    my $lines = $1;
    if($lines =~ /\$GPGSV.*/) {
      my(%data) = (type => "gps");
      $data{"text"} = $last_gps = ""; # status text
      $data{"time"} = $last_gps_when = time();
      $data{parsed} = parse($lines);
      Clients::broadcast_status(\%data);
    }
  }
}

sub parse {
  my($lines) = @_;

  my(@locks) = ("???", "No Lock", "2D Lock", "3D/Full Lock");

  my(%parsed);
  my(@sats);
  while($lines =~ s/^([^\n]*\n)//s) {
    my $line = $1;
    my(@split) = split(/[,*]/,$line);
    if($split[0] eq '$GPGSA') { # $GPGSA,A,1, , , , , , , , , , , , ,3.5,3.4,1.0*30 
      if($split[2] > 0 and $split[2] < @locks) {
	$parsed{"GPGSA"} = "Lock=".@locks[$split[2]];
      } else {
	$parsed{"GPGSA"} = "Lock=?".$split[2];
      }
      $parsed{"GPGSA"} .= " sats=".join(",",@split[3..14]);
      $parsed{"GPGSA"} =~ s/,,+//;
    } elsif($split[0] eq '$GLGSA') {
      $parsed{"GPGSA"} .= " GLsats=".join(",",@split[3..14]);
      $parsed{"GPGSA"} =~ s/,,+//;
    } elsif($split[0] eq '$GPGSV') {
      for(my $i = 4; $i+3 < @split; $i += 4) {
        push(@sats, {id => $split[$i], elevation => $split[$i+1], azimuth => $split[$i+2], snr => $split[$i+3]});
      }
    } elsif($split[0] eq '$GLGSV') {
      for(my $i = 4; $i+3 < @split; $i += 4) {
        push(@sats, {id => "GL".$split[$i], elevation => $split[$i+1], azimuth => $split[$i+2], snr => $split[$i+3]});
      }
    } 
  }

  @sats = sort { $b->{snr} <=> $a->{snr} } @sats;

  $parsed{"GPGSV"} = \@sats;

  return \%parsed;
}

sub status {
  return {text => $last_gps, "time" => $last_gps_when};
}

sub gpspipe_junk { # JSON junk before the actual data
  my($hdl,$line) = @_;
  return 1;
}

print STDERR "starting gpspipe -r\n";
open(GPSPIPE,"gpspipe -r |") or die("gpspipe failed");
our $gpspipe = AnyEvent::Handle->new(
  fh => \*GPSPIPE,
  on_error => sub { 
    print STDERR "gpspipe died?\n";
  },
  on_read => \&gpspipe_text,
  );
$gpspipe->push_read(line => \&gpspipe_junk);
$gpspipe->push_read(line => \&gpspipe_junk);
$gpspipe->push_read(line => \&gpspipe_junk);

1;
