# Updates the app-version.json with the latest information available.

# Parsing the options
require 'optparse'

# Interacting with iTunes Connect
require "spaceship"
require "json"

# Parse options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_app_version.rb [options]"

  opts.on('-u', '--username ITUNES_CONNECT_USERNAME', 'Username of the iTunes Connect user that manages the app') { |v| options[:itunes_connect_username] = v }
  opts.on('-b', '--bundle_id BUNDLE_ID', 'Bundle ID of the application to query') { |v| options[:bundle_id] = v }
  opts.on('-d', '--destination PATH', 'Path of the JSON file to write the app status to') { |v| options[:destination_file] = v }
end.parse!
raise OptionParser::MissingArgument.exception("--username ITUNES_CONNECT_USERNAME") if options[:itunes_connect_username].nil?
raise OptionParser::MissingArgument.exception("--bundle_id BUNDLE_ID") if options[:bundle_id].nil?
raise OptionParser::MissingArgument.exception("--destination PATH") if options[:destination_file].nil?

class AppVersionUpdater

  def run(itunes_connect_username, bundle_id, destination_file)
    puts "Updating the app version details for '#{bundle_id}'..."

    Spaceship::Tunes.login(itunes_connect_username)

    application = Spaceship::Tunes::Application.find(bundle_id)
    latest_version = application.latest_version

    hash = {
      "version" => latest_version.version,
      "app_status" => latest_version.app_status,
      "is_live" => latest_version.is_live,
      "phased_release" => latest_version.phased_release
    }

    puts "Writing status to '#{destination_file}'..."

    File.open(destination_file, "w") do |f|
      f.write(hash.to_json)
    end

    puts "Version updated. ✅"
  end

end



AppVersionUpdater.new.run(
  options[:itunes_connect_username],
  options[:bundle_id],
  options[:destination_file]
)
