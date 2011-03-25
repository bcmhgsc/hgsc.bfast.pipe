#!/usr/bin/ruby
# This class encapsulates a Sequence Event name
#
# Example: 0312_20100211_1_SP_ANG_LVNC109718_1_1sA_01003280944_3
#
# constructor: string with the name of the sequence event
#
# public methods:
#
#  + instrument     : return instrument number (0312)
#  + l_barcode      : returns lims barcode (01003280944_3)
#  + spot?          : returns true if seq_event is a spot, false otherwise 
#  + slide?         : returns true if seq_event is slide, false otherwise 
#  + fr?            : returns true if seq_event is fragment, false otherwise 
#  + mp?            : returns true if seq_event is mate pair, false otherwise 
#  + to_s           : returns the run name for this sequence event
#  + get_run_name   : returns the run name from the specified path
#
# Author: David Rio Deiros

require 'helpers'

class Sequence_event
  def initialize(seq_event)
    @run_name = seq_event
    if valid?(@run_name) == false
      puts "#{@run_name} is invalid"
      exit 1
    end
  end

  def instrument
    return @run_name.slice(/^\d+/)
  end

  def l_barcode
    return @run_name.slice(/\d+_\d+$/)
  end

  def spot?
    if @run_name.match(/^\d+_\d+_\d+_SP_/)
      return true
    else
      return false
    end
  end

  def slide?
    if @run_name.match(/^\d+_\d+_\d+_SL_/)
      return true
    else
      return false
    end
  end

  def fr?
    if @run_name.match(/s\w_\d+_\d$/)
      return true
    else
      return false
    end
  end

  def mp?
    if @run_name.match(/p\w_\d+_\d$/) 
      return true
    else
      return false
    end
  end

  def pe?(raw_data)
    if raw_data.size == 4 and                                               # 4 raw files
       raw_data.inject(0) {|sum, i| i =~ /F5-/ ? sum + 1 : sum } == 2 and # 2 raw files with the regexp on it
       raw_data.inject(0) {|sum, i| i =~ /_F3/ ? sum + 1 : sum } == 2       # 2 raw files with the regexp on it
      true
    else
      false
    end
  end

  def to_s
    return @run_name
  end

  def same_name_as?(sea)
    # Given a directory path (to csfasta or qual),
    # discard everything that is not a run name
    # validate that the run name is of correct format
    # if valid, return the run name
    # else bail out
    r_name = File.basename(sea, '.*')
    #r_name.slice!(/_[a-z0-9A-Z]+_[a-z0-9A-Z]+$/)

    # A qual file will have suffix _F{R}3_QV OR _F5-P2_QV (new v4 format for PE data)
    # A csfasta file will have suffix F{R}3 OR _F5-P2_QV (new v4 format for PE data)
    # Following two statements remove these suffixes
    r_name.slice!(/_QV/)
    r_name.slice!(/-P2/)
    r_name.slice!(/-BC/)
    r_name.slice!(/_[FR][35]/)

    (valid?(r_name) and @run_name == r_name) ? true : false
  end

  def year
    return ((/^\d+_(\d\d\d\d)\d+_\d_S/).match(@run_name))[1]
  end

  def month
    return ((/^\d+_\d\d\d\d(\d\d)\d+_\d_S/).match(@run_name))[1]
  end

  def rname
    return ((/^(\d+_\d+_\d_S[L|P])/).match(@run_name))[1]
  end

  # check if jobs for the sea is in cluster
  def job_in_cluster?
    list = `bjobs -w | grep #{@run_name}`
    if list.empty?
      return false
    else
      return true
    end
  end

  private

# Method to validate run_name
  def valid?(run_name)
    valid_prefix = false
    valid_suffix = false 

    # Given run name is valid under the following conditions
    # i)  First 3 fields are numeric followed by SP or SL 
    # ii) Last 2 fields are numeric, and third from last field
    #     ends with sA (for fragment) or pA (for mate pair) or _BC\d+ for Barcode
    if run_name.match(/^\d+_\d+_\d+_SP_/) ||
       run_name.match(/^\d+_\d+_\d+_SL_/)
      valid_prefix = true
    end

    if run_name.match(/p\w_\d+_\d$/) ||
       run_name.match(/s\w_\d+_\d$/) ||
       run_name.match(/s\w_\d+_\d_BC\d+$/) ||
       run_name.match(/s\w_\d+_\d_bc\d+$/) ||
       run_name.match(/s\w_\d+_\d_\S+sA$/)
      valid_suffix = true
    end
    return valid_prefix && valid_suffix
  end
end
