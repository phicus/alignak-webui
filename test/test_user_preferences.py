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

from __future__ import print_function
import os
import json
import time
import shlex
import unittest2
import subprocess
# from gettext import gettext as _

from nose import with_setup
from nose.tools import *

# Set test mode ...
os.environ['ALIGNAK_WEBUI_TEST'] = '1'
os.environ['ALIGNAK_WEBUI_DEBUG'] = '1'
os.environ['ALIGNAK_WEBUI_CONFIGURATION_FILE'] = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'settings.cfg')
print ("Configuration file", os.environ['ALIGNAK_WEBUI_CONFIGURATION_FILE'])
# To load application configuration used by the objects
import alignak_webui.app

# from alignak_webui import webapp
from alignak_webui.backend.datamanager import DataManager

from webtest import TestApp

backend_process = None
backend_address = "http://127.0.0.1:5000/"


def setup_module(module):
    # Set test mode for applications backend
    os.environ['TEST_ALIGNAK_BACKEND'] = '1'
    os.environ['ALIGNAK_BACKEND_MONGO_DBNAME'] = 'alignak-backend-test'

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
        shlex.split('alignak-backend-import --delete %s/cfg/default/_main.cfg' % test_dir),
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


class tests_preferences(unittest2.TestCase):

    def setUp(self):
        # Test application
        self.app = TestApp(alignak_webui.app.session_app)

        response = self.app.get('/login')
        response.mustcontain('<form role="form" method="post" action="/login">')

        response = self.app.post('/login', {'username': 'admin', 'password': 'admin'})
        # Redirected twice: /login -> / -> /dashboard !
        redirected_response = response.follow()
        redirected_response = redirected_response.follow()
        session = redirected_response.request.environ['beaker.session']
        # A host cookie now exists
        assert self.app.cookies['Alignak-WebUI']
        # Get a data manager
        self.dmg = DataManager(alignak_webui.app.app, session=session)

    def tearDown(self):
        response = self.app.get('/logout')
        redirected_response = response.follow()
        redirected_response.mustcontain('<form role="form" method="post" action="/login">')

    def test_global_preferences(self):
        """ User preferences - global preferences """
        print('test global user preferences page')

        # /ping, still sends a status 200, but refresh is required
        response = self.app.get('/ping')
        # response.mustcontain('refresh')
        response = self.app.get('/ping?action=done')
        # response.mustcontain('pong')

        # Get user's preferences page
        response = self.app.get('/preferences/user')
        response.mustcontain(
            '<div id="user-preferences">',
            'admin',
            """<p class="username">
              Administrator
            </p>""",
            """<p class="usercategory">
               <small>administrator</small>
            </p>""",
            """<div class="user-header""",
            """<div class="user-body">""",
            """<table class="table table-condensed table-user-identification """,
            """<table class="table table-condensed table-user-preferences """,
            """No user preferences"""
        )

if __name__ == '__main__':
    unittest.main()
