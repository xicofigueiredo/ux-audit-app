class AddFrameDetailsToIssueScreenshots < ActiveRecord::Migration[7.1]
  def change
    add_column :issue_screenshots, :frame_sequence, :integer, default: 0
    add_column :issue_screenshots, :frame_number, :integer
    add_column :issue_screenshots, :is_primary, :boolean, default: false

    add_index :issue_screenshots, [:video_audit_id, :issue_index, :frame_sequence],
              name: 'index_screenshots_on_audit_issue_sequence'
  end
end
