# Transhelvetica Magazine Analyzer

This repository contains tools and scripts for analyzing, processing, and managing issues of the Transhelvetica magazine. It is designed to help automate workflows such as extracting articles from PDFs, converting them to YAML, and organizing magazine content for further use.

## Features
- Extract articles from magazine PDFs
- Convert magazine content to structured YAML files
- Organize articles by issue
- Label and summarize articles

## Folder Structure
- `magazines/` — Contains magazine PDFs, YAML files, and extracted articles (ignored by git)
- `label_articles.rb` — Script for labeling articles
- `pdf_to_yaml.rb` — Script for converting PDFs to YAML
- `split_magazine.rb` — Script for splitting magazine content

## Getting Started
1. Clone the repository
2. Install Ruby and required gems
3. Run the provided scripts to process magazine files

## Usage
Example commands:
```bash
ruby pdf_to_yaml.rb magazines/trnshlvtc01.pdf
ruby split_magazine.rb magazines/trnshlvtc01.yaml
ruby label_articles.rb magazines/trnshlvtc01_articles/
```

## Contributing
Feel free to open issues or submit pull requests for improvements or new features.

## License
Specify your license here (e.g., MIT, GPL, etc.)
