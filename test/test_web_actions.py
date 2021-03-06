#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright (c) 2015-2017:
#   Frederic Mohier, frederic.mohier@gmail.com
#
# This file is part of (WebUI).
#
# (WebUI) is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# (WebUI) is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with (WebUI).  If not, see <http://www.gnu.org/licenses/>.
# import the unit testing module


import os
import time
import shlex
import unittest2
import subprocess
import requests
from calendar import timegm
from datetime import datetime, timedelta

# from nose.tools import *

# Set test mode ...
os.environ['ALIGNAK_WEBUI_TEST'] = '1'
os.environ['ALIGNAK_WEBUI_DEBUG'] = '1'
os.environ['ALIGNAK_WEBUI_CONFIGURATION_FILE'] = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'settings.cfg')
print("Configuration file", os.environ['ALIGNAK_WEBUI_CONFIGURATION_FILE'])
os.environ['ALIGNAK_WEBUI_LOGGER_FILE'] = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'logging.json')
print("Logger configuration file", os.environ['ALIGNAK_WEBUI_LOGGER_FILE'])

if os.path.exists('/tmp/alignak-webui.log'):
    os.remove('/tmp/alignak-webui.log')

import alignak_webui.app
# from alignak_webui import webapp
from alignak_webui.backend.datamanager import DataManager
import alignak_webui.utils.datatable

# from logging import getLogger, DEBUG, INFO
# loggerDm = getLogger('alignak_webui.objects.datamanager')
# loggerDm.setLevel(DEBUG)

import bottle
from bottle import BaseTemplate, TEMPLATE_PATH

from webtest import TestApp

backend_process = None
backend_address = "http://127.0.0.1:5000/"


def setup_module(module):
    # Set test mode for applications backend
    os.environ['TEST_ALIGNAK_BACKEND'] = '1'
    os.environ['ALIGNAK_BACKEND_MONGO_DBNAME'] = 'alignak-webui-tests'

    # Delete used mongo DBs
    exit_code = subprocess.call(
        shlex.split('mongo %s --eval "db.dropDatabase()"'
                    % os.environ['ALIGNAK_BACKEND_MONGO_DBNAME'])
    )
    assert exit_code == 0
    time.sleep(1)

    test_dir = os.path.dirname(os.path.realpath(__file__))
    print("Current test directory: %s" % test_dir)

    print("Starting Alignak backend...")
    global backend_process
    fnull = open(os.devnull, 'w')
    backend_process = subprocess.Popen(['uwsgi', '--plugin', 'python',
                                        '-w', 'alignak_backend.app:app',
                                        '--socket', '0.0.0.0:5000',
                                        '--protocol=http', '--enable-threads', '--pidfile',
                                        '/tmp/uwsgi.pid'],
                                       stdout=fnull)
    print("Started")

    print("Feeding Alignak backend... %s" % test_dir)
    exit_code = subprocess.call(
        shlex.split('alignak-backend-import --delete %s/cfg/alignak-demo/alignak-backend-import.cfg' % test_dir),
        stdout=fnull
    )
    assert exit_code == 0
    print("Fed")


def teardown_module(module):
    print("Stopping Alignak backend...")
    global backend_process
    backend_process.kill()
    # subprocess.call(['pkill', 'alignak-backend'])
    print("Stopped")
    time.sleep(2)


class tests_actions(unittest2.TestCase):

    def setUp(self):
        # Test application
        self.app = TestApp(alignak_webui.app.session_app)

        response = self.app.get('/login')
        response.mustcontain('<form role="form" method="post" action="/login">')

        response = self.app.post('/login', {'username': 'admin', 'password': 'admin'})
        # Redirected twice: /login -> / -> /dashboard !
        redirected_response = response.follow()
        redirected_response = redirected_response.follow()
        # redirected_response.mustcontain('<div id="dashboard">')
        self.stored_response = redirected_response
        # A host cookie now exists
        assert self.app.cookies['Alignak-WebUI']

    def tearDown(self):
        response = self.app.get('/logout')
        redirected_response = response.follow()
        redirected_response.mustcontain('<form role="form" method="post" action="/login">')

    @unittest2.skip("Skipped because needing some updates")
    def test_acknowledge(self):
        """ Actions - acknowledge"""
        print('test actions')

        print('get page /acknowledge/form/add')
        response = self.app.get('/acknowledge/form/add')
        response.mustcontain(
            '<form class="form-horizontal" data-item="acknowledge" data-action="add" '
        )

        # Get Data manager in the session
        session = response.request.environ['beaker.session']
        assert 'current_user' in session and session['current_user']
        assert session['current_user'].get_username() == 'admin'

        datamgr = DataManager(alignak_webui.app.app, session=session)

        # Get host and user in the backend
        host = datamgr.get_host({'where': {'name': 'localhost'}})
        user = datamgr.get_user({'where': {'name': 'admin'}})

        # -------------------------------------------
        # Add an acknowledge
        # Missing element_id!
        data = {
            "elements_type": "host",
            "element_id": host.id,
            "service": None,
            "sticky": True,
            "persistent": True,
            "notify": True,
            "comment": "User comment",
        }
        self.app.post('/acknowledge/add', data, status=400)

        # Acknowledge an host
        data = {
            "action": "add",
            "elements_type": 'host',    # Default value, can be omitted ...
            "element_id": host.id,
            "sticky": True,
            "persistent": True,
            "notify": True,
            "comment": "User comment",
        }
        response = self.app.post('/acknowledge/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Acknowledge sent for localhost. "

        # Acknowledge a service
        service = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        data = {
            "action": "add",
            "elements_type": 'service',
            "element_id": service.id,
            "sticky": True,
            "persistent": True,
            "notify": True,
            "comment": "User comment",
        }
        response = self.app.post('/acknowledge/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Acknowledge sent for localhost/Cpu. "

        # Acknowledge several services
        service1 = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        service2 = datamgr.get_service({'where': {'host': host.id, 'name': 'Memory'}})
        data = {
            "action": "add",
            "elements_type": 'service',
            "element_id": [service1.id, service2.id],
            "sticky": True,
            "persistent": True,
            "notify": True,
            "comment": "User comment",
        }
        response = self.app.post('/acknowledge/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Acknowledge sent for localhost/Cpu. " \
                         "Acknowledge sent for localhost/Memory. " \

        # Acknowledge several services
        service1 = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        service2 = datamgr.get_service({'where': {'host': host.id, 'name': 'Memory'}})
        data = {
            "action": "add",
            "elements_type": 'service',
            "element_id": [service1.id, service2.id, 'test'],
            "sticky": True,
            "persistent": True,
            "notify": True,
            "comment": "User comment",
        }
        response = self.app.post('/acknowledge/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Acknowledge sent for localhost/Cpu. " \
                         "Acknowledge sent for localhost/Memory. " \
                         "service element test does not exist. "

    @unittest2.skip("Skipped because needing some updates")
    def test_downtime(self):
        """ Actions - downtime"""
        print('test actions')

        print('get page /downtime/form/add')
        response = self.app.get('/downtime/form/add')
        response.mustcontain(
            '<form class="form-horizontal" data-item="downtime" data-action="add"'
        )

        # Current user is admin
        session = response.request.environ['beaker.session']
        assert 'current_user' in session and session['current_user']
        assert session['current_user'].get_username() == 'admin'

        # Data manager
        datamgr = DataManager(alignak_webui.app.app, session=session)

        # Get host, user and realm in the backend
        host = datamgr.get_host({'where': {'name': 'localhost'}})
        user = datamgr.get_user({'where': {'name': 'admin'}})

        now = datetime.utcnow()
        later = now + timedelta(days=2, hours=4, minutes=3, seconds=12)
        now = timegm(now.timetuple())
        later = timegm(later.timetuple())

        # -------------------------------------------
        # Add an downtime
        # Missing livestate_id!
        data = {
            "action": "add",
            "host": host.id,
            "service": None,
            "start_time": now,
            "end_time": later,
            "fixed": False,
            'duration': 86400,
            "comment": "User comment",
        }
        self.app.post('/downtime/add', data, status=400)

        # downtime an host
        data = {
            "action": "add",
            "element_id": host.id,
            "start_time": now,
            "end_time": later,
            "fixed": False,
            'duration': 86400,
            "comment": "User comment",
        }
        response = self.app.post('/downtime/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Downtime sent for localhost. "

        # downtime a service
        service = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        data = {
            "action": "add",
            "elements_type": 'service',
            "element_id": service.id,
            "start_time": now,
            "end_time": later,
            "fixed": False,
            'duration': 86400,
            "comment": "User comment",
        }
        response = self.app.post('/downtime/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Downtime sent for localhost/Cpu. "

        # downtime several services
        service1 = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        service2 = datamgr.get_service({'where': {'host': host.id, 'name': 'Memory'}})
        data = {
            "action": "add",
            "elements_type": 'service',
            "element_id": [service1.id, service2.id, 'test'],
            "start_time": now,
            "end_time": later,
            "fixed": False,
            'duration': 86400,
            "comment": "User comment",
        }
        response = self.app.post('/downtime/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == \
                         "Downtime sent for localhost/Cpu. " \
                         "Downtime sent for localhost/Memory. " \
                         "service element test does not exist. "

    @unittest2.skip("Skipped because needing some updates")
    def test_recheck(self):
        """ Actions - recheck"""
        print('test recheck')

        print('get page /recheck/form/add')
        response = self.app.get('/recheck/form/add')
        response.mustcontain(
            '<form class="form-horizontal" data-item="recheck" data-action="add" '
        )

        # Current user is admin
        session = response.request.environ['beaker.session']
        assert 'current_user' in session and session['current_user']
        assert session['current_user'].get_username() == 'admin'

        # Data manager
        datamgr = DataManager(alignak_webui.app.app, session=session)

        # Get host, user and realm in the backend
        host = datamgr.get_host({'where': {'name': 'localhost'}})
        user = datamgr.get_user({'where': {'name': 'admin'}})

        # -------------------------------------------
        # Add a recheck
        # Missing livestate_id!
        data = {
            "host": host.id,
            "service": None,
            "sticky": True,
            "persistent": True,
            "notify": True,
            "comment": "User comment",
        }
        response = self.app.post('/recheck/add', data, status=400)

        # Recheck an host
        data = {
            "elements_type": 'host',
            "element_id": host.id,
            "comment": "User comment",
        }
        response = self.app.post('/recheck/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == "Check request sent for localhost. "

        # Recheck a service
        service = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        data = {
            "elements_type": 'service',
            "element_id": service.id,
            "comment": "User comment",
        }
        response = self.app.post('/recheck/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == "Check request sent for localhost/Cpu. "

        # Recheck several services
        service1 = datamgr.get_service({'where': {'host': host.id, 'name': 'Cpu'}})
        service2 = datamgr.get_service({'where': {'host': host.id, 'name': 'Memory'}})
        data = {
            "action": "add",
            "elements_type": 'service',
            "element_id": [service1.id, service2.id, 'test'],
            "comment": "User comment",
        }
        response = self.app.post('/recheck/add', data)
        assert response.json['status'] == "ok"
        assert response.json['message'] == "Check request sent for localhost/Cpu. Check request sent for localhost/Memory. service element test does not exist. "

    @unittest2.skip("Skipped because difference between Travis and local execution (correct!) ... to be explained!")
    def test_command(self):
        """ Actions - command"""
        print('test command')

        print('get page /command/form/add')
        response = self.app.get('/command/form/add')
        response.mustcontain(
            '<form class="form-horizontal" data-item="command" data-action="add" '
        )

        print('get page /command/parameters - bad parameters')
        response = self.app.get('/command/parameters', status=409)
        assert response.json == {'error': "the command 'None' does not exist"}
        response = self.app.get('/command/parameters?command=fake&elements_type=host', status=409)
        assert response.json == {'error': "the command 'fake' does not exist"}
        response = self.app.get('/command/parameters?command=process_host_check_result&elements_type=fake', status=409)
        assert response.json == {'error': "the plugin for 'fake' is not existing or not installed"}


        print('get page /command/parameters')
        response = self.app.get('/command/parameters?elements_type=host&command=process_host_check_result')
        expected = {
            "ls_state_id": {
                "allowed": {
                    "0": "Up", "1": "Down (1)", "2": "Not used (2)", "3": "Not used (3)", "4": "Unreachable"
                },
                "allowed_0": "Up",
                "allowed_1": "Down (1)",
                "allowed_2": "Not used (2)",
                "allowed_3": "Not used (3)",
                "allowed_4": "Unreachable",
                "comment": "Current state identifier. O: UP, 1: DOWN, 2/3: NOT USED, 4: UNREACHABLE",
                "default": 3,
                "title": "State identifier",
                "editable": True,
                "hidden": True,
                "type": "integer"
            },
            "ls_output": {
                "default": "Check output from WebUI",
                "type": "string",
                "title": "Output",
                "editable": True,
                "comment": "Last check output"
            },
            "ls_long_output": {
                "default": "",
                "type": "string",
                "title": "Long output",
                "editable": True,
                "visible": False,
                "comment": "Last check long output"
            },
            "ls_perf_data": {
                "default": "",
                "type": "string",
                "title": "Performance data",
                "editable": True,
                "visible": False,
                "comment": "Last check performance data"
            }
        }
        assert expected == response.json

        # Current user is admin
        session = response.request.environ['beaker.session']
        assert 'current_user' in session and session['current_user']
        assert session['current_user'].get_username() == 'admin'

        # Data manager
        datamgr = DataManager(alignak_webui.app.app, session=session)

        # Get host and user in the backend
        host = datamgr.get_host({'where': {'name': 'localhost'}})
        user = datamgr.get_user({'where': {'name': 'admin'}})

        # -------------------------------------------
        # Add a command
        # Missing or invalid parameters!
        data = {
            # "command": "test",
            "elements_type": 'host',
            "element_id": host.id
        }
        response = self.app.post('/command/add', data, status=400)
        print(response)

        # Unknown command
        data = {
            "command": "test",
            "elements_type": 'host',
            "element_id": host.id
        }
        response = self.app.post('/command/add', data, status=400)

        # Missing command parameter
        data = {
            "command": "process_host_check_result",
            "elements_type": 'host',
            "element_id": host.id
        }
        response = self.app.post('/command/add', data, status=400)

        # Command for an host
        data = {
            "command": "process_host_check_result",
            "elements_type": 'host',
            "element_id": host.id,
            "ls_state_id": '0',
            "ls_output": "New output...",
            "ls_long_output": "",
            "ls_perf_data": "",
        }
        response = self.app.post('/command/add', data, status=409)
        # As of #193...
        assert response.json['status'] == "ko"
        assert response.json['message'] == "Failed sending a command for localhost. "


if __name__ == '__main__':
    unittest.main()
