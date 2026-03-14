-- SafeSaw - Circular saw for Minetest
-- Copyright (C) 2026 Vasyl Onufriichuk
--
-- This project is based in part on code originally released under the zlib License.
-- Original authors retain copyright to their respective work.
--
-- This modified version and all new code are licensed under the
-- GNU General Public License v3.0.
--
-- You should have received a copy of the GNU GPL v3 license
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
local modname = minetest.get_current_modname()

-- Таблиця користувачів
local users = {}

-- Заборонені моди (ігнорувати блоки)
local banned_mods = {"techage","mesecons","pipeworks","technic"}

-- Форми блоків, які створює пилка
local saw_shapes = {"slab","stair","panel","micro"}

-- Перевірка, чи блок безпечний
local function is_valid_block(name, def)
    if not def or not name then return false end
    local mod = name:split(":")[1]
    for _, m in ipairs(banned_mods) do
        if mod == m then return false end
    end
    if def.drawtype ~= "normal" then return false end
    if not def.groups then return false end
    if not (def.groups.stone or def.groups.wood) then return false end
    if def.groups.container then return false end
    return true
end

-- Генерація списку безпечних блоків
local safe_blocks = {}
for name, def in pairs(minetest.registered_nodes) do
    if is_valid_block(name, def) then
        table.insert(safe_blocks, name)
    end
end

-- Генерація вихідних предметів
local function generate_output(block_name, max_offered)
    local output = {}
    for _, shape in ipairs(saw_shapes) do
        local form_name = block_name.."_"..shape
        if minetest.registered_nodes[form_name] then
            table.insert(output, form_name.." "..max_offered)
        end
    end
    return output
end

-- Створення Formspeс для пилки
local function get_formspec(player_name)
    local user = users[player_name]
    return "formspec_version[4]"..
           "size[15,15]"..
           "label[0,0;Smart Circular Saw]"..
           "list[detached:safesaw_"..player_name..";input;2,1;1,1;]"..
           "label[0.75,3;Left-over]"..
           "list[detached:safesaw_"..player_name..";micro;2,2.5;1,1;]"..
           "label[0.75,4.3;Recycle output]"..
           "list[detached:safesaw_"..player_name..";recycle;2,4;1,1;]"..
           "field[0.75,6;1,1;max_offered;Max:;"..user.max_offered.."]"..
           "button[2,6;1,1;Set;Set]"..
           "list[detached:safesaw_"..player_name..";output;4,1;8,6;]"..
           "list[current_player;main;4,9.5;8,4;]"..
           "listring[current_player;main]"..
           "listring[detached:safesaw_"..player_name..";input]"..
           "listring[current_player;main]"..
           "listring[detached:safesaw_"..player_name..";output]"
end

-- Скидання інвентарю
local function reset_inventory(inv, player_name)
    inv:set_list("input", {})
    inv:set_list("micro", {})
    inv:set_list("output", {})
    users[player_name].micros = 0
end

-- Оновлення інвентарю
local function update_inventory(inv, player_name, delta)
    local user = users[player_name]
    user.micros = user.micros + delta
    local amount = user.micros

    inv:set_list("recycle", {})

    if amount < 1 then
        reset_inventory(inv, player_name)
        return
    end

    local stack = inv:get_stack("input",1)
    if stack:is_empty() then
        reset_inventory(inv, player_name)
        return
    end

    local node_name = stack:get_name()
    local modname_prefix = node_name:match("^default:") and "moreblocks" or node_name:split(":")[1]

    inv:set_list("input", {node_name.." "..math.floor(amount/8)})
    inv:set_list("micro", {modname_prefix..":micro_"..node_name:split(":")[2].." "..(amount%8)})
    inv:set_list("output", generate_output(node_name, user.max_offered))
end

-- Дозвіл вставки предметів
local function allow_put(inv, listname, index, stack)
    if listname == "output" or listname == "micro" then return 0 end
    if listname == "input" then
        if not inv:is_empty("input") then
            if inv:get_stack("input",index):get_name() ~= stack:get_name() then return 0 end
        end
        return stack:get_count()
    elseif listname == "recycle" then
        return stack:get_count()
    end
    return stack:get_count()
end

-- Обробка взяття предметів
local function on_take(inv, listname, index, stack, player)
    local player_name = player:get_player_name()
    if listname == "input" then
        update_inventory(inv, player_name, -8*stack:get_count())
    elseif listname == "micro" then
        update_inventory(inv, player_name, -stack:get_count())
    elseif listname == "output" then
        update_inventory(inv, player_name, -stack:get_count())
    end
end

-- Обробка вставки предметів
local function on_put(inv, listname, index, stack, player)
    local player_name = player:get_player_name()
    if listname == "input" then
        update_inventory(inv, player_name, 8*stack:get_count())
    elseif listname == "recycle" then
        update_inventory(inv, player_name, stack:get_count())
    end
end

-- Створення інвентарю для кожного гравця
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    users[name] = {micros=0,max_offered=99}
    local inv = minetest.create_detached_inventory("safesaw_"..name, {
        allow_put = allow_put,
        on_put = on_put,
        on_take = on_take,
        allow_move = function() return 0 end,
    }, name)
    inv:set_size("input",1)
    inv:set_size("micro",1)
    inv:set_size("recycle",1)
    inv:set_size("output",48)
    users[name].inv = inv
end)

-- Обробка поля Set
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()
    if formname=="safesaw:saw" and fields.Set then
        users[name].max_offered = tonumber(fields.max_offered) or 99
        update_inventory(users[name].inv,name,0)
        minetest.show_formspec(name,"safesaw:saw",get_formspec(name))
    end
end)
