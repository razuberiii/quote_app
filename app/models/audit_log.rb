class AuditLog < ApplicationRecord
  enum :action, {
    role_changed: "role_changed",
    status_changed: "status_changed",
    impersonation_started: "impersonation_started",
    impersonation_stopped: "impersonation_stopped"
  }

  belongs_to :actor, class_name: "User", optional: true

  validates :target_type, :target_id, :action, presence: true
end
