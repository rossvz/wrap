class AddTokenToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :token, :string

    reversible do |dir|
      dir.up do
        Session.find_each do |session|
          session.update_column(:token, SecureRandom.base58(24))
        end
      end
    end

    change_column_null :sessions, :token, false
    add_index :sessions, :token, unique: true
  end
end
