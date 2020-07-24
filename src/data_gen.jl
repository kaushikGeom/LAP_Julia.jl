using TestImages: testimage
using CSV, FileIO, Images, Colors

"""
    gen_anhir(base_path = "/Users/MrTrololord/Documents/anhir/";
              mutate=true,
              diag_pixels=500)

Generate a random ANHIR image pair `target` and `source` images (in this order) from the ANHIR dataset at `base_path`.

See also: [`load_anhir_image_pair`](@ref)
"""
function gen_anhir(base_path = "/Users/MrTrololord/Documents/anhir/";
                   mutate=true,
                   diag_pixels=500)

    loc_table = CSV.read(joinpath(base_path, "location_table.csv"))
    train_rows = loc_table[loc_table[:status] .== "training", :]

    random_row = train_rows[rand(1:size(train_rows, 1)), :]
    target_path = random_row[Symbol("Target image")]
    source_path = random_row[Symbol("Source image")]

    target, source = load_anhir_image_pair(target_path, source_path, base_path=joinpath(base_path, "dataset"))

    if any(size(target) .!= size(source))
        println("sizes: ", size(target), ", ", size(source))
    end
    target, source = pad_images(target, source)

    if mutate
        target = resize_to_diag_size(target, diag_pixels)
        source = resize_to_diag_size(source, diag_pixels)
    end

    return target, source
end

"""
    resize_to_diag_size(img, desired_diag_size)

Resize `img` so that it has `desired_diag_size` pixels on its diagonal.

See also: [`gen_anhir`](@ref), [`load_anhir_image_pair`](@ref)
"""
function resize_to_diag_size(img, desired_diag_size)
    actual_diag_pixels = sqrt(sum((size(img).^2)))
    resize_ratio = desired_diag_size/actual_diag_pixels
    img = imresize(img, ratio = resize_ratio)
    return img
end

"""
    load_anhir_image_pair(target_path,
                          source_path;
                          base_path = "/Users/MrTrololord/Documents/anhir/dataset")

Load an image pair in the locations `target_path` and `source_path` from the location `base_path`.

See also: [`gen_anhir`](@ref)
"""
function load_anhir_image_pair(target_path,
                               source_path;
                               base_path = "/Users/MrTrololord/Documents/anhir/dataset")

    println(joinpath(base_path, target_path))
    target = Float64.(Gray.(load(joinpath(base_path, target_path))))
    source = Float64.(Gray.(load(joinpath(base_path, source_path))))

    return target, source
end


"""
    gen_lena()

Get a `256x256` grayscale "lena" image.
"""
function gen_lena()
    img = testimage("lena_gray")
    img = Float64.(img)
    return img
end

"""
    gen_quad_flow(img_size, max_magnitude=20)

Generate a smoothly varying locally constant random flow of size `img_size` and with a maximal
displacement of `max_magnitude` using a quadratic function:

```math
f(z) = a + b*z + c*z^2,
```
where:
```math
z = x + y*i, x, y ∈ (0,1)
```

The constants `a`, `b` and `c` are random numbers from the normal distribution with mean 0 and standard deviation 1.

See also: [`showflow`](@ref), [`gen_tiled_flow`](@ref), [`Flow`](@ref)
"""
function gen_quad_flow(img_size, max_magnitude=10)

    a, b, c = randn(), randn(), randn()
    f(z) = a + b*z + c*z^2

    X = ones(img_size[1]) * collect(range(0,1,length=img_size[2]))'
    Y = collect(range(0,1,length=img_size[1])) * ones(img_size[2])'
    A = Y .* im + X

    B = f.(A)
    max_len = maximum(vec_len.(B))
    B = B .* (max_magnitude/max_len)

    return B
end

"""
    gen_uniform_flow(flow_size=(200, 200), vector=1 + 1im, max_magnitude=vec_len(vector))

Generate a uniform flow of size `flow_size`, where every displacement vector is `vector`, scaled by `max_magnitude`.

Note: `max_magnitude` = `vec_len(vector)` by default,
so if nothing is enetered as `max_magnitude` the flow is made up of `vector` and is not scaled.

See also: [`showflow`](@ref), [`gen_tiled_flow`](@ref), [`Flow`](@ref), [`gen_quad_flow`](@ref)
"""
function gen_uniform_flow(flow_size=(200, 200),
                          vector=1 + 1im,
                          max_magnitude=vec_len(vector))

    flow = ones(flow_size) .* vector

    max_len = vec_len(vector)
    flow = flow .* (max_magnitude/max_len)
    return flow
end


"""
    gen_tiled_flow(flow_size::Tuple{T, T}=(200, 200),
    max_magnitude::Real=20, tile_size=nothing; filter_amp=nothing)::Flow where {T <: Integer}

Generate a smoothly varying random flow. The flow parameters are set by the function arguments.

It works by generating a tiled flow where each tile has a random uniform flow. Then it smooths these tiles by filtering with a gaussian.

# Arguments
- `flow_size::Tuple{T, T}=(200, 200)`: dimensions of the flow.
- `max_magnitude::Real=20`: maximum allowed amplitude of the displacement.
- `tile_size=nothing`: size of random uniform flow tiles that make up the start matrix. (The larger the slower the flow.) Note: If set to `flow_size` or larger it will generate a uniform pixel shift in a random direction.
- `filter_amp=nothing`: size of the gaussian filter which is used to smooth the random start matrix.

See also: [`showflow`](@ref), [`Flow`](@ref), [`gen_chess`](@ref), [`gen_quad_flow`](@ref)
"""
function gen_tiled_flow(flow_size::Tuple{T, T}=(200, 200),
                        max_magnitude::Real=10,
                        tile_size=nothing,
                        filter_amp=nothing)::Flow where {T <: Integer}

    # set default values
    if tile_size == nothing
        tile_size = ceil(Int64, flow_size[1]/6)
    end
    if filter_amp == nothing
        filter_amp = ceil(Int64, tile_size/2)
        if isodd(filter_amp)
            filter_amp += 1
        end
    end

    tile_count = ceil.(Int64, flow_size ./ tile_size)

    uv_base = Array{Float64}(undef, tile_count..., 2)
    uv_base[:,:,1] .= -max_magnitude .+ (2 .* max_magnitude .* rand(tile_count...))
    uv_base[:,:,2] .= -max_magnitude .+ (2 .* max_magnitude .* rand(tile_count...))

    uv_flow = Array{Float64}(undef, tile_size*tile_count[1], tile_size*tile_count[2], 2)
    uv_flow[:,:,1] .= repeat(uv_base[:,:,1], inner=(tile_size, tile_size))
    uv_flow[:,:,2] .= repeat(uv_base[:,:,2], inner=(tile_size, tile_size))

    # cut off what we dont want
    #rand_flow = zeros(Complex{Float64}, flow_size)
    rand_flow = uv_flow[1:flow_size[1], 1:flow_size[2], 1] .+ (im * uv_flow[1:flow_size[1], 1:flow_size[2], 2]);

    # blur to make it continuous
    rand_flow = smooth_with_gaussian!(rand_flow, [filter_amp, filter_amp])

    # set maximum magnitude to actually be the max_magnitude
    max_len = maximum(vec_len.(rand_flow))
    rand_flow = rand_flow .* (max_magnitude/max_len)

    return rand_flow
end

"""
    gen_chess(tile_size::Integer=50, board_size::Integer=4)

Create a chessboard image with `board_size` tiles in each dimension, where each tile is `tile_size` pixels in each dimension.
Note that `board_size` has to be even.

See also: [`imgshow`](@ref), [`gen_tiled_flow`](@ref)
"""
function gen_chess(tile_size::Integer=50, board_size::Integer=4)
    mini_board = [zeros(tile_size, tile_size) ones(tile_size, tile_size);
                  ones(tile_size, tile_size) zeros(tile_size, tile_size)]

    chessboard = repeat(mini_board, outer=(convert(Integer, (board_size/2)), convert(Integer, (board_size/2))))
    return chessboard
end

"""
    gen_init(type::Symbol=:lena; flow_args=[])

Create the usual testing data; img, imgw, flow.

# Arguments
- `img_type::Symbol=:lena`: what base image is used. [Options: `:lena`, `:chess`]
- `flow_type::Symbol=:quad`: what flow generation function is used. [Options: `:tiled`, `:quad`, `:uniform`]

# Keyword Arguments
- `flow_args=[]`: arguments passed to the flow generation function besides the flow size.
- `chess_args=[]`: arguments passed to the img generation function if `:chess` is chosen.

# Example
```@example
# chess image, warped chess image, flow with maximal displacement 20 generated by the `gen_quad_flow` function
img, imgw, flow = gen_init(:chess, :quad, flow_args=[20])
```
"""
function gen_init(img_type::Symbol=:lena, flow_type::Symbol=:quad; flow_args=[], chess_args=[])
    if img_type == :lena
        img = gen_lena()
    elseif img_type == :chess
        if chess_args == []
            img = gen_chess(50,4)
        else
            img = gen_chess((Int64.(chess_args))...)
        end
    end

    if flow_type == :quad
        flow = gen_quad_flow(size(img), flow_args...)
    elseif flow_type == :tiled
        flow = gen_tiled_flow(size(img), flow_args...)
    elseif flow_type == :uniform
        flow = gen_uniform_flow(size(img), flow_args...)
    end

    imgw = warp_img(img, -real(flow), -imag(flow))

    return img, imgw, flow
end