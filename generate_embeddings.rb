#!/usr/bin/env ruby

require 'pg'
require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'

class EmbeddingsGenerator
  # Using Voyage AI (Anthropic's recommended embeddings provider)
  # Alternative: Can also use OpenAI by setting EMBEDDING_PROVIDER=openai
  VOYAGE_API_URL = 'https://api.voyageai.com/v1/embeddings'
  OPENAI_API_URL = 'https://api.openai.com/v1/embeddings'

  # Model options
  VOYAGE_MODEL = 'voyage-2' # or 'voyage-large-2' for better quality
  OPENAI_MODEL = 'text-embedding-3-small'

  BATCH_SIZE = 100

  def initialize(connection_string = nil, api_key = nil, provider = nil)
    @connection_string = connection_string || ENV['DATABASE_URL']
    @provider = provider || ENV['EMBEDDING_PROVIDER'] || 'voyage' # default to voyage

    # Select appropriate API key based on provider
    if @provider == 'openai'
      @api_key = api_key || ENV['OPENAI_API_KEY']
      raise "Please set OPENAI_API_KEY environment variable or pass API key as argument" if @api_key.nil? || @api_key.empty?
    else # voyage
      @api_key = api_key || ENV['VOYAGE_API_KEY']
      raise "Please set VOYAGE_API_KEY environment variable or pass API key as argument" if @api_key.nil? || @api_key.empty?
    end

    raise "Please provide a DATABASE_URL environment variable or pass connection string" unless @connection_string

    @conn = connect_to_db
    setup_embeddings_table
  end

  def generate_all_embeddings
    puts "Starting embeddings generation..."

    # Get all articles with their metadata
    articles = fetch_articles_data
    puts "Found #{articles.length} articles to process"

    # Process articles in batches
    articles.each_slice(BATCH_SIZE) do |batch|
      process_batch(batch)
    end

    puts "Embeddings generation completed!"
  end

  def generate_embeddings_for_article(article_id)
    puts "Generating embeddings for article #{article_id}..."

    articles = fetch_articles_data("WHERE articles.id = #{article_id}")
    return if articles.empty?

    process_batch(articles)
    puts "Embeddings generated for article #{article_id}"
  end

  def close_connection
    @conn.close if @conn
  end

  private

  def connect_to_db
    PG.connect(@connection_string)
  rescue PG::Error => e
    puts "Database connection failed: #{e.message}"
    exit 1
  end

  def setup_embeddings_table
    # Create embeddings table if it doesn't exist
    @conn.exec <<~SQL
      CREATE TABLE IF NOT EXISTS article_embeddings (
        id SERIAL PRIMARY KEY,
        article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
        embedding_text TEXT NOT NULL,
        embedding_vector REAL[] NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(article_id)
      );
    SQL

    # Create index for faster similarity searches (if using pgvector extension)
    begin
      @conn.exec "CREATE INDEX IF NOT EXISTS article_embeddings_vector_idx ON article_embeddings USING ivfflat (embedding_vector vector_cosine_ops);"
    rescue PG::Error
      # Fallback to regular index if pgvector is not available
      puts "Note: pgvector extension not available. Consider installing it for better vector search performance."
    end
  end

  def fetch_articles_data(where_clause = "")
    query = <<~SQL
      SELECT
        magazines.magazine_number,
        articles.id as article_id,
        articles.title,
        articles.start_page,
        articles.end_page,
        COALESCE(
          ARRAY_AGG(DISTINCT article_questions.question)
            FILTER (WHERE article_questions.question IS NOT NULL),
          '{}'
        ) AS questions,
        COALESCE(
          ARRAY_AGG(DISTINCT article_locations.location_type || ':' || article_locations.name)
            FILTER (WHERE article_locations.name IS NOT NULL),
          '{}'
        ) AS locations,
        COALESCE(
          ARRAY_AGG(DISTINCT article_categories.label)
            FILTER (WHERE article_categories.label IS NOT NULL),
          '{}'
        ) AS categories,
        COALESCE(
          ARRAY_AGG(DISTINCT article_keywords.keyword)
            FILTER (WHERE article_keywords.keyword IS NOT NULL),
          '{}'
        ) AS keywords,
        articles.content
      FROM articles
      JOIN magazines ON articles.magazine_id = magazines.id
      LEFT JOIN article_questions ON article_questions.article_id = articles.id
      LEFT JOIN article_locations ON article_locations.article_id = articles.id
      LEFT JOIN article_categories ON article_categories.article_id = articles.id
      LEFT JOIN article_keywords ON article_keywords.article_id = articles.id
      #{where_clause}
      GROUP BY magazines.magazine_number, articles.id, articles.title, articles.start_page, articles.end_page, articles.content
      ORDER BY magazines.magazine_number, articles.start_page
    SQL

    result = @conn.exec(query)
    result.map { |row| row }
  end

  def process_batch(articles)
    puts "Processing batch of #{articles.length} articles..."

    # Prepare texts for embedding
    texts_to_embed = articles.map { |article| prepare_embedding_text(article) }

    # Generate embeddings via OpenAI API
    embeddings = get_embeddings(texts_to_embed)

    # Store embeddings in database
    articles.each_with_index do |article, index|
      store_embedding(article['article_id'], texts_to_embed[index], embeddings[index])
    end

    puts "Batch processed successfully"
  end

  def prepare_embedding_text(article)
    # Combine all relevant text for embedding
    parts = []

    # Add title with emphasis
    parts << "Title: #{article['title']}" if article['title'] && !article['title'].empty?

    # Add magazine context
    parts << "Magazine: #{article['magazine_number']}, Pages: #{article['start_page']}-#{article['end_page']}"

    # Add categories
    if article['categories'] && !article['categories'].empty?
      categories = article['categories'].gsub(/[{}"]/, '').split(',').map(&:strip).reject(&:empty?)
      parts << "Categories: #{categories.join(', ')}" unless categories.empty?
    end

    # Add locations
    if article['locations'] && !article['locations'].empty?
      locations = article['locations'].gsub(/[{}"]/, '').split(',').map(&:strip).reject(&:empty?)
      parts << "Locations: #{locations.join(', ')}" unless locations.empty?
    end

    # Add keywords
    if article['keywords'] && !article['keywords'].empty?
      keywords = article['keywords'].gsub(/[{}"]/, '').split(',').map(&:strip).reject(&:empty?)
      parts << "Keywords: #{keywords.join(', ')}" unless keywords.empty?
    end

    # Add questions
    if article['questions'] && !article['questions'].empty?
      questions = article['questions'].gsub(/[{}"]/, '').split(',').map(&:strip).reject(&:empty?)
      parts << "Related Questions: #{questions.join(' ')}" unless questions.empty?
    end

    # Add content (truncated for embedding efficiency)
    if article['content'] && !article['content'].empty?
      content = article['content'][0..2000] # Limit content length
      parts << "Content: #{content}"
    end

    parts.join("\n\n")
  end

  def get_embeddings(texts)
    if @provider == 'openai'
      get_openai_embeddings(texts)
    else
      get_voyage_embeddings(texts)
    end
  end

  def get_voyage_embeddings(texts)
    uri = URI(VOYAGE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'

    request.body = {
      input: texts,
      model: VOYAGE_MODEL
    }.to_json

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      data['data'].map { |item| item['embedding'] }
    else
      puts "Error generating Voyage embeddings: #{response.code} - #{response.body}"
      raise "Failed to generate embeddings"
    end
  end

  def get_openai_embeddings(texts)
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'

    request.body = {
      input: texts,
      model: OPENAI_MODEL
    }.to_json

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      data['data'].map { |item| item['embedding'] }
    else
      puts "Error generating OpenAI embeddings: #{response.code} - #{response.body}"
      raise "Failed to generate embeddings"
    end
  end

  def store_embedding(article_id, text, embedding)
    # Convert embedding array to PostgreSQL array format
    embedding_str = "{#{embedding.join(',')}}"

    # Insert or update embedding
    @conn.exec_params(<<~SQL, [article_id, text, embedding_str])
      INSERT INTO article_embeddings (article_id, embedding_text, embedding_vector)
      VALUES ($1, $2, $3)
      ON CONFLICT (article_id)
      DO UPDATE SET
        embedding_text = EXCLUDED.embedding_text,
        embedding_vector = EXCLUDED.embedding_vector,
        updated_at = CURRENT_TIMESTAMP
    SQL
  end
end

# Main execution
if __FILE__ == $0
  begin
    # Display provider info
    provider = ENV['EMBEDDING_PROVIDER'] || 'voyage'
    puts "Using #{provider} for embeddings generation"
    puts "Set EMBEDDING_PROVIDER=openai to use OpenAI instead" if provider == 'voyage'
    puts ""

    generator = EmbeddingsGenerator.new

    # Check command line arguments
    if ARGV.length > 0 && ARGV[0] =~ /^\d+$/
      # Generate embeddings for specific article
      article_id = ARGV[0].to_i
      generator.generate_embeddings_for_article(article_id)
    else
      # Generate embeddings for all articles
      generator.generate_all_embeddings
    end

  rescue => e
    puts "Error: #{e.message}"
    puts ""
    puts "Note: This script requires one of the following:"
    puts "  - VOYAGE_API_KEY environment variable (default, recommended by Anthropic)"
    puts "  - OPENAI_API_KEY with EMBEDDING_PROVIDER=openai"
    exit 1
  ensure
    generator&.close_connection
  end
end