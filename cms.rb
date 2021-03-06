require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

# Assign path according to environment
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# Assign the user path according to environment
def users_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

# Load the correct user list
def load_users
  YAML.load_file(users_path)
end

# Check to see if user is signed in and redirect if not
def redirect_if_not_authorized
  unless session[:user_name]
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

# Display list of documents
get "/" do
  @files = Dir.children(data_path)
  erb :index, layout: :layout
end

# Display sign in form
get "/users/sign_in" do
  erb :sign_in, layout: :layout
end

# Validate user credentials
def valid_user?(user_name, password)
  users = load_users
  users.key?(user_name) && BCrypt::Password.new(users[user_name]) == password
end

# Check user credentials and sign user in
post "/users/sign_in" do
  if valid_user?(params[:user_name], params[:password])
    session[:user_name] = params[:user_name]
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid Credentials"
    status 422
    erb :sign_in, layout: :layout
  end
end

# Sign user out
post "/users/sign_out" do
  session.delete(:user_name)
  session[:success] = "You have been signed out."
  redirect "/"
end

def error_for_new_credentials(user_name, password)
  users = load_users
  if user_name.empty?
    "You must enter a username."
  elsif users.key?(user_name)
    "That username is already taken. Please enter a different username."
  elsif password.size < 4
    "The password must be at least 4 characters long."
  end
end

# Display sign up new user form
get "/users/sign_up" do
  erb :sign_up, layout: :layout
end

# Create a new user
post "/users/sign_up" do
  user_name = params[:user_name].strip
  error = error_for_new_credentials(user_name, params[:password])

  if error
    session[:error] = error
    status 422
    erb :sign_up, layout: :layout
  else
    hashed_password = BCrypt::Password.create(params[:password])
    users = load_users
    users[user_name] = hashed_password
    File.open(users_path, 'w') do |file|
      file.write(users.to_yaml)
    end
    session[:success] = "You're signed up! Sign in to get started."
    redirect "/users/sign_in"
  end
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

# Display new document form
get "/new" do
  redirect_if_not_authorized
  erb :new, layout: :layout
end

def error_for_file_name(name)
  if name.empty?
    "A name is required."
  elsif !name.match(/\.(txt|md)/)
    "A .txt or .md file extension must be provided."
  end
end

# Creates new document
post "/new" do
  redirect_if_not_authorized
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

# Display contents of given file
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

# Display form for editing contents of given file
get "/:file_name/edit" do
  redirect_if_not_authorized
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

# Write changes to contents of given file
post "/:file_name/edit" do
  redirect_if_not_authorized
  path = File.join data_path, params[:file_name]

  IO.write(path, params[:file_contents])
  session[:success] = "#{params[:file_name]} has been updated."
  redirect "/"
end

# Delete given file from system
post "/:file_name/delete" do
  redirect_if_not_authorized
  path = File.join data_path, params[:file_name]

  File.delete(path)
  session[:success] = "#{params[:file_name]} was deleted."
  redirect "/"
end

def new_file_name(old_file_name)
  base, ext = old_file_name.split(".")
  if base.match(/_\d+/)
    name, num = base.split("_")
    base = "#{name}_#{num.to_i + 1}"
  else
    base += "_1"
  end

  "#{base}.#{ext}"
end

# Duplicate given file
post "/:file_name/duplicate" do
  redirect_if_not_authorized

  new_file = new_file_name(params[:file_name])
  path = File.join data_path, new_file

  File.new(path, "w+")
  session[:success] = "#{new_file} was created."
  redirect "/"
end
