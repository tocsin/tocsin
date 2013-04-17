require 'spec_helper'

describe Tocsin::Notifiers::EmailNotifier do
  let(:alert) {
    stub("Tocsin::Alert", :id => 1, :category => 'category', :severity => 'severity',
                          :message => 'message', :exception => 'exception',
                          :backtrace => 'backtrace')
  }

  context "configurable mailer" do

    let(:action_mailer_class) { ActionMailer::Base }
    let(:alt_mailer_class)    { Foo }
    let(:message)             { stub('message') }

    before(:all) do
      unless defined?(ActionMailer::Base)
        ACTION_MAILER_LOCALLY_DEFINED = true
        module ActionMailer
          class Base
            def self.mail(*args)
              Mail.new(*args)
            end
          end
        end
      end

      class Foo < ActionMailer::Base; end
    end

    after(:all) do
      if defined?(ACTION_MAILER_LOCALLY_DEFINED)
        # reset to default configuration after everything.
        ActionMailer.send(:remove_const, :Base)
        Object.send(:remove_const, :ActionMailer)
        Tocsin.configure {}
      end
    end

    it "uses ActionMailer::Base by default when available" do
      Tocsin.configure {}
      message.expects(:deliver).returns(true)
      action_mailer_class.expects(:mail).returns(message)
      described_class.notify(["a@b.com"], alert)
    end

    it "uses the specified mailer when configured" do
      Tocsin.configure do |c|
        c.mailer = alt_mailer_class
      end

      message.expects(:deliver).returns(true)
      alt_mailer_class.expects(:mail).returns(message)
      described_class.notify(["a@b.com"], alert)
    end

    it "uses the specified mail_method when configured" do
      Tocsin.configure do |c|
        c.mailer = alt_mailer_class
        c.mailer_method = :some_dumb_method_name
      end

      message.expects(:deliver).returns(true)
      alt_mailer_class.expects(:some_dumb_method_name).returns(message)
      described_class.notify(["a@b.com"], alert)
    end
  end

  describe "notifying" do
    let(:origin_email) { "test@test.com" }

    before {
      Tocsin.configure do |c|
        c.from_address = "test@test.com"
      end
    }

    it "uses the Mail gem to send an alert" do
      described_class.notify(["a@b.com"], alert)
    end

    describe "the sent email" do
      let(:message) { Mail::TestMailer.deliveries.first }
      let(:body) { message.body.decoded }

      it "was sent" do
        message.should_not be_nil
      end

      it "has a subject including the alert's message, severity and category" do
        message.subject.should == "[Tocsin] [severity] message (category)"
      end

      it "has a body including all fields" do
        body.should =~ /severity/
        body.should =~ /message/
        body.should =~ /category/
        body.should =~ /exception/
        body.should =~ /backtrace/
      end

      it "is from the configured origin email" do
        message.from.should == [origin_email]
      end
    end
  end

  it "registers itself under the key :email" do
    Tocsin::Notifiers[:email].should == described_class
  end
end
