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

require_relative 'markdown'

module Extension
    class Block < Markdown::Converter
        skip_step
        def self.parse(string, converters)
            if start_index = (string =~ /\A#{identifier}\{/)
                inside_block = 1
                index = start_index + string[/\A#{identifier}\{/].length
                end_index = 0
                (index..string.length).each { |i|
                    case string[i]
                    when '{'
                        inside_block += 1
                    when '}'
                        if (inside_block -= 1) == 0
                            end_index = i
                            break
                        end
                    end
                }

                if end_index > 0
                    return execute(string, converters, (start_index..end_index), (index..end_index-1))
                end
            end

            super
        end

        def self.identifier
            ""
        end

        def self.execute(string, converters, block_range, body_range)
            superclass.parse(string, converters)
        end
    end

    class ExecBlock < Block
        place_before(Markdown)
        def self.identifier
            /@ruby[[:space:]]*/m
        end

        def self.execute(string, converters, block_range, body_range)
            string[block_range] = eval string[body_range]
            ""
        end
    end

    class StyleBlock < Block
        place_before(Markdown)
        def self.identifier
            /@style.*?/m
        end

        def self.execute(string, converters, block_range, body_range)
            styles = string[block_range.min+6..body_range.min-2].split("\n").map! { |style|
                s = style.strip
                if s.length > 0
                    s[-1] == ';' ? s : s << ';'
                end
                s
            }.join
            string[block_range] = "<span style=\"#{styles}\">#{string[body_range]}</span>"
            ""
        end
    end
end
