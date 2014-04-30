Gem::Specification.new do |s|
  s.name          = "gene_pool"
  s.summary       = 'Generic pooling library for creating a connection pool'
  s.description   = 'Generic pooling library for creating a connection pool'
  s.authors       = ['Brad Pardee']
  s.email         = ['bradpardee@gmail.com']
  s.homepage      = 'http://github.com/bpardee/gene_pool'
  s.files         = Dir["{examples,lib}/**/*"] + %w(LICENSE.txt Rakefile Gemfile History.md README.md)
  s.test_files    = ["test/gene_pool_test.rb"]
  s.version       = '1.4.1'
  s.require_paths = ["lib"]
  s.add_dependency('thread_safe')
end
