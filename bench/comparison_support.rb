require "fileutils"
require "json"
require "open3"
require "optparse"

module BenchmarkSupport
  ROOT = File.expand_path("..", __dir__)
  WORK = File.join(ROOT, "tmp/bench")
  KNOWN_APPS = %w[rails django laravel express express-bun elixir go rust c cpp].freeze
  DEFAULT_IMAGES = { "rails" => "once-campfire:app", "rust" => "campfire-rust:app", "elixir" => "campfire-elixir:app",
    "express-bun" => "once-campfire-express:bun" }.freeze

  Implementation = Struct.new(:app, :kind, :image, :source, :topology, keyword_init: true)

  # Where each selected app comes from. A known app's image defaults to its usual tag and its source to
  # <workspace>/once-campfire-<kind>. An app the harness doesn't know is accepted only when its image is
  # named (NAME_IMAGE, so a misspelt known app still fails); it gets no app-specific preparation, and
  # NAME_TOPOLOGY (a JSON object) describes it in the results. NAME_SOURCE overrides any app's checkout.
  def implementations(apps, env, workspace)
    raise "apps must be nonempty and unique" if apps.empty? || apps.uniq != apps
    apps.map do |app|
      raise "invalid app name: #{app}" unless app.match?(/\A[a-z][a-z0-9-]*\z/)
      name = app.upcase.tr("-", "_")
      known = KNOWN_APPS.include?(app)
      raise "#{app} isn't a known implementation; set #{name}_IMAGE to benchmark it" unless known || env["#{name}_IMAGE"]
      kind = app == "express-bun" ? "express" : app
      # A known app's topology comes from compare.rb; an unknown one's must be an object (not null).
      topology = known ? nil : JSON.parse(env.fetch("#{name}_TOPOLOGY", "{}"))
      raise "#{name}_TOPOLOGY must be a JSON object" unless known || topology.is_a?(Hash)
      Implementation.new(app: app, kind: kind, image: env.fetch("#{name}_IMAGE") { DEFAULT_IMAGES.fetch(app, "once-campfire-#{app}:app") },
        source: env.fetch("#{name}_SOURCE") { File.join(workspace, kind == "rails" ? "once-campfire" : "once-campfire-#{kind}") },
        topology: topology)
    end
  end

  def run(*command, input: nil)
    output, errors, status = Open3.capture3(*command, stdin_data: input, binmode: true)
    raise "#{command.first} failed (#{status.exitstatus}): #{errors}" unless status.success?
    output
  end

  def remove_container(name)
    Open3.capture3("docker", "rm", "-f", name)
  end

  def prepare_storage(seed, destination)
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
    FileUtils.cp_r(File.join(seed, "db"), File.join(destination, "db"))
    FileUtils.cp_r(File.join(seed, "storage"), File.join(destination, "files"))
  end

  def mounts(paths)
    paths.flat_map { |host, target| [ "-v", "#{host}:#{target}" ] }
  end

  def environment(values)
    values.flat_map { |name, value| [ "-e", "#{name}=#{value}" ] }
  end

  def write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def median(values)
    values = values.sort
    middle = values.length / 2
    values.length.odd? ? values[middle] : (values[middle - 1] + values[middle]) / 2.0
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
