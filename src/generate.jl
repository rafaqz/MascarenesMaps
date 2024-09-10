
struct Link#{F,C,T}
    filename::Union{String,Nothing}
    categories::Union{Vector{String},Nothing}
    to::NamedTuple#{<:Any,<:Tuple{Vararg{Union{Nothing,<:Pair{Int},<:Vector{<:Pair{Int}}}}}}
    function Link(filename, categories, to) 
        _validate_link(to, categories)
        new(filename, categories, to) 
    end
end
Link(; filename, categories, to,) = Link(filename, categories, to)

_validate_link(to::NamedTuple, categories::Nothing) = nothing
_validate_link(to::NamedTuple, categories::Vector{String}) =
    foreach((l, k) -> _validate_link(l, categories, k), to, keys(to))
_validate_link(to::Nothing, categories::Nothing, key) = nothing
_validate_link(to::Nothing, categories::Vector{String}, key) = nothing
_validate_link(to::AbstractArray, categories::Vector{String}, key) =
    foreach(l -> _validate_link(l, categories, key), to)
_validate_link(to::Pair, categories::Vector{String}, key) =
    _validate_link(to[2], categories, key)
_validate_link(to::Tuple, categories::Vector{String}, key) =
    _validate_link(to[2], categories, key)
function _validate_link(to::String, categories::Vector{String}, key)
    to in categories || throw(ArgumentError("$to not found in $categories for item $key"))
    nothing
end


function compile_all(filelist, mask, transitions)
    standardized = namedvector_raster.(standardize_timeline(filelist, mask, states).timeline) |> Rasters.combine
    final = cross_validate_timeline(standardized, transitions)
    filled = map(standardized, final) do rs, fs
        if any(rs)
            zero(rs)
        else
            fs
        end
    end
    added_uncertainty = map(standardized, final) do rs, fs
        # We minimise forced values in the source throught its possible 
        # transitions, they may resolve to one or two distinct timelines. 
        if any(rs) # Ignore completely missing
            map(rs, fs) do r, f
                !r & f
            end
        else
            rs
        end
    end
    removed_uncertainty = map(standardized, final) do rs, fs
        map(rs, fs) do r, f
            r & !f
        end
    end
    final_uncertainty = map(final) do fs
        if count(fs) > 1
            fs
        else
            zero(fs)
        end
    end

    return (; standardized, filled, added_uncertainty, removed_uncertainty, final_uncertainty, final)
end

function summarise_timeline(timelines)
    map(timelines) do t
        sum(+, t; dims=(X, Y)) |> _nt_vecs
    end
end

function _nt_vecs(xs::AbstractArray{<:NamedVector{K}}) where K
    xs = dropdims(xs; dims=(X(), Y()))
    vecs = map(1:length(K)) do i
        getindex.(xs, i)
    end
    RasterStack(vecs...; name=K)
end

"""
    standardize_timeline(links, mask; categories)

"""
function standardize_timeline(
    links::NamedTuple{Labels}, mask::Raster, final_categories::NamedTuple;
    start_year=1500,
) where Labels

    linked_rasters = map(links, NamedTuple{Labels}(Labels)) do link, key
        categorized_raster = if isnothing(link.filename)
            mask .* 1
        else
            rebuild(mask .* _fix_order(Raster(link.filename)); missingval=0)
        end
        linked_timeline = _link_timeline(link, final_categories)
        grouped_rasters = map(linked_timeline) do (time, link_spec)
            _standardize_raster(categorized_raster, link_spec; 
                mask, time, sources=link.categories
            )
        end
        (; link, categorized_raster, grouped_rasters, linked_timeline, times=first.(linked_timeline))
    end
    timeline = _merge_timeline(linked_rasters; start_year)

    return (; files=linked_rasters, timeline)
end

function _merge_timeline(linked_rasters; start_year)
    alltimes = union(map(f -> f.times, linked_rasters)...)
    sort!(alltimes)
    timeline_dict = Dict{Int,Any}()
    for x in linked_rasters
        for time in alltimes
            i = findfirst(==(time), x.times)
            isnothing(i) && continue
            to_add = x.grouped_rasters[i]
            if haskey(timeline_dict, time)
                # Combine matching times with boolean or
                current = timeline_dict[time]
                timeline_dict[time] = map(.|, current, to_add)
            else
                timeline_dict[time] = to_add
            end
        end
    end

    # Sort the rasters into a complete timeline
    timeline_pairs = collect(pairs(timeline_dict))
    sort!(timeline_pairs; by=first)
    # Create raster stacks from values
    # map(identity helps resolve the final RasterStack type
    stacks = map(identity, RasterStack.(last.(timeline_pairs)))

    years = first.(timeline_pairs)
    timedim = Ti(years; 
        sampling=Intervals(End()), 
        span=Irregular(start_year, last(years))
    )
    return RasterSeries(stacks, timedim)
end


    # for (time, (cat_key, forced_rast)) in forced
    #     st = timeline[At(time)]
    #     # Wipe all stack layers where forced raster is true
    #     map(Rasters.DimensionalData.layers(st)) do layer
    #         broadcast!(layer, layer, forced_rast) do l, f
    #             f ? false : l
    #         end
    #     end
    #     # Add forced values to its category
    #     cat_rast = getproperty(st, cat_key)
    #     broadcast!(cat_rast, cat_rast, forced_rast) do c, f
    #         f ? true : c
    #     end
    # end

function _standardize_raster( r::Raster, dests::NamedTuple{C}; kw...) where C
    map(dests, NamedTuple{C}(C)) do dest, label
        _standardize_raster(r, dest; label, kw...)
    end
end
function _standardize_raster(r::Raster, dests::Vector; mask, kw...)::Raster{Bool}
    layers = map(dests) do dest
        _standardize_raster(r, dest; mask, kw...)
    end
    out = Bool.(broadcast(|, layers...) .& mask)
    @assert missingval(out) == false
    return out
end
function _standardize_raster(r::Raster, destfunc::Tuple{<:Function,Vararg}; mask, kw...)::Raster{Bool}
    f, dests... = destfunc
    vals = map(dests) do dest
        _standardize_raster(r, dest; mask, kw...)
    end
    return map(f, vals...) .& mask
end
function _standardize_raster(r::Raster, dest::Symbol; mask, kw...)::Raster{Bool}
    if dest === :fill
        return mask
    else
        error(":$dest directive not understood, only `:fill` is allowed")
    end
end
function _standardize_raster(r::Raster, dest::Nothing; kw...)::Raster{Bool}
    return map(_ -> false, r)
end
function _standardize_raster(r::Raster, dest::String;
    sources, mask, kw...
)::Raster{Bool}
    I = findall(==(dest), map(String, sources))
    if length(I) == 0
        error("could not find $category in $(sources)")
    end
    # Get all values matching the first category as a mask
    out = Bool.(r .== first(I))
    # Add pixels for any subsequent categories
    foreach(I[2:end]) do i
        out .|= r .== first(i)
    end
    return rebuild(out .& mask; missingval=false)
end
function _standardize_raster(r::Raster, x::Pair{Symbol};
    forced, time, label, kw...
)
    x[1] == :force || error("$(x[1]) not recognised")
    cr = _standardize_raster(r, x[2]; forced, time, label, kw...)
    push!(forced, time => label => cr)
    return cr
end
function _standardize_raster(r::Raster, categories::Vector, x, mask, forced, time, label::Symbol)
    error("slice must be a NamedTuple, String or Vector{String}, got a $(typeof(x)) - $x")
end

function _get_times(link::Link)
    times = Set{Int}()
    for cat in link.to
        if cat isa Pair{Int} # 1999 => x
            time = cat[1]
            push!(times, time)
        elseif cat isa Vector # [1999 => x, 2000 => y]
            foreach(cat) do (time, _)
                push!(times, time)
            end
        end
    end
    return sort!(collect(times))
end

function _link_timeline(link::Link, final_categories)
    times = _get_times(link)
    # Organise by linear time
    spec = map(times) do time
        time => map(final_categories) do fc
            # Fill all missing dest categories with `nothing`
            haskey(link.to, fc) || return nothing
            dest = link.to[fc]
            # Nothing is allowed
            isnothing(dest) && return nothing
            if dest isa Pair
                # Pairs of time => x
                first(dest) == time ? last(dest) : nothing
            else # Vector of [time1 => x, time2 => y]
                # Find which one matches the current `time`
                i = findfirst(c -> first(c) == time, dest)
                if isnothing(i)
                    return nothing
                else
                    return last(dest[i])
                end
            end
        end
    end

    return spec
end

_fix_order(A) = reorder(A, ForwardOrdered)
