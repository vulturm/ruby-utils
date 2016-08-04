#!/bin/env ruby
# Copyright (C) 2016
#
# Author: 'Mihai Vultur <xanto@egaming.ro>'
#
# All rights reserved
#

require 'json'
#
source_path = ARGV[0] 

if ARGV.empty?
  puts "Syntax: #{$0} /path/to/directory/containing/changelog/files/"
  exit
end

unless File.directory?(source_path)
  raise "#{source_path} is not a valid directory containing changelog files"
end
all_templates = Dir["#{source_path}/*"]

#-- our changelog categories with
#-- corresponding regexes witch match those categories
sql_types = {
  'intermediate_changelogs' => '^iam.changelog.*',
  'master_changelogs' => '^master-db-changelog.*',
  'seed_data' => '^initData.*',
  'large_entities' => '^iam_large_entity.*'
}

#-- create multidimensional array for each category
#-- to store it's logfiles
category = {}
sql_types.each do |category_name, _xml_name|
  category[category_name] = []
end

#-- we itterate over the files and add them
#-- to the specific category matched by each regex
all_templates.each do |template_name|
  xml_basename = File.basename(template_name, '.erb')
  sql_types.each do |category_name, xml_name|
    if xml_basename =~ /#{xml_name}/
      (category[category_name] ||= []) << xml_basename
    end
  end
end

sql_types.each do |category_name, xml_name|
  category[category_name].sort_by! { |e| e.sub(/#{xml_name}/, '').to_i }.reverse
end

changelogs_section = {
  'cookbook_name' => 'rf_iam_database',
  'template_folder' => 'changelogs'
}

liquibase_section = {
  'rf_infra_liquibase' => {
    'migrate' => {
      'schema_version' =>
        category['master_changelogs'].map { |e| e[/\d+/].to_i }.max.to_s,
      'change_log_file' => 'master-db-changelog.xml'
    },
    'changelogs' => changelogs_section.merge!(category)
  }
}
#-- print our json that will be used as a list of
#-- attributes in chef environment
#-- use the output without first and last braces { }
puts liquibase_section.to_json
