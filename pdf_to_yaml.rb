require 'pdf-reader'
require 'yaml'
require 'base64'

Dir.glob('magazines/*.pdf').each do |pdf_path|
  yaml_path = pdf_path.sub(/\.pdf$/i, '.yaml')
  reader = PDF::Reader.new(pdf_path)

  # Extract images using basic pdf-reader approach
  all_images = []
  image_counter = 0

  pages = reader.pages.map.with_index do |page, idx|
    # Use runs instead of text to preserve reading order
    # runs maintains the proper flow of text including column order
    text_runs = page.runs.map(&:text).join(' ')

    # Alternative: If runs doesn't work well, use text_in_reading_order
    # which attempts to reconstruct the logical reading order
    if text_runs.strip.empty?
      text_runs = page.text
    end

    # Extract images from this page using manual approach
    page_images = []
    begin
      # Look for XObject images in the page resources
      xobjects = page.xobjects
      if xobjects
        xobjects.each do |name, stream|
          if stream.hash[:Subtype] == :Image
            image_counter += 1
            
            # Get basic image properties
            width = stream.hash[:Width] || 0
            height = stream.hash[:Height] || 0
            
            # Try to extract image data
            begin
              image_data = stream.data
              if image_data && !image_data.empty?
                base64_image = Base64.strict_encode64(image_data)
                page_images << {
                  'index' => image_counter,
                  'name' => name.to_s,
                  'width' => width,
                  'height' => height,
                  'base64' => base64_image
                }
                puts "Extracted image #{image_counter} from page #{idx + 1} (#{width}x#{height})"
              end
            rescue => img_error
              puts "Warning: Could not extract image data for #{name} on page #{idx + 1}: #{img_error.message}"
            end
          end
        end
      end
    rescue => e
      puts "Warning: Could not process images on page #{idx + 1}: #{e.message}"
    end

    page_data = { 'page' => idx + 1, 'text' => text_runs }
    page_data['images'] = page_images unless page_images.empty?
    page_data
  end
  yaml_data = { 'pages' => pages }
  File.write(yaml_path, yaml_data.to_yaml)
  puts "YAML file created at #{yaml_path}"
end