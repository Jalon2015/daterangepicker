class Config
  constructor: (options = {}) ->
    @firstDayOfWeek = @_firstDayOfWeek(options.firstDayOfWeek)
    @showPeriods = @_showPeriods(options.showPeriods)
    @timeZone = @_timeZone(options.timeZone)
    @period = @_period(options.period)
    @periods = @_periods(options.periods)
    @single = @_single(options.single)
    @opened = @_opened(options.opened)
    @expanded = @_expanded(options.expanded)
    @locale = @_locale(options.locale)
    @opens = @_opens(options.opens)

    @minDate = @_minDate(options.minDate)
    @maxDate = @_maxDate(options.maxDate)
    @startDate = @_startDate(options.startDate)
    @endDate = @_endDate(options.endDate)

    @ranges = @_ranges(options.ranges)

    @anchorElement = @_anchorElement(options.anchorElement)
    @parentElement = @_parentElement(options.parentElement)
    @callback = @_callback(options.callback)

    @firstDayOfWeek.subscribe (newValue) ->
      MomentUtil.setFirstDayOfTheWeek(newValue)
    MomentUtil.setFirstDayOfTheWeek(@firstDayOfWeek())

  extend: (obj) ->
    obj[k] = v for k, v of @ when @.hasOwnProperty(k) && k[0] != '_'

  _firstDayOfWeek: (val) ->
    ko.observable(if val then val else 0) # default to Sunday (0)

  _timeZone: (val) ->
    ko.observable(val || 'UTC')

  _showPeriods: (val) ->
    ko.observable(val || false)

  _period: (val) ->
    val ||= 'day'
    console.warn("invalid period #{val}") unless val in ['day', 'week', 'month', 'quarter', 'year']
    Period.extendObservable(ko.observable(val))

  _periods: (val) ->
    ko.observableArray(val || Period.allPeriods)

  _single: (val) ->
    ko.observable(val || false)

  _opened: (val) ->
    ko.observable(val || false)

  _expanded: (val) ->
    ko.observable(val || false)

  _minDate: (val) ->
    [val, mode] = val if val instanceof Array
    val ||= moment().subtract(30, 'year')
    @_dateObservable(val, mode)

  _maxDate: (val) ->
    [val, mode] = val if val instanceof Array
    val ||= moment()
    @_dateObservable(val, mode, @minDate)

  _startDate: (val) ->
    val ||= moment().subtract(30, 'days')
    @_dateObservable(val, null, @minDate, @maxDate)

  _endDate: (val) ->
    val ||= moment()
    @_dateObservable(val, null, @startDate, @maxDate)

  _ranges: (obj) ->
    obj ||= {}
    for title, value of obj
      switch value
        when 'all-time'
          new AllTimeDateRange(title, @minDate().clone(), @maxDate().clone())
        when 'custom'
          new CustomDateRange(title)
        else
          [startDate, endDate] = value
          from = MomentUtil.tz(startDate, @timeZone())
          to = MomentUtil.tz(endDate, @timeZone())
          new DateRange(title, from, to)

  _locale: (val) ->
    val || {
      applyButtonTitle: 'Apply'
      cancelButtonTitle: 'Cancel'
      inputFormat: 'L'
      startLabel: 'Start'
      endLabel: 'End'
    }

  _opens: (val) ->
    val = 'right' unless val in ['right', 'left']
    ko.observable(val)

  _dateObservable: (val, mode, minBoundary, maxBoundary) ->
    observable = ko.observable()
    computed = ko.computed
      read: ->
        observable()
      write: (newValue) =>
        newValue = computed.fit(newValue)
        oldValue = observable()
        observable(newValue) unless oldValue && newValue.isSame(oldValue)

    computed.mode = mode || 'inclusive'

    computed.fit = (val) =>
      val = MomentUtil.tz(val, @timeZone())
      if minBoundary
        min = minBoundary()
        switch minBoundary.mode
          when 'extended'
            min = min.clone().startOf(@period())
          when 'exclusive'
            min = min.clone().endOf(@period()).subtract(1, 'millisecond')
        val = moment.max(min, val)
      if maxBoundary
        max = maxBoundary()
        switch maxBoundary.mode
          when 'extended'
            max = max.clone().endOf(@period())
          when 'exclusive'
            max = max.clone().startOf(@period()).subtract(1, 'millisecond')
        val = moment.min(max, val)
      val

    computed(val)

    computed.clone = =>
      @_dateObservable(observable(), computed.mode, minBoundary, maxBoundary)

    computed.isWithinBoundaries = (date) =>
      min = minBoundary()
      max = maxBoundary()
      between = date.isBetween(min, max, @period())
      sameMin = date.isSame(min, @period())
      sameMax = date.isSame(max, @period())
      minExclusive = minBoundary.mode == 'exclusive'
      maxExclusive = maxBoundary.mode == 'exclusive'
      between || (!minExclusive && sameMin && !(maxExclusive && sameMax)) || (!maxExclusive && sameMax && !(minExclusive && sameMin))

    if minBoundary
      computed.minBoundary = minBoundary
      minBoundary.subscribe -> computed(observable())

    if maxBoundary
      computed.maxBoundary = maxBoundary
      maxBoundary.subscribe -> computed(observable())

    computed

  _anchorElement: (val) ->
    $(val)

  _parentElement: (val) ->
    $(val || 'body') if @anchorElement

  _callback: (val) ->
    val
