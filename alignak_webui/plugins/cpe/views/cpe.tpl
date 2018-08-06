%setdefault('debug', True)

%from bottle import request
%search_string = request.query.get('search', '')

%rebase("layout", title="title", js=[], css=['cpe/static/css/cpe.css'], page="/cpe")

%from alignak_webui.utils.helper import Helper

%import json

<div id="cpe" class="card">
<h1>CPE</h1>
<pre>
{{host}}

perf_data_ {{raw.perf_data}}

</pre>
</div>
