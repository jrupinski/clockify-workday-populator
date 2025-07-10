require 'date'
require 'time'
require 'json'
require 'net/http'
require 'uri'

# --- Configuration (from command line arguments) ---
api_key = ARGV[0]
workspace_id = ARGV[1]
project_id = ARGV[2]
task_id = ARGV[3]

# Polish Timezone Offset (CEST = UTC+2 in summer, CET = UTC+1 in winter)
POLISH_TIMEZONE_OFFSET = "+02:00"

# --- Helper to check for weekends ---
def on_weekend?(date)
  date.wday == 0 || date.wday == 6 # 0 for Sunday, 6 for Saturday
end

# --- Function to make HTTP requests ---
def make_api_request(method, path, api_key, body = nil)
  uri = URI("https://api.clockify.me/api/v1/#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = case method.upcase
            when 'GET'
              Net::HTTP::Get.new(uri)
            when 'POST'
              req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
              req.body = body.to_json if body
              req
            else
              raise ArgumentError, "Unsupported HTTP method: #{method}"
            end

  request['X-Api-Key'] = api_key
  http.request(request)
end

# --- Main Logic ---

unless api_key
  puts "Usage: ruby script_name.rb <api_key> [workspace_id] [project_id] [task_id]"
  puts "  - If only <api_key> is provided: Lists available workspaces."
  puts "  - If <api_key> and <workspace_id> are provided: Lists projects in that workspace."
  puts "  - If <api_key>, <workspace_id>, and <project_id> are provided: Lists tasks for that project."
  puts "  - If <api_key>, <workspace_id>, <project_id>, and <task_id> are provided: Creates time entries for the current month."
  exit 1
end

# The order of these if/elsif blocks matters, from most specific to least specific.

if workspace_id && project_id && task_id
  # --- Create Time Entries Mode ---
  puts "Creating time entries for current month..."

  today = Date.today
  first_day = Date.new(today.year, today.month, 1)
  # last_day = Date.new(today.year, today.month, -1)

  (first_day..today).each do |date|
    if on_weekend?(date)
      puts "Skipping #{date.strftime('%Y-%m-%d')} (weekend)"
      next
    end

    # 8 AM to 4 PM in Polish timezone
    start_time = Time.new(date.year, date.month, date.day, 8, 0, 0, POLISH_TIMEZONE_OFFSET).iso8601
    end_time = Time.new(date.year, date.month, date.day, 16, 0, 0, POLISH_TIMEZONE_OFFSET).iso8601

    payload = {
      "billable": true,
      "projectId": project_id,
      "start": start_time,
      "end": end_time,
      "taskId": task_id,
      "type": "REGULAR",
    }

    print "Processing #{date.strftime('%Y-%m-%d')}... "
    response = make_api_request('POST', "workspaces/#{workspace_id}/time-entries", api_key, payload)

    if response.is_a?(Net::HTTPSuccess)
      puts "SUCCESS"
    else
      puts "ERROR (#{response.code}): #{response.body}"
    end
    sleep(0.02) # Small delay to avoid hitting rate limits (50 requests/second)
  end
  puts "Time entry creation finished."

elsif workspace_id && project_id # This condition is now for LISTING TASKS (3 arguments provided)
  # --- List Tasks Mode ---
  puts "Listing tasks for project: #{project_id} in workspace: #{workspace_id}..."
  response = make_api_request('GET', "workspaces/#{workspace_id}/projects/#{project_id}/tasks", api_key)

  if response.is_a?(Net::HTTPSuccess)
    tasks = JSON.parse(response.body)
    if tasks.empty?
      puts "No tasks found for project ID '#{project_id}' in workspace ID '#{workspace_id}'."
    else
      puts "Tasks for project '#{project_id}' (in workspace '#{workspace_id}'):"
      tasks.each { |t| puts "  Name: #{t['name']} (ID: #{t['id']}), Status: #{t['status']}" }
    end
  else
    puts "Error fetching tasks for project '#{project_id}' (#{response.code}): #{response.body}"
  end

elsif workspace_id # This condition is now for LISTING PROJECTS (2 arguments provided)
  # --- List Projects Mode ---
  puts "Listing projects in workspace: #{workspace_id}..."
  response = make_api_request('GET', "workspaces/#{workspace_id}/projects", api_key)

  if response.is_a?(Net::HTTPSuccess)
    projects = JSON.parse(response.body)
    if projects.empty?
      puts "No projects found in workspace ID '#{workspace_id}'."
    else
      puts "Projects in workspace '#{workspace_id}':"
      projects.each { |p| puts "  Name: #{p['name']} (ID: #{p['id']}), Client: #{p['clientId'] ? p['clientName'] : 'None'}" }
    end
  else
    puts "Error fetching projects for workspace '#{workspace_id}' (#{response.code}): #{response.body}"
  end

else # Only api_key provided (1 argument)
  # --- List Workspaces Mode ---
  puts "Listing available workspaces..."
  response = make_api_request('GET', "workspaces", api_key)

  if response.is_a?(Net::HTTPSuccess)
    workspaces = JSON.parse(response.body)
    if workspaces.empty?
      puts "No workspaces found."
    else
      workspaces.each { |ws| puts "  Name: #{ws['name']} (ID: #{ws['id']})" }
    end
  else
    puts "Error fetching workspaces (#{response.code}): #{response.body}"
  end
end
