require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

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
    render_markdown_as_html(contents)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  end
end

get "/:file_name" do
  path = root + "/data/" + params[:file_name]
  error = error_for_file_name(path)

  if error
    session[:error] = error
    redirect "/"
  else
    get_file_contents(path)
  end
end

get "/:file_name/edit" do
  path = root + "/data/" + params[:file_name]
  error = error_for_file_name(path)
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
  path = root + "/data/" + params[:file_name]

  new_content = params[:file_contents]

  IO.write(path, new_content)
  session[:success] = "#{params[:file_name]} has been updated."
  redirect "/"
end
