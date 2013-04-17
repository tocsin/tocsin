require 'mail'

module Tocsin
  module Notifiers
    class EmailNotifier
      def self.notify(recipients, alert)
        attrs = { :from     => sender(recipients),
                  :to       => recipients,
                  :subject  => subject(alert),
                  :body     => compose(alert) }

        message = mail(attrs)
        message.deliver
      end

      private

      def self.mail(attrs)
        mailer.send mailer_method, attrs
      end

      def self.config
        Tocsin.config
      end

      def self.mailer
        config.mailer
      end

      def self.mailer_method
        config.mailer_method
      end

      def self.sender(recipients)
        config.from_address || recipients.first
      end

      def self.subject(alert)
        "[Tocsin] [#{alert.severity}] #{alert.message} (#{alert.category})"
      end

      def self.compose(alert)
        _body = []
        _body << "Alert raised by Tocsin on your site:\n"
        _body << "Message: #{alert.message}"
        _body << "Category: #{alert.category}"
        _body << "Severity: #{alert.severity}"
        _body << "Exception: #{alert.exception}"
        _body << "Backtrace: #{alert.backtrace}"
        _body.join("\n")
      end
    end

    register! :email, EmailNotifier
  end
end
