class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :user

  scope :active, -> { where(expires_at: Time.current..) }
  scope :stale, -> { where(expires_at: ..Time.current) }

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  validates :code, uniqueness: true, presence: true

  class << self
    def consume(code)
      active.find_by(code: normalize_code(code))&.consume
    end

    def normalize_code(code)
      return nil if code.blank?
      code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end

    def cleanup
      stale.delete_all
    end

    private

  end

  def consume
    destroy
    self
  end

  private

  def generate_code
    self.code ||= loop do
      candidate = SecureRandom.alphanumeric(CODE_LENGTH).upcase
      break candidate unless self.class.exists?(code: candidate)
    end
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_TIME.from_now
  end
end
