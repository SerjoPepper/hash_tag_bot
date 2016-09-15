_ = require 'lodash'
path = require 'path'

module.exports = {
  bot:
    key: 'YOUR_KEY_HERE'
    name: 'hash_tag_bot'
  mongo:
    name: 'hash_tag_bot'
    host: '127.0.0.1'
    port: 27017
  redis:
    port: '6379',
    host: '127.0.0.1',
    options:
      db: 0
}

try
  _.merge(module.exports, require('./local'))
