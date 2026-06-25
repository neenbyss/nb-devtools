Config = {}

Config.Command   = 'nbd'
Config.AdminOnly = true

Config.Placer = {
    Step     = 0.05,
    FastStep = 0.25,
    RotStep  = 5.0,
    Alpha    = 150,
}

Config.Camera = {
    Speed      = 0.15,
    FastSpeed  = 0.8,
    SlowSpeed  = 0.03,
    FovDefault = 50.0,
    FovMin     = 10.0,
    FovMax     = 100.0,
    FovStep    = 5.0,
    MouseSpeed = 5.0,
}

Config.Inspector = {
    Distance = 50.0,
}

Config.PedPresets = {
    { label = 'Male Freemode',   model = 'mp_m_freemode_01'  },
    { label = 'Female Freemode', model = 'mp_f_freemode_01'  },
    { label = 'Mechanic',        model = 's_m_m_mech_01'     },
    { label = 'Security Guard',  model = 's_m_m_security_01' },
    { label = 'Doctor',          model = 's_m_m_doctor_01'   },
    { label = 'Shop Keeper',     model = 'mp_m_shopkeep_01'  },
    { label = 'Bartender',       model = 's_f_m_fembarber'   },
    { label = 'Taxi Driver',     model = 's_m_m_taxi_01'     },
}

Config.PropPresets = {
    { label = 'Marker Cone',     model = 'prop_mp_cone_01'      },
    { label = 'Wooden Box S',    model = 'prop_box_wood01a'     },
    { label = 'Wooden Box L',    model = 'prop_box_wood02a'     },
    { label = 'Office Chair',    model = 'prop_off_chair_01'    },
    { label = 'Office Table',    model = 'prop_table_01'        },
    { label = 'Metal Bin',       model = 'prop_bin_01a'         },
    { label = 'Street Light',    model = 'prop_streetlight_09'  },
    { label = 'Barrier',         model = 'prop_barrier_work04b' },
}
