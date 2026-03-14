local conversions = {
    ["stairs:slab_stone"] = "moreblocks:slab_stone",
    ["stairs:slab_wood"] = "moreblocks:slab_wood",
    ["stairs:stair_stone"] = "moreblocks:stair_stone",
    ["stairs:stair_wood"] = "moreblocks:stair_wood",
}

for old,new in pairs(conversions) do
    minetest.register_lbm({
        name = "safesaw:convert_"..old:gsub(":","_"),
        nodenames = {old},
        run_at_every_load = false,
        action = function(pos,node)
            minetest.set_node(pos,{name=new})
        end
    })
end
