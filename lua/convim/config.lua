local M = {}

M.base_url  = nil
M.token     = nil
M.email     = nil   -- required when auth = 'basic' (Confluence Cloud)
M.auth      = nil   -- 'bearer' (Data Center PAT) | 'basic' (Cloud email+API token)
M.space_key = nil

--- Validate that the required configuration is present.
--- Returns an error string if invalid, or nil if OK.
M.validate = function()
  if not M.base_url or M.base_url == '' then
    return 'convim: base_url is not configured. Call require("convim").setup({base_url = ...})'
  end
  if not M.token or M.token == '' then
    return 'convim: token is not configured. Call require("convim").setup({token = ...})'
  end
  if M.auth == 'basic' and (not M.email or M.email == '') then
    return 'convim: auth="basic" requires an email. Call setup({email = ...})'
  end
  if M.auth and M.auth ~= 'basic' and M.auth ~= 'bearer' then
    return 'convim: auth must be "basic" or "bearer", got ' .. tostring(M.auth)
  end
  return nil
end

--- Auto-detect the auth scheme when the caller didn't set one explicitly.
--- atlassian.net hosts → Cloud → basic; everything else → bearer (DC PAT).
local function detect_auth()
  if M.auth then return M.auth end
  if M.base_url and M.base_url:lower():find('atlassian%.net') then
    return 'basic'
  end
  return 'bearer'
end

--- Return the value for the HTTP Authorization header, or nil + err.
M.auth_header = function()
  local scheme = detect_auth()
  if scheme == 'basic' then
    if not M.email or M.email == '' then
      return nil, 'convim: basic auth requires an email'
    end
    local raw = M.email .. ':' .. (M.token or '')
    local ok, b64 = pcall(vim.base64.encode, raw)
    if not ok then
      -- Fallback for older Neovim without vim.base64
      b64 = vim.fn.system({ 'base64', '-w0' }, raw):gsub('%s+$', '')
    end
    return 'Basic ' .. b64
  end
  return 'Bearer ' .. (M.token or '')
end

--- Read a non-empty environment variable, or nil.
local function env(name)
  local v = os.getenv(name)
  if v == nil or v == '' then return nil end
  return v
end

--- Explicit setup() options win; otherwise fall back to the CONFLUENCE_*
--- environment variables so credentials never need to live in the nvim config.
M.setup = function(opts)
  opts = opts or {}
  local function pick(key, var)
    if opts[key] ~= nil then return opts[key] end
    return env(var)
  end
  local base_url  = pick('base_url',  'CONFLUENCE_URL')
  local token     = pick('token',     'CONFLUENCE_TOKEN')
  local email     = pick('email',     'CONFLUENCE_EMAIL')
  local space_key = pick('space_key', 'CONFLUENCE_SPACE')
  if base_url  ~= nil then M.base_url  = base_url  end
  if token     ~= nil then M.token     = token     end
  if email     ~= nil then M.email     = email     end
  if opts.auth ~= nil then M.auth      = opts.auth end
  if space_key ~= nil then M.space_key = space_key end
end

return M
