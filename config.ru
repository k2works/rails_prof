# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run ProfileTest::Application

if Rails.env.profile?
  use Rack::RubyProf, :path => 'temp/profile', :printers => {RubyProf::CallTreePrinter => 'Callgrid.out'}
end
