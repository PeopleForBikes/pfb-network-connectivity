FROM node:8.15-stretch-slim

ENV BASE_DIR /opt/pfb/tilegarden

# Install git for git dependencies
RUN apt-get update -y
RUN apt-get install git jq -y
RUN yarn global add carto

# Copy files needed for installing packages first
COPY package.json yarn.lock ${BASE_DIR}/
WORKDIR ${BASE_DIR}/

# install node modules
RUN yarn install

# Copy remaining files after package installation to benefit from layer caching
COPY . ${BASE_DIR}/

CMD ["yarn", "dev"]
