process.on 'uncaughtException', (err) ->
  console.error(err)
  console.log(err.stack)
require './models'
require 'coffee-script/register'

require('./bot')