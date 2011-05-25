#
# Author: Phillip Coleman

class SEA_validate
  
  def initialize
  end

  def run(param)
    @bin_dir  = File.dirname($0)
    submit
  end

  private

  def submit
    dir = "#{ENV['HOME']}/.hgsc_solid/automation/"
    if File.exist?(dir+"blacklist.txt")
      running=File.readlines(dir+"ready.txt")
      
      running.each do |a|
        list=a.split(';')
        se=list[0]
        
        machine=se[0,4]
        year=se[5,4]
        month=se[9,2]

        ref=list[2]
        type=list[3]
        capture=list[4]
        capture.chomp!

        ignore=false
        File.open(dir+"blacklist.txt", "r") do |infile|
          while ((line = infile.gets) && !ignore)
            name_error=line.split(',')
            if (name_error[0].eql?(se))
              ignore=true
              puts "Ignoring #{se}: #{name_error[1]}"
            end
          end
        end

        if (!ignore)
          finishedJobs = %x( more /stornext/snfs5/next-gen/solid/csv_dump/csv.dump.latest.csv | grep #{se} )
          runningJobs = %x( bjobs -w | grep #{se} )
          zeros = %x( more /stornext/snfs5/next-gen/solid/csv_dump/csv.dump.latest.csv | grep #{se} | grep bam,0,0,0 )
          maindir="/stornext/snfs*/next-gen/solid/analysis/solid#{machine}/#{year}/#{month}/#{se}"

          if (!(finishedJobs.empty?) && zeros.empty?)
            running.delete(a)
          else
          
            if (!(zeros.empty?) && runningJobs.empty?)
              File.open(dir+"blacklist.txt", "a") {|f| f.puts("#{se},Zero Stats,")}
              puts "#{se} finished with zero stats"
            elsif (runningJobs.empty?)
              File.open(dir+"blacklist.txt", "a") {|f| f.puts("#{se},Errors,")}
              puts "#{se} ran into errors"
            end
        
          end
        end
      end        
    end

    File.open(dir+"ready.txt", "w") {|f| f.puts(running)}
  end
end
