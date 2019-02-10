# Description:
#   Watches the state of iTunes Connect app versions.

# Import the Slack Developer Kit
{WebClient} = require "@slack/client"

exec = require('child_process').exec
fs = require 'fs'

# Configuration
refresh_interval = 60 * 1000

itunes_connect_username = process.env.HUBOT_ITUNES_CONNECT_USERNAME.trim()
bundle_id = process.env.HUBOT_BUNDLE_ID.trim()
room_name = process.env.HUBOT_ROOM_NAME.trim()

app_version_file = "./app-version.json"

# Path to the Ruby script that updates the JSON file.
ruby_script_file = "update_app_version_json.rb"

module.exports = (robot) ->
  web = new WebClient robot.adapter.options.token

  last_message_sent_key = 'last_update_message'

  update_app_version_status = () ->
    robot.logger.info "Checking for latest version..."

    run_script_command = "ruby #{ruby_script_file} \
      -u #{itunes_connect_username} \
      -b #{bundle_id} \
      -d #{app_version_file}"

    exec run_script_command, (error, stdout, stderr) ->
      if error
        robot.logger.error "Error updating the app status:", error
      else if stderr
        robot.logger.error "The Ruby script resulted in an error:", stderr
      else
        update_bot_with_app_version_from_file()

  get_json_from_version_file = () ->
    return JSON.parse(fs.readFileSync(app_version_file, 'utf8'));

  update_bot_with_app_version_from_file = () ->
    version = get_json_from_version_file()

    if typeof version.app_status is 'undefined'
      robot.logger.debug "Won't update the bot, since the app status cannot be determined."
      return

    last_message = robot.brain.get last_message_sent_key
    new_message = get_message_for_version version

    if new_message is last_message
      # There is no news to tell; don't send a message.
      robot.logger.info "Nothing new - no need to send a message."
    else
      send_message_to_rooms new_message


  get_message_for_version = (version) ->
    if version.is_live
      phased_release = version.phased_release

      is_phased_release_active = phased_release["state"]["value"] == "ACTIVE"
      current_day_number = phased_release["currentDayNumber"]

      if is_phased_release_active && current_day_number <= 7
        day_percentage_map = phased_release["dayPercentageMap"]
        current_percentage = day_percentage_map["#{current_day_number}"]

        return "🍎 *#{version.version}* is scaling at #{current_percentage}%."
      else

    return "🍎 *#{version.version}* is #{version.status}."

  send_message_to_rooms = (message) ->
    robot.logger.info "Posting new message: '#{message}'"

    web.channels.list()
      .then (api_response) ->
        room_to_post_to = api_response.channels.find (channel) -> channel.name is room_name

        if !room_to_post_to
          robot.logger.error "Unable to find room '#{room_name}'"
          return
        else if !room_to_post_to.is_member
          robot.logger.error "The bot is not a member of '#{room_name}'. Please invite it."
          return

        robot.messageRoom room_to_post_to.id, message

        # Remember the last sent message.
        robot.brain.set last_message_sent_key, message
      .catch (error) -> robot.logger.error error.message

  # Initial check
  update_app_version_status()

  # Schedule regular updates.
  setInterval update_app_version_status, refresh_interval
