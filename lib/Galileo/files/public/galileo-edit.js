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
  
  // image upload stuff
  var $dialog = $('#insertImageDialog').dialog({ 
    autoOpen: false,
    closeOnEscape: true,
    modal: true,
    open: function(event, ui) { $(".ui-dialog-titlebar-close").hide(); }
  });
  var $loader = $('span.loading-icon', $dialog);
  var $url = $('input[type=text]', $dialog);
  var $file = $('input[type=file]', $dialog);

  editor.hooks.set('insertImageDialog', function(callback) {
    // dialog functions
    var dialogInsertClick = function() {                                      
      callback($url.val().length > 0 ? $url.val() : null);
      dialogClose();
    };

    var dialogCancelClick = function() {
      dialogClose();
      callback(null);
    };

    var dialogClose = function() {
      // clean up inputs
      $url.val('');
      $file.val('');
      $loader.hide();      
      $dialog.dialog('close');
    };

    // set up dialog button handlers
    $dialog.dialog( 'option', 'buttons', { 
      'Insert': dialogInsertClick, 
      'Cancel': dialogCancelClick 
    });

    var uploadStart = function() {
      $loader.show();
    };

    var uploadComplete = function(response) {
      $loader.hide();
      if (response.success) {
        callback(response.imagePath);
        dialogClose();
      } else {
        alert(response.message);
        $file.val('');
      }
    };

    // upload
    $file.unbind('change').ajaxfileupload({
      action: $file.attr('data-action'),
      onStart: uploadStart,
      onComplete: uploadComplete
    });

    // open the dialog
    $dialog.dialog('open');

    return true; // tell the editor that we'll take care of getting the image url
  });

  editor.run();

  this.converter = converter;
}

Editor.prototype.save = function (title) {
  this.data.title = title;
  sendViaWS(this.url, this.data);
};

