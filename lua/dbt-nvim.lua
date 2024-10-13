local M = {}

local config = {
	venv_path = ".venv",
	split_direction = "horizontal",
	limit = 100,
	do_create_file = true,
	tmp_file_dir = vim.fn.getcwd() .. "/target/dbt_nvim",
}

function M.setup(user_config)
	config = vim.tbl_deep_extend("force", config, user_config or {})
	config.dbt_cmd = "source " .. config.venv_path .. "/bin/activate && dbt"
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function()
			vim.wo.wrap = false
			vim.wo.linebreak = false
		end,
	})
end

local function get_filename()
	local filepath = vim.fn.expand("%:p")
	return filepath:match("([^/\\]+)%.%w+$")
end

local function clean_for_query(str)
	local escaped_str = str:gsub("'", "''")
	return escaped_str:gsub("\\", "\\\\")
end

local function clean_for_compile(str)
	local escaped_str = str:gsub('"', "'")
	return escaped_str:gsub("%-%-.-\n", "")
end

local function compile_sql(file_sql)
	local cmd = config.dbt_cmd .. ' compile --inline "' .. clean_for_compile(file_sql) .. '"'
	local handle = io.popen(cmd)
	if handle then
		local sql = handle:read("*a")
		local delimiter = "Compiled inline node is:"
		for w in string.gmatch(sql, delimiter .. "(.*)") do
			sql = w
		end
		handle:close()
		return sql
	else
		vim.notify("Error compiling SQL with dbt.", vim.log.levels.ERROR)
		return nil
	end
end

local function run_operation(compiled_sql)
	local cmd = config.dbt_cmd
		.. " run-operation dbt_nvim__run_query --args \"{'sql': '"
		.. clean_for_query(compiled_sql)
		.. "'}\" --quiet"
	local handle = io.popen(cmd)
	if handle then
		local data = handle:read("*a")
		handle:close()
		if data and data ~= "" then
			local success, json = pcall(vim.fn.json_decode, data)
			if success then
				return json
			else
				vim.notify("Failed to decode JSON from dbt operation.", vim.log.levels.ERROR)
			end
		else
			vim.notify("No data returned from dbt operation.", vim.log.levels.WARN)
		end
	else
		vim.notify("Error running dbt operation.", vim.log.levels.ERROR)
	end
	return nil
end

local function get_current_buffer_query_results()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local file_sql = table.concat(lines, "\n")
	local compiled_sql = compile_sql(file_sql)
	if compiled_sql then
		compiled_sql = compiled_sql .. " limit " .. config.limit
		local query_results = run_operation(compiled_sql)
		if query_results then
			return query_results
		else
			vim.notify("Error getting query results.", vim.log.levels.ERROR)
		end
	end
	return nil
end

local function show_table(data, model_name)
	if not data or not data.columns or not data.data then
		vim.notify("Invalid data format received.", vim.log.levels.ERROR)
		return
	end

	local headers = data.columns
	local rows = data.data

	local content = {}

	table.insert(content, "<!-- markdownlint-disable MD034 MD013 -->")
	table.insert(content, "# " .. model_name)
	table.insert(content, "")
	table.insert(content, "| " .. table.concat(headers, " | ") .. " |")
	table.insert(content, "|" .. string.rep("---|", #headers))

	for _, row_values in ipairs(rows) do
		local formatted_row = {}
		for _, value in ipairs(row_values) do
			if type(value) == "string" and (value:sub(1, 1) == "{" or value:sub(1, 1) == "[") then
				local success, decoded_value = pcall(vim.fn.json_decode, value)
				if success then
					value = vim.inspect(decoded_value)
				end
			end
			if type(value) == "string" and value:find("\n") then
				value = value:gsub("\n", " ")
			end
			table.insert(formatted_row, tostring(value))
		end
		table.insert(content, "| " .. table.concat(formatted_row, " | ") .. " |")
	end

	local split_cmd = "split"
	if config.split_direction == "vertical" then
		split_cmd = "vsplit"
	end

	if config.do_create_file then
		local tmp_file = config.tmp_file_dir .. "/" .. model_name .. ".md"
		if vim.fn.isdirectory(config.tmp_file_dir) == 0 then
			vim.fn.mkdir(config.tmp_file_dir, "p")
		end
		local file = io.open(tmp_file, "w")
		if file then
			for _, line in ipairs(content) do
				file:write(line .. "\n")
			end
			file:close()
			vim.cmd(split_cmd .. " " .. tmp_file)
		else
			vim.notify("Failed to create temporary file for output.", vim.log.levels.ERROR)
		end
	else
		vim.cmd(split_cmd)
		vim.cmd("enew")
		vim.bo.filetype = "markdown"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
	end
end

function M.show()
	local filename = get_filename()
	if not filename then
		vim.notify("Unable to determine the current file name.", vim.log.levels.ERROR)
		return
	end

	local results = get_current_buffer_query_results()
	if results then
		show_table(results, filename)
	else
		vim.notify("No results to display.", vim.log.levels.WARN)
	end
end

return M
