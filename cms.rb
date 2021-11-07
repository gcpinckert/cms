require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.children(root + "/data")
  erb :index, layout: :layout
end

def error_for_file_name(path)
  if !File.exist?(path)
    "#{File.basename(path)} does not exist."
  end
end

get "/:file_name" do
  path = root + "/data/" + params[:file_name]
  error = error_for_file_name(path)

  if error
    session[:error] = error
    redirect "/"
  else
    @contents = IO.read(path)
    headers["Content-Type"] = "text/plain"
    @contents
  end
end