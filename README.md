# Transhelvetica Magazine Analyzer

A comprehensive tool for converting PDF magazines into searchable, AI-analyzable content. This system processes magazine PDFs through multiple stages to create a searchable database of articles with AI-generated image descriptions, intelligent classification, and reader questions.

## Features
- Extract text and images from magazine PDFs
- Convert magazine content to structured YAML with base64-encoded images
- Split magazines into individual articles
- Replace images with AI-generated descriptions
- Classify and label articles with detailed categories
- Generate potential reader questions for each article
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
Analyzes article content and adds detailed classification labels for improved search and categorization.

```bash
ruby label_articles_llm.rb
```

Labels include:
- Detailed category classifications (10 main categories with 130+ specific labels)
- Geographic locations mentioned (countries, cantons, cities, regions)
- Key themes and keywords

### Step 5: Generate Reader Questions
Creates potential questions that readers might ask about the general topics covered in each article.

```bash
ruby generate_questions.rb
```

This step:
- Generates 10 topic-focused questions per article
- Creates questions based on general themes and subjects
- Helps with content discovery and SEO

### Step 6: Setup Database Schema
Creates the database tables needed to store all processed content.

```bash
ruby db_setup.rb
```

### Step 7: Import to Database
Stores processed articles with their descriptions and labels in the database for efficient querying.

```bash
ruby import_articles.rb
```

## Database Queries

### Sample Queries
The repository includes sample SQL queries to help you explore the processed magazine data:

- **`all_articles_with_data.pgsql`** - Retrieves articles with magazine numbers, locations, categories, and keywords
- **`all_articles_with_questions.pgsql`** - Retrieves articles with magazine numbers and all associated reader questions

These queries demonstrate how to access the structured data and can be used as templates for building your own search functionality.

## Folder Structure
- `magazines/` — Contains magazine PDFs, YAML files, and extracted articles (ignored by git)
- `setup_and_process.sh` — Automated setup and processing script (recommended)
- `pdf_to_yaml.rb` — Converts PDFs to YAML with base64 images
- `split_magazine.rb` — Splits magazine YAML into individual articles
- `describe_images.rb` — Replaces base64 images with AI descriptions
- `label_articles_llm.rb` — Classifies and labels articles with detailed categories
- `generate_questions.rb` — Generates potential reader questions for articles
- `db_setup.rb` — Creates database schema
- `import_articles.rb` — Imports processed articles to database

## Getting Started

### Quick Setup (Recommended)

For the easiest setup experience, use the automated setup script:

```bash
chmod +x setup_and_process.sh
./setup_and_process.sh
```

This script will:
- Check and install all dependencies (Ruby, gems, PostgreSQL tools)
- Guide you through environment configuration
- Set up API keys for AI services
- Process all PDF magazines in the magazines/ directory
- Optionally set up and populate the database

The script asks for all required information upfront, then runs the entire pipeline without interruption.

### Manual Setup

If you prefer manual setup:

#### Prerequisites
1. Ruby 3.0 or higher
2. Required gems:
   ```bash
   gem install pdf-reader
   gem install yaml
   gem install pg  # for PostgreSQL
   gem install dotenv  # for environment variables
   ```
3. PostgreSQL database
4. AI API credentials (Claude, OpenAI, or local Ollama)
5. Environment variables in `.env` file:
   ```
   DATABASE_URL=postgresql://username:password@host:port/database
   ANTHROPIC_API_KEY=your_claude_api_key
   OPENAI_API_KEY=your_openai_api_key
   ```

### Full Processing Workflow
Process a complete magazine from PDF to database:

```bash
# 1. Convert PDF to YAML with images
ruby pdf_to_yaml.rb

# 2. Split into articles
ruby split_magazine.rb

# 3. Generate image descriptions
ruby describe_images.rb

# 4. Classify articles with detailed categories (defaults to 'all' articles with 'claude')
ruby label_articles_llm.rb

# 5. Generate reader questions (defaults to 'all' articles with 'claude')
ruby generate_questions.rb

# 6. Setup database (one time only)
ruby db_setup.rb

# 7. Import to database
ruby import_articles.rb
```

### Detailed Category System
Articles are classified using 10 main categories with comprehensive subcategories, combining Swiss-focused topics with broad thematic coverage:

- **Geography & Places**: Swiss Cantons (Schwyz, Wallis, Graubünden, Zürich, Bern, Tessin, Appenzell, Fribourg), Alpine Regions, Urban Centers, International Locations, etc.
- **Culture & Arts**: Traditional Crafts, Contemporary Art, Museums, Exhibitions, Traditional Handwork (Weberei & Stickerei, Schwingen), etc.
- **Travel & Tourism**: Train Journeys, Hiking Routes, Alpinismus, Tourism Economy, International Relations, etc.
- **Nature & Outdoors**: Mountain Landscapes, Wildlife & Flora (Waschbär, Alpine Animals), Environmental Conservation, etc.
- **Food & Culinary**: Traditional Cuisine, Wine & Viticulture, Gastronomie, Culinary Specialties, etc.
- **Architecture & Gardens**: Garden Design, Historic Buildings, Modern Architecture, Landscape Architecture, etc.
- **People & Profiles**: Local Artisans, Cultural Figures, Contemporary Actors, Authors & Writers, etc.
- **History & Heritage**: Medieval History, Industrial Heritage, Archaeological Sites, Political History, etc.
- **Symbols & Motifs**: Cross & Religious Symbols, Animal Symbols, Cultural Icons, Traditional Patterns, etc.
- **Society & Lifestyle**: Urban Development, Social Trends, Language & Communication, Cultural Integration, etc.

## License

MIT license
