#!/usr/bin/env ruby

require 'yaml'
require 'base64'
require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require 'dotenv/load'

class ImageDescriber
  def initialize(api_key = nil)
    @api_key = api_key || ENV['ANTHROPIC_API_KEY']
    if @api_key.nil? || @api_key.empty?
      puts "Error: ANTHROPIC_API_KEY environment variable not set"
      puts "Set it with: export ANTHROPIC_API_KEY=your_api_key_here"
      exit 1
    end

    @processed_count = 0
    @skipped_count = 0
    @error_count = 0
  end

  def process_directory(articles_dir)
    unless Dir.exist?(articles_dir)
      puts "Error: Directory '#{articles_dir}' not found"
      exit 1
    end

    puts "Processing images in: #{articles_dir}"

    # Find all YAML files except summary
    yaml_files = Dir.glob(File.join(articles_dir, "*.yaml")).reject { |f| File.basename(f) == 'summary.yaml' }

    puts "Found #{yaml_files.length} article files"

    yaml_files.each_with_index do |file_path, idx|
      puts "\n[#{idx + 1}/#{yaml_files.length}] Processing: #{File.basename(file_path)}"
      process_article_file(file_path)
    end

    puts "\n=== Summary ==="
    puts "Images processed: #{@processed_count}"
    puts "Images skipped: #{@skipped_count}"
    puts "Errors: #{@error_count}"
  end

  def process_article_file(file_path)
    begin
      data = YAML.load_file(file_path)

      # Skip if no images
      unless data['images'] && !data['images'].empty?
        puts "  No images found"
        return
      end

      puts "  Found #{data['images'].length} images"
      modified = false

      data['images'].each_with_index do |image, idx|
        puts "    Processing image #{idx + 1}/#{data['images'].length}..."

        # Skip if image already has description instead of base64
        if image['description'] && !image['base64']
          puts "      Already has description, skipping"
          @skipped_count += 1
          next
        end

        # Skip if no base64 data
        unless image['base64']
          puts "      No base64 data found, skipping"
          @skipped_count += 1
          next
        end

        # Get description from Claude
        description = describe_image(image['base64'], data['title'], image)

        if description
          # Replace all image data with just the description
          image.clear
          image['description'] = description
          modified = true
          @processed_count += 1
          puts "      ✓ Described successfully"
        else
          puts "      ✗ Failed to get description"
          @error_count += 1
        end
      end

      # Save the modified file
      if modified
        File.write(file_path, data.to_yaml)
        puts "  ✓ File updated"
      end

    rescue => e
      puts "  Error processing file: #{e.message}"
      @error_count += 1
    end
  end

  def describe_image(base64_data, article_title, image_metadata)
    begin
      # Create context for better descriptions
      context = "This image is from a Swiss magazine article"
      context += " titled '#{article_title}'" if article_title && !article_title.empty?
      context += " on page #{image_metadata['page']}" if image_metadata['page']
      context += ". The image dimensions are #{image_metadata['width']}x#{image_metadata['height']} pixels" if image_metadata['width'] && image_metadata['height']
      context += "."

      prompt = "#{context}\n\nProvide a brief, focused description of what is clearly visible in this image. Keep it under 100 words and focus only on:\n- Main subject or objects shown\n- Basic setting (indoor/outdoor, type of location)\n- Any readable text if prominent\n\nBe concise and factual. Describe only what you can clearly see:"

      # Prepare API request
      uri = URI('https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60
      http.open_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = @api_key
      request['anthropic-version'] = '2023-06-01'

      body = {
        model: 'claude-3-haiku-20240307',
        max_tokens: 300,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'text',
              text: prompt
            },
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: 'image/jpeg',
                data: base64_data
              }
            }
          ]
        }]
      }

      request.body = body.to_json

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        if result['content'] && result['content'][0] && result['content'][0]['text']
          return result['content'][0]['text'].strip
        else
          puts "        Unexpected API response format"
          return nil
        end
      else
        puts "        API Error: #{response.code} - #{response.body}"
        return nil
      end

    rescue => e
      puts "        Error calling Claude API: #{e.message}"
      return nil
    end
  end
end

# Main execution
def process_all_magazines
  magazine_dirs = Dir.glob('magazines/*_articles')

  if magazine_dirs.empty?
    puts "No article directories found in magazines/"
    puts "Make sure to run split_magazine.rb first"
    exit 1
  end

  puts "Found #{magazine_dirs.length} magazine article directories to process"

  describer = ImageDescriber.new

  magazine_dirs.each do |dir|
    puts "\n" + "="*60
    describer.process_directory(dir)
  end
end

# Check command line arguments
if ARGV.empty? || ARGV[0] == 'all'
  # Process all magazines
  process_all_magazines
else
  # Process specific directory
  articles_dir = ARGV[0]
  describer = ImageDescriber.new
  describer.process_directory(articles_dir)
end