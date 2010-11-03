#
# Author: David Rio Deiros

class SEA_create
  def initialize
  end

  def run(params)
    perform_create(params[:sea], params[:c_design], params[:force_mp], 
                   params[:force_pe], params[:pival], params[:no_trans_check],
                   params[:special_run])
  end

  private

  def dump_raw_data_found(raw_data)
    tmp_file = "/tmp/fire.#{rand 10000}.txt"
    File.open(tmp_file, "w") do |f|
      raw_data.each {|e| f << e + "\n" }
    end
    Helpers::log "Logging raw_data in: " + tmp_file
  end

  def check_for_sea_dirs(sea, special_run)
    Helpers::log "Checking if SEA is already there ..."
    Helpers::dir_exists?(sea, special_run)
  end

  def print_seas_found(sds)
    sds.each_with_index {|s,i| Helpers::log("#{i}. #{s}", 1) }
  end

  def perform_create(sea, c_design, force_mp, force_pe, pival, no_trans_check,
                     special_run)
    # A. check /stornext/snfs(1/4)/next-gen/solid/analysis/solid0312 to see 
    #    if the SEA directory exists. 
    #    Bail out: printing the path to the SEA dir found.
    sea_dirs_found = check_for_sea_dirs(sea, special_run)
    
    # If found anything .. complain
    # If all cool (nothing found), get the full path to the SEA dir we'll use
    sea_dir = ""
    if sea_dirs_found.size > 1
      Helpers::log("Found more than 1 SEA directory :(")
      print_seas_found(sea_dirs_found)
    elsif sea_dirs_found.size == 1
      Helpers::log("Found the SEA directory already :( #{sea_dirs_found[0]}", 1)
    else
      sea_dir = Helpers::a_dir_for(sea, special_run)
      Helpers::log("Good, not found, SEA dir will be: #{sea_dir}")
    end
   
    # B. Look for the csfasta and qual files
    #    Bail out: Couldn't find raw data files
    #    Bail out: >= 4 raw files ... MP (.csfasta + qual) x 2
    #    Bail out: >= 2 raw files ... FR (.csfasta + .qual)
    raw_data = Helpers::find_raw_data(sea, special_run)
    Helpers::log("# of raw data files found: (#{raw_data.size})")
    if raw_data.size == 0
      Helpers::log("There is no raw data. Bailing out", 1)
    elsif !Helpers::transferred?(sea, no_trans_check) #&& !no_trans_check
      Helpers::log("The raw data have not been fully transferred", 1)
    elsif sea.mp? and raw_data.size != 4 
      dump_raw_data_found(raw_data)
      Helpers::log("SEA is MP but raw data != 4 (#{raw_data.size})", 1)
    elsif sea.pe?(raw_data) and raw_data.size != 4
      dump_raw_data_found(raw_data)
      Helpers::log("SEA is PE but raw data != 4 (#{raw_data.size})", 1)
    elsif sea.fr? and raw_data.size != 2 and !sea.pe?(raw_data) and !force_pe
      dump_raw_data_found(raw_data)
      Helpers::log("SEA is FR but raw data != 2 (#{raw_data.size})", 1)
    else
      dump_raw_data_found(raw_data)
      Helpers::log "raw data found"
    end

    # Tell the user what kind of SE I detected.
    Helpers::log "sea.fr?: #{sea.fr?} "
    Helpers::log "sea.pe?: #{sea.pe?(raw_data)} "
    Helpers::log "sea.mp?: #{sea.mp?} "
   
    # C. Generate config:
    mp_detection = (sea.mp? or  force_mp)  ? "1" : "0"
    pe_detection = ((sea.pe?(raw_data) and !force_mp) or (sea.fr? and force_pe)) ? "1" : "0"
    Helpers::log "cfg MP: #{mp_detection}"
    Helpers::log "cfg PE: #{pe_detection}"

    bf_config = Yaml_template.new.to_s
    bf_config.gsub!(/__RN__/        , sea.to_s)
    bf_config.gsub!(/__IMP__/       , mp_detection)
    # This is a little bit confusing but it is the only option since we don't have a marker
    # in the SE names for PE data (for v4 we can check the raw data filenames)
    bf_config.gsub!(/__PE__/        , pe_detection)
    bf_config.gsub!(/__ICAP__/      , c_design ? "1" : "0")
    bf_config.gsub!(/__RUN_DIR__/   , sea_dir + "/input")
    bf_config.gsub!(/__READS_DIR__/ , sea_dir + "/reads")
    bf_config.gsub!(/__OUTPUT_DIR__/, sea_dir + "/output")
    bf_config.gsub!(/__CD__/        , c_design ? c_design : "" )
    bf_config.gsub!(/__PIVAL__/     , pival)

    # D. create SEA dir, input dir and links to raw data
    Helpers::create_dir(sea_dir)
    Helpers::create_dir(sea_dir + "/input")
    Helpers::link_raw_data(sea_dir + "/input", raw_data)

    # E. Dump the config
    Helpers::dump_config(sea, bf_config, special_run)

    # F. Create go.sh on dir
    puts Helpers::create_starting_script(sea, special_run)
    Helpers::log "Done."
  end
end
