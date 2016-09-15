mongoose = require('mongoose')
promise = require 'bluebird'
config = require '../config'
promise.promisifyAll(mongoose)

mongoose.connect("mongodb://#{config.mongo.host}:#{config.mongo.port}/#{config.mongo.name}")

require './User'
require './Chat'
require './ChatTag'
