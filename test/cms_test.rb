ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"
require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_file_contents
    create_document "history.txt", "This is a file about history."

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This is a file about history."
  end

  def test_error_for_nonexistent_file
    get "/notafile.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist."

    get "/"
    refute_includes last_response.body, "notafile.txt does not exist."
  end

  def test_markdown_file_contents
    create_document "/about.md", "## This will be a heading"

    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>This will be a heading</h2>"
  end

  def test_edit_content
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, '<input type="submit"'
  end

  def test_updated_content
    create_document "changes.txt", "old content"

    post "/changes.txt/edit", file_contents: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
    refute_includes last_response.body, "old content"
  end

  def test_new_doc_form
    get "/new"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, '<input type="text"'
    assert_includes last_response.body, '<input type="submit"'
  end

  def test_new_doc_created
    post "/new", new_file: "test.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt was created."

    get "/"
    assert_includes last_response.body, "test.txt"
    refute_includes last_response.body, "test.txt was created."
  end

  def test_error_without_filename
    post "/new", new_file: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_error_without_file_ext
    post "/new", new_file: "test"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A .txt or .md file extension must be provided."

    post "/new", new_file: "test.rb"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A .txt or .md file extension must be provided."
  end

  def test_delete_file
    create_document "test.txt"

    get "/"
    assert_includes last_response.body, '<form action="/test.txt/delete"'
    assert_includes last_response.body, '<button type="submit">Delete'

    post"/test.txt/delete"
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_includes last_response.body, "test.txt was deleted."
    refute_includes last_response.body, '<a href="/test.txt">test.txt</a>'
  end
end
