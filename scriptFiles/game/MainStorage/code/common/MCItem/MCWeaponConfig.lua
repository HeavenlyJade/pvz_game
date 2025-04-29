--- 武器配置文件

---@class  MCWeaponConfig
local MCWeaponConfig = {
    weapon_def = {
        ["we_1"] = {
            id = "we_1",
            name = "星海神秘之刃",
            asset = "resId&usev2=1://352280310502682624",
            pos = 1001,
            quality = 4,
            level = 1,
            itype =1,
            attrs=  {
                [1] = { k = "int",     v = 9  },
                [2] = { k = "rd_spell",v = 30 },
                [3] = { k = "r3",      v = 27 },
                [4] = { k = "r4",      v = 27 },
                [5] = { k = "edp",     v = 9  }, 
                [6] = { k = "str",     v = 9  },
            },
        },    
    }
}

return MCWeaponConfig
