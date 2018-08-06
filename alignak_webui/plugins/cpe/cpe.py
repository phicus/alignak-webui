#!/usr/bin/python

# -*- coding: utf-8 -*-

"""
    Plugin CPE
"""

import collections
import json

from logging import getLogger

from bottle import request

from alignak_webui.utils.plugin import Plugin
from alignak_webui.utils.helper import Helper
from alignak_webui.objects.element import BackendElement


# pylint: disable=invalid-name
logger = getLogger(__name__)

class BackendElementEncoder(json.JSONEncoder):

        __serializable__ = ['name']

        def default(self, obj):
            if isinstance(obj, BackendElement):
                return dict([ (field,getattr(obj, field)) for field in self.__serializable__ ])
            return json.JSONEncoder.default(self, obj)


class CpeEncoder(json.JSONEncoder):

        __serializable__ = ['id','name','display_name','alias','address',
        'address6', 'location', 'notes', 'notes_url', 'state']

        def default(self, obj):
            return dict([ (field,getattr(obj, field)) for field in self.__serializable__ ])

class FooObject(object):
    def __iter__(self):
        return self

    def next(self):
        raise StopIteration

    def __call__(self, *args, **kwargs):
        return FooObject()
    def __getattr__(self, name):
        return FooObject()

    def __len__(self):
        return 0

class PluginCPE(Plugin):
    """ CPE plugin """

    def __init__(self, webui, plugin_dir, cfg_filenames=None):
        """CPE plugin"""
        self.name = 'CPE'
        self.backend_endpoint = None

        self.pages = {
            'show_cpe': {
                'name': 'CPE',
                'route': '/cpe/<element_id>',
                'view': 'cpe'
            }
        }

        super(PluginCPE, self).__init__(webui, plugin_dir, cfg_filenames)

    def show_cpe(self, element_id):

        datamgr = request.app.datamgr
        host = datamgr.get_host(element_id)
        if not host:
            host = datamgr.get_host(search={'max_results': 1, 'where': {'name': element_id}})
        if not host:
            return self.webui.response_invalid_parameters(_('Host does not exist'))

        ''' Mostrar la ficha del CPE con nombre cpe_name.'''
        return {'host': json.dumps(host, cls=CpeEncoder), 'raw': host}
