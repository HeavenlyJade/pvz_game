local Perlin = {}

Perlin.NoiseData_2D = nil
Perlin.NoiseData_3D = nil


function Perlin:StaticNoise2D(x, y)
	if Perlin.NoiseData_2D == nil then
		Perlin.NoiseData_2D = {}
		for y = 1, 64 do
			Perlin.NoiseData_2D[y] = {}
			for x = 1, 64 do
				Perlin.NoiseData_2D[y][x] = self:Noise2D(x, y)
			end
		end
	end
	x = math.floor(x) % 64 + 1
	y = math.floor(y) % 64 + 1
	return Perlin.NoiseData_2D[y][x]
end

function Perlin:Noise(x, y, z)
	local x = x or 0
	local y = y or 0
	local z = z or 0
	local n = x + y * 57 + z * 57 * 57
	n = n + n / 2
	n = math.floor(n)
	n = (n % 289) + 1
	local s = math.floor((n +31) / 32)
    return (((s * s * 31 + s) * 6 + s) % 289) / 289.0
end

function Perlin:Noise3D(x, y, z, octaves, persistence)
	local total = 0
	local frequency = 1
	local amplitude = 1
	local maxValue = 0
	local d = octaves or 6
    persistence = persistence or 0.5
	for i = 1, d do
		total = total + self:Noise(x * frequency, y * frequency, z * frequency) * amplitude
		maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
	end
    return total / maxValue
end

function Perlin:Noise2D(x, y, octaves, persistence)
	local total = 0
	local frequency = 1
	local amplitude = 1
	local maxValue = 0
	local d = octaves or 6
    persistence = persistence or 0.5
	for i = 1, d do
		total = total + self:Noise(x * frequency, y * frequency) * amplitude
		maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
	end
    return total / maxValue
end

function Perlin:Noise1D(x, octaves, persistence)
	local total = 0
	local frequency = 1
	local amplitude = 1
	local maxValue = 0
	local d = octaves or 6
    persistence = persistence or 0.5
	for i = 1, d do
		total = total + self:Noise(x * frequency) * amplitude
		maxValue = maxValue + amplitude
        amplitude= amplitude * persistence
        frequency = frequency * 2
	end
    return total / maxValue
end

return Perlin