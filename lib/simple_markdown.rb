#  Copyright (c) 2014, Stefan Johnson                                                  
#  All rights reserved.                                                                
#                                                                                      
#  Redistribution and use in source and binary forms, with or without modification,    
#  are permitted provided that the following conditions are met:                       
#                                                                                      
#  1. Redistributions of source code must retain the above copyright notice, this list 
#     of conditions and the following disclaimer.                                      
#  2. Redistributions in binary form must reproduce the above copyright notice, this   
#     list of conditions and the following disclaimer in the documentation and/or other
#     materials provided with the distribution.                                        
#  
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module SimpleMarkdown
    def convert(string, converters = :all)
        return "" if string == nil

        #converters can equal :all, :standard, :extended, { :all => true, SimpleMarkdown::Standard::Paragraph => false }, SimpleMarkdown::Standard::Paragraph => true
        converters = { converters => true } if converters.class == Symbol

        converter_list = Converter.converters
        if !converters[:all] || converters.length > 1
            converter_list.delete_if { |step| !step.can_use(converters) }
        end

        converted_string = ""
        while string.length > 0
            result = ""
            converter_list.each { |step|
                if (r = step.parse(string, converters)) == :empty
                    result = :empty
                else
                    result << r
                end

                break if result.length > 0
            }
            converted_string << (result.length == 0 ? string.slice!(0,1) : result) if result != :empty
        end

        converted_string
    end
    module_function :convert

    class Converter
        @@converters = []
        def self.converters
            Array.new(@@converters)
        end

        def self.inherited(subclass)
            @@converters << subclass
        end

        def self.skip_step
            @@converters.delete(self)
        end

        def self.include?(cls)
            if cls.class == Class
                self <= cls
            else
                super
            end
        end

        def self.place_before(steps)
            if index = @@converters.find_index { |converter|
                match = Proc.new { |s|
                    case s
                    when Class
                        converter <= s
                    when Module
                        converter.to_s.start_with? s.to_s
                    when Array
                        s.one? &match
                    end
                }
             
                match.call(steps)
            }

                if index < @@converters.find_index(self)
                    @@converters.delete(self)
                    @@converters.insert(index, self)
                end
            end
        end

        def self.can_use(converters)
            converters[self] == true || (converters[:all] && converters[self] != false)
        end

        def self.parse(string, converters)
            ""
        end
    end

    module Standard
        class StandardMarkdown < SimpleMarkdown::Converter
            skip_step
            def self.can_use(converters)
                super && (converters[:standard] != false)
            end
        end

        class Header < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A.*?\n=+(?!.)/)
                    string.slice!(0,1)
                    "<h1>#{SimpleMarkdown.convert(capture[/\A.*/], converters.merge(SimpleMarkdown::Standard::Paragraph => false))}</h1>"
                elsif capture = string.slice!(/\A.*?\n-+(?!.)/)
                    string.slice!(0,1)
                    "<h2>#{SimpleMarkdown.convert(capture[/\A.*/], converters.merge(SimpleMarkdown::Standard::Paragraph => false))}</h2>"
                elsif string.chr == '#'
                    6.downto(1).each { |i|
                        if capture = string.slice!(/\A\#{#{i}}.*/)
                            string.slice!(0,1)
                            return "<h#{i}>#{SimpleMarkdown.convert(capture[i..-1], converters.merge(SimpleMarkdown::Standard::Paragraph => false))}</h#{i}>"
                        end
                    }
                else
                    super
                end
            end
        end

        class HorizontalRule < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A *(-|\*)( {0,2}\1){2,} *(?![^\n])/)
                    "<hr />"
                elsif capture = string.slice!(/\A.*?\n(?= *(-|\*)( {0,2}\1){2,} *(?![^\n]))/)
                    SimpleMarkdown.convert(capture, converters)
                else
                    if !(capture = string.slice!(/^.*?(?=\n[[:space:]]*\n *(-|\*)( {0,2}\1){2,} *(?![^\n]))/m))
                        capture = string.slice!(0..-1)
                    end

                    SimpleMarkdown.convert(capture, converters.merge(self => false)) 
                end
            end
        end

        class PhraseEmphasis < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A\*\*.*?\*\*/) || capture = string.slice!(/\A__.*?__/)
                    "<strong>#{SimpleMarkdown.convert(capture[2..-3], converters)}</strong>"
                elsif capture = string.slice!(/\A\*.*?\*/) || capture = string.slice!(/\A_.*?_/)
                    "<em>#{SimpleMarkdown.convert(capture[1..-2], converters)}</em>"
                else
                    super
                end
            end
        end

        class List < StandardMarkdown
            def self.parseItems(point, string, converters)
                string.split(/^#{point}[[:blank:]]*/).drop(1).map { |item|
                        if content = item[/(?<=\n).*/m]
                            content = content.split("\n")
                            minIndent = content.map { |line| line[/[[:blank:]]*/].length }.min

                            content.map! { |line| line[minIndent..-1] }
                            content = content.join("\n")
                        end

                        "<li>#{SimpleMarkdown.convert(item[/.*/], converters.merge(SimpleMarkdown::Standard::Paragraph => false))}#{SimpleMarkdown.convert(content, converters)}</li>"
                }.join
            end

            def self.parse(string, converters)
                if capture = string.slice!(/\A\*[[:blank:]]+.*(\n([[:blank:]]|\*).*)*/)
                    "<ul>#{self.parseItems(/\*/, capture, converters)}</ul>"
                elsif capture = string.slice!(/\A[[:digit:]]\.[[:blank:]]+.*(\n([[:blank:]]|([[:digit:]]\.)).*)*/)
                    "<ol>#{self.parseItems(/[[:digit:]]\./, capture, converters)}</ol>"
                elsif capture = string.slice!(/\A.+(\*|([[:digit:]]\.)).*\n*/)
                    SimpleMarkdown.convert(capture, converters.merge(self => false))
                else
                    super
                end
            end
        end

        class PreformattedCodeBlock < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A(\n*( {4,}|\t{1,}).*)+/)
                    capture.slice!(/^\n/)
                    capture = "<pre><code>#{SimpleMarkdown.convert(capture.gsub!(/( {4}|\t{1})(?![ \t])/, ""), SimpleMarkdown::HTMLEntities::LiteralToHTMLEntity => true)}</code></pre>"
                else
                    super
                end
            end
        end

        class Paragraph < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A(.|\n)*?\n{2,}/) || capture = string.slice!(/\A(.|\n)*(\n|\z)/)
                    capture.strip!
                    capture.length > 0 ? "<p>#{SimpleMarkdown.convert(capture, converters.merge(self => false)).gsub(/\n/, ' ')}</p>" : :empty
                else
                    super
                end
            end
        end

        class Blockquote < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A>.*(\n([[:blank:]]|>).*)*/)
                    "<blockquote>#{SimpleMarkdown.convert(capture.gsub!(/^>[[:blank:]]*/, ""), converters.merge(SimpleMarkdown::Standard::Paragraph => true))}</blockquote>"
                elsif capture = string.slice!(/\A.+>.*\n*/)
                    SimpleMarkdown.convert(capture, converters.merge(self => false))
                else
                    super
                end
            end
        end

        class Link < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A\[.*?\]\(.*?\)/)
                    text = capture[/\A\[.*\]/][1..-2]
                    link = capture[text.length+3..-2].split(/ /, 2).map { |s| SimpleMarkdown.convert(s, converters.merge(:standard => false)) }
                    text = SimpleMarkdown.convert(text, converters)
                    link = "href=\"#{link[0]}\"" << (link.count == 2? " title=#{link[1]}" : "")

                    "<a #{link}>#{text}</a>"
                else
                    super
                end
            end
        end

        class Image < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A!\[.*?\]\(.*?\)/)
                    text = capture[/\A!\[.*\]/][2..-2]
                    link = capture[text.length+4..-2].split(/ /, 2).map { |s| SimpleMarkdown.convert(s, converters.merge(:standard => false)) }
                    text = SimpleMarkdown.convert(text, converters.merge(:standard => false))
                    link = "src=\"#{link[0]}\"" << (text.length > 0 ? " alt=\"#{text}\"" : "") << (link.count == 2? " title=#{link[1]}" : "")

                    "<img #{link} />"
                else
                    super
                end
            end
        end

        class CodeSpan < StandardMarkdown
            def self.parse(string, converters)
                if capture = string.slice!(/\A`[^`].*?`/)
                    "<code>#{SimpleMarkdown.convert(capture[1..-2].strip, SimpleMarkdown::HTMLEntities::LiteralToHTMLEntity => true)}</code>"
                else
                    super
                end
            end
        end

        #class ManualLineBreak < StandardMarkdown
        #   def self.parse(string, converters)
        #       super
        #   end
        #end
    end

    module HTMLEntities
        LITERALS_AND_ENTITIES = {
            "&" => "amp",
            "<" => "lt",
            ">" => "gt"
        }

        class LiteralToHTMLEntity < SimpleMarkdown::Converter
            def self.can_use(converters)
                self == LiteralToHTMLEntity ? converters[self] == true : super
            end

            def self.parse(string, converters)
                if entity = LITERALS_AND_ENTITIES[string.chr]
                    string.slice!(0,1)
                    "&#{entity};"
                else
                    super
                end
            end
        end

        class SafeLiteralToHTMLEntity < LiteralToHTMLEntity
            def self.parse(string, converters)
                if capture = string.slice!(/\A<.+>/)
                    SimpleMarkdown.convert(capture, converters.merge(self => false))
                elsif !string[/\A&[[:alnum:]]+;/] && !string[/\A&\#[[:xdigit:]]+;/] #&& !string[/\A<.+>/]
                    super
                else
                    ""
                end
            end
        end
    end

    module Extended
        class ExtendedMarkdown < SimpleMarkdown::Converter
            skip_step
            def self.can_use(converters)
                super && (converters[:extended] != false)
            end
        end

        class MultilineCodeSpan < ExtendedMarkdown
            place_before(Standard)
            def self.parse(string, converters)
                if capture = string.slice!(/\A`{3}.*?`{3}/m)
                    "<pre><code>#{SimpleMarkdown.convert(capture[3..-4].strip, SimpleMarkdown::HTMLEntities::LiteralToHTMLEntity => true)}</code></pre>"
                else
                    super
                end
            end
        end

        class Table < ExtendedMarkdown
            place_before(Standard)
            def self.addRow(type, row, converters, alignment = [])
                defaultAlignment = alignment[0]
                tableRow = "<tr>"

                row.split("|").each { |column|
                    column.strip!
                    if column.length > 0
                        align = alignment.shift
                        align = defaultAlignment if align == nil

                        tableRow << "<#{type}#{align}>#{SimpleMarkdown.convert(column, converters)}</#{type}>"
                    end
                }

                tableRow << "</tr>"
            end

            def self.getAlignments(row)
                alignments = []
                row.split("|").each { |column|
                    column.strip!
                    if column.length > 0
                        if column.chr == ':' && column[-1] == ':'
                            alignments << " style=\"text-align: center;\""
                        elsif column[-1] == ':'
                            alignments << " style=\"text-align: right;\""
                        else
                            alignments << " style=\"text-align: left;\""
                        end
                    end
                }

                alignments
            end

            def self.parse(string, converters)
                if capture = string.slice!(/\A.*\|.*\n(\|?[ :-]*?-[ :-]*){1,}.*(\n.*\|.*)*/)
                    convert = converters.merge(self => false, SimpleMarkdown::Standard::Paragraph => false)
                    table = "<table>"
                    rows = capture.split("\n")

                    table << "<thead>#{addRow('th', rows.shift, convert)}</thead>"

                    alignments = getAlignments(rows.shift)

                    table << "<tbody>"
                    rows.each { |row|
                        table << addRow("td", row, convert, Array.new(alignments))
                    }
                    table << "</tbody>"
                    table << "</table>"
                elsif capture = string.slice!(/\A(\|?[ :-]*?-[ :-]*){1,}.*(\n.*\|.*)+/)
                    convert = converters.merge(self => false, SimpleMarkdown::Standard::Paragraph => false)
                    table = "<table>"
                    rows = capture.split("\n")

                    alignments = getAlignments(rows.shift)

                    table << "<tbody>"
                    rows.each { |row|
                        table << addRow("td", row, convert, Array.new(alignments))
                    }
                    table << "</tbody>"
                    table << "</table>"
                else
                    super
                end
            end
        end
    end
end
