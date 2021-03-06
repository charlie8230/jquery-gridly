###
jQuery Gridly
Copyright 2013 Kevin Sylvestre
###

"use strict"

$ = jQuery

class Animation
  @transitions:
    "webkitTransition": "webkitTransitionEnd"
    "mozTransition": "mozTransitionEnd"
    "msTransition": "msTransitionEnd"
    "oTransition": "oTransitionEnd"
    "transition": "transitionend"

  @transition: ($el) ->
    el = $el[0]
    return result for type, result of @transitions when el.style[type]?

  @execute: ($el, callback) ->
    transition = @transition($el)
    if transition? then $el.one(transition, callback) else callback()

class Gridly

  @settings:
    base: 60
    gutter: 20
    columns: 12
    draggable:
      zIndex: 800

  @gridly: ($el, options = {}) ->
    @existing ?= {}
    @existing[$el[0]] ?= new Gridly($el, options)
    return @existing[$el[0]]

  constructor: ($el, settings = {}) ->
    @$el = $el
    @settings = $.extend {}, Gridly.settings, settings
    @ordinalize(@$('> *'))

  ordinalize: ($elements) =>
    for i in [0 .. $elements.length]
      $element = $($elements[i])
      $element.data('position', i)

  reordinalize: ($element, position) =>
    $element.data('position', position)

  $: (selector) =>
    @$el.find(selector)

  compare: (d, s) =>
    return +1 if d.y > s.y + s.h
    return -1 if s.y > d.y + d.h
    return +1 if (d.x + (d.w / 2)) > (s.x + (s.w / 2))
    return -1 if (s.x + (s.w / 2)) > (d.x + (d.w / 2))
    return 0

  draggable: =>
    callbacks =
      drag: @drag
      start: @start
      stop: @stop

    @$('> *').draggable($.extend(callbacks, @settings.draggable))

  stationary: =>
    @$('> *').draggable('destroy')

  start: (event, ui) =>
    $elements = @$sorted()
    @ordinalize($elements)
    setTimeout @layout, 0
    @settings?.callbacks?.reordering?($elements)

  stop: (event, ui) =>
    $elements = @$sorted()
    @ordinalize($elements)
    setTimeout @layout, 0
    @settings?.callbacks?.reordered?($elements)

  $sorted: ($elements) =>
    ($elements || @$('> *')).sort (a,b) ->
      $a = $(a)
      $b = $(b)
      aPosition = $a.data('position')
      bPosition = $b.data('position')
      aPositionInt = parseInt(aPosition)
      bPositionInt = parseInt(bPosition)
      return -1 if aPosition? and not bPosition?
      return +1 if bPosition? and not aPosition?
      return -1 if not aPosition and not bPosition and $a.index() < $b.index()
      return +1 if not bPosition and not aPosition and $b.index() < $a.index()
      return -1 if aPositionInt < bPositionInt
      return +1 if bPositionInt < aPositionInt
      return 0

  drag: (event, ui) =>
    $dragging = $(event.target)
    $elements = @$sorted()
    positions = @structure($elements).positions
    original = index = $dragging.data('position')

    for element in positions.filter((position) -> position.$element.is($dragging))
      element.x = $dragging.position().left
      element.y = $dragging.position().top
      element.w = $dragging.data('width')  || $dragging.width()
      element.h = $dragging.data('height') || $dragging.height()

    positions.sort @compare

    $elements = positions.map (position) -> position.$element
    $elements = (@settings.callbacks?.optimize || @optimize)($elements)

    for i in [0...$elements.length]
      @reordinalize($($elements[i]), i)

    @layout()

  size: ($element) =>
    (($element.data('width') || $element.width()) + @settings.gutter) / (@settings.base + @settings.gutter)

  position: ($element, columns) =>
    size = @size($element)

    height = Infinity
    column = 0

    for i in [0 ... (columns.length - size)]
      max = Math.max columns[i ... (i + size)]...
      if max < height
        height = max
        column = i

    for i in [column ... column + size]
      columns[i] = height + ($element.data('height') || $element.height()) + @settings.gutter

    x: (column * (@settings.base + @settings.gutter))
    y: height

  structure: ($elements = @$sorted()) =>
    positions = []
    columns = (0 for i in [0 .. @settings.columns])

    for index in [0 ... $elements.length]
      $element = $($elements[index])

      position = @position($element, columns)
      positions.push
        x: position.x
        y: position.y
        w: $element.data('width') || $element.width()
        h: $element.data('height') || $element.height()
        $element: $element

    height: Math.max columns...
    positions: positions

  layout: =>
    $elements = (@settings.callbacks?.optimize || @optimize)(@$sorted())

    structure = @structure($elements)

    for index in [0 ... $elements.length]
      $element = $($elements[index])
      position = structure.positions[index]

      $element.css
        position: 'absolute'
        left: position.x
        top:  position.y

    @$el.css
      height: structure.height

  optimize: (originals) =>
    results = []

    columns = 0
    while originals.length > 0
      columns = 0 if columns is @settings.columns

      index = 0
      for index in [0...originals.length]
        break if columns + @size($(originals[index])) <= @settings.columns

      if index is originals.length
        index = 0
        columns = 0

      columns += @size($(originals[index]))

      # Move from originals into results
      results.push(originals.splice(index,1)[0])

    return results

$.fn.extend
  gridly: (option = {}) ->
    @each ->
      $this = $(@)

      options = $.extend {}, $.fn.gridly.defaults, typeof option is "object" and option
      action = if typeof option is "string" then option else option.action
      action ?= "layout"

      Gridly.gridly($this, options)[action]()
