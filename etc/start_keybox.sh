#!/bin/bash

function relpath() { python3 -c "import os,sys;print(os.path.relpath(*(sys.argv[1:])))" "$@"; }

# Assure all external storage is in /apps/var

JETTY=$APPS_DIR/KeyBox-jetty/jetty
VAR_KEYDB=$VAR_DIR/keydb

# Assure all external storage and writable properties are in /apps/var

if [ ! -d $VAR_KEYDB ]; then
  cp -a $APPS_DIR/etc/keydb-dist $VAR_KEYDB
fi

# Reprocess templates unconditionally at startup since config may have changed.

source $APPS_DIR/etc/ssl_vars.inc # may be needed in these files

mkdir -p $VAR_DIR/config

VAR_KBCONFIG=$VAR_DIR/config/KeyBoxConfig.properties
VAR_SSLXML=$VAR_DIR/config/jetty-start.ini

tpl_envcp --overwrite $APPS_DIR/etc/KeyBoxConfig.properties.tpl $VAR_KBCONFIG
tpl_envcp --overwrite $APPS_DIR/etc/jetty-start.ini.tpl $VAR_SSLXML

# Now go ahead and fork off Jetty and keybox

cd $APPS_DIR/KeyBox-jetty/jetty
java -Xms1024m -Xmx1024m -jar start.jar &

sleep 1

if [ "$(jobs)" == "" ]; then
  wait $!
  joberror=$?
  echo "Keybox did not start. Exit code = $joberror"
  exit $joberror
fi

while [ "$ok" != "yes" -a "$1" != "-n" ]; do
  checkurl="https://localhost:8443"
  [ "$CONFIG_EXT_SSL_HOSTNAME" == "" ] && checkurl="http://localhost:8443"
  if [[ "$(wget -q -t 1 --no-check-certificate -O- $checkurl)" =~ /.*loginSubmit_auth.*/ ]]; then
    echo "Valid login page detected -- KeyBox looks ready"
    ok="yes"
  elif [ "$ok" == "nnnnnnn" ]; then
    echo "KeyBox did not respond with valid results after 7 seconds."
    [ "$(jobs)" != "" ] && kill %1
    exit 1
  else
    sleep 1
    ok="n$ok"
  fi
done  

echo PID file /tmp/keybox.pid created with PID $!
echo $! >/tmp/keybox.pid
disown -a
