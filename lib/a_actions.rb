#
# Author: Phillip Coleman

class Automation_actions
  def initialize(action_string)
    @a_string = action_string
    load_actions
  end

  def get_action
    create_action
  end

  private

  # create the necessary action class
  #
  def create_action
    case @a_string
      when "update"
        Helpers::log "Instanciating Action: #{@a_string}"
        SEA_update.new
      when "submit"
        Helpers::log "Instanciating Action: #{@a_string}"
        SEA_submit.new
      when "validate"
        SEA_validate.new
      else
        Helpers::log("ERROR: cannot find action: #{@a_string}", 1)
        exit 1
    end
  end

  # Load all the actions available
  #
  def load_actions
    bin_dir  = File.dirname($0)
    main_dir = File.dirname(bin_dir)

    lib_dir   = File.join(main_dir, "lib")
    a_lib_dir = lib_dir + "/a_actions"
    a_files   = Dir[File.join(a_lib_dir, "*.rb")]

    Dir[File.join(a_lib_dir, "*.rb")].each do |file|
      f = a_lib_dir + "/" + File.basename(file.gsub(/\.rb$/,''))
      Helpers::log "Loading action: #{f}"
      require f
    end
  end
end
