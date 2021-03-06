# vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 tw=80
#
# Author: David Rio Deiros

require 'find'
require 'date'
require 'fileutils'

module Helpers

  curr_dir = FileUtils.pwd

  # TO DO: This has to by dynamic.
  # 
  SNFS             = %w(0 1 4 5).freeze
  L1_DIR           = `id -u -n`.chomp == "p-solid" ? "/stornext" :
                      curr_dir + "/tmp"
  SEA_DIR_TEMPLATE = "#{L1_DIR}/snfsSS/next-gen/solid/analysis/solidII"
  RAW_DIR_TEMPLATE = "#{L1_DIR}/snfsSS/next-gen/solid/results/solidII"
  SEA_SP_TEMPLATE  = "#{L1_DIR}/snfsSS/next-gen/solid/analysis/special/solidII"
  RAW_SP_TEMPLATE  = "#{L1_DIR}/snfsSS/next-gen/solid/results/special/solidII"

  SNFS_NUMBER      = "0"
  RUN_A_PATH       = `id -u -n`.chomp == "p-solid" ?
                      File.dirname($0) + "/../helpers/run_analysis.sh" :
                      curr_dir.gsub!(/test$/, "helpers/run_analysis.sh")

  def self.log(msg, bye=0)
    $stderr.puts "LOG: " + msg
    exit bye.to_i if bye != 0
  end

  # Look to see if a SEA directory for that sea already exists
  def self.dir_exists?(sea, special=false)
    found = []
    SNFS.each do |s|
      i_dir = SEA_DIR_TEMPLATE.gsub(/SS/, s).gsub(/II/, sea.instrument)
      if special
        i_dir = SEA_SP_TEMPLATE.gsub(/SS/, s).gsub(/II/, sea.instrument)
      end
      log("I can't find #{i_dir}", 1) unless File.exists?(i_dir)
      re = %r{ ^#{i_dir}/\d+/\d+/#{sea}$ }x
      log("Looking for SEA dirs in: #{i_dir}")
      Find.find(i_dir) {|p| found << p if p =~ re and File.directory?(p) }
    end

    found
  end

  def self.find_raw_data(sea, special=false)
    found = []
    SNFS.each do |s|
      path = RAW_DIR_TEMPLATE.gsub(/SS/, s).gsub(/II/, sea.instrument)
      if special
        path = RAW_SP_TEMPLATE.gsub(/SS/, s).gsub(/II/, sea.instrument)
      end
      log("I can't find #{path}", 1) unless File.exists?(path)
      log("Looking for raw data in: #{path}")
      Find.find(path) do |path|
        found << path if File.file?(path)             and
#                         !File.symlink?(path)         and
                         path =~ /(.csfasta$|.qual$)/ and
                         sea.same_name_as?(path)
      end
    end
    found
  end

  # Get a SEA dir
  def self.a_dir_for(sea, special_run)
    sea_dir_path = SEA_DIR_TEMPLATE.gsub(/SS/, SNFS_NUMBER).gsub(/II/, sea.instrument)
    if special_run
      sea_dir_path = SEA_SP_TEMPLATE.gsub(/SS/, SNFS_NUMBER).gsub(/II/, sea.instrument)
    end
    sea_dir_path + "/" +
    DateTime.now.year.to_s + "/" +
    sprintf("%.2d", DateTime.now.month) + "/" + 
    sea.to_s

  end

  # Create a bf.config.yaml and write to the proper location
  def self.dump_config(sea, bf_config, special_run)
    cfg_fname = a_dir_for(sea, special_run) + "/bf.config.yaml"
    Helpers::log "Creating config: #{cfg_fname}"
    File.open(cfg_fname, "w") {|f| f.write(bf_config)}
  end

  def self.create_dir(d)
    log("Couldn't create dir: #{d}, already exists", 1) if Dir.exists?(d)
    begin
      FileUtils.mkdir_p d
    rescue
      Helpers::log("Couldn't create dir: #{d}", 1)
    end
    log("dir created: #{d}")
  end

  def self.remove_dir(d)
    "\n### remove dir\n" + 
    "rm -rf #{d}\n\n"
  end

  def self.link_raw_data(sea_dir, raw_data)
    raw_data.each do |data_file|
      link_name = File.basename(data_file)

      # If the link is existing, bail out
      if File.exist?(sea_dir + "/" + link_name)
        Helpers::log "Link is existing. Bailing out.", 1
      end

      begin
        FileUtils.ln_s(data_file, sea_dir + "/" + link_name)
      rescue
        Helpers::log "Link is existing. Bailing out", 1
      end
    end 
  end

  def self.kill_jobs_for(sea)
    cmd = "\n### bkill jobs for this SEA\n"
    cmd << "for i in `bjobs -w | grep #{sea.to_s} | awk '{print $1}'`\n"
    cmd << "do\n"
    cmd << "  bkill $i\n"
    cmd << "done\n"
  end
  
  def self.remove_lims(sea)
    cmd = "\n### remove from LIMS\n"
    cmd << "/hgsc_software/java/jdk1.6.0_05/bin/java -jar " +
           "/users/p-lims/programs/analysis-data/solid2Lims.jar delete " +
           "\"name=#{sea}\""
  end

  def self.create_starting_script(sea, special_run)
    sea_dir = a_dir_for(sea, special_run)
    cmd = "\n### cd into the SEA and run the analysis\n"
    cmd << "cd #{sea_dir}" + "\n"
    cmd << RUN_A_PATH + " normal" + " > ./go.sh\n"
    cmd << "chmod 755 ./go.sh\n"
    cmd << "./go.sh\n"
  end
  
  def self.transferred?(sea, no_trans_check)
    machine = "solid#{sea.to_s.slice(0,4)}"
    done_slides = "#{ENV['HOME']}/.hgsc_solid/#{machine}/" +
                  "#{machine}_done_slides.txt"
    if no_trans_check
      return true
    elsif File.exist?(done_slides)
      known = File.open(done_slides).readlines.map!{ |e| e.chomp }
      return known.include?(sea.to_s)
    else
      Helpers::log "#{done_slides} cannot be found", 1
    end
  end

  # dump the start and end time of the SEA
  def self.start_end_time_output(sea_dir)
    tmp_start = "01/01/01_01:00"
    tmp_end = "01/01/01_01:00"
    time_stamp = "#{sea_dir}/time_stamps.txt"
    if File.exist?(time_stamp)
      File.open(time_stamp,"r").each do |l|
        if /START/.match(l)
          tmp_start = l.split()[1].chomp
        elsif /END/.match(l)
          tmp_end = l.split()[1].chomp
        end
      end
    end
    return tmp_start + DELIMITER + tmp_end
  end

  # checks if the sea is FR MP
  def self.check_fr?(name)
    if /_[\d]*sA_/.match(name)
      return "FR"
    else
      return "MP"
    end
  end

  # dumps the meta data of the SEA
  def self.gather_meta_data(sea_dir)
    tmp_ref = "/stornext/snfs5/next-gen/solid/bf.references/h/hsap.36.1.hg18/hsap_36.1_hg18.fa"
    tmp_bfast = "0.6.4d"
    tmp_picard = "1.07"
    tmp_mode = Helpers::check_fr?(sea_dir.split("/")[-1])
    tmp_gatk = "NA"

    meta = "#{sea_dir}/metadata.txt"
    if File.exist?(meta)
      File.open(meta, "r").each do |l|
        if /REF/.match(l)
          tmp_ref = l.split()[1].chomp
        elsif /BFAST/.match(l)
          tmp_bfast = l.split()[1].chomp
        elsif /PICARD/.match(l)
          tmp_picard = l.split()[1].chomp
        elsif /MODE/.match(l)
          tmp_mode = l.split()[1].chomp
        elsif /GATK/.match(l)
          tmp_gatk = l.split()[1].chomp
        end
      end
    end
    return tmp_ref + DELIMITER + tmp_bfast + DELIMITER + tmp_picard + DELIMITER +
           tmp_mode + DELIMITER + tmp_gatk
  end
  
  # creates the metadata file
  def self.create_metadata(path, ref, bfast, picard, mode, gatk = "NA")
    File.open("#{path}/metadata.txt", 'w') do |f|
      f.puts("REF #{ref}")
      f.puts("BFAST #{bfast}")
      f.puts("PICARD #{picard}")
      f.puts("MODE #{mode}")
      f.puts("GATK #{gatk}")
    end
  end
  
  # loads the given config file
  def self.load_config_file(file)
    obj = ""
    File.open(file, "r") do |infile|
      while (line = infile.gets)
        obj << line
      end
    end
    return YAML::load(obj)
  end
end
