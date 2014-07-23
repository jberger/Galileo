// requires humane and pagedown

// General functions

function sendViaWS (url, payload, success, failure) {
  var serialized = JSON.stringify(payload);
  var ws;
  if ( "WebSocket" in window ) {
    ws = new WebSocket(url);
  } else {
    humane.log( 'Error: Your browser does not support websockets.' );
    return;
  }
  ws.onmessage = function (evt) {
    var data = JSON.parse(evt.data);
    //console.log( data );

    if ( data.message ) {
      humane.log( data.message );
    }

    // handle success or failure callbacks
    if ( data.success && success ) {
      success( data );
    } else if ( !data.success && failure) {
      failure( data );
    }

    ws.close();
  };
  ws.onopen = function () {
    //console.log( "Sending ==> " + serialized );
    ws.send( serialized );
  };
}

// Editor class

function Editor (name, url, sanitize, pagedown_extra_options) {
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
  var extra = Markdown.Extra.init(converter, pagedown_extra_options);

  var editor = new Markdown.Editor(converter);
  converter.hooks.chain("preConversion", function (text) {
    data.md = text;
    return text; 
  });
  converter.hooks.chain("postConversion", function (text) {
    // codeblock of original pagedown looks little differ rather than
    // fenced code block of pagedown-extra so need little fix
    var preclass = extra.googleCodePrettify ? ' class="prettyprint"' : extra.highlightJs ? ' class="hljs"' : '';
    text = text.replace(/<pre><code>/g, "<pre" + preclass + "><code>");

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

