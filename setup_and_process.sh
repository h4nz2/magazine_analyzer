#!/bin/bash

# PDF Magazine Summarizer - Setup and Processing Script
# This script sets up the project and processes all PDF magazines

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PDF Magazine Summarizer Setup and Processing ===${NC}"
echo

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local result

    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt [Y/n]: " result
            result=${result:-y}
        else
            read -p "$prompt [y/N]: " result
            result=${result:-n}
        fi

        case $result in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

echo -e "${YELLOW}=== Dependency Check and Setup ===${NC}"

# Check and install Ruby
if ! command_exists ruby; then
    echo -e "${RED}Ruby is not installed.${NC}"
    if prompt_yes_no "Install Ruby using rbenv (recommended)" "y"; then
        echo "Installing rbenv and Ruby..."

        # Install rbenv
        if ! command_exists rbenv; then
            if command_exists apt-get; then
                sudo apt-get update
                sudo apt-get install -y rbenv ruby-build
            elif command_exists yum; then
                sudo yum install -y rbenv ruby-build
            elif command_exists dnf; then
                sudo dnf install -y rbenv ruby-build
            else
                echo -e "${RED}Cannot install rbenv automatically. Please install Ruby manually.${NC}"
                exit 1
            fi
        fi

        # Initialize rbenv
        export PATH="$HOME/.rbenv/bin:$PATH"
        eval "$(rbenv init -)"

        # Install Ruby
        RUBY_VERSION=$(prompt_with_default "Ruby version to install" "3.1.0")
        rbenv install "$RUBY_VERSION"
        rbenv global "$RUBY_VERSION"

        # Reload shell
        source ~/.bashrc || true

    else
        echo -e "${RED}Please install Ruby manually and run this script again.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Ruby is already installed: $(ruby --version)${NC}"
fi

# Check and install Bundler
if ! command_exists bundle; then
    echo "Installing Bundler..."
    gem install bundler
else
    echo -e "${GREEN}Bundler is already installed: $(bundle --version)${NC}"
fi

# Check for PostgreSQL client tools
if ! command_exists psql; then
    echo -e "${RED}PostgreSQL client tools are not installed.${NC}"
    if prompt_yes_no "Install PostgreSQL client tools" "y"; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y postgresql-client libpq-dev
        elif command_exists yum; then
            sudo yum install -y postgresql postgresql-devel
        elif command_exists dnf; then
            sudo dnf install -y postgresql postgresql-devel
        else
            echo -e "${RED}Cannot install PostgreSQL client tools automatically.${NC}"
            echo "Please install them manually and run this script again."
            exit 1
        fi
    else
        echo -e "${YELLOW}Warning: PostgreSQL client tools not installed. Database operations may fail.${NC}"
    fi
else
    echo -e "${GREEN}PostgreSQL client tools are installed.${NC}"
fi

# Install Ruby gems
echo -e "${YELLOW}Installing Ruby gems...${NC}"
if [ -f "Gemfile" ]; then
    bundle install
else
    echo -e "${RED}Gemfile not found! Please run this script from the project root directory.${NC}"
    exit 1
fi

echo

# Environment setup
echo -e "${YELLOW}=== Environment Configuration ===${NC}"

if [ ! -f ".env" ]; then
    echo -e "${RED}.env file not found. Setting up environment variables...${NC}"

    echo "Please provide your database connection details:"
    DB_URL=$(prompt_with_default "PostgreSQL DATABASE_URL" "postgres://username:password@host:port/database?sslmode=require")

    echo "DATABASE_URL=$DB_URL" > .env
    echo -e "${GREEN}.env file created successfully.${NC}"
else
    echo -e "${GREEN}.env file already exists.${NC}"

    # Check if DATABASE_URL is set
    source .env
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}DATABASE_URL not set in .env file.${NC}"
        DB_URL=$(prompt_with_default "PostgreSQL DATABASE_URL" "postgres://username:password@host:port/database?sslmode=require")
        echo "DATABASE_URL=$DB_URL" >> .env
    fi
fi

# API Configuration
echo
echo "API Configuration for AI services:"
echo "The scripts support Claude (default), OpenAI, and Ollama APIs."

if prompt_yes_no "Do you want to configure API keys now" "y"; then

    if prompt_yes_no "Configure Claude API key (Anthropic)" "y"; then
        CLAUDE_KEY=$(prompt_with_default "ANTHROPIC_API_KEY" "")
        if [ -n "$CLAUDE_KEY" ]; then
            echo "ANTHROPIC_API_KEY=$CLAUDE_KEY" >> .env
        fi
    fi

    if prompt_yes_no "Configure OpenAI API key" "n"; then
        OPENAI_KEY=$(prompt_with_default "OPENAI_API_KEY" "")
        if [ -n "$OPENAI_KEY" ]; then
            echo "OPENAI_API_KEY=$OPENAI_KEY" >> .env
        fi
    fi

    if prompt_yes_no "Configure Ollama endpoint (for local AI)" "n"; then
        OLLAMA_URL=$(prompt_with_default "OLLAMA_BASE_URL" "http://localhost:11434")
        echo "OLLAMA_BASE_URL=$OLLAMA_URL" >> .env
    fi
fi

echo

# Processing options
echo -e "${YELLOW}=== Processing Configuration ===${NC}"

LLM_PROVIDER=$(prompt_with_default "Which AI provider to use for labeling and questions (claude/openai/ollama)" "claude")

if prompt_yes_no "Run image description step (recommended but optional)" "y"; then
    RUN_IMAGE_DESC=true
else
    RUN_IMAGE_DESC=false
fi

if prompt_yes_no "Set up database (required for first run)" "y"; then
    SETUP_DB=true
else
    SETUP_DB=false
fi

if prompt_yes_no "Import articles to database after processing" "y"; then
    IMPORT_DB=true
else
    IMPORT_DB=false
fi

echo

# Check for PDF files
echo -e "${YELLOW}=== Checking for PDF magazines ===${NC}"

PDF_COUNT=$(find magazines/ -name "*.pdf" -type f 2>/dev/null | wc -l)

if [ "$PDF_COUNT" -eq 0 ]; then
    echo -e "${RED}No PDF files found in magazines/ directory.${NC}"
    echo "Please add PDF magazines to the magazines/ directory and run this script again."
    exit 1
else
    echo -e "${GREEN}Found $PDF_COUNT PDF magazine(s) to process.${NC}"
    find magazines/ -name "*.pdf" -type f | while read -r pdf; do
        echo "  - $(basename "$pdf")"
    done
fi

echo

# Final confirmation
echo -e "${BLUE}=== Processing Summary ===${NC}"
echo "The following steps will be executed:"
echo "1. Convert PDFs to YAML format"
echo "2. Split magazines into individual articles"
if [ "$RUN_IMAGE_DESC" = true ]; then
    echo "3. Generate AI descriptions for images"
fi
echo "4. Label articles with AI ($LLM_PROVIDER)"
echo "5. Generate reader questions with AI ($LLM_PROVIDER)"
if [ "$SETUP_DB" = true ]; then
    echo "6. Set up database schema"
fi
if [ "$IMPORT_DB" = true ]; then
    echo "7. Import articles to database"
fi

echo

if ! prompt_yes_no "Proceed with processing" "y"; then
    echo "Processing cancelled."
    exit 0
fi

echo

# Start processing
echo -e "${GREEN}=== Starting Magazine Processing ===${NC}"

# Step 1: Convert PDFs to YAML
echo -e "${BLUE}Step 1: Converting PDFs to YAML...${NC}"
ruby pdf_to_yaml.rb
echo -e "${GREEN}✓ PDF to YAML conversion completed${NC}"

# Step 2: Split into articles
echo -e "${BLUE}Step 2: Splitting magazines into articles...${NC}"
ruby split_magazine.rb
echo -e "${GREEN}✓ Magazine splitting completed${NC}"

# Step 3: Describe images (optional)
if [ "$RUN_IMAGE_DESC" = true ]; then
    echo -e "${BLUE}Step 3: Generating image descriptions...${NC}"
    ruby describe_images.rb
    echo -e "${GREEN}✓ Image descriptions completed${NC}"
fi

# Step 4: Label articles
echo -e "${BLUE}Step 4: Labeling articles with AI ($LLM_PROVIDER)...${NC}"
ruby label_articles_llm.rb all "$LLM_PROVIDER"
echo -e "${GREEN}✓ Article labeling completed${NC}"

# Step 5: Generate questions
echo -e "${BLUE}Step 5: Generating reader questions with AI ($LLM_PROVIDER)...${NC}"
ruby generate_questions.rb all "$LLM_PROVIDER"
echo -e "${GREEN}✓ Question generation completed${NC}"

# Step 6: Setup database (optional)
if [ "$SETUP_DB" = true ]; then
    echo -e "${BLUE}Step 6: Setting up database schema...${NC}"
    ruby db_setup.rb
    echo -e "${GREEN}✓ Database setup completed${NC}"
fi

# Step 7: Import to database (optional)
if [ "$IMPORT_DB" = true ]; then
    echo -e "${BLUE}Step 7: Importing articles to database...${NC}"
    ruby import_articles.rb
    echo -e "${GREEN}✓ Database import completed${NC}"
fi

echo
echo -e "${GREEN}=== Processing Complete! ===${NC}"
echo
echo "Summary:"
echo "- Processed $PDF_COUNT PDF magazine(s)"
echo "- Created individual article files in magazines/*_articles/ directories"
echo "- Added AI-generated labels and categories"
echo "- Generated reader questions for content discovery"

if [ "$IMPORT_DB" = true ]; then
    echo "- Imported all articles to PostgreSQL database"
    echo
    echo "You can now run queries on your database using the provided SQL files:"
    echo "  - all_articles_with_data.pgsql"
    echo "  - all_articles_with_questions.pgsql"
fi

echo
echo -e "${BLUE}Next steps:${NC}"
echo "- Review the processed articles in magazines/*_articles/ directories"
echo "- Use the database queries to search and analyze your magazine content"
echo "- Add more PDFs to magazines/ directory and re-run this script to process them"

echo
echo -e "${GREEN}Setup and processing completed successfully!${NC}"