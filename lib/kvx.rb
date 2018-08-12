!#/usr/bin/env ruby

# file: kvx.rb

require 'line-tree'
require 'rxfhelper'
require 'rexle-builder'

###
# Kvx does the following:
#
# * h -> xml
# * xml -> h
# * s -> h

class Kvx
  include RxfHelperModule

  attr_accessor :attributes, :summary
  attr_reader :to_h

  def initialize(x, attributes: {}, debug: false)

    @header = false
    @identifier = 'kvx'
    @summary = {}
    @ignore_blank_lines ||= false
    
    @attributes, @debug = attributes, debug
    
    h = {
      hash: :passthru, 
      :'rexle::element' => :xml_to_h, 
      string: :parse_string,
      rexle: :doc_to_h,
      :"rexle::element::value" => :parse_string
    }
    
    @body = method(h[x.class.to_s.downcase.to_sym]).call x

  end
    
  def item()
    @body
  end
  
  alias body item
  
  def save(filename)
    FileX.write filename, self.to_s
  end
  
  def to_h()
    
    if @summary.empty? then
      deep_clone @body
    else
      {summary: deep_clone(@summary), body: deep_clone(@body)}
    end
    
  end
  
  def to_doc()
    
    a = if @summary.empty? then
      
      [self.class.to_s.downcase, @attributes, '', *make_xml(@body)]      
      
    else
      
      summary = make_xml(@summary)
      
      tags_found = summary.assoc(:tags)
      
      if tags_found then
        tags = tags_found.pop
        tags_found.push *tags.split.map {|x| [:tag,{},x]} 
      end

      summary = [:summary, {}, *summary]
      body = [:body, {}, *make_xml(@body)]
      [self.class.to_s.downcase, @attributes, '', summary, body]      
      
    end    
    
    Rexle.new a
    
  end
  
  def to_s()
    
    header = ''
    
    if @header or @summary.any? then
      
      attr = @attributes ? ' ' + @attributes\
                                       .map {|x| "%s='%s'" % x }.join(' ') : ''
      header = '<?' + @identifier
      header += attr
      header += "?>\n"
      header += scan_to_s @summary
      header += "\n----------------------------------\n\n"
    end
    
    header + scan_to_s(@body)

  end    

  def to_xml(options={pretty: true})
          
    doc = self.to_doc
    doc.xml(options)

  end

  private
  
  def deep_clone(h)
      
    h.inject({}) do |r, x|

      h2 = if x.last.is_a? Hash then
          [x.first, deep_clone(x.last)]
      else
        x
      end
      r.merge h2[0] => h2[1]
    end
    
  end  
  
  def doc_to_h(doc)
    xml_to_h(doc.root)
  end

  def get_attributes(raw_attributes)
#     
    r1 = /([\w\-:]+\='[^']*)'/
    r2 = /([\w\-:]+\="[^"]*)"/
    
    r =  raw_attributes.scan(/#{r1}|#{r2}/).map(&:compact)\
                                  .flatten.inject(Attributes.new) do |r, x|
      attr_name, raw_val = x.split(/=/,2) 
      val = attr_name != 'class' ? raw_val[1..-1] : raw_val[1..-1].split
      r.merge(attr_name.to_sym => val)
    end

    return r
  end
  
  def hashify(e)

    v = if e.has_elements? then 
      e.elements.inject({}) do |r, x|
        r.merge hashify(x)
      end
    else
      e.text
    end

    {e.name.to_sym => v}
  end  

  def make_xml(h)
    RexleBuilder.new(h).to_a[3..-1]
  end
  
  def parse_string(s)
    
    buffer, type = RXFHelper.read(s)
    puts 'buffer: ' + buffer.inspect if @debug
    buffer.lstrip =~ /^<\?xml/ ? xml_to_h(Rexle.new(buffer).root) : parse_to_h(buffer)
    
  end

  def parse_to_h(s, header_pattern: %r(^<\?kvx[\s\?]))

    raw_txt, _ = RXFHelper.read(s)

    # does the raw_txt contain header information? 
    a = s.strip.lines

    txt = if a[0] =~ header_pattern then
    
      raw_header = a.shift
      attr = get_attributes(raw_header)
      
      if attr[:created] then
        attr[:last_modified] = Time.now.to_s
      else
        attr[:created] = Time.now.to_s 
      end
      
      @attributes.merge! attr
      @header = true
      body, summary = a.join.strip.split(/^----*$/).reverse      
      @summary = scan_to_h summary
      
      body
    else
      raw_txt
    end
    
    scan_to_h(txt)
  end

  def passthru(x)
    
    if x[:summary] and x[:body]
      @summary = deep_clone x[:summary]
      deep_clone x[:body]
    else      
      deep_clone x
    end
    
  end
  
  def pretty_print(a, indent='')
    
    a.map do |x|  
      (x.is_a?(String) or x.nil?) ? x.to_s : pretty_print(x, indent + '  ')
    end.join("\n" + indent)
    
  end
    
  
  def scan_to_h(txt)

    puts 'inside scan_to_h' if @debug
    raw_a = LineTree.new(txt.gsub(/(^-*$)|(#.*)/,'').strip, 
                                              ignore_blank_lines: @ignore_blank_lines).to_a
    puts 'raw_a: ' + raw_a.inspect if @debug
    
    # if there are any orphan lines which aren't nested underneath a 
    #   label, they will be fixed using the following statement
    
    a = raw_a.chunk {|x| x[0][/^[^:]+:|.*/]}.inject([]) do |r,y|
      if r.last and !y.first[/[^:]+:/] then
        r.last << y.last[-1]
      else
        r << y.last[-1]
      end
      r
    end

    @body = a.inject({}) do |r, line|
           
      s = line.shift
      puts 's: ' + s.inspect
      
      if line.join.length > 0 then 

        r2 = if line[0][0][/^[^:]+:/] then

          padding = line[0].length < 2 ? "\n" : "\n  "
          
          scan_to_h(line.map{|x| x.join(padding)}.join("\n"))
          
        else

          desc = pretty_print(line).split(/\n(?=\w+: )/)         

          txt2, remaining = desc

          h = txt2.lines.inject([]) do |r, x| 
            x.chomp!
            x.length > 0 ?  r << x : r
          end
          
          r3 = {description: txt2, items: h}

          if remaining then
            r3.merge!(scan_to_h remaining + "\n ")
          end
          
          r3
        end

        r.merge({s[/[^:]+/].to_sym => r2})
        
      else
        
        value, name = s.split(': ',2).reverse
        name ||= 'description'          
        v = value =~ /^\{\s*\}$/ ? {} : value.to_s
        
        r.merge({name.to_sym => v})
      end     

    end
    
    puts '@body: ' + @body.inspect
    @body

  end     
  
  def scan_to_s(h, indent='')    
    
    a = h.inject([]) do |r, x|
      if x.last.is_a? Hash then
        r << x.first.to_s + ":\n" + scan_to_s(x.last, '  ')
      else
        r << "%s%s: %s" % [indent, *x]
      end
    end
    
    @to_s = a.join("\n")
  end
  
  def xml_to_h(node)
    
    summary = node.element('summary')
    
    if summary then

      etags = summary.element 'tags'
      
      if etags then

        tags = etags.xpath('tag/text()')
        etags.delete 'tag'
        etags.text = tags.join(' ') if tags.any?
        
      end

      @summary = hashify(summary)[:summary]
      @body = hashify(node.element('body'))[:body]
    else
      @body = hashify node
    end
  end

end
