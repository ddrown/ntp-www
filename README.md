# ntp-www

perl module prereqs:
  1. AnyEvent
  2. JSON
  3. twiggy
  4. Protocol::WebSocket

Many of these prereqs are in Fedora's and Debian's package system

to run: twiggy --port 9090 ntp-app

This will listen on port 9090 and respond as a HTTP server
