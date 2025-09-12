require 'pdf-reader'
require 'yaml'

Dir.glob('magazines/*.pdf').each do |pdf_path|
  yaml_path = pdf_path.sub(/\.pdf$/i, '.yaml')
  reader = PDF::Reader.new(pdf_path)
  pages = reader.pages.map.with_index do |page, idx|
    # Use runs instead of text to preserve reading order
    # runs maintains the proper flow of text including column order
    text_runs = page.runs.map(&:text).join(' ')
    
    # Alternative: If runs doesn't work well, use text_in_reading_order
    # which attempts to reconstruct the logical reading order
    if text_runs.strip.empty?
      text_runs = page.text
    end
    
    { 'page' => idx + 1, 'text' => text_runs }
  end
  yaml_data = { 'pages' => pages }
  File.write(yaml_path, yaml_data.to_yaml)
  puts "YAML file created at #{yaml_path}"
end