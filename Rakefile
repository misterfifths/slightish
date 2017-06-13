require 'rake/testtask'
require 'rubocop/rake_task'

desc 'Run tests'
Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*_test{s,}.rb']
end
task default: :test

desc 'Run rubocop'
RuboCop::RakeTask.new(:rubocop)

desc 'Run rubocop'
task lint: :rubocop
