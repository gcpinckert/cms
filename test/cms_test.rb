ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "history.txt"
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_file_contents
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Edgar Allan Poe"
    assert_includes last_response.body, "His heart which trembles at the beam"
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
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>By Emily Elizabeth Dickinson</h2>"
    assert_includes last_response.body, "<p>It&#39;s <em>sorer to believe</em>!</p>\n"
  end

  def test_edit_content
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, '<input type="submit"'
  end

  def test_updated_content
    post "/changes.txt/edit", file_contents: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end
