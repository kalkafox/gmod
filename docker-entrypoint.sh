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
TIME=`date "+%Y-%m-%d %H:%M:%S"`
LOG="[Entrypoint] [$(echo $TIME)]"

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
    sudo cp -R /home/steam/.steam /home/$USER/.steam
    SUDO="sudo -u $USER"
    echo "$LOG Finished with permissions!"
  else
    USER=steam
    sudo chown -R steam:steam {$GAME_DIR,$HOME_DIR/.steam}
  fi
}

#Update function.
function update {
  echo "$LOG Starting update."
  permfix
  if [ "$BETA" == "x86-64" ]; then
    echo "$LOG Starting the update for 64-bit."
    $SUDO $STEAMCMD_BIN +login anonymous +force_install_dir $GAME_DIR +app_update 4020 -beta x86-64 +quit
  else
    echo "$LOG Starting the update for stable version."
    $SUDO $STEAMCMD_BIN +login anonymous +force_install_dir $GAME_DIR +app_update 4020 -beta NONE +quit
  fi
  echo "$LOG Update finished!"
  echo "$LOG Checking if d_admin should be downloaded..."
}


#Main function.
function main {
  echo "$LOG Starting main function..."
  permfix
  if [ "$D_ADMIN" ]; then
    echo "$LOG d_admin is flagged to be downloaded!"
    echo "$LOG **MAKE SURE YOU SET THE DATABASE PERMISSIONS CORRECTLY, OR D_ADMIN WILL NOT CONNECT TO THE DB!"
    if [ ! "$TOKEN" ]; then
      echo "$LOG Installing d_admin requires you to have a token for GitLab to be able to read the repository. set it with -e TOKEN=<token>"
      exit
    fi
    if [ ! -d "$ADDONS_DIR/d_admin_config" ]; then
      $SUDO mkdir -p $ADDONS_DIR/d_admin_config/lua/da
      $SUDO git clone https://kalka:$TOKEN@git.globius.org/globius/d_admin.git -b dev $ADDONS_DIR/d_admin
      $SUDO cp $ADDONS_DIR/d_admin/lua/da/sv_config.lua.template $ADDONS_DIR/d_admin_config/lua/da/sv_config.lua
      echo "$LOG Go to d_admin_config in the garrysmod addons directory and edit the file according to your settings, then relaunch the container."
      exit
    fi
    echo "$LOG We need to download the reqs if it's not already there."
    $SUDO mkdir -p $GARRYSMOD_DIR/lua/bin
    if [ ! -f "$GARRYSMOD_DIR/lua/bin/gmsv_mysqloo_linux64.dll" ]; then
      $SUDO wget https://github.com/FredyH/MySQLOO/releases/download/9.6.1/gmsv_mysqloo_linux64.dll -P $GARRYSMOD_DIR/lua/bin
    fi
    $SUDO git clone https://kalka:$TOKEN@git.globius.org/globius/d_admin.git -b dev $ADDONS_DIR/d_admin
  else
    echo "$LOG d_admin is not being downloaded. Moving on!"
  fi
  if [ "$UPDATE" ]; then
    echo "$LOG The server is flagged to be updated! Checking now."
    update
  fi
  if [ "$BETA" == "x86-64" ]; then
    echo "$LOG Using 64-bit for server..."
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

  MSG="Everything looks good! Starting ${USER^^} server with $PERMS"
  echo $LOG $MSG
}

# tunnel into bash incase we need it
if [ "$1" == "/bin/bash" ]; then
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

if [ "$BETA" == "x86-64" ]; then
  SRCDS_BIN=$GAME_DIR/srcds_run_x64
fi

$SUDO $SRCDS_BIN -console $@
