FROM kalka/steamcmd

ENV UID=1000
ENV GID=1000
ENV USER=gmod
ENV BETA=NONE

RUN sudo apt update && sudo apt -y install wget unzip && sudo apt clean

COPY ./docker-entrypoint.sh .

RUN sudo chmod +x ./docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]