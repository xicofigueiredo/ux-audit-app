module ApplicationHelper
  def markdown_to_html(text)
    renderer = Redcarpet::Render::HTML.new
    markdown = Redcarpet::Markdown.new(renderer)
    sanitize(markdown.render(text.to_s))
  end

  def frame_range_to_time(frame_ref)
    if frame_ref =~ /Frame(?:s)? (\d+)(?:-(\d+))?/i
      start_frame = $1.to_i
      end_frame = $2 ? $2.to_i : start_frame
      start_time = Time.at(start_frame - 1).utc.strftime('%-M:%S')
      end_time = Time.at(end_frame - 1).utc.strftime('%-M:%S')
      return start_time == end_time ? start_time : "#{start_time} - #{end_time}"
    end
    nil
  end
end
