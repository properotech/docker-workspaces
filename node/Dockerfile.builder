FROM node:12-alpine

LABEL \
    name="propero/workspace-node12" \
    description="... used during ci/cd of node based containers"

ENV URL_DOCKERIZE https://github.com/jwilder/dockerize/releases/download/v0.6.1/dockerize-alpine-linux-amd64-v0.6.1.tar.gz

RUN wget "$URL_DOCKERIZE" -O - | tar -C /usr/local/bin -xz

RUN apk update && apk add python make git && rm -rf /var/cache/apk/*
RUN git init

ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
WORKDIR /service
RUN chown node:node /service
USER node
RUN npm install -g sequelize-cli gulp-cli nodemon bunyan
# test github actions path match
