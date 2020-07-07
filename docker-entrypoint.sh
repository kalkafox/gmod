#!/bin/bash
#Set environment.

# Main binaries & their directories.
HOME_DIR=/home/steam
GAME_DIR=$HOME_DIR/$USER
GARRYSMOD_DIR=$GAME_DIR/garrysmod
ADDONS_DIR=$GARRYSMOD_DIR/addons
SRCDS_BIN=$GAME_DIR/srcds_run
STEAMCMD_BIN=/usr/games/steamcmd
PERMS=$@

# Server version.

touch server_version

VERSION=$(head -n 1 server_version)

# Logging
TIME=`date "+%Y-%m-%d %H:%M:%S"`
LOG="[Entrypoint] [$TIME]"

if [ -z $1 ]; then
  echo "$LOG The script can have a parameter. Example: +gamemode sandbox +map gm_construct, etc..."
  PERMS="+gamemode sandbox +map gm_construct"
else
  PERMS="$@"
fi

function permfix {
  echo "$LOG Changing permissions to $UID and $GID..."
  if [ $UID != 1000 ]; then
    sudo groupadd -g $GID $USER
    sudo useradd -m -u $UID -g $GID $USER
    sudo echo $USER' ALL=(ALL:ALL) NOPASSWD:ALL' > sudouser
    sudo echo 'steam ALL=(ALL:ALL) NOPASSWD:ALL' >> sudouser
    sudo cp sudouser /etc/sudoers.d
    sudo find $GAME_DIR ! -user $UID -exec sudo chown -R $UID:$GID {} \;
    sudo find $HOME_DIR/.steam ! -user $UID -exec sudo chown -R $UID:$GID {} \;
    echo "$LOG Finished with permissions!"
  else
    sudo chown -R steam:steam {$GAME_DIR,$HOME_DIR/.steam}
  fi
}

#Update function.
function update {
  echo "$LOG Starting update."
  permfix
  sudo -u $USER $STEAMCMD_BIN +login anonymous +force_install_dir $GAME_DIR +app_update 4020 -beta $BETA +quit
  if [ "$BETA" == "x86_64" ]; then
    echo $BETA > server_version
    VERSION=$(head -n 1 server_version)
    echo "$LOG Server version is now $BETA"
  else
    echo $BETA > server_version
    VERSION=$(head -n 1 server_version)
    echo "$LOG Server version is now NONE -- only x86_64 is supported for now."
  fi
  echo "$LOG Update finished!"
  echo "$LOG Checking if d_admin should be downloaded..."
  if [ "$D_ADMIN" == "true" ]; then
    echo "$LOG d_admin is flagged to be downloaded!"
    git clone https://kalka:sg1Cekq_4scyUFMyjzFT@git.globius.org/globius/d_admin.git -b dev $ADDONS_DIR/d_admin
  else
    echo "$LOG d_admin is not being downloaded. Moving on!"
  fi
}


#Main function.
function main {
  echo "$LOG Starting main function..."
  permfix
  if [ "$UPDATE" ]; then
    echo "$LOG The server is flagged to be updated! Checking now."
    update
  fi
  if [ "$BETA" == "x86_64" ]; then
    echo "$LOG The server is flagged to be 64-bit. Starting that now."
    if [ "$VERSION" == "NONE" ]; then
      echo "$LOG The previous version was NONE, so we're forcing an update."
      update
    fi
  else
    echo "$LOG Just checking if the server is still 64-bit."
    if [ "$VERSION" == "x86_64" ]; then
      echo "$LOG The previous version was 64-bit, so we're forcing an update."
      update
    fi
  fi
  MSG="Everything looks good! Starting ${USER^^} server with $PERMS"
  echo $LOG $MSG
}

# tunnel into bash incase we need it
if [ $1 == "/bin/bash" ]; then
  echo "$LOG Tunneling to /bin/bash!"
  /bin/bash
  exit
fi

if [ -f "$SRCDS_BIN" ]; then
  echo "$LOG ${USER^^} detected! Proceeding with launch."
  main
else
  echo "$LOG ${USER^^} not detected! Starting update."
  update
  main
fi

sudo -u $USER $SRCDS_BIN -console $@
