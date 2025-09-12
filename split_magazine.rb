#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'

class MagazineSplitter
  def initialize(yaml_file)
    @yaml_file = yaml_file
    @basename = File.basename(yaml_file, '.yaml')
    @output_dir = File.join(File.dirname(yaml_file), @basename + '_articles')
    @data = YAML.load_file(yaml_file)
  end

  def extract_articles
    FileUtils.mkdir_p(@output_dir)
    
    articles = []
    current_article = nil
    
    @data['pages'].each do |page_data|
      page_num = page_data['page']
      text = page_data['text'] || ''
      
      # Look for article headers (uppercase text that appears to be titles)
      lines = text.split("\n")
      
      lines.each_with_index do |line, idx|
        stripped = line.strip
        
        # Skip empty lines
        next if stripped.empty?
        
        # Detect potential article titles - look for patterns like section headers
        if is_article_title?(stripped, lines, idx)
          # Save previous article if exists
          if current_article && !current_article[:content].strip.empty?
            articles << current_article
          end
          
          # Start new article
          current_article = {
            title: clean_title(stripped),
            start_page: page_num,
            content: "",
            pages: [page_num]
          }
        elsif current_article
          # Add content to current article
          current_article[:content] += line + "\n"
          current_article[:pages] << page_num unless current_article[:pages].include?(page_num)
        end
      end
    end
    
    # Save last article
    if current_article && !current_article[:content].strip.empty?
      articles << current_article
    end
    
    # Also extract articles based on table of contents patterns
    toc_articles = extract_from_toc
    
    # Merge both approaches
    all_articles = merge_article_lists(articles, toc_articles)
    
    # Save articles to files
    save_articles(all_articles)
    
    all_articles
  end
  
  private
  
  def is_article_title?(line, lines, idx)
    # Check if line appears to be a title
    return false if line.length < 3
    
    # Common section headers in the magazine
    title_patterns = [
      /^EdiTorial$/i,
      /^EinrEisE$/i,
      /^FundstückE$/i,
      /^AlltAgsWundEr$/i,
      /^gEdAnkEngAng$/i,
      /^culinAriA HElvEticA$/i,
      /^EinWAndErEr$/i,
      /^spEziAlist$/i,
      /^scHWErpunkt$/i,
      /^AltErnAtivEs rEisEn$/i,
      /^HElvEtAriEn$/i,
      /^AvAntgArdE$/i,
      /^HErkunFt$/i,
      /^BrEttEr dEr HEiMAt$/i,
      /^AngEWAndt$/i,
      /^Es WAr EinMAl$/i,
      /^kunststückE$/i,
      /^AusrEisE$/i,
      /^kindErrEport$/i,
      /^gEMEindEportrAit$/i
    ]
    
    title_patterns.any? { |pattern| line.match?(pattern) }
  end
  
  def clean_title(title)
    # Clean up title formatting
    title.gsub(/\s+/, ' ').strip
  end
  
  def extract_from_toc
    articles = []
    
    @data['pages'].each do |page_data|
      text = page_data['text'] || ''
      
      # Look for table of contents patterns
      if text.include?('iNHalT') || text.include?('INHALT')
        
        # Extract article entries from TOC
        lines = text.split("\n")
        lines.each do |line|
          # Match patterns like "14 Saure Grüsse" or "22 Der Herr des Mythenkreuzes"
          if match = line.match(/^\s*(\d{1,2})\s+(.+?)(?:\s{2,}|$)/)
            page_num = match[1].to_i
            title = match[2].strip
            
            # Skip if title is too short or looks like noise
            next if title.length < 5
            
            articles << {
              title: title,
              start_page: page_num,
              toc_entry: true
            }
          end
        end
      end
    end
    
    # Now extract content for TOC articles
    articles.each do |article|
      extract_article_content(article)
    end
    
    articles
  end
  
  def extract_article_content(article)
    content = []
    pages = []
    in_article = false
    
    @data['pages'].each do |page_data|
      page_num = page_data['page']
      text = page_data['text'] || ''
      
      if page_num >= article[:start_page]
        in_article = true
      end
      
      if in_article
        # Check if we've reached the next article (heuristic)
        if page_num > article[:start_page] + 10
          break
        end
        
        content << text
        pages << page_num
      end
    end
    
    article[:content] = content.join("\n")
    article[:pages] = pages
  end
  
  def merge_article_lists(articles1, articles2)
    # Merge two article lists, avoiding duplicates
    all_articles = articles1.dup
    
    articles2.each do |article2|
      # Check if this article already exists
      exists = all_articles.any? do |a1|
        similar_title?(a1[:title], article2[:title]) ||
        (a1[:start_page] == article2[:start_page])
      end
      
      all_articles << article2 unless exists
    end
    
    # Sort by start page
    all_articles.sort_by { |a| a[:start_page] }
  end
  
  def similar_title?(title1, title2)
    # Check if two titles are similar enough to be the same article
    return false if title1.nil? || title2.nil?
    
    t1 = title1.downcase.gsub(/[^a-z0-9]/, '')
    t2 = title2.downcase.gsub(/[^a-z0-9]/, '')
    
    t1 == t2 || t1.include?(t2) || t2.include?(t1)
  end
  
  def save_articles(articles)
    puts "Saving #{articles.length} articles to #{@output_dir}"
    
    # Save summary
    summary_file = File.join(@output_dir, 'summary.yaml')
    summary = articles.map do |article|
      {
        'title' => article[:title],
        'start_page' => article[:start_page],
        'pages' => article[:pages],
        'filename' => generate_filename(article)
      }
    end
    
    File.write(summary_file, summary.to_yaml)
    
    # Save individual articles
    articles.each_with_index do |article, idx|
      filename = generate_filename(article, idx)
      filepath = File.join(@output_dir, filename)
      
      article_data = {
        'title' => article[:title],
        'start_page' => article[:start_page],
        'pages' => article[:pages],
        'content' => article[:content]
      }
      
      File.write(filepath, article_data.to_yaml)
      puts "  Saved: #{filename}"
    end
  end
  
  def generate_filename(article, idx = nil)
    # Generate a safe filename from article title
    safe_title = article[:title].downcase.gsub(/[^a-z0-9]+/, '_')[0..50]
    safe_title = safe_title.gsub(/^_|_$/, '')
    
    if safe_title.empty?
      safe_title = "article_#{idx || article[:start_page]}"
    end
    
    "#{article[:start_page].to_s.rjust(3, '0')}_#{safe_title}.yaml"
  end
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby split_magazine.rb <yaml_file>"
  exit 1
end

yaml_file = ARGV[0]

unless File.exist?(yaml_file)
  puts "Error: File '#{yaml_file}' not found"
  exit 1
end

splitter = MagazineSplitter.new(yaml_file)
articles = splitter.extract_articles

puts "\nExtracted #{articles.length} articles"
puts "Articles saved to: #{File.join(File.dirname(yaml_file), File.basename(yaml_file, '.yaml') + '_articles')}"