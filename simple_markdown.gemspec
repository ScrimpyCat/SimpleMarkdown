Gem::Specification.new do |gem|
    gem.name = 'simple_markdown'
    gem.version = '0.0.0'
    gem.license = 'BSD 2-Clause'
    gem.author = 'Stefan Johnson'
    gem.email = 'ScrimpyCat@gmail.com'

    gem.homepage = 'https://github.com/ScrimpyCat/SimpleMarkdown'
    gem.summary = 'A simple and extendable Markdown to HTML converter.'
    gem.description = """
    Supports the majority of the standard Markdown with the exceptions of
    references (for links, images) and no manual line breaking. It is extended
    to also support tables. For anything else, it can be easily extended to
    support any custom features.
    """.strip

    gem.files = ['lib/simple_markdown.rb']

    gem.required_ruby_version = '>= 1.9'
end