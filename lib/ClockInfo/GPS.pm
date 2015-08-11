package ClockInfo::GPS;

use strict;
use POSIX qw(strftime);

my($gps_buffer) = "";
my($last_gps) = ("[no status yet]");
my($last_gps_when) = 0;
my($last_gps_lock) = 0;

my(%snr_histogram);
my($seconds_with_lock,$last_lock_report) = (0,0);

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
      $data{lastlock} = $last_gps_lock;
      Clients::broadcast_status(\%data);
    }
  }
}

sub gsa {
  my($split,$sats,$satid_prefix) = @_;

  for(my $i = 3; $i <= 14; $i++) {
    if($split->[$i] > 0) {
      $sats->{$satid_prefix.$split->[$i]}{used_in_lock} = 1;
    }
  }
}

sub gsv {
  my($split,$sats,$satid_prefix) = @_;

  my(%special_sats) = (
    46 => "WAAS (Inmarsat)",
    48 => "WAAS (Galaxy 15)",
    51 => "WAAS (Anik F1R)",
  );

  for(my $i = 4; $i+3 < @$split; $i += 4) {
    my $satname = $satid_prefix . $split->[$i];
    $sats->{$satname}{id} = $satname;
    $sats->{$satname}{id} =~ s/^0//; # 0-padded
    $sats->{$satname}{elevation} = $split->[$i+1];
    $sats->{$satname}{elevation} =~ s/^0//; # 0-padded
    $sats->{$satname}{azimuth} = $split->[$i+2];
    $sats->{$satname}{azimuth} =~ s/^0//; # 0-padded
    my $snr = $split->[$i+3];
    $snr =~ s/^0//;
    $sats->{$satname}{snr} = $snr;
    $snr_histogram{$snr}++;
    if(defined($special_sats{$satname})) {
      $sats->{$satname}{special} = $special_sats{$satname};
    } else {
      $sats->{$satname}{special} = "";
    }
  }
}

sub parse_sat_lock {
  my($split,$parsed) = @_;

  my(@locks) = ("???", "No Lock", "2D Lock", "3D/Full Lock");

  if($split->[2] > 0 and $split->[2] < @locks) {
    $parsed->{"GPGSA"} = "Lock=".@locks[$split->[2]];
    if($split->[2] > 1) {
      $seconds_with_lock++;
      $last_gps_lock = time();
      open(STATUS, ">/dev/shm/.lastlock");
      print STATUS $last_gps_lock,"\n";
      close(STATUS);
      rename("/dev/shm/.lastlock","/dev/shm/lastlock");
    }
  } else {
    $parsed->{"GPGSA"} = "Lock=?".$split->[2];
  }
}

sub write_signal_info {
  if($last_lock_report == 0) {
    $last_lock_report = time();
  } elsif($last_lock_report < time() - 60*60) { # every hour
    $last_lock_report = time();
    open(LOCK_REPORT, ">>/var/log/ntp-app/gps-lock");
    print LOCK_REPORT POSIX::strftime("%F %R",gmtime($last_lock_report))," $seconds_with_lock\n";
    close(LOCK_REPORT);
    $seconds_with_lock = 0;
    open(SNR_HISTOGRAM, ">>/var/log/ntp-app/snr-history");
    my(@snr_strings) = map { "$_:".$snr_histogram{$_}; } sort { $a <=> $b } keys %snr_histogram;
    print SNR_HISTOGRAM POSIX::strftime("%F %R",gmtime($last_lock_report))," ",join(", ",@snr_strings),"\n";
    close(SNR_HISTOGRAM);
    %snr_histogram = ();
  }
}

sub parse {
  my($lines) = @_;

  my(%parsed);
  my(%sats);
  while($lines =~ s/^([^\n]*\n)//s) {
    my $line = $1;
    my(@split) = split(/[,*]/,$line);
    if($split[0] eq '$GPGSA') { # $GPGSA,A,1, , , , , , , , , , , , ,3.5,3.4,1.0*30 
      parse_sat_lock(\@split,\%parsed); 
      write_signal_info(); # only on GPGSA
      gsa(\@split, \%sats, "");
    } elsif($split[0] eq '$GLGSA') {
      gsa(\@split, \%sats, "GL");
    } elsif($split[0] eq '$GPGSV') {
      gsv(\@split, \%sats, "");
    } elsif($split[0] eq '$GLGSV') {
      gsv(\@split, \%sats, "GL");
    } 
  }

  my @sats = sort { $b->{snr} <=> $a->{snr} } values %sats;

  $parsed{"GPGSV"} = \@sats;

  return \%parsed;
}

sub status {
  return {text => $last_gps, "time" => $last_gps_when, "lastlock" => $last_gps_lock};
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
