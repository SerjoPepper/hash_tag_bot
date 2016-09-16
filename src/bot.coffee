config = require './config'
locale = require './locale'
mongoose = require 'mongoose'
_ = require 'lodash'
bb = require 'bot-brother'

msgOptions = { parse_mode: 'Markdown', disable_web_page_preview: true }
cleanSpaces = (text) -> text.replace(/^\s*[\r\n]/gm, '').replace(/^\s+/gm, '')

bot = module.exports = bb({
  key: config.bot.key
  sessionManager: bb.sessionManager.redis(config.redis)
  webHook: config.bot.webHook
  polling: config.bot.polling
})
.texts(locale.ru, {locale: 'ru'})
.texts(locale.ru)

bot.api.on 'edited_message', (message) ->
  text = message.text
  isPrivate = message.chat.type is 'private'
  Chat = mongoose.model('Chat')
  User = mongoose.model('User')
  return if !text || isPrivate
  tags =  text.match(/#[^\s]+/ig)
  if tags?.length > 0
    chat = yield Chat.findOneAsync(id: message.chat.id)
    return unless chat
    chatTags = yield chat.addTags(tags, message.message_id)
    for tag in chatTags
      users = yield User.findAsync(subscriptions: tag._id)
      for user in users
        try yield bot.api.forwardMessage(user.id, message.chat.id, message.message_id)

bot.use 'before', (ctx) ->
  chat = ctx.meta.chat
  ctx.private = chat.type is 'private'
  Chat = mongoose.model('Chat')
  User = mongoose.model('User')
  if !ctx.private
    ctx.usePrevKeyboard()
  else
    ctx.keyboard([
      [{ 'keyboard.subscriptions': go: 'subscriptions' }]
      [{ 'keyboard.group': go: 'add_to_group' }]
    ])
  if !ctx.private and ctx.meta.user.id != ctx.bot.id
    tags =  ctx.answer?.match(/#[^\s]+/ig)
    if tags?.length > 0
      chat = yield Chat.findOneAsync(id: chat.id)
      unless chat
        chat = yield Chat.createAsync({ title: chat.title, id: chat.id, username: chat.username })
      chatTags = yield chat.addTags(tags, ctx.message.message_id)
      if !chat.settings.silent && chatTags?.length
        for chatTag in chatTags
          ctx.data.tag = chatTag.tag
          ctx.data.link = "telegram.me/#{config.bot.name}?start=#{chatTag._id}"
          yield ctx.sendMessage('group.tag_added', msgOptions)
      for tag in chatTags
        users = yield User.findAsync(subscriptions: tag._id)
        for user in users
          try yield ctx.bot.api.forwardMessage(user.id, chat.id, ctx.message.message_id)
          # TODO forward message


bot.use 'beforeInvoke', (ctx) ->
  chat = ctx.meta.chat
  user = ctx.meta.user
  Chat = mongoose.model('Chat')
  User = mongoose.model('User')
  unless ctx.private
    ctx.chat = yield Chat.findOneAsync(id: chat.id)
    chatData = { title: chat.title, id: chat.id, username: chat.username }
    unless ctx.chat
      ctx.chat = yield Chat.createAsync(chatData)
    else
      _.extend(ctx.chat, chatData)
      yield ctx.chat.saveAsync()
  else
    ctx.user = yield User.findOne(id: user.id).populate('subscriptions').execAsync()
    unless ctx.user
      ctx.user = yield User.createAsync(user)
    else
      _.extend(ctx.user, user)
      yield ctx.user.saveAsync()
    ctx.data.user = ctx.user


bot.command('start').invoke (ctx) ->
  if ctx.private
    id = try
      ctx.args[0] && mongoose.Types.ObjectId(ctx.args[0])
    if id
      ctx.data.chatTag = chatTag = yield mongoose.model('ChatTag').findByIdAsync(id)
      unless _.find(ctx.user.subscriptions, (s) -> s._id.equals(id))
        ctx.user.subscriptions.push(chatTag)
      yield ctx.user.saveAsync()
      yield ctx.sendMessage('user.subscribe')
    else
      yield ctx.sendMessage('user.start')
  else
    yield ctx.sendMessage('group.start')

bot.command('show_tags').invoke (ctx) ->
  return if ctx.private
  chatTags = yield mongoose.model('ChatTag').findAsync(chat: ctx.chat._id)
  unless chatTags?.length
    yield ctx.sendMessage('group.no_tags')
  else
    ctx.data.tags = chatTags.map (chatTag) ->
      tag: chatTag.tag
      link: "telegram.me/#{config.bot.name}?start=#{chatTag._id}"
    yield ctx.sendMessage(cleanSpaces(ctx.render('group.tags')), msgOptions)

# TODO
bot.command('silent').invoke (ctx) ->
  return if ctx.private

# TODO
bot.command('disable_filter').invoke (ctx) ->
  return if ctx.private

# TODO
bot.command('enable_filter').invoke (ctx) ->
  return if ctx.private


bot.command('subscriptions').invoke (ctx) ->
  return unless ctx.private
  for chatTag in ctx.user.subscriptions
    yield chatTag.populate('chat').execPopulate()
  ctx.data.chatTags = ctx.user.subscriptions
  yield ctx.sendMessage('user.subscriptions')

bot.command('add_to_group').invoke (ctx) ->
  return unless ctx.private
  yield ctx.sendMessage('user.group', { disable_web_page_preview: true })

bot.command('remove').invoke (ctx) ->
  return unless ctx.private
  id = try
    ctx.args[0] && mongoose.Types.ObjectId(ctx.args[0])
  return unless id
  ctx.user.subscriptions = _.reject(ctx.user.subscriptions, (s) -> s._id.equals(id))
  yield ctx.user.saveAsync()
  yield ctx.sendMessage('common.done')

bot.command('show').invoke (ctx) ->
  return unless ctx.private
  id = try
    ctx.args[0] && mongoose.Types.ObjectId(ctx.args[1])
  count = Number(ctx.args[0])
  return if !id || isNaN(count)
  chatTag = _.find(ctx.user.subscriptions, (s) -> s._id.equals(id))
  yield chatTag.populate('chat').execPopulate()
  for message in chatTag.messages.slice(-count)
    try yield ctx.forwardMessage(chatTag.chat.id, message)

