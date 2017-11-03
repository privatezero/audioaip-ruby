#!/usr/bin/env ruby

require 'os'
require 'yaml'
require 'optparse'
require 'bagit'
#Enter Location of Configuration File between the single quotes In this section!!
########
configuration_file = '' 
########

# Confirm and set config
path2script = __dir__
DefaultConfigLocation = "#{path2script}/audioaipruby_config.txt"
if configuration_file.empty?
	configuration_file = DefaultConfigLocation
end

if ! File.exist? configuration_file
	puts "Selected configuration file not found. Exiting"
	exit
end

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options] [inputfile1] [inputfile2] ..."

  opts.on("-e", "--edit", "Edit Configuration") do |e|
    options[:edit] = 'edit'
  end
  opts.on("-p", "--photo", "Photo Mode") do |p|
  	options[:photo] = 'photo'
  end
  opts.on("-h", "--help", "Help") do
    puts opts
    exit
  end
  if ARGV.empty?
    puts opts
  end
end.parse!

Targetlist = Array.new

def validtarget?(inputfile)
	if File.extname(inputfile) != '.wav'
		puts "Input #{inputfile} is not a WAV file. Skipping."
	elsif ! File.exist?(inputfile)
		puts "Input #{inputfile} not found. Skipping."
	else
		Targetlist << inputfile
	end
end

ARGV.each do|file_input|
	validtarget? file_input
end
