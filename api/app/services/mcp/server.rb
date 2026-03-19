module Mcp
  class Server
    PROTOCOL_VERSION = "2024-11-05"
    SERVER_NAME = "fleetops-mcp"
    SERVER_VERSION = "1.0.0"

    TOOLS = [
      Tools::VehiclesDueForMaintenance,
      Tools::UpcomingTripsForVehicle,
      Tools::ServiceCentersNearRoute,
      Tools::VehicleHealthSummary,
      Tools::DraftMaintenanceRecommendation,
      Tools::FleetQuery
    ].freeze

    def run
      $stdout.sync = true
      $stderr.puts "[MCP] FleetOps MCP server started (pid: #{Process.pid})"

      $stdin.each_line do |line|
        line = line.strip
        next if line.empty?

        request = JSON.parse(line)
        # Notifications have no id — don't respond
        next if request["id"].nil?

        response = handle(request)
        $stdout.puts(JSON.generate(response))
      rescue JSON::ParserError => e
        $stderr.puts "[MCP] Parse error: #{e.message}"
        $stdout.puts(JSON.generate(error_response(nil, -32700, "Parse error")))
      rescue => e
        $stderr.puts "[MCP] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        $stdout.puts(JSON.generate(error_response(request&.dig("id"), -32603, e.message)))
      end
    end

    private

    def handle(request)
      id = request["id"]
      method = request["method"]
      params = request["params"] || {}

      case method
      when "initialize"
        success_response(id, {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { tools: {} },
          serverInfo: { name: SERVER_NAME, version: SERVER_VERSION }
        })
      when "tools/list"
        tools = TOOLS.map do |tool|
          { name: tool.tool_name, description: tool.description, inputSchema: tool.input_schema }
        end
        success_response(id, { tools: tools })
      when "tools/call"
        call_tool(id, params)
      else
        error_response(id, -32601, "Unknown method: #{method}")
      end
    end

    def call_tool(id, params)
      tool_name = params["name"]
      arguments = params["arguments"] || {}

      tool = TOOLS.find { |t| t.tool_name == tool_name }
      return error_response(id, -32602, "Unknown tool: #{tool_name}") unless tool

      result = tool.execute(arguments)
      summary = tool.respond_to?(:summary) ? tool.summary(result, arguments) : nil
      text = summary ? "#{summary}\n\n#{JSON.pretty_generate(result)}" : JSON.pretty_generate(result)
      success_response(id, {
        content: [{ type: "text", text: text }]
      })
    rescue ActiveRecord::RecordNotFound => e
      success_response(id, {
        content: [{ type: "text", text: "Record not found: #{e.message}" }],
        isError: true
      })
    rescue => e
      success_response(id, {
        content: [{ type: "text", text: "Error: #{e.message}" }],
        isError: true
      })
    end

    def success_response(id, result)
      { jsonrpc: "2.0", id: id, result: result }
    end

    def error_response(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end
  end
end
