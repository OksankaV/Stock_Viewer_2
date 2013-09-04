require 'rubygems'
require 'bundler'

Bundler.require

require './page.rb'

run Sinatra::Application
