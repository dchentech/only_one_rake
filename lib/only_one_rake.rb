module Rake
  WHOAMI = `whoami`.strip

  class ProcessStatusLine < Struct.new(:uid, :pid, :ppid, :c, :stime, :tty, :time, :cmd)
    def nt_str; self.cmd.split.select {|i| i.match(/:/) }[0] end
    def namespace; self.nt_str.split(':')[1..-2].join(":") end
    def task; self.nt_str.split(':')[-1] end
    def equal? name; self.nt_str == name end
  end

  # TODO support not only one namespace
  def self.ensure_only_one_task_is_running name
    oors = `ps -u #{WHOAMI} -ef | grep rake | grep -v '/bash ' | grep -v 'grep rake'`.split("\n").map {|line| ProcessStatusLine.new *line.split(" ", 8) }
    Process.exit! 0 if oors.select {|oor| oor.equal? name }.size > 1
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

      # patch
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
