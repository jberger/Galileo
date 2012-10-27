// requires humane and pagedown

// General functions

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

// Editor class

function Editor (name, url, sanitize) {
  this.url = url;   
  var data = {
    name  : name,
    md    : "",
    html  : "",
    title : ""
  };
  this.data = data;

  // setup the pagedown editor
  sanitize = (typeof sanitize === "undefined") ? 1 : sanitize;
  var converter = sanitize
    ? Markdown.getSanitizingConverter()
    : new Markdown.Converter();

  var editor = new Markdown.Editor(converter);
  converter.hooks.chain("preConversion", function (text) {
    data.md = text;
    return text; 
  });
  converter.hooks.chain("postConversion", function (text) {
    data.html = text;
    return text; 
  });
  editor.run();

  this.converter = converter;
}

Editor.prototype.save = function (title) {
  this.data.title = title;
  sendViaWS(this.url, this.data);
};

