require 'pdf-reader'
require 'yaml'

Dir.glob('magazines/*.pdf').each do |pdf_path|
  yaml_path = pdf_path.sub(/\.pdf$/i, '.yaml')
  reader = PDF::Reader.new(pdf_path)
  pages = reader.pages.map.with_index do |page, idx|
    { 'page' => idx + 1, 'text' => page.text }
  end
  yaml_data = { 'pages' => pages }
  File.write(yaml_path, yaml_data.to_yaml)
  puts "YAML file created at #{yaml_path}"
end