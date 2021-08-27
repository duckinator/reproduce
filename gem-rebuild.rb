#!/usr/bin/env ruby

# Rebuild a gem from source using `rake build`, with SOURCE_DATE_EPOCH
# set to a timestamp derived from the value of the `date` field in the gem
# metadata.

require 'date'
require 'digest'
require 'rubygems/package'

DATE_FORMAT = '%Y-%m-%d %H:%M:%S.%N Z'

def download_gem(gem_name, gem_version)
  filename = "original--#{gem_name}-#{gem_version}.gem"
  # TODO: Make this less kludgey
  `wget -O#{filename} https://rubygems.org/downloads/#{gem_name}-#{gem_version}.gem`
  filename
end

def sha256(file)
  Digest::SHA256.hexdigest(File.read(file))
end

def get_timestamp(file)
  mtime = nil
  Gem::Package::TarReader.new(File.open(file)) { |tar|
    mtime = tar.seek('metadata.gz') { |f| f.header.mtime }
  }

  mtime
end

def rebuild(gem_name, gem_version)
  original_file = download_gem(gem_name, gem_version)
  output_file = "rebuild--#{gem_name}-#{gem_version}.gem"
  command = "gem build -o #{output_file}"

  timestamp = get_timestamp(original_file).to_s
  date = Time.at(timestamp.to_i).strftime('%F %T %Z')
  puts "Timestamp: #{timestamp} (#{date})"
  puts "Command:   #{command}"

  system({"SOURCE_DATE_EPOCH" => timestamp}, command)

  original_hash = sha256(original_file)
  output_hash = sha256(output_file)

  puts "#{original_hash}\t#{original_file}"
  puts "#{output_hash}\t#{output_file}"

  if original_hash == output_hash
    puts "MATCH"
    exit 0
  else
    puts "NO MATCH"
    exit 1
  end
end

if ARGV.length == 2
  rebuild(*ARGV)
else
  puts "Usage: $0 GEM_NAME GEM_VERSION"
  puts
  puts "Rebuild a gem from source, with SOURCE_DATE_EPOCH set to a value"
  puts "derived from ORIGINAL_FILE.gem."
  exit 1
end
