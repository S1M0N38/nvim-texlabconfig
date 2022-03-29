local vim = vim
local json = vim.json
local uv = vim.loop
local create_augroup = vim.api.nvim_create_augroup
local create_autocmd = vim.api.nvim_create_autocmd

local config = require('texlabconfig.config').get()
local utils = require('texlabconfig.utils')

local M = {}

M.fname = config.cache_root .. '/nvim-texlabconfig.json'
M.cache_filetype = config.cache_filetype
M.cache_activate = config.cache_activate

M._servernames = {}

function M:servernames()
    self:read()
    return self._servernames
end

function M:add_servernames()
    local avaiable_servernames = {}
    self:read()
    for _, server in
        ipairs(
            -- unique servernames
            utils.list_unique(
                -- last nvim session is always first
                vim.list_extend({ vim.v.servername }, self._servernames)
            )
        )
    do
        local ok = pcall(function()
            local socket = vim.fn.sockconnect('pipe', server)
            -- from help sockconnect()
            if socket == 0 then
                error('Connection Failture')
            end
            vim.fn.chanclose(socket)
        end)
        if ok then
            avaiable_servernames[#avaiable_servernames + 1] = server
        end
    end
    self._servernames = avaiable_servernames
    self:write()
end

function M:remove_servernames()
    for k, server in pairs(self:servernames()) do
        if server == vim.v.servername then
            table.remove(self._servernames, k)
            self:write()
            return
        end
    end
end

function M:write()
    local encode = json.encode({ servernames = self._servernames })
    local fd = assert(uv.fs_open(self.fname, 'w', utils.modes))
    assert(uv.fs_write(fd, encode))
    assert(uv.fs_close(fd))
end

function M:read()
    if not utils.file_exists(self.fname) then
        self:write()
        return
    end
    local fd = assert(uv.fs_open(self.fname, 'r', utils.modes))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))

    local decode = json.decode(data)
    self._servernames = decode.servernames
end

function M:autocmd_servernames()
    if not self.cache_activate then
        return
    end

    create_augroup('TeXLabCacheInit', { clear = true })
    create_autocmd({ 'FileType' }, {
        pattern = M.cache_filetypes,
        callback = function()
            self:add_servernames()
        end,
        group = 'TeXLabCacheInit',
    })

    create_autocmd({ 'VimLeavePre' }, {
        callback = function()
            self:remove_servernames()
        end,
        group = 'TeXLabCacheInit',
    })
end

return M
