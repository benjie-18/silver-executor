--[[
  RobloxApi — compact API index: services, instance classes with
  props/events/methods, and global docs. Drives member completion,
  the Properties panel, and IntelliSense docs.
]]
local Api = {}

Api.Services = {
  Players = "Players", Workspace = "Workspace", Lighting = "Lighting",
  RunService = "RunService", UserInputService = "UserInputService",
  CoreGui = "CoreGui", CoreScripts = "CoreScripts",
  HttpService = "HttpService", TweenService = "TweenService",
  Debris = "Debris", CollectionService = "CollectionService",
  TeleportService = "TeleportService", MarketService = "MarketService",
  PathfindingService = "PathfindingService", Selection = "Selection",
  StarterGui = "StarterGui", StarterPack = "StarterPack",
  StarterCharacterScripts = "StarterCharacterScripts",
  StarterPlayer = "StarterPlayer", Teams = "Teams",
  VirtualUserInput = "VirtualUserInput", VersionPlaceId = "VersionPlaceId",
  RbxAnalyticsService = "RbxAnalyticsService", LogService = "LogService",
  ServiceProviderService = "ServiceProviderService", TestService = "TestService",
  TextChatService = "TextChatService", TextService = "TextService",
}

local P = function(t) return t end -- props: name -> "Type"
local E = function(t) return t end -- events
local M = function(t) return t end -- methods

Api.Classes = {
  Instance = {
    props = P({ Name = "string", ClassName = "string", Parent = "Instance" }),
    events = E({ ChildAdded = "Child", ChildRemoved = "Child",
      DescendantAdded = "Descendant", DescendantRemoved = "Descendant" }),
    methods = M({ GetChildren = "() -> {Instance}", FindFirstChild = "(name) -> Instance?",
      FindFirstChildOfClass = "(class) -> Instance?", FindFirstChildWhichIsA = "(class) -> Instance?",
      Destroy = "()", Clone = "() -> Instance", WaitForChild = "(name) -> Instance",
      GetAttribute = "(name) -> any", SetAttribute = "(name, value) -> nil",
      IsDescendantOf = "(inst) -> boolean" }),
  },
  BasePart = {
    props = P({ Anchored = "boolean", Size = "Vector3", Position = "Vector3",
      CFrame = "CFrame", Color = "Color3", Transparency = "number",
      CanCollide = "boolean", CanTouch = "boolean", CanQuery = "boolean",
      Massless = "boolean", BricksColor = "BrickColor", Material = "Material" }),
    events = E({ Touched = "part", TouchEnded = "part", CanTouch = "bool",
      MouseEnter = "", MouseLeave = "", MouseClick = "", Breaking = "what" }),
    methods = M({ GetPartsBetween = "(part) -> {BasePart}",
      GetTouchingParts = "() -> {BasePart}", GetTouchedParts = "() -> {BasePart}",
      WorldToPart = "(world) -> part", PartToWorld = "(part) -> world" }),
  },
  Part = { props = P({ Shape = "PartShape" }) },
  MeshPart = { props = P({ MeshId = "string" }) },
  Model = {
    props = P({ PrimaryPart = "BasePart" }),
    events = E({ ChildrenChanged = "" }),
    methods = M({ GetPrimaryPartCFrame = "() -> CFrame" }),
  },
  Folder = { props = P({}) },
  Script = {
    props = P({ Disabled = "boolean", Source = "string" }),
    methods = M({ GetTopology = "() -> {string}" }),
  },
  LocalScript = { props = P({}) },
  ModuleScript = { props = P({}) },
  ScreenGui = {
    props = P({ ResetOnCloser = "boolean", DisplayOrder = "number",
      IgnoreGuiInset = "boolean", ZIndexBehavior = "ZIndexBehavior" }),
  },
  BillboardGui = {
    props = P({ Size = "UDim2", StudsOffset = "Vector2", AlwaysOnTop = "boolean" }),
  },
  SurfaceGui = { props = P({ Size = "UDim2" }) },
  Frame = {
    props = P({ BackgroundColor3 = "Color3", BackgroundTransparency = "number",
      BorderSizePixel = "number", Size = "UDim2", Position = "UDim2",
      Active = "boolean", Draggable = "boolean" }),
    events = E({ MouseEnter = "", MouseLeave = "", MouseButton1Down = "",
      MouseButton1Up = "", MouseButton2Down = "", MouseClick = "",
      MouseLeave = "", GUIObjectAdded = "", GUIObjectRemoved = "" }),
  },
  TextLabel = {
    props = P({ Text = "string", TextColor3 = "Color3", TextSize = "number",
      TextScaled = "boolean", Font = "Font", RichText = "boolean",
      TextWrapped = "boolean", TextTruncate = "TextTruncate",
      BackgroundColor3 = "Color3", BackgroundTransparency = "number" }),
    events = E({ GetPropertyChangedSignal = "(prop) -> Signal" }),
  },
  TextButton = {
    props = P({ AutoButtonColor = "boolean", Text = "string",
      TextColor3 = "Color3", TextSize = "number", Font = "Font" }),
    events = E({ MouseButton1Click = "", MouseButton1Down = "",
      MouseButton1Up = "", MouseButton2Click = "", Activated = "",
      MouseEnter = "", MouseLeave = "" }),
  },
  UICorner = { props = P({ CornerRadius = "UDim" }) },
  UIGridLayout = { props = P({ CellSize = "Vector2", CellPadding = "Vector2" }) },
  UIListLayout = { props = P({ FillDirection = "FillDirection", Padding = "number" }) },
  UIPadding = { props = P({ PaddingTop = "number", PaddingBottom = "number" }) },
  UISizeConstraint = { props = P({ MinSize = "Vector2", MaxSize = "Vector2" }) },
  UIScale = { props = P({ Scale = "Vector2" }) },
  UIStrokeEffect = { props = P({ Color = "Color3", Thickness = "number" }) },
  SurfaceAppearance = {
    props = P({ Texture = "string" }),
  },
  Camera = {
    props = P({ CFrame = "CFrame", FieldOfView = "number" }),
    events = E({ AncestryChanged = "", Breaking = "", MouseEnter = "",
      MouseLeave = "", Touched = "part", TouchEnded = "part" }),
    methods = M({ GetExtents = "() -> number", WorldToViewportPoint = "(pos) -> Vector3",
      ViewportPointToWorld = "(pt) -> Vector3" }),
  },
  Lighting = {
    props = P({ Ambient = "Color3", OutdoorAmbient = "Color3",
      ClockTime = "number", FogEnd = "number" }),
  },
  Humanoid = {
    props = P({ WalkSpeed = "number", JumpPower = "number",
      Health = "number", MaxHealth = "number", State = "HumanoidStateType" }),
    events = E({ Running = "speed", Died = "", Jumping = "",
      StateChanged = "state" }),
    methods = M({ ChangeState = "(state) -> nil", MoveTo = "(pos) -> nil",
      GetWalkSpeed = "() -> number" }),
  },
  Player = {
    props = P({ Character = "Model", CharacterAppearance = "Model",
      Name = "string", DisplayName = "string" }),
    events = E({ CharacterAdded = "Model", CharacterRemoving = "Model",
      CharacterAutoRotateChanged = "", AncestryChanged = "" }),
    methods = M({ GetMouse = "() -> Mouse" }),
  },
  Players = {
    props = P({ MaximumSimultaneousGuests = "number" }),
    events = E({ PlayerAdded = "Player", PlayerRemoving = "Player",
      PlayerRemoving = "Player" }),
    methods = M({ GetPlayers = "() -> {Player}", GetLocalPlayer = "() -> Player" }),
  },
  Mouse = {
    props = P({ IconSize = "Vector2", TargetFilter = "function" }),
    events = E({ ClickDetect = "pos", Button1Down = "", Button1Up = "",
      Button2Down = "", Button2Up = "", MouseEnter = "", MouseLeave = "",
      MouseMove = "pos" }),
    methods = M({ HitTest = "(from, dist) -> bool, pos, normal",
      Raycast = "(origin, dir, params) -> RaycastResult" }),
  },
  Tool = { props = P({} ) },
  RemoteEvent = {
    events = E({ RemoteEvent = "" }),
    methods = M({ FireServer = "(...)", FireClient = "(...)", FireAllClients = "(...)",
      FireServer = "(...)", OnClientEvent = "(fn)", OnServerEvent = "(fn)" }),
  },
  RemoteFunction = {
    methods = M({ InvokeServer = "(...)", InvokeClient = "(...)",
      InvokeServer = "(...)", OnClientEvent = "(fn)", OnServerEvent = "(fn)" }),
  },
  RemoteProperty = { props = P({}) },
  BindableEvent = {
    methods = M({ Fire = "(...)", Event = "Signal" }),
  },
  BindableFunction = {
    methods = M({ Invoke = "(...)", Event = "Signal" }),
  },
  BindableObject = {},
  NumberValue = { props = P({ Value = "number" }) },
  BoolValue = { props = P({ Value = "boolean" }) },
  StringValue = { props = P({ Value = "string" }) },
  IntValue = { props = P({ Value = "number" }) },
  VectorValue = { props = P({ Value = "Vector3" }) },
  Color3Value = { props = P({ Value = "Color3" }) },
  Workspace = {
    methods = M({ GetPlayerFromCharacter = "(model) -> Player" }),
  },
}

Api.Globals = {
  game = "DataModel — the datamodel root",
  workspace = "Workspace — the workspace instance",
  script = "Script — this script's reference",
  task = "Task — structured concurrency (wait, spawn, delay, cancel, defer)",
  tick = "() -> number — current tick",
  wait = "(n) -> dt — yield n seconds, returns dt",
  spawn = "(fn) -> thread",
  delay = "(n, fn) -> thread",
  print = "(...)",
  warn = "(...)",
  error = "(msg, level)",
  pcall = "(fn, ...) -> ok, ...",
  xpcall = "(fn, errhandler, ...) -> ok, ...",
  ipairs = "(t)",
  pairs = "(t)",
  select = "(...)",
  tostring = "(v)",
  tonumber = "(v, base?)",
  type = "(v) -> string",
  typeof = "(v) -> string",
  setmetatable = "(t, mt)",
  getmetatable = "(t)",
  rawget = "(t, k)",
  rawset = "(t, k, v)",
  rawequal = "(a, b)",
  rawlen = "(v)",
  rawnext = "(t, k)",
  unpack = "(t, i, j)",
  next = "(t, k)",
  assert = "(v, msg?)",
  require = "(path) -> module",
  loadstring = "(src, name, mode, env) -> fn, err",
  setfenv = "(fn, env)",
  getfenv = "(n?) -> env",
  shared = "table — shared globals table",
  sharedatamodel = "number — datamodel address",
  getrenv = "() -> table",
  getgenv = "() -> table",
  gethui = "() -> Instance",
  readclipboard = "() -> string",
  setclipboard = "(s) -> nil",
  hookfunction = "(fn) -> unwrapped",
  hookmetamethod = "(name, fn) -> old",
  getcallingscript = "() -> Script",
  getgc = "(n) -> {gc}",
  getupvalue = "(fn, i) -> v",
  fromaddress = "(addr, size) -> string",
  toaddress = "(v) -> v, addr",
  getbytecode = "(fn) -> {bytes}",
  writeflag = "(addr, v)",
  writeint = "(addr, v)",
  getint = "(addr, n?)",
  getdword = "(addr)",
  getstring = "(addr, n)",
  getrawstring = "(addr, n)",
  makeobject = "(class) -> Instance",
  string = "string library",
  table = "table library",
  math = "math library",
  bit32 = "bit32 library",
  buffer = "buffer library",
  utf8 = "utf8 library",
  os = "os library",
  Enum = "Enum — all enums",
}

function Api.membersOf(name)
  local cls = Api.Classes[name]
  if cls then
    local out = {}
    for k, v in pairs(cls.props) do
      table.insert(out, { name = k, kind = "prop", doc = v })
    end
    local evs = cls.events or {}
    for k, v in pairs(evs) do
      table.insert(out, { name = k, kind = "event", doc = v })
    end
    local ms = cls.methods or {}
    for k, v in pairs(ms) do
      table.insert(out, { name = k, kind = "method", doc = v })
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
  end
  if Api.Services[name] then
    return { { name = name, kind = "service", doc = "Service" } }
  end
  if Api.Globals[name] then
    return { { name = name, kind = "global", doc = Api.Globals[name] } }
  end
  return nil
end

return Api
