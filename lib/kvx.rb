!#/usr/bin/env ruby

# file: kvx.rb

require 'line-tree'
require 'rxfhelper'
require 'rexle-builder'

module RegGem

  def self.register()
'
hkey_gems
  doctype
    kvx
      require kvx
      class Kvx
      media_type kvx
'
  end
end

###
# Kvx does the following:
#
# * h -> xml
# * xml -> h
# * s -> h

class Kvx
  include RXFHelperModule
  using ColouredText

  attr_accessor :attributes, :summary
  attr_reader :to_h

  def initialize(x=nil, attributes: {}, debug: false)

    @header = attributes.any?
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

    if x then

      sym = h[x.class.to_s.downcase.to_sym]
      puts 'sym: ' + sym.inspect if @debug
      @body = method(sym).call x
      methodize(@body)
    end

  end

  def import(s)
    @body = parse_string(s)
    methodize(@body)
  end

  def item()
    @body
  end

  alias body item

  def save(filename)
    FileX.write filename, self.to_s
  end

  # flattening is helpful when passing the Hash object to
  # RecordX as a new record
  #
  def to_h(flatten: false)

    if @summary.empty? then

      deep_clone @body

    else

      if flatten then
        @summary.merge @body
      else
        {summary: deep_clone(@summary), body: deep_clone(@body)}
      end

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

      # -- use the nested description Hash object if there are multiple lines
      h = {}

      @body.each do |key, value|

        h[key] = value.is_a?(String) ? value : value[:description]

      end

      body = [:body, {}, *make_xml(h)]
      [self.class.to_s.downcase, @attributes, '', summary, body]

    end

    puts 'a: ' + a.inspect if @debug
    doc = Rexle.new a
    doc.instructions = @instructions || []
    doc

  end

  def to_s()

    header = ''

    if @header or (@summary and @summary.any?) then

      attr = @attributes ? ' ' + @attributes\
                                       .map {|x| "%s='%s'" % x }.join(' ') : ''
      header = '<?' + @identifier
      header += attr
      header += "?>\n"

      if @summary and @summary.any? then
        header += scan_to_s @summary
        header += "\n----------------------------------\n\n"
      end

    end

    # -- use the nested description Hash object if there are multiple lines
    h = {}

    @body.each do |key, value|

      h[key] = if value.is_a?(String) then

        if value.lines.length < 2 then
          value
        else
          "\n" + value.lines.map {|x| '  ' + x }.join
        end

      else
          "\n" + value[:description].lines.map {|x| '  ' + x }.join
      end

    end

    header + scan_to_s(h)

  end

  def to_xml(options={pretty: true})

    doc = self.to_doc
    doc.xml(options)

  end

  def to_xslt()

    summary = self.summary.keys.map do |key|
      "    	<xsl:element name='#{key}'><xsl:value-of select='#{key}' /></xsl:element>"
    end.join("\n")

    body = self.body.keys.map do |key|
      "    	<xsl:element name='#{key}'><xsl:value-of select='#{key}' /></xsl:element>"
    end.join("\n")

s = "
<xsl:stylesheet xmlns:xsl='http://www.w3.org/1999/XSL/Transform' version='1.0'>

  <xsl:template match='kvx'>

    <xsl:element name='kvx'>

        <xsl:attribute name='created'>
        <xsl:value-of select='@created'/>
      </xsl:attribute>
      <xsl:attribute name='last_modified'>
        <xsl:value-of select='@last_modified'/>
      </xsl:attribute>

      <xsl:apply-templates select='summary' />
      <xsl:apply-templates select='body' />

    </xsl:element>

  </xsl:template>

  <xsl:template match='summary'>

    <xsl:element name='summary'>

#{summary}

    </xsl:element>

  </xsl:template>

  <xsl:template match='body'>

    <xsl:element name='body'>

#{body}

    </xsl:element>

  </xsl:template>

</xsl:stylesheet>
"

  end

  # used by RecordX to update a KVX record
  # id is unnecssary because there is only 1 record mapped to RecordX
  #
  def update(id=nil, hpair={})
    @body.merge! hpair
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

    puts 'inside make_xml: ' + h.inspect if @debug
    h2 = h.clone
    h2.each {|key,value| value.delete :items if value.is_a?(Hash) }

    RexleBuilder.new(h2, debug: false).to_a[3..-1]
  end

  def parse_string(s)

    buffer, type = RXFHelper.read(s)
    puts ('buffer: ' + buffer.inspect).debug if @debug

    if buffer.lstrip =~ /^<\?xml/ then

      s = buffer.force_encoding("UTF-8")
      doc = Rexle.new(s)
      @instructions = doc.instructions
      puts '@instructions: ' + @instructions.inspect if @debug

      xml_to_h(doc.root)

    else
      parse_to_h(buffer)
    end

  end

  def methodize(h)

    h.each do |k,v|

      define_singleton_method(k){v} unless self.methods.include? k

      unless self.methods.include? (k.to_s + '=').to_sym then
        define_singleton_method((k.to_s + '=').to_sym){|x| h[k] = x}
      end

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
      body, summary = a.join.strip.split(/^----*$/).reverse
      @summary = scan_to_h summary if summary

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

    txt.gsub!(/^\w+:(?=$)/,'\0 ')
    puts 'txt:'  + txt.inspect if @debug

    # auto indent any multiline values which aren't already indented

    indent = ''

    lines = txt.gsub(/^-+$/m,'').lines.map do |line|

      if not line[/^ *[^:]+:|^ +/] then
        indent + '  ' + line
      else
        indent = line[/^ +/] || ''
        line
      end

    end
    puts ('lines: ' + lines.inspect).debug if @debug

    puts ('inside scan_to_h').info if @debug
    raw_a = LineTree.new(lines.join.gsub(/(^-*$)|(?<=\S) +#.*/,'').strip,
                         ignore_blank_lines: @ignore_blank_lines).to_a
    puts ('raw_a: ' + raw_a.inspect).debug if @debug

    # if there are any orphan lines which aren't nested underneath a
    #   label, they will be fixed using the following statement

    a = raw_a.chunk {|x| x[0][/^[^:]+:/]}.inject([]) do |r,y|


      puts 'r: ' + r.inspect if @debug

      if r.last and !y.first[/[^:]+:/] then
        r.last << y.last[-1]
      else
        puts 'y: ' + y.inspect if @debug
        r << y.last[-1]
      end

      r

    end

    @body = a.inject({}) do |r, line|

      s = line.shift
      puts ('s: ' + s.inspect).debug if @debug

      if line.join.length > 0 then

        puts 'line: ' + line.inspect if @debug

        padding = line[0].length < 2 ? "\n" : "\n  "
        s10 = line.map{|x| x.join(padding)}.join("\n")

        r2 = if s10[/^ *\w+:[\n ]/] then

          scan_to_h(s10)

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

        value, name = s.split(/: */,2).reverse
        name ||= 'description'
        v = value =~ /^\{\s*\}$/ ? {} : value.to_s

        r.merge({name.to_sym => v})
      end

    end

    puts ('@body: ' + @body.inspect).debug if @debug
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

    puts 'node: ' + node.xml.inspect if @debug
    @attributes = node.attributes.to_h

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
