#!/usr/bin/env ruby

require 'pg'
require 'yaml'
require 'dotenv/load'

class DatabaseSetup
  def initialize(connection_string = nil)
    @connection_string = connection_string || ENV['DATABASE_URL']
    raise "Please provide a DATABASE_URL environment variable or pass connection string" unless @connection_string
  end

  def create_schema
    conn = connect_to_db
    
    puts "Creating database schema..."
    
    # Drop existing tables if they exist (be careful with this in production!)
    drop_sql = <<-SQL
      DROP TABLE IF EXISTS article_questions CASCADE;
      DROP TABLE IF EXISTS article_keywords CASCADE;
      DROP TABLE IF EXISTS article_categories CASCADE;
      DROP TABLE IF EXISTS article_topics CASCADE;
      DROP TABLE IF EXISTS article_locations CASCADE;
      DROP TABLE IF EXISTS article_images CASCADE;
      DROP TABLE IF EXISTS article_pages CASCADE;
      DROP TABLE IF EXISTS articles CASCADE;
      DROP TABLE IF EXISTS magazines CASCADE;
    SQL
    
    schema_sql = <<-SQL
      -- Main magazines table
      CREATE TABLE magazines (
          id SERIAL PRIMARY KEY,
          code VARCHAR(50) UNIQUE NOT NULL,
          magazine_number INTEGER,
          title VARCHAR(255),
          publication_date DATE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Articles table
      CREATE TABLE articles (
          id SERIAL PRIMARY KEY,
          magazine_id INTEGER REFERENCES magazines(id) ON DELETE CASCADE,
          title VARCHAR(500) NOT NULL,
          start_page INTEGER,
          content TEXT,
          filename VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Article pages (many-to-many relationship)
      CREATE TABLE article_pages (
          id SERIAL PRIMARY KEY,
          article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
          page_number INTEGER NOT NULL,
          UNIQUE(article_id, page_number)
      );

      -- Article images
      CREATE TABLE article_images (
          id SERIAL PRIMARY KEY,
          article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
          image_index INTEGER,
          name VARCHAR(100),
          width INTEGER,
          height INTEGER,
          base64_data TEXT,
          description TEXT,
          position INTEGER,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Labels/metadata
      CREATE TABLE article_locations (
          id SERIAL PRIMARY KEY,
          article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
          location_type VARCHAR(50),
          name VARCHAR(255)
      );

      CREATE TABLE article_categories (
          id SERIAL PRIMARY KEY,
          article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
          category_type VARCHAR(50) NOT NULL,
          label VARCHAR(100) NOT NULL
      );

      CREATE TABLE article_keywords (
          id SERIAL PRIMARY KEY,
          article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
          keyword VARCHAR(255)
      );

      CREATE TABLE article_questions (
          id SERIAL PRIMARY KEY,
          article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
          question TEXT NOT NULL,
          question_order INTEGER,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Indexes for better search performance
      CREATE INDEX idx_magazines_number ON magazines(magazine_number);
      CREATE INDEX idx_articles_magazine_id ON articles(magazine_id);
      CREATE INDEX idx_article_pages_article_id ON article_pages(article_id);
      CREATE INDEX idx_article_images_article_id ON article_images(article_id);
      CREATE INDEX idx_article_locations_article_id ON article_locations(article_id);
      CREATE INDEX idx_article_categories_article_id ON article_categories(article_id);
      CREATE INDEX idx_article_categories_type ON article_categories(category_type);
      CREATE INDEX idx_article_categories_label ON article_categories(label);
      CREATE INDEX idx_article_keywords_article_id ON article_keywords(article_id);
      CREATE INDEX idx_article_keywords_keyword ON article_keywords(keyword);
      CREATE INDEX idx_article_questions_article_id ON article_questions(article_id);

      -- Full text search on content (using German dictionary)
      CREATE INDEX idx_articles_content_fts ON articles USING gin(to_tsvector('german', content));
      CREATE INDEX idx_article_questions_fts ON article_questions USING gin(to_tsvector('german', question));
    SQL
    
    begin
      # Ask for confirmation before dropping tables
      print "This will DROP and recreate all tables. Are you sure? (yes/no): "
      confirmation = gets.chomp.downcase
      
      if confirmation == 'yes'
        conn.exec(drop_sql)
        puts "Existing tables dropped."
        
        conn.exec(schema_sql)
        puts "Database schema created successfully!"
      else
        puts "Operation cancelled."
      end
    rescue PG::Error => e
      puts "Error creating schema: #{e.message}"
    ensure
      conn.close if conn
    end
  end
  
  def test_connection
    conn = connect_to_db
    puts "Successfully connected to database!"
    
    # Get database info
    result = conn.exec("SELECT current_database(), current_user, version()")
    result.each do |row|
      puts "Database: #{row['current_database']}"
      puts "User: #{row['current_user']}"
      puts "PostgreSQL version: #{row['version']}"
    end
    
    conn.close
  rescue PG::Error => e
    puts "Connection failed: #{e.message}"
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

# Usage example:
if __FILE__ == $0
  # You can pass connection string as argument or use environment variable
  # Format: postgres://username:password@host:port/database?sslmode=require
  
  connection_string = ARGV[0]
  
  setup = DatabaseSetup.new(connection_string)
  
  puts "Testing connection..."
  setup.test_connection
  
  puts "\nDo you want to create the database schema? (yes/no)"
  if gets.chomp.downcase == 'yes'
    setup.create_schema
  end
end