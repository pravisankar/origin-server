# desc "Explaining what the task does"
# task :stick_shift do
#   # Task goes here
# end

namespace :test do
  root = StickShift::Engine.config.root.to_s

  Rake::TestTask.new :sanity => ['test:prepare'] do |t|
    t.libs << 'test'
    t.test_files = FileList[
      "#{root}/test/unit/cloud_user_unit_test.rb",
      "#{root}/test/unit/legacy_request_test.rb",
      "#{root}/test/functional/**/*_test.rb",
      "#{root}/test/integration/**/*_test.rb"
    ]
  end
  
  Rake::TestTask.new :ss_unit1 => ['test:prepare'] do |t|
    t.libs << 'test'
    t.test_files = FileList[
      "#{root}/test/unit/cloud_user_unit_test.rb",
      "#{root}/test/unit/legacy_request_test.rb",
    ]
  end
  
  Rake::TestTask.new :ss_unit2 => ['test:prepare'] do |t|
    t.libs << 'test'
    t.test_files = FileList[
      "#{root}/test/unit/rest_api_test.rb"
    ]
  end
  
  Rake::TestTask.new :ss_unit_ext1 => ['test:prepare'] do |t|
    t.libs << 'test'
    t.test_files = FileList[
      "#{root}/test/unit/rest_api_nolinks_test.rb"
    ]
  end
  
  Rake::TestTask.new :all => ['test:prepare'] do |t|
    t.libs << 'test'
    t.test_files = FileList[
      "#{root}/test/unit/cloud_user_unit_test.rb",
      "#{root}/test/unit/legacy_request_test.rb",
      "#{root}/test/unit/rest_api_test.rb",
      "#{root}/test/unit/rest_api_nolinks_test.rb",
      "#{root}/test/functional/**/*_test.rb",
      "#{root}/test/integration/**/*_test.rb"
    ]
  end
end
