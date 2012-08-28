Gem::Specification.new do |s|
  s.name        = 'model_cached'
  s.version     = '0.1.0'
  s.authors     = ['Ary Djmal']
  s.email       = ['arydjmal@gmail.com']
  s.summary     = 'Rails gem that gives you the ability to transparently cache single active record objects using memcached.'
  s.homepage    = 'http://github.com/arydjmal/model_cached'

  s.add_dependency 'rails', '>= 3.0.0'

  s.add_development_dependency 'rake'

  s.files = Dir["#{File.dirname(__FILE__)}/**/*"]
end
