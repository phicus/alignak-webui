#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Many functions need to use protected members of a base class
# pylint: disable=protected-access
# Attributes need to be defined in constructor before initialization
# pylint: disable=attribute-defined-outside-init

# Copyright (c) 2015-2016:
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

"""
    This module contains the classes used to manage the application objects with the data manager.
"""

from logging import getLogger, INFO

# Import the backend interface class

# Set logger level to INFO, this to allow global application DEBUG logs without being spammed... ;)
from alignak_webui.objects.element import Element

logger = getLogger(__name__)
logger.setLevel(INFO)


class TimePeriod(Element):
    """
    Object representing a timeperiod
    """
    _count = 0
    # Next value used for auto generated id
    _next_id = 1
    # _type stands for Backend Object Type
    _type = 'timeperiod'
    # _cache is a list of created objects
    _cache = {}

    def __new__(cls, params=None, date_format='%a, %d %b %Y %H:%M:%S %Z'):
        """
        Create a new user
        """
        return super(TimePeriod, cls).__new__(cls, params, date_format)

    def _create(self, params, date_format):
        """
        Create a timeperiod (called only once when an object is newly created)
        """
        super(TimePeriod, self)._create(params, date_format)

    def _update(self, params=None, date_format='%a, %d %b %Y %H:%M:%S %Z'):
        """
        Update a timeperiod (called every time an object is updated)
        """
        super(TimePeriod, self)._update(params, date_format)

    def __init__(self, params=None):
        """
        Initialize a timeperiod (called every time an object is invoked)
        """
        super(TimePeriod, self).__init__(params)

    @property
    def endpoint(self):
        """
        Overload default property. Link to the main objects page with an anchor.
        """
        return '/%ss#%s' % (self.object_type, self.id)
