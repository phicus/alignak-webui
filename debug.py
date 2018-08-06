#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import alignak_webui.app


os.environ["ALIGNAK_WEBUI_DEBUG"]="1"
os.environ["BOTTLE_DEBUG"]="1"

if not os.environ.get("ALIGNAK_WEBUI_CONFIGURATION_FILE"):
    os.environ["ALIGNAK_WEBUI_CONFIGURATION_FILE"]="/usr/local/etc/alignak-webui/settings-debug.cfg"
if not os.environ.get("ALIGNAK_WEBUI_BACKEND"):
    os.environ["ALIGNAK_WEBUI_BACKEND"]="http://127.0.0.1:5000"
if not os.environ.get("ALIGNAK_WEBUI_WS"):
    os.environ["ALIGNAK_WEBUI_WS"]="http://127.0.0.1:7770"
if not os.environ.get("ALIGNAK_WEBUI_LOG"):
    os.environ["ALIGNAK_WEBUI_LOG"]="/usr/local/var/log/alignak-webui"
if not os.environ.get("ALIGNAK_WEBUI_LOGGER_FILE"):
    os.environ["ALIGNAK_WEBUI_LOGGER_FILE"]="/usr/local/etc/alignak-webui/logging.json"

alignak_webui.app.main()
