Gem::Specification.new do |s|
  s.name = 'kvx'
  s.version = '0.6.2'
  s.summary = 'Kvx (Keys, Values, and XML) makes it convenient to store ' \
      + 'and retrieve the simplest of data as plain text using a ' \
      + 'hash-like format or as XML.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/kvx.rb']
  s.add_runtime_dependency('line-tree', '~> 0.5', '>=0.5.6') 
  s.add_runtime_dependency('rxfhelper', '~> 0.4', '>=0.4.0')
  s.signing_key = '../privatekeys/kvx.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/kvx'
end
