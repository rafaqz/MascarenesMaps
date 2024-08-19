deleteat!(Base.LOAD_PATH, 2:3) # Don't allow other environments

using Revise
using Rasters
using ColorSchemes
using Colors
using GLMakie
using CairoMakie
CairoMakie.activate!()

using MascarenesMaps

basepath = realpath(joinpath(dirname(pathof(MascarenesMaps)), ".."))

filelists = define_map_files()
masks = load_srtm_masks() 

# Original vegetation rasters
mus_veg_path = joinpath(basepath, "data/vegetation/mus/lostland_vegetaion.tif")
reu_veg_path = joinpath(basepath, "data/vegetation/reu/strassberg_vegetaion.tif")

# Habitat classes
island_habitat_names = (;
    mus=["semi-dry_evergreen_forest", "open_dry_palm-rich_woodland", "wet_forest", "pandanus_swamp", "mossy_rainforest", "mangrove", "wetland vegetation"],
    reu=["Acacia heterophylla forest", "Coastal habitats", "Lava flows", "Leeward mountain rainforest", "Leeward submountain rainforest", "Lowland open woodland",
         "Lowland rainforest", "Pandanus humid thicket", "Pandanus mountain humid thicket", "Philippia mountain thicket", "Semi dry forest", "Subalpine grassland",
         "Subalpine heathland", "Subalpine shrubland on lapillis", "Subalpine Sophora thicket", "Submountain mesic forest", "Wetlands", "Windward mountain rainforest",
         "Windward submountain rainforest", "no_data"],
)

# Compile statistics

landcover_statistics = map(filelists, masks) do f, m
    compile_all(f, m, MascarenesMaps.transitions)
end
certain_uncleared = map(landcover_statistics) do island
    map(island.merged) do xs
        count(xs) == 1 && xs.native
    end |> x -> rebuild(x; missingval=0)
end
uncertain_uncleared = map(landcover_statistics) do island
    map(island.merged) do xs
        count(xs) > 1 && xs.native
    end |> x -> rebuild(x; missingval=0)
end

original_veg = (;
    mus=reorder(replace_missing(Raster(mus_veg_path), 0), dims(uncertain_uncleared.mus)),
    reu=resample(reorder(replace_missing(Raster(reu_veg_path), 0), uncertain_uncleared.reu); to=masks.reu),
)

# Mask final vegetation maps
# We just broadcast a multiplication of the vegetation 
# over the timeseries of uncleared masks
k = keys(original_veg) # Probably no rod
uncleared = map(original_veg, certain_uncleared[k], uncertain_uncleared[k]) do v, c, u
    (; certain=broadcast_dims(*, c, v), uncertain=broadcast_dims(*, u, v))
end
nhabitats = map(length, island_habitat_names)

# Mauritius
mus_fig = let
    collen, rowlen = size = (1700, 2400)
    fig = Figure(; size);
    nrows, ncols = 5, 4
    # fig = Figure(; size=(2400, 1700));
    # nrows, ncols = 3, 6
    data = uncleared.mus
    cmap = :tableau_20
    habitat_colors = map(x -> getproperty(ColorSchemes, cmap)[(x - 1) / 9 ], 1:nhabitats.mus) |> reverse
    # Heatmaps
    plot_habitats!(fig, data; colormap=habitat_colors, nrows, ncols, show_uncertain=true) 
    # Legend
    add_legend!(fig[nrows+1, ncols], habitat_colors, island_habitat_names.mus)
    # Area plot
    line_ax = Axis(fig[nrows+1, 1:ncols-1])
    plot_aggregate!(line_ax, data, habitat_colors)
    # Title
    # fig[nrows+2, :] = Label(fig, "Mauritius Habitat Loss (striped/transparent areas uncertain)"; fontsize=30)
    for i in 1:nrows+1
        # rowgap!(fig.layout, i, 1)
        rowsize!(fig.layout, i, rowlen / (nrows + 1) * 0.85)
    end
    for i in 1:ncols
        # i == ncols || colgap!(fig.layout, i, 0)
        colsize!(fig.layout, i, collen / ncols)
    end
    fig
end
save("$basepath/images/mauritius_habitat_loss.png", mus_fig)

# Reunion
reu_fig = let
    collen, rowlen = size = (1700, 2000)
    nrows, ncols = 3, 4
    fig = Figure(; size);
    # fig = Figure(; size=(2400, 1700));
    # nrows, ncols = 2, 5
    data = uncleared.reu
    cmap = :tableau_20
    habitat_colors = map(x -> getproperty(ColorSchemes, cmap)[(x - 1) / (nhabitats.reu - 1) ], 1:nhabitats.reu)
    # Heatmaps
    plot_habitats!(fig, data; colormap=habitat_colors, nrows, ncols, show_uncertain=true);
    add_legend!(fig[nrows:nrows+1, ncols], habitat_colors, island_habitat_names.reu)
    # Area plot
    line_ax = Axis(fig[nrows+1, 1:ncols-1])
    plot_aggregate!(line_ax, data, habitat_colors)
    for i in 1:nrows+1
        # i < nrows || rowgap!(fig.layout, i, 0)
        rowsize!(fig.layout, i, rowlen / (nrows + 1) * 0.9)
    end
    for i in 1:ncols
        # i == ncols || colgap!(fig.layout, i, 0)
        colsize!(fig.layout, i, collen / ncols * 0.9)
    end
    fig
end
save("$basepath/images/reunion_habitat_loss.png", reu_fig)


