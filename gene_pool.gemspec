Gem::Specification.new do |s|
  s.name          = "gene_pool"
  s.summary       = 'Highly performant Ruby connection pooling library.'
  s.description   = 'Threadsafe, performant library for managing pools of resources, such as connections.'
  s.authors       = ['Brad Pardee']
  s.email         = ['bradpardee@gmail.com']
  s.homepage      = 'http://github.com/bpardee/gene_pool'
  s.files         = Dir["{examples,lib}/**/*"] + %w(LICENSE.txt Rakefile Gemfile CHANGELOG.md README.md)
  s.test_files    = ["test/gene_pool_test.rb"]
  s.license       = 'MIT'
  s.version       = '1.5.0'
  s.require_paths = ["lib"]
  s.add_dependency 'concurrent-ruby', '>= 1.0'
end
