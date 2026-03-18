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
end
