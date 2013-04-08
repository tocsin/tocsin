require File.expand_path(File.join(File.dirname(__FILE__), '..', 'tocsin'))

namespace :tocsin do
  desc "Generate Tocsin::Alert model & migration"
  task :generate do
    if defined?(Rails)
      puts `rails g model Tocsin::Alert exception:string message:string category:string severity:string backtrace:string --no-test-framework --skip`
      puts "Run rake db:migrate to finish installation."
    else
      puts "Not using rails. Please create Tocsin::Alert manually"
    end
  end
end
