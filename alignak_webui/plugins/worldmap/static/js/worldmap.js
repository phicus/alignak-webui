// Set true to activate javascript console logs
var debugMaps = true;
if (debugMaps && !window.console) {
    alert('Your web browser does not have any console object ... you should stop using IE ;-) !');
}
if (debugMaps) {
    console.log("Activated debug maps logs");
}

var defaultZoom = 6;
if (debugMaps) console.log('Default zoom: ', defaultZoom);
var defaultCenter = [46.60611, 1.87528];
if (debugMaps) console.log('Default center: ', defaultCenter);

var actions = false;

// Markers ...
var allMaps = [];

// Hosts
var hosts = []


function hostInfoContent() {
    return this.content;
}

function gpsLocation() {
    return L.latLng(this.lat, this.lng);
}

function markerIcon() {
    return "/static/plugins/worldmap/static/img/" + '/glyph-marker-icon-' + this.hostStatus().toLowerCase() + '.png';
}

function hostState() {
    return this.overallState;
}

function hostStatus() {
    return this.overallStatus;
}

function Host(id, name, alias, overallState, overallStatus, state, bi, content, lat, lng, services) {
    this.id = id;
    this.name = name;
    this.alias = alias;
    this.overallState = overallState;
    this.overallStatus = overallStatus;
    this.state = state;
    this.bi = bi;
    this.content = content;
    this.services = services;

    this.lat = lat;
    this.lng = lng;

    this.infoContent = hostInfoContent;
    this.location = gpsLocation;
    this.markerIcon = markerIcon;
    this.hostState = hostState;
    this.hostStatus = hostStatus;
}

function serviceInfoContent() {
    var text = '<li>' + this.stateIcon + ' <a href="/service/' + this.id + '">' + this.name + '</a> ' + this.biIcon;
    if (this.isDowntimed) {
        text += '<div><i class="fa fa-ambulance"></i>Currently in scheduled downtime.</div>';
    }
    if (this.isProblem) {
        text += '<div>';
        if (this.isAcknowledged) {
            text += '<em><span class="fa fa-check"></span>Problem has been acknowledged.</em>';
        } else {
            if (actions) {
                text += '<button class="btn btn-raised btn-xs" ';
                text += 'data-type="action" data-action="acknowledge" data-toggle="tooltip" data-placement="top"';
                text += 'title="Acknowledge this problem"';
                text += 'data-element_type="service" data-name="'+this.name+'" data-element="'+this.id+'">';
                text += '<i class="fa fa-check"></i></button>';
            } else {
                text += '<em><span class="fa fa-exclamation"></span>Problem should be acknowledged.</em>';
            }
        }
        text += '</div>';
    }
    text += '</li>';
    return text;
}

function Service(hostId, id, name, alias, overallState, overallStatus, state, bi, content) {
    this.hostId = hostId;
    this.id = id;
    this.name = name;
    this.alias = alias;
    this.overallState = overallState;
    this.overallStatus = overallStatus;
    this.state = state;
    this.bi = bi;
    this.content = content;

    this.infoContent = serviceInfoContent;
}

//------------------------------------------------------------------------------
// Sequentially load necessary scripts to create map with markers
//------------------------------------------------------------------------------
loadScripts = function(scripts, complete) {
    var loadScript = function(src) {
        if (!src)
            return;
        if (debugMaps)
            console.log('Loading script: ', src);

        $.getScript(src, function(data, textStatus, jqxhr) {
            next = scripts.shift();
            if (next) {
                loadScript(next);
            } else if (typeof complete == 'function') {
                complete();
            }
        });
    };
    if (scripts.length) {
        loadScript(scripts.shift());
    } else if (typeof complete == 'function') {
        complete();
    }
}

// ------------------------------------------------------------------------------
// Create a marker for specified host
// ------------------------------------------------------------------------------
markerCreate = function($map, host) {
    if (debugMaps) console.log("-> marker creation for " + host.name + ", state : " + host.hostStatus());

    var icon = L.icon.glyph({iconUrl: host.markerIcon(), prefix: 'fa', glyph: 'server'});

    var m = L.marker(host.location(), {icon: icon}).bindLabel(host.name, {
        noHide: true,
        direction: 'center',
        offset: [0, 0]
    }).bindPopup(host.infoContent()).openPopup();
    m.state = host.hostState();
    m.state_text = host.hostStatus();
    m.name = host.name;
    return m;
}

// ------------------------------------------------------------------------------
// Resize the map
// ------------------------------------------------------------------------------
mapResize = function($map, host) {
    if (typeof L !== 'undefined') {
        if (debugMaps)
            console.log("Map resize...", $map._leaflet_id);
        // Set map widht and height
        L.Util.requestAnimFrame($map.invalidateSize, $map, !1, $map._container);
        $("#hostsMap").height($("#worldmap").height()).width($("#worldmap").width());
        $map.invalidateSize();
    }
}

// ------------------------------------------------------------------------------
// Map initialization
// ------------------------------------------------------------------------------
mapInit = function(map_id, callback) {
    if (debugMaps) console.log('Initialization function: mapInit for ', map_id);

    if  (hosts.length < 1) {
        if (debugMaps) console.log('No hosts to display on the map.');
        return false;
    }

    var scripts = [];
    scripts.push('/static/plugins/worldmap/static/js/leaflet.markercluster.js');
    scripts.push('/static/plugins/worldmap/static/js/leaflet.Icon.Glyph.js');
    scripts.push('/static/plugins/worldmap/static/js/leaflet.label.js');
    loadScripts(scripts, function() {
        if (debugMaps) console.log('Scripts loaded')

        $map = L.map(map_id, {zoom: defaultZoom, center: defaultCenter});
        if (debugMaps) console.log('Map object: ', map_id, $map)

        L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png', {attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors, &copy; <a href="http://cartodb.com/attributions">CartoDB</a>'}).addTo($map);

        // Markers ...
        var allMarkers = [];
        var bounds = new L.LatLngBounds();
        if (debugMaps) console.log("Initial map bounds:", bounds);
        for (var i = 0; i < hosts.length; i++) {
            var h = hosts[i];
            bounds.extend(h.location());
            allMarkers.push(markerCreate($map, h));
        }
        if (debugMaps) console.log("Extended map bounds:", bounds);

        // Zoom adaptation if bounds are a rectangle
        if (debugMaps) console.log("Extended map bounds:", bounds.getNorth(), bounds.getSouth());
        if (bounds.getNorth() != bounds.getSouth()) {
            $map.fitBounds(bounds);
        }

        // Build marker cluster
        var markerCluster = L.markerClusterGroup({
            iconCreateFunction: function(cluster) {
                // Manage markers in the cluster ...
                var markers = cluster.getAllChildMarkers();
                if (debugMaps) console.log("cluster markers, count : " + markers.length);

                var clusterState = 0, clusterStyle = 'ok';
                for (var i = 0; i < markers.length; i++) {
                    var currentMarker = markers[i];
                    if (debugMaps) console.log("marker, " + currentMarker.name + " state is: " + currentMarker.state_text);
                    clusterState = Math.max(clusterState, currentMarker.state);
                }
                if (clusterState > 3) {
                    clusterStyle = 'ko';
                } else if (clusterState > 0) {
                    clusterStyle = 'warning';
                }
                if (debugMaps) console.log("cluster state:", clusterState, clusterStyle);
                return L.divIcon({
                    html: '<div><span>' + markers.length + '</span></div>',
                    className: 'marker-cluster marker-cluster-' + clusterStyle,
                    iconSize: new L.Point(60, 60)
                });
            }
        });
        markerCluster.addLayers(allMarkers);
        $map.addLayer(markerCluster);

        allMaps.push($map);

        $(window).on("resize", function() {
            mapResize($map);
        //    $("#hostsMap").height($("#worldmap").height()).width($("#worldmap").width());
        //    $map.invalidateSize();
        }).trigger("resize");

        if (typeof callback !== 'undefined' && $.isFunction(callback)) {
            if (debugMaps) console.log('Calling callback function ...');
            callback($map);
        }
    });

    return true;
};

// ------------------------------------------------------------------------------
// Map assets loading
// ------------------------------------------------------------------------------
createMap = function(mapId, emptyMessage) {
    var cssfiles=[
        '/static/plugins/worldmap/static/leaflet/leaflet.css',
        '/static/plugins/worldmap/static/css/MarkerCluster.css',
        '/static/plugins/worldmap/static/css/MarkerCluster.Default.css',
        '/static/plugins/worldmap/static/css/leaflet.label.css',
        '/static/plugins/worldmap/static/css/worldmap.css'];

    $.getCssFiles(cssfiles, function(){
        var jsfiles=[
            '/static/plugins/worldmap/static/leaflet/leaflet.js',
            '/static/plugins/worldmap/static/js/worldmap.js'];

        $.getJsFiles(jsfiles, function(){
            window.setTimeout(function () {
                // Build hosts list
                buildHosts();

                // Build map
                var mapCreated = mapInit(mapId, function($map) {
                    // Map height to be scaled inside the window
                    var mapOffset = $('#' + mapId).offset().top;
                    var footerOffset = $('footer').offset().top;
                    $('#' + mapId).height(footerOffset - mapOffset - 35)

                    if (debugMaps) console.log('Resizing map:')
                    mapResize($map);
                });
                if (! mapCreated) {
                    $('#' + mapId).html('<div class="alert alert-danger"><a href="#" class="alert-link">'+ emptyMessage +'</a></div>');
                }
            }, 500);
        });
    });
}