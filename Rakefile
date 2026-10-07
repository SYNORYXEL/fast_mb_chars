# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |task|
  task.libs << 'lib' << 'test'
  task.test_files = FileList['test/**/*_test.rb']
  task.warning = false
end

desc 'Compare limit against a full grapheme walk at several sizes'
task :benchmark do
  ruby 'benchmark/compare.rb'
end

task default: :test
