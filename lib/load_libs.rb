# vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 tw=80

bin_dir  = File.dirname($0)
main_dir = File.dirname(bin_dir)

lib_dir = File.join(main_dir, "lib")
puts "Lib dir: #{lib_dir}"
Dir[File.join(lib_dir, "*.rb")].each do |file| 
  puts "Loading #{file}"
  require File.basename(file)
end