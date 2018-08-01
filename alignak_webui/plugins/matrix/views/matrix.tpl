%setdefault('debug', True)

%from bottle import request
%search_string = request.query.get('search', '')

%rebase("layout", title="title", js=[], css=['cpe/static/css/matrix.css'], page="/matrix")

%from alignak_webui.utils.helper import Helper

<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/v/bs/dt-1.10.16/datatables.min.css"/>

<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.16/js/jquery.dataTables.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/buttons/1.5.1/js/dataTables.buttons.min.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/buttons/1.5.1/js/buttons.flash.min.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.3/jszip.min.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.32/pdfmake.min.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.32/vfs_fonts.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/buttons/1.5.1/js/buttons.html5.min.js"></script>
<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/buttons/1.5.1/js/buttons.print.min.js"></script>


<style>
.hoststate0 {background-color: #5bb75b; color: #fff;}
.hoststate1 {background-color: #da4f49; color: #fff;}
.hoststate2 {background-color: #faa732; color: #fff;}
.hoststate3 {background-color: #49afcd; color: #fff;}
.hoststate0 a { color: #fff; }
.hoststate1 a { color: #fff; }
.hoststate2 a { color: #fff; }
.hoststate3 a { color: #fff; }
td.highlight { background-color: whitesmoke !important; }
</style>

<div id="matrix">

<table id="myTable" class="table table-bordered table-condensed" style="text-align: right;">

</table>


<script>
var _cache = {}

function humanBytes(fileSizeInBytes) {

    var i = -1;
    var byteUnits = ['kb', 'Mb', 'Gb', 'Tb', 'Pb', 'Eb', 'Zb', 'Yb'];
    do {
        fileSizeInBytes = fileSizeInBytes / 1024;
        i++;
    } while (fileSizeInBytes > 1024);

    return Math.max(fileSizeInBytes, 0.1).toFixed(1) + byteUnits[i];
};

function humanHertz(frequency) {

    var i = 0;
    var byteUnits = ['Hz', 'kHz', 'MHz', 'GHz'];
    do {
        frequency = frequency / 1000;
        i++;
    } while (frequency > 1000);

    return Math.max(frequency, 0).toFixed(0) + byteUnits[i];
};

function toHHMMSS(num) {
    var sec_num = parseInt(num, 10); // don't forget the second param
    var days    = Math.floor(sec_num / (3600 * 24));
    var hours   = Math.floor((sec_num / 3600) % 24);
    var minutes = Math.floor((sec_num / 60) % 60);
    var seconds = sec_num % 60;

    if (days    >  1) {days    = days + "d " } else { days = ""}
    if (hours   < 10) {hours   = "0"+hours;}
    if (minutes < 10) {minutes = "0"+minutes;}
    if (seconds < 10) {seconds = "0"+seconds;}
    return days+hours+':'+minutes+':'+seconds;
};

function getServiceFromMetric(metric) {
  for (var i in _cache.groups) {
    if( $.inArray(metric, _cache.groups[i]) >= 0 ) {
       return i;
    }
  }
  return '';
}

function g(host,metric) {
  var ser = getServiceFromMetric(metric)
  if (ser == 'host') ser = '__HOST__';
  var val = "" + host + "." + ser + "." + metric;
  var src = "http://"+window.location.hostname+":4288/render/?width=640&height=200&lineMode=connected&target="+val+"&fontSize=12&from=-7days"
  $('#g').attr('src',src);
}

function processMetric(m) {
    str = "";

    if (false) { null }
    else if (m.name == 'upbw' || m.name == 'dnbw') str = str + humanBytes(m.value);
    else if (m.name == 'filesize') str = str + humanBytes(m.value);
    else if (m.name.includes('freq')) str = str + humanHertz(m.value);
    else if (m.uom == 's') str = str + toHHMMSS(m.value);
    else if (m.name.includes('uptime')) str = str + toHHMMSS(m.value);
    else str = str + m.value;

    //if ( m.uom ) str = str +  " " + m.uom;


    if (false) { null }
    else if ( m.critical && m.critical > m.warning && m.value > m.critical ) str = '<span class="font-critical">' + str + '<span>';
    else if ( m.critical && m.critical < m.warning && m.value < m.critical ) str = '<span class="font-critical">' + str + '<span>';
    else if ( m.warning && m.critical > m.warning && m.value > m.warning )   str = '<span class="font-warning">' + str + '<span>';
    else if ( m.warning && m.critical < m.warning && m.value < m.warning )   str = '<span class="font-warning">' + str + '<span>';
    else if ( m.warning == null && m.critical == null) str = '<span>' + str + '<span>'
    else  str = '<span class="font-ok">' + str + '<span>';

    return str

}

$(document).ready( function (){

  var table;
  var _headers = [];


  $("#g").hide();
  $("#g").on('click',function(){
    $(this).hide();
  });

  $('body').keypress(function(e) {
    if ( e.key == 'g' ) {
      $('#g').toggle();
    }
  });


  $.getJSON( "/matrix.json?search=" + $('#search').val(), function( data ) {
        _cache = data;

        row = '<thead><tr><th></th>';
        _headers.push('host');

        if ('host' in data.groups) {
          data.groups['host'].push('reg');
        }

        $.each(data.groups, function(k,v){
           if (v.length > 0) {
             row = row + '<th colspan="'+v.length+'">' + k + "</th>";
           }
        });
        row = row + '</tr><tr>';
        row = row + '<th>Host</th>';


        $.each(data.groups, function(k,v){
           $.each(v, function(kk,vv){
             _headers.push(vv)
             if(vv == "reg" || vv == "uptime" || vv == "ruptime" || vv == "luptime" ) {
               row = row + '<th style="width: 40px; override: hidden"><span title="'+vv+'" alt="'+vv+'">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' + vv + '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span></th>';
             } else {
               row = row + '<th style="width: 40px; override: hidden"><span title="'+vv+'" alt="'+vv+'">' + vv.substr(0,2) + "</span></th>";
             }
           });
        });
        row = row + "</tr></thead>";
        $('#myTable').append(row);

        row = "<tbody>";
        $('#myTable').append(row);
        var host = null;
        $.each(data.data, function(k,v){
            row = "<tr>";
            $.each(_headers, function(kk,i){
              cell = v[i]
              if ( i == "host" ) {
                row = row + '<td class="hoststate' + v.state_id +'"">'
                + '<a href="/cpe/' + cell +'">'
                + '<span class="host_name">' + cell + '</span>'
                + '<span class="display_name hidden">' + v.display_name + '</span>'
                + '</a></td>';
                host = cell;
              } else if ( i == "reg" ) {
                row = row + '<td>'
                + '<a href="?search=reg:' + v.reg +'">'
                + '<span>' + v.reg + '</span>'
                + '</a></td>';
              } else if ( cell instanceof Object ) {
                row = row + '<td data-order="' + Math.round(cell.value) + '" onmouseover="g(\''+host+'\',\''+cell.name+'\')">' + processMetric(cell) +'</td>';
              } else if ( typeof cell === "undefined"){
                row = row + '<td data-order="0">-</td>';
              } else {
                row = row + '<td data-order="0">' + cell + '</td>';
              }
            });

           row = row + "</tr>";
           $('#myTable').append(row);
        });

        row = "</tbody>";
        $('#myTable').append(row);

        var table = $('#myTable').DataTable( {
          autoFill: true,
          lengthMenu: [[25, 50, 100, -1], [25, 50, 100, "All"]],
          searching: false,
          pageLength: 25,
          dom: 'Blfrtip',
          buttons: [
              'copy', 'csv', 'excel', 'pdf', 'print'
          ]
        });

        table.button().add( 0, {
            action: function ( e, dt, button, config ) {
              $('.display_name').toggleClass('hidden');
              $('.host_name').toggleClass('hidden');
            },
            text: 'Toggle Display Name'
        } );

        $('#myTable tbody').on( 'click', 'tr', function () {
               if ( $(this).hasClass('selected') ) {
                   $(this).removeClass('selected');
               } else {
                   table.$('tr.selected').removeClass('selected');
                   $(this).addClass('selected');
               }
           } );




  } );


 // buttons
 $('#toggleName').on('click', function(){

 });



} );

</script>

<img id="g" src="about:blank" style="position: fixed; bottom: 0px; right: 0px;">
