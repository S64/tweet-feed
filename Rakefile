namespace :init do
  task :bundle do
    system 'bundle install --path vendor/bundle'
  end
end

namespace :app do
  task :up do
    system 'bundle exec rackup'
  end
end
