Populate clockify for CURRENT month, up to current day. Workdays only! Personal use only.

Usage: ruby script_name.rb <api_key> [workspace_id] [project_id] [task_id]
  - If only <api_key> is provided: Lists available workspaces.
  - If <api_key> and <workspace_id> are provided: Lists projects in that workspace.
  - If <api_key>, <workspace_id>, and <project_id> are provided: Lists tasks for that project.
  - If <api_key>, <workspace_id>, <project_id>, and <task_id> are provided: Creates time entries for the current month.
