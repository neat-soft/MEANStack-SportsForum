(($)->
  $(document).ready(->

    conversait_count_format_default = (value)->
      if value.all_activities == 1
        return "1 Comment"
      else
        return "#{value.all_activities} Comments"

    format = (value)->
      format_count = window.conversait_count_format || conversait_count_format_default
      if typeof format_count == "string"
        return format_count
          .replace("{c}", value.comments || 0)
          .replace("{ch}", value.challenges || 0)
          .replace("{q}", value.questions || 0)
          .replace("{a}", value.activities || 0)
          .replace("{allc}", value.all_comments || 0)
          .replace("{alla}", value.all_activities || 0)
      else if typeof format_count == "function"
        return format_count(value)
      else
        return ""

    window.conversait_set_counts = (id, url, value)->
      if id
        $("[data-conversation-id='#{id}']").text(format(value))
      else
        $("[data-conversation-url='#{url}']").text(format(value))

    $("[data-conversation-url]").each((index, elem)->
      id = $(elem).attr("data-conversation-id")
      url = $(elem).attr("data-conversation-url")
      title = $(elem).attr("data-conversation-title")?.substring?(0, 100)
      if url
        query = [
          's=' + encodeURIComponent(window.conversait_sitename),
          'u=' + encodeURIComponent(url),
          't=' + encodeURIComponent(title)
        ]
        if id
          query.push('id=' + encodeURIComponent(id))
        query.push('callback=' + encodeURIComponent("conversait_set_counts"))
        $("body").append($('<script type="text/javascript" src="{{{host}}}/web/js/count.js?' + query.join('&') + '"></script>'))
    )
  )
)(conversait_jQuery)
