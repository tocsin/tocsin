module Tocsin
  class Config
    attr_accessor :mailer, :mailer_method, :exception_level, :from_address, :logger, :queue, :recipient_groups

    def initialize
      @exception_level  = StandardError
      @logger           = select_logger
      @mailer           = select_mailer
      @mailer_method    = select_mailer_method
      @queue            = :high
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

    private

    def select_logger
      rails = defined?(Rails) && Rails.respond_to?(:logger)
      rails ? Rails.logger : Logger.new($stderr)
    end

    def select_mailer
      action_mailer = defined?(ActionMailer::Base) && ActionMailer::Base.respond_to?(:mail)
      action_mailer ? ActionMailer::Base : Mail
    end

    def select_mailer_method
      action_mailer = defined?(ActionMailer::Base) && mailer.ancestors.include?(ActionMailer::Base)
      action_mailer ? :mail : :new
    end
  end
end
