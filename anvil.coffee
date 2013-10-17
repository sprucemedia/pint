###
Anvil.coffee MVC library
Released under the MIT License
###

Events =
  bind: (ev, callback) ->
    evs   = ev.split(' ')
    calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}
    for name in evs
      calls[name] or= []
      calls[name].push(callback)
    this

  one: (ev, callback) ->
    @bind ev, handler = ->
      @unbind(ev, handler)
      callback.apply(this, arguments)

  trigger: (args...) ->
    ev = args.shift()
    list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
    return unless list
    for callback in list
      if callback.apply(this, args) is false
        break
    true

  listenTo: (obj, ev, callback) ->
    obj.bind(ev, callback)
    @listeningTo or= []
    @listeningTo.push {obj, ev, callback}
    this

  listenToOnce: (obj, ev, callback) ->
    listeningToOnce = @listeningToOnce or = []
    obj.bind ev, handler = ->
      idx = -1
      for lt, i in listeningToOnce when lt.obj is obj
        idx = i if lt.ev is ev and lt.callback is callback
      obj.unbind(ev, handler)
      listeningToOnce.splice(idx, 1) unless idx is -1
      callback.apply(this, arguments)
    listeningToOnce.push {obj, ev, callback, handler}
    this

  stopListening: (obj, events, callback) ->
    if arguments.length is 0
      for listeningTo in [@listeningTo, @listeningToOnce]
        continue unless listeningTo
        for lt in listeningTo
          lt.obj.unbind(lt.ev, lt.handler or lt.callback)
      @listeningTo = undefined
      @listeningToOnce = undefined

    else if obj
      for listeningTo in [@listeningTo, @listeningToOnce]
        continue unless listeningTo
        events = if events then events.split(' ') else [undefined]
        for ev in events
          for idx in [listeningTo.length-1..0]
            lt = listeningTo[idx]
            if (not ev) or (ev is lt.ev)
              lt.obj.unbind(lt.ev, lt.handler or lt.callback)
              listeningTo.splice(idx, 1) unless idx is -1
            else if ev
              evts = lt.ev.split(' ')
              if ev in evts
                evts = (e for e in evts when e isnt ev)
                lt.ev = $.trim(evts.join(' '))
                lt.obj.unbind(ev, lt.handler or lt.callback)

  unbind: (ev, callback) ->
    if arguments.length is 0
      @_callbacks = {}
      return this
    return this unless ev
    evs = ev.split(' ')
    for name in evs
      list = @_callbacks?[name]
      continue unless list
      unless callback
        delete @_callbacks[name]
        continue
      for cb, i in list when (cb is callback)
        list = list.slice()
        list.splice(i, 1)
        @_callbacks[name] = list
        break
    this

Events.on = Events.bind
Events.off = Events.unbind

moduleKeywords = ['included', 'extended']

class Module
  @include: (obj) ->
    throw new Error('include(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @::[key] = value
    obj.included?.apply(this)
    this

  @extend: (obj) ->
    throw new Error('extend(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @[key] = value
    obj.extended?.apply(this)
    this

  @proxy: (func) ->
    => func.apply(this, arguments)

  proxy: (func) ->
    => func.apply(this, arguments)

  constructor: ->
    @init?(arguments...)

class Controller extends Module
  @include Events

  eventSplitter: /^(\S+)\s*(.*)$/
  tag: 'div'

  constructor: (options) ->
    @options = options

    for key, value of @options
      @[key] = value

    @el  = document.createElement(@tag) unless @el
    @el  = $(@el)
    @$el = @el

    @el.addClass(@className) if @className
    @el.attr(@attributes) if @attributes

    @events = @constructor.events unless @events
    @elements = @constructor.elements unless @elements

    context = @
    while parent_prototype = context.constructor.__super__
      @events = $.extend({}, parent_prototype.events, @events) if parent_prototype.events
      @elements = $.extend({}, parent_prototype.elements, @elements) if parent_prototype.elements
      context = parent_prototype

    @delegateEvents(@events) if @events
    @refreshElements() if @elements

    super

  release: =>
    @trigger 'release', this
    # no need to unDelegateEvents since remove will end up handling that
    @el.remove()
    @unbind()
    @stopListening()

  $: (selector) -> $(selector, @el)

  delegateEvents: (events) ->
    for key, method of events

      if typeof(method) is 'function'
        # Always return true from event handlers
        method = do (method) => =>
          method.apply(this, arguments)
          true
      else
        unless @[method]
          throw new Error("#{method} doesn't exist")

        method = do (method) => =>
          @[method].apply(this, arguments)
          true

      match      = key.match(@eventSplitter)
      eventName  = match[1]
      selector   = match[2]

      if selector is ''
        @el.bind(eventName, method)
      else
        @el.on(eventName, selector, method)

  refreshElements: ->
    for key, value of @elements
      @[value] = @$(key)

  delay: (func, timeout) ->
    setTimeout(@proxy(func), timeout || 0)

  # keep controllers elements obj in sync with it contents

  html: (element) ->
    @el.html(element.el or element)
    @refreshElements()
    @el

  append: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.append(elements...)
    @refreshElements()
    @el

  appendTo: (element) ->
    @el.appendTo(element.el or element)
    @refreshElements()
    @el

  prepend: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.prepend(elements...)
    @refreshElements()
    @el

  replace: (element) ->
    element = element.el or element
    element = $.trim(element) if typeof element is "string"
    # parseHTML is incompatible with Zepto
    [previous, @el] = [@el, $($.parseHTML(element)?[0] or element)]
    previous.replaceWith(@el)
    @delegateEvents(@events)
    @refreshElements()
    @el

# Utilities & Shims

$ = window?.jQuery or window?.Zepto or (element) -> element

createObject = Object.create or (o) ->
  Func = ->
  Func.prototype = o
  new Func()

isArray = (value) ->
  Object::toString.call(value) is '[object Array]'

isBlank = (value) ->
  return true unless value
  return false for key of value
  true

makeArray = (args) ->
  Array::slice.call(args, 0)

# Globals

Anvil = @Anvil   = {}
module?.exports  = Anvil

Anvil.version    = '1.0.0'
Anvil.isArray    = isArray
Anvil.isBlank    = isBlank
Anvil.$          = $
Anvil.Events     = Events
Anvil.Module     = Module
Anvil.Controller = Controller

# Global events

Module.extend.call(Anvil, Events)

# JavaScript compatability
Controller.create = Controller.sub = (instances, statics) ->
    class Result extends this
    Result.include(instances) if instances
    Result.extend(statics) if statics
    Result.unbind?()
    Result

Anvil.Class = Module
