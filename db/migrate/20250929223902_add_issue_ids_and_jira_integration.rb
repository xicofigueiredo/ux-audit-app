class AddIssueIdsAndJiraIntegration < ActiveRecord::Migration[7.1]
  def change
    add_column :video_audits, :issue_id_counter, :integer, default: 0
    add_column :video_audits, :jira_epic_key, :string
    add_column :video_audits, :share_token, :string
    add_column :video_audits, :shared_at, :datetime

    add_index :video_audits, :share_token, unique: true
    add_index :video_audits, :jira_epic_key
  end
end
