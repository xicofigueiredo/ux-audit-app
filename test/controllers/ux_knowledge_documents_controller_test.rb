require "test_helper"

class UxKnowledgeDocumentsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get ux_knowledge_documents_index_url
    assert_response :success
  end

  test "should get show" do
    get ux_knowledge_documents_show_url
    assert_response :success
  end

  test "should get search" do
    get ux_knowledge_documents_search_url
    assert_response :success
  end
end
