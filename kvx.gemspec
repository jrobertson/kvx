Gem::Specification.new do |s|
  s.name = 'kvx'
  s.version = '0.1.2'
  s.summary = 'kvx'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('line-tree', '~> 0.5', '>=0.5.0') 
  s.add_runtime_dependency('rxfhelper', '~> 0.1', '>=0.1.12')
  s.signing_key = '../privatekeys/kvx.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/kvx'
end
