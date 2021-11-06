require "sinatra"
require "sinatra/reloader" if development?


get "/" do
  "Getting started"
end