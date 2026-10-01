-- Headless Roblox mock, part 2: Instance tree.
-- Instances live in ONE shared tree. Replication is modelled with ownership + overlays:
--   * an instance created by a client context is owned by it and invisible to the server and to
--     other clients (FindFirstChild / GetChildren / WaitForChild / indexing all filter);
--   * a client writing a property or attribute of an instance it does not own writes a
--     client-local overlay (the server and other clients keep seeing the shared value).
-- Reads of members that are neither a modelled property, a method, an event nor a child raise
-- "X is not a valid member of Y", like Roblox. Writes of unknown properties are accepted but
-- recorded in M.unknownWrites so the report can list them.

local V = M.Vector3.new
local CFrame = M.CFrame
local Color3 = M.Color3
local UDim2 = M.UDim2
local UDim = M.UDim
local Vector2 = M.Vector2
local Enum = M.Enum
local typeof = M.typeof
local Signal = M.Signal
local SignalApi = M.SignalApi
local cur = M.cur

------------------------------------------------------------------------------------------ classes
local Classes = {}
M.Classes = Classes
local KNOWN = {} -- every modelled property name (any class) -> true
M.KNOWN = KNOWN

local function def(name, super, props, extra)
	extra = extra or {}
	local c = {
		name = name,
		super = super and Classes[super],
		props = props or {},
		nilprops = extra.nilprops or {},
		events = extra.events or {},
		methods = {},
		getters = {},
		setters = {},
		abstract = extra.abstract,
		service = extra.service,
	}
	for k in c.props do
		KNOWN[k] = true
	end
	for _, k in c.nilprops do
		KNOWN[k] = true
	end
	local ev = {}
	for _, e in c.events do
		ev[e] = true
	end
	c.eventSet = ev
	Classes[name] = c
	return c
end
M.defClass = def

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

def("Instance", nil, { Archivable = true }, {
	abstract = true,
	events = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "AttributeChanged" },
})
def("Folder", "Instance", {})
def("Configuration", "Instance", {})
def("PVInstance", "Instance", {}, { abstract = true })
def("Model", "PVInstance", { LevelOfDetail = Enum.ModelLevelOfDetail.Automatic, ModelStreamingMode = Enum.ModelStreamingMode.Default }, {
	nilprops = { "PrimaryPart", "WorldPivot" },
})
def("WorldRoot", "Model", {}, { abstract = true })
def("Workspace", "WorldRoot", { Gravity = 196.2, StreamingEnabled = false, DistributedGameTime = 0 }, { nilprops = { "CurrentCamera", "Terrain" }, service = true })
def("Camera", "PVInstance", {
	CFrame = CFrame.new(0, 20, 20),
	Focus = CFrame.identity,
	FieldOfView = 70,
	ViewportSize = Vector2.new(1280, 720),
	CameraType = Enum.CameraType.Custom,
}, { nilprops = { "CameraSubject" } })
local BASEPART_PROPS = {
	Size = V(4, 1, 2),
	CFrame = CFrame.identity,
	Color = C(163, 162, 165),
	Material = Enum.Material.Plastic,
	MaterialVariant = "",
	Transparency = 0,
	Reflectance = 0,
	Anchored = false,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	CastShadow = true,
	Massless = false,
	Locked = false,
	CollisionGroup = "Default",
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	LeftSurface = Enum.SurfaceType.Smooth,
	RightSurface = Enum.SurfaceType.Smooth,
	FrontSurface = Enum.SurfaceType.Smooth,
	BackSurface = Enum.SurfaceType.Smooth,
	AssemblyLinearVelocity = V(0, 0, 0),
	AssemblyAngularVelocity = V(0, 0, 0),
	PivotOffset = CFrame.identity,
	EnableFluidForces = true,
	AudioCanCollide = true,
}
def("BasePart", "PVInstance", BASEPART_PROPS, { abstract = true, events = { "Touched", "TouchEnded" }, nilprops = { "CustomPhysicalProperties", "BrickColor" } })
def("FormFactorPart", "BasePart", {}, { abstract = true })
def("Part", "FormFactorPart", { Shape = Enum.PartType.Block })
def("WedgePart", "FormFactorPart", {})
def("CornerWedgePart", "BasePart", {})
def("TrussPart", "BasePart", {})
def("MeshPart", "BasePart", { MeshId = "", TextureID = "", DoubleSided = false, RenderFidelity = Enum.RenderFidelity.Automatic })
def("UnionOperation", "BasePart", { UsePartColor = false })
def("SpawnLocation", "Part", { Neutral = true, Duration = 0, Enabled = true, AllowTeamChangeOnTouch = false, TeamColor = "Medium stone grey" })
def("Seat", "Part", { Disabled = false })
def("Terrain", "BasePart", { WaterColor = C(12, 84, 92), WaterTransparency = 0.3, WaterWaveSize = 0.15, WaterWaveSpeed = 10, WaterReflectance = 1, Decoration = false })
def("Attachment", "Instance", { Position = V(0, 0, 0), Orientation = V(0, 0, 0), CFrame = CFrame.identity, Axis = V(1, 0, 0), SecondaryAxis = V(0, 1, 0), Visible = false })
def("Beam", "Instance", {
	Enabled = true,
	FaceCamera = false,
	LightEmission = 0,
	LightInfluence = 0,
	Segments = 10,
	Width0 = 1,
	Width1 = 1,
	CurveSize0 = 0,
	CurveSize1 = 0,
	Texture = "",
	TextureLength = 1,
	TextureSpeed = 1,
	TextureMode = Enum.TextureMode.Stretch,
	ZOffset = 0,
	Brightness = 1,
}, { nilprops = { "Attachment0", "Attachment1", "Color", "Transparency" } })
def("ParticleEmitter", "Instance", { Enabled = true, Rate = 5, Texture = "", LightEmission = 0, LightInfluence = 0, SpreadAngle = Vector2.new(0, 0), Drag = 0, Acceleration = V(0, 0, 0), EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.FacingCamera, LockedToPart = false, ZOffset = 0, Brightness = 1, Squash = nil }, {
	nilprops = { "Lifetime", "Speed", "Size", "Color", "Transparency", "Rotation", "RotSpeed", "Shape", "ShapeStyle", "ShapeInOut", "TimeScale", "VelocityInheritance", "Squash", "FlipbookLayout" },
})
def("Sparkles", "Instance", { Enabled = true, SparkleColor = C(144, 25, 255), TimeScale = 1 })
def("Fire", "Instance", { Enabled = true, Heat = 9, Size = 5, Color = C(236, 139, 70), SecondaryColor = C(139, 80, 55) })
def("Smoke", "Instance", { Enabled = true, Opacity = 0.5, RiseVelocity = 1, Size = 1, Color = C(255, 255, 255) })
def("Light", "Instance", { Enabled = true, Brightness = 1, Color = C(255, 255, 255), Shadows = false }, { abstract = true })
def("PointLight", "Light", { Range = 8 })
def("SpotLight", "Light", { Range = 16, Angle = 90, Face = Enum.NormalId.Front })
def("SurfaceLight", "Light", { Range = 16, Angle = 90, Face = Enum.NormalId.Front })
def("DataModelMesh", "Instance", { Scale = V(1, 1, 1), Offset = V(0, 0, 0), VertexColor = V(1, 1, 1) }, { abstract = true })
def("SpecialMesh", "DataModelMesh", { MeshType = Enum.MeshType.Head, MeshId = "", TextureId = "" })
def("BlockMesh", "DataModelMesh", {})
def("Decal", "Instance", { Texture = "", Face = Enum.NormalId.Front, Transparency = 0, Color3 = C(255, 255, 255), ZIndex = 1 })
def("Texture", "Decal", { StudsPerTileU = 2, StudsPerTileV = 2, OffsetStudsU = 0, OffsetStudsV = 0 })
def("Highlight", "Instance", { Enabled = true, FillColor = C(255, 0, 0), FillTransparency = 0.5, OutlineColor = C(255, 255, 255), OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, { nilprops = { "Adornee" } })
def("SelectionBox", "Instance", { Color3 = C(13, 105, 172), LineThickness = 0.15, Transparency = 0, SurfaceTransparency = 1, SurfaceColor3 = C(13, 105, 172), Visible = true }, { nilprops = { "Adornee" } })
def("Weld", "Instance", { C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true }, { nilprops = { "Part0", "Part1" } })
def("WeldConstraint", "Instance", { Enabled = true }, { nilprops = { "Part0", "Part1" } })
def("Motor6D", "Weld", { Transform = CFrame.identity, MaxVelocity = 0.1, CurrentAngle = 0, DesiredAngle = 0 })

-- lighting / post effects / sky
def("Lighting", "Instance", {
	Ambient = C(70, 70, 70),
	OutdoorAmbient = C(128, 128, 128),
	Brightness = 2,
	ClockTime = 14,
	TimeOfDay = "14:00:00",
	GeographicLatitude = 41.73,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	GlobalShadows = true,
	Technology = Enum.Technology.ShadowMap,
	ColorShift_Top = C(0, 0, 0),
	ColorShift_Bottom = C(0, 0, 0),
	ExposureCompensation = 0,
	FogColor = C(192, 192, 192),
	FogEnd = 100000,
	FogStart = 0,
	ShadowSoftness = 0.2,
}, { service = true })
def("PostEffect", "Instance", { Enabled = true }, { abstract = true })
def("ColorCorrectionEffect", "PostEffect", { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = C(255, 255, 255) })
def("BloomEffect", "PostEffect", { Intensity = 1, Size = 24, Threshold = 2 })
def("BlurEffect", "PostEffect", { Size = 24 })
def("SunRaysEffect", "PostEffect", { Intensity = 0.25, Spread = 1 })
def("DepthOfFieldEffect", "PostEffect", { FarIntensity = 0.75, FocusDistance = 0.05, InFocusRadius = 10, NearIntensity = 0.75 })
def("Atmosphere", "Instance", { Density = 0.395, Offset = 0, Color = C(199, 199, 199), Decay = C(106, 112, 125), Glare = 0, Haze = 0 })
def("Clouds", "Instance", { Cover = 0.5, Density = 0.7, Color = C(255, 255, 255), Enabled = true })
def("Sky", "Instance", { SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "", SkyboxRt = "", SkyboxUp = "", SunAngularSize = 21, MoonAngularSize = 11, StarCount = 3000, CelestialBodiesShown = true, SunTextureId = "", MoonTextureId = "" })

-- values
def("ValueBase", "Instance", {}, { abstract = true })
def("NumberValue", "ValueBase", { Value = 0 })
def("IntValue", "ValueBase", { Value = 0 })
def("StringValue", "ValueBase", { Value = "" })
def("BoolValue", "ValueBase", { Value = false })
def("Color3Value", "ValueBase", { Value = C(0, 0, 0) })
def("Vector3Value", "ValueBase", { Value = V(0, 0, 0) })
def("CFrameValue", "ValueBase", { Value = CFrame.identity })
def("ObjectValue", "ValueBase", {}, { nilprops = { "Value" } })

-- scripts
def("LuaSourceContainer", "Instance", {}, { abstract = true })
def("BaseScript", "LuaSourceContainer", { Enabled = true, Disabled = false, RunContext = Enum.RunContext.Legacy }, { abstract = true })
def("Script", "BaseScript", {})
def("LocalScript", "Script", {})
def("ModuleScript", "LuaSourceContainer", {})

-- sound
def("Sound", "Instance", {
	SoundId = "",
	Volume = 0.5,
	Looped = false,
	PlaybackSpeed = 1,
	Playing = false,
	TimePosition = 0,
	TimeLength = 0,
	IsLoaded = true,
	IsPlaying = false,
	RollOffMaxDistance = 10000,
	RollOffMinDistance = 10,
	RollOffMode = Enum.RollOffMode.InverseTapered,
	PlayOnRemove = false,
}, { events = { "Ended", "Played", "Loaded", "Stopped", "Paused", "Resumed", "DidLoop" }, nilprops = { "SoundGroup" } })
def("SoundGroup", "Instance", { Volume = 0.5 })
def("SoundService", "Instance", { AmbientReverb = Enum.ReverbType.NoReverb, DistanceFactor = 3.33, DopplerScale = 1, RolloffScale = 1, RespectFilteringEnabled = true }, { service = true })

-- humanoid / player
def("Humanoid", "Instance", {
	Health = 100,
	MaxHealth = 100,
	WalkSpeed = 16,
	JumpPower = 50,
	JumpHeight = 7.2,
	UseJumpPower = false,
	HipHeight = 2,
	AutoRotate = true,
	Sit = false,
	PlatformStand = false,
	MoveDirection = V(0, 0, 0),
	DisplayName = "",
	DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer,
	HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged,
	NameDisplayDistance = 100,
	RigType = Enum.HumanoidRigType.R15,
	FloorMaterial = Enum.Material.Plastic,
	BreakJointsOnDeath = true,
	RequiresNeck = true,
	EvaluateStateMachine = true,
}, { events = { "Died", "Running", "Jumping", "StateChanged", "HealthChanged", "MoveToFinished", "Seated", "Touched", "FreeFalling" } })
def("Player", "Instance", {
	UserId = 0,
	DisplayName = "",
	AccountAge = 30,
	MembershipType = Enum.MembershipType.None,
	Neutral = true,
	CameraMaxZoomDistance = 128,
	CameraMinZoomDistance = 0.5,
	LocaleId = "en-us",
	CanLoadCharacterAppearance = true,
	AutoJumpEnabled = true,
	HealthDisplayDistance = 100,
	NameDisplayDistance = 100,
	DevEnableMouseLock = true,
}, {
	events = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled", "OnTeleport" },
	nilprops = { "Character", "RespawnLocation", "Team", "ReplicationFocus" },
})
def("PlayerGui", "Instance", { ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor, SelectionImageObject = nil })
def("PlayerScripts", "Instance", {})
def("Backpack", "Instance", {})
def("StarterGear", "Instance", {})

-- remotes / bindables
def("RemoteEvent", "Instance", {}, { events = { "OnServerEvent", "OnClientEvent" } })
def("UnreliableRemoteEvent", "RemoteEvent", {})
def("RemoteFunction", "Instance", {}, { nilprops = { "OnServerInvoke", "OnClientInvoke" } })
def("BindableEvent", "Instance", {}, { events = { "Event" } })
def("BindableFunction", "Instance", {}, { nilprops = { "OnInvoke" } })

-- proximity prompt
def("ProximityPrompt", "Instance", {
	ActionText = "Interact",
	ObjectText = "",
	HoldDuration = 0,
	MaxActivationDistance = 10,
	RequiresLineOfSight = true,
	Enabled = true,
	KeyboardKeyCode = Enum.KeyCode.E,
	GamepadKeyCode = Enum.KeyCode.ButtonX,
	ClickablePrompt = true,
	Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
	Style = Enum.ProximityPromptStyle.Default,
	UIOffset = Vector2.new(0, 0),
	AutoLocalize = true,
}, { events = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded" } })
def("ClickDetector", "Instance", { MaxActivationDistance = 32, CursorIcon = "" }, { events = { "MouseClick", "MouseHoverEnter", "MouseHoverLeave" } })

-- GUI ------------------------------------------------------------------------------------------
def("GuiBase", "Instance", {}, { abstract = true })
def("GuiBase2d", "GuiBase", { AutoLocalize = true, SelectionGroup = false }, { abstract = true, nilprops = { "RootLocalizationTable" } })
def("LayerCollector", "GuiBase2d", { Enabled = true, ResetOnSpawn = true, ZIndexBehavior = Enum.ZIndexBehavior.Global }, { abstract = true })
def("ScreenGui", "LayerCollector", {
	DisplayOrder = 0,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension,
	ClipToDeviceSafeArea = true,
})
def("BillboardGui", "LayerCollector", {
	Size = UDim2.new(),
	StudsOffset = V(0, 0, 0),
	StudsOffsetWorldSpace = V(0, 0, 0),
	ExtentsOffset = V(0, 0, 0),
	ExtentsOffsetWorldSpace = V(0, 0, 0),
	SizeOffset = Vector2.new(0, 0),
	AlwaysOnTop = false,
	LightInfluence = 1,
	Brightness = 1,
	MaxDistance = math.huge,
	ClipsDescendants = false,
	Active = false,
	DistanceLowerLimit = 0,
	DistanceUpperLimit = -1,
	DistanceStep = 0,
}, { nilprops = { "Adornee", "PlayerToHideFrom" } })
def("SurfaceGui", "LayerCollector", {
	Face = Enum.NormalId.Front,
	CanvasSize = Vector2.new(800, 600),
	SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
	PixelsPerStud = 50,
	LightInfluence = 1,
	Brightness = 1,
	AlwaysOnTop = false,
	ZOffset = 0,
	ClipsDescendants = true,
	Active = true,
	MaxDistance = 0,
}, { nilprops = { "Adornee" } })
local GUIOBJ = {
	Size = UDim2.fromOffset(100, 100),
	Position = UDim2.new(),
	AnchorPoint = Vector2.new(0, 0),
	Visible = true,
	BackgroundColor3 = C(163, 162, 165),
	BackgroundTransparency = 0,
	BorderColor3 = C(27, 42, 53),
	BorderSizePixel = 1,
	BorderMode = Enum.BorderMode.Outline,
	ZIndex = 1,
	LayoutOrder = 0,
	Rotation = 0,
	ClipsDescendants = false,
	AutomaticSize = Enum.AutomaticSize.None,
	Active = false,
	Selectable = false,
	SizeConstraint = Enum.SizeConstraint.RelativeXY,
	Interactable = true,
	Transparency = 0,
}
def("GuiObject", "GuiBase2d", GUIOBJ, {
	abstract = true,
	events = { "InputBegan", "InputEnded", "InputChanged", "MouseEnter", "MouseLeave", "MouseMoved", "TouchTap", "TouchLongPress", "SelectionGained", "SelectionLost" },
	nilprops = { "NextSelectionUp", "NextSelectionDown", "NextSelectionLeft", "NextSelectionRight" },
})
def("Frame", "GuiObject", { Style = Enum.FrameStyle.Custom })
def("CanvasGroup", "GuiObject", { GroupTransparency = 0, GroupColor3 = C(255, 255, 255) })
local TEXT = {
	Text = "Label",
	TextColor3 = C(27, 42, 53),
	TextSize = 14,
	Font = Enum.Font.Legacy,
	TextScaled = false,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextTransparency = 0,
	TextStrokeTransparency = 1,
	TextStrokeColor3 = C(0, 0, 0),
	RichText = false,
	LineHeight = 1,
	MaxVisibleGraphemes = -1,
	TextTruncate = Enum.TextTruncate.None,
	TextDirection = Enum.TextDirection.Auto,
}
def("TextLabel", "GuiObject", TEXT, { nilprops = { "FontFace" } })
def("GuiButton", "GuiObject", { AutoButtonColor = true, Modal = false, Selected = false, Style = Enum.ButtonStyle.Custom }, {
	abstract = true,
	events = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down", "MouseButton2Up" },
})
def("TextButton", "GuiButton", TEXT, { nilprops = { "FontFace" } })
local IMAGE = {
	Image = "",
	ImageColor3 = C(255, 255, 255),
	ImageTransparency = 0,
	ImageRectOffset = Vector2.new(0, 0),
	ImageRectSize = Vector2.new(0, 0),
	ScaleType = Enum.ScaleType.Stretch,
	SliceScale = 1,
	ResampleMode = Enum.ResamplerMode.Default,
	TileSize = UDim2.fromScale(1, 1),
}
def("ImageLabel", "GuiObject", IMAGE, { nilprops = { "SliceCenter" } })
def("ImageButton", "GuiButton", IMAGE, { nilprops = { "SliceCenter", "HoverImage", "PressedImage" } })
def("TextBox", "GuiObject", TEXT, { events = { "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard" }, nilprops = { "FontFace", "PlaceholderText", "PlaceholderColor3", "ClearTextOnFocus", "TextEditable", "MultiLine", "CursorPosition", "SelectionStart", "ShowNativeInput" } })
def("ScrollingFrame", "GuiObject", {
	CanvasSize = UDim2.new(0, 0, 2, 0),
	CanvasPosition = Vector2.new(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.None,
	ScrollingDirection = Enum.ScrollingDirection.XY,
	ScrollBarThickness = 12,
	ScrollBarImageColor3 = C(0, 0, 0),
	ScrollBarImageTransparency = 0,
	ScrollingEnabled = true,
	ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	VerticalScrollBarInset = Enum.ScrollBarInset.None,
	HorizontalScrollBarInset = Enum.ScrollBarInset.None,
	VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right,
	TopImage = "",
	MidImage = "",
	BottomImage = "",
})
def("ViewportFrame", "GuiObject", { Ambient = C(200, 200, 200), LightColor = C(140, 140, 140), LightDirection = V(-1, -1, -1), ImageColor3 = C(255, 255, 255), ImageTransparency = 0 }, { nilprops = { "CurrentCamera" } })
def("UIBase", "Instance", {}, { abstract = true })
def("UIComponent", "UIBase", {}, { abstract = true })
def("UICorner", "UIComponent", { CornerRadius = UDim.new(0, 8) })
def("UIStroke", "UIComponent", { Thickness = 1, Color = C(0, 0, 0), Transparency = 0, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Enabled = true })
def("UIGradient", "UIComponent", { Rotation = 0, Offset = Vector2.new(0, 0), Enabled = true }, { nilprops = { "Color", "Transparency" } })
def("UIPadding", "UIComponent", { PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0) })
def("UIScale", "UIComponent", { Scale = 1 })
def("UIConstraint", "UIComponent", {}, { abstract = true })
def("UISizeConstraint", "UIConstraint", { MinSize = Vector2.new(0, 0), MaxSize = Vector2.new(math.huge, math.huge) })
def("UITextSizeConstraint", "UIConstraint", { MaxTextSize = 100, MinTextSize = 1 })
def("UIAspectRatioConstraint", "UIConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width })
def("UIGridStyleLayout", "UIComponent", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.Name,
}, { abstract = true })
def("UIListLayout", "UIGridStyleLayout", { Padding = UDim.new(0, 0), Wraps = false, HorizontalFlex = Enum.UIFlexAlignment.None, VerticalFlex = Enum.UIFlexAlignment.None, ItemLineAlignment = Enum.ItemLineAlignment.Automatic })
def("UIGridLayout", "UIGridStyleLayout", { CellSize = UDim2.fromOffset(100, 100), CellPadding = UDim2.fromOffset(5, 5), FillDirectionMaxCells = 0, StartCorner = Enum.StartCorner.TopLeft })
def("UIFlexItem", "UIComponent", { FlexMode = Enum.UIFlexMode.None, GrowRatio = 0, ShrinkRatio = 0 })
def("UIPageLayout", "UIGridStyleLayout", { Padding = UDim.new(0, 0), Animated = true, Circular = false, EasingStyle = Enum.EasingStyle.Back })

-- services (generic shells; behaviour attached in 30_services)
for _, s in {
	"ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterPlayer",
	"StarterPlayerScripts", "StarterCharacterScripts", "StarterGui", "StarterPack", "Players", "RunService",
	"TweenService", "Debris", "MarketplaceService", "ProximityPromptService", "UserInputService",
	"ContextActionService", "GuiService", "HttpService", "CollectionService", "TextService", "Teams",
	"Chat", "TextChatService", "PolicyService", "LocalizationService", "SocialService", "BadgeService",
	"DataStoreService", "MessagingService", "MemoryStoreService", "PhysicsService", "AnalyticsService",
	"HapticService", "VRService", "GroupService", "AssetService", "ContentProvider", "Stats", "TeleportService",
	"VoiceChatService", "SoundService_", "StarterPlayerScripts_",
} do
	if not Classes[s] then
		def(s, "Instance", {}, { service = true })
	end
end
Classes.StarterPlayer.props.CharacterWalkSpeed = 16
Classes.StarterPlayer.props.CameraMaxZoomDistance = 400
Classes.StarterPlayer.props.CameraMinZoomDistance = 0.5
Classes.StarterPlayer.props.EnableMouseLockOption = true
Classes.StarterGui.props.ResetPlayerGuiOnSpawn = true
Classes.Players.props.CharacterAutoLoads = true
Classes.Players.props.MaxPlayers = 8
Classes.Players.props.RespawnTime = 5
Classes.Players.props.BubbleChat = true
Classes.ProximityPromptService.props.Enabled = true
Classes.ProximityPromptService.props.MaxPromptsVisible = 16
for _, k in { "CharacterWalkSpeed", "CameraMaxZoomDistance", "CameraMinZoomDistance", "EnableMouseLockOption", "ResetPlayerGuiOnSpawn", "CharacterAutoLoads", "MaxPlayers", "RespawnTime", "BubbleChat", "Enabled", "MaxPromptsVisible" } do
	KNOWN[k] = true
end
KNOWN.Name = true
KNOWN.Parent = true
KNOWN.ClassName = true

------------------------------------------------------------------------------------------ helpers
local InstMt = {}
M.InstMt = InstMt
M.TYPE[InstMt] = "Instance"
local isInst = function(v)
	return type(v) == "table" and getmetatable(v) == InstMt
end
M.isInst = isInst

local function classOf(inst)
	return rawget(inst, "_class")
end

local function isA(inst, name)
	local c = classOf(inst)
	while c do
		if c.name == name then
			return true
		end
		c = c.super
	end
	return false
end
M.isA = isA

-- Can context `ctx` see instance `inst`? (client-created instances are local to that client)
local function canSee(ctx, inst)
	local owner = rawget(inst, "_owner")
	return owner == nil or owner == ctx or ctx.kind == "harness"
end
M.canSee = canSee

-- Flattened per-class lookup tables (built lazily after every mock file has defined its
-- classes; derived classes override their bases).
local function flat(c)
	local f = c._flat
	if f then
		return f
	end
	f = { m = {}, g = {}, s = {}, d = {}, known = {}, ev = {} }
	local chain = {}
	local x = c
	while x do
		table.insert(chain, 1, x)
		x = x.super
	end
	for _, k in chain do
		for n, fn in k.methods do
			f.m[n] = fn
		end
		for n, fn in k.getters do
			f.g[n] = fn
		end
		for n, fn in k.setters do
			f.s[n] = fn
		end
		for n, v in k.props do
			f.d[n] = v
			f.known[n] = true
		end
		for _, n in k.nilprops do
			f.d[n] = nil
			f.known[n] = true
		end
		for n in k.eventSet do
			f.ev[n] = true
		end
	end
	c._flat = f
	return f
end
M.flatClass = flat

local function lookupDefault(c, k)
	local f = flat(c)
	return f.d[k], f.known[k] == true
end
local function findMethod(c, k)
	return flat(c).m[k]
end
local function findGetter(c, k)
	return flat(c).g[k]
end
local function findSetter(c, k)
	return flat(c).s[k]
end
local function isEvent(c, k)
	return flat(c).ev[k] == true
end

local function childNamed(inst, name, ctx)
	for _, ch in rawget(inst, "_kids") do
		if rawget(ch, "_p").Name == name and canSee(ctx, ch) then
			return ch
		end
	end
	return nil
end

local function fullName(inst)
	local parts = {}
	local c = inst
	while c and rawget(c, "_class").name ~= "DataModel" do
		table.insert(parts, 1, rawget(c, "_p").Name)
		c = rawget(c, "_parent")
	end
	return table.concat(parts, ".")
end
M.fullName = fullName

------------------------------------------------------------------------------------------ signals
local function getSignal(inst, name)
	local sigs = rawget(inst, "_sigs")
	if not sigs then
		sigs = {}
		rawset(inst, "_sigs", sigs)
	end
	local s = sigs[name]
	if not s then
		s = Signal(name)
		sigs[name] = s
		local hook = M.signalHooks[name]
		if hook then
			hook(inst, s)
		end
	end
	return s
end
M.getSignal = getSignal
M.signalHooks = {}

local function peekSignal(inst, name)
	local sigs = rawget(inst, "_sigs")
	return sigs and sigs[name]
end
M.peekSignal = peekSignal

-- fire an instance event to contexts that can see `subject` (default: the instance itself)
local function fireVisible(inst, name, subject, ...)
	local s = peekSignal(inst, name)
	if not s then
		return
	end
	subject = subject or inst
	SignalApi.FireFor(s, function(ctx)
		return canSee(ctx, subject)
	end, ...)
end
M.fireVisible = fireVisible

local function propChanged(inst, k, onlyCtx)
	local ps = rawget(inst, "_psigs")
	local filter = nil
	if onlyCtx then
		filter = function(ctx)
			return ctx == onlyCtx
		end
	end
	if ps and ps[k] then
		SignalApi.FireFor(ps[k], filter)
	end
	local ch = peekSignal(inst, "Changed")
	if ch then
		if isA(inst, "ValueBase") then
			if k == "Value" then
				SignalApi.FireFor(ch, filter, inst.Value)
			end
		else
			SignalApi.FireFor(ch, filter, k)
		end
	end
end
M.propChanged = propChanged

------------------------------------------------------------------------------------------ GUI dirty tracking
M.guiVersion = 0
local function markGui(inst)
	M.guiVersion += 1
end

------------------------------------------------------------------------------------------ construction
M.stats = { created = 0, destroyed = 0, parts = 0 }
local creatable = {}

local function newInstance(className, owner)
	local c = Classes[className]
	if not c then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 3)
	end
	local inst = setmetatable({
		_class = c,
		_p = { Name = className },
		_kids = {},
		_parent = nil,
		_attrs = {},
		_owner = owner,
	}, InstMt)
	M.stats.created += 1
	if isA(inst, "BasePart") then
		M.stats.parts += 1
	end
	local init = M.initHooks[className]
	if init then
		init(inst)
	end
	return inst
end
M.newInstance = newInstance
M.initHooks = {}

local function ctxOwner()
	local ctx = cur()
	if ctx.kind == "client" then
		return ctx
	end
	return nil
end
M.ctxOwner = ctxOwner

local Instance = {}
function Instance.new(className, parent)
	local c = Classes[className]
	if not c or c.abstract or c.service or className == "DataModel" then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 2)
	end
	local inst = newInstance(className, ctxOwner())
	if parent then
		inst.Parent = parent
	end
	return inst
end
function Instance.fromExisting(i)
	return i:Clone()
end
M.Instance = Instance
M.globals.Instance = Instance

------------------------------------------------------------------------------------------ parenting
local function descendantsRaw(inst, out)
	for _, ch in rawget(inst, "_kids") do
		table.insert(out, ch)
		descendantsRaw(ch, out)
	end
	return out
end
M.descendantsRaw = descendantsRaw

local function isGuiish(inst)
	return isA(inst, "GuiBase2d") or isA(inst, "UIBase")
end

local function setParent(inst, newParent)
	if rawget(inst, "_destroyed") then
		error("The Parent property of " .. rawget(inst, "_p").Name .. " is locked, current parent: NULL, new parent " .. (newParent and rawget(newParent, "_p").Name or "nil"), 3)
	end
	if newParent ~= nil and not isInst(newParent) then
		error("Unable to assign property Parent. Instance expected, got " .. typeof(newParent), 3)
	end
	local old = rawget(inst, "_parent")
	if old == newParent then
		return
	end
	-- cycle check
	local p = newParent
	while p do
		if p == inst then
			error("Attempt to set " .. fullName(inst) .. " as its own ancestor", 3)
		end
		p = rawget(p, "_parent")
	end
	if isGuiish(inst) then
		markGui(inst)
	end
	if old then
		-- DescendantRemoving on old ancestors
		local a = old
		while a do
			if peekSignal(a, "DescendantRemoving") then
				fireVisible(a, "DescendantRemoving", inst, inst)
			end
			a = rawget(a, "_parent")
		end
		local list = rawget(old, "_kids")
		local i = table.find(list, inst)
		if i then
			table.remove(list, i)
		end
	end
	rawset(inst, "_parent", newParent)
	if newParent then
		table.insert(rawget(newParent, "_kids"), inst)
	end
	if old then
		fireVisible(old, "ChildRemoved", inst, inst)
	end
	propChanged(inst, "Parent")
	fireVisible(inst, "AncestryChanged", inst, inst, newParent)
	if newParent then
		fireVisible(newParent, "ChildAdded", inst, inst)
		-- DescendantAdded for inst and its descendants on every ancestor that listens
		local a = newParent
		local all = nil
		while a do
			local s = peekSignal(a, "DescendantAdded")
			if s and #s.conns > 0 then
				all = all or descendantsRaw(inst, { inst })
				for _, d in all do
					fireVisible(a, "DescendantAdded", d, d)
				end
			end
			a = rawget(a, "_parent")
		end
	end
	if M.onReparent then
		M.onReparent(inst, old, newParent)
	end
end
M.setParent = setParent

------------------------------------------------------------------------------------------ __index / __newindex
M.unknownWrites = {}
M.typeErrors = {}

InstMt.__index = function(inst, k)
	local c = rawget(inst, "_class")
	local f = c._flat or flat(c)
	if k == "Parent" then
		local p = rawget(inst, "_parent")
		if p and not canSee(cur(), p) then
			return nil
		end
		return p
	elseif k == "ClassName" then
		return c.name
	end
	local m = f.m[k]
	if m then
		return m
	end
	local g = f.g[k]
	if g then
		return g(inst)
	end
	local ov = rawget(inst, "_ov")
	local ctx
	if ov then
		ctx = cur()
		local mine = ov[ctx]
		if mine and mine[k] ~= nil then
			return mine[k]
		end
	end
	local v = rawget(inst, "_p")[k]
	if v ~= nil then
		return v
	end
	local d = f.d[k]
	if d ~= nil then
		return d
	end
	local known = f.known[k]
	if f.ev[k] then
		return getSignal(inst, k)
	end
	ctx = ctx or cur()
	local ch = childNamed(inst, k, ctx)
	if ch then
		return ch
	end
	if known or KNOWN[k] then
		return nil
	end
	error(tostring(k) .. " is not a valid member of " .. c.name .. " \"" .. fullName(inst) .. "\"", 2)
end

local ENUMISH = {} -- property -> true when default is an EnumItem (numbers/strings accepted)
local function checkType(c, k, v)
	local d, known = lookupDefault(c, k)
	if d == nil or v == nil then
		return true
	end
	local td, tv = typeof(d), typeof(v)
	if td == tv then
		return true
	end
	if td == "EnumItem" and (tv == "number" or tv == "string") then
		return true
	end
	if td == "string" and tv == "number" then
		return true
	end
	if td == "number" and tv == "string" and tonumber(v) then
		return true
	end
	return false, td, tv
end

InstMt.__newindex = function(inst, k, v)
	local c = rawget(inst, "_class")
	if k == "Parent" then
		local ctx = cur()
		if ctx.kind == "client" and rawget(inst, "_owner") ~= ctx then
			-- client moving a replicated instance: allowed in Roblox (local only); recorded
			M.clientReparents = (M.clientReparents or 0) + 1
		end
		setParent(inst, v)
		return
	elseif k == "ClassName" then
		error("ClassName is read-only", 2)
	end
	if findMethod(c, k) or isEvent(c, k) then
		error("Unable to assign property " .. tostring(k) .. ". Property is read only", 2)
	end
	local ok, want, got = checkType(c, k, v)
	if not ok then
		local msg = string.format("Unable to assign property %s. %s expected, got %s", k, want, got)
		table.insert(M.typeErrors, c.name .. "." .. k .. ": " .. msg)
		error(msg, 2)
	end
	local _, known = lookupDefault(c, k)
	if not known and not KNOWN[k] and not findSetter(c, k) then
		M.unknownWrites[c.name .. "." .. tostring(k)] = (M.unknownWrites[c.name .. "." .. tostring(k)] or 0) + 1
		KNOWN[k] = true
	end
	if type(v) == "number" and v ~= v and (k == "Size" or k == "Transparency") then
		-- Roblox accepts NaN but it's always a bug; record it
		table.insert(M.typeErrors, c.name .. "." .. k .. " = NaN")
	end
	local ctx = cur()
	if ctx.kind == "client" and rawget(inst, "_owner") ~= ctx and k ~= "Name" then
		-- client-local overlay on a replicated instance
		local ov = rawget(inst, "_ov")
		if not ov then
			ov = {}
			rawset(inst, "_ov", ov)
		end
		ov[ctx] = ov[ctx] or {}
		local old = ov[ctx][k]
		if old == nil then
			old = rawget(inst, "_p")[k]
		end
		ov[ctx][k] = v
		if old ~= v then
			propChanged(inst, k, ctx)
		end
		return
	end
	local setter = findSetter(c, k)
	if setter then
		setter(inst, v)
		return
	end
	local p = rawget(inst, "_p")
	local old = p[k]
	if old == nil then
		old = lookupDefault(c, k)
	end
	p[k] = v
	if old ~= v then
		if k == "Name" or isGuiish(inst) then
			markGui(inst)
		end
		propChanged(inst, k)
	end
end

InstMt.__tostring = function(inst)
	return rawget(inst, "_p").Name
end

-- raw base-value write (used by setters / harness)
function M.rawSet(inst, k, v, fire)
	local p = rawget(inst, "_p")
	local old = p[k]
	p[k] = v
	if fire ~= false and old ~= v then
		propChanged(inst, k)
	end
end

------------------------------------------------------------------------------------------ Instance methods
local IM = Classes.Instance.methods

function IM.IsA(inst, name)
	return isA(inst, name)
end
function IM.GetFullName(inst)
	return fullName(inst)
end
function IM.GetChildren(inst)
	local ctx = cur()
	local out = {}
	for _, ch in rawget(inst, "_kids") do
		if canSee(ctx, ch) then
			table.insert(out, ch)
		end
	end
	return out
end
function IM.GetDescendants(inst)
	local ctx = cur()
	local out = {}
	local function walk(x)
		for _, ch in rawget(x, "_kids") do
			if canSee(ctx, ch) then
				table.insert(out, ch)
				walk(ch)
			end
		end
	end
	walk(inst)
	return out
end
function IM.FindFirstChild(inst, name, recursive)
	local ctx = cur()
	if not recursive then
		return childNamed(inst, name, ctx)
	end
	for _, d in IM.GetDescendants(inst) do
		if rawget(d, "_p").Name == name then
			return d
		end
	end
	return nil
end
function IM.FindFirstChildOfClass(inst, cl)
	local ctx = cur()
	for _, ch in rawget(inst, "_kids") do
		if rawget(ch, "_class").name == cl and canSee(ctx, ch) then
			return ch
		end
	end
	return nil
end
function IM.FindFirstChildWhichIsA(inst, cl, recursive)
	local list = if recursive then IM.GetDescendants(inst) else IM.GetChildren(inst)
	for _, ch in list do
		if isA(ch, cl) then
			return ch
		end
	end
	return nil
end
function IM.FindFirstDescendant(inst, name)
	return IM.FindFirstChild(inst, name, true)
end
function IM.FindFirstAncestor(inst, name)
	local p = rawget(inst, "_parent")
	while p do
		if rawget(p, "_p").Name == name then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function IM.FindFirstAncestorOfClass(inst, cl)
	local p = rawget(inst, "_parent")
	while p do
		if rawget(p, "_class").name == cl then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function IM.FindFirstAncestorWhichIsA(inst, cl)
	local p = rawget(inst, "_parent")
	while p do
		if isA(p, cl) then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function IM.IsDescendantOf(inst, anc)
	local p = rawget(inst, "_parent")
	while p do
		if p == anc then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
function IM.IsAncestorOf(inst, d)
	return IM.IsDescendantOf(d, inst)
end
function IM.WaitForChild(inst, name, timeout)
	local ctx = cur()
	local found = childNamed(inst, name, ctx)
	if found then
		return found
	end
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		error("WaitForChild(" .. name .. ") on " .. fullName(inst) .. " from the harness main thread: child missing", 2)
	end
	local start = M.clock
	local warned = false
	while true do
		M.schedule(co, M.FRAME, nil)
		coroutine.yield()
		if rawget(inst, "_destroyed") then
			return nil
		end
		found = childNamed(inst, name, ctx)
		if found then
			return found
		end
		if timeout and M.clock - start >= timeout then
			return nil
		end
		if not timeout and not warned and M.clock - start >= 5 then
			warned = true
			M.globals.warn("Infinite yield possible on '" .. fullName(inst) .. ":WaitForChild(\"" .. name .. "\")'")
		end
	end
end
function IM.ClearAllChildren(inst)
	for _, ch in IM.GetChildren(inst) do
		ch:Destroy()
	end
end
function IM.Destroy(inst)
	if rawget(inst, "_destroyed") then
		return
	end
	local ds = peekSignal(inst, "Destroying")
	if ds then
		SignalApi.Fire(ds)
	end
	for _, ch in table.clone(rawget(inst, "_kids")) do
		IM.Destroy(ch)
	end
	if rawget(inst, "_parent") then
		setParent(inst, nil)
	end
	rawset(inst, "_destroyed", true)
	M.stats.destroyed += 1
	-- disconnect everything on the instance
	local sigs = rawget(inst, "_sigs")
	if sigs then
		for _, s in sigs do
			table.clear(s.conns)
		end
	end
	local ps = rawget(inst, "_psigs")
	if ps then
		for _, s in ps do
			table.clear(s.conns)
		end
	end
	if M.onDestroy then
		M.onDestroy(inst)
	end
end
IM.Remove = function(inst)
	setParent(inst, nil)
end

local function cloneValue(v)
	return v
end
function IM.Clone(inst)
	if rawget(inst, "_p").Archivable == false then
		return nil
	end
	local owner = ctxOwner()
	local map = {}
	local function cl(x)
		local c = rawget(x, "_class")
		local n = setmetatable({
			_class = c,
			_p = table.clone(rawget(x, "_p")),
			_kids = {},
			_parent = nil,
			_attrs = table.clone(rawget(x, "_attrs")),
			_owner = owner,
			_src = rawget(x, "_src"),
		}, InstMt)
		map[x] = n
		M.stats.created += 1
		if isA(n, "BasePart") then
			M.stats.parts += 1
		end
		local hook = M.cloneHooks[c.name]
		if hook then
			hook(x, n)
		end
		for _, ch in rawget(x, "_kids") do
			if rawget(ch, "_p").Archivable ~= false then
				local cc = cl(ch)
				rawset(cc, "_parent", n)
				table.insert(rawget(n, "_kids"), cc)
			end
		end
		return n
	end
	local root = cl(inst)
	-- remap instance-valued properties pointing inside the clone
	for old, new in map do
		local p = rawget(new, "_p")
		for k, v in p do
			if isInst(v) and map[v] then
				p[k] = map[v]
			end
		end
	end
	return root
end
M.cloneHooks = {}

local ATTR_OK = {
	string = true, boolean = true, number = true, UDim = true, UDim2 = true, BrickColor = true,
	Color3 = true, Vector2 = true, Vector3 = true, CFrame = true, NumberSequence = true,
	ColorSequence = true, NumberRange = true, Rect = true, Font = true, EnumItem = true,
}
function IM.SetAttribute(inst, k, v)
	if type(k) ~= "string" then
		error("Attribute name must be a string", 2)
	end
	if v ~= nil and not ATTR_OK[typeof(v)] then
		error(typeof(v) .. " is not a supported attribute type", 2)
	end
	local ctx = cur()
	local attrs = rawget(inst, "_attrs")
	if ctx.kind == "client" and rawget(inst, "_owner") ~= ctx then
		local ov = rawget(inst, "_aov")
		if not ov then
			ov = {}
			rawset(inst, "_aov", ov)
		end
		ov[ctx] = ov[ctx] or {}
		ov[ctx][k] = { v = v }
		local as = rawget(inst, "_asigs")
		if as and as[k] then
			SignalApi.FireFor(as[k], function(c)
				return c == ctx
			end)
		end
		return
	end
	local old = attrs[k]
	attrs[k] = v
	if old ~= v then
		local as = rawget(inst, "_asigs")
		if as and as[k] then
			SignalApi.Fire(as[k])
		end
		local s = peekSignal(inst, "AttributeChanged")
		if s then
			SignalApi.Fire(s, k)
		end
	end
end
function IM.GetAttribute(inst, k)
	local ctx = cur()
	if ctx.kind == "client" then
		local ov = rawget(inst, "_aov")
		local mine = ov and ov[ctx]
		if mine and mine[k] then
			return mine[k].v
		end
	end
	return rawget(inst, "_attrs")[k]
end
function IM.GetAttributes(inst)
	local out = table.clone(rawget(inst, "_attrs"))
	local ctx = cur()
	local ov = rawget(inst, "_aov")
	if ctx.kind == "client" and ov and ov[ctx] then
		for k, w in ov[ctx] do
			out[k] = w.v
		end
	end
	return out
end
function IM.GetAttributeChangedSignal(inst, k)
	local as = rawget(inst, "_asigs")
	if not as then
		as = {}
		rawset(inst, "_asigs", as)
	end
	as[k] = as[k] or Signal("AttributeChanged:" .. k)
	return as[k]
end
function IM.GetPropertyChangedSignal(inst, k)
	local c = rawget(inst, "_class")
	local _, known = lookupDefault(c, k)
	if not known and not KNOWN[k] and not findGetter(c, k) then
		error(tostring(k) .. " is not a valid property name.", 2)
	end
	local ps = rawget(inst, "_psigs")
	if not ps then
		ps = {}
		rawset(inst, "_psigs", ps)
	end
	ps[k] = ps[k] or Signal("Changed:" .. k)
	return ps[k]
end
-- tags (CollectionService)
M.tags = {}
function IM.AddTag(inst, tag)
	M.tags[tag] = M.tags[tag] or setmetatable({}, { __mode = "k" })
	M.tags[tag][inst] = true
end
function IM.RemoveTag(inst, tag)
	if M.tags[tag] then
		M.tags[tag][inst] = nil
	end
end
function IM.HasTag(inst, tag)
	return M.tags[tag] ~= nil and M.tags[tag][inst] == true
end
function IM.GetTags(inst)
	local out = {}
	for t, set in M.tags do
		if set[inst] then
			table.insert(out, t)
		end
	end
	return out
end
function IM.GetActor()
	return nil
end
function IM.GetStyled(inst, k)
	return inst[k]
end

------------------------------------------------------------------------------------------ BasePart / Model
local BP = Classes.BasePart
BP.getters.Position = function(p)
	return p.CFrame.Position
end
BP.setters.Position = function(p, v)
	local cf = p.CFrame
	M.rawSet(p, "CFrame", CFrame.new(v) * cf.Rotation)
end
BP.getters.Orientation = function(p)
	local a, b, c = M.toEulerYXZ(p.CFrame.r)
	return V(math.deg(a), math.deg(b), math.deg(c))
end
BP.setters.Orientation = function(p, v)
	M.rawSet(p, "CFrame", CFrame.new(p.CFrame.Position) * CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z)))
end
BP.getters.Rotation = BP.getters.Orientation
BP.getters.AssemblyMass = function(p)
	return p.Size.X * p.Size.Y * p.Size.Z * 0.7
end
BP.getters.Mass = BP.getters.AssemblyMass
BP.getters.AssemblyRootPart = function(p)
	return p
end
BP.getters.ExtentsSize = function(p)
	return p.Size
end
for _, k in { "Position", "Orientation", "Rotation" } do
	KNOWN[k] = true
end
function BP.methods.GetPivot(p)
	return p.CFrame * p.PivotOffset
end
function BP.methods.PivotTo(p, cf)
	p.CFrame = cf * p.PivotOffset:Inverse()
end
function BP.methods.GetMass(p)
	return p.Size.X * p.Size.Y * p.Size.Z * 0.7
end
function BP.methods.GetTouchingParts()
	return {}
end
function BP.methods.ApplyImpulse() end
function BP.methods.SetNetworkOwner() end
function BP.methods.GetNetworkOwner()
	return nil
end
function BP.methods.BreakJoints() end
function BP.methods.GetConnectedParts(p)
	return { p }
end
function BP.methods.GetJoints()
	return {}
end
function BP.methods.CanCollideWith()
	return true
end
local BrickColorMod = M.globals.BrickColor
BP.getters.BrickColor = function(p)
	return BrickColorMod.new("Custom")
end
BP.setters.BrickColor = function(p, v)
	if type(v) == "table" and v.Color then
		p.Color = v.Color
	end
end

local function partsOf(model)
	local out = {}
	for _, d in descendantsRaw(model, {}) do
		if isA(d, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
M.partsOf = partsOf

local function aabb(parts)
	local mn, mx
	for _, p in parts do
		local cf, s = p.CFrame, p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = cf * V(s.X * sx, s.Y * sy, s.Z * sz)
					if not mn then
						mn, mx = w, w
					else
						mn = mn:Min(w)
						mx = mx:Max(w)
					end
				end
			end
		end
	end
	return mn, mx
end
M.aabb = aabb

local MD = Classes.Model
function MD.methods.GetPivot(m)
	local pp = rawget(m, "_p").PrimaryPart
	if pp and rawget(pp, "_parent") ~= nil and pp:IsDescendantOf(m) then
		return pp.CFrame * pp.PivotOffset
	end
	local wp = rawget(m, "_p").WorldPivot
	if wp then
		return wp
	end
	local mn, mx = aabb(partsOf(m))
	if not mn then
		return CFrame.identity
	end
	return CFrame.new((mn + mx) / 2)
end
MD.getters.WorldPivot = function(m)
	return rawget(m, "_p").WorldPivot or MD.methods.GetPivot(m)
end
function MD.methods.PivotTo(m, cf)
	local old = MD.methods.GetPivot(m)
	local delta = cf * old:Inverse()
	for _, p in partsOf(m) do
		M.rawSet(p, "CFrame", delta * p.CFrame)
	end
	local pp = rawget(m, "_p").PrimaryPart
	if not (pp and pp:IsDescendantOf(m)) then
		rawget(m, "_p").WorldPivot = cf
	end
end
function MD.methods.SetPrimaryPartCFrame(m, cf)
	local pp = rawget(m, "_p").PrimaryPart
	assert(pp, "Model:SetPrimaryPartCFrame() failed because no PrimaryPart has been set")
	MD.methods.PivotTo(m, cf * pp.PivotOffset)
end
function MD.methods.GetPrimaryPartCFrame(m)
	local pp = rawget(m, "_p").PrimaryPart
	return pp and pp.CFrame
end
function MD.methods.GetBoundingBox(m)
	local mn, mx = aabb(partsOf(m))
	if not mn then
		return CFrame.identity, V(0, 0, 0)
	end
	return CFrame.new((mn + mx) / 2), mx - mn
end
function MD.methods.GetExtentsSize(m)
	local _, s = MD.methods.GetBoundingBox(m)
	return s
end
function MD.methods.MoveTo(m, pos)
	local pv = MD.methods.GetPivot(m)
	MD.methods.PivotTo(m, pv.Rotation + pos)
end
function MD.methods.TranslateBy(m, d)
	MD.methods.PivotTo(m, MD.methods.GetPivot(m) + d)
end
function MD.methods.ScaleTo() end
function MD.methods.GetScale()
	return 1
end
function MD.methods.BreakJoints() end
function MD.methods.MakeJoints() end

-- Attachment world position
Classes.Attachment.getters.WorldPosition = function(a)
	local p = rawget(a, "_parent")
	local pos = a.Position
	if p and isA(p, "BasePart") then
		return p.CFrame * pos
	end
	return pos
end
Classes.Attachment.getters.WorldCFrame = function(a)
	local p = rawget(a, "_parent")
	local cf = CFrame.new(a.Position)
	if p and isA(p, "BasePart") then
		return p.CFrame * cf
	end
	return cf
end
KNOWN.WorldPosition = true
KNOWN.WorldCFrame = true

-- ParticleEmitter / Sound / misc methods
Classes.ParticleEmitter.methods.Emit = function(pe, n)
	M.stats.particlesEmitted = (M.stats.particlesEmitted or 0) + (n or 16)
end
Classes.ParticleEmitter.methods.Clear = function() end
local SoundM = Classes.Sound.methods
function SoundM.Play(s)
	M.stats.soundsPlayed = (M.stats.soundsPlayed or 0) + 1
	M.rawSet(s, "Playing", true)
	M.rawSet(s, "IsPlaying", true, false)
	local sig = peekSignal(s, "Played")
	if sig then
		SignalApi.Fire(sig, s.SoundId)
	end
end
function SoundM.Stop(s)
	M.rawSet(s, "Playing", false)
	M.rawSet(s, "IsPlaying", false, false)
end
SoundM.Pause = SoundM.Stop
SoundM.Resume = SoundM.Play

-- BindableEvent / BindableFunction
Classes.BindableEvent.methods.Fire = function(b, ...)
	SignalApi.Fire(getSignal(b, "Event"), ...)
end
Classes.BindableFunction.methods.Invoke = function(b, ...)
	local f = rawget(b, "_p").OnInvoke
	assert(f, "BindableFunction has no OnInvoke")
	return f(...)
end

-- TextBox
Classes.TextBox.methods.CaptureFocus = function() end
Classes.TextBox.methods.ReleaseFocus = function(tb, enter)
	SignalApi.Fire(getSignal(tb, "FocusLost"), enter == true)
end
Classes.TextBox.methods.IsFocused = function()
	return false
end
-- text bounds estimate
local function textBounds(t)
	local s = tostring(rawget(t, "_p").Text or "")
	local size = t.TextSize
	return Vector2.new(#s * size * 0.55, size)
end
Classes.TextLabel.getters.TextBounds = textBounds
Classes.TextButton.getters.TextBounds = textBounds
Classes.TextBox.getters.TextBounds = textBounds
Classes.TextLabel.getters.TextFits = function()
	return true
end
Classes.TextButton.getters.TextFits = Classes.TextLabel.getters.TextFits
KNOWN.TextBounds = true
KNOWN.TextFits = true
KNOWN.ContentText = true
Classes.TextLabel.getters.ContentText = function(t)
	return tostring(rawget(t, "_p").Text or "Label")
end
Classes.TextButton.getters.ContentText = Classes.TextLabel.getters.ContentText

-- GUI absolute geometry (computed by the layout engine in 50_harness)
local GB = Classes.GuiBase2d
GB.getters.AbsolutePosition = function(g)
	return M.guiAbs(g).pos
end
GB.getters.AbsoluteSize = function(g)
	return M.guiAbs(g).size
end
GB.getters.AbsoluteRotation = function(g)
	return 0
end
Classes.ScrollingFrame.getters.AbsoluteCanvasSize = function(g)
	return M.guiAbs(g).canvas or M.guiAbs(g).size
end
Classes.ScrollingFrame.getters.AbsoluteWindowSize = function(g)
	return M.guiAbs(g).size
end
Classes.UIGridStyleLayout.getters.AbsoluteContentSize = function(l)
	local p = rawget(l, "_parent")
	if not p then
		return Vector2.new(0, 0)
	end
	return M.guiAbs(p).content or Vector2.new(0, 0)
end
Classes.Camera.methods.WorldToViewportPoint = function(cam, pos)
	return Vector2.new(0, 0), false
end
Classes.Camera.methods.WorldToScreenPoint = Classes.Camera.methods.WorldToViewportPoint
Classes.Camera.methods.ViewportPointToRay = function(cam, x, y)
	return M.globals.Ray.new(cam.CFrame.Position, cam.CFrame.LookVector)
end
Classes.Camera.methods.ScreenPointToRay = Classes.Camera.methods.ViewportPointToRay
for _, k in { "AbsolutePosition", "AbsoluteSize", "AbsoluteRotation", "AbsoluteCanvasSize", "AbsoluteWindowSize", "AbsoluteContentSize" } do
	KNOWN[k] = true
end

-- Humanoid
local HM = Classes.Humanoid.methods
function HM.TakeDamage(h, n)
	h.Health = math.max(0, h.Health - n)
end
function HM.MoveTo(h, pos)
	M.humanoidMoveTo(h, pos)
end
function HM.ChangeState() end
function HM.GetState()
	return Enum.HumanoidStateType.Running
end
function HM.SetStateEnabled() end
function HM.LoadAnimation()
	return { Play = function() end, Stop = function() end, AdjustSpeed = function() end }
end
function HM.GetAppliedDescription()
	return nil
end
function HM.UnequipTools() end
Classes.Humanoid.setters.Health = function(h, v)
	local old = rawget(h, "_p").Health or 100
	M.rawSet(h, "Health", math.clamp(v, 0, h.MaxHealth))
	local s = peekSignal(h, "HealthChanged")
	if s then
		SignalApi.Fire(s, v)
	end
	if old > 0 and v <= 0 then
		SignalApi.Fire(getSignal(h, "Died"))
	end
end
Classes.Humanoid.getters.RootPart = function(h)
	local ch = rawget(h, "_parent")
	return ch and ch:FindFirstChild("HumanoidRootPart")
end
KNOWN.RootPart = true
