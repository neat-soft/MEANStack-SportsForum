# BurnZone Commenting System

## Installation

### Prerequisites

1. Linux, mandatory (Windows not officially supported)
2. [MongoDB](http://www.mongodb.org)
3. [nvm](https://github.com/creationix/nvm)
4. [Redis](http://redis.io/)
5. `nvm install 0.10`
6. `nvm use 0.10`
7. `make initial`

### Configuration

Configure host related options, port and database connection options in `server/config/development`.

Setup db indexes. In the project directory, run `mongo conversait ./scripts/mongo/indexes.js`.

### Compile client files

This step is needed to compile (.coffee->.js, .styl->.css) and concatenate source files. Just run:

`make all`

### Run server

`./script/run_server_dev.sh`
`./script/run_jobs_dev.sh`

### Test the setup

1. Point your browser to `http://<hostname>:<port>`
2. Sign up, create site named "test" using the base url `http://<hostname>:<port>`
3. Open `http://<hostname>:<port>/test/embedded`

## Structure

There's one directory in `./client` for each client application. 

`./shared/` contains code that can be run on the server as well as on the client. All files in `./shared/` are copied under `./client/<client app>/app/lib/shared` whenever necessary. This is the way we're sharing code between the client and the backend.

Everything in `./client/common` (models, collections, vendor scripts, shared views and helpers) is merged with `./client/<client app>` whenever necessary - currently with `./client/moderator` and `./client/embedded`. As a consequence, you have to edit the files (most often models and collections) in the common directory and not those in specific client directories.
