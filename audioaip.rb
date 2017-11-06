#!/usr/bin/env ruby

require 'os'
require 'yaml'
require 'optparse'
require 'bagit'
require 'digest'
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
Rejectedlist = Array.new

def assignpaths(inputfile)
	packagename = File.basename(inputfile, '.*')
	packagelocation = File.dirname(inputfile)
	package = "#{packagelocation}/#{packagename}"
	datadir = "#{package}/data"
	logdir = "#{package}/data/logs"
	metadatadir = "#{package}/data/metadata"
	objectsdir = "#{package}/data/objects"
	workingdir = "#{packagelocation}/#{packagename}_working_directory"
	return package, datadir, logdir, metadatadir, objectsdir, workingdir, packagelocation, packagename
end

def validtarget?(inputfile)
	if File.extname(inputfile) != '.wav'
		puts "Input #{inputfile} is not a WAV file. Skipping."
		Rejectedlist << inputfile
	elsif ! File.exist?(inputfile)
		puts "Input #{inputfile} not found. Skipping."
		Rejectedlist << inputfile
	elsif Dir.exist?(assignpaths(inputfile)[0])
		puts "Directory already exists for target package"
		Rejectedlist << inputfile	
	else
		Targetlist << inputfile
	end
end

def createstructure(inputfile)
	buildpackage = assignpaths(inputfile)
	buildpackage[0..5].each do |make|
		Dir.mkdir(make)
	end
	bag = BagIt::Bag.new(buildpackage[0])
end

def makederivatives(inputfile)
	paths = assignpaths(inputfile)
	packagecontents = Array.new
	basename = "#{paths[5]}/#{paths[7]}"
	mp3file = "#{basename}.mp3"
	txtfile = "#{basename}.txt"
	xmlfile = "#{basename}.xml"
	md5file = "#{basename}.md5"
	ffmpegcommand = "ffmpeg -i '#{inputfile}' -codec:a libmp3lame -write_id3v1 1 -id3v2_version 3 -dither_method triangular -af dynaudnorm=g=81 -metadata Normalization='ffmpeg dynaudnorm=g=81' -qscale:a 2 '#{mp3file}'"
	mediainfocommand = "mediainfo '#{inputfile}' > '#{basename}.txt' && mediainfo --output=XML '#{inputfile}' > '#{xmlfile}'"
	packagecontents << "#{inputfile}"
	packagecontents << "#{mp3file}"
	packagecontents << "#{txtfile}"
	packagecontents << "#{xmlfile}"
	system(mediainfocommand)
	system(ffmpegcommand)

	hashmanifest = Array.new
	packagecontents.each do |hashtarget|
		md5 = Digest::MD5.file hashtarget
		hashmanifest << "#{md5},#{File.basename(hashtarget)}"
	end
	open("#{md5file}", 'w') do |f|
		f.puts hashmanifest
	end
end

ARGV.each do|file_input|
	validtarget? file_input
end

Targetlist.each do |aiptarget|
	createstructure aiptarget
	makederivatives aiptarget
end