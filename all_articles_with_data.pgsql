

SELECT
	magazines.magazine_number,
	articles.title,
	articles.start_page,
	COALESCE(
		ARRAY_AGG(DISTINCT article_topics.topic)
			FILTER (WHERE article_topics.topic IS NOT NULL),
		'{}'
	) AS topics,
	COALESCE(
		ARRAY_AGG(DISTINCT article_locations.location_type || ':' || article_locations.name)
			FILTER (WHERE article_locations.name IS NOT NULL),
		'{}'
	) AS locations
FROM articles
JOIN magazines ON articles.magazine_id = magazines.id
LEFT JOIN article_topics ON article_topics.article_id = articles.id
LEFT JOIN article_locations ON article_locations.article_id = articles.id
GROUP BY magazines.magazine_number, articles.title, articles.start_page

