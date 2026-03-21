module Admin
  class AuditLogger
    class << self
      def log!(actor:, target:, action:, metadata: {})
        AuditLog.create!(
          actor: actor,
          target_type: target.class.name,
          target_id: target.id,
          action: action,
          metadata: metadata
        )
      end
    end
  end
end
