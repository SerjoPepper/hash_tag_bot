config = require './config'
locale = require './locale'
mongoose = require 'mongoose'
_ = require 'lodash'
bb = require 'bot-brother'
co = require 'co'

# кол-во сообщений, по прошествии которых, постим кнопку подписки
msgThrottleCount = 5
msgThrottleMemory = {}

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

messageHandler = co.wrap (message, isEdited) ->
  text = message.text
  chat = message.chat
  isPrivate = chat.type is 'private'
  Chat = mongoose.model('Chat')
  User = mongoose.model('User')
  return if !text || isPrivate || message.from.id is bot.id
  tags =  text.match(/#[^\s]+/ig)
  if tags?.length > 0 && !/^\s*#[^\s]+\s*$/ig.test(text)
    chat = yield Chat.findOneAsync(id: message.chat.id)
    chatData = { title: chat.title, id: chat.id, username: chat.username }
    unless chat
      chat = yield Chat.createAsync(chatData)
    else
      _.extend(chat, chatData)
      yield chat.saveAsync()
    chatTags = yield chat.addTags(tags, message.message_id)
    if !isEdited and (!msgThrottleMemory[chat.id] || msgThrottleMemory[chat.id] > msgThrottleCount)
      text = ''
      for chatTag in chatTags
        tag = chatTag.tag
        link = "telegram.me/#{config.bot.name}?start=#{chatTag._id}"
        text += "[Подписка на ##{tag}](#{link})\n"
      yield bot.api.sendMessage(chat.id, cleanSpaces(text), msgOptions)
      msgThrottleMemory[chat.id] = 1

    for tag in chatTags
      users = yield User.findAsync(subscriptions: tag._id)
      for user in users
        try yield bot.api.forwardMessage(user.id, chat.id, message.message_id)
  else if !isEdited and msgThrottleMemory[chat.id]
    msgThrottleMemory[chat.id]++

bot.api.on 'edited_message', (message) -> messageHandler(message, true)
bot.api.on 'message', (message) -> messageHandler(message, false)

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

# bot.command('show_tags').invoke (ctx) ->
#   return if ctx.private
#   chatTags = yield mongoose.model('ChatTag').findAsync(chat: ctx.chat._id)
#   unless chatTags?.length
#     yield ctx.sendMessage('group.no_tags')
#   else
#     ctx.data.tags = chatTags.map (chatTag) ->
#       tag: chatTag.tag
#       link: "telegram.me/#{config.bot.name}?start=#{chatTag._id}"
#     yield ctx.sendMessage(cleanSpaces(ctx.render('group.tags')), msgOptions)

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

