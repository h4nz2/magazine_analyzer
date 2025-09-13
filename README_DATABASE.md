# Magazine Article Database System

This system imports magazine articles from YAML files into a PostgreSQL database (Neon) and provides search functionality.

## Setup Instructions

### 1. Install Dependencies

```bash
bundle install
```

Or manually install:
```bash
gem install pg dotenv
```

### 2. Configure Database Connection

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Edit `.env` and add your Neon PostgreSQL connection string:
```
DATABASE_URL=postgres://username:password@ep-your-project.region.aws.neon.tech:5432/neondb?sslmode=require
```

### 3. Create Database Schema

Run the setup script:

```bash
ruby db_setup.rb
# Or with connection string directly:
ruby db_setup.rb "postgres://username:password@host:port/database?sslmode=require"
```

This will:
- Test the database connection
- Create all necessary tables and indexes

### 4. Import Articles

Import all YAML articles into the database:

```bash
ruby import_articles.rb
```

### 5. Search Articles

Use the search interface:

```bash
ruby search_articles.rb
```

## Database Schema

The system uses the following tables:

- **magazines**: Store magazine information
- **articles**: Main articles table with title, content, and metadata
- **article_pages**: Many-to-many relationship for article pages
- **article_images**: Store article images (base64 encoded)
- **article_locations**: Store location references
- **article_topics**: Store article topics
- **article_keywords**: Store article keywords

## Search Capabilities

The search system supports:

1. **Keyword search**: Search in titles, content, and keywords
2. **Topic search**: Find articles by topic (e.g., "mountains", "culture")
3. **Location search**: Find articles mentioning specific locations
4. **Full-text search**: German language full-text search with ranking
5. **Article details**: Get complete information about a specific article

## Example Searches

After importing data, you can search for:

- Articles about mountains: Topic search → "mountains"
- Articles mentioning Zürich: Location search → "Zürich"
- Swiss culture articles: Full-text search → "Schweizer Kultur"

## Files Description

- `db_setup.rb`: Creates database schema
- `import_articles.rb`: Imports YAML articles into database
- `search_articles.rb`: Interactive search interface
- `.env.example`: Example environment configuration
- `Gemfile`: Ruby dependencies

## Security Notes

- Never commit `.env` file with real credentials
- Use SSL mode for Neon connections (`sslmode=require`)
- The connection string includes username and password