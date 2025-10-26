#!/usr/bin/env ruby

ab_file = ARGV.shift
sp_file = ARGV.shift

spp = []
File.open(sp_file, "r") do |fh|
  fh.each_line do |ln|
    spp << ln.chomp.split(",")
  end
end
classif = {}
spp.each_with_index do |v, k|
  v.each do |i|
    classif[i] = k
  end
end

ds = {}
ab = []
File.open(ab_file, "r") do |fh|
  fh.each_line do |ln|
    r = ln.chomp.split("\t")
    if fh.lineno == 1
      ds = r[1 .. -1]
    else
      sp = classif[ r.shift ]
      ab[sp] ||= Array.new(ds.size, 0)
      r.each_with_index{ |v, k| ab[sp][k] += v.to_f }
    end
  end
end

puts (["Clade"] + ds).join("\t")
ab.each_with_index do |v, k|
  next if v.nil?
  puts (["ANIsp_#{"%03d" % k}"] + v).join("\t")
end
