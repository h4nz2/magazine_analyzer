#!/usr/bin/env ruby

require 'pdf-reader'
require 'yaml'
require 'base64'

class SmartPDFExtractor
  def initialize(pdf_path)
    @pdf_path = pdf_path
    @reader = PDF::Reader.new(pdf_path)
    @image_counter = 0
  end

  def extract
    pages = @reader.pages.map.with_index do |page, idx|
      page_num = idx + 1
      puts "  Processing page #{page_num}/#{@reader.pages.length}..." if page_num % 10 == 0

      extract_page_content(page, page_num)
    end

    { 'pages' => pages }
  end

  private

  def extract_page_content(page, page_num)
    # Extract text using multiple strategies
    text_content = extract_text_smart(page, page_num)

    # Extract images
    page_images = extract_images(page, page_num)

    # Build page data
    page_data = {
      'page' => page_num,
      'text' => text_content
    }

    page_data['images'] = page_images unless page_images.empty?
    page_data
  end

  def extract_text_smart(page, page_num)
    # Strategy 1: Try the built-in text_in_reading_order if available
    if page.respond_to?(:text_in_reading_order)
      begin
        text = page.text_in_reading_order
        return text if text && !text.strip.empty? && looks_reasonable?(text)
      rescue => e
        # Silent fallback
      end
    end

    # Strategy 2: Use runs with intelligent sorting
    begin
      text = extract_from_runs(page)
      return text if text && !text.strip.empty? && looks_reasonable?(text)
    rescue => e
      # Silent fallback
    end

    # Strategy 3: Fall back to basic text extraction
    page.text
  end

  def extract_from_runs(page)
    runs = page.runs
    return nil if runs.nil? || runs.empty?

    # Determine if this is a multi-column layout
    if is_multi_column?(runs)
      extract_multi_column(runs)
    else
      extract_single_column(runs)
    end
  end

  def is_multi_column?(runs)
    # Analyze X distribution to detect columns
    x_positions = runs.map(&:x)
    x_min = x_positions.min
    x_max = x_positions.max
    x_range = x_max - x_min

    # Look for a gap in the middle that suggests columns
    mid_point = x_min + (x_range / 2)
    left_runs = runs.select { |r| r.x < mid_point - 20 }
    right_runs = runs.select { |r| r.x > mid_point + 20 }

    # If we have substantial content on both sides, it's likely multi-column
    left_runs.size > 10 && right_runs.size > 10 && x_range > 200
  end

  def extract_multi_column(runs)
    # Split runs into columns
    x_positions = runs.map(&:x)
    x_min = x_positions.min
    x_max = x_positions.max
    mid_point = x_min + ((x_max - x_min) / 2)

    left_column = runs.select { |r| r.x < mid_point }
    right_column = runs.select { |r| r.x >= mid_point }

    # Process each column
    left_text = process_column_runs(left_column)
    right_text = process_column_runs(right_column)

    # Combine columns (left first, then right for typical reading order)
    [left_text, right_text].reject(&:empty?).join("\n\n")
  end

  def extract_single_column(runs)
    process_column_runs(runs)
  end

  def process_column_runs(runs)
    return '' if runs.empty?

    # Sort by Y position (top to bottom), then X (left to right)
    # Note: PDF Y coordinates are bottom-up, so we use negative Y for top-to-bottom
    sorted_runs = runs.sort_by { |r| [-r.y.to_f, r.x.to_f] }

    # Group into lines based on Y position
    lines = []
    current_line = []
    last_y = nil
    line_threshold = 3 # Tolerance for same line detection

    sorted_runs.each do |run|
      y_pos = run.y.to_f

      if last_y && (last_y - y_pos).abs > line_threshold
        # New line detected
        unless current_line.empty?
          line_text = current_line.sort_by(&:x).map(&:text).join(' ')
          lines << line_text.strip
        end
        current_line = [run]
      else
        current_line << run
      end
      last_y = y_pos
    end

    # Add the last line
    unless current_line.empty?
      line_text = current_line.sort_by(&:x).map(&:text).join(' ')
      lines << line_text.strip
    end

    # Clean up and join lines
    lines.reject(&:empty?).join("\n")
  end

  def looks_reasonable?(text)
    # Basic heuristic to check if text extraction looks good
    return false if text.nil? || text.strip.empty?

    # Check for common issues
    lines = text.split("\n")

    # If we have mostly single characters or numbers per line, extraction likely failed
    single_char_lines = lines.count { |l| l.strip.length <= 2 }
    return false if lines.size > 5 && single_char_lines > lines.size * 0.7

    # If the text is just a jumble of numbers (like page numbers from TOC), it's likely bad
    numbers_only = text.gsub(/[\s\n]/, '').match?(/^\d+$/)
    return false if numbers_only && text.length > 20

    true
  end

  def extract_images(page, page_num)
    images = []

    begin
      xobjects = page.xobjects
      return images unless xobjects

      xobjects.each do |name, stream|
        next unless stream.hash[:Subtype] == :Image

        width = stream.hash[:Width] || 0
        height = stream.hash[:Height] || 0

        # Skip tiny images
        next if width < 10 || height < 10

        @image_counter += 1

        begin
          image_data = stream.data
          next if image_data.nil? || image_data.empty?

          base64_image = Base64.strict_encode64(image_data)

          images << {
            'index' => @image_counter,
            'name' => name.to_s,
            'width' => width,
            'height' => height,
            'base64' => base64_image,
            'page' => page_num
          }

          puts "  Extracted image #{@image_counter} from page #{page_num} (#{width}x#{height})"
        rescue => e
          puts "  Warning: Could not extract image #{name} on page #{page_num}: #{e.message}"
        end
      end
    rescue => e
      puts "  Warning: Could not process images on page #{page_num}: #{e.message}"
    end

    images
  end
end

# Main execution
def main
  magazine_dir = 'magazines'

  unless Dir.exist?(magazine_dir)
    puts "Error: Directory '#{magazine_dir}' not found"
    exit 1
  end

  pdf_files = Dir.glob(File.join(magazine_dir, '*.pdf'))

  if pdf_files.empty?
    puts "No PDF files found in #{magazine_dir}/"
    exit 1
  end

  puts "Found #{pdf_files.length} PDF file(s) to process"

  pdf_files.each do |pdf_path|
    yaml_path = pdf_path.sub(/\.pdf$/i, '.yaml')

    puts "\nProcessing: #{File.basename(pdf_path)}"

    begin
      extractor = SmartPDFExtractor.new(pdf_path)
      yaml_data = extractor.extract

      File.write(yaml_path, yaml_data.to_yaml)

      puts "✓ Successfully created: #{File.basename(yaml_path)}"
      puts "  Total pages: #{yaml_data['pages'].length}"

      # Count total images
      total_images = yaml_data['pages'].sum do |page|
        page['images'] ? page['images'].length : 0
      end
      puts "  Total images: #{total_images}"

    rescue => e
      puts "✗ Error processing #{File.basename(pdf_path)}: #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
    end
  end

  puts "\n=== Processing Complete ==="
end

# Run the script
main if __FILE__ == $0