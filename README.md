# Introducing the Kvx gem

## Reading a Hash object

    require 'kvx'

    kvx = Kvx.new({:fun =&gt; '123', :apple =&gt; 'red'})

    puts kvx.to_xml

Output:

<pre>
&lt;?xml version='1.0' encoding='UTF-8'?&gt;
&lt;kvx&gt;
  &lt;fun&gt;123&lt;/fun&gt;
  &lt;apple&gt;red&lt;/apple&gt;
&lt;/kvx&gt;
</pre>


    s =<<EOF
    <kvx>
      <fun>123</fun>
      <apple>red</apple>
    </kvx>
    EOF

    h = Kvx.new(Rexle.new(s).root).to_h
    #=> {"kvx"=>{"fun"=>"123", "apple"=>"red"}} 

## Resource

* ?kvx https://rubygems.org/gems/kvx?

kvx gem
