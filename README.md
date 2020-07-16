
# kalka/gmod

### Usage & Installation
Pull the image from the Docker Hub like so:
* `docker pull kalka/gmod`
To run without a volume, simply:
* `docker run --rm -it kalka/gmod +map gm_construct`
Here's the breakdown of this command:
	* `--rm` Removes the container after it has been exited automatically. If you wish to have the container persist, remove this flag.
	* `-it` Enables interactive mode. If you are wanting the console to print in STDOUT, you MUST have this flag, or you will lock yourself out of your terminal. An alternative flag to daemonize the container is done with `-d`
	* **Important**: At the end of `kalka/gmod` is where the container will begin to listen for regular SRCDS parameters. This is where you would put your GSLT token, workshop collection ID, etc.
### Environment Variables
* `D_ADMIN` Set with `-e D_ADMIN=true`. Downloads d_admin directly from Globius GitLab. You NEED a token with the permission `read_repository` set for this to work. Set the token with `-e TOKEN=<token>`.
* `UID & GID` Set with `-e UID=$(id -u) -e GID=$(id -g)`. If your UID/GID is not set to 1000 on the host level, set these, otherwise the container will fail to run due to permissions.
* `UPDATE` Set this if you want to force an update.
* `BETA` Set with `-e BETA=x86-64`. Allows the Garry's Mod server to be in 64-bit. The only value that works is just `x86-64`.
* `PORT` Set with `-e PORT=<port>`. Use this if you are intending to use a custom port.

### Volumes
To allow the server to persist, run the docker run command with `-v path/to/dir:/home/steam/gmod`

### Counter-Strike: Source
To install Counter-Strike: Source into the server, do the following:
* Run `docker volume create cstrike` - This will create a volume where we will download Counter Strike: Source's resources.
* Run `docker run --rm -it -v cstike:/opt/cstrike kalka/css:base`
* Once it has finished, mount the `cstrike` volume with `-v cstrike:/opt/cstrike/cstrike` in the docker run command.

### Networking (IMPORTANT)
OK, so this is where it can get a bit complicated sometimes. If you are running a system with multiple IPs, the way SRCDS connects to Steam servers is via the main IP and that one only, as opposed to an alternative one. This would be fixable by running `-p <alternate:ip>:27015:27015` (breakdown: `-p <ip>:host_listen_port:container_listen_port` [more info here](https://docs.docker.com/engine/tutorials/networkingcontainers/)) but SRCDS seems to ignore it. If you want the server to listen on an alternative IP:
* Add `-net="host"` in the docker run command
* Add `-ip <ip>` at the end of the docker run command after `kalka/gmod`
* (Optional) Add`-port <port>/udp` at the end of the docker run command after `kalka/gmod`
	* To use RCON for localhost only, we add the following: `-port 127.0.0.1:27015:27015/tcp` USE LOCAL IP ADDRESSES FOR RCON ONLY.

**NOTE:** If you are using the host network instead, **follow the proper SRCDS security guidelines.** Do not ever expose RCON to TCP. Only forward the public IP with the UDP protocol.

### Run Command
Here is the full run command for everything:

#### With Docker Networking
```bash
#!/bin/bash
mkdir -p $(pwd)/gmod
docker run --rm -it \
	--name=gmod \
	-v $(pwd)/gmod:/home/steam/gmod \
	-e UID=$(id -u) \
	-e GID=$(id -g) \
	-e D_ADMIN=true \
	-e TOKEN=<token> \
	-e BETA=x86-64 \
	-p 27015:27015/udp \
	kalka/gmod +gamemode sandbox +map gm_construct +sv_setsteamaccount <your GLST token>
```

#### With Host Networking
```bash
#!/bin/bash
mkdir -p $(pwd)/gmod
docker run --rm -it \
	--name=gmod \
	--network=host \
	-v $(pwd)/gmod:/home/steam/gmod \
	-e UID=$(id -u) \
	-e GID=$(id -g) \
	-e D_ADMIN=true \
	-e TOKEN=<token> \
	-e BETA=x86-64 \
	-e IP=0.0.0.0 \
	-e PORT=27016 \
	kalka/gmod -ip <ip> +gamemode sandbox +map gm_construct +sv_setsteamaccount <your GLST token>
```
