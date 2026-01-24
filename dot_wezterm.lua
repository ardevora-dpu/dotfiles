local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Dynamic home path - works on any Windows machine
local home = os.getenv("USERPROFILE"):gsub("\\", "/")

-- Read project root from ~/.quinlan_root (created by /update)
-- Falls back to home if file doesn't exist (first run)
local function read_quinlan_root()
  local f = io.open(home .. '/.quinlan_root', 'r')
  if f then
    local path = f:read('*l')
    f:close()
    if path and path ~= '' then
      return path:gsub('\\', '/'):gsub('%s+$', '')
    end
  end
  return home
end
config.default_cwd = read_quinlan_root()

-- Clipboard image helper (compile once: see setup/dotfiles/scripts/clip2png.cs)
local clip2png = home .. '/.local/bin/clip2png.exe'

config.set_environment_variables = {
  MSYSTEM = 'MINGW64',
  MSYS = 'winsymlinks:nativestrict',
  MSYS2_PATH_TYPE = 'inherit',
  CHERE_INVOKING = '1',
}

config.default_prog = { 'C:/Program Files/Git/bin/bash.exe', '--login', '-i' }

-- Enable Kitty keyboard protocol for better key handling
-- Claude Code v2.1.14+ explicitly supports this (fixed Ctrl+Z suspend)
config.enable_kitty_keyboard = true

-- GPU rendering and high refresh rate support
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.max_fps = 240
config.animation_fps = 240

-- Reduce output latency (default 3ms throttle)
config.mux_output_parser_coalesce_delay_ms = 0

-- Larger caches for smoother scrolling through long outputs
config.shape_cache_size = 1024
config.line_state_cache_size = 1024

-- Disable aggressive hyperlink detection (causes random words to turn blue)
config.hyperlink_rules = {
  -- Only match explicit URLs (http/https/file)
  { regex = '\\bhttps?://\\S+', format = '$0' },
  { regex = '\\bfile://\\S+', format = '$0' },
}

-- Appearance
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.color_scheme = 'Gruvbox dark, medium (base16)'
config.font = wezterm.font('JetBrainsMono Nerd Font')
config.font_size = 12
config.line_height = 1.1
config.hide_tab_bar_if_only_one_tab = false  -- Always show tab bar (shows workspace)
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }

-- Show current workspace in right status bar
wezterm.on('update-status', function(window, pane)
  local workspace = window:active_workspace()
  window:set_right_status(wezterm.format({
    { Foreground = { Color = '#7c6f64' } },
    { Text = ' ' .. workspace .. ' ' },
  }))
end)

-- Disable blinking (removes constant redraw loop, improves streaming smoothness)
config.cursor_blink_rate = 0
config.text_blink_rate = 0

-- Scrollback (default 3500 - increase for long Claude outputs)
config.scrollback_lines = 15000

-- Suppress notifications when focused on the source pane (Claude Code uses OSC 777)
config.notification_handling = "SuppressFromFocusedPane"

-- Dim inactive panes (visual feedback for which pane has focus)
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.7,
}

-- Mouse bindings
config.mouse_bindings = {
  -- Right-click to paste
  {
    event = { Down = { streak = 1, button = 'Right' } },
    action = act.PasteFrom('Clipboard'),
    mods = 'NONE',
  },
}

-- Leader key: Ctrl+Space, then press another key within 1 second
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
  -- ===== Leader shortcuts (Ctrl+Space, then key) =====

  -- Tabs
  { key = 'c', mods = 'LEADER', action = act.SpawnTab('CurrentPaneDomain') },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
  { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
  { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
  { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
  { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },
  { key = '6', mods = 'LEADER', action = act.ActivateTab(5) },
  { key = '7', mods = 'LEADER', action = act.ActivateTab(6) },
  { key = '8', mods = 'LEADER', action = act.ActivateTab(7) },
  { key = '9', mods = 'LEADER', action = act.ActivateTab(8) },

  -- Panes: split
  { key = 'v', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 's', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Panes: navigate (arrow keys)
  { key = 'LeftArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Left') },
  { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Right') },
  { key = 'UpArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Up') },
  { key = 'DownArrow', mods = 'LEADER', action = act.ActivatePaneDirection('Down') },

  -- Panes: zoom and close
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { key = 'X', mods = 'LEADER|SHIFT', action = act.CloseCurrentTab { confirm = true } },

  -- Workspaces
  { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { key = 'W', mods = 'LEADER|SHIFT', action = act.PromptInputLine {
    description = 'New workspace name:',
    action = wezterm.action_callback(function(window, pane, line)
      if line then
        window:perform_action(act.SwitchToWorkspace { name = line }, pane)
      end
    end),
  }},

  -- Utility
  { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },

  -- ===== Smart clipboard (always active, no leader) =====

  -- Smart Ctrl+C: copy if text selected, otherwise send interrupt
  {
    key = 'c',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local has_selection = window:get_selection_text_for_pane(pane) ~= ''
      if has_selection then
        window:perform_action(act.CopyTo('Clipboard'), pane)
      else
        window:perform_action(act.SendKey{ key='c', mods='CTRL' }, pane)
      end
    end),
  },
  -- Smart Ctrl+V: if clipboard has image, save to temp and paste path; otherwise normal paste
  {
    key = 'v',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local temp = os.getenv("TEMP"):gsub("\\", "/")
      local timestamp = os.date("%Y%m%d_%H%M%S")
      local outpath = temp .. '/clip_' .. timestamp .. '.png'

      local success, stdout, stderr = wezterm.run_child_process {
        clip2png, outpath
      }

      if success then
        -- Image saved, paste the path
        pane:send_text(outpath)
      else
        -- No image or helper missing, normal paste
        window:perform_action(act.PasteFrom('Clipboard'), pane)
      end
    end),
  },
}

return config
