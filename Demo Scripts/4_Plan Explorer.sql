/*-----------------------------------------------------------------------------
-- 4_Plan Explorer.sql
--
-- Written By: Andy Yun
-- Created On: 2021-10-19
-- 
-- Summary: 
-- 
-----------------------------------------------------------------------------*/
USE CookbookDemo
GO




-----
-- Query w. multiple predicates
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 
	Categories.CategoryName, Recipes.RecipeName, Recipes.DatePublished,
	RecipeAuthors.FirstName, RecipeAuthors.State,
	NutritionalInformation.Calories, NutritionalInformation.Protein_g, 
	NutritionalInformation.Sugar_g, NutritionalInformation.Fat_g

FROM dbo.Recipes
INNER JOIN dbo.Categories
	ON Categories.CategoryID = Recipes.CategoryID
INNER JOIN dbo.Authors AS RecipeAuthors
	ON RecipeAuthors.AuthorID = Recipes.AuthorId
INNER JOIN dbo.NutritionalInformation
	ON NutritionalInformation.RecipeID = Recipes.RecipeID

WHERE 
	Categories.CategoryName NOT IN ('Pork', 'Poultry', 'Apple')
	AND Recipes.DatePublished > '2005-01-01'
	AND NutritionalInformation.Calories > 150.0
	AND EXISTS (
		SELECT 1
		FROM dbo.RecipeIngredients
		INNER JOIN dbo.Ingredients
			ON RecipeIngredients.IngredientID = Ingredients.IngredientID
		WHERE Recipes.RecipeID = RecipeIngredients.RecipeID
			AND Ingredients.IngredientName IN ('mayonnaise', 'salt', 'garlic', 'brown sugar')
	);
GO

-- View missing index rec
-- Missing Index Details... 
-- Show Plan XML...
-- View with S1 PE








-----
-- Kitchen sink query V2
-- 
-- SKIP FOR NOW - will break Workload Analysis demo
-- Use PE to create RecipeIngredients example indexes instead then continue
--
-- Run WITH default NCI's
-- Note: Default NCI will fulfill need on dbo.RecipeIngredients
--EXEC dbo.sp_DropAllNCIs @PrintOnly = 0, @RestoreBaseNCIs = 1;
--GO

SELECT 
	Categories.CategoryName, Recipes.RecipeName, Recipes.DatePublished,
	RecipeAuthors.FirstName, RecipeAuthors.State,
	NutritionalInformation.Calories, NutritionalInformation.Protein_g, 
	NutritionalInformation.Sugar_g, NutritionalInformation.Fat_g

FROM dbo.Recipes
INNER JOIN dbo.Categories
	ON Categories.CategoryID = Recipes.CategoryID
INNER JOIN dbo.Authors AS RecipeAuthors
	ON RecipeAuthors.AuthorID = Recipes.AuthorId
INNER JOIN dbo.NutritionalInformation
	ON NutritionalInformation.RecipeID = Recipes.RecipeID

WHERE 
	Categories.CategoryName NOT IN ('Pork', 'Poultry', 'Apple')
	AND Recipes.DatePublished > '2005-01-01'
	AND NutritionalInformation.Calories > 150.0
	AND NutritionalInformation.Protein_g > 10.0
	AND NutritionalInformation.Sugar_g < 100.0
	AND EXISTS (
		SELECT 1
		FROM dbo.RecipeIngredients
		INNER JOIN dbo.Ingredients
			ON RecipeIngredients.IngredientID = Ingredients.IngredientID
		WHERE Recipes.RecipeID = RecipeIngredients.RecipeID
			AND Ingredients.IngredientName IN ('mayonnaise', 'salt', 'garlic', 'brown sugar')
	);
GO

-- View with S1 PE
-- Get fresh Estimated -> Index Analysis -> Recipe Ingredients








-----
-- OPTIONAL
-- 
-- Add Review sub-query: how does this differ from the first iteration?
SELECT 
	Categories.CategoryName, Recipes.RecipeName, Recipes.DatePublished,
	RecipeAuthors.FirstName, RecipeAuthors.State,
	NutritionalInformation.Calories, NutritionalInformation.Protein_g, 
	NutritionalInformation.Sugar_g, NutritionalInformation.Fat_g,
	ReviewSummary.NumberOfReviews
FROM dbo.Recipes
INNER JOIN dbo.Categories
	ON Categories.CategoryID = Recipes.CategoryID
INNER JOIN dbo.Authors AS RecipeAuthors
	ON RecipeAuthors.AuthorID = Recipes.AuthorId
INNER JOIN dbo.NutritionalInformation
	ON NutritionalInformation.RecipeID = Recipes.RecipeID
INNER JOIN (
	SELECT 
		Reviews.RecipeID,
		COUNT(Reviews.ReviewID) AS NumberOfReviews,
		AVG(HelpfulScore) AS AvgHelpfulScore,
		MIN(HelpfulScore) AS MinHelpfulScore,
		MAX(HelpfulScore) AS MaxHelpfulScore
	FROM dbo.Reviews
	WHERE 1 = (SELECT 1)
	GROUP BY
		Reviews.RecipeID
) AS ReviewSummary
	ON ReviewSummary.RecipeID = Recipes.RecipeID
WHERE 
	Categories.CategoryName NOT IN ('Pork', 'Poultry', 'Apple')
	AND Recipes.DatePublished > '2005-01-01'
	AND NutritionalInformation.Calories > 150.0
	AND ReviewSummary.AvgHelpfulScore > 3.0
	AND ReviewSummary.NumberOfReviews > 5
	AND EXISTS (
		SELECT 1
		FROM dbo.RecipeIngredients
		INNER JOIN dbo.Ingredients
			ON RecipeIngredients.IngredientID = Ingredients.IngredientID
		WHERE Recipes.RecipeID = RecipeIngredients.RecipeID
			AND Ingredients.IngredientName IN ('mayonnaise', 'salt', 'garlic', 'brown sugar')
	)
OPTION(RECOMPILE);


-- PE - how did the plan shape change?
-- Cost/Impact "scale threshold" theory
