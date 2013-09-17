#!/usr/bin/env ruby

require 'fileutils'
include FileUtils

version = "2.1.2"
distributions = [
  {:type => :deb, :ver => "10.04", :arch => ["i386", "amd64"], :channel => "lucid"},
  {:type => :deb, :ver => "11.10", :arch => ["i386", "amd64"], :channel => "oneiric"},
  {:type => :deb, :ver => "12.04", :arch => ["i386", "amd64"], :channel => "precise"},
  {:type => :rpm, :ver => "5.5", :arch => ["i386", "x86_64"]},
  {:type => :rpm, :ver => "6.2", :arch => ["i686", "x86_64"]},
  {:type => :win, :ver => "9", :arch => ["x86", "amd64"]},
  {:type => :win, :ver => "10", :arch => ["x86", "amd64"]},
  {:type => :win, :ver => "11", :arch => ["x86", "amd64"]},
]

puts "*** Downloading all the packages"
def get_list(uri, version)
  `s3cmd ls -r #{uri}`.split("\n").grep(/libcouchbase.*#{Regexp.escape(version)}/).map do |line|
    line[%r{(s3://.*)$}, 1].sub(/^s3/, "http")
  end
end

ubuntu_files = get_list("s3://packages.couchbase.com/ubuntu/", version)
rpm_files = get_list("s3://packages.couchbase.com/rpm/", version)

distributions.each do |dist|
  dist[:arch].each do |arch|
    case dist[:type]
      when :deb
        dirname = "libcouchbase-#{version}_ubuntu#{dist[:ver].gsub(".", "")}_#{arch}"
        mkdir_p(dirname)
        cd dirname do
          ubuntu_files.each do |file|
            if file =~ /\/#{dist[:channel]}\/.*#{arch}\.deb$/
              system("wget -c #{file}")
            end
          end
        end
        system("tar cvf #{dirname}.tar #{dirname}")
        rm_rf dirname
      when :rpm
        dirname = "libcouchbase-#{version}_centos#{dist[:ver].gsub(".", "")}_#{arch}"
        mkdir_p(dirname)
        cd dirname do
          rpm_files.each do |file|
            if file =~ /\/#{Regexp.escape(dist[:ver])}\/.*#{arch}\.rpm$/
              system("wget -c #{file}")
            end
          end
        end
        system("tar cvf #{dirname}.tar #{dirname}")
        rm_rf dirname
    when :win
      system("wget -c http://sdkbuilds.couchbase.com/job/libcouchbase-win/ARCH=#{arch},MSVCC_VER=#{dist[:ver]},label=windows/ws/libcouchbase-#{version}_#{arch}_vc#{dist[:ver]}.zip")
    end
  end
end
