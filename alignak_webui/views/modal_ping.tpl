%from bottle import request
%from alignak_webui import __manifest__

<div class="modal-header">
   <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
   <h4 class="modal-title">{{_('Ping')}}</h4>
</div>
<div class="modal-body">
   <!-- About Form -->
   <form class="form">
      <div class="form-group">
        <label class="control-label" for="input_hostname">{{_('Hostname')}}</label>
        <input id="input_hostname" type="text" class="form-control" placeholder="8.8.8.8" class="input-medium" value="">
        <button class="btn">Ping</button>
      </div>
   </form>
</div>
