? my ($host,$chrony,$gps) = @_;
? my $GPS_RADAR_WIDTH = 355;
? my $GPS_RADAR_HEIGHT = 315;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML Strict//EN">
<html>
<head>
<title>NTP server status</title>
<script src="/static/jquery-1.3.2.min.js"></script>
<script src="/static/pretty.js"></script>
<script>
var ws;
var connected = 0;

function set_date_element(element_id, when) {
  var date = new Date(when);
  var pretty_time = $('<span class="pretty-time" title="' + date.toUTCString() + '">').text(date.toDateString());
  $(pretty_time).prettyDate();
  $(element_id).html(pretty_time);
}

var last_ping = 0;
function check_ping() {
  var ts = Date.now();
  if(ws && connected && (last_ping + 10000) < ts) {
    last_ping = ts;
    var msg = {
      "type": "ping",
      "send": Date.now()
    };
    ws.send(JSON.stringify(msg));
    set_date_element("#ping_ts", last_ping);
  }
}

function ping_reply(d, ts) {
  var sent = parseInt(d.send,10);
  var recv = parseInt(d.recv,10);
  var rtt = ts-sent;
  $("#ping_reply").text("rtt: "+rtt+"ms, clock difference: "+(ts-recv-(rtt/2))+"ms");
}

function show_radar(ctx) {
  ctx.clearRect(0, 0, <?= $GPS_RADAR_WIDTH ?>, <?= $GPS_RADAR_HEIGHT ?>);
  ctx.strokeStyle = "rgba(0,0,0, 0.3)";
  ctx.lineWidth = 1;
  for(var radius = 150; radius >= 10; radius = radius - 46) {
    ctx.beginPath();
    ctx.arc(151, 151, radius, 0, Math.PI*2, true);
    ctx.closePath();
    ctx.stroke();
  }

  ctx.beginPath();
  ctx.moveTo(0,151);
  ctx.lineTo(302,151);
  ctx.moveTo(151,0);
  ctx.lineTo(151,302);
  ctx.closePath();
  ctx.stroke();

  ctx.strokeStyle = "rgb(0,0,0)";
  ctx.font = "15px Georgia";
  ctx.fillText("N",152,16);
}

function show_radar_sats(ctx, sats) {
  ctx.strokeStyle = "rgb(0,0,0)";
  ctx.lineWidth = 2;
  for(var i = 0; i < sats.length; i++) {
    var elevation_rad = (90-sats[i].elevation) * Math.PI / 180; // from horizon
    var r = Math.sin(elevation_rad) * 150;

    var azimuth_rad = (540 - sats[i].azimuth) % 360 * Math.PI / 180; // clockwise from north
    var x = Math.sin(azimuth_rad) * r + 151;
    var y = Math.cos(azimuth_rad) * r + 151;

    ctx.beginPath();
    ctx.arc(x,y,5,0,Math.PI*2, true);
    ctx.closePath();
    if(sats[i].snr < 2) {
      ctx.fillStyle = "rgb(0,0,0)";
    } else if(sats[i].snr < 10) {
      ctx.fillStyle = "rgb(255,0,0)";
    } else if(sats[i].snr < 20) {
      ctx.fillStyle = "rgb(255,255,0)";
    } else if(sats[i].snr < 30) {
      ctx.fillStyle = "rgb(196,232,104)";
    } else {
      ctx.fillStyle = "rgb(0,214,7)";
    }
    ctx.fill();
    if(sats[i].used_in_lock) {
      ctx.stroke();
      ctx.fillStyle = "rgb(3,15,79)";
    } else {
      ctx.fillStyle = "rgb(0,0,0)";
    }

    ctx.fillText(sats[i].id,x+5,y+4);
  }
}

function gps_msg(d, ts) {
  $('#messages_'+d.type).text(d.text);
  set_date_element("#messages_time_"+d.type, ts);
  if(d.type == "gps") {
    $("#GPGSA").html(d.parsed.GPGSA);
    var i;
    var sats = "";
    for(i = 0; i < d.parsed.GPGSV.length; i++) {
      if(d.parsed.GPGSV[i]["special"].length > 0) {
        sats += 
	  "id = "+d.parsed.GPGSV[i]["id"] + 
	  ", snr = "+d.parsed.GPGSV[i]["snr"] +
          ", special = "+d.parsed.GPGSV[i]["special"] +
          "<br/>";
      }
    }
    $("#GPGSV").html(sats);
    var gps_radar = $('#gps_radar')[0].getContext("2d");
    show_radar(gps_radar);
    show_radar_sats(gps_radar,d.parsed.GPGSV);
  }
}

$(function(){
    if ("WebSocket" in window) {
        ws = new WebSocket("ws://<?= $host ?>/ws");
    }
    else {
        $("#ws_error").text("This browser doesn't support WebSocket.");
        $("#connected").text("not connected");
        return;
    }

    if (ws) {
        connected = 1;
        $("#connected").text("Connected");
        ws.onmessage = function (ev) {
            var ts = Date.now();
            try {
                var d = JSON.parse(ev.data);
                if(d.type == "reply") {
                  ping_reply(d, ts);
                } else {
                  gps_msg(d, ts);
                }
            } catch(e) { if (console) console.log(e) }
        }
        ws.onerror = function(ev) {
	  $("#ws_error").text("WebSocket error: ["+ev.code+"]"+ev.reason);
	  $("#connected").text("not connected");
	  connected = 0;
        }
        ws.onclose = function(ev) {
	  $("#ws_close").text("WebSocket closed: ["+ev.code+"]"+ev.reason);
	  $("#connected").text("not connected");
	  connected = 0;
        }
    }

    window.setInterval(function(){ $(".pretty-time").prettyDate(); check_ping(); }, 1000);

    set_date_element("#messages_time_chrony", <?= $chrony->{"time"} ?> * 1000);
    set_date_element("#messages_time_gps", <?= $gps->{"time"} ?> * 1000);
});
</script>
<link rel="stylesheet" href="/static/screen.css" />
<style>
.messages {
  margin-top: 1em;
  margin-right: 3em;
  float: left;
}
.avatar {
  width: 25px;
  vertical-align: top;
}
.avatar img {
  width: 25px; height: 25px;
  vertical-align: top;
  margin-right: 0.5em;
}
.chat-message {
  width: 70%;
}
.chat-message .name {
  font-weight: bold;
}
.meta {
  vertical-align: top;
  color: #888;
  font-size: 0.8em;
}
body {
  margin: 1em 2em
}
.locksat {
  color: #99cc00;
}
</style>
</head>
<body>

<div id="connected"></div>
<div id="ws_error"></div>
<div id="ws_close"></div>
<div id="ping">
Last timestamp:
<span id="ping_ts"></span>
</div>
<div id="reply">
Local clock:
<span id="ping_reply"></span>
</div>

<h1>NTP server status</h1>

<div id=chrony class=messages>
Last Chrony Update:
<span id="messages_time_chrony">
</span>
<pre id="messages_chrony">
<?= $chrony->{"text"} ?>
</pre>
</div>

<div id=gps class=messages>
Last GPS Update:
<span id="messages_time_gps">
</span>
<canvas style="display: block" id="gps_radar" width=<?= $GPS_RADAR_WIDTH ?> height=<?= $GPS_RADAR_HEIGHT ?>></canvas>
<pre id="messages_gps">
<?= $gps->{"text"} ?>
</pre>
<span id="GPGSA"></span><br/>
<span id="GPGSV"></span>
</div>

</body>
</html>
