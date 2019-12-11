FROM node:12-stretch-slim
LABEL \
    name="propero/infrastructure" \
    description="... base image for node microservice"

ENV NPM_CONFIG_LOGLEVEL=info
ENV VER_DUMB_INIT=1.2.2
ENV VER_DOCKERIZE=0.6.1
ENV URL_DUMBINIT=https://github.com/Yelp/dumb-init/releases/download/v${VER_DUMB_INIT}/dumb-init_${VER_DUMB_INIT}_amd64.deb
ENV URL_DOCKERIZE=https://github.com/jwilder/dockerize/releases/download/v${VER_DOCKERIZE}/dockerize-linux-amd64-v${VER_DOCKERIZE}.tar.gz

RUN npm --silent install -g sequelize-cli gulp-cli nodemon bunyan \
    && mkdir -p /service \
    && wget $URL_DUMBINIT && dpkg -i dumb-init_*.deb \
    && wget $URL_DOCKERIZE >/dev/null \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-v${VER_DOCKERIZE}.tar.gz \
    && rm -rf dumb-init_*.deb dockerize-linux-amd64-v${VER_DOCKERIZE}.tar.gz
