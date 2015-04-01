require 'rspec/core/rake_task'
require 'erb'
require 'pty'
require 'expect'

RSpec::Core::RakeTask.new

task :default => :spec

desc "Deploy to Turbot"
task :deploy do
  (0..4).each do |num|
    @number = num
    manifest = ERB.new(File.read("manifest.json.erb")).result
    File.open("manifest.json", 'w+') {|f| f.write(manifest) }
    system "bundle exec turbot bots:register"
    system "bundle exec turbot bots:config NUMBER=#{@number}"
    PTY.spawn("bundle exec turbot bots:push") do |reader, writer|
      reader.expect(/Are you happy your bot produces valid data/, 5) # cont. in 5s if input doesn't match
      writer.puts('y')
      puts reader.gets
    end
    sleep 5
  end
end
