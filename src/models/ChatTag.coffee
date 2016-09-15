# хранит связку таг-канал
# в каждой сущности хранится до 100 последний сообщений
# у каждого chattag есть чат и таг :)
#

mongoose = require 'mongoose'
_ = require 'lodash'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId


schema = new Schema({

  # название тага
  tag:
    type: String
  chat:
    type: ObjectId
    ref: 'Chat'
    index: true

  # список с последними 100 сообщениями
  messages: [Number]

})

mongoose.model('ChatTag', schema)

