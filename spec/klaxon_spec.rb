require 'spec_helper'

describe Klaxon do
  let(:alert_options) do
    { :severity => :critical, 
      :message => "Raised by someone", 
      :category => :real_important_job   }
  end

  context "when an exception has already been rescued" do
    it "raises an alert" do
      Alert.expects(:create)

      begin
        raise "Testing"
      rescue => e
        Klaxon.raise_alert(e, alert_options)
      end
    end
  end

  context "when considering a block of code which explodes" do
    it "provides a watch method which raises an alert silently" do
      Klaxon.expects(:raise_alert).with(is_a(Exception), has_entries(alert_options))

      lambda {
        Klaxon.watch(alert_options) do
          raise "Testing"
        end
      }.should_not raise_error
    end

    it "provides a watch! method which both send an alert and re-raises the exception" do
      Klaxon.expects(:raise_alert).with(is_a(Exception), has_entries(alert_options))

      lambda {
        Klaxon.watch!(alert_options) do
          raise "Testing"
        end
      }.should raise_error
    end
  end

  describe "being configured" do
    let(:groups) { [] }

    it "sets the list of recipient groups directly" do
      Klaxon.configure do |c|
        c.recipient_groups = groups
      end

      Klaxon.config.recipient_groups.should == groups
    end
  end

  context "deciding what recipients apply to a given alert" do
    before(:each) {
      Klaxon.config.stubs(:recipient_groups).returns(
        [{:category => /.*/, :severity => /.*/, :recipients => ["x@y.com", "z@w.com"]},
         {:category => /^test$/, :severity => /(high|low)/, :recipients => ["a@b.com", "z@w.com"]}]
      )
    }

    it "should find a single group which matches the pattern" do
      Klaxon.recipients(stub('alert', :category => "whee", :severity => "test")).should =~ ["x@y.com", "z@w.com"]
    end

    it "should merge all groups which match the pattern" do
      Klaxon.recipients(stub('alert', :category => "test", :severity => "high")).should =~ ["a@b.com", "x@y.com", "z@w.com"]
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

    after(:each) do
      Klaxon.raise_alert(exception, alert_options)
    end

    describe "the created Alert object" do
      it "is created with appropriate fields" do
        Alert.expects(:create).with(has_entries(
          :exception  =>  exception.to_s,
          :backtrace  =>  exception.backtrace.join("\n"),
          :severity   =>  alert_options[:severity].to_s,
          :message    =>  alert_options[:message].to_s,
          :category   =>  alert_options[:category].to_s 
        ))
      end
    end

    it "should enqueue an email job in Resque" do
      Resque.expects(:enqueue).with(Klaxon::EmailAlertJob, is_a(Integer))
    end
  end
end