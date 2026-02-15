Config = {}

Config.Debug = false -- Set to false for production

-- Job name required to use undertaker features
Config.JobName = 'undertaker'

-- Payment for burying a body
Config.BurialPayment = 25
Config.AnimalBurialPayment = 15
-- How close a dead body needs to be to bury it (in units)
Config.BodySearchRadius = 25.0

-- How long the digging animation takes (in seconds)
Config.DiggingTimer = 10

Config.DirtPile = {
    Enabled = true,
    Model = 'mp005_p_dirtpile_tall_unburied',
    OffsetForward = 0.6,
    OffsetZ = -1.0,
}

Config.GraveMarker = {
    Enabled = true,
    Model = 'mp008_p_mp_gravemarker01x',
    OffsetForward = 1.2,  -- Place it at the head of the grave
    OffsetZ = -1.0,
}

Config.BodyDetection = {
    Enabled = true,                 -- Master toggle for body detection system
    AutoNotify = false,             -- Set to false to disable automatic notifications
    CheckInterval = 10000,          -- How often to check for bodies (ms)
    NotifyRadius = 600.0,           -- How far away to detect bodies
    MinNotifyInterval = 60000,      -- Minimum time between notifications (ms)
}

Config.DeathReport = {
    Enabled = true,                 -- Enable /reportdeath command
    Command = 'death',        -- Command name
    Cooldown = 60000,               -- Cooldown between reports (ms) - 60 seconds
    RewardReporter = true,          -- Give small reward to reporter
    RewardAmount = 1,               -- Amount to give reporter
}

Config.Dig = {
    shovel = "p_shovel02x",
    anim = {"amb_work@world_human_gravedig@working@male_b@idle_a", "idle_a"},
    bone = "skel_r_hand",
    pos = {0.06, -0.06, -0.03, 270.0, 165.0, 151.0},
}

-- Pray animations
Config.PrayAnim = {
    {"amb_misc@world_human_pray_rosary@base", "base"},
    --{"amb_misc@prop_human_seat_pray@male_b@idle_b", "idle_d"},
    --{"script_common@shared_scenarios@stand@random@town_burial@stand_mourn@male@react_look@loop@generic", "front"},
    --{"amb_misc@world_human_grave_mourning@kneel@female_a@idle_a", "idle_a"},
    --{"script_common@shared_scenarios@kneel@mourn@female@a@base", "base"},
    --{"amb_misc@world_human_grave_mourning@female_a@idle_a", "idle_a"},
    --{"amb_misc@world_human_grave_mourning@male_b@idle_c", "idle_g"},
    --{"amb_misc@world_human_grave_mourning@male_b@idle_c", "idle_h"},
}

-- Notification texts
Config.Texts = {
    NotUndertaker = "Only undertakers can do this",
    NoBodyNearby = "No dead body nearby to bury",
    BurialComplete = "Burial complete",
    DiggingGrave = "Digging grave...",
    Praying = "Paying respects...",
    AlreadyDigging = "Already digging...",
	WagonFull = "Wagon is full",
	WagonEmpty = "No bodies in wagon",
	BodyStored = "Body loaded into wagon",
	BodyRetrieved = "Body retrieved from wagon",
	NoWagonNearby = "No wagon nearby",
	BodyDetected = "A body has been reported",
	GPSSet = "GPS route set to body location",
	BodyCollected = "You have arrived at the body location",
	DeathReported = "Death reported to undertaker",
	DeathReportReceived = "A death has been reported",
	NoBodyToReport = "No dead body nearby to report",
	ReportCooldown = "Please wait before reporting another death",
	.ReportReward = "Received $%s for reporting a death",
	AlreadyReported = "This body has already been reported",
}


Config.RandomNames = {
    FirstNames = {
        
        'citizen', 
    },
    LastNames = {
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Wilson',
        'Anderson', 'Taylor', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson',
        'Garcia', 'Martinez', 'Robinson', 'Clark', 'Rodriguez', 'Lewis', 'Lee', 'Walker',
        'Hall', 'Allen', 'Young', 'King', 'Wright', 'Scott', 'Green', 'Baker',
        'Adams', 'Nelson', 'Carter', 'Mitchell', 'Roberts', 'Turner', 'Phillips', 'Campbell',
        'Parker', 'Evans', 'Edwards', 'Collins', 'Stewart', 'Morris', 'Murphy', 'Cook',
        'Morgan', 'Bell', 'Bailey', 'Cooper', 'Richardson', 'Cox', 'Howard', 'Ward',
        'O\'Brien', 'McCarthy', 'Sullivan', 'Kennedy', 'Walsh', 'Burns', 'Kelly', 'Flynn',
    },
}

-- Location Names (based on coordinates)
Config.LocationNames = {
    { name = "Valentine", coords = vector3(-179.0, 641.0, 114.0), radius = 300.0 },
    { name = "Rhodes", coords = vector3(1292.0, -1303.0, 77.0), radius = 300.0 },
    { name = "Saint Denis", coords = vector3(2650.0, -1200.0, 46.0), radius = 500.0 },
    { name = "Strawberry", coords = vector3(-1792.0, -384.0, 160.0), radius = 200.0 },
    { name = "Blackwater", coords = vector3(-814.0, -1282.0, 43.0), radius = 300.0 },
    { name = "Tumbleweed", coords = vector3(-5506.0, -2938.0, -2.0), radius = 250.0 },
    { name = "Armadillo", coords = vector3(-3658.0, -2610.0, -14.0), radius = 200.0 },
    { name = "Annesburg", coords = vector3(2905.0, 1282.0, 44.0), radius = 250.0 },
    { name = "Van Horn", coords = vector3(2984.0, 443.0, 51.0), radius = 200.0 },
    { name = "Emerald Ranch", coords = vector3(1430.0, 310.0, 88.0), radius = 200.0 },
    { name = "Colter", coords = vector3(-1378.0, 2393.0, 307.0), radius = 150.0 },
    { name = "Hanging Dog Ranch", coords = vector3(-1029.0, 1543.0, 295.0), radius = 150.0 },
    { name = "Manzanita Post", coords = vector3(-1970.0, -1557.0, 113.0), radius = 150.0 },
    { name = "Lagras", coords = vector3(2120.0, -653.0, 42.0), radius = 150.0 },
    { name = "Thieves Landing", coords = vector3(-1449.0, -2055.0, 42.0), radius = 150.0 },
    { name = "MacFarlane's Ranch", coords = vector3(-2338.0, -2398.0, 62.0), radius = 200.0 },
    { name = "Tall Trees", coords = vector3(-1834.0, -1073.0, 93.0), radius = 300.0 },
    { name = "Big Valley", coords = vector3(-1523.0, 702.0, 147.0), radius = 400.0 },
    { name = "Heartlands", coords = vector3(870.0, 256.0, 95.0), radius = 500.0 },
    { name = "Grizzlies", coords = vector3(-485.0, 1735.0, 215.0), radius = 600.0 },
    { name = "Roanoke Ridge", coords = vector3(2575.0, 833.0, 77.0), radius = 400.0 },
    { name = "Bluewater Marsh", coords = vector3(2064.0, -247.0, 42.0), radius = 300.0 },
    { name = "Bayou Nwa", coords = vector3(2254.0, -783.0, 42.0), radius = 400.0 },
    { name = "Scarlett Meadows", coords = vector3(1150.0, -1050.0, 70.0), radius = 400.0 },
    { name = "Lemoyne", coords = vector3(1900.0, -1100.0, 45.0), radius = 800.0 },
    { name = "New Austin", coords = vector3(-4000.0, -2800.0, 0.0), radius = 1500.0 },
}

-- Wagon Storage Settings
Config.WagonStorage = {
    Enabled = true,
    MaxBodies = 6,
    StoreRadius = 5.0,
    WagonModels = {
        'coach3',
        'huntercart01',
       
    },
}
-- Burial Settings
Config.BurialMode = 'anywhere' -- 'anywhere' or 'graves' (graves uses Config.Graves locations)

-- If using 'anywhere' mode
Config.AnywhereBurial = {
    Enabled = true,
    RequireShovel = true,          -- Set to true if player needs shovel item
    ShovelItem = 'shovel', 
	AllowAnimals = true,	-- Item name if RequireShovel is true
}

-- Grave Text Settings
Config.GraveText = {
    Enabled = true,
    Duration = 300,  -- Duration in seconds (5 minutes = 300)
    DisplayDistance = 5.0,  -- How far away you can see the text
    Font = 1,
    Scale = 0.35,
    DefaultText = "R.I.P.",  -- Shown if no name available
}
-- Grave locations for burial
Config.Graves = {
    [1] = {
        name = "Grave 1",
        coords = vector3(1282.042, -1242.295, 79.989),
        heading = 26.0788,
    },
    [2] = {
        name = "Grave 2",
        coords = vector3(1280.190, -1243.406, 79.721),
        heading = 26.999,
    },
    [3] = {
        name = "Grave 3",
        coords = vector3(1277.646, -1243.937, 79.641),
        heading = 28.891,
    },
    [4] = {
        name = "Grave 4",
        coords = vector3(1273.183, -1238.915, 79.715),
        heading = 21.938,
    },
    [5] = {
        name = "Grave 5",
        coords = vector3(1275.114, -1237.997, 79.923),
        heading = 17.2695,
    },
    [6] = {
        name = "Grave 6",
        coords = vector3(1277.472, -1237.081, 80.183),
        heading = 22.858,
    },
    [7] = {
        name = "Grave 7",
        coords = vector3(1277.429, -1231.219, 80.685),
        heading = 9.5856,
    },
    [8] = {
        name = "Grave 8",
        coords = vector3(1273.790, -1229.006, 80.594),
        heading = 5.973,
    },
    [9] = {
        name = "Grave 9",
        coords = vector3(1270.969, -1230.913, 80.255),
        heading = 11.065,
    },
    [10] = {
        name = "Grave 10",
        coords = vector3(1267.327, -1232.056, 79.946),
        heading = 16.203,
    },
    [11] = {
        name = "Grave 11",
        coords = vector3(1268.745, -1228.923, 80.280),
        heading = 15.811,
    },
    [12] = {
        name = "Grave 12",
        coords = vector3(1275.525, -1220.127, 81.420),
        heading = 18.769,
    },
    [13] = {
        name = "Grave 13",
        coords = vector3(1271.028, -1224.483, 80.772),
        heading = 15.9214,
    },
    [14] = {
        name = "Grave 14",
        coords = vector3(1272.812, -1224.395, 80.905),
        heading = 16.95,
    },
    [15] = {
        name = "Grave 15",
        coords = vector3(1274.721, -1223.716, 81.162),
        heading = 22.049,
    },
    [16] = {
        name = "Grave 16",
        coords = vector3(-238.43, 819.83, 123.88),
        heading = 313.18,
    },
    [17] = {
        name = "Grave 17",
        coords = vector3(-238.08, 829.77, 123.61),
        heading = 291.93,
    },
	[18] = {
        name = "Grave 18",
        coords = vector3(-231.44, 825.87, 124.31),
        heading = 291.93,
    },
	[19] = {
        name = "Grave 19",
        coords = vector3(-232.12, 828.44, 124.3),
        heading = 291.93,
    },
	[20] = {
        name = "Grave 20",
        coords = vector3(-231.06, 823.24, 124.3),
        heading = 291.93,
    },
	[21] = {
        name = "Grave 21",
        coords = vector3(-954.67, -1206.23, 55.49),
        heading = 291.93,
    },
}