class CopilotSessionsController < ApplicationController
  include Paginatable
  skip_forgery_protection only: [:create]

  def index
    @sessions_pagination = paginate(CopilotSession.recent, per_page: 15)
    @sessions = @sessions_pagination[:records]
    @total_count = @sessions_pagination[:total]
    @total_tools = CopilotSession.sum { |s| s.tool_count }
  end

  def show
    @session = CopilotSession.find(params[:id])
  end

  def create
    session = CopilotSession.new(
      user_name: params[:user_name] || "unknown",
      session_summary: params[:session_summary],
      tool_invocations: params[:tool_invocations],
      outcome: params[:outcome] || "completed",
      s3_transcript_url: params[:session_id]
    )
    session.created_at = Time.parse(params[:started_at]) if params[:started_at].present?
    session.save!
    render json: { id: session.id, status: "created" }, status: :created
  end
end
