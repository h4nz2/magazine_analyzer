# Pdf magazine summarizer

This is a very simple repository, whose goal is to build something, that will be able to take pdf of a magazine issue and convert it into a form, that will allow AI powered searching through the magazines and its articles.

## Tech stack

Preferably ruby programming language, alternatively other programming languages if the task cannot be done in ruby. Using language models for various tasks is also permitted.

## Code structure

The app consist of several independent scripts, which when run in proper sequence, will do the following:

1. convert magazines from pdf to yaml
2. split magazines into individual articles, saved in separate files
3. replace images in the articles with AI generated description of the image
4. classify each article and add various labels
5. store the classified articles in a database

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


