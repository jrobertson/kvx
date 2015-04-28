!#/usr/bin/env ruby

# file: kvx.rb

require 'line-tree'
require 'rxfhelper'

###
# Kvx does the following:
#
# * h -> xml
# * xml -> h
# * s -> h

class Kvx

  attr_accessor :attributes
  attr_reader :to_h

  def initialize(x, attributes: {})

    @header = false
    @identifier = 'kvx'
    @attributes = attributes
    h = {hash: :passthru, :'rexle::element' => :hashify, string: :parse_to_h}
    @h = method(h[x.class.to_s.downcase.to_sym]).call x

  end
    
  def item()
    @h
  end

  def parse(t=nil)
    parse_to_h(t || @to_s)
  end        
  
  def to_h()
    deep_clone @h
  end
  
  def to_s()
    
    header = ''
    
    if @header then
      
      header = '<?' + @identifier
      header += ' ' + @attributes.map {|x| "%s='%s'" % x }.join(' ')
      header += "?>\n"
    end
    h = @to_h
    
    header + scan_to_s(@to_h)

  end    

  def to_xml(options={pretty: true})
  
    make_xml(@to_h)
        
    a = [self.class.to_s.downcase, @attributes, '', *make_xml(@to_h)]
    Rexle.new(a).xml(options)

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

  def get_attributes(raw_attributes)
    
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

    {e.name => v}
  end  

  def make_xml(h)

    h.map do |name, x|

      value = x.is_a?(Hash) ? make_xml(x) : x
      [name, {}, *value]

    end
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
      a.join
    else
      raw_txt
    end
    
    scan_to_h(txt)
  end

  def passthru(x)
    x
  end
  
  def pretty_print(a, indent='')
    
    a.map do |x|  
      (x.is_a?(String) or x.nil?) ? x.to_s : pretty_print(x, indent + '  ')
    end.join("\n" + indent)
    
  end
    
  
  def scan_to_h(txt)

    raw_a = LineTree.new(txt.gsub(/(^-*$)|(#.*)/,'').strip, 
                                              ignore_blank_lines: false).to_a
    
    # if there are any orphan lines which aren't nested underneath a 
    #   label, they will be fixed using the following statement
    
    a = raw_a.chunk {|x| x[0][/^\w+:|.*/]}.inject([]) do |r,y|
      if r.last and !y.first[/\w+:/] then
        r.last << y.last[-1]
      else
        r << y.last[-1]
      end
      r
    end
    

    @to_h = a.inject({}) do |r, line|
           
      s = line.shift
      

      if line.join.length > 0 then 

        r2 = if line[0][0][/^\w+: /] then

          scan_to_h(line.join("\n"))
          
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
        
        r.merge({name.to_sym => value.to_s})
      end     

    end    

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

end