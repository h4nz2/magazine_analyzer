SELECT
	magazines.magazine_number,
	articles.title,
	articles.start_page,
	COALESCE(
		ARRAY_AGG(DISTINCT article_questions.question)
			FILTER (WHERE article_questions.question IS NOT NULL),
		'{}'
	) AS questions
FROM articles
JOIN magazines ON articles.magazine_id = magazines.id
LEFT JOIN article_questions ON article_questions.article_id = articles.id
GROUP BY magazines.magazine_number, articles.title, articles.start_page
ORDER BY magazines.magazine_number, articles.start_page
LIMIT 20