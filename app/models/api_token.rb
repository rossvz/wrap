class ApiToken < ApplicationRecord
  belongs_to :user

  has_secure_token

  validates :name, length: { maximum: 100 }

  def touch_usage!(ip_address)
    update_columns(last_used_at: Time.current, last_used_ip: ip_address)
  end
end
