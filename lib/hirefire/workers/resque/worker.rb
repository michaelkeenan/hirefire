# encoding: utf-8

##
# HireFire
# This is a HireFire modified version of
# the official Resque::Worker class
module ::Resque
  class Worker

    def work(interval = 5.0, &block)
      interval = Float(interval)
      $0 = "resque: Starting"
      startup

      loop do
        break if shutdown?

        pause if should_pause?

        # Added HireFire hiring
        ::Resque::Job.environment.hire

        if job = reserve(interval)
          Resque.logger.info "got: #{job.inspect}"
          job.worker = self
          working_on job

          if @child = fork(job) do
              unregister_signal_handlers
              procline "Processing #{job.queue} since #{Time.now.to_i}"
              reconnect
              perform(job, &block)
            end
            srand # Reseeding
            procline "Forked #{@child} at #{Time.now.to_i}"
            begin
              Process.waitpid(@child)
            rescue SystemCallError
              nil
            end
            job.fail(DirtyExit.new($?.to_s)) if $?.signaled?
          else
            procline "Processing #{job.queue} since #{Time.now.to_i}"
            reconnect
            perform(job, &block)
          end
          done_working
          @child = nil
        else
          
          ##
          # HireFire Hook
          # After the last job in the queue finishes processing, Resque::Job.jobs will return 0.
          # This means that there aren't any more jobs to process for any of the workers.
          # If this is the case it'll command the current environment to fire all the hired workers
          # and then immediately break out of this infinite loop.
          if (::Resque::Job.jobs + ::Resque::Job.working) == 0
            break if ::Resque::Job.environment.fire
          end
        end
      end

      unregister_worker
    rescue Exception => exception
      unregister_worker(exception)
    end
  end
end
