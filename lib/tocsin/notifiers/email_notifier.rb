require 'mail'

module Tocsin
  module Notifiers
    class EmailNotifier
      def self.notify(recipients, alert)
        _body = "
Alert raised by Tocsin on your site:
\n
Message: #{alert.message}
Category: #{alert.category}
Severity: #{alert.severity}
Exception: #{alert.exception}
Backtrace: #{alert.backtrace}
        ";

        from_address = Tocsin.config.from_address || recipients.first

        Mail.deliver do
          from    from_address
          to      recipients.join(", ")
          subject "[Tocsin] [#{alert.severity}] #{alert.message} (#{alert.category})"
          body    _body
        end
      end
    end

    register! :email, EmailNotifier
  end
end
