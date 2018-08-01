#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
    Matrix Worldmap
"""

import re

from logging import getLogger
from collections import OrderedDict

from bottle import request

from alignak_webui.utils.plugin import Plugin
from alignak_webui.utils.helper import Helper
from alignak_webui.utils.perfdata import PerfDatas

# pylint: disable=invalid-name
logger = getLogger(__name__)

def _metric_to_json(m):
    return dict(name=m.name, value=m.value, uom=m.uom, warning=m.warning, critical=m.critical, min=m.min, max=m.max)


class PluginMatrix(Plugin):
    """ Matrix plugin """

    def __init__(self, webui, plugin_dir, cfg_filenames=None):
        """Worldmap plugin"""
        self.name = 'Worldmap'
        self.backend_endpoint = None

        self.pages = {
            'show_matrix': {
                'name': 'Matrix',
                'route': '/matrix',
                'view': 'matrix'
            },
            'show_matrix_json': {
                'name': 'Matrix Json',
                'route': '/matrix.json'
            },
        }

        super(PluginMatrix, self).__init__(webui, plugin_dir, cfg_filenames)

        self.search_engine = True


    def show_matrix(self):
        return {
            'search_engine': self.search_engine,
            'search_filters': self.search_filters,
            'title': request.query.get('title', _('Hosts matrix'))
        }


    def show_matrix_json(self):
        # TODO

        datamgr = request.app.datamgr

        search = request.query.get('search', "")
        draw = request.query.get('draw', "")

        start  = int(request.query.get('start', None) or 0)
        length = int(request.query.get('length', None) or 5000)

        items = []

        data = list()

        hosts = dict()

        _headers = set()
        _groups  = OrderedDict()

        #for h in items:
        #    logger.warning("busqueda::%s" % type(h) )

        #hosts_items = [item for item in items if isinstance(item, Host)]
        search = {
            'sort': '-_overall_state_id,name',
            'where': {}
        }

        hosts_items = datamgr.get_hosts(search={'where': {}})

        for h in hosts_items:
            _host = h.name
            if not hosts.get(_host):
                hosts[_host] = dict()

                hosts[_host]['state_id'] = h.state_id
                hosts[_host]['display_name'] = h.display_name


            if hasattr(h,'perf_data'):
                for m in PerfDatas(h.perf_data):
                    _metric = _metric_to_json(m)
                    _name  = _metric.get('name')
                    p = re.compile(r"\w+\d+")
                    if p.search(_name):
                        continue
                    hosts[_host][_name] = _metric
                    if not _name in _headers:
                        _headers.add(_name)
                        if not _groups.get('host'):
                            _groups['host'] = list()
                        _groups['host'].append(_name)


            if hasattr(h,'cpe_registration_host') and h.cpe_registration_host:
                hosts[_host]['reg'] =  h.cpe_registration_host
            elif hasattr(h,'address') and h.address:
                hosts[_host]['reg'] = h.address

            # for s in h.services:
            #     _group = s.get_name()
            #     if not _groups.get(_group):
            #         _groups[_group] = list()
            #
            #     for m in s.perf_data:
            #         _metric = _metric_to_json(m)
            #         _name  = _metric.get('name')
            #         p = re.compile(r"\w+\d+")
            #         if p.search(_name):
            #             continue
            #
            #         hosts[_host][_name] = _metric
            #         if not _name in _headers:
            #             _headers.add(_name)
            #             _groups[_group].append(_name)


        for key, value in hosts.iteritems():
            if not value:
                continue
            _temp = {'host': key}
            for _kk, _vv in value.iteritems():
                _temp[_kk] = _vv

            data.append(_temp)

        xdata = {
            'draw': draw,
            'data': data[start:int(start+length)],
            'recordsFiltered': len(data),
            'recordsTotal': len(data),
            'headers': list(_headers),
            'groups': _groups
        }

        return xdata
