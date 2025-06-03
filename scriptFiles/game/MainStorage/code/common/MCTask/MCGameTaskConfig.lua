-- 游戏主线任务系统配置
---@class MCGameTaskConfig
local MCGameTaskConfig = {
    chapter_1 = {
        chapter = "章节1",
        name = "斗魂之路",
        description = "踏上成为魂师的第一步",
        quests = {
            {
                id = 1000,
                name = "斗魂觉醒",
                description ="觉醒斗魂，成为斗神第一人",
                location = {-1048.651, 8.036, 322.627},
                unlock_condition = nil,  -- 无解锁条件，游戏开始即可接取
                npc ={"g0_1", "g0_2"} ,
                complete_conditions = {
                    "变量 任务 主线 1000 get %p = 1"
                },
                rewards = {
                    "添加 武魂 随机 %p = 1",
                    "设置 任务 主线 1001 状态 %p = 进行中",
                    "增加 经验 %p = 100",
                },
                dialogue = {
                    sequence = {
                        {speaker = "npc", npc_id = "g0_1", text = "孩子!你就是%player%吧！欢迎来到诺丁城武魂殿。"},
                        {speaker = "npc", npc_id = "g0_1", text = "这是一个斗魂的世界"},
                        {speaker = "npc", npc_id = "g0_2", text = "哦耶！"},
                        {speaker = "player", text = "我感受到了血脉的呼唤，斗魂正在涌现。"},
                        {speaker = "npc", npc_id = "g0_1", text = "很好，你已经开始感受到了。"},
                        {speaker = "npc", npc_id = "g0_1", text = "新来的小家伙可真有灵性！"},
                    },
                    
                },
                objectives={
                    {
                        type = "talk", -- 对话类型
                        target = "g0_1", -- 目标NPC
                        count = 1 -- 需要1次对话
                    }
                },
                next_quest = 1001,
            },
            {
                id = 1001,
                name = "第一魂环",
                description="猎杀魂兽，等级到达10级",
                location = {-225.562, -42.368, 0},
                unlock_condition = {
                    "变量 任务 主线 1001 get %p = 2"
                },  
                complete_conditions = {
                    "变量 人物 等级 lv get %p >= 10",
                },
                rewards = {
                    "变量 任务 主线 1002 set %p 2",
                },
             
                next_quest = 1002,
            },
        }
    },
}

return MCGameTaskConfig