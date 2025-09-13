#!/usr/bin/env ruby

require 'pg'
require 'yaml'
require 'fileutils'
require 'dotenv/load'

class ArticleImporter
  def initialize(connection_string = nil)
    @connection_string = connection_string || ENV['DATABASE_URL']
    raise "Please provide a DATABASE_URL environment variable or pass connection string" unless @connection_string
    @conn = connect_to_db
  end
  
  def import_all
    magazines_dir = File.join(File.dirname(__FILE__), 'magazines')
    
    # First, import magazines
    Dir.glob(File.join(magazines_dir, 'trnshlvtc*.yaml')).each do |magazine_file|
      next if magazine_file.include?('_articles')
      import_magazine(magazine_file)
    end
    
    # Then, import articles for each magazine
    Dir.glob(File.join(magazines_dir, '*_articles')).each do |articles_dir|
      import_articles_from_directory(articles_dir)
    end
    
    puts "Import completed!"
  ensure
    @conn.close if @conn
  end
  
  def import_magazine(magazine_file)
    magazine_code = File.basename(magazine_file, '.yaml')
    
    # Extract magazine number from code (last 2 digits)
    # e.g., trnshlvtc01 -> 1, trnshlvtc12 -> 12
    magazine_number = magazine_code[-2..-1].to_i
    
    begin
      data = YAML.load_file(magazine_file) if File.exist?(magazine_file)
      
      # Insert or update magazine
      result = @conn.exec_params(
        "INSERT INTO magazines (code, magazine_number, title) VALUES ($1, $2, $3) 
         ON CONFLICT (code) DO UPDATE SET 
           magazine_number = EXCLUDED.magazine_number,
           title = EXCLUDED.title
         RETURNING id",
        [magazine_code, magazine_number, data&.dig('title') || magazine_code]
      )
      
      magazine_id = result[0]['id']
      puts "Imported magazine: #{magazine_code} (Number: #{magazine_number}, ID: #{magazine_id})"
      
    rescue => e
      puts "Error importing magazine #{magazine_file}: #{e.message}"
    end
  end
  
  def import_articles_from_directory(articles_dir)
    magazine_code = File.basename(articles_dir).sub('_articles', '')
    
    # Extract magazine number from code (last 2 digits)
    magazine_number = magazine_code[-2..-1].to_i
    
    # Get magazine_id
    result = @conn.exec_params(
      "SELECT id FROM magazines WHERE code = $1",
      [magazine_code]
    )
    
    if result.ntuples == 0
      puts "Magazine #{magazine_code} not found. Creating it..."
      result = @conn.exec_params(
        "INSERT INTO magazines (code, magazine_number) VALUES ($1, $2) RETURNING id",
        [magazine_code, magazine_number]
      )
    end
    
    magazine_id = result[0]['id']
    
    # Import each article YAML file
    Dir.glob(File.join(articles_dir, '*.yaml')).each do |article_file|
      next if File.basename(article_file) == 'summary.yaml'
      import_article(article_file, magazine_id)
    end
  end
  
  def import_article(article_file, magazine_id)
    begin
      data = YAML.load_file(article_file)
      filename = File.basename(article_file)
      
      # Begin transaction for this article
      @conn.exec("BEGIN")
      
      # Calculate end_page from pages array
      end_page = data['pages'] && data['pages'].any? ? data['pages'].max : data['start_page']

      # Insert article
      result = @conn.exec_params(
        "INSERT INTO articles (magazine_id, title, start_page, end_page, content, filename)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id",
        [magazine_id, data['title'], data['start_page'], end_page, data['content'], filename]
      )
      
      article_id = result[0]['id']
      
      # Insert pages
      if data['pages']
        data['pages'].each do |page_num|
          @conn.exec_params(
            "INSERT INTO article_pages (article_id, page_number) VALUES ($1, $2)",
            [article_id, page_num]
          )
        end
      end
      
      # Insert images
      if data['images']
        data['images'].each_with_index do |image, idx|
          @conn.exec_params(
            "INSERT INTO article_images (article_id, image_index, name, width, height, base64_data, description, position) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            [
              article_id,
              image['index'],
              image['name'],
              image['width'],
              image['height'],
              image['base64'],
              image['description'],
              idx
            ]
          )
        end
      end
      
      # Insert labels/metadata
      if data['labels']
        # Locations
        if data['labels']['locations']
          data['labels']['locations'].each do |location|
            @conn.exec_params(
              "INSERT INTO article_locations (article_id, location_type, name) VALUES ($1, $2, $3)",
              [article_id, location['type'], location['name']]
            )
          end
        end
        
        # Categories
        if data['labels']['categories']
          data['labels']['categories'].each do |category_type, labels|
            labels.each do |label|
              @conn.exec_params(
                "INSERT INTO article_categories (article_id, category_type, label) VALUES ($1, $2, $3)",
                [article_id, category_type, label]
              )
            end
          end
        end
        
        # Keywords
        if data['labels']['keywords']
          data['labels']['keywords'].each do |keyword|
            @conn.exec_params(
              "INSERT INTO article_keywords (article_id, keyword) VALUES ($1, $2)",
              [article_id, keyword]
            )
          end
        end
      end
      
      # Insert questions
      if data['questions']
        data['questions'].each_with_index do |question, idx|
          @conn.exec_params(
            "INSERT INTO article_questions (article_id, question, question_order) VALUES ($1, $2, $3)",
            [article_id, question, idx + 1]
          )
        end
      end
      
      @conn.exec("COMMIT")
      puts "  Imported article: #{data['title']} (#{filename})"
      
    rescue => e
      @conn.exec("ROLLBACK")
      puts "  Error importing article #{article_file}: #{e.message}"
    end
  end
  
  def clear_all_data
    print "This will DELETE all data from the database. Are you sure? (yes/no): "
    confirmation = gets.chomp.downcase
    
    if confirmation == 'yes'
      @conn.exec("DELETE FROM magazines CASCADE")
      puts "All data cleared."
    else
      puts "Operation cancelled."
    end
  end
  
  private
  
  def connect_to_db
    if @connection_string.start_with?('postgres://', 'postgresql://')
      # Parse connection string
      require 'uri'
      uri = URI.parse(@connection_string)
      
      connection_params = {
        host: uri.host,
        port: uri.port || 5432,
        dbname: uri.path[1..-1],  # Remove leading slash
        user: uri.user,
        password: uri.password
      }
      
      # Add SSL mode if specified in query params
      if uri.query
        params = URI.decode_www_form(uri.query).to_h
        connection_params[:sslmode] = params['sslmode'] if params['sslmode']
      end
      
      PG.connect(connection_params)
    else
      # Assume it's already a hash or connection params
      PG.connect(@connection_string)
    end
  end
end

# Usage
if __FILE__ == $0
  connection_string = ARGV[0]
  
  importer = ArticleImporter.new(connection_string)
  
  puts "Article Importer"
  puts "1. Import all articles"
  puts "2. Clear all data"
  puts "3. Exit"
  print "Choose an option: "
  
  choice = gets.chomp
  
  case choice
  when '1'
    importer.import_all
  when '2'
    importer.clear_all_data
  else
    puts "Exiting..."
  end
end