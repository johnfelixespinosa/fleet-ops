module ApplicationHelper
  VEHICLE_STATUS_COLORS = {
    "active" => "green", "in_shop" => "amber",
    "out_of_service" => "red", "retired" => "gray"
  }.freeze

  TRIP_STATUS_COLORS = {
    "scheduled" => "blue", "in_progress" => "amber",
    "completed" => "green", "cancelled" => "gray"
  }.freeze

  URGENCY_COLORS = {
    "critical" => "red", "high" => "orange",
    "moderate" => "amber", "normal" => "green"
  }.freeze

  def status_badge(status, color_map = VEHICLE_STATUS_COLORS)
    color = color_map.fetch(status.to_s, "gray")
    content_tag :span, status.to_s.titleize,
      class: "inline-block px-2 py-1 rounded text-xs font-medium bg-#{color}-100 text-#{color}-800"
  end

  def vehicle_status_badge(status) = status_badge(status, VEHICLE_STATUS_COLORS)
  def trip_status_badge(status) = status_badge(status, TRIP_STATUS_COLORS)

  # Colored truck icon per make — distinct silhouette + brand color
  MAKE_ICON_COLORS = {
    "Tesla" => { bg: "#eef2ff", stroke: "#4f46e5" },       # indigo
    "Freightliner" => { bg: "#fff7ed", stroke: "#ea580c" }, # orange
    "Volvo" => { bg: "#ecfdf5", stroke: "#059669" }          # emerald
  }.freeze

  def vehicle_icon(make, size: 40)
    colors = MAKE_ICON_COLORS.fetch(make, { bg: "#f3f4f6", stroke: "#6b7280" })
    # Semi-truck silhouette SVG — cab shape varies per make
    cab_path = case make
    when "Tesla"
      # Sleek rounded cab (Tesla's futuristic design)
      "M8 22 L8 12 Q8 8 12 8 L22 8 Q26 8 28 10 L30 14 L32 14 L32 22 Z"
    when "Freightliner"
      # Angular traditional cab (eCascadia)
      "M8 22 L8 10 L14 8 L24 8 L28 10 L30 14 L32 14 L32 22 Z"
    else
      # Rounded European cab (Volvo)
      "M8 22 L8 11 Q8 8 11 8 L23 8 Q27 8 29 11 L31 14 L32 14 L32 22 Z"
    end

    content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 40 30",
      width: size, height: (size * 0.75).round,
      style: "background:#{colors[:bg]};border-radius:6px;padding:3px") {
      safe_join([
        # Cab body
        tag.path(d: cab_path, fill: "none", stroke: colors[:stroke], "stroke-width": "1.8", "stroke-linejoin": "round"),
        # Windshield
        tag.path(d: "M24 10 L28 10 L29.5 13 L24 13 Z", fill: colors[:stroke], opacity: "0.2"),
        # Wheels
        tag.circle(cx: "13", cy: "23", r: "2.5", fill: "none", stroke: colors[:stroke], "stroke-width": "1.5"),
        tag.circle(cx: "28", cy: "23", r: "2.5", fill: "none", stroke: colors[:stroke], "stroke-width": "1.5"),
        # Axle line
        tag.line(x1: "8", y1: "22", x2: "32", y2: "22", stroke: colors[:stroke], "stroke-width": "1", opacity: "0.4")
      ])
    }
  end
end
