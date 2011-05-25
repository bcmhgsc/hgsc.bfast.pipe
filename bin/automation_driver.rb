#!/usr/bin/env ruby
#
# Main automation framework.
#
# Author: Phillip Coleman 

require 'optparse' 
require 'ostruct'
require 'date'
require 'logger'

$: << File.join(File.dirname(File.dirname($0)), "lib")
require 'a_actions'
require 'helpers'
#require 'load_libs'

#
class App
  VERSION = '0.0.1'
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments     = arguments
    @stdin         = stdin
    @valid_actions = /(update|submit|validate)/

    # Set defaults
    @options         = OpenStruct.new
    # TO DO - add additional defaults
  end

  # Parse options, check arguments, then process the command
  def run
    if parsed_options? && arguments_valid?
      log "Start at #{DateTime.now}\n"
      output_options

      process_arguments
      process_command
      log "Finished at #{DateTime.now}"
    else
      output_usage
    end
  end
  
  protected

    def parsed_options?
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version')        { output_version ; exit 0 }
      opts.on('-h', '--help')           { output_help }

      opts.on('-r', '--run_name r')     {|r| @options.run_name = r }
      opts.on('-a', '--action   a')     {|a| @options.action   = a }

      opts.parse!(@arguments) rescue return false

      log "Parsing options"
      process_options
      true
    end

    # Performs post-parse processing on options
    def process_options
    end
    
    def output_options
      @options.marshal_dump.each {|name, val| log "#{name} = #{val}" }
    end

    # True if required arguments were provided
    def arguments_valid?
      true
    end

    # Place arguments in instance variables
    def process_arguments
      @r_name         = @options.run_name
      @action         = @options.action
    end
    
    def output_help
      output_version
      RDoc::usage() #exits app
    end
    
    def output_usage
      puts DATA.read
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    def process_command
      puts @action
      error "Not valid action" unless @action =~ @valid_actions
      Automation_actions.new(@action).get_action.run(params_to_hash)
    end

    def process_standard_input
      input = @stdin.read      
      # TO DO - process input
      
      # @stdin.each do |line| 
      #  # TO DO - process each line
      #end
    end

    def params_to_hash
      {
        :r_name         => @r_name  , 
        :action         => @action
      }
    end

    def log(msg)
      Helpers::log msg.chomp
    end

    def error(msg)
      $stderr.puts "ERROR: " + msg + "\n\n"; output_usage; exit 1
    end
end

# Create and run the application
app = App.new(ARGV, STDIN)
app.run

__END__
Usage:
  automation_driver.rb [options]

Options:
 -h, --help           Displays help message
 -v, --version        Display the version, then exit

 -r, --run_name       Run_name
