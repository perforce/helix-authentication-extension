#!/bin/bash
#
# Script for redeploying the extension, replacing whatever was installed
# previously, retaining the existing configuration.
#

rm -f loginhook.p4-extension
p4 -u $P4USER -p $P4PORT extension --package loginhook
EXISTS=$(p4 -p "$P4PORT" -u "$P4USER" extension --list --type=extensions)
if [[ "${EXISTS}" =~ 'Auth::loginhook' ]]; then
    GLOBAL_CFG=$(mktemp)
    p4 -u $P4USER -p $P4PORT extension --configure Auth::loginhook -o > $GLOBAL_CFG
    INSTANCE_CFG=$(mktemp)
    p4 -u $P4USER -p $P4PORT extension --configure Auth::loginhook --name loginhook-a1 -o > $INSTANCE_CFG
    p4 -u $P4USER -p $P4PORT extension --delete Auth::loginhook --yes
    p4 -u $P4USER -p $P4PORT extension --install loginhook.p4-extension -y
    p4 -u $P4USER -p $P4PORT extension --configure Auth::loginhook -i < $GLOBAL_CFG
    p4 -u $P4USER -p $P4PORT extension --configure Auth::loginhook --name loginhook-a1 -i < $INSTANCE_CFG
    rm -f $GLOBAL_CFG
    rm -f $INSTANCE_CFG
else
    p4 -u $P4USER -p $P4PORT extension --delete Auth::loginhook --yes
    p4 -u $P4USER -p $P4PORT extension --install loginhook.p4-extension -y
    p4 -u $P4USER -p $P4PORT extension --configure Auth::loginhook
    p4 -u $P4USER -p $P4PORT extension --configure Auth::loginhook --name loginhook-a1
fi
