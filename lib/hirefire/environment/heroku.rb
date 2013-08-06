require 'heroku-api'

module HireFire
  module Environment
    class Heroku < Base

      private

      ##
      # Either retrieves the amount of currently running workers,
      # or set the amount of workers to a specific amount by providing a value
      #
      # @overload workers(amount = nil)
      #   @param [Fixnum] amount will tell heroku to run N workers
      #   @return [nil]
      # @overload workers(amount = nil)
      #   @param [nil] amount
      #   @return [Fixnum] will request the amount of currently running workers from Heroku
      def workers(amount = nil)
        heroku = ::Heroku::API.new(:api_key => ENV['HEROKU_API_KEY']) 
        #
        # Returns the amount of Delayed Job
        # workers that are currently running on Heroku
        if amount.nil?
          processes = heroku.get_ps(ENV['APP_NAME']).body.select {|p| p['process'] =~ /worker.[0-9]+/}.length
          puts "Queried Heroku for processes - result: #{processes}"
          return processes
        end

        ##
        # Sets the amount of Delayed Job
        # workers that need to be running on Heroku
        return heroku.post_ps_scale(ENV['APP_NAME'], "worker", amount) 

      rescue ::Heroku::API::Errors
        # Heroku library uses rest-client, currently, and it is quite
        # possible to receive RestClient exceptions through the client.
        HireFire::Logger.message("Worker query request failed with #{ $!.class.name } #{ $!.message }")
        nil
      end
      
    end
  end
end
