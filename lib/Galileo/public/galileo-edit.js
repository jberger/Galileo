function sendViaWS (url, payload) {
  var serialized = JSON.stringify(payload);
  ws = new WebSocket(url);
  ws.onmessage = function (evt) {
    var message = evt.data;
    //console.log( message );
    humane.log( message );
  };
  ws.onopen = function () {
    //console.log( "Sending ==> " + serialized );
    ws.send( serialized );
  };
}
