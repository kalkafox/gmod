#!/bin/bash
#Set environment.

# Main binaries & their directories.
HOME_DIR=/home/steam
GAME_DIR=$HOME_DIR/$USER
GARRYSMOD_DIR=$GAME_DIR/garrysmod
ADDONS_DIR=$GARRYSMOD_DIR/addons
SRCDS_BIN=$GAME_DIR/srcds_run
SRCDS_BIN_64=$GAME_DIR/srcds_run_x64
STEAMCMD_BIN=/usr/games/steamcmd
PERMS=$@

# Logging

log() {
  echo "[ENTRYPOINT] [$(date "+%Y-%m-%d %H:%M:%S")] $*"
}

if [ -z $1 ]; then
  log "The script can have a parameter. Example: +gamemode sandbox +map gm_construct, etc..."
  PERMS="+gamemode sandbox +map gm_construct"
else
  PERMS="$@"
fi

permfix() {
  log "Changing permissions to $UID and $GID..."
  if [ $UID != 1000 ]; then
    sudo groupadd -g $GID $USER
    sudo useradd -m -u $UID -g $GID $USER
    sudo echo $USER' ALL=(ALL:ALL) NOPASSWD:ALL' > sudouser
    sudo echo 'steam ALL=(ALL:ALL) NOPASSWD:ALL' >> sudouser
    sudo cp -v sudouser /etc/sudoers.d
    sudo find $GAME_DIR ! -user $UID -exec sudo chown -c -R $UID:$GID {} \;
    sudo mv /home/steam/.steam /home/$USER/.steam
    SUDO="sudo -u $USER"
    log "Finished with permissions!"
  else
    USER=steam
    sudo find -D exec $GAME_DIR ! -user steam -exec sudo chown -c -R steam:steam {} \;
  fi
}

#Update function.
update() {
  log "Starting update."
  permfix
  if [ "$BETA" == "x86-64" ]; then
    log "Starting the update for 64-bit."
    $SUDO $STEAMCMD_BIN +login anonymous +force_install_dir $GAME_DIR +app_update 4020 -beta x86-64 validate +quit
  else
    log "Starting the update for stable version."
    $SUDO $STEAMCMD_BIN +login anonymous +force_install_dir $GAME_DIR +app_update 4020 -beta NONE validate +quit
  fi
  log "Update finished!"
  log "Checking if d_admin should be downloaded..."
}

d_admin_flag() {
  if [ "$D_ADMIN" ]; then
    log "d_admin is flagged to be downloaded!"
    log "**MAKE SURE YOU SET THE DATABASE PERMISSIONS CORRECTLY, OR D_ADMIN WILL NOT CONNECT TO THE DB!"
    if [ ! "$TOKEN" ]; then
      log "Installing d_admin requires you to have a token for GitLab to be able to read the repository. set it with -e TOKEN=<token>"
      exit
    fi
    if [ ! -d "$ADDONS_DIR/d_admin_config" ]; then
      $SUDO mkdir -p $ADDONS_DIR/d_admin_config/lua/da
      $SUDO git clone https://kalka:$TOKEN@git.globius.org/globius/d_admin.git -b dev $ADDONS_DIR/d_admin
      $SUDO cp $ADDONS_DIR/d_admin/lua/da/sv_config.lua.template $ADDONS_DIR/d_admin_config/lua/da/sv_config.lua
      log "Go to d_admin_config in the garrysmod addons directory and edit the file according to your settings, then relaunch the container."
      exit
    fi
    log "We need to download the reqs if it's not already there."
    $SUDO mkdir -p $GARRYSMOD_DIR/lua/bin
    if [ ! -f "$GARRYSMOD_DIR/lua/bin/gmsv_mysqloo_linux64.dll" ]; then
      $SUDO wget https://github.com/FredyH/MySQLOO/releases/download/9.6.1/gmsv_mysqloo_linux64.dll -P $GARRYSMOD_DIR/lua/bin
    fi
    $SUDO git clone https://kalka:$TOKEN@git.globius.org/globius/d_admin.git -b dev $ADDONS_DIR/d_admin
  else
    log "d_admin is not being downloaded. Moving on!"
  fi
}

64_bit_flag() {
  if [ "$BETA" == "x86-64" ]; then
    log "Using 64-bit for server..."
    if [ ! -d "$ADDONS_DIR/unixtermcol" ]; then
      $SUDO wget https://gitlab.kalka.io/srcds/unixtermcol/-/archive/master/unixtermcol-master.tar.gz -P $GARRYSMOD_DIR
      $SUDO tar -C $GARRYSMOD_DIR -zxvf $GARRYSMOD_DIR/unixtermcol-master.tar.gz
      $SUDO cp -R $GARRYSMOD_DIR/unixtermcol-master/{addons,lua} $GARRYSMOD_DIR
      $SUDO rm {$GARRYSMOD_DIR/unixtermcol-master,$GARRYSMOD_DIR/unixtermcol-master.tar.gz}
    fi
    if [ ! -f "$SRCDS_BIN_64" ]; then
      update
    fi
  else
    if [ -d "$ADDONS_DIR/unixtermcol" ]; then
      $SUDO rm {$GARRYSMOD_DIR/lua/bin/gmsv_xterm_x64.dll,$ADDONS_DIR/unixtermcol}
    fi
  fi
}

#Main function.
main() {
  log "Starting main function..."
  permfix
  d_admin_flag
  64_bit_flag
  if [ "$UPDATE" ]; then
    log "The server is flagged to be updated! Checking now."
    update
  fi

  MSG="Everything looks good! Starting ${USER^^} server with $PERMS"
  log $MSG
}

# tunnel into bash incase we need it
if [ "$1" == "/bin/bash" ]; then
  log "Tunneling to /bin/bash!"
  /bin/bash
  exit
fi

if [ -f "$SRCDS_BIN" ]; then
  log "${USER^^} detected! Proceeding with launch."
  main
else
  log "${USER^^} not detected! Starting update."
  update
  main
fi

if [ "$BETA" == "x86-64" ]; then
  SRCDS_BIN=$GAME_DIR/srcds_run_x64
fi

$SUDO $SRCDS_BIN -console $@
