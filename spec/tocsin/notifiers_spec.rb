require 'spec_helper'

# Fixture for testing notifiers.
class DummyNotifier

end

describe Tocsin::Notifiers do
  context "after a notifier has been registered with a key" do
    before {
      Tocsin::Notifiers.register! :dummy, DummyNotifier
    }

    it "can retrieve the notifier based on that key" do
      Tocsin::Notifiers[:dummy].should == DummyNotifier
    end
  end
end
