lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dynamodb/stream/enumerator/version"

Gem::Specification.new do |spec|
  spec.name          = "dynamodb-stream-enumerator"
  spec.version       = Dynamodb::Stream::Enumerator::VERSION
  spec.authors       = ["Johannes Würbach"]
  spec.email         = ["johannes.wuerbach@googlemail.com"]

  spec.summary       = %q{Simply enumerate AWS DynamoDB Streams}
  spec.description   = %q{dynamodb-stream-enumerator allows to simply enumerate AWS DynamoDB Streams}
  spec.homepage      = "https://github.com/johanneswuerbach/dynamodb-stream-enumerator"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-dynamodbstreams", "~> 1.13"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "aws-sdk-dynamodb", "~> 1.31"
  spec.add_development_dependency "standard", "~> 0.0.40"
  spec.add_development_dependency "simplecov", "~> 0.16.1"
end
