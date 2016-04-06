View = require("views/base_view")
template = require("views/templates/analytics")

module.exports = class Main extends View

  template: template


  date_end: moment.utc()
  date_start: moment.utc().subtract("week", 2).utc().startOf("day")

  plot_options:
    xaxis:
      mode: "time"
      timeformat: "%b %d"
      tickSize: [2, "day"]
    yaxis:
      tickFormatter: (val, axis)->
        return Humanize.intword(val, "", 1)
    legend:
      position: "nw"
      container: "#trend-legend"
    series:
      lines:
        show: true
        fill: true
      points:
        show: true
    grid:
      hoverable: true
    colors: ['#afd8f8', '##edc240']

  plot_data:
    loads: []
    comments: []
    conversations: []
    notifications: []
    profiles: []
    subscriptions: []
    verified: []

  active_view: "loads"

  chart: null

  initialize: ->
    super

  sum_array: (arr)->
    if arr.length == 0
      return 0
    return arr.reduce((x, y)->
      x + y
    )

  render_plot: ->
    current_days = @day_span(@date_start, @date_end) / 2
    current = @plot_data[@active_view][0..current_days - 1]
    previous = @plot_data[@active_view][current_days..]
    for x, i in previous
      if current[i]
        previous[i][0] = current[i][0]
    min_visible = Math.min(moment.utc(@date_end).subtract("weeks", 1).valueOf(), current[current.length - 1]?[0] || @date_end.valueOf())
    visible_days = @day_span(moment.utc(min_visible), @date_end)
    @plot_options.xaxis.min = min_visible
    ml = moment(min_visible).utc().valueOf()
    @plot_options.xaxis.tickSize = [Math.floor(visible_days/7), "day"]
    @chart = $.plot($("#trend-chart"), [
        {
          label: "previous period"
          data: previous
          lines:
            show: true
            fill: false
        },
        {
          label: "current period"
          data: current
        }
      ], @plot_options)
    $("#trend-loading").removeClass("loading")
    return

  split_array: (v, count)->
    while v.length < count * 2
      v.push(0)
    return [v[0..count - 1], v[count..v.length]]

  take_half: (array, count, second)->
    if second
      res = array[count..]
    else
      res = array[0..count - 1]
    while res.length < count
      res.push(0)
    return res

  day_span: (start, end)->
    return moment.utc(end).diff(start, "days")

  nth_tuple_element: (array, n)->
    return (elem[n] for elem in array)

  count_trend: (array, span)->
    [second, first] = @split_array(array, span)
    total_first = @sum_array(first)
    if total_first == 0
      return "#{(100.0 * @sum_array(second)).toFixed(1)} %"
    return "#{(100.0 * (@sum_array(second) - total_first) / total_first).toFixed(1)} %"

  render_counts: ->
    numberOfDays = @day_span(@date_start, @date_end)
    half = numberOfDays / 2
    #@count_trend(@nth_tuple_element(@plot_data.loads, 1), half)
    $("#count-conv-load").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.loads, 1), half, false))))
    $("#count-comments").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.comments, 1), half, false))))
    $("#count-conversations").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.conversations, 1), half, false))))
    $("#count-profiles").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.profiles, 1), half, false))))
    $("#count-notifications").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.notifications, 1), half, false))))
    $("#count-subscriptions").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.subscriptions, 1), half, false))))
    $("#count-verified").html(Humanize.intword(@sum_array(@take_half(@nth_tuple_element(@plot_data.verified, 1), half, false))))

  render_trends: ->
    numberOfDays = @day_span(@date_start, @date_end)
    half = numberOfDays / 2
    $("#trend-conv-load").html(@count_trend(@nth_tuple_element(@plot_data.loads, 1), half))
    $("#trend-comments").html(@count_trend(@nth_tuple_element(@plot_data.comments, 1), half))
    $("#trend-conversations").html(@count_trend(@nth_tuple_element(@plot_data.conversations, 1), half))
    $("#trend-profiles").html(@count_trend(@nth_tuple_element(@plot_data.profiles, 1), half))
    $("#trend-notifications").html(@count_trend(@nth_tuple_element(@plot_data.notifications, 1), half))
    $("#trend-subscriptions").html(@count_trend(@nth_tuple_element(@plot_data.subscriptions, 1), half))
    $("#trend-verified").html(@count_trend(@nth_tuple_element(@plot_data.verified, 1), half))

  update: ->
    now = moment.utc(@date_end).startOf("day")
    last_month = moment.utc(@date_start).startOf("day")
    $("#trend-loading").addClass("loading")
    $("#trend-chart").html("")
    @app.get_site_stats(last_month, now, (err, result)=>
      if not err
        @plot_data = {}

        for k, v of result
          if v.length > 0
            begin = moment.utc(v[0][0])
          else
            begin = moment.utc(now)
          all = []

          for item in v
            current = moment.utc(item[0])
            while begin < current
              # insert missing data
              all.push([begin.valueOf(), 0])
              begin.add("days", 1)
            all.push(item)
            begin.add("days", 1)

          while begin < now
            all.push([begin.valueOf(), 0])
            begin.add("days", 1)

          @plot_data[k] = all.reverse()
        @render_plot()
        @render_counts()
        @render_trends()
    )
    @$('.dropdown-toggle').dropdown()

  render: ->
    setTimeout(()=>
      @update()
    , 1)

  events:
    "plothover #trend-chart": "show_tooltip_count_date"
    "resize #trend-chart": "resize_view"
    "click .date-range": "set_date_range"
    "click .metric-row": "metric_row_click"

  metric_row_click: (e)->
    old_active = @active_view
    $(".metric-row").removeClass("info")
    row_id = $(e.target).parents(".metric-row")[0].id
    $("##{row_id}").addClass("info")
    @active_view = row_id.split("-").pop() || old_active
    if @active_view != old_active
      @render_plot()

  set_date_range: (e)->
    $("#date-range-label").html("Date range: #{$(e.target).html()}")
    $("#date-range-dropdown").dropdown("toggle")
    range = e.target.id.split("-").pop() || "week"
    @date_end = moment.utc()
    if range == "all"
      @date_start = moment.utc(0)
    else
      @date_start = moment.utc(@date_end).subtract(range, 2)
    @date_start.utc().startOf("day")
    @update()
    return false

  resize_view: ()->
    w = $("#trend-chart").width()
    if w > 900
      @plot_options.xaxis.tickSize[0] = 2
    if w < 700
      @plot_options.xaxis.tickSize[0] = 3
    if w < 500
      @plot_options.xaxis.tickSize[0] = 4
    @render_plot()
    return false

  show_tooltip_count_date: (event, pos, item)->
    if item
      x = moment.utc(new Date(item.datapoint[0]))
      if item.datapoint.length == 2
        x.subtract("days", @day_span(@date_start, @date_end) / 2)
      y = item.datapoint[1]
      $("#plot-tooltip-count").html(Humanize.intword(y, "", 1))
      $("#plot-tooltip-date").html(x.format("DD-MMM-YYYY"))
      $("#plot-tooltip").css({top: item.pageY + 5, left: item.pageX + 5}).fadeIn(200)
    else
      $("#plot-tooltip").hide()
