# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = "activerecord-bulk_update"
  spec.version     = "0.0.0"
  spec.summary     = "Updates multiple records with different values in a single database statement."
  spec.authors     = ["Nicke van Oorschot"]
  spec.email       = "devs@paytsoftware.com"
  spec.files       = Dir["lib/**/*.rb"]
  spec.homepage    = "https://github.com/payt/activerecord-bulk_update"
  spec.license     = "MIT"

  spec.add_dependency "activerecord", "> 6", "< 9"
end
