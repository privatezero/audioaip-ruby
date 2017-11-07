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

class Makeaip
  def assignpaths(inputfile)
    @datadir = "#{@package}/data"
    @logdir = "#{@package}/data/logs"
    @metadatadir = "#{@package}/data/metadata"
    @objectsdir = "#{@package}/data/objects"
    @workingdir = "#{@packagelocation}/#{@packagename}_working_directory"
    return @package, @datadir, @logdir, @metadatadir, @objectsdir, @workingdir, @packagelocation, @packagename
  end

  def validtarget?(inputfile)
    @packagename = File.basename(inputfile, '.*')
    @packagelocation = File.dirname(inputfile)
    @package = "#{@packagelocation}/#{@packagename}"
    if File.extname(inputfile) != '.wav'
      errormessage = "Input #{inputfile} is not a WAV file. Skipping."
    elsif ! File.exist?(inputfile)
      errormessage = "Input #{inputfile} not found. Skipping."
    elsif Dir.exist?(@package)
      errormessage = "Directory already exists for target package"
    end
    return errormessage
  end

  def createstructure
    Dir.mkdir(@package)
    Dir.mkdir(@datadir)
    Dir.mkdir(@logdir)
    Dir.mkdir(@metadatadir)
    Dir.mkdir(@objectsdir)
    Dir.mkdir(@workingdir)
    bag = BagIt::Bag.new(@package)
  end

  def makederivatives(inputfile)
    packagecontents = Array.new
    basename = "#{@workingdir}/#{@packagename}"
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
end

ARGV.each do|file_input|
  finalout = Makeaip.new
  exiterror = finalout.validtarget?(file_input)
  if exiterror.nil?
    finalout.assignpaths(file_input)
    finalout.createstructure
    finalout.makederivatives file_input
  else
    puts exiterror
  end
end
