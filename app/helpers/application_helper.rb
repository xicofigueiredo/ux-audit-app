module ApplicationHelper
  def markdown_to_html(text)
    renderer = Redcarpet::Render::HTML.new
    markdown = Redcarpet::Markdown.new(renderer)
    sanitize(markdown.render(text.to_s))
  end
end
