require "thor"
require "net/http"
require "json"
require "yaml"
require "fileutils"

module WrapCli
  class CLI < Thor
    CONFIG_PATH = File.expand_path("~/.config/wrap/config.yml")

    desc "configure", "Configure CLI with API token"
    def configure
      print "Enter your API token: "
      token = $stdin.gets.chomp

      print "Enter API base URL [https://wrap.rosscodes.com]: "
      url = $stdin.gets.chomp
      url = "http://localhost:3000" if url.empty?

      save_config("token" => token, "base_url" => url)
      puts "Configuration saved to #{CONFIG_PATH}"
    end

    desc "habits", "List all habits"
    def habits
      response = api_get("/api/v1/habits")

      if response.code == "200"
        habits = JSON.parse(response.body)

        if habits.empty?
          puts "No habits found."
        else
          habits.each do |h|
            status = h["active"] ? "" : " (inactive)"
            puts "#{h['id']}: #{h['name']}#{status}"
          end
        end
      else
        handle_error(response)
      end
    end

    desc "log HABIT_ID START_HOUR END_HOUR", "Create a habit log"
    option :date, type: :string, desc: "Date (YYYY-MM-DD), defaults to today"
    option :notes, type: :string, desc: "Optional notes"
    def log(habit_id, start_hour, end_hour)
      payload = {
        start_hour: start_hour.to_f,
        end_hour: end_hour.to_f,
        logged_on: options[:date] || Date.today.iso8601,
        notes: options[:notes]
      }.compact

      response = api_post("/api/v1/habits/#{habit_id}/logs", payload)

      if response.code == "201"
        result = JSON.parse(response.body)
        puts "Logged #{result['duration_hours']}h of #{result['habit']['name']} on #{result['logged_on']}"
      else
        handle_error(response)
      end
    end

    desc "version", "Show CLI version"
    def version
      puts "wrap-cli 0.1.0"
    end

    private

    def config
      @config ||= YAML.load_file(CONFIG_PATH)
    rescue Errno::ENOENT
      puts "Error: Not configured. Run: bin/wrap configure"
      exit 1
    end

    def api_get(path)
      uri = URI("#{config['base_url']}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{config['token']}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"

      http.request(request)
    end

    def api_post(path, body)
      uri = URI("#{config['base_url']}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{config['token']}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = body.to_json

      http.request(request)
    end

    def save_config(data)
      FileUtils.mkdir_p(File.dirname(CONFIG_PATH))
      File.write(CONFIG_PATH, data.to_yaml)
      File.chmod(0o600, CONFIG_PATH)
    end

    def handle_error(response)
      case response.code
      when "401"
        puts "Error: Unauthorized. Check your API token."
      when "404"
        puts "Error: Not found. The habit may not exist or belong to another user."
      when "422"
        error = JSON.parse(response.body)
        puts "Error: Validation failed"
        if error["errors"]
          error["errors"].each do |field, messages|
            Array(messages).each { |msg| puts "  #{field}: #{msg}" }
          end
        end
      else
        puts "Error: #{response.code} - #{response.message}"
      end
      exit 1
    end
  end
end
