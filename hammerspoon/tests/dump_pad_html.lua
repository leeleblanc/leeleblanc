-- Renders the Capture Pad's real HTML to stdout, so the JS harness can
-- drive the ACTUAL page instead of a hand-written copy of it.
--
--     lua5.4 dump_pad_html.lua /path/to/modules > /tmp/pad.html
--
-- STDOUT IS THE HTML AND NOTHING ELSE. The module prints to the
-- Hammerspoon console in several places, and those lines landed at the
-- top of the generated file until print was redirected here — which the
-- JS harness survived (it matches on tags) but which would have quietly
-- corrupted anything that read the file as a document.
local MODDIR = arg[1] or "./modules"
local out = {}
print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  io.stderr:write(table.concat(p, " "), "\n")
end
hs = {
  timer={secondsSinceEpoch=function() return 1 end,doAfter=function() return {stop=function()end} end,
         doEvery=function() return {stop=function()end,start=function(s)return s end} end,
         doAt=function() return {stop=function()end} end,usleep=function()end},
  hotkey={bind=function() return {} end,new=function() return {enable=function()end,disable=function()end} end,
          modal={new=function() local m={} function m:bind()return self end function m:enter()return self end
                 function m:exit()return self end return m end}},
  alert={show=function()end}, fs={attributes=function()end,mkdir=function()end,dir=function() return function() end end},
  json={encode=function() return "{}" end}, pasteboard={getContents=function() return "" end,
        setContents=function() return true end, readImage=function() end},
  image={imageFromPath=function() end}, http={asyncPost=function()end},
  task={new=function() return {start=function()return true end,setInput=function()end,
        closeInput=function()end,terminate=function()end} end},
  screen={mainScreen=function() return {frame=function() return {x=0,y=0,w=1440,h=900} end} end,
          allScreens=function() return {} end,
          watcher={new=function() return {start=function(s)return s end,stop=function(s)return s end} end}},
  drawing={windowLevels={floating=1}}, chooser={new=function() local c={} return c end},
  dialog={textPrompt=function() return "Cancel","" end}, settings={get=function()end,set=function()end},
  mouse={absolutePosition=function() return {x=0,y=0} end},
  eventtap={checkMouseButtons=function() return {} end},
  application={launchOrFocus=function()end}, window={focusedWindow=function()end},
  keycodes={map=setmetatable({},{__index=function() return 1 end})},
  webview = {
    windowMasks={borderless=0,titled=1,closable=2,miniaturizable=4,resizable=8,
                 utility=16,nonactivating=128,texturedBackground=256,
                 HUD=8192,fullSizeContentView=32768},
    usercontent={new=function() local uc={} function uc:setCallback(f) self.cb=f; return self end return uc end},
    new=function(rect,opts,uc)
      local w={ styleMask = 0 }   -- hs.webview hard-codes borderless (0)
      function w:html(h) out[#out+1]=h; return self end
      -- a REAL getter/setter, not a self-returning stub: the pad asks for a
      -- non-activating panel and reads the mask back, so a stub that answers
      -- the getter with itself sends it down the failure path and puts a
      -- console warning where the page should be
      function w:windowStyle(s)
        if s == nil then return self.styleMask end
        self.styleMask = s; return self
      end
      for _,m in ipairs({"windowTitle","allowTextEntry","closeOnEscape","level",
                         "show","bringToFront","delete","frame"}) do w[m]=function(self) return self end end
      return w
    end },
}
_G.diag={say=function()end,warn=function()end,err=function()end,mark=function()end,
         verbose=false,trail={},errors={},marks={}}
_G.safeJson=function() return {} end
_G.service={registry={},provide=function(n,f) _G.service.registry[n]=f end,
  has=function() return true end,call=function() end}
_G.choosers={}
local core={logsDir="/tmp/padjs",homeDir="/tmp/padjs",hostTag="T",asanaEnabled=true,
  asanaToken="TOK",asanaWorkspaceId="W",asanaProjectId="P",
  warnWriteFailed=function()end,csvQuote=function(s)return s end,
  resolveBaseScreen=function() return hs.screen.mainScreen() end,
  hyperAddShortcut=function()end,provide=function(n,f) _G.service.provide(n,f) end,
  call=function()end,diag=_G.diag,safeJson=_G.safeJson,formatDuration=function(s) return tostring(s) end}

local mod = assert(loadfile(MODDIR.."/capture_pad.lua"))()
mod.setup(core)
local pad = mod.pad
-- A representative state: one queued note, one parked note, so every
-- branch of the page is present in what the harness drives.
pad.queue  = { { id="q", text="already filed", createdAt=os.time(), images={}, tries=0 } }
pad.parked = { { id="p", text="failed one", createdAt=os.time(), images={}, tries=3,
                 parkedAt=os.time(), lastError="HTTP 403 — Not Authorized" } }
pad.draft, pad.draftCaret = "", 0
pad.show()
io.write(out[#out] or "")
