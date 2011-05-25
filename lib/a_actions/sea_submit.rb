#
# Author: Phillip Coleman

class SEA_submit
  
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
      if File.exist?(dir+"ready.txt")
         blacklist=File.readlines(dir+"blacklist.txt")
         File.open(dir+"ready.txt", "r") do |infile|
           while (line = infile.gets)
             list=line.split(';')
             se=list[0]
             sample=list[1]
             lib=list[2]
             ref=list[3]
             type=list[4]
             capture=list[5]
             
             capture.chomp!
             

             ignore=false
             blacklist.each do |line|
               name_error=line.split(',')
               if (name_error[0].eql?(se))
                 ignore=true
                 puts "Ignoring #{se}: #{name_error[1]}"
                 #blacklist.delete(line)
               end
             end
           
             if (!ignore)
               finishedJobs = %x( more /stornext/snfs5/next-gen/solid/csv_dump/csv.dump.latest.csv | grep #{se} )
               runningJobs = %x( bjobs -w | grep #{se} )
               if (runningJobs.eql?(""))
                 if (finishedJobs.eql?(""))
                   if (se.include?("TREN") || se.include?("TLVR"))
                     finished = system( "sh #{File.dirname(@bin_dir)}/helpers/submit_analysis.sh #{se} #{sample} #{lib} /users/p-solid/ezexome2_hg19 #{type} /stornext/snfs0/next-gen/solid/bf.references/h/GRCh37-lite/GRCh37-lite.hg19.fa" )
                   else
                     finished = system( "sh #{File.dirname(@bin_dir)}/helpers/submit_analysis.sh #{se} #{sample} #{lib} #{capture} #{type} /stornext/snfs0/next-gen/solid/bf.references/h/hsap.36.1.hg18/hsap_36.1_hg18.fa" )
                   end
                 end
               end
             else
               puts "#{se} was skipped"
               #puts "Resubmitting #{se}"
               #finished = system( "sh #{File.dirname(@bin_dir)}/helpers/remove_analysis.sh #{se}" )
               #if (se.include?("TREN"))
               #  finished = system( "sh #{File.dirname(@bin_dir)}/helpers/submit_analysis.sh #{se} #{sample} #{lib} /users/p-solid/ezexome2_hg19 #{type} /stornext/snfs0/next-gen/solid/bf.references/h/GRCh37-lite/GRCh37-lite.hg19.fa" )
               #else
               #  finished = system( "sh #{File.dirname(@bin_dir)}/helpers/submit_analysis.sh #{se} #{sample} #{lib} #{capture} #{type} /stornext/snfs0/next-gen/solid/bf.references/h/hsap.36.1.hg18/hsap_36.1_hg18.fa" )
               #end
             end
           end
         end
         #File.open(dir+"blacklist.txt", "w") {|f| f.puts(blacklist)}
      else
        "No jobs ready"
      end
    else
      "Black List not properly initialized"
    end
  end
end
