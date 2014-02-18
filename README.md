SimpleMarkdown
==============

A simple and extendable Markdown to HTML converter.

This probably won't be of much interest for anyone else. I needed a Markdown implementation that was extendable yet very simple to port to other languages. This implementation is extremely slow because of the nature of how it parses the Markdown, however this was done on purpose to keep its simplicity.

It supports the majority of the standard Markdown with the exception of references (for links, images) and no manual line breaking. It also supports tables.