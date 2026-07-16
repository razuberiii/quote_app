namespace :visual_review do
  desc "Create deterministic, non-production evidence data"
  task seed: :environment do
    puts JSON.pretty_generate(VisualReviewSeeder.call)
  end
end
