function dodir(dir)
  local popen = io.popen
  local pfile = popen('ls -a "'..dir..'"/*.conf.lua 2>/dev/null')
  for f in pfile:lines() do
    dofile(f)
  end
  pfile:close()
end
