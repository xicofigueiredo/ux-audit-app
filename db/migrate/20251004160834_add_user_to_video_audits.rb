class AddUserToVideoAudits < ActiveRecord::Migration[7.1]
  def change
    add_reference :video_audits, :user, null: true, foreign_key: true

    # Assign existing video audits to the first user (if any exists)
    # This is a temporary solution - in production you'd handle this differently
    reversible do |dir|
      dir.up do
        if User.exists? && VideoAudit.exists?
          first_user = User.first
          VideoAudit.where(user_id: nil).update_all(user_id: first_user.id)
        end
      end
    end

    # Now make user_id required
    change_column_null :video_audits, :user_id, false
  end
end
