require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.children(root + "/data")
  erb :index 
end

get "/:file_name" do
  path = root + "/data/" + params[:file_name]
  @contents = IO.read(path)
  headers["Content-Type"] = "text/plain"
  @contents
end