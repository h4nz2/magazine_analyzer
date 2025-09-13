# PDF Magazine Summarizer

This is a very simple repository, whose goal is to build something that will be able to take PDF of a magazine issue and convert it into a form that will allow AI-powered searching through the magazines and its articles.

## Tech Stack

Preferably Ruby programming language, alternatively other programming languages if the task cannot be done in Ruby. Using language models for various tasks is also permitted.

## Code Structure

The app consists of several independent scripts that process magazine PDFs through a pipeline. Each script performs a specific transformation step:

### Scripts Overview

1. **`pdf_to_yaml.rb`** - Converts PDF magazines to YAML format
   - Extracts text content from each page while preserving reading order
   - Extracts images as base64-encoded data
   - Saves output as `.yaml` files in the `magazines/` directory
   - Input: `magazines/*.pdf`
   - Output: `magazines/*.yaml`

2. **`split_magazine.rb`** - Splits magazines into individual articles
   - Parses the YAML files and identifies article boundaries
   - Creates separate YAML files for each article
   - Preserves metadata like title, page numbers, and images
   - Input: `magazines/*.yaml`
   - Output: `magazines/{magazine_name}_articles/*.yaml`

3. **`describe_images.rb`** - Generates AI descriptions for images
   - Uses AI/LLM to analyze images in articles
   - Replaces base64 image data with textual descriptions
   - Helps make visual content searchable
   - Input: `magazines/*_articles/*.yaml`
   - Output: Updates article YAML files in-place

4. **`label_articles_llm.rb`** - Classifies and labels articles
   - Uses LLM to analyze article content
   - Adds semantic labels and categories
   - Generates metadata for improved searchability
   - Input: `magazines/*_articles/*.yaml`
   - Output: Updates article YAML files with labels

5. **`db_setup.rb`** - Sets up the database schema
   - Creates necessary PostgreSQL tables
   - Configures indexes for efficient searching
   - Must be run before importing articles
   - Requires: PostgreSQL database and `.env` configuration

6. **`import_articles.rb`** - Imports articles into database
   - Loads labeled articles into PostgreSQL
   - Stores content, metadata, and labels
   - Enables full-text search capabilities
   - Input: `magazines/*_articles/*.yaml`
   - Output: PostgreSQL database records

### Execution Order

Run the scripts in this sequence:

```bash
# Step 1: Convert PDFs to YAML
ruby pdf_to_yaml.rb

# Step 2: Split into articles
ruby split_magazine.rb

# Step 3: Describe images (optional but recommended)
ruby describe_images.rb

# Step 4: Label articles with AI
ruby label_articles_llm.rb

# Step 5: Setup database (only once)
ruby db_setup.rb

# Step 6: Import to database
ruby import_articles.rb
```

### Directory Structure

```
transhelvetica/
├── magazines/              # PDF files and converted YAML files
│   ├── *.pdf              # Original PDF magazines
│   ├── *.yaml             # Converted full magazines
│   └── *_articles/        # Directories with individual articles
│       └── *.yaml         # Individual article files
├── *.rb                   # Processing scripts
└── .env                   # Database configuration (create from .env.example)

## Example use cases:

_Question:_

I want to get links to all articles that talk about mountains.

_Answer:_
1. Magazine number 1 from October 2010, pages 68-69.
2. Magazine number 13 from November 2011, pages 68-69.

_Question:_

What can you tell me about local culture in Switzerland?

_Answer:_
A summary of everything about culture from all the magazines that mention Swiss culture in any way.

1. Magazine number 1 from October 2010, pages 68-69.
2. Magazine number 13 from November 2011, pages 68-69.


