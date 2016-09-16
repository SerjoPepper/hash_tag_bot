# - настройки бота в чате (фильтры и silent)
mongoose = require 'mongoose'
_ = require 'lodash'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId


schema = new Schema({

  id:
    type: Number
    index: true
  title: String
  username: String
  # Настройки чата
  settings:
    silent: Boolean
    filterTags: [String]

})

_.extend schema.methods, {

  # Добавляет существующие таги
  addTags: (tags, messageId) ->
    tags = _.uniq(tags.map((tag) -> tag.replace('#', '').trim().toLowerCase()))
    ChatTag = mongoose.model('ChatTag')
    chatTags = []
    for tag in tags
      chatTag = yield ChatTag.findOne({ chat: @_id, tag })
      if (!chatTag)
        chatTag = yield ChatTag.create({ chat: @, tag })
      chatTag.messages.push(messageId)
      chatTag.messages = _.uniq(chatTag.messages).slice(-50)
      yield chatTag.save()
      chatTags.push(chatTag)
    chatTags




}

mongoose.model('Chat', schema)
