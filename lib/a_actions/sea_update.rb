#
# Author: Phillip Coleman

class SEA_update
  
  def initialize
  end

  def run(param)
    @bin_dir  = File.dirname($0)
    query
    check_completion
  end

  private

  def query
    bin_dir  = File.dirname($0)
    main_dir = File.dirname(bin_dir)

    help_dir = File.join(main_dir, "helpers")
    script = File.join(help_dir, "getNotAnalysisLibraryInfo.pl")
                
    @runInfo = %x( perl #{script} )

  end

  def check_completion
    @runInfo.each_line do |name|
      list=name.split(';')
      se=list[0]
      machine=se[0,4]
      ref=list[2]
      type=list[3]
      capture=list[4]
      dir = "#{ENV['HOME']}/.hgsc_solid/automation/"
      transdir = "#{ENV['HOME']}/.hgsc_solid/solid#{machine}/solid#{machine}_done_slides.txt"
      ready = false
      if File.exist?(dir+"ready.txt")
        File.open(dir+"ready.txt", "r") do |infile|
          while (line = infile.gets)
            if (line == name)
              ready = true
            else
            end
          end
        end
      else
        puts "No runs ready."
      end

      if (!ready)
        if File.exist?(transdir)
          trans = false
          File.open(transdir, "r") do |infile|
            while ((line = infile.gets) && trans != true)
              line.chomp!

              if (se.eql?(line))
                File.open(dir+"ready.txt", "a") {|f| f.puts(name)}
                trans = true
              else
               
              end
            end
          end

          if (!trans)
            machine=se[0,18]
            finished = system( "ruby #{@bin_dir}/transfer_driver.rb -a completed_se -r " + machine)
          else

          end
        else
          puts "No transfers finished."
        end
      else

      end
    end
  end
end
