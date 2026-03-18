class CreateCopilotSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :copilot_sessions, id: :uuid do |t|
      t.string :user_name
      t.text :session_summary
      t.jsonb :tool_invocations
      t.string :outcome
      t.string :s3_transcript_url

      t.timestamps
    end
  end
end
