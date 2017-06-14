require 'rake/testtask'
require 'rubocop/rake_task'

desc 'Run tests'
Rake::TestTask.new do |t|
  ENV.delete('SLIGHTISH_TEMPLATE_DIR')
  ENV['SLIGHTISH_NO_COLOR'] = '1'
  ENV['SLIGHTISH_NO_WARNINGS'] = '1'
  t.test_files = FileList['test/**/*_test{s,}.rb']
end
task default: :test

desc 'Run rubocop'
RuboCop::RakeTask.new(:rubocop)

desc 'Run rubocop'
task lint: :rubocop
