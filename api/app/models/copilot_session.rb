# == Schema Information
#
# Table name: copilot_sessions
#
#  id                :uuid             not null, primary key
#  outcome           :string
#  s3_transcript_url :string
#  session_summary   :text
#  tool_invocations  :jsonb
#  user_name         :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class CopilotSession < ApplicationRecord
  validates :user_name, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(outcome: "successful_recommendation") }

  def tool_count
    tool_invocations&.size || 0
  end

  def duration_display
    return "—" unless updated_at && created_at
    mins = ((updated_at - created_at) / 60).round
    mins < 1 ? "< 1 min" : "#{mins} min"
  end
end
