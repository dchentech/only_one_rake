module Rake
  WHOAMI = `whoami`.strip

  class OOR < Struct.new(:uid, :pid, :ppid, :c, :stime, :tty, :time, :cmd)
    def nt_str; self.cmd.split.select {|i| i.match(/:/) }[0].split(':') end
    def namespace; self.nt_str[0] end
    def task; self.nt_str[1] end
    def equal?(n, t); self.nt_str == "#{n}:#{t}" end
  end

  # TODO support not only one namespace
  def self.ensure_only_one_task_is_running namespace, task = ""
    oors = `ps -u #{WHOAMI} -ef | grep rake | grep -v '/bash ' | grep -v 'grep rake'`.split("\n").map {|line| OOR.new *line.split(" ", 8) }

    Process.exit! 0 if oors.select {|oor| oor.equal? namespace, task }.size > 1
  end

  # From github.com/hongchen
  # Add to rake.gem/lib/rake/dsl_definition.rb
  module DSL
    private
    def only_one_task(*args, &block)
        name, params, deps = Rake.application.resolve_args(args.dup)
        scope = Rake.application.instance_variable_get(:@scope).dup[0].to_sym
        new_block = Proc.new do
          Rake.ensure_only_one_task_is_running scope, name.to_sym
          yield
        end
        Rake::Task.define_task(*args, &new_block)
    end
  end
end
