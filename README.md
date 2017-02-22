# ntp-www

perl module prereqs:
  1. AnyEvent
  2. JSON
  3. twiggy
  4. Protocol::WebSocket
  5. Text::MicroTemplate::File

Many of these prereqs are in Fedora's and Debian's package system

To install:

  1. create the user/group ntpwww (or adjust the user in ntp-app)
  2. Put ntp-www.service in /etc/systemd/system/ (adjust ExecStart= + WorkingDirectory= as needed)
  3. systemctl enable ntp-www ; systemctl start ntp-www

This will listen on port 9090 and respond as a HTTP server
