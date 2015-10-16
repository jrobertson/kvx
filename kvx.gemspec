Gem::Specification.new do |s|
  s.name = 'kvx'
  s.version = '0.5.10'
  s.summary = 'Kvx (Keys, Values, and XML) makes it convenient to store ' \
      + 'and retrieve the simplest of data as plain text using a ' \
      + 'hash-like format or as XML.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('line-tree', '~> 0.5', '>=0.5.3') 
  s.add_runtime_dependency('rxfhelper', '~> 0.2', '>=0.2.3')
  s.signing_key = '../privatekeys/kvx.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/kvx'
end
