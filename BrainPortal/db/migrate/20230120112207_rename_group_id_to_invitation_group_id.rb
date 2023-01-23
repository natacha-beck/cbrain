class RenameGroupIdToInvitationGroupId < ActiveRecord::Migration[5.0]
  def self.up
    rename_column :messages, :group_id, :invitation_group_id
  end

  def self.down 
    rename_column :messages, :invitation_group_id, :group_id
  end
end
