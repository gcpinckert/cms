require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get "/" do
  @files = Dir.children(data_path)
  erb :index, layout: :layout
end

def error_for_file(path)
  "#{File.basename(path)} does not exist." unless File.exist?(path)
end

def render_markdown_as_html(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def get_file_contents(path)
  contents = IO.read(path)
  case File.extname(path)
  when ".md"
    erb render_markdown_as_html(contents), layout: :layout
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  end
end

get "/new" do
  erb :new, layout: :layout
end

def error_for_file_name(name)
  if name.empty?
    "A name is required."
  elsif !name.match(/\.(txt|md)/)
    "A .txt or .md file extension must be provided."
  end
end

post "/new" do
  @file_name = params[:new_file].strip
  error = error_for_file_name(@file_name)

  if error
    session[:error] = error
    status 422
    erb :new, layout: :layout
  else
    path = File.join data_path, @file_name
    File.new(path, "w+")
    session[:success] = "#{@file_name} was created."
    redirect "/"
  end
end

get "/:file_name" do
  path = File.join data_path, params[:file_name]
  error = error_for_file(path)

  if error
    session[:error] = error
    redirect "/"
  else
    get_file_contents(path)
  end
end

get "/:file_name/edit" do
  path = File.join data_path, params[:file_name]
  error = error_for_file(path)
  @file_name = params[:file_name]

  if error
    session[:error] = error
    redirect "/"
  else
    @contents = IO.read(path)
    erb :edit_contents, layout: :layout
  end
end

post "/:file_name/edit" do
  path = File.join data_path, params[:file_name]

  IO.write(path, params[:file_contents])
  session[:success] = "#{params[:file_name]} has been updated."
  redirect "/"
end

post "/:file_name/delete" do
  path = File.join data_path, params[:file_name]

  File.delete(path)
  session[:success] = "#{params[:file_name]} was deleted."
  redirect "/"
end
