# Tocsin
Tocsin is a library designed to simplify the task of notifying interested parties about your site's
operation. You may already be tracking errors through [New Relic](http://www.newrelic.com), but not
all errors are created equal -- there are probably parts of your site where an exception is a bigger
problem than a random link surfing throwing 404s. Tocsin will inform you when these parts of your
site break, or when important events happen, or really whenever you configure it to notify you.

Currently, Tocsin works only in Rails 3, and supports notification via email.

## Installation
Add Tocsin to your Gemfile:
<pre>gem 'tocsin'</pre>

Update your bundle:
<pre>bundle install</pre>

Use the provided Rake task to generate the migration and model needed by Tocsin. (Angry at the lack
of normalization? Install [lookup_by](https://github.com/companygardener/lookup_by/) and rewrite the
migration and model to use it; Tocsin won't even notice.)
<pre>rake tocsin:install</pre>

Lastly, configure Tocsin to be useful. Create an initializer in `config/initializers/tocsin.rb` that
looks something like this:

<pre>
Tocsin.configure do |c|
  c.from_address = 'me@mysite.com'

  c.notify 'you@gmail.com', :of => { :category => /user_registrations/ }, :by => :email
  c.notify ['you@gmail.com', 'sales@mysite.com'], :of => { :category => /new_sales/ } # N.B. 'email' is the default nofifier.
  c.notify 'ops@mysite.com', :of => { :severity => /critical/ } # Values in the :of hash should be regexes.
end
</pre>

## Usage
In anywhere you want to send yourself a notification:
<pre>
Tocsin.notify :category => :user_registrations,
              :message => "User #{user.name} registered at #{Time.now}!"
</pre>

If you want to sound the alarm:

<pre>
begin
  # ...
rescue => e
  Tocsin.raise_alert  e, :category => :user_registrations,
                         :severity => :critical,
                         :message => "An error occurred when a user tried to sign up!"
end
</pre>

In any code you want to watch for explosions:

<pre>
Tocsin.watch! :category => :important_stuff, :severity => :critical, :message => "Error doing important stuff!" do
  Important::Stuff.do!
end
</pre>
