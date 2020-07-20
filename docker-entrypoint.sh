#!/bin/bash
#Set environment.

# Main binaries & their directories.
HOME_DIR=/home/steam
GAME_DIR=$HOME_DIR/$USER
GARRYSMOD_DIR=$GAME_DIR/garrysmod
ADDONS_DIR=$GARRYSMOD_DIR/addons
CSTRIKE_DIR=/opt/cstrike/cstrike
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

check_for_cstrike() {
  log "Checking if Counter-Strike: Source is available..."
  if [ -d $CSTRIKE_DIR ]; then
    log "Counter-Strike: Source has been detected! Mounting..."
    sudo echo '"mountcfg"{"cstrike" "'$CSTRIKE_DIR'"}' > mount.cfg
  else
    log "Counter-Strike: Source has not been detected. Will not mount."
    sudo echo '"mountcfg"{//"cstrike" "'$CSTRIKE_DIR'"}' > mount.cfg
  fi
  sudo mv mount.cfg $GARRYSMOD_DIR/cfg/mount.cfg
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
}

d_admin_flag() {
  log "Checking if d_admin should be downloaded..."
  if [ "$D_ADMIN" == "true" ]; then
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
  if [ -d "$ADDONS_DIR/d_admin_config" ] && [ "$TOKEN" ]; then
    log "d_admin is already detected, but let's update it to make sure."
    $SUDO git -C $ADDONS_DIR/d_admin pull
  fi
}

darkrp_flag() {
  if [ "$DARKRP" == "true" ]; then
    DARKRP_FLAG="+gamemode darkrp"
    if [ ! -d "$ADDONS_DIR/darkrp" ]; then
      log "Cloning DarkRP..."
      $SUDO git clone https://github.com/FPtje/DarkRP.git $ADDONS_DIR/darkrp
    fi
    if [ ! -d "$ADDONS_DIR/darkrpmod" ] || [ ! -d "$ADDONS_dir/darkrpmodification " ]; then
      log "Cloning DarkRP mod..."
      $SUDO git clone https://github.com/FPtje/darkrpmodification.git $ADDONS_DIR/darkrpmod
    fi
  fi
  if [ -d "$ADDONS_DIR/darkrp" ]; then
    DARKRP_FLAG="+gamemode darkrp"
    log "Let's make sure DarkRP is up to date."
    $SUDO git -C $ADDONS_DIR/darkrp pull
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
  check_for_cstrike
  permfix
  d_admin_flag
  64_bit_flag
  darkrp_flag
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

if [ "$PORT" != "27015" ]; then
  PORT_FLAG="-port $PORT"
fi

if [ "$IP" ]; then
  IP=$IP
fi

$SUDO $SRCDS_BIN -console $PORT_FLAG $IP $DARKRP_FLAG $@
