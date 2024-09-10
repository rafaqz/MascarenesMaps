deleteat!(Base.LOAD_PATH, 2:lastindex(Base.LOAD_PATH)) # Don't allow other environments

using Revise
using Rasters
using ColorSchemes
using Colors
using FileIO
using ImageIO

using CairoMakie
CairoMakie.activate!()
# using GLMakie
# GLMakie.activate!()

using MascarenesMaps

basepath = realpath(joinpath(dirname(pathof(MascarenesMaps)), ".."))

category_links = define_category_links()
masks = load_srtm_masks()

# Original vegetation rasters
mus_veg_path = joinpath(basepath, "data/vegetation/mus/lostland_vegetation.tif")
reu_veg_path = joinpath(basepath, "data/vegetation/reu/strassberg_vegetation.tif")

# Habitat classes
island_habitat_names = (;
    mus=["semi-dry_evergreen_forest", "open_dry_palm-rich_woodland", "wet_forest", "pandanus_swamp", "mossy_rainforest", "mangrove", "wetland vegetation"],
    reu=["Acacia heterophylla forest", "Coastal habitats", "Lava flows", "Leeward mountain rainforest", "Leeward submountain rainforest", "Lowland open woodland",
         "Lowland rainforest", "Pandanus humid thicket", "Pandanus mountain humid thicket", "Philippia mountain thicket", "Semi dry forest", "Subalpine grassland",
         "Subalpine heathland", "Subalpine shrubland on lapillis", "Subalpine Sophora thicket", "Submountain mesic forest", "Wetlands", "Windward mountain rainforest",
         "Windward submountain rainforest", "no_data"],
)

# Compile statistics
landcover_statistics = map(category_links, masks) do f, m
    compile_all(f, m, MascarenesMaps.transitions)
end
certain_uncleared = map(landcover_statistics) do island
    map(island.final) do xs
        count(xs) == 1 && xs.native
    end |> x -> rebuild(x; missingval=0)
end
uncertain_uncleared = map(landcover_statistics) do island
    map(island.final) do xs
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
habitat = map(original_veg, certain_uncleared[k], uncertain_uncleared[k]) do v, c, u
    (; certain=broadcast_dims(*, c, v), uncertain=broadcast_dims(*, u, v))
end
nhabitats = map(length, island_habitat_names)


# Mauritius
mus_fig = let
    collen, rowlen = size = (1700, 2400)
    nrows, ncols = 5, 4
    fig = Figure(; size)
    colormap = :tableau_20
    habitat_colors = map(x -> getproperty(ColorSchemes, colormap)[(x - 1) / 9 ], 1:nhabitats.mus) |> reverse
    # Heatmaps
    plot_habitats!(fig, habitat.mus; 
        colormap=habitat_colors, 
        nrows, ncols, 
        show_uncertain=true,
        titlesize=25.0,
    )
    # Legend
    add_legend!(fig[nrows+1, ncols], habitat_colors, island_habitat_names.mus)
    # Area plot
    line_ax = Axis(fig[nrows+1, 1:ncols-1]; xticklabelsize=25.0)
    plot_aggregate!(line_ax, habitat.mus, habitat_colors)
    # Title
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
save("$basepath/images/habitat_loss_mus.png", mus_fig)

# Reunion
reu_fig = let
    collen, rowlen = size = (1700, 2000)
    nrows, ncols = 3, 4
    fig = Figure(; size);
    cmap = :tableau_20
    habitat_colors = map(x -> getproperty(ColorSchemes, cmap)[(x - 1) / (nhabitats.reu - 1) ], 1:nhabitats.reu)
    # Heatmaps
    plot_habitats!(fig, habitat.reu; 
        colormap=habitat_colors, 
        nrows, ncols, 
        titlesize=25.0,
        show_uncertain=true
    );
    add_legend!(fig[nrows:nrows+1, ncols], habitat_colors, island_habitat_names.reu)
    # Area plot
    line_ax = Axis(fig[nrows+1, 1:ncols-1]; xticklabelsize=25.0)
    plot_aggregate!(line_ax, habitat.reu, habitat_colors)
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
save("$basepath/images/habitat_loss_reu.png", reu_fig)
