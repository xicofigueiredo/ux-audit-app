class LlmPartialResponse < ApplicationRecord
  belongs_to :video_audit

  validates :chunk_index, presence: true
  validates :status, presence: true
end
