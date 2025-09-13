

SELECT
	magazines.magazine_number,
	articles.title,
	articles.start_page,
  articles.end_page,
	COALESCE(
		ARRAY_AGG(DISTINCT article_locations.location_type || ':' || article_locations.name)
			FILTER (WHERE article_locations.name IS NOT NULL),
		'{}'
	) AS locations,
	COALESCE(
		ARRAY_AGG(DISTINCT article_categories.label)
			FILTER (WHERE article_categories.label IS NOT NULL),
		'{}'
	) AS categories,
	COALESCE(
		ARRAY_AGG(DISTINCT article_keywords.keyword)
			FILTER (WHERE article_keywords.keyword IS NOT NULL),
		'{}'
	) AS keywords
FROM articles
JOIN magazines ON articles.magazine_id = magazines.id
LEFT JOIN article_locations ON article_locations.article_id = articles.id
LEFT JOIN article_categories ON article_categories.article_id = articles.id
LEFT JOIN article_keywords ON article_keywords.article_id = articles.id
GROUP BY magazines.magazine_number, articles.title, articles.start_page, articles.end_page
ORDER BY magazines.magazine_number, articles.start_page
LIMIT 20

