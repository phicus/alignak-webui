%import json

%setdefault('debug', False)
%setdefault('debugLogs', False)

%# embedded is True if the table is got from an external application
%setdefault('embedded', False)
%from bottle import request
%setdefault('links', request.params.get('links', ''))
%setdefault('identifier', 'widget')
%setdefault('credentials', None)

%# Default filtering is to use the table saved state
%setdefault('where', {'saved_filters': True})

%setdefault('commands', False)
%setdefault('object_type', 'unknown')

%from bottle import request
%search_string = request.query.get('search', '')

%if not embedded:
%# Datatables js and css are included in the page layout
%rebase("layout", title=title, page="/{{object_type}}s_table")
%end

%if embedded and identifier:
%scheme = request.urlparts.scheme
%location = request.urlparts.netloc
%path = request.urlparts.path
%#Do not change path ...
%#path = path.replace('/external/table/'+identifier, '')
%server_url = scheme + '://' + location + path
%else:
%server_url = ''
%end
<!-- Table display -->
<div id="{{object_type}}s_table" class="alignak_webui_table {{'embedded' if embedded else ''}}">
   <table id="tbl_{{object_type}}" class="{{dt.css}}">
      <thead>
         <tr>
            %for column in dt.table_columns:
            <th data-name="{{ column.get('data') }}" data-type="{{ column.get('type') }}">{{ column.get('title','###') }}</th>
            %end
         </tr>
         %if dt.searchable:
         %if debug:
         <tr id="debug">
            %idx=0
            %for field in dt.table_columns:
               %name = field.get('data', '')
               %label = field.get('title', '')
               %field_type = field.get('type', 'string')
               %content_type = field.get('content_type', 'string')
               %placeholder = field.get('placeholder', label)
               %allowed = field.get('allowed', '').split(',')
               %if allowed[0] == '':
               %  allowed = []
               %end
               %format = field.get('format')
               %format_parameters = field.get('format_parameters')
               <th>
                  <div>
                  <i class="fa fa-bug"></i>
                  %if field_type=='list':
                  {{'%s -> %s (%s) - %s (%s)' % (name, field_type, content_type, format, format_parameters)}}
                  %else:
                  {{'%s -> %s - %s (%s)' % (name, field_type, format, format_parameters)}}
                  %end
                  <br/>
                  <i class="fa fa-list"></i> {{allowed}}
                  </div>
               </th>
            %end
         </tr>
         %end
         <tr id="filterrow">
            %idx=0
            %for field in dt.table_columns:
               %selectize = False
               %name = field.get('data', '')
               %label = field.get('title', '')
               %field_type = field.get('type', 'string')
               %content_type = field.get('content_type', 'string')
               %placeholder = field.get('placeholder', '')
               %allowed = field.get('allowed', '').split(',')
               %if allowed[0] == '':
               %  allowed = []
               %end
               %format = field.get('format')
               %format_parameters = field.get('format_parameters')
               %required = field.get('required')

               %is_list = False
               %if field_type=='list':
               %  is_list = True
               %  selectize = True
               %  field_type = content_type
               %else:
               %  if allowed:
               %  selectize = True
               %  end
               %  if field_type in ['boolean', 'objectid']:
               %  selectize = True
               %  end
               %end

               <th data-index="{{idx}}" data-name="{{ field['data'] }}" data-selectize="{{selectize}}"
                   data-searchable="{{ field['searchable'] }}"
                   data-regex="{{ field['regex'] }}" data-size="{{ field['size'] }}"
                   data-type="{{ field['type'] }}" data-content-type="{{ field['content_type'] }}"
                   data-format="{{ field['format'] }}" data-format-parameters="{{ field['format_parameters'] }}"
                   data-allowed="{{ field['allowed'] }}"
                   >

                  %if is_list:
                  <div class="form-group form-group-sm">
                     <select id="filter_{{name}}" class="form-control">
                     </select>
                  </div>
                  %else:
                  %  if field_type in ['boolean']:
                  %  allowed = {'Yes': 'true', 'No': 'false', 'Both': ''}
                  <div class="form-group form-group-sm">
                     <input id="filter_{{name}}"
                        class="form-control"
                        type="text"
                        placeholder="{{placeholder}}"
                        >
                  </div>
                  %  else:
                  <div class="form-group form-group-sm">
                     <input id="filter_{{name}}"
                        class="form-control"
                        type="{{'number' if field_type=='integer' else 'text'}}"
                        placeholder="{{placeholder}}"
                        >
                  </div>
                  %  end
                  %end
                  %if selectize:
                  <script>
                     $('#filter_{{name}}').selectize({
                        plugins: ['remove_button'],
                        delimiter: ',',
                        persist: true,

                        valueField: 'id',
                        labelField: 'name',
                        searchField: 'name',

                        create: false,

                        /*
                        render: {
                           option: function(item, escape) {
                              return '<div>' +
                                 (item.name ? '<span class="name">' + escape(item.name) + '</span>' : '') +
                                 (item.alias ? '<small><em><span class="alias"> (' + escape(item.alias) + ')</span></em></small>' : '') +
                              '</div>';
                           },
                           item: function(item, escape) {
                              console.log(item)
                              return '<div>' +
                                 (item.name ? '<span class="name">' + escape(item.name) + '</span>' : '') +
                              '</div>';
                           }
                        },*/

                        %if allowed:
                        %  if isinstance(allowed, dict):
                           options: [
                        %     for k in allowed:
                                 { 'id': '{{allowed[k]}}', 'name': '{{k}}' },
                        %     end
                           ],
                        %  else:
                        %     if allowed[0].startswith('inner://'):
                        //preload: 'focus',
                        preload: true,
                        load: function(query, callback) {
                           //if (!query.length) return callback();
                           $.ajax({
                              url: "{{allowed[0].replace('inner://', '/')}}",
                              type: 'GET',
                              error: function() {
                                 callback();
                              },
                              success: function(res) {
                                 // 10 first items...
                                 //callback(res.slice(0, 10));
                                 callback(res);
                              }
                           });
                        },
                        %     else:
                           options: [
                        %        for option in allowed:
                                    { 'id': '{{option}}', 'name': '{{option}}' },
                        %        end
                           ],
                        %     end
                        %  end
                        %end

                        maxItems: {{'1' if not is_list else 'null'}},
                        closeAfterSelect: {{'true' if format == 'select' else 'false'}},
                        placeholder: '{{placeholder}}',
                        hideSelected: true,
                        allowEmptyOption: false,
                        openOnFocus: true,
                        onChange: function(value) {
                           console.log("Changed:", value);
                           console.log("Changed:", this);
                           //this.clear(true);
                        }
                     });
                  </script>
                  %end
               </th>
               %idx += 1
            %end
         </tr>
         %end
      </thead>
      <tbody>
      </tbody>
   </table>
</div>

<script>
   var debugTable = {{'true' if debugLogs else 'false'}};
   var where = {{! json.dumps(where)}};
   var columns = '';
   var selectedRows = [];

   function resetFilters() {
      var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });

      // Reset table columns search
      table
         .columns()
            .search('', false, false)
            .draw();

      // Clear the search fields
      $('#filterrow th[data-searchable="True"][data-selectize="True"]').each( function () {
         var field_name = $(this).data('name');

         if ($('#filter_'+field_name).length) {
            var input_filter = $('#filter_'+field_name).selectize()[0].selectize;
            if (input_filter) {
               if (debugTable) console.debug('*** clear filter: ', field_name, input_filter.items);
               input_filter.clear(true);
            }
         }
      });

      // Disable the clear filter button
      table.buttons('clearFilter:name').disable();
   }
   $(document).ready(function() {
      %if not embedded:
      set_current_page("{{ webui.get_url(request.route.name) }}");
      %end

      $.ajaxSetup({
         headers: { "Authorization": "Basic " + btoa('{{credentials}}') }
      });

      %if dt.searchable:
      // Apply the search filter for input fields
      $("#tbl_{{object_type}} thead input").on('keyup change', function () {
         var parent = $(this).parents('th')
         var column_index = parent.data('index');
         var column_name = parent.data('name');
         var regex = parent.data('regex');
         var value = $(this).val();
         if ($(this).attr('type') == 'checkbox') {
            value = $(this).is(':checked');
         }
         if (debugTable) console.debug('Datatable event, search column '+column_name+' for '+value);

         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });
         table
            .column(column_index)
               .search(value, regex=='True', false)
               .draw();

         // Enable the clear filter button
         table.buttons('clearFilter:name').enable();
      });

      // Apply the search filter for select fields
      $("#tbl_{{object_type}} thead select").on('change', function () {
         var parent = $(this).parents('th')
         var column_index = parent.data('index');
         var column_name = parent.data('name');
         var value = $(this).val() || [];

         if (debugTable) console.debug("Datatable event, search column '"+column_name+"' for '" + value + "'");

         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });
         table
            .column(column_index)
              .search(value, false, false)
              .draw();

         // Enable the clear filter button
         table.buttons('clearFilter:name').enable();
      });
      %end

      $('#tbl_{{object_type}}').on( 'init.dt', function ( e, settings ) {
         if (debugTable) console.debug('Datatable event, init ...');
         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });

         %if dt.selectable:
         if (table.rows( { selected: true } ).count() > 0) {
             $('[data-reaction="selection-not-empty"]').prop('disabled', false);
             $('[data-reaction="selection-empty"]').prop('disabled', true);
         } else {
             $('[data-reaction="selection-not-empty"]').prop('disabled', true);
             $('[data-reaction="selection-empty"]').prop('disabled', false);
         }
         %end
      });

      %if dt.selectable:
      $('#tbl_{{object_type}}').on( 'select.dt', function ( e, dt, type, indexes ) {
         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });
         if (debugTable) console.debug('Datatable event, selected row ...');

         var rowData = table.rows( indexes ).data().toArray();
         if (debugTable) console.debug('Datatable event, selected: ', rowData);

         if (table.rows( { selected: true } ).count() > 0) {
             $('[data-reaction="selection-not-empty"]').prop('disabled', false);
             $('[data-reaction="selection-empty"]').prop('disabled', true);
         } else {
             $('[data-reaction="selection-not-empty"]').prop('disabled', true);
             $('[data-reaction="selection-empty"]').prop('disabled', false);
         }
      });

      $('#tbl_{{object_type}}').on( 'deselect.dt', function ( e, dt, type, indexes ) {
         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });
         if (debugTable) console.debug('Datatable event, deselected row ...');

            var rowData = table.rows( indexes ).data().toArray();
            if (debugTable) console.debug('Datatable event, deselected: ', rowData);

            if (table.rows( { selected: true } ).count() > 0) {
                $('[data-reaction="selection-not-empty"]').prop('disabled', false);
                $('[data-reaction="selection-empty"]').prop('disabled', true);
            } else {
                $('[data-reaction="selection-not-empty"]').prop('disabled', true);
                $('[data-reaction="selection-empty"]').prop('disabled', false);
            }
      });
      %end

      $('#tbl_{{object_type}}').on( 'stateLoaded.dt', function ( e, settings, data ) {
         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });
         if (debugTable) console.debug('Datatable event, saved state loaded ...');

         resetFilters();

         if (where['saved_filters']) {
            if (debugTable) console.debug('Restoring saved filters:', where);

            // Update each search field with the received value
            $.each(data.columns, function(index, value) {
               var name = $('#filterrow th[data-index="'+index+'"]').data('name');

               if ($('#filter_'+name).length) {
                  if (value['search']['search'] != "") {
                     var input_filter = $('#filter_'+name).selectize()[0].selectize;
                     if (debugTable) console.debug('*** update filter: ', index, name, value['search']['search']);

                     // Update search filter input field value
                     input_filter.setValue(value['search']['search']);

                     // Configure table filtering
                     table
                        .column(index)
                           .search(value['search']['search'], $('#filterrow th[data-index="'+index+'"]').data('regex'), false);

                     // Enable the clear filter button
                     table.buttons('clearFilter:name').enable();
                  }
               }
            });
         } else {
            if (debugTable) console.debug('Erasing saved filters:', where);

            // Update each search field with the filter URL parameters
            $.each(where, function(key, value) {
               var special = '';
               // Special filtering ($ne, $in, ...)
               if (key[0] == "$") {
                  special = key;
                  for (k in value) {
                     key = k;
                     value = value[k];
                  }
               }
               var column_index = table.column(key+':name').index();
               var column_regex = table.column(key+':name').data('regex');

               if (debugTable) console.debug('Update column search special', special);
               if (debugTable) console.debug('Update column search', column_index, key, value, column_regex);
               if (debugTable) console.debug('Update column search', table.column(key+':name'));

               // Update search filter input field value
               var input_filter = $('#filter_'+key).selectize()[0].selectize;
               if (debugTable) console.debug("Set new value: '" + value + "', for "+key);
               $('#filterrow th[data-name="'+key+'"]').children().val(value);

               // Update search filter input field value
               input_filter.setValue(value);

               // Configure table filtering
               table
                  .column(column_index)
                     .search(value, $('#filterrow th[data-name="'+key+'"]').data('regex'), false);

               // Enable the clear filter button
               table.buttons('clearFilter:name').enable();
            });
         }
      });

      // Table declaration
      var table = $('#tbl_{{object_type}}').DataTable( {
         // Disable automatic width calculation
         "autoWidth": false,

         // Pagination
         "paging": {{'true' if dt.paginable else 'false'}},
         "pagingType": "simple_numbers",

         // Pagination
         "lengthChange": true,
         "pageLength": 25,
         "lengthMenu": [ 5, 10, 25, 50, 75, 100, '-1' ],
         "lengthMenu": [
            [ 10, 25, 50, 100, -1 ],
            [
               "{{_('10 rows')}}", "{{_('25 rows')}}", "{{_('50 rows')}}",
               "{{_('100 rows')}}", "{{_('Show all')}}"
            ]
         ],

         // Table information
         "info": true,
         /* Table fixed header - do not activate because table scrolling is not compatible
         "fixedHeader": true, */

         // Server side processing: request new data
         "processing": true,
         "serverSide": true,
         "ajax": {
            "url": "{{server_url}}/{{object_type}}s/table_data",
            "method": "POST",
            "data": function ( d ) {
               // Add an extra field
               d = $.extend({}, d, {
                  "object_type": '{{object_type}}',
                  "embedded": '{{embedded}}',
                  "links": '{{links}}'
               });

               // Json stringify to avoid complex array formatting ...
               d.columns = JSON.stringify( d.columns );
               d.search = JSON.stringify( d.search );
               d.order = JSON.stringify( d.order );
               return ( d );
            }
         },

         %if dt.orderable:
         // Table ordering
         "ordering": true,
         // First row for ordering
         "orderCellsTop": true,
         // Default initial sort
         "order": {{ ! json.dumps(dt.initial_sort) }},
         %else:
         "ordering": false,
         %end

         // Language
         "language": {{! json.dumps(dt.get_language_strings())}},

         // Responsive mode
         %if dt.responsive:
         %setdefault('details', True)
         %setdefault('inline', True)
         %setdefault('immediateRow', False)
         %setdefault('modalDisplay', True)

         responsive: {
            %if details:
            details: {
               %if inline:
               type: 'inline'
               %else:
               type: 'inline'
               %end
               %if immediateRow:
               , display: $.fn.dataTable.Responsive.display.childRowImmediate
               , type: ''
               %elif modalDisplay:
               , display: $.fn.dataTable.Responsive.display.modal({
                  header: function ( row ) {
                     return ('{{_('Details for %s') % object_type}}');
                  }
                })
               , renderer: $.fn.dataTable.Responsive.renderer.tableAll({
                    tableClass: 'table'
               })
               %end
            }
            %else:
            details: false,
            %end
         },
         %else:
         responsive: false,
         %end

         // Selection mode
         select: {{'true' if dt.selectable else 'false'}},

         // Table columns definition
         "columns": {{ ! json.dumps(dt.table_columns) }},

         // Table state saving/restoring
         stateSave: true,
         // Saved parameters
         "stateSaveParams": function (settings, data) {
            if (debugTable) console.debug("state saved data", data);
            // Ignore global search parameter ...
            data.search.search = "";
         },
         // Load table configuration
         stateLoadCallback: function (settings) {
            if (debugTable) console.debug("state loading for 'tbl_{{object_type}}' ...");

            // Get table stored state from the server ...
            var o;
            $.ajax( {
               "url": "{{server_url}}/preference/user",
               "dataType": "json",
               "type": "GET",
               "data": {
                  "key": '{{object_type}}s_table'
               },
               "async": false,
               "success": function (json) {
                  if (debugTable) console.debug("state restored for 'tbl_{{object_type}}' ...", json);
                  o = json;
               }
            });

            return o;
         },
         // Save table configuration
         stateSaveCallback: function (settings, data) {
            if (debugTable) console.debug("state saving for 'tbl_{{object_type}}' ...", settings);

            // Post table data to the server ...
            $.ajax({
               "url": "{{server_url}}/preference/user",
               "dataType": "json",
               "type": "POST",
               "data": {
                  "key": '{{object_type}}s_table',
                  // Json stringify to avoid complex array formatting ...
                  "value": JSON.stringify( data )
               },
               "success": function () {
                  if (debugTable) console.debug("state saved for 'tbl_{{object_type}}' ...", settings);
               }
            });
         },

         // Each created row ...
         createdRow: function (row, data, index) {
            /*
            if (debugTable) console.debug('Datatable createdRow, data: ', data);
            if (debugTable) console.debug('Datatable createdRow, name: {{dt.name_property}}');
            if (debugTable) console.debug('Datatable createdRow, status: {{dt.status_property}}');
            */

            if ('{{dt.name_property}}' in data) {
               var name_node = table.cell(index, '{{dt.name_property}}:name').node();
               // The node descendants should contain some information about the element
               /* eg.
                  <a href="/livestate/5786027106fd4b0af2d51b3e">vm-win7/Cpu</a>
               */
            }

            if ('{{dt.status_property}}' in data) {
               var status_node = table.cell(index, '{{dt.status_property}}:name').node();
               // The node descendants should contain some information about the element
               /* eg.
                  <div class="item-state item_livestate_ok OK" style="display: inline; font-size:0.9em;" data-item-id="5786027006fd4b0af0d51c42" data-item-name="vm-win7/Disks" data-item-type="livestate" data-item-state="OK" title="Service is ok">
                     <span class="fa-stack ">
                        <i class="fa fa-circle fa-stack-2x item_livestate_ok"></i>
                        <i class="fa fa-cube fa-stack-1x fa-inverse"></i>
                     </span>
                     <span>Service is ok</span>
                  </div>
                */
               var id = $(status_node).find('[data-item-id]').data('item-id');
               var type = $(status_node).find('[data-item-type]').data('item-type');
               var name = $(status_node).find('[data-item-name]').data('item-name');
               var state = $(status_node).find('[data-item-state]').data('item-state');

               var row = table.row(index).node();
               $(row).addClass('table-row-'+state.toLowerCase());
            }
         },

         /*
            B - buttons
            l - length changing input control
            f - filtering input
            t - The table!
            i - Table information summary
            p - pagination control
            r - processing display element
         dom: 'Blfrtip',
         Currently, no global search...
         */
         dom: "<'row'<'col-xs-12'B><'col-xs-1'>>" + "<'row'<'col-xs-12'tr>>" + "<'row'<'col-xs-12'i>>" + "<'row'<'col-xs-12'p>>",
         // Table columns visibility button
         buttons: [
            {
               extend: 'pageLength',
               className: 'btn-raised btn-xs'
            }
            ,{
               extend: 'colvis',
               className: 'btn-raised btn-xs'
            }
            %if dt.printable:
            ,{
               extend: 'print',
               autoPrint: false,
               // message: 'Utiliser la fonction Imprimer de votre navigateur pour imprimer la page',
               exportOptions: {
                  columns: ':visible',
                  modifier: {
                     search: 'none'
                  }
               },
               className: 'btn-raised btn-xs'
            }
            %end
            %if dt.exportable:
            ,{
               extend: 'collection',
               buttons: [
                  {
                     extend: 'csv',
                     header: true,
                     footer: false,
                     fieldBoundary: '"',
                     fieldSeparator: ";",
                     extension: ".csv",
                     exportOptions: {
                        columns: ':visible',
                        modifier: {
                           search: 'none'
                        }
                     },
                     className: 'btn-raised btn-xs'
                  }
                  ,
                  {
                     extend: 'excel',
                     header: true,
                     footer: false,
                     extension: ".xlsx",
                     exportOptions: {
                        columns: ':visible',
                        modifier: {
                           search: 'none'
                        }
                     },
                     className: 'btn-raised btn-xs'
                  }
                  ,
                  {
                     extend: 'pdf',
                     header: true,
                     footer: false,
                     extension: ".pdf",
                     orientation: 'landscape',
                     pageSize: 'A4',
                     exportOptions: {
                        columns: ':visible',
                        modifier: {
                           search: 'none'
                        }
                     },
                     className: 'btn-raised btn-xs'
                  }
               ],
               className: 'btn-raised btn-xs'
            }
            %end
            %if dt.searchable:
            ,{
               name: 'clearFilter',
               text: '<span id="clearFilter" class="fa-stack" style="font-size:0.63em;"><i class="fa fa-filter"></i><i class="fa fa-ban fa-stack-2x text-danger"></i></span>',
               titleAttr: "{{_('Reset all the search filters')}}",
               action: function ( e, dt, node, data ) {
                  resetFilters();
               },
               className: 'btn-raised btn-xs'
            }
            %end
            %if dt.selectable:
            ,{
               extend: 'selectAll',
               titleAttr: "{{_('Select all the table rows')}}",
               className: 'btn-raised btn-xs'
            }
            ,{
               extend: 'selectNone',
               titleAttr: "{{_('Unselect all rows')}}",
               className: 'btn-raised btn-xs'
            }
            %end
            // Only for 'editable' tables
            %if dt.editable:
            ,{
               extend: 'selectedSingle',
               text: "{{! _('<span class=\'fa fa-edit\'></span>')}}",
               titleAttr: "{{_('Edit the selected item')}}",
               className: 'btn-raised btn-xs',
               action: function (e, dt, button, config) {
                  var selected = dt.rows( { selected: true } );
                  var count_selected = selected.indexes().length;
                  if (count_selected != 1) {
                     return;
                  }
                  var url = "{{server_url}}/{{object_type}}/form/";
                  var first = true;
                  $.each(selected.data(), function(index, elt){
                     if (! first) return false;
                     url += encodeURIComponent(elt._id);
                  });
                  window.setTimeout(function(){
                     window.location.href = url;
                  }, 50);
               }
            }
            %end
            %if dt.commands:
            // Only for tables with 'commands' attribute (eg. livestate)
            ,{
               extend: 'collection',
               text: "{{! _('<span class=\'fa fa-bolt\'></span>')}}",
               className: 'btn-raised btn-xs',
               buttons: [
                  {
                     extend: 'selected',
                     text: "{{_('Re-check')}}",
                     titleAttr: "{{_('Force a re-check for selected items')}}",
                     className: 'btn-raised btn-xs',
                     action: function (e, dt, button, config) {
                        // Fix for datatable that do not close dropdown immediatly...
                        $(".dt-button-background").trigger("click");
                        var selected = dt.rows( { selected: true } );
                        var count_selected = selected.indexes().length;
                        if (count_selected == 0) {
                           return;
                        }
                        var url = "/recheck/form/add?";
                        var first = true;
                        $.each(selected.data(), function(index, elt){
                           var elt_name = elt.display_name_host;
                           if (elt.type == 'service') {
                              elt_name += ' (' + elt.display_name_service + ')';
                           }
                           if (! first) url += '&';
                           url += "livestate_id="+encodeURIComponent(elt._id)+'&element_name='+encodeURIComponent(elt_name);
                           if (first) first = false;
                        });
                        window.setTimeout(function(){
                           display_modal(url);
                        }, 50);
                     },
                  }
                  ,
                  {
                     extend: 'selected',
                     text: "{{_('Acknowledge')}}",
                     titleAttr: "{{_('Acknowledge selected items')}}",
                     className: 'btn-raised btn-xs',
                     action: function (e, dt, button, config) {
                        // Fix for datatable that do not close dropdown immediatly...
                        $(".dt-button-background").trigger("click");
                        var selected = dt.rows( { selected: true } );
                        var count_selected = selected.indexes().length;
                        if (count_selected == 0) {
                           return;
                        }
                        var url = "/acknowledge/form/add?";
                        var first = true;
                        $.each(selected.data(), function(index, elt){
                           var elt_name = elt.display_name_host;
                           if (elt.type == 'service') {
                              elt_name += ' (' + elt.display_name_service + ')';
                           }
                           if (! first) url += '&';
                           url += "livestate_id="+encodeURIComponent(elt._id)+'&element_name='+encodeURIComponent(elt_name);
                           if (first) first = false;
                        });
                        window.setTimeout(function(){
                           display_modal(url);
                        }, 50);
                     },
                  }
                  ,
                  {
                     extend: 'selected',
                     text: "{{_('Downtime')}}",
                     titleAttr: "{{_('Schedule a downtime for selected items')}}",
                     className: 'btn-raised btn-xs',
                     action: function (e, dt, button, config) {
                        // Fix for datatable that do not close dropdown immediatly...
                        $(".dt-button-background").trigger("click");
                        var selected = dt.rows( { selected: true } );
                        var count_selected = selected.indexes().length;
                        if (count_selected == 0) {
                           return;
                        }
                        var url = "/downtime/form/add?";
                        var first = true;
                        $.each(selected.data(), function(index, elt){
                           var elt_name = elt.display_name_host;
                           if (elt.type == 'service') {
                              elt_name += ' (' + elt.display_name_service + ')';
                           }
                           if (! first) url += '&';
                           url += "livestate_id="+encodeURIComponent(elt._id)+'&element_name='+encodeURIComponent(elt_name);
                           if (first) first = false;
                        });
                        window.setTimeout(function(){
                           display_modal(url);
                        }, 50);
                     },
                  }
               ],
            }
            %end
            %if dt.recursive:
            ,{
               text: "{{! _('<span class=\'fa fa-sitemap\'></span>')}}",
               titleAttr: "{{_('Navigate to the tree view')}}",
               action: function (e, dt, button, config) {
                  if (debugTable) console.log('Navigate to the tree view for {{object_type}}!');
                  window.location.href = "/{{object_type}}s/tree";
               },
               className: 'btn-raised btn-xs'
            }
            %end
         ]
      });

      %if dt.responsive:
      $('#tbl_{{object_type}}').on( 'responsive-resize.dt', function ( e, datatable, columns ) {
         var table = $('#tbl_{{object_type}}').DataTable({ retrieve: true });
         if (debugTable) console.debug('Datatable event, responsive resize...');

         $.each(columns, function(index, visibility){
            if (visibility == false) {
               // Update search filter input field value
               $('#filterrow th[data-index="'+index+'"]').css({
                  display: "none"
               });
            }
            if (visibility == true) {
               // Update search filter input field value
               $('#filterrow th[data-index="'+index+'"]').css({
                  display: "table-cell"
               });
            }
         });
         // Recalculate columns and table width
         if (debugTable) console.debug('Datatable event, responsive resize... recalculate columns and table width');
         table.columns.adjust()
         table.responsive.recalc();
      });
      %end
   });
 </script>
