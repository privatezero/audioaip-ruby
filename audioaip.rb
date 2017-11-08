#!/usr/bin/env ruby

require 'os'
require 'yaml'
require 'optparse'
require 'bagit'
require 'digest'
require 'fileutils'
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
  opts.on("-d", "--directory", "Directory Mode") do |d|
    options[:directory] = 'directory'
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

# Methods for colored text output
def red(input)
  puts "\e[31m#{input}\e[0m"
end

def green(input)
  puts "\e[36m#{input}\e[0m"
end

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
      errormessage = "Directory already exists for target package #{inputfile}"
    end
    return errormessage
  end

  def createstructure
    green("Creating Package Structure")
    Dir.mkdir(@package)
    Dir.mkdir(@datadir)
    Dir.mkdir(@logdir)
    Dir.mkdir(@metadatadir)
    Dir.mkdir(@objectsdir)
    Dir.mkdir(@workingdir)
    bag = BagIt::Bag.new(@package)
  end

  def makederivatives(inputfile)
    green("Generating Package Contents")
    @packagecontents = Array.new
    @mp3file = "#{@workingdir}/#{@packagename}.mp3"
    @txtfile = "#{@workingdir}/#{@packagename}.txt"
    @xmlfile = "#{@workingdir}/#{@packagename}.xml"
    @md5file = "#{@workingdir}/#{@packagename}.md5"
    ffmpegcommand = "ffmpeg -i '#{inputfile}' -codec:a libmp3lame -write_id3v1 1 -id3v2_version 3 -dither_method triangular -af dynaudnorm=g=81 -metadata Normalization='ffmpeg dynaudnorm=g=81' -qscale:a 2 '#{@mp3file}'"
    mediainfocommand = "mediainfo '#{inputfile}' > '#{@txtfile}' && mediainfo --output=XML '#{inputfile}' > '#{@xmlfile}'"
    @packagecontents << inputfile
    @packagecontents << @mp3file
    @packagecontents << @txtfile
    @packagecontents << @xmlfile
    system(mediainfocommand)
    system(ffmpegcommand)

    hashmanifest = Array.new
    @packagecontents.each do |hashtarget|
      md5 = Digest::MD5.file hashtarget
      hashmanifest << "#{md5},#{File.basename(hashtarget)}"
    end
    open("#{@md5file}", 'w') do |f|
      f.puts hashmanifest
    end
    @packagecontents << @md5file
  end

  def movecontents(inputfile)
    green("Adding Files to Package")
    masterfile = File.basename(inputfile)
    bag = BagIt::Bag.new(@package)
    bag.add_file("objects/#{masterfile}", inputfile)
    bag.add_file("objects/access/#{@packagename}.mp3", @mp3file)
    bag.add_file("logs/filemeta/#{@packagename}.txt", @txtfile)
    bag.add_file("logs/filemeta/#{@packagename}.xml", @xmlfile)
    bag.add_file("metadata/#{@packagename}.md5", @md5file)
    bag.manifest!
  end

  def confirmpackage
    green("Verifying Package Integrity")
    bagmanifest = Array.new
    originmanifest = Array.new
    @packagecontents.each do |original_file|
      md5 = Digest::MD5.file(original_file)
      filename = File.basename(original_file)
      originmanifest << "#{md5} #{filename}"
    end
    baghash = File.readlines("#{@package}/manifest-md5.txt")
    baghash.each do |manifestline|
      manifestbase = File.basename(manifestline.split(" ")[1])
      manifesthash = File.basename(manifestline.split(" ")[0])
      bagmanifest << "#{manifesthash} #{manifestbase}"
    end
    hashcomparison = (originmanifest - bagmanifest)
  end

  def cleanup
    FileUtils.rm_r(@workingdir)
  end

end

ARGV.each do|file_input|
  finalout = Makeaip.new
  exiterror = finalout.validtarget?(file_input)
  if exiterror.nil?
    finalout.assignpaths(file_input)
    finalout.createstructure
    finalout.makederivatives(file_input)
    finalout.movecontents(file_input)
    validation = finalout.confirmpackage
    if validation.empty?
      green("Package Contents Confirmed")
      finalout.cleanup
    else
      red("Warning: Irregulatities found in package for #{file_input}")
      exit
    end
  else
    red(exiterror)
  end
end
