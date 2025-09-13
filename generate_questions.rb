#!/usr/bin/env ruby

require 'yaml'
require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'

class QuestionGenerator
  # Using Claude API for question generation
  CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'
  
  def initialize(article_file, api_key = nil)
    @article_file = article_file
    @article_data = YAML.load_file(article_file)
    @api_key = api_key || ENV['ANTHROPIC_API_KEY']
    
    if @api_key.nil? || @api_key.empty?
      raise "Please set ANTHROPIC_API_KEY environment variable or pass API key as argument"
    end
  end
  
  def generate_and_save_questions
    content = @article_data['content'] || ''
    title = @article_data['title'] || ''
    labels = @article_data['labels'] || {}
    
    # Prepare context for question generation
    context = build_context(title, content, labels)
    
    # Generate questions using LLM
    questions = generate_questions_with_llm(context)
    
    # Add questions to article data
    @article_data['questions'] = questions
    
    # Save updated article
    File.write(@article_file, @article_data.to_yaml)
    
    questions
  end
  
  private
  
  def build_context(title, content, labels)
    context = "Title: #{title}\n\n"
    
    # Add location context
    if labels['locations'] && !labels['locations'].empty?
      locations = labels['locations'].map { |l| l.is_a?(Hash) ? l['name'] : l }.join(', ')
      context += "Mentioned locations: #{locations}\n"
    end
    
    # Add category context
    if labels['categories'] && !labels['categories'].empty?
      active_categories = labels['categories'].select { |k, v| v&.any? }
      if active_categories.any?
        context += "Article categories: #{active_categories.map { |k, v| "#{k}: #{v.join(', ')}" }.join(' | ')}\n"
      end
    end
    
    # Add keywords context
    if labels['keywords'] && !labels['keywords'].empty?
      context += "Keywords: #{labels['keywords'].join(', ')}\n"
    end
    
    context += "\nContent preview: #{content[0..2000]}"
    context
  end
  
  def generate_questions_with_llm(context)
    prompt = <<~PROMPT
      Based on this Swiss magazine article, generate 10 general questions that potential readers who know nothing about this topic might ask. These should be broad, topic-focused questions that would lead someone to find this article helpful.

      Article context:
      #{context}

      Generate questions that:
      1. Focus on the GENERAL TOPICS and themes covered in the article
      2. Are questions someone might ask BEFORE reading the article
      3. Are broad enough that many people might wonder about these topics
      4. Cover general interest areas like travel planning, cultural understanding, practical advice, etc.
      5. Don't require specific knowledge from the article to understand
      6. Would be natural search queries or conversation starters

      Examples of good general questions:
      - "What are the best places to visit in Switzerland?"
      - "What is Swiss culture like?"
      - "How expensive is traveling in Switzerland?"
      - "What food is Switzerland famous for?"
      - "What should I know before visiting the Alps?"
      - "What are the main attractions in this region?"
      - "How do I plan a trip to Switzerland?"
      - "What makes this area special?"
      - "What can I do in this part of Switzerland?"
      - "What is unique about Swiss traditions?"

      Think about what someone might Google or ask a friend about these general topics. The questions should be broad interest questions that this article helps answer.

      Please return the questions as a JSON array:
      {
        "questions": [
          "Question 1 here?",
          "Question 2 here?",
          "Question 3 here?",
          "Question 4 here?",
          "Question 5 here?",
          "Question 6 here?",
          "Question 7 here?",
          "Question 8 here?",
          "Question 9 here?",
          "Question 10 here?"
        ]
      }

      Make sure each question ends with a question mark and focuses on general topics/themes.
    PROMPT
    
    response = call_claude_api(prompt)
    parse_questions_response(response)
  rescue => e
    puts "Error calling LLM for questions: #{e.message}"
    # Fallback to empty questions if API fails
    []
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
      max_tokens: 1500,
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
  
  def parse_questions_response(response)
    # Extract the content from Claude's response
    content = response.dig('content', 0, 'text') || ''
    
    # Try to parse JSON from the response
    json_match = content.match(/\{.*\}/m)
    if json_match
      begin
        result = JSON.parse(json_match[0])
        return result['questions'] || []
      rescue JSON::ParserError
        puts "Failed to parse JSON from LLM response"
      end
    end
    
    # Fallback parsing if JSON extraction fails
    []
  end
end

# Alternative: Using OpenAI API
class QuestionGeneratorOpenAI
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  
  def initialize(article_file, api_key = nil)
    @article_file = article_file
    @article_data = YAML.load_file(article_file)
    @api_key = api_key || ENV['OPENAI_API_KEY']
    
    if @api_key.nil? || @api_key.empty?
      raise "Please set OPENAI_API_KEY environment variable or pass API key as argument"
    end
  end
  
  def generate_and_save_questions
    content = @article_data['content'] || ''
    title = @article_data['title'] || ''
    labels = @article_data['labels'] || {}
    
    context = build_context(title, content, labels)
    questions = generate_questions_with_llm(context)
    
    @article_data['questions'] = questions
    File.write(@article_file, @article_data.to_yaml)
    
    questions
  end
  
  private
  
  def build_context(title, content, labels)
    context = "Title: #{title}\n\n"
    
    if labels['locations'] && !labels['locations'].empty?
      locations = labels['locations'].map { |l| l.is_a?(Hash) ? l['name'] : l }.join(', ')
      context += "Mentioned locations: #{locations}\n"
    end
    
    if labels['categories'] && !labels['categories'].empty?
      active_categories = labels['categories'].select { |k, v| v&.any? }
      if active_categories.any?
        context += "Article categories: #{active_categories.map { |k, v| "#{k}: #{v.join(', ')}" }.join(' | ')}\n"
      end
    end
    
    if labels['keywords'] && !labels['keywords'].empty?
      context += "Keywords: #{labels['keywords'].join(', ')}\n"
    end
    
    context += "\nContent preview: #{content[0..2000]}"
    context
  end
  
  def generate_questions_with_llm(context)
    prompt = <<~PROMPT
      Based on this Swiss magazine article, generate 10 general questions that potential readers who know nothing about this topic might ask. These should be broad, topic-focused questions that would lead someone to find this article helpful.

      Article context:
      #{context}

      Generate questions that:
      1. Focus on the GENERAL TOPICS and themes covered in the article
      2. Are questions someone might ask BEFORE reading the article
      3. Are broad enough that many people might wonder about these topics
      4. Cover general interest areas like travel planning, cultural understanding, practical advice, etc.
      5. Don't require specific knowledge from the article to understand
      6. Would be natural search queries or conversation starters

      Examples: "What are the best places to visit in Switzerland?", "What is Swiss culture like?", "How expensive is traveling in Switzerland?"

      Return as JSON array:
      {"questions": ["Question 1?", "Question 2?", ...]}
    PROMPT
    
    response = call_openai_api(prompt)
    parse_questions_response(response)
  rescue => e
    puts "Error calling OpenAI: #{e.message}"
    []
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
          content: 'You are an expert at generating natural reader questions for Swiss magazine articles. Always respond with valid JSON.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 800
    }.to_json
    
    response = http.request(request)
    
    if response.code != '200'
      raise "API request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body)
  end
  
  def parse_questions_response(response)
    content = response.dig('choices', 0, 'message', 'content') || ''
    
    begin
      result = JSON.parse(content)
      return result['questions'] || []
    rescue JSON::ParserError
      puts "Failed to parse JSON from OpenAI response"
      []
    end
  end
end

# Local LLM option using Ollama
class QuestionGeneratorOllama
  OLLAMA_API_URL = 'http://localhost:11434/api/generate'
  
  def initialize(article_file, model = 'llama2')
    @article_file = article_file
    @article_data = YAML.load_file(article_file)
    @model = model
  end
  
  def generate_and_save_questions
    content = @article_data['content'] || ''
    title = @article_data['title'] || ''
    labels = @article_data['labels'] || {}
    
    context = build_context(title, content, labels)
    questions = generate_questions_with_llm(context)
    
    @article_data['questions'] = questions
    File.write(@article_file, @article_data.to_yaml)
    
    questions
  end
  
  private
  
  def build_context(title, content, labels)
    context = "Title: #{title}\n\n"
    
    if labels['locations'] && !labels['locations'].empty?
      locations = labels['locations'].map { |l| l.is_a?(Hash) ? l['name'] : l }.join(', ')
      context += "Locations: #{locations}\n"
    end
    
    if labels['keywords'] && !labels['keywords'].empty?
      context += "Keywords: #{labels['keywords'].join(', ')}\n"
    end
    
    context += "\nContent: #{content[0..1500]}"
    context
  end
  
  def generate_questions_with_llm(context)
    prompt = <<~PROMPT
      Generate 10 general questions that potential readers who know nothing about this topic might ask. These should be broad questions about the general topics covered.

      Article: #{context}

      Create general questions someone might ask BEFORE reading the article. Focus on broad topics like travel, culture, activities, etc.

      Examples: "What are the best places to visit in Switzerland?", "What is Swiss culture like?"

      Return as JSON:
      {"questions": ["Question 1?", "Question 2?", ...]}
    PROMPT
    
    response = call_ollama_api(prompt)
    parse_questions_response(response)
  rescue => e
    puts "Error calling Ollama: #{e.message}"
    []
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
  
  def parse_questions_response(response)
    content = response['response'] || ''
    
    # Try to extract JSON from response
    json_match = content.match(/\{.*\}/m)
    if json_match
      begin
        result = JSON.parse(json_match[0])
        return result['questions'] || []
      rescue JSON::ParserError
        puts "Failed to parse JSON from Ollama response"
      end
    end
    
    []
  end
end

# Process articles
def process_magazine_articles_for_questions(magazine_dir, llm_provider = 'claude')
  article_files = Dir.glob(File.join(magazine_dir, '*.yaml')).reject { |f| f.include?('summary.yaml') }
  
  puts "Generating questions for #{article_files.length} articles in #{File.basename(magazine_dir)} using #{llm_provider}..."
  
  article_files.each_with_index do |article_file, idx|
    begin
      generator = case llm_provider.downcase
      when 'claude'
        QuestionGenerator.new(article_file)
      when 'openai'
        QuestionGeneratorOpenAI.new(article_file)
      when 'ollama'
        QuestionGeneratorOllama.new(article_file)
      else
        raise "Unknown LLM provider: #{llm_provider}"
      end
      
      questions = generator.generate_and_save_questions
      
      puts "  [#{idx+1}/#{article_files.length}] #{File.basename(article_file)}:"
      puts "    Generated #{questions.length} questions"
      questions.each_with_index do |q, i|
        puts "      #{i+1}. #{q}"
      end
      puts ""
      
      # Rate limiting for API calls
      sleep(1) if llm_provider != 'ollama'
    rescue => e
      puts "  Error processing #{File.basename(article_file)}: #{e.message}"
    end
  end
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby generate_questions.rb <magazine_directory> [llm_provider]"
  puts "   or: ruby generate_questions.rb all [llm_provider]"
  puts ""
  puts "LLM providers: claude (default), openai, ollama"
  puts ""
  puts "For Claude: set ANTHROPIC_API_KEY environment variable"
  puts "For OpenAI: set OPENAI_API_KEY environment variable"
  puts "For Ollama: ensure Ollama is running locally with a model installed"
  exit 1
end

magazine_arg = ARGV[0]
llm_provider = ARGV[1] || 'claude'

if magazine_arg == 'all'
  magazine_dirs = Dir.glob('/home/hanz/panter/transhelvetica/magazines/*_articles')
  
  magazine_dirs.each do |dir|
    process_magazine_articles_for_questions(dir, llm_provider)
    puts "---"
  end
else
  unless Dir.exist?(magazine_arg)
    puts "Error: Directory '#{magazine_arg}' not found"
    exit 1
  end
  
  process_magazine_articles_for_questions(magazine_arg, llm_provider)
end

puts "\nQuestion generation complete!"