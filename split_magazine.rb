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

    # First extract articles from TOC which gives us reliable page numbers
    toc_articles = extract_from_toc

    # Sort by start page for proper content extraction
    toc_articles.sort_by! { |a| a[:start_page] }

    # Extract content for each article with proper boundaries
    toc_articles.each_with_index do |article, idx|
      next_article = toc_articles[idx + 1]
      extract_article_content_with_bounds(article, next_article)

      # Extract the proper title using improved pattern matching
      extracted_title = extract_proper_title_from_content(article[:content], article[:title])
      article[:title] = extracted_title if extracted_title && extracted_title.length > 2
    end

    # Remove articles with no content
    toc_articles.reject! { |a| a[:content].to_s.strip.empty? }

    # Save articles to files
    save_articles(toc_articles)

    toc_articles
  end

  private

  def extract_proper_title_from_content(content, current_title)
    # Skip if content is too short
    return current_title if content.to_s.strip.length < 50

    # Use a simple approach - look for patterns in the content first
    simple_title = extract_title_simple(content)
    return simple_title if simple_title && simple_title.length > 2
    
    # If simple extraction fails, try pattern matching
    pattern_title = extract_title_by_patterns(content)
    return pattern_title if pattern_title && pattern_title.length > 2
    
    # Return original title if nothing better found
    current_title
  end

  def extract_title_simple(content)
    lines = content.split("\n").map(&:strip).reject(&:empty?)
    return nil if lines.empty?
    
    # Look for the first substantial line after section headers
    lines.each_with_index do |line, idx|
      # Skip section headers like "EiNrEiSE", "AlltAgsWundEr", etc.
      next if line.match?(/^(EinrEisE|EiNrEiSE|AlltAgsWundEr|allTaGSWuNdEr|gEdAnkEngAng|FundstückE|spEziAlist|EinWAndErEr|culinAriA HElvEticA|scHWErpunkt|HElvEtAriEn|AvAntgArdE|HErkunFt|BrEttEr dEr HEiMAt|AngEWAndt|Es WAr EinMAl|kunststückE|AusrEisE|kindErrEport|gEMEindEportrAit)$/i)
      
      # Skip lines that are clearly not titles (too long, have quotes, etc.)
      next if line.length > 80
      next if line.include?('"') || line.include?('«') || line.include?('»')
      next if line.match?(/^\d+/) # Skip lines starting with numbers
      next if line.match?(/^(der|die|das|ein|eine|und|oder|mit|von|zu|in|auf|an|im|am)\s/i) # Skip articles/prepositions at start
      
      # Look for patterns that suggest this is a title
      if line.match?(/^[A-ZÄÖÜ]/) && line.length >= 3 && line.length <= 60
        # Check if it looks like a proper title (not just random text)
        word_count = line.split.length
        if word_count >= 1 && word_count <= 10
          return clean_extracted_title(line)
        end
      end
    end
    
    nil
  end

  def extract_title_by_patterns(content)
    lines = content.split("\n").map(&:strip).reject(&:empty?)
    return nil if lines.empty?
    
    # Look for specific patterns based on the magazine structure
    content_start = content.strip
    
    # Pattern 1: EiNrEiSE articles with person interviews
    # Look for pattern: EiNrEiSE «quote» Person Name, age, location
    if match = content_start.match(/EiNrEiSE\s+«.+?»\s+([A-Z][a-zäöü]+(?:\s+[a-zäöü]+)*),?\s*\d+,?\s*[a-zäöü]/m)
      person_name = match[1].strip
      # Clean up the name - capitalize properly
      person_name = person_name.split.map(&:capitalize).join(' ')
      return person_name if person_name && person_name.length <= 40 && !person_name.match?(/^(Text|Bild|Foto)/)
    end
    
    # Pattern 2: Look for section headers followed by main titles
    # Like "AlltAgsWundEr Nasse Kleidung Text:"
    if match = content_start.match(/(AlltAgsWundEr|allTaGSWuNdEr)\s+([A-Z][A-Za-zäöü\s]+?)(?:\s+Text:|$)/m)
      title = match[2].strip
      return clean_extracted_title(title) if title.length >= 3 && title.length <= 50
    end
    
    # Pattern 3: Look for specialized titles like "Der Herr des Mythenkreuzes"
    if match = content_start.match(/([Dd]er\s+[A-Z][a-zäöü]+(?:\s+[a-zäöü]+)*(?:\s+[A-Z][a-zäöü]+)*)/m)
      title = match[1].strip
      return clean_extracted_title(title) if title.length <= 50
    end
    
    # Pattern 4: Look for other section headers with titles
    section_patterns = [
      /(EinWAndErEr)\s+([A-Z][a-zäöü\s]+?)(?:\s+Text:|$)/m,
      /(spEziAlist|SPEzialiST)\s*\d*\s*$/m, # Sometimes just the section header
      /(gEdAnkEngAng)\s+([A-Z][a-zäöü\s]+?)(?:\s|$)/m
    ]
    
    section_patterns.each do |pattern|
      if match = content_start.match(pattern)
        if match[2] # Has a title part
          title = match[2].strip
          return clean_extracted_title(title) if title.length >= 3 && title.length <= 50
        else
          # Just the section header, look for title in next lines
          lines[1..3].each do |line|
            if line.match?(/^[A-Z][a-zäöü\s]+$/) && line.length >= 3 && line.length <= 50
              return clean_extracted_title(line)
            end
          end
        end
      end
    end
    
    # Pattern 5: Look for capitalized words that could be titles
    lines[0..5].each do |line|
      words = line.split
      if words.length >= 2 && words.length <= 6
        if words.all? { |w| w.match?(/^[A-ZÄÖÜ]/) || w.match?(/^(und|oder|von|zu|im|am|der|die|das|ein|eine)$/i) }
          return clean_extracted_title(line)
        end
      end
    end
    
    nil
  end

  def clean_extracted_title(title)
    # Clean up the title
    title = title.gsub(/\s+/, ' ').strip
    title = title.gsub(/^(der|die|das)\s+/i, '') # Remove leading articles for consistency
    title.length > 60 ? title[0..57] + "..." : title
  end

  def is_article_title?(line, lines = [], idx = 0)
    # Check if line appears to be a title
    return false if line.length < 3

    # Common section headers in the magazine (with flexible capitalization)
    title_patterns = [
      /EdiTorial/i,
      /EinrEisE/i,
      /FundstückE/i,
      /AlltAgsWundEr/i,
      /gEdAnkEngAng/i,
      /culinAriA\s+HElvEticA/i,
      /EinWAndErEr/i,
      /spEziAlist/i,
      /scHWErpunkt/i,
      /AltErnAtivEs\s+rEisEn/i,
      /HElvEtAriEn/i,
      /AvAntgArdE/i,
      /HErkunFt/i,
      /BrEttEr\s+dEr\s+HEiMAt/i,
      /AngEWAndt/i,
      /Es\s+WAr\s+EinMAl/i,
      /kunststückE/i,
      /AusrEisE/i,
      /kindErrEport/i,
      /gEMEindEportrAit/i
    ]

    title_patterns.any? { |pattern| line.match?(pattern) }
  end

  def clean_title(title)
    # Clean up title formatting
    title.gsub(/\s+/, ' ').strip
  end

  def clean_toc_title(title)
    # Remove page numbers that might be embedded in title
    title = title.gsub(/\d{1,3}\s*$/, '').strip
    # Remove section headers that might be attached
    title = title.gsub(/\s*(EinrEisE|scHWErpunkt|HElvEtAriEn|FundstückE|AlltAgsWundEr|gEdAnkEngAng|culinAriA HElvEticA|EinWAndErEr|spEziAlist|AltErnAtivEs rEisEn|AvAntgArdE|HErkunFt|BrEttEr dEr HEiMAt|AngEWAndt|Es WAr EinMAl|kunststückE|AusrEisE|kindErrEport|gEMEindEportrAit).*$/i, '')
    # Clean up extra spaces
    title.gsub(/\s+/, ' ').strip
  end

  def is_section_header?(text)
    section_headers = [
      'EinrEisE', 'scHWErpunkt', 'HElvEtAriEn', 'FundstückE',
      'AlltAgsWundEr', 'gEdAnkEngAng', 'culinAriA HElvEticA',
      'EinWAndErEr', 'spEziAlist', 'AltErnAtivEs rEisEn',
      'AvAntgArdE', 'HErkunFt', 'BrEttEr dEr HEiMAt',
      'AngEWAndt', 'Es WAr EinMAl', 'kunststückE',
      'AusrEisE', 'kindErrEport', 'gEMEindEportrAit'
    ]

    section_headers.any? { |header| text.match?(/^#{Regexp.escape(header)}$/i) }
  end

  def is_new_article_start?(text)
    # Check if this text contains a section header indicating a new article
    return false if text.nil? || text.empty?

    lines = text.split("\n").first(5) # Check first 5 lines
    lines.any? { |line| is_article_title?(line.strip) }
  end

  def detect_articles_from_headers
    articles = []

    @data['pages'].each do |page_data|
      page_num = page_data['page']
      text = page_data['text'] || ''

      lines = text.split("\n")
      lines.each do |line|
        stripped = line.strip

        if is_article_title?(stripped)
          articles << {
            title: clean_title(stripped),
            start_page: page_num,
            header_detected: true
          }
        end
      end
    end

    articles
  end

  def extract_from_toc
    articles = []
    toc_found = false

    @data['pages'].each do |page_data|
      text = page_data['text'] || ''

      # Look for table of contents patterns
      if text.match?(/iNHalT|INHALT|inhalt/i)
        toc_found = true

        # The TOC text might have entries separated by spaces instead of newlines
        # Split by multiple patterns to extract individual entries

        # First try to extract patterns like "07 Yoshimi Takano"
        text.scan(/(\d{1,3})\s+([A-Za-zÄÖÜäöü][^\d]{3,50})(?=\s+\d|\s+[A-Z]|$)/) do |page, title|
          page_num = page.to_i
          title = title.strip

          # Clean up title - remove trailing section names
          title = title.gsub(/\s*(EinrEisE|scHWErpunkt|HElvEtAriEn|FundstückE|AlltAgsWundEr|gEdAnkEngAng|culinAriA HElvEticA|EinWAndErEr|spEziAlist|AltErnAtivEs rEisEn|AvAntgArdE|HErkunFt|BrEttEr dEr HEiMAt|AngEWAndt|Es WAr EinMAl|kunststückE|AusrEisE|kindErrEport|gEMEindEportrAit).*$/i, '')
          title = clean_toc_title(title)

          next if title.length < 3 || page_num == 0

          # Split titles separated by commas into individual articles
          title.split(/,\s*/).each do |single_title|
            single_title = single_title.strip
            next if single_title.length < 3
            articles << {
              title: single_title,
              start_page: page_num,
              toc_entry: true
            }
          end
        end

        # Also look for section headers with their page numbers in various formats
        # Pattern like "Saure Grüsse aus dem Wallis 14"
        text.scan(/([A-Za-zÄÖÜäöü][^\d]{5,50})\s+(\d{1,3})(?=\s|$)/) do |title, page|
          page_num = page.to_i
          title = title.strip

          # Skip section headers
          next if is_section_header?(title)

          title = clean_toc_title(title)

          next if title.length < 3 || page_num == 0

          # Split titles separated by commas into individual articles
          title.split(/,\s*/).each do |single_title|
            single_title = single_title.strip
            next if single_title.length < 3
            articles << {
              title: single_title,
              start_page: page_num,
              toc_entry: true
            }
          end
        end
      end
    end

    # If no TOC found, try to detect articles from section headers
    if !toc_found || articles.empty?
      articles = detect_articles_from_headers
    end

    # Remove duplicates based on page number
    articles.uniq! { |a| a[:start_page] }

    # Sort by page number
    articles.sort_by! { |a| a[:start_page] }

    articles
  end

  def extract_article_content_with_bounds(article, next_article = nil)
    content = []
    pages = []
    end_page = next_article ? next_article[:start_page] - 1 : article[:start_page] + 20

    @data['pages'].each do |page_data|
      page_num = page_data['page']
      text = page_data['text'] || ''

      # Check if we're within the article's page range
      if page_num >= article[:start_page] && page_num <= end_page
        # Check if this page starts a new article (by looking for section headers)
        if page_num > article[:start_page] && is_new_article_start?(text) && next_article && page_num >= next_article[:start_page]
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