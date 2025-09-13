# PDF Magazine Summarizer

This is a very simple repository, whose goal is to build something that will be able to take PDF of a magazine issue and convert it into a form that will allow AI-powered searching through the magazines and its articles.

## Tech Stack

Preferably Ruby programming language, alternatively other programming languages if the task cannot be done in Ruby. Using language models for various tasks is also permitted.

## Documentation

Whenever the scripts are updated or new scripts are added, make sure to add them to both REAMDE.md and CLAUDE.md

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
   - Adds detailed semantic labels and categories (10 main categories, 130+ specific labels)
   - Generates metadata for improved searchability
   - Supports Claude, OpenAI, and Ollama APIs
   - Input: `magazines/*_articles/*.yaml`
   - Output: Updates article YAML files with labels

5. **`generate_questions.rb`** - Generates potential reader questions
   - Uses LLM to create general topic-based questions
   - Generates 10 questions per article that readers might ask about the topics
   - Helps with content discovery and SEO
   - Supports Claude, OpenAI, and Ollama APIs
   - Input: `magazines/*_articles/*.yaml`
   - Output: Updates article YAML files with questions

6. **`db_setup.rb`** - Sets up the database schema
   - Creates necessary PostgreSQL tables
   - Configures indexes for efficient searching
   - Must be run before importing articles
   - Requires: PostgreSQL database and `.env` configuration

7. **`import_articles.rb`** - Imports articles into database
   - Loads labeled articles into PostgreSQL
   - Stores content, metadata, labels, and questions
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

# Step 4: Label articles with AI using detailed categories
ruby label_articles_llm.rb all claude

# Step 5: Generate reader questions
ruby generate_questions.rb all claude

# Step 6: Setup database (only once)
ruby db_setup.rb

# Step 7: Import to database
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

### Detailed Category System

Articles are classified using 10 main categories with detailed subcategories:

1. **Geography & Places**: Swiss Cantons, Alpine Regions, Urban Centers, Border Areas, Lake Districts, Valley Communities, Mountain Peaks, European Destinations, Cross-Border Regions, Remote Locations, Accessibility & Transportation Hubs, UNESCO World Heritage Sites, Natural Parks & Reserves

2. **Culture & Arts**: Traditional Crafts, Contemporary Art, Music & Concerts, Theater & Performance, Literature & Poetry, Photography & Visual Media, Cultural Festivals, Folk Traditions, Religious Heritage, Multicultural Communities, Language & Dialects, Design & Architecture, Street Art & Public Installations

3. **Travel & Transportation**: Train Journeys, Hiking & Walking Routes, Cycling Paths, Public Transportation, Cable Cars & Funiculars, Road Trips, Accommodation & Hotels, Travel Planning, Seasonal Travel, Accessible Tourism, Adventure Sports, Budget Travel, Luxury Experiences

4. **History & Heritage**: Medieval History, Industrial Heritage, Military History, Archaeological Sites, Historic Buildings, Political History, Social Movements, Immigration & Migration, Economic Development, Technological Innovation, Religious History, Family Histories, Preservation Efforts

5. **Nature & Outdoors**: Mountain Landscapes, Water Bodies, Forests & Woodlands, Wildlife & Flora, Climate & Weather, Environmental Conservation, Outdoor Activities, Seasonal Changes, Natural Phenomena, Geological Features, Agriculture & Farming, Sustainable Living, Eco-Tourism

6. **Food & Drink**: Traditional Cuisine, Regional Specialties, Wine & Viticulture, Local Markets, Restaurants & Dining, Food Festivals, Artisanal Products, Cooking Techniques, Food History, Modern Gastronomy, Seasonal Ingredients, Food Culture & Customs, Beverages & Spirits

7. **People & Profiles**: Local Artisans, Cultural Figures, Historical Personalities, Community Leaders, Entrepreneurs, Artists & Creators, Scientists & Researchers, Political Figures, Immigrant Stories, Youth & Education, Elder Wisdom, Professional Profiles, Social Innovators

8. **Curiosities & Discoveries**: Hidden Gems, Unusual Traditions, Scientific Discoveries, Archaeological Finds, Mysterious Places, Quirky Architecture, Local Legends, Surprising Statistics, Forgotten Stories, Modern Mysteries, Cultural Oddities, Unexpected Connections

9. **Events & Seasonal**: Annual Festivals, Cultural Celebrations, Seasonal Activities, Holiday Traditions, Temporary Exhibitions, Sporting Events, Markets & Fairs, Religious Observances, Contemporary Events, Recurring Gatherings, Weather-Dependent Activities, Calendar Highlights, Community Gatherings

10. **Lifestyle & Society**: Urban Development, Social Trends, Technology & Innovation, Education & Learning, Healthcare & Wellness, Work & Economy, Housing & Living, Transportation Trends, Environmental Awareness, Cultural Integration, Generational Changes, Quality of Life, Future Planning

### Reader Questions

Each article gets 10 general questions that potential readers might ask about the topics covered. These questions:
- Focus on general topics and themes rather than specific article details
- Are questions someone might ask before reading the article
- Help with content discovery and SEO
- Cover areas like travel planning, cultural understanding, and practical advice

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


