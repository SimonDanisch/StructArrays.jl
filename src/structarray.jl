"""
A type that stores an array of structures as a structure of arrays.
# Fields:
- `columns`: a tuple of arrays. Also `columns(x)`
"""
struct StructArray{T, N, C<:Tup} <: AbstractArray{T, N}
    columns::C

    function StructArray{T, N, C}(c) where {T, N, C<:Tup}
        length(c) > 0 || error("must have at least one column")
        n = size(c[1])
        length(n) == N || error("wrong number of dimensions")
        for i = 2:length(c)
            size(c[i]) == n || error("all columns must have same size")
        end
        new{T, N, C}(c)
    end
end

StructArray{T}(c::C) where {T, C<:Tuple} = StructArray{T}(NamedTuple{fields(T)}(c))
StructArray{T}(c::C) where {T, C<:NamedTuple} =
    StructArray{createtype(T, eltypes(C)), length(size(c[1])), C}(c)
StructArray(c::C) where {C<:NamedTuple} = StructArray{C}(c)

StructArray{T}(args...) where {T} = StructArray{T}(NamedTuple{fields(T)}(args))

columns(s::StructArray) = getfield(s, :columns)
getproperty(s::StructArray, key::Symbol) = getfield(columns(s), key)
getproperty(s::StructArray, key::Int) = getfield(columns(s), key)

size(s::StructArray) = size(columns(s)[1])

getindex(s::StructArray, I::Int...) = get_ith(s, I...)
function getindex(s::StructArray{T, N, C}, I::Union{Int, AbstractArray, Colon}...) where {T, N, C}
    StructArray{T}(map(v -> getindex(v, I...), columns(s)))
end

function view(s::StructArray{T, N, C}, I...) where {T, N, C}
    StructArray{T}(map(v -> view(v, I...), columns(s)))
end

setindex!(s::StructArray, val, I::Int...) = set_ith!(s, val, I...)

fields(::Type{<:NamedTuple{K}}) where {K} = K
fields(::Type{<:StructArray{T}}) where {T} = fields(T)

Base.propertynames(s::StructArray) = fieldnames(typeof(columns(s)))

@generated function fields(t::Type{T}) where {T}
   return :($(Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)))
end

@generated function push!(s::StructArray{T, 1}, vals) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :(push!($field, $val)))
    end
    push!(args, :s)
    Expr(:block, args...)
end

@generated function append!(s::StructArray{T, 1}, vals) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :(append!($field, $val)))
    end
    push!(args, :s)
    Expr(:block, args...)
end

function cat(dims, args::StructArray...)
    f = key -> cat(dims, (getproperty(t, key) for t in args)...)
    T = mapreduce(eltype, promote_type, args)
    StructArray{T}(map(f, fields(eltype(args[1]))))
end

for op in [:hcat, :vcat]
    @eval begin
        function $op(args::StructArray...)
            f = key -> $op((getproperty(t, key) for t in args)...)
            T = mapreduce(eltype, promote_type, args)
            StructArray{T}(map(f, fields(eltype(args[1]))))
        end
    end
end
