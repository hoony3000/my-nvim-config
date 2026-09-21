local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

----------------------------------------------------------------------
-- VS Code style variables
--
-- ${file}                    Current file absolute path
-- ${fileDirname}             Current file directory
-- ${fileBasename}            Current file name
-- ${fileBasenameNoExtension} Current file name without extension
-- ${fileExtname}             Current file extension
-- ${workspaceFolder}         Neovim working directory
----------------------------------------------------------------------

local function get_variables()
  return {
    ["${file}"] = vim.fn.expand("%:p"),
    ["${fileDirname}"] = vim.fn.expand("%:p:h"),
    ["${fileBasename}"] = vim.fn.expand("%:t"),
    ["${fileBasenameNoExtension}"] = vim.fn.expand("%:t:r"),
    ["${fileExtname}"] = vim.fn.expand("%:e"),
    ["${workspaceFolder}"] = vim.fn.getcwd(),
  }
end

----------------------------------------------------------------------
-- Expand variables
----------------------------------------------------------------------

local function expand_vars(str, shell_escape)
  if not str then
    return nil
  end

  local vars = get_variables()

  for key, value in pairs(vars) do
    if shell_escape then
      value = vim.fn.shellescape(value)
    end

    str = str:gsub(vim.pesc(key), value)
  end

  return str
end

----------------------------------------------------------------------
-- Task definitions
--
-- Add your own tasks here.
----------------------------------------------------------------------

local tasks = {
  {
    name = "Build Project",
    cmd = "make",
    cwd = "${workspaceFolder}",
  },

  {
    name = "Clean Project",
    cmd = "make clean",
    cwd = "${workspaceFolder}",
  },

  {
    name = "Rebuild Project",
    cmd = "make clean && make",
    cwd = "${workspaceFolder}",
  },

  {
    name = "Compile Current C File",
    cmd = "gcc ${fileBasename} -o ${fileBasenameNoExtension}",
    cwd = "${fileDirname}",
  },

  {
    name = "Run Current File",
    cmd = "./${fileBasenameNoExtension}",
    cwd = "${fileDirname}",
  },

  {
    name = "Run Test",
    cmd = "./run_test.sh",
    cwd = "${workspaceFolder}",
  },
}

----------------------------------------------------------------------
-- Last executed task
----------------------------------------------------------------------

local last_task = nil

----------------------------------------------------------------------
-- Run task
----------------------------------------------------------------------

local function run_task(task)
  if not task then
    return
  end

  last_task = task

  local cmd = expand_vars(task.cmd, true)
  local cwd = expand_vars(task.cwd or "${workspaceFolder}", false)

  if vim.fn.isdirectory(cwd) == 0 then
    vim.notify(
      "Task cwd does not exist: " .. cwd,
      vim.log.levels.ERROR
    )
    return
  end

  vim.cmd("botright new")
  vim.cmd("resize 15")

  local terminal_buf = vim.api.nvim_get_current_buf()

  vim.fn.termopen(cmd, {
    cwd = cwd,

    on_exit = function(_, exit_code)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(terminal_buf) then
          return
        end

        if exit_code == 0 then
          vim.notify(
            "Task finished: " .. task.name,
            vim.log.levels.INFO
          )
        else
          vim.notify(
            "Task failed: "
              .. task.name
              .. " (exit "
              .. exit_code
              .. ")",
            vim.log.levels.ERROR
          )
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

----------------------------------------------------------------------
-- Telescope task picker
----------------------------------------------------------------------

local function select_task()
  pickers.new({}, {
    prompt_title = "Tasks",

    finder = finders.new_table({
      results = tasks,

      entry_maker = function(task)
        return {
          value = task,
          display = task.name,
          ordinal = task.name,
        }
      end,
    }),

    sorter = conf.generic_sorter({}),

    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()

        actions.close(prompt_bufnr)

        if selection then
          run_task(selection.value)
        end
      end)

      return true
    end,
  }):find()
end

----------------------------------------------------------------------
-- Re-run last task
----------------------------------------------------------------------

local function run_last_task()
  if not last_task then
    vim.notify(
      "No task has been executed yet",
      vim.log.levels.WARN
    )
    return
  end

  run_task(last_task)
end

----------------------------------------------------------------------
-- Run task by name
----------------------------------------------------------------------

local function run_task_by_name(name)
  for _, task in ipairs(tasks) do
    if task.name == name then
      run_task(task)
      return
    end
  end

  vim.notify(
    "Task not found: " .. name,
    vim.log.levels.ERROR
  )
end

----------------------------------------------------------------------
-- Keymaps
----------------------------------------------------------------------

vim.keymap.set("n", "<leader>tt", select_task, {
  desc = "Select Task",
})

vim.keymap.set("n", "<leader>tr", run_last_task, {
  desc = "Run Last Task",
})

vim.keymap.set("n", "<leader>tb", function()
  run_task_by_name("Build Project")
end, {
  desc = "Build Project",
})

----------------------------------------------------------------------
-- Optional commands
----------------------------------------------------------------------

vim.api.nvim_create_user_command("Tasks", function()
  select_task()
end, {})

vim.api.nvim_create_user_command("TaskLast", function()
  run_last_task()
end, {})

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

M.tasks = tasks
M.run = run_task
M.select = select_task
M.run_last = run_last_task

return M
