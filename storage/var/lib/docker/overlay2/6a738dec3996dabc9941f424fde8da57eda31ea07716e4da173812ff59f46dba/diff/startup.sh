#!/bin/bash

# # This file has to be UNIX line terminated (i.e. LF) otherwise you will get an obscure file not found error
# # Beware when editing in editors that might replace line endings with CR+LF, e.g. Visual Studio Code
PIDPATH="/var/run/pfc.pid"
PFC_EXIT_CODE=1

killNodeProcess() {
  PIDVAL=$(cat $PIDPATH)
  kill -$PFC_EXIT_CODE $PIDVAL
  if [ $? -eq 0 ]; then
    echo "Wait for process '$PIDVAL' to stop completely..."
    while [ ! -z "$(ps $PIDVAL | grep $PIDVAL)" ]; do sleep 0.1s; done;
    echo "Process '$PIDVAL' process stop successfully."
  else
    echo "Failed to send SIGTERM to PFC process $PIDVAL."
  fi
}
sendTermToNodeProcess() {
  echo "SIGTERM received. Sending SIGTERM to pfc process..."
  if [ -f "$PIDPATH" ]; then
    PFC_EXIT_CODE=15
    killNodeProcess
  else
    echo "PFC process not started."
  fi
}
sendIntToNodeProcess() {
  echo "SIGINT received. Sending SIGINT to pfc process $(cat $PIDPATH)..."
  if [ -f "$PIDPATH" ]; then
    PFC_EXIT_CODE=2
    killNodeProcess
  else
    echo "PFC process not started."
  fi
}
trap sendTermToNodeProcess 15 
trap sendIntToNodeProcess 2

if [ ! -d /storage/plugins ]; then
  mkdir -p /storage/plugins
fi

STORAGE_PICO_DIR_GROUP=`ls -la /storage | awk 'NR==2 {print $4}'`

# this is to ensure RSS tool has permission to transfer plugin files and folders to host /storage/pico/plugins
if [ "$STORAGE_PICO_DIR_GROUP" != "8888" ]; then
  chown -R 0:8888 /storage 
  chmod -R 775 /storage
fi

# make sure /appconfig existed first
if [ -d /appconfig ]; then
  # container /appconfig is mapped from the host /storage/pi/appconfig
  # plugins offline setup to /boot/appconfig path will be moved to /storage/pi/appconfig (when docker-compose service is running)
  # then /storage/pi/appconfig plugins will be moved into /storage/pico when this container is running (container: /storage)
  cd /appconfig
  cp -r * /storage/plugins/ 2> /dev/null
  rm -rf /appconfig/* 2> /dev/null

  # this is to check if /storage/plugins folder exist to be copied
  if [ -d /storage/plugins ]; then
    cd /storage/plugins

    # to read each plugin name folder in /storage/plugins
    for PLUGINDIR in */ ; do
      if [ "$PLUGINDIR" != "*/" ]; then
        # plugin existed in container
        if [ -d /plugins/$PLUGINDIR ]; then
          if [ "$PLUGINDIR" == "mes/" ] || [ "$PLUGINDIR" == "jemsco/" ]; then
            MSG="/plugins/$PLUGINDIR is system plugin!"
            echo "$MSG"
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $MSG" >> /plugins_update.log
          else
            cd /storage/plugins/$PLUGINDIR

            # to read each plugin filename in /storage/plugins
            for PLUGINNAME in ./*; do
              PLUGIN_NAME=`echo $PLUGINNAME | cut -c3-`

              # only for files
              if [ -f /storage/plugins/$PLUGINDIR$PLUGIN_NAME ]; then
                MD5SUM_SOURCEFILE=`md5sum /storage/plugins/$PLUGINDIR$PLUGIN_NAME | awk '{ print $1 }'`
                MD5SUM_DESTFILE=`md5sum /plugins/$PLUGINDIR$PLUGIN_NAME | awk '{ print $1 }'`

                # compare the source file md5 checsum and to compare the existing file md5 checksum
                if [ $MD5SUM_SOURCEFILE != $MD5SUM_DESTFILE ]; then
                  # replace the container's file if there is change found
                  cp /storage/plugins/$PLUGINDIR$PLUGIN_NAME /plugins/$PLUGINDIR$PLUGIN_NAME
                  MSG="Copied file: /storage/plugins/$PLUGINDIR$PLUGIN_NAME"
                  echo "$MSG"
                  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $MSG" >> /plugins_update.log
                fi
              fi
            done
          fi

          cd /storage/plugins
        else
          # plugin not found from container
          # copy the entire folder over /plugins/
          # if logic is to ensure all plugin necessary files are listed only then will be copied
          if [ -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.ico ] && [ -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.js ] && [ -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.md ] && [ -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.yaml ]; then
            cp -r /storage/plugins/$PLUGINDIR /plugins/$PLUGINDIR
            MSG="Copied path: /storage/plugins/$PLUGINDIR"
            echo "$MSG"
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $MSG" >> /plugins_update.log
          else
            # to display missing file from plugin name
            MSG=""

            if [ ! -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.ico ]; then
              MSG="Plugin ${PLUGINDIR%?} missing ico file..."
            fi

            if [ ! -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.js ]; then
              MSG="Plugin ${PLUGINDIR%?} missing js file..."
            fi

            if [ ! -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.md ]; then
              MSG="Plugin ${PLUGINDIR%?} missing md file..."
            fi

            if [ ! -f /storage/plugins/$PLUGINDIR${PLUGINDIR%?}.yaml ]; then
              MSG="Plugin ${PLUGINDIR%?} missing yaml file..."
            fi

            if [ "$MSG" != "" ]; then
              echo "$MSG"
              echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $MSG" >> /plugins_update.log
            fi
          fi
        fi
      fi
    done
    cd /
  fi
fi

cd /

# Start Pico
node /main.js &
echo $! > $PIDPATH
wait $(cat $PIDPATH)