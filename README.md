# Transhelvetica Magazine Analyzer

A comprehensive tool for converting PDF magazines into searchable, AI-analyzable content. This system processes magazine PDFs through multiple stages to create a searchable database of articles with AI-generated image descriptions and intelligent classification.

## Features
- Extract text and images from magazine PDFs
- Convert magazine content to structured YAML with base64-encoded images
- Split magazines into individual articles
- Replace images with AI-generated descriptions
- Classify and label articles automatically
- Store processed articles in a searchable database

## Processing Pipeline

### Step 1: Convert PDF to YAML with Images
Extracts all text and images from PDF magazines, storing images as base64-encoded data in YAML format.

```bash
ruby pdf_to_yaml.rb magazines/trnshlvtc01.pdf
```

This creates a YAML file with:
- Full text content from each page
- Images encoded in base64 format
- Page metadata and structure

### Step 2: Split Magazine into Articles
Analyzes the magazine YAML and intelligently splits it into individual articles, preserving images and layout.

```bash
ruby split_magazine.rb magazines/trnshlvtc01.yaml
```

Output: Individual article files in `magazines/trnshlvtc01_articles/`

### Step 3: Replace Images with AI Descriptions
Processes each article's base64 images and replaces them with detailed AI-generated descriptions for better searchability.

```bash
ruby describe_images.rb magazines/trnshlvtc01_articles/
```

This step:
- Sends images to AI vision models
- Generates contextual descriptions
- Replaces base64 data with text descriptions

### Step 4: Classify and Label Articles
Analyzes article content and adds classification labels for improved search and categorization.

```bash
ruby label_articles.rb magazines/trnshlvtc01_articles/
```

Labels include:
- Topic categories (e.g., culture, mountains, food, travel)
- Geographic locations mentioned
- Key themes and subjects

### Step 5: Import to Database
Stores processed articles with their descriptions and labels in the database for efficient querying.

```bash
ruby import_to_db.rb magazines/trnshlvtc01_articles/
```

## Folder Structure
- `magazines/` — Contains magazine PDFs, YAML files, and extracted articles (ignored by git)
- `pdf_to_yaml.rb` — Converts PDFs to YAML with base64 images
- `split_magazine.rb` — Splits magazine YAML into individual articles
- `describe_images.rb` — Replaces base64 images with AI descriptions
- `label_articles.rb` — Classifies and labels articles
- `import_to_db.rb` — Imports processed articles to database

## Getting Started

### Prerequisites
1. Ruby 3.0 or higher
2. Required gems:
   ```bash
   gem install pdf-reader
   gem install yaml
   gem install openai  # or your preferred AI API client
   ```
3. Database setup (PostgreSQL/SQLite)
4. AI API credentials for image description

### Full Processing Workflow
Process a complete magazine from PDF to database:

```bash
# 1. Convert PDF to YAML with images
ruby pdf_to_yaml.rb magazines/trnshlvtc01.pdf

# 2. Split into articles
ruby split_magazine.rb magazines/trnshlvtc01.yaml

# 3. Generate image descriptions
ruby describe_images.rb magazines/trnshlvtc01_articles/

# 4. Classify articles
ruby label_articles.rb magazines/trnshlvtc01_articles/

# 5. Import to database
ruby import_to_db.rb magazines/trnshlvtc01_articles/
```

## License

MIT license
