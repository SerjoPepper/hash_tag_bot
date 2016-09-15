fs = require 'fs'
yaml = require 'js-yaml'
config = require '../config'
localeDir = __dirname

fs.readdirSync(localeDir).forEach (file) ->
  arr = file.split('.')
  if arr[1] == 'yaml'
    module.exports[arr[0]] = yaml.load(fs.readFileSync(localeDir + '/' + file).toString())
