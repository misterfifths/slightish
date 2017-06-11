require 'slightish/testsuite'

class Slightish::Command
    def self.run(argv)
        self.new.run(argv)
    end

    def run(test_files)
        Thread.abort_on_exception = true

        suites = []
        worker_threads = []

        test_files.each do |file|
            suite = Slightish::TestSuite.new(file)
            suites << suite
            worker_threads << Thread.new { suite.run }
        end

        worker_threads.each { |thread| thread.join }

        puts("----------")

        total_tests = 0
        total_passed = 0
        total_failed = 0
        max_suite_name_length = suites.max_by { |suite| suite.name.length }.name.length
        max_passed_length = suites.max_by { |suite| suite.passed_count }.passed_count.to_s.length
        max_failed_length = suites.max_by { |suite| suite.failed_count }.failed_count.to_s.length

        suites.each do |suite|
            total_tests += suite.test_cases.length
            total_passed += suite.passed_count
            total_failed += suite.failed_count

            line = suite.name.ljust(max_suite_name_length + 1).bold + "\t"
            line += "#{suite.passed_count.to_s.rjust(max_passed_length)} passed".green + "\t"
            line += "#{suite.failed_count.to_s.rjust(max_failed_length)} failed".red
            puts(line)
        end

        puts()
        puts("Total tests: ".bold + total_tests.to_s.gray)
        puts("Passed: ".green + total_passed.to_s.gray)
        puts("Failed: ".red + (total_tests - total_passed).to_s.gray)

        Process.exit(1) if total_failed > 0
    end
end
