module MascarenesMaps

using ArchGDAL
using Colors
using ColorSchemes
using DataFrames
using DBFTables
using GeometryBasics
import LandscapeChange
using Makie
using Rasters
using RasterDataSources
using Stencils

using Rasters.Lookups
using LandscapeChange: NamedVector

const NV = NamedVector
using Rasters: Between

export define_category_links

export plot_compilation!

export plot_habitats!, plot_aggregate!, add_legend! 

export plot_process!

export compile_all, load_srtm_masks, summarise_timeline, standardize_timeline

export stripe_raster, color_raster, namedvector_raster, cross_validate_timeline

export Link

const basepath = realpath(joinpath(@__DIR__, ".."))

include("generate.jl")
include("transitions.jl")
include("landcover_settings.jl")
include("map_file_list.jl")
include("plots.jl")
include("rasters.jl")

end
