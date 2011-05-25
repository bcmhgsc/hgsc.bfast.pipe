#!/usr/bin/ruby
#
# This class handles all SE information on the instrument.
#
# constructior: ip address of a machine. 
# (be sure the user can ssh into the machine)
#
# main methods:
#   check_storage(email_to = "nobody") - check storage of instrument.
#     It will email a warning to clean up if email is provided
#   se_on_machine(se = "all") - returns information of the SEs currently on the
#     instrument.  It will return the information of the specific SE if its 
#     given.
#   place_done_flag(se) - create a .slide_done.txt for the given SE on inst.
#
# Author: David Chen


$:.unshift File.join(File.dirname(__FILE__))
require 'rubygems'
require 'net/ssh'
require 'ostruct'
require 'emailer'
require 'helpers'

class Se_inst
  EMAIL_FROM = "p-solid@bcm.edu"
  STORAGE_THRESHOLD = 70
  def initialize(ip, df = 0)
    @ip = ip
    if df == 0
      @all_se = get_se_hash
    end
  end

  # checks the amount of free space for instrument
  def check_storage(email_to)
    Helpers::log("checking storage information..")
    df = ssh_df_inst
    if df.nil?
      Helpers::log("The storage information for #{hostname} cannot be accessed")
    else
      percentage = df.split(":")[2].to_i
      if percentage >= STORAGE_THRESHOLD
        hostname = ssh_hostname
        Helpers::log("#{hostname} has exceeded the storage threshold: " + 
                     "#{STORAGE_THRESHOLD}%.")
        if !email_to.nil?
          msg = "#{hostname} is currently at #{percentage}%.\n" +
                "It is over the #{STORAGE_THRESHOLD}% threshold.\n"
          Emailer::send_email(EMAIL_FROM, email_to,
                   "Time to clean up #{hostname}", msg)
        end
      end
      df
    end
  end

  # return the run name given the path to the file (csfasta, qual)
  def run_name_from_path(full_path)
    path = path_parse(full_path)
    bc = ""
    if path.bc.upcase.match(/BC/)
      bc = "_" + path.bc
    end
    return path.rname + "_" + path.sample + bc
  end

  # outputs all of the sequence event on the machine
  def se_on_machine(se = "all")
    if se == "all"
      Helpers::log("Showing all SE info on instrument..")
      @all_se.each do |k,v|
        Helpers::log("#{k}:#{se_type?(@all_se[k])}")
        @all_se[k].each do |f|
          Helpers::log("  " + f)
        end
      end
    else
      seq = matching_keys(se)
      if seq.size == 0
        Helpers::log("#{seq} is not found on the instrument " +
                     "or the raw data has not been created")
        return FALSE
      else
        seq.each do |s|
          Helpers::log("Showing info for #{s}..")
          Helpers::log("#{s}:#{se_type?(@all_se[s])}")
          @all_se[s].each do |f|
            Helpers::log(f)
          end
        end
      end
    end
    return TRUE
  end

  # create the machine_name, run_name, sample_name, and barcode_name into an 
  # ostruct obj
  # ie. /data/results/solid0714/0714_20100528_2_SP/ANG_TCOL_AA_A00L_10A_1_1sA_
  # 01003311206_4/results.F1B1/libraries/defaultLibrary/primary.20100605013237
  # 983/reads/0714_20100528_2_SP_ANG_TCOL_AA_A00L_10A_1_1sA_01003311206_4_F3_B
  # C14.csfasta
  def path_parse(path)
    dest = OpenStruct.new
    dest.mach   = path.split("/")[3]
    dest.rname  = path.split("/")[4]
    dest.sample = path.split("/")[5]
    dest.bc     = path.split("/")[8]
    dest
  end

  # set .slide_done.txt flag for the se finished on instrument
  def place_done_flag(se)
    if completed_se?(se)
      Helpers::log("The flag has already been created for #{se}. Skipping..")
      return FALSE
    else
      path = get_rname_path(se)
      if path == ""
        Helpers::log("#{se} not found on #{ssh_hostname}")
      else
        Helpers::log("Creating the slide done flag for #{se}.")
        Net::SSH.start(@ip, "pipeline") do |ssh|
          ssh.exec! "touch #{get_rname_path(se)}/.slide_done.txt"
        end
      end
    end
  end

  # returns an array of run names contains .slide_done.txt
  def completed_run
    temp = ssh_se_on_inst(1)
    complete_se = []
    temp.each do |s|
      complete_se << File.basename(File.dirname(s))
    end
    complete_se
  end

  # returns @all_se
  def all_se
    @all_se
  end

  # helper to return all of keys matching the given name
  def matching_keys(name)
    matched_keys = []
    @all_se.each_key do |k|
      if /#{name}/.match(k)
        matched_keys << k
      end
    end
    matched_keys
  end

  # gets the host name from the given ip
  def ssh_hostname
    name = ""
    Net::SSH.start(@ip, "pipeline") do |ssh|
      name = ssh.exec! "hostname -s"
    end
    name.downcase.chomp
  end

  private

  # checks if the se is completed on instrument
  def completed_se?(se)
    Helpers::log("Checks if .slide_done.txt is created for #{se}..")
    done_se = completed_run
    done_se.each do |s|
      if /#{s}/.match(se)
        return TRUE
      end
    end
    return FALSE
  end

  # get the type of the SE
  def se_type?(files)
    files.each do |f|
      if /3_BC\d+/.match(f)
        return "BC"
      elsif /_F5-P2/.match(f)
        return "PE"
      elsif /_R3/.match(f)
        return "MP"
      end
    end
    "FR"
  end

  # returns the path up to the SE rname
  def get_rname_path(se)
    matched = matching_keys(se)
    if matched.size == 0
      return ""
    end
    path = path_parse(@all_se[matched[0]][0])
    "/data/results/#{path.mach}/#{path.rname}"
  end

  # get the newest files based on the dates on primary direcotry
  def get_latest_file(files)
    temp = {:f3 => [], :r3 => [], :f5 => [], :misc =>[]}
    files.each do |fi|
      if /F3/.match(fi)
        temp[:f3] << fi
      elsif /R3/.match(fi)
        temp[:r3] << fi
      elsif /F5-P2/.match(fi)
        temp[:f5] << fi
      else
        temp[:misc] << fi
      end
    end
    temp.each do |k,v|
      if v.size != 0 && v.size != 2 && v.size != 1
        date = 0
        csfasta = ""
        qual = ""
        v.each do |f|
          num = /\w+.(\d+)/.match(File.basename(File.dirname(File.dirname(f))))
          if date <= num[1].to_i
            if /csfasta/.match(f)
              csfasta = f
            elsif /qual/.match(f)
              qual = f
            end
            date = num[1].to_i
          end
        end
        temp[k] = [csfasta, qual]
      end
    end
    temp.values.flatten
  end

  # returns the files in a hash table {se -> [csfasta,qual], ..}
  def get_se_hash
    files = sort_paths_to_hash(ssh_se_on_inst)
    files.each do |k,v|
      files[k] = get_latest_file(v)
    end
    files
  end

  # sort the csfasta, qual paths into its
  def sort_paths_to_hash(files)
    temp = {}
    files.each do |f|
      run = run_name_from_path(f)
      temp[run] = [f].concat([temp[run]]).flatten.compact
    end
    temp
  end

  # returns the disk usage on the results volume
  def ssh_df_inst
    df = ""
    Net::SSH.start(@ip, "pipeline") do |ssh|
      df = ssh.exec! "df -mh /data/results/"
    end
    msg = ssh_hostname
    df.split("\n")[2].split[2...4].each do |t|
      msg = msg + ":#{t}"
    end
    msg
  end

  # returns all of the csfasta, qual required for transferring
  def ssh_se_on_inst(slide_done = 0)
    files = ""
    Net::SSH.start(@ip, "pipeline") do |ssh|
      if slide_done == 1
        Helpers::log("Searching for .slide_done.txt on instrument..")
        files = ssh.exec! "ls /*/r*/solid*/*/.slide_done.txt"
      else 
        Helpers::log("Searching for files on instrument..")
        files = ssh.exec! "find /*/r*/solid*/*/*/r*.*/lib*/ -follow " +
                          "-name \"*csfasta\" -o -name \"*qual\" " +
                          "-o -name \"*Stat*txt\""
      end
    end
    temp = []
    if /No such/.match(files)
      Helpers::log("No files could be found.")
    else
      files.split.each do |f|
        if !/sampled/.match(f) && !/unassigned/.match(f) && !/_BC_/.match(f) &&
          !/missing/.match(f) && !/old/.match(f)
          temp << f
        end
      end
    end
    temp
  end
end
