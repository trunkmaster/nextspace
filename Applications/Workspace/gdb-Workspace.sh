#!/bin/sh
gdb /usr/NextSpace/Apps/Workspace.app/Workspace `ps auxw|grep Workspace|grep -v grep|awk -c '{print $2}'`
