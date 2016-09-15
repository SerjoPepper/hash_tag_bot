# Пользователи
# subscriptions - здесь хранятся ChatTag
#

mongoose = require 'mongoose'
_ = require 'lodash'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId


schema = new Schema({

  # название тага
  id:
    type: Number
    index: true
  first_name: String
  last_name: String
  username: String

  # список с последними 100 сообщениями
  subscriptions: [{
    type: ObjectId
    ref: 'ChatTag'
    index: true
  }]

})

mongoose.model('User', schema)

