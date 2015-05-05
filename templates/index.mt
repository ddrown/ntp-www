? my ($host,$chrony,$gps) = @_
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

function gps_msg(d, ts) {
  $('#messages_'+d.type).text(d.text);
  set_date_element("#messages_time_"+d.type, ts);
  if(d.type == "gps") {
    $("#GPGSA").html(d.parsed.GPGSA);
    var i;
    var sats = "";
    for(i = 0; i < d.parsed.GPGSV.length; i++) {
      if(d.parsed.GPGSV[i]["used_in_lock"]) {
        sats += "<span class=locksat>";
      }
      sats += 
	"id = "+d.parsed.GPGSV[i]["id"] + 
	", elevation = "+d.parsed.GPGSV[i]["elevation"] + 
	", azimuth = "+d.parsed.GPGSV[i]["azimuth"] + 
	", snr = "+d.parsed.GPGSV[i]["snr"];
      if(d.parsed.GPGSV[i]["used_in_lock"]) {
        sats += "</span>";
      }
      sats += "<br/>";
    }
    $("#GPGSV").html(sats);
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
<pre id="messages_gps">
<?= $gps->{"text"} ?>
</pre>
<span id="GPGSA"></span><br/>
<span id="GPGSV"></span>
</div>

</body>
</html>
