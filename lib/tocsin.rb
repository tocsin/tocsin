require "tocsin/version"
require "tocsin/notifiers"
require "tocsin/config"

require "active_record/errors" 
require 'logger'

# Library for escalating and logging errors.
module Tocsin
  # Raise an alarm and escalate as configured in etc/tocsin.yml.
  # @param [Exception] exception exception object if one was raised
  # @option options :severity severity of this notication. Should be low,
  # medium, high, critical, or notification (arbitrary, though)
  # @option options :message any info attached to this notification
  # @option options :category totally arbitrary, but escalation can be configured based on
  # this field.
  # @return [Tocsin::Alert] the created alert
  def self.raise_alert(exception, options={})
    urgent = options.delete(:now) || options.delete(:urgent) || options.delete(:synchronous)
    alert  = alert_for(exception, options)

    begin
      urgent ? sound(alert) : queue(alert)
    rescue => e
      sound cannot_enqueue_alert(e)
      sound alert
    end

    alert
  end

  # Synonyms for raise_alert when no exception is involved.
  def self.notify(options)
    self.raise_alert(nil, {:severity => "notification"}.merge(options))
  end

  def self.warn!(options)
    self.raise_alert(nil, options)
  end

  # Watch the yielded block for exceptions, and log one if it's raised.
  def self.watch(options={})
    begin
      yield
    rescue => e
      raise_alert(e, options)
    end
  end

  # Same as watch, but re-raises the exception after catching it.
  def self.watch!(options={})
    begin
      yield
    rescue => e
      raise_alert(e, options)
      raise e
    end
  end

  # Determine the recipients per notification method for a particular alert.
  def self.recipients(alert)
    # Each recipient group should look like (where the filter values are regexps):
    # - category: .*
    # severity: (critical|high)
    # recipients:
    # - rnubel@test.com
    # notifier: email
    return {} unless config.recipient_groups

    recipients_per_notifier = config.recipient_groups.inject({}) do |rec_lists, group|
      if alert_matches_group(alert, group)
        notifier = group[:notifier] || Tocsin::Notifiers.default_notifier
        rec_lists[notifier] ||= []
        rec_lists[notifier] += group[:recipients]
      end

      rec_lists
    end

    recipients_per_notifier.each do |k, v| v.uniq!; v.sort! end # Filter duplicates and sort for sanity
  end

  def self.configure
    @config = nil
    yield config
  end

  def self.config
    @config ||= Tocsin::Config.new
  end

  def self.queue
    @queue ||= config.queue
  end

  def self.logger
    @logger ||= config.logger
  end

  # Job to notify admins via email of a problem.
  class NotificationJob
    @queue = Tocsin.queue

    # Look up the given alert and notify recipients of it.
    def self.perform(alert_id)
      Tocsin.sound(alert_id)
    rescue ActiveRecord::RecordNotFound
      Tocsin.logger.error { "Raised alert with ID=#{alert_id} but couldn't find that alert." }
    end

  end

  private

  def self.sound(alert)
    alert = Tocsin::Alert.find(alert) unless alert.is_a?(Tocsin::Alert)
    recipients = Tocsin.recipients(alert)

    recipients.each do |notifier_key, recipient_list|
      notifier = Tocsin::Notifiers[notifier_key]

      if notifier && recipient_list.any?
        logger.info { "Sending notification to #{recipient_list.inspect} via #{notifier_key} for alert #{alert.id}." }
        begin
          notifier.notify(recipient_list, alert)
        rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ENETUNREACH, Errno::ETIMEDOUT => e
          logger.error { "Notification failed. #{e.to_s}:\n#{e.backtrace.join('\n')}" }
        end
      elsif recipient_list.empty?
        logger.error { "No recipients associated with alert: \n #{alert.inspect}" }
      elsif notifier.nil?
        logger.error { "Raised alert with ID=#{alert.id} for unregistered notifier '#{notifier_key}'." }
      end
    end
  end

  def self.alert_for(exception, options = {})
    alert = Tocsin::Alert.create(
      :exception => exception && exception.to_s,
      :backtrace => exception && exception.backtrace.join("\n"),
      :severity => options[:severity].to_s || "",
      :message => options[:message].to_s || "",
      :category => options[:category].to_s || "uncategorized"
    )
  end

  def self.queue(alert)
    alert = Tocsin::Alert.find(alert) unless alert.is_a?(Tocsin::Alert)
    Resque.enqueue(NotificationJob, alert.id)
  end

  def self.cannot_enqueue_alert(exception=nil)
    logger.error "[Tocsin] Enqueuing alert job into Resque failed!"
    alert_for exception, :severity => "critical",
                         :message => "[Tocsin] Enqueuing alert job into Resque failed!",
                         :category => "system"
  end

  def self.alert_matches_group(alert, group)
    alert.category =~ Regexp.new(group[:category] || '.*') && 
    alert.severity =~ Regexp.new(group[:severity] || '.*')
  end
end
