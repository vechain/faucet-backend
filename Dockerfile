FROM node:22.6

COPY . .

RUN yarn install --frozen-lockfile

RUN yarn build

# Expose the port that the application listens on.
EXPOSE 80

CMD yarn start
