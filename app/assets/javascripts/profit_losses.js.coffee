global = exports ? this
(($) ->
  $ ->
    urls = global.urls
    $.ajax({
      url: urls["income"],
      type: "GET",
      dataType: "json",
      success: (data) -> charts.pieChart("#income_chart", data) })
    $.ajax({
      url: urls["outgo"],
      type: "GET",
      dataType: "json",
      success: (data) -> charts.pieChart("#outgo_chart", data) })
    $.ajax({
      url: urls["yearly_income"],
      type: "GET",
      dataType: "json",
      success: (data) -> charts.lineChart("#yearly_income_chart", "#yearly_income_chart_choices" , data) })
    $.ajax({
      url: urls["yearly_outgo"],
      type: "GET",
      dataType: "json",
      success: (data) -> charts.lineChart("#yearly_outgo_chart", "#yearly_outgo_chart_choices" , data) })
    $.ajax({
      url: urls["yearly_total"],
      type: "GET",
      dataType: "json",
      success: (data) -> charts.lineChart("#yearly_total_chart", "#yearly_total_chart_choices" , data) })
) jQuery
