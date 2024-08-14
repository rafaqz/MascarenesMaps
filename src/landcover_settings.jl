const states = (native=1, cleared=2, abandoned=3, urban=4, forestry=5, water=6)
const category_names = NamedTuple{keys(states)}(keys(states))
const island_names = (; mus=:mus, reu=:reu, rod=:rod)

const transitions = NV(
    native    = NV(native=true,  cleared=false, abandoned=false, urban=false, forestry=false,  water=false),
    cleared   = NV(native=true,  cleared=true,  abandoned=true,  urban=false, forestry=false,  water=false),
    abandoned = NV(native=false, cleared=true,  abandoned=true,  urban=false,  forestry=false,  water=false),
    urban     = NV(native=false,  cleared=true,  abandoned=true,  urban=true,  forestry=false,  water=false),
    forestry  = NV(native=false,  cleared=true,  abandoned=true,  urban=false, forestry=true,   water=false),
    water     = NV(native=false,  cleared=true,  abandoned=true,  urban=true,  forestry=true,  water=true),
)
