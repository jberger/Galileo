var modal_body = 
'<div class="modal hide fade" id="modal">' +
'  <div class="modal-header">' +
'    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>' +
'    <h3>Confirm Action</h3>' +
'  </div>' +
'  <div class="modal-body" id="modal-text"><p></p></div>' +
'  <div class="modal-footer">' +
'    <a href="#" class="btn" data-dismiss="modal">Close</a>' +
'    <a href="#" class="btn btn-primary" data-dismiss="modal" id="confirm">Confirm</a>' +
'  </div>' +
'</div>';

function show_modal(text, callback) {
  var modal = $('#modal');

  if ( modal.length == 0 ) {
    $('body').append(modal_body);
    modal = $('#modal');
  }

  $('#modal-text p').replaceWith( '<p>' + text + '</p>' );
  $('#confirm').click( callback );
  $('#modal').modal();
}

