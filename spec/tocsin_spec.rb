require 'spec_helper'

describe Tocsin do
  let(:alert_options) do
    { :severity => :critical,
      :message => "Raised by someone",
      :category => :real_important_job   }
  end

  let(:recipient_groups) do
    [ {:category => /.*/, :severity => /.*/, :recipients => ["x@y.com", "z@w.com"]},
      {:category => /^test$/, :severity => /(high|low)/, :recipients => ["a@b.com", "z@w.com"], :notifier => :email},
      {:category => /^test$/, :severity => /(high|low)/, :recipients => ["1234567890"], :notifier => :text_message}
    ]
  end

  before do
    Tocsin.configure do |c|
      c.recipient_groups = recipient_groups
      c.logger = Logger.new('/dev/null')
    end
  end

  context "when an exception has already been rescued" do
    it "raises (and returns) an alert" do
      Tocsin::Alert.expects(:create).returns(Tocsin::Alert.new)

      begin
        raise "Testing"
      rescue => e
        Tocsin.raise_alert(e, alert_options).should be_a_kind_of(Tocsin::Alert)
      end
    end
  end

  context "when considering a block of code which explodes" do
    it "provides a watch method which raises an alert silently" do
      Tocsin.expects(:raise_alert).with(is_a(Exception), has_entries(alert_options))

      lambda {
        Tocsin.watch(alert_options) do
          raise "Testing"
        end
      }.should_not raise_error
    end

    it "provides a watch! method which both send an alert and re-raises the exception" do
      Tocsin.expects(:raise_alert).with(is_a(Exception), has_entries(alert_options))

      lambda {
        Tocsin.watch!(alert_options) do
          raise "Testing"
        end
      }.should raise_error
    end
  end

  describe "being configured" do
    it "wipes old configuration" do
      Tocsin.configure do |c|
        c.recipient_groups = []
      end

      Tocsin.configure { }
      Tocsin.config.recipient_groups.should be_nil
    end

    describe "#recipient_groups=" do
      it "can set the list of recipient groups directly" do
        Tocsin.configure do |c|
          c.recipient_groups = recipient_groups
        end

        Tocsin.config.recipient_groups.should == recipient_groups
      end
    end

    describe "#notify" do
      it "can create a notification group idiomatically" do
        Tocsin.configure do |c|
          c.notify ["rnubel@test.com"], :of => { :severity => /critical/ }, :by => :email
        end

        Tocsin.config.recipient_groups.should == [
          { :severity => /critical/, :recipients => ["rnubel@test.com"], :notifier => :email }
        ]
      end

      it "assumes email as the default notifier if not specified" do
        Tocsin.configure do |c|
          c.notify ["rnubel@test.com"], :of => { :severity => /critical/ }
        end

        Tocsin.config.recipient_groups.should == [
          { :severity => /critical/, :recipients => ["rnubel@test.com"], :notifier => :email }
        ]
      end

      it "converts a single recipient into an array of that single recipient" do
        Tocsin.configure do |c|
          c.notify "rnubel@test.com", :of => { :severity => /critical/ }, :by => :email
        end

        Tocsin.config.recipient_groups.should == [
          { :severity => /critical/, :recipients => ["rnubel@test.com"], :notifier => :email }
        ]
      end

      it 'has a default queue' do
        Tocsin.configure { }
        Tocsin.config.queue.should_not be_nil
      end

      it 'can be confgiured with a default from_address' do
        Tocsin.configure do |c|
          c.from_address = "webdude@example.net"
        end
        Tocsin.config.from_address.should == "webdude@example.net"
      end
    end
  end

  context "deciding what recipients apply to a given alert" do
    context "when given a pattern matching only one group" do
      it "returns the group in a hash with the notifier as the key" do
        Tocsin.recipients(stub('alert', :category => "whee", :severity => "test")).should == { :email => ["x@y.com", "z@w.com"] }
      end
    end

    it "should merge all groups which match the pattern" do
      Tocsin.recipients(stub('alert', :category => "test", :severity => "high")).should == { :email => ["a@b.com", "x@y.com", "z@w.com"],
                                                                                             :text_message => ["1234567890"] }
    end
  end

  describe "synoynms for ::raise_alert" do
    describe "::notify" do
      it "calls raise_alert with notification as the default severity" do
        Tocsin.expects(:raise_alert).with(nil, has_entries(:severity => "notification"))
        Tocsin.notify({})
      end
    end

    describe "::warn!" do
      it "calls raise_alert with the same options as passed" do
        opts = mock("options")
        Tocsin.expects(:raise_alert).with(nil, opts)
        Tocsin.warn!(opts)
      end
    end
  end

  context "when raising an alarm" do
    let(:exception) do
      begin
        raise "Exception"
      rescue => e
        e
      end
    end

    let(:alert) do
      Tocsin.raise_alert(exception, alert_options)
    end

    let(:attributes) do
      { :exception  =>  exception.to_s,
        :backtrace  =>  exception.backtrace.join("\n"),
        :severity   =>  alert_options[:severity].to_s,
        :message    =>  alert_options[:message].to_s,
        :category   =>  alert_options[:category].to_s
      }
    end

    describe "the created Tocsin::Alert object" do
      it "is created with appropriate fields" do
        Tocsin::Alert.expects(:create).with(has_entries(attributes)).returns(Tocsin::Alert.new)
        alert
      end
    end

    it "should enqueue a notification job in Resque by default" do
      Resque.expects(:enqueue).with(Tocsin::NotificationJob, is_a(Integer))
      Tocsin.expects(:sound).never
      alert
    end

    it "should sound an alert immediately when asked" do
      Resque.expects(:enqueue).never
      Tocsin.expects(:sound).once
      alert_options[:urgent] = true
      alert
    end

    it "does not explode if Resque.enqueue fails" do
      Resque.expects(:enqueue).raises("Blah")

      ## once for the original alert, once for queuing failure
      Tocsin.expects(:sound).twice

      expect { alert }.to_not raise_error
    end

    context "common communication errors" do
      before do
        Tocsin.configure do |c|
          c.notify ["a@b.com"], :of => { :severity => /.*/ }
          c.logger = Logger.new('/dev/null')
        end
      end

      errors =  [ Timeout::Error,
                  Errno::EHOSTUNREACH,
                  Errno::ECONNREFUSED,
                  Errno::ENETUNREACH,
                  Errno::ETIMEDOUT ]

      errors.each do |err|
        it "logs #{err.to_s} without exploding" do
          alert_options.merge!(now: true)
          Mail.expects(:deliver).raises(err)
          Tocsin.logger.expects(:error)
          expect { alert }.to_not raise_error
        end
      end
    end

  end

  describe Tocsin::NotificationJob do
    let(:alert) { stub("alert", :id => 5, :category => "test", :severity => "test", :message => "test", :exception => nil, :backtrace => nil) }
    before { Mail::TestMailer.deliveries.clear }

    it "locates the alert by id" do
      Tocsin::Alert.expects(:find).with(5).returns(alert)
      Tocsin::NotificationJob.perform(5)
    end

    it "uses the associated notifier to alert recipients" do
      Tocsin::Alert.expects(:find).with(5).returns(alert)
      Tocsin.expects(:recipients).with(alert).returns( :email => ["a@b.com"] )
      Tocsin::Notifiers[:email].expects(:notify).with(["a@b.com"], alert)
      Tocsin::NotificationJob.perform(5)
    end

    it 'will use the first email address as the sender when from_address is not present' do
      Tocsin::Alert.expects(:find).with(5).returns(alert)
      Tocsin.expects(:recipients).with(alert).returns( :email => ["a@b.com", "x@y.com"] )
      Tocsin::NotificationJob.perform(5)

      em = Mail::TestMailer.deliveries.first
      em.from.should include("a@b.com")
    end

    it "should log an error for an unknown notifier" do
      Tocsin::Alert.expects(:find).with(5).returns(alert)
      Tocsin.expects(:recipients).returns({:raven => "Cersei"})
      Tocsin.logger.expects(:error)
      Tocsin::NotificationJob.perform(5)
    end

    context "empty recipient list" do
      before do
        Tocsin::Alert.expects(:find).with(5).returns(alert)
        Tocsin.expects(:recipients).returns({:email => []})
      end

      after { Tocsin::NotificationJob.perform(5) }

      it "should not attempt notification" do
        Tocsin::Notifiers[:email].expects(:notify).never
      end

      it "should log an error" do
        Tocsin.logger.expects(:error)
      end
    end

    it "should not raise an exception if the alert isn't found (otherwise, possible recursion)" do
      Tocsin::Alert.expects(:find).with(5).raises(ActiveRecord::RecordNotFound)
      lambda {
        Tocsin::NotificationJob.perform(5)
      }.should_not raise_error
    end
  end
end
