#!/usr/bin/env ruby

require 'yaml'
require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'

class ArticleLabeler
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

      Geography & Places: Swiss Cantons, Alpine Regions, Urban Centers, Border Areas, Lake Districts, Valley Communities, Mountain Peaks, European Destinations, Cross-Border Regions, Remote Locations, UNESCO World Heritage Sites, Natural Parks & Reserves, Schwyz, Wallis, Graubünden, Zürich, Bern, Tessin, Appenzell, Fribourg, International Locations

      Culture & Arts: Traditional Crafts, Contemporary Art, Music & Concerts, Theater & Performance, Literature & Poetry, Photography & Visual Media, Cultural Festivals, Folk Traditions, Religious Heritage, Multicultural Communities, Language & Dialects, Street Art & Public Installations, Museums, Exhibitions, Weberei & Stickerei, Schwingen, Traditional Handwork

      Travel & Tourism: Train Journeys, Hiking & Walking Routes, Cycling Paths, Public Transportation, Cable Cars & Funiculars, Road Trips, Accommodation & Hotels, Travel Planning, Seasonal Travel, Accessible Tourism, Adventure Sports, Budget Travel, Luxury Experiences, Alpinismus, Tourism Economy, International Relations, Traffic & Transport

      Nature & Outdoors: Mountain Landscapes, Water Bodies, Forests & Woodlands, Wildlife & Flora, Climate & Weather, Environmental Conservation, Outdoor Activities, Seasonal Changes, Natural Phenomena, Geological Features, Agriculture & Farming, Sustainable Living, Eco-Tourism, Waschbär, Alpine Animals, Animal Wildlife

      Food & Culinary: Traditional Cuisine, Regional Specialties, Wine & Viticulture, Local Markets, Restaurants & Dining, Food Festivals, Artisanal Products, Cooking Techniques, Food History, Modern Gastronomy, Seasonal Ingredients, Food Culture & Customs, Beverages & Spirits, Gastronomie, Culinary Specialties

      Architecture & Gardens: Garden Design, Historic Buildings, Modern Architecture, Landscape Architecture, Urban Planning, Religious Architecture, Industrial Architecture, Bridge & Infrastructure, Garden Art, Botanical Gardens, Park Design, Architectural Heritage

      People & Profiles: Local Artisans, Cultural Figures, Historical Personalities, Community Leaders, Entrepreneurs, Artists & Creators, Scientists & Researchers, Political Figures, Immigrant Stories, Youth & Education, Elder Wisdom, Professional Profiles, Social Innovators, Contemporary Actors, Authors & Writers

      History & Heritage: Medieval History, Industrial Heritage, Military History, Archaeological Sites, Historic Buildings, Political History, Social Movements, Immigration & Migration, Economic Development, Technological Innovation, Religious History, Family Histories, Preservation Efforts

      Symbols & Motifs: Cross & Religious Symbols, Animal Symbols, Landscape Motifs, Cultural Icons, National Symbols, Regional Emblems, Artistic Motifs, Traditional Patterns, Heraldic Symbols, Spiritual Symbols

      Society & Lifestyle: Urban Development, Social Trends, Technology & Innovation, Education & Learning, Healthcare & Wellness, Work & Economy, Housing & Living, Transportation Trends, Environmental Awareness, Cultural Integration, Generational Changes, Quality of Life, Future Planning, Language & Communication, Social Issues
      
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
          "travel_tourism": ["Train Journeys"],
          "nature_outdoors": ["Mountain Landscapes"],
          "food_culinary": [],
          "architecture_gardens": [],
          "people_profiles": [],
          "history_heritage": [],
          "symbols_motifs": [],
          "society_lifestyle": []
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


# Process articles
def process_magazine_articles(magazine_dir)
  article_files = Dir.glob(File.join(magazine_dir, '*.yaml')).reject { |f| f.include?('summary.yaml') }

  puts "Processing #{article_files.length} articles in #{File.basename(magazine_dir)} using Claude..."

  article_files.each_with_index do |article_file, idx|
    begin
      labeler = ArticleLabeler.new(article_file)
      labels = labeler.analyze_and_label

      puts "  [#{idx+1}/#{article_files.length}] #{File.basename(article_file)}:"
      puts "    Locations: #{labels['locations'].map { |l| l.is_a?(Hash) ? l['name'] : l }.join(', ')}"

      # Display categories with values
      categories_display = labels['categories'].select { |k, v| v&.any? }.map { |k, v| "#{k}: #{v.join(', ')}" }
      puts "    Categories: #{categories_display.join(' | ')}"

      puts "    Keywords: #{labels['keywords'].join(', ')}"

      # Rate limiting for API calls
      sleep(0.5)
    rescue => e
      puts "  Error processing #{File.basename(article_file)}: #{e.message}"
    end
  end
end

# Main execution
magazine_arg = ARGV[0] || 'all'

if ARGV.include?('--help') || ARGV.include?('-h')
  puts "Usage: ruby label_articles_llm.rb [magazine_directory]"
  puts ""
  puts "Defaults: ruby label_articles_llm.rb all"
  puts ""
  puts "Requires: ANTHROPIC_API_KEY environment variable"
  exit 1
end

if magazine_arg == 'all'
  magazine_dirs = Dir.glob('/home/hanz/panter/transhelvetica/magazines/*_articles')

  magazine_dirs.each do |dir|
    process_magazine_articles(dir)
    puts "---"
  end
else
  unless Dir.exist?(magazine_arg)
    puts "Error: Directory '#{magazine_arg}' not found"
    exit 1
  end

  process_magazine_articles(magazine_arg)
end

puts "\nLabeling complete!"