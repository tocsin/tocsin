module Tocsin
  class Config
    attr_accessor :exception_level, :from_address, :logger, :queue, :recipient_groups

    def initialize
      @exception_level  = StandardError
      @logger           = select_logger
      @queue            = :high
    end

    def select_logger
      rails = defined?(Rails) && Rails.respond_to?(:logger)
      rails ? Rails.logger : Logger.new($stderr)
    end

    # notify [r1, r2], :of => filters, :by => notifier 
    def notify(recipients, parameters)
      self.recipient_groups ||= []

      recipients = [recipients] unless recipients.is_a? Array
      filters   = parameters[:of] || {}
      notifier  = parameters[:by] || Tocsin::Notifiers.default_notifier

      group_config = { :recipients  => recipients,
                       :notifier    => notifier}.merge(filters)
      self.recipient_groups.push(group_config)
    end
  end
end
