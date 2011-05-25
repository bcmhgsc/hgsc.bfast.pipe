#!/usr/bin/env ruby19
#
# This tools creates the necessary cluster JOBS to complete 
# a SEA (Sequence Event Analysis)
#
# Author: David Rio Deiros, David Chen

$: << File.join(File.dirname(File.dirname($0)), "lib")
require 'load_libs'

# Load config
ui = UInterface.instance
config = Config.new( YAML::load(ui.load_config(ARGV, $0)) )

# Find path to the wrapper script to run bfast cmds and check 
# for successful execution
cmd_wrapper_scpt = File.dirname(__FILE__) + "/script.run.process.sh"

# Get list of read splits/files
#splits = Dir[config.global_reads_dir + "/*.fastq"]
path_to_fastqs = config.global_reads_dir + "/" + 
                 Misc::wild("fastq", config).gsub(/ /,'')
splits = Dir[path_to_fastqs.chomp]
puts "Splits wild = -#{path_to_fastqs.chomp}-"
puts "Splits found = #{splits.size}"

# Do we have bwaaln enabled?
bwaaln_flag = config.global_bwaaln == 1 ? true : false

# Prepare LSF 
moab = MoabDealer.new(config.input_run_name,
                      config.global_moab_queue,
                      cmd_wrapper_scpt,
                      config.global_trackdir,
                      splits.size)
# Prepare bfast cmd generation
cmds = BfastCmd.new(config, splits)

# Create the rg.txt file (@RG tag)
#Misc::create_rg_file(config)

# Per each split, create the basic bfast workflow with deps
#reg_job     = "rusage[mem=4000]"
#one_machine = "rusage[mem=28000]span[hosts=1]"

re_match  = config.match_moab_resources
re_local  = config.local_moab_resources
re_post   = config.post_moab_resources
re_tobam  = config.tobam_moab_resources
re_sort   = config.sort_moab_resources
re_dups   = config.dups_moab_resources
re_final  = config.final_moab_resources
re_rg = config.rg_moab_resources
re_stats  = config.stats_moab_resources
re_cap    = config.capture_moab_resources

final_deps = []

splits.each do |s|
  sn  = s.match(/\.(\d+)\./)[1]
  puts "Jobs for split: #{s.split} - #{sn}"
  if bwaaln_flag
    moab.add_job_to_file("match2bam" , cmds.bwaaln(s), sn)
    moab.add_job_to_file("match2bam" , cmds.local_u  , sn)
  else
    moab.add_job_to_file("match2bam" , cmds.match(s), sn)
    moab.add_job_to_file("match2bam" , cmds.local   , sn)
  end
  moab.add_job_to_file("match2bam", cmds.post, sn)
  moab.add_job_to_file("match2bam", cmds.tobam, sn)
  dep = moab.add_job_from_file("match2bam", sn, re_match)
  moab.blank "----------------"

  final_deps << dep
end

# when all the previous jobs are completed, we can merge all the bams
moab.add_job_to_file("merge2dups", cmds.final_merge, "")

# Sort and mark dups in the final BAM
moab.add_job_to_file("merge2dups", cmds.sort, "")
moab.add_job_to_file("merge2dups", cmds.dups, "")
moab.add_job_to_file("merge2dups", cmds.gen_rg, "")
dup_dep = moab.add_job_from_file("merge2dups", "", re_final, final_deps)


# Run stats
s_deps = []
if config.global_input_MP == 0 and config.global_bwaaln == 0
  s_deps << moab.add_job("stats", cmds.stats_frag, "", re_stats, [dup_dep])
else
  s_deps << moab.add_job("stats_F3", cmds.stats_f3, "", re_stats, [dup_dep])
  s_deps << moab.add_job("stats_R3", cmds.stats_r3, "", re_stats, [dup_dep])
end

# Run Bam Stats
s_deps << moab.add_job("bam_stats", cmds.bam_stats, "", re_stats, [dup_dep])

# Run BAM Reads Validation
s_deps << moab.add_job("bam_reads_val", cmds.bam_reads_validator, "", re_stats, [dup_dep])

# Run Capture Stats
caps_dir = config.capture_stats_dir
if config.global_input_CAP == 1
  Dir.mkdir(caps_dir)
  s_deps << moab.add_job("capture_stats", cmds.capture_stats, "", re_cap, [dup_dep])
end

# Clean up dirs
moab.add_job_to_file("clean2fin", cmds.clean_up, "")

# Email if the analysis went well
moab.add_job_to_file("clean2fin", cmds.email_success, "")

# saves the finished time stamp
moab.add_job_to_file("clean2fin", "#{File.dirname(File.dirname($0))}" +
            "/helpers/create_time.sh END time_stamps.txt", "")

# updating LIMS
moab.add_job_to_file("clean2fin", "/stornext/snfs5/next-gen/software/bin/ruby19 #{File.dirname(File.dirname($0))}" +
            "/helpers/update_lims_sea_stat.rb all", "")

moab.add_job_from_file("clean2fin", "", re_stats, s_deps)

moab.create_file
