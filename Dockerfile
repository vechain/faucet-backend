FROM node:22.6

COPY . .

RUN yarn install --frozen-lockfile

RUN yarn build

CMD yarn start
