#!/usr/bin/env ruby

require 'yaml'
require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'

class ArticleLabelerLLM
  # Using Claude API for labeling
  CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'
  
  def initialize(article_file, api_key = nil)
    @article_file = article_file
    @article_data = YAML.load_file(article_file)
    @api_key = api_key || ENV['ANTHROPIC_API_KEY']
    
    if @api_key.nil? || @api_key.empty?
      raise "Please set ANTHROPIC_API_KEY environment variable or pass API key as argument"
    end
  end
  
  def analyze_and_label
    content = @article_data['content'] || ''
    title = @article_data['title'] || ''
    
    # Prepare the text for analysis
    article_text = "Title: #{title}\n\nContent: #{content[0..3000]}" # Limit content for API
    
    # Get labels from LLM
    labels = get_llm_labels(article_text)
    
    # Add labels to article data
    @article_data['labels'] = labels
    
    # Save updated article
    File.write(@article_file, @article_data.to_yaml)
    
    labels
  end
  
  private
  
  def get_llm_labels(text)
    prompt = <<~PROMPT
      Analyze this Swiss magazine article and extract relevant labels.
      
      Article:
      #{text}
      
      Please provide:
      1. LOCATIONS: List all mentioned locations (countries, Swiss cantons, cities, regions, landmarks). Be specific - if a Swiss city is mentioned, include it.
      
      2. CATEGORIES: Classify the article into relevant categories from the following structure. Select ALL that apply:
      
      Geography & Places: Swiss Cantons, Alpine Regions, Urban Centers, Border Areas, Lake Districts, Valley Communities, Mountain Peaks, European Destinations, Cross-Border Regions, Remote Locations, Accessibility & Transportation Hubs, UNESCO World Heritage Sites, Natural Parks & Reserves
      
      Culture & Arts: Traditional Crafts, Contemporary Art, Music & Concerts, Theater & Performance, Literature & Poetry, Photography & Visual Media, Cultural Festivals, Folk Traditions, Religious Heritage, Multicultural Communities, Language & Dialects, Design & Architecture, Street Art & Public Installations
      
      Travel & Transportation: Train Journeys, Hiking & Walking Routes, Cycling Paths, Public Transportation, Cable Cars & Funiculars, Road Trips, Accommodation & Hotels, Travel Planning, Seasonal Travel, Accessible Tourism, Adventure Sports, Budget Travel, Luxury Experiences
      
      History & Heritage: Medieval History, Industrial Heritage, Military History, Archaeological Sites, Historic Buildings, Political History, Social Movements, Immigration & Migration, Economic Development, Technological Innovation, Religious History, Family Histories, Preservation Efforts
      
      Nature & Outdoors: Mountain Landscapes, Water Bodies, Forests & Woodlands, Wildlife & Flora, Climate & Weather, Environmental Conservation, Outdoor Activities, Seasonal Changes, Natural Phenomena, Geological Features, Agriculture & Farming, Sustainable Living, Eco-Tourism
      
      Food & Drink: Traditional Cuisine, Regional Specialties, Wine & Viticulture, Local Markets, Restaurants & Dining, Food Festivals, Artisanal Products, Cooking Techniques, Food History, Modern Gastronomy, Seasonal Ingredients, Food Culture & Customs, Beverages & Spirits
      
      People & Profiles: Local Artisans, Cultural Figures, Historical Personalities, Community Leaders, Entrepreneurs, Artists & Creators, Scientists & Researchers, Political Figures, Immigrant Stories, Youth & Education, Elder Wisdom, Professional Profiles, Social Innovators
      
      Curiosities & Discoveries: Hidden Gems, Unusual Traditions, Scientific Discoveries, Archaeological Finds, Mysterious Places, Quirky Architecture, Local Legends, Surprising Statistics, Forgotten Stories, Modern Mysteries, Cultural Oddities, Unexpected Connections
      
      Events & Seasonal: Annual Festivals, Cultural Celebrations, Seasonal Activities, Holiday Traditions, Temporary Exhibitions, Sporting Events, Markets & Fairs, Religious Observances, Contemporary Events, Recurring Gatherings, Weather-Dependent Activities, Calendar Highlights, Community Gatherings
      
      Lifestyle & Society: Urban Development, Social Trends, Technology & Innovation, Education & Learning, Healthcare & Wellness, Work & Economy, Housing & Living, Transportation Trends, Environmental Awareness, Cultural Integration, Generational Changes, Quality of Life, Future Planning
      
      3. KEYWORDS: Extract 5-10 specific keywords that capture the essence of the article (in the original language where appropriate)
      
      Format your response as JSON:
      {
        "locations": [
          {"type": "country", "name": "Switzerland"},
          {"type": "canton", "name": "Zürich"},
          {"type": "city", "name": "Basel"},
          {"type": "region", "name": "Alps"}
        ],
        "categories": {
          "geography_places": ["Swiss Cantons", "Alpine Regions"],
          "culture_arts": ["Traditional Crafts"],
          "travel_transportation": ["Train Journeys"],
          "history_heritage": [],
          "nature_outdoors": ["Mountain Landscapes"],
          "food_drink": [],
          "people_profiles": [],
          "curiosities_discoveries": [],
          "events_seasonal": [],
          "lifestyle_society": []
        },
        "keywords": ["keyword1", "keyword2"]
      }
      
      Be thorough but precise. Only include locations that are actually mentioned in the text. For categories, only include labels that are directly relevant to the content.
    PROMPT
    
    response = call_claude_api(prompt)
    parse_llm_response(response)
  rescue => e
    puts "Error calling LLM: #{e.message}"
    # Fallback to empty labels if API fails
    { 'locations' => [], 'topics' => [], 'keywords' => [] }
  end
  
  def call_claude_api(prompt)
    uri = URI.parse(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'
    
    request.body = {
      model: 'claude-3-haiku-20240307',
      max_tokens: 1000,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    }.to_json
    
    response = http.request(request)
    
    if response.code != '200'
      raise "API request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body)
  end
  
  def parse_llm_response(response)
    # Extract the content from Claude's response
    content = response.dig('content', 0, 'text') || ''
    
    # Try to parse JSON from the response
    json_match = content.match(/\{.*\}/m)
    if json_match
      begin
        result = JSON.parse(json_match[0])
        return {
          'locations' => result['locations'] || [],
          'categories' => result['categories'] || {},
          'keywords' => result['keywords'] || []
        }
      rescue JSON::ParserError
        puts "Failed to parse JSON from LLM response"
      end
    end
    
    # Fallback parsing if JSON extraction fails
    { 'locations' => [], 'categories' => {}, 'keywords' => [] }
  end
end

# Alternative: Using OpenAI API
class ArticleLabelerOpenAI
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  
  def initialize(article_file, api_key = nil)
    @article_file = article_file
    @article_data = YAML.load_file(article_file)
    @api_key = api_key || ENV['OPENAI_API_KEY']
    
    if @api_key.nil? || @api_key.empty?
      raise "Please set OPENAI_API_KEY environment variable or pass API key as argument"
    end
  end
  
  def analyze_and_label
    content = @article_data['content'] || ''
    title = @article_data['title'] || ''
    
    article_text = "Title: #{title}\n\nContent: #{content[0..3000]}"
    
    labels = get_llm_labels(article_text)
    
    @article_data['labels'] = labels
    File.write(@article_file, @article_data.to_yaml)
    
    labels
  end
  
  private
  
  def get_llm_labels(text)
    prompt = <<~PROMPT
      Analyze this Swiss magazine article and extract relevant labels.
      
      Article:
      #{text}
      
      Please provide:
      1. LOCATIONS: List all mentioned locations (countries, Swiss cantons, cities, regions, landmarks)
      2. TOPICS: Identify main topics from: food, culture, nature, history, architecture, people, transportation, wildlife, art, music, sports, religion, economy, technology, language, travel, tourism, tradition, education, health, politics, environment, agriculture, industry, literature, theater, fashion, photography
      3. KEYWORDS: Extract 5-10 specific keywords that capture the essence
      
      Return as JSON:
      {
        "locations": [{"type": "country", "name": "Switzerland"}],
        "topics": ["food", "culture"],
        "keywords": ["keyword1", "keyword2"]
      }
    PROMPT
    
    response = call_openai_api(prompt)
    parse_openai_response(response)
  rescue => e
    puts "Error calling OpenAI: #{e.message}"
    { 'locations' => [], 'categories' => {}, 'keywords' => [] }
  end
  
  def call_openai_api(prompt)
    uri = URI.parse(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    
    request.body = {
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: 'You are an expert at analyzing Swiss magazine articles and extracting location and topic labels. Always respond with valid JSON.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 500
    }.to_json
    
    response = http.request(request)
    
    if response.code != '200'
      raise "API request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body)
  end
  
  def parse_openai_response(response)
    content = response.dig('choices', 0, 'message', 'content') || ''
    
    begin
      result = JSON.parse(content)
      return {
        'locations' => result['locations'] || [],
        'topics' => result['topics'] || [],
        'keywords' => result['keywords'] || []
      }
    rescue JSON::ParserError
      puts "Failed to parse JSON from OpenAI response"
      { 'locations' => [], 'topics' => [], 'keywords' => [] }
    end
  end
end

# Local LLM option using Ollama
class ArticleLabelerOllama
  OLLAMA_API_URL = 'http://localhost:11434/api/generate'
  
  def initialize(article_file, model = 'llama2')
    @article_file = article_file
    @article_data = YAML.load_file(article_file)
    @model = model
  end
  
  def analyze_and_label
    content = @article_data['content'] || ''
    title = @article_data['title'] || ''
    
    article_text = "Title: #{title}\n\nContent: #{content[0..2000]}"
    
    labels = get_llm_labels(article_text)
    
    @article_data['labels'] = labels
    File.write(@article_file, @article_data.to_yaml)
    
    labels
  end
  
  private
  
  def get_llm_labels(text)
    prompt = <<~PROMPT
      Analyze this Swiss magazine article and extract labels.
      
      Article: #{text}
      
      Extract:
      1. All locations mentioned (countries, cities, regions)
      2. Categories from: Geography & Places, Culture & Arts, Travel & Transportation, History & Heritage, Nature & Outdoors, Food & Drink, People & Profiles, Curiosities & Discoveries, Events & Seasonal, Lifestyle & Society
      3. 5-10 keywords
      
      Format as JSON:
      {
        "locations": [{"type": "country", "name": "Switzerland"}],
        "categories": {
          "geography_places": ["label"],
          "culture_arts": [],
          "travel_transportation": [],
          "history_heritage": [],
          "nature_outdoors": [],
          "food_drink": [],
          "people_profiles": [],
          "curiosities_discoveries": [],
          "events_seasonal": [],
          "lifestyle_society": []
        },
        "keywords": ["keyword1", "keyword2"]
      }
    PROMPT
    
    response = call_ollama_api(prompt)
    parse_ollama_response(response)
  rescue => e
    puts "Error calling Ollama: #{e.message}"
    { 'locations' => [], 'categories' => {}, 'keywords' => [] }
  end
  
  def call_ollama_api(prompt)
    uri = URI.parse(OLLAMA_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      prompt: prompt,
      stream: false
    }.to_json
    
    response = http.request(request)
    
    if response.code != '200'
      raise "Ollama request failed: #{response.code}"
    end
    
    JSON.parse(response.body)
  end
  
  def parse_ollama_response(response)
    content = response['response'] || ''
    
    # Try to extract JSON from response
    json_match = content.match(/\{.*\}/m)
    if json_match
      begin
        result = JSON.parse(json_match[0])
        return {
          'locations' => parse_locations(result['locations']),
          'categories' => result['categories'] || {},
          'keywords' => result['keywords'] || []
        }
      rescue JSON::ParserError
        puts "Failed to parse JSON from Ollama response"
      end
    end
    
    { 'locations' => [], 'categories' => {}, 'keywords' => [] }
  end
  
  def parse_locations(locations)
    return [] unless locations.is_a?(Array)
    
    locations.map do |loc|
      if loc.is_a?(Hash)
        loc
      elsif loc.is_a?(String)
        { 'type' => 'unknown', 'name' => loc }
      else
        nil
      end
    end.compact
  end
end

# Process articles
def process_magazine_articles(magazine_dir, llm_provider = 'ollama')
  article_files = Dir.glob(File.join(magazine_dir, '*.yaml')).reject { |f| f.include?('summary.yaml') }
  
  puts "Processing #{article_files.length} articles in #{File.basename(magazine_dir)} using #{llm_provider}..."
  
  article_files.each_with_index do |article_file, idx|
    begin
      labeler = case llm_provider.downcase
      when 'claude'
        ArticleLabelerLLM.new(article_file)
      when 'openai'
        ArticleLabelerOpenAI.new(article_file)
      when 'ollama'
        ArticleLabelerOllama.new(article_file)
      else
        raise "Unknown LLM provider: #{llm_provider}"
      end
      
      labels = labeler.analyze_and_label
      
      puts "  [#{idx+1}/#{article_files.length}] #{File.basename(article_file)}:"
      puts "    Locations: #{labels['locations'].map { |l| l.is_a?(Hash) ? l['name'] : l }.join(', ')}"
      
      # Display categories with values
      categories_display = labels['categories'].select { |k, v| v&.any? }.map { |k, v| "#{k}: #{v.join(', ')}" }
      puts "    Categories: #{categories_display.join(' | ')}"
      
      puts "    Keywords: #{labels['keywords'].join(', ')}"
      
      # Rate limiting for API calls
      sleep(0.5) if llm_provider != 'ollama'
    rescue => e
      puts "  Error processing #{File.basename(article_file)}: #{e.message}"
    end
  end
end

# Main execution
magazine_arg = ARGV[0] || 'all'
llm_provider = ARGV[1] || 'claude'

if ARGV.include?('--help') || ARGV.include?('-h')
  puts "Usage: ruby label_articles_llm.rb [magazine_directory] [llm_provider]"
  puts ""
  puts "Defaults: ruby label_articles_llm.rb all claude"
  puts ""
  puts "LLM providers: claude (default), openai, ollama"
  puts ""
  puts "For Claude: set ANTHROPIC_API_KEY environment variable"
  puts "For OpenAI: set OPENAI_API_KEY environment variable"
  puts "For Ollama: ensure Ollama is running locally with a model installed"
  exit 1
end

if magazine_arg == 'all'
  magazine_dirs = Dir.glob('/home/hanz/panter/transhelvetica/magazines/*_articles')
  
  magazine_dirs.each do |dir|
    process_magazine_articles(dir, llm_provider)
    puts "---"
  end
else
  unless Dir.exist?(magazine_arg)
    puts "Error: Directory '#{magazine_arg}' not found"
    exit 1
  end
  
  process_magazine_articles(magazine_arg, llm_provider)
end

puts "\nLLM-based labeling complete!"