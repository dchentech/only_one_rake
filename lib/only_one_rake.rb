module Rake
  WHOAMI = `whoami`.strip

  class ProcessStatusLine < Struct.new(:uid, :pid, :ppid, :c, :stime, :tty, :time, :cmd)
    def namespace_equal? namespace
      self.cmd.split.select {|i| i.match(/:/) }[0] == namespace
    end

    def working_dir_equal? working_dir
      `lsof -p #{self.pid} | grep cwd | grep DIR`.split[-1] == working_dir.strip
    end
  end

  def self.ensure_only_one_task_is_running name
    oors = `ps -u #{WHOAMI} -ef | grep rake | grep -v '/bash ' | grep -v 'grep rake'`.split("\n").map {|line| ProcessStatusLine.new *line.split(" ", 8) }
    Process.exit! 0 if oors.select {|oor| oor.namespace_equal?(name) && oor.working_dir_equal?(`pwd`) }.size > 1
  end

  module DSL
    private
    def only_one_task(*args, &block)
      task = Rake::Task.define_task(*args, &block)
      task.is_only_one_task = true
      task
    end
  end

  class Task
    attr_accessor :is_only_one_task

    # Execute the actions associated with this task.
    def execute(args=nil)
      args ||= EMPTY_TASK_ARGS
      if application.options.dryrun
        application.trace "** Execute (dry run) #{name}"
        return
      end
      if application.options.trace
        application.trace "** Execute #{name}"
      end
      application.enhance_with_matching_rule(name) if @actions.empty?

      # here's the patch!
      Rake.ensure_only_one_task_is_running name if is_only_one_task

      @actions.each do |act|
        case act.arity
        when 1
          act.call(self)
        else
          act.call(self, args)
        end
      end
    end
  end

end
