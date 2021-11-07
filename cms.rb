require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.children(root + "/data")
  erb :index 
end