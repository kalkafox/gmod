FROM kalka/steamcmd

ENV UID=1000
ENV GID=1000
ENV USER=gmod

COPY ./docker-entrypoint.sh .

RUN sudo chmod +x ./docker-entrypoint.sh

ENTRYPOINT ["./docker-entrypoint.sh"]