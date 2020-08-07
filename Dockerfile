FROM kalka/steamcmd

ENV UID=1000
ENV GID=1000
ENV USER=gmod
ENV BETA=NONE
ENV GAMEMODE=sandbox
ENV PORT=27015

RUN sudo apt update && sudo apt -y install wget unzip libcurl3-dev && sudo apt clean

COPY ./docker-entrypoint.sh .

RUN sudo chmod +x ./docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]