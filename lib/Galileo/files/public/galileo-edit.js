// requires humane and pagedown

// General functions

function sendViaWS (url, payload, success, failure) {
  var serialized = JSON.stringify(payload);
  ws = new WebSocket(url);
  ws.onmessage = function (evt) {
    var data = evt.data;

    if ( data.message ) {
      humane.log( data.message );
    }

    // handle success or failure callbacks
    if ( data.success && success ) {
      success( data );
    } else if ( !data.success && failure) {
      failure( data );
    }
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

  // be sure to default to sanitizing
  sanitize = (typeof sanitize === "undefined") ? true : sanitize;

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

