local parser = {}
function parser.next()
	if parser.last then
		local last = parser.last
		parser.last = nil
		return last
	else
		return io.read(1)
	end
end
function parser.unget(c)
	parser.last = c
end


local types = {
	UNKNOWN = "UNKNOWN",
	STRING = "STRING",
	IDENTIFIER = "IDENTIFIER",
	COMMENT = "COMMENT",
	MINUS = "MINUS",
	ASSIGN = 'ASSIGN',
	CONCAT = 'CONCAT',
	DOT = 'DOT',
	LOGICAL_EQ = 'LOGICAL_EQ',
	NUMBER = "NUMBER"
	
}


-- todo: parse args
if true then
	io.input('lua-lua.lua')
end

local function parse_identifier_remains(parser, init)
	local str = init
	while true do
		local char = parser.next()
		if string.match(char, '[%w_]') then
			str = str .. char
		else
			parser.unget(char)
			break
		end
	end
	return str
end

local function parse_string(parser, quote)
	local str = ''
	while true do
		local char = parser.next()
		if not char then error('No end of string for quote ' .. quote) end
		if char == '\\' then
			local char2 = parser.next()
			local result
			if char2 == 'n' then result = '\n'
			elseif char2 == 'r' then result = '\r'
			else result = char2 end
			str = str .. result
		elseif char == quote then
			break
		else
			str = str .. char
		end
	end
	return string.format('%q', str)
end

local function parse_number(parser, init)
	local str = init
	while true do
		local char = parser.next()
		if not char then break end
		if string.match(char, '%d') then
			str = str .. char
		elseif str == '0' and (char == 'x' or char == 'X') then
			-- hexadecimal
			str = str .. char
		elseif char == '.' and not string.match(str, '%.') then
			-- it is allowed one .
			str = str .. char
		elseif char == 'e' and not string.match(str, 'e') then
			str = str .. char
		else
			parser.unget(char)
			break
		end
	end
	return str
end

local token_stream = coroutine.wrap(function()
	local yield = coroutine.yield
	while true do
		local char = parser.next()
		if not char then
			-- end of file
			break
		elseif string.match(char, '%s') then
			-- nothing to do
		elseif char == '-' then
			local char2 = parser.next()
			if char2 == '-' then
				local extra = io.read("*l")
				yield(types.COMMENT, '--' .. extra)
			else
				parser.unget(char2)
				yield(types.MINUS, '-')
			end
		elseif string.match(char, '%a') then
			-- Some letter - maybe a keyword or identifier
			-- Keep reading all letters, alphanumeric, and underscore
			local identifier = parse_identifier_remains(parser, char)
			yield(types.IDENTIFIER, identifier)
		elseif char == '.' then
			local char2 = parser.next()
			if char2 == '.' then
				yield(types.CONCAT, '..')
			else
				parser.unget(char2)
				yield(types.DOT, char)
			end
		elseif char == "'" or char == '"' then
			-- Need to read up to the next unescaped '
			-- and compress the escapes along the way
			yield(types.STRING, parse_string(parser, char))
		elseif char == '=' then
			local char2 = parser.next()
			if char2 == '=' then
				yield(types.LOGICAL_EQ, '==')
			else
				parser.unget(char2)
				yield(types.ASSIGN, char)
			end
		elseif string.match(char, '%d') then
			yield(types.NUMBER, parse_number(parser, char))
		else
			yield(types.UNKNOWN, char)
		end
	end
end)

for type, item in token_stream do
	print("token_stream yields type " .. string.format('%12s', type), item)
end

local x = {0x1234, 1.234, 1.2e10}

