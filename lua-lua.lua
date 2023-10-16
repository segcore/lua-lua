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

local function lextype(type, content)
	return {type = type, content = content}
end

local types = {
	UNKNOWN = 1, 'UNKNOWN',
	IDENTIFIER = 2, 'IDENTIFIER',
	STRING = 3, 'STRING',
	NUMBER = 4, 'NUMBER',
	COMMENT = 5, 'COMMENT',
	MINUS = 6, 'MINUS',
	ASSIGN = 7, 'ASSIGN',
	CONCAT = 8, 'CONCAT',
	DOT = 9, 'DOT',
	COLON = 10, 'COLON',
	ADD = 11, 'ADD',
	MULTIPLY = 12, 'MULTIPLY',
	DIVIDE = 13, 'DIVIDE',
	REMAINDER = 14, 'REMAINDER',
	EXPONENTIATION = 15, 'EXPONENTIATION',
	LENGTH = 16, 'LENGTH',
	BIT_AND = 17, 'BIT_AND',
	BIT_NOT = 18, 'BIT_NOT',
	BIT_OR = 19, 'BIT_OR',
	BIT_SHIFT_LEFT = 20, 'BIT_SHIFT_LEFT',
	BIT_SHIFT_RIGHT = 21, 'BIT_SHIFT_RIGHT',
	DIVIDE_INTEGER = 22, 'DIVIDE_INTEGER',
	CHECK_EQUAL = 23, 'CHECK_EQUAL',
	CHECK_UNEQUAL = 24, 'CHECK_UNEQUAL',
	CHECK_LT = 25, 'CHECK_LT',
	CHECK_GT = 26, 'CHECK_GT',
	CHECK_LE = 27, 'CHECK_LE',
	CHECK_GE = 28, 'CHECK_GE',
	SEMICOLON = 29, 'SEMICOLON',
	VAR_ARGS = 30, 'VAR_ARGS',
	PAREN_OPEN = 31, 'PAREN_OPEN',
	PAREN_CLOSE = 32, 'PAREN_CLOSE',
	CURLY_OPEN = 33, 'CURLY_OPEN',
	CURLY_CLOSE = 34, 'CURLY_CLOSE',
	SQUARE_OPEN = 35, 'SQUARE_OPEN',
	SQUARE_CLOSE = 36, 'SQUARE_CLOSE',
	COMMA = 37, 'COMMA',
	LABEL_TAG = 38, 'LABEL_TAG',

	-- keywords
	AND = 39, 'and',
	BREAK = 40, 'break',
	DO = 41, 'do',
	ELSE = 42, 'else',
	ELSEIF = 43, 'elseif',
	END = 44, 'end',
	FALSE = 45, 'false',
	FOR = 46, 'for',
	FUNCTION = 47, 'function',
	GOTO = 48, 'goto',
	IF = 49, 'if',
	IN = 50, 'in',
	LOCAL = 51, 'local',
	NIL = 52, 'nil',
	NOT = 53, 'not',
	OR = 54, 'or',
	REPEAT = 55, 'repeat',
	RETURN = 56, 'return',
	THEN = 57, 'then',
	TRUE = 58, 'true',
	UNTIL = 59, 'until',
	WHILE = 60, 'while',

	KEYWORDS_BEGIN = 39,
	KEYWORDS_END = 60,
}

-- Because we put the string of the token immediately after and we start at 1
-- and count up, just like lua, then the string also lands at the same index as
-- our identifer name. Thanks, Lua!
local function type_string(type)
	return types[type]
end

-- todo: parse args
if true then
	io.input('token_list')
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
			elseif char2 == 'a' then result = '\a'
			elseif char2 == 'b' then result = '\b'
			elseif char2 == 'f' then result = '\f'
			elseif char2 == 't' then result = '\t'
			elseif char2 == 'v' then result = '\v'
			elseif char2 == '\n' then result = '\n'
			elseif char2 == '\\' then result = '\\'
			elseif char2 == '"' then result = '\"'
			elseif char2 == "'" then result = "'"
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

local function parse_long_string(parser, opening)
	local str = ''
	local ending = ']' .. string.rep('=', #opening - 2) .. ']'
	local pattern = ending .. '$'
	while true do
		local char = parser.next()
		if not char then error('No end of string for long string') end
		str = str .. char

		if string.match(str, pattern) then
			str = string.sub(str, 1, #str - #ending)
			break
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
			local keyword = nil
			for i = types.KEYWORDS_BEGIN, types.KEYWORDS_END do
				if identifier == type_string(i) then
					keyword = i
					break
				end
			end
			if keyword then
				yield(keyword, identifier)
			else
				yield(types.IDENTIFIER, identifier)
			end
		elseif char == '.' then
			local char2 = parser.next()
			if char2 == '.' then
				local char3 = parser.next()
				if char3 == '.' then
					yield(types.VAR_ARGS, '...')
				else
					parser.unget(char3)
					yield(types.CONCAT, '..')
				end
			else
				parser.unget(char2)
				yield(types.DOT, char)
			end
		elseif char == ':' then
			local char2 = parser.next()
			if char2 == ':' then
				yield(types.LABEL_TAG, '::')
			else
				parser.unget(char2)
				yield(types.COLON, char)
			end
		elseif char == "'" or char == '"' then
			-- Need to read up to the next unescaped '
			-- and compress the escapes along the way
			yield(types.STRING, parse_string(parser, char))
		elseif char == '=' then
			local char2 = parser.next()
			if char2 == '=' then
				yield(types.CHECK_EQUAL, '==')
			else
				parser.unget(char2)
				yield(types.ASSIGN, char)
			end
		elseif char == '<' then
			local char2 = parser.next()
			if char2 == '=' then
				yield(types.CHECK_LE, '<=')
			elseif char2 == '<' then
				yield(types.BIT_SHIFT_LEFT, '<<')
			else
				parser.unget(char2)
				yield(types.CHECK_LT, char)
			end
		elseif char == '>' then
			local char2 = parser.next()
			if char2 == '=' then
				yield(types.CHECK_GE, '>=')
			elseif char2 == '>' then
				yield(types.BIT_SHIFT_RIGHT, '>>')
			else
				parser.unget(char2)
				yield(types.CHECK_GT, char)
			end
		elseif char == '+' then
			yield(types.ADD, char)
		elseif char == '%' then
			yield(types.REMAINDER, char)
		elseif char == '^' then
			yield(types.EXPONENTIATION, char)
		elseif char == '#' then
			yield(types.LENGTH, char)
		elseif char == '&' then
			yield(types.BIT_AND, char)
		elseif char == '|' then
			yield(types.BIT_OR, char)
		elseif char == '~' then
			local char2 = parser.next()
			if char2 == '=' then
				yield(types.CHECK_UNEQUAL, '~=')
			else
				parser.unget(char2)
				yield(types.BIT_NOT, char)
			end
		elseif char == '*' then
			yield(types.MULTIPLY, char)
		elseif char == '/' then
			local char2 = parser.next()
			if char2 == '/' then
				yield(types.DIVIDE_INTEGER, '//')
			else
				parser.unget(char2)
				yield(types.DIVIDE, char)
			end
		elseif string.match(char, '%d') then
			yield(types.NUMBER, parse_number(parser, char))
		elseif char == '(' then
			yield(types.PAREN_OPEN, char)
		elseif char == ')' then
			yield(types.PAREN_CLOSE, char)
		elseif char == '[' then
			local char2 = parser.next()
			if char2 == '[' then
				yield(types.STRING, parse_long_string(parser, '[['))
			else
				parser.unget(char2)
				yield(types.SQUARE_OPEN, char)
			end
		elseif char == ']' then
			yield(types.SQUARE_CLOSE, char)
		elseif char == '{' then
			yield(types.CURLY_OPEN, char)
		elseif char == '}' then
			yield(types.CURLY_CLOSE, char)
		elseif char == ',' then
			yield(types.COMMA, char)
		else
			yield(types.UNKNOWN, char)
		end
	end
end)

for type, item in token_stream do
	print("token_stream yields " .. string.format('%12s', type_string(type)), item)
end
