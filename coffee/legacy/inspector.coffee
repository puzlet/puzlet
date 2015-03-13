###
Echos the value of a value. Trys to print the value out
in the best way possible given the different types.

{Object} obj The object to print out.
{Object} opts Optional options object that alters the output.
Adapted from node.js object inspector.
License MIT (© Joyent)
###

inspect = (obj, opts) ->
	inspector = new Inspector obj, opts
	return inspector.formattedObj

class Inspector
	
	lf: "\n"
	
	constructor: (@obj, opts) ->
		
		# default options
		@ctx =
			seen: []
			stylize: stylizeNoColor
			
		@ctx.depth = arguments[2] if arguments.length >= 3
		@ctx.colors = arguments[3] if arguments.length >= 4
		
		_extend @ctx, opts if opts
		
		# set default options
		@ctx.showHidden ?= false
		@ctx.depth ?= 2
		@ctx.keysLimit ?= 20
		@ctx.arrayLimit ?= 20  # Not implemented yet.
		@ctx.processJQuery ?= false
		@ctx.processNumericJs ?= false
		@ctx.colors ?= false
		@ctx.customInspect ?= true
		@ctx.stylize = stylizeWithColor if @ctx.colors
		
		@formattedObj = @formatValue @obj, @ctx.depth
	
	formatValue: (value, recurseTimes) ->
		
		#v = if isFunction(value) then "(Function)" else value
		#console.log "--------recurseTimes", recurseTimes, "value", v
		
		# Provide a hook for user-specified inspect functions.
		return custom if custom = @customFormat(value)  # Possible recursion here
		
		return "[jQuery]" if not @ctx.processJQuery and value.jquery
		return "[numericjs]" if not @ctx.processNumericJs and value.name is "numeric"
		return "" if (typeof value is "string") and value.indexOf("eval_plot") is 0
		
		# Primitive types cannot have properties.
		return primitive if primitive = @formatPrimitive(value)
		
		# Look up the keys of the object.
		{keys, visibleKeys, keysLimited} = @getKeys(value) 
		
		# Some types of object without properties can be shortcutted.
		return shortcut if shortcut = @formatObjectShortcut(value, keys)
		
		baseInfo = @getBase(value)
		
		return base.braces[0] + baseInfo.base + baseInfo.braces[1] if keys.length is 0 and (not baseInfo.array or value.length is 0)
		
		return @haltProcessing(value) if recurseTimes < 0
		
		# Format as object or array.
		@ctx.seen.push value
		output = undefined
		if baseInfo.array
			output = @formatArray(value, recurseTimes, visibleKeys, keys)
		else
			output = keys.map (key) => @formatProperty(value, recurseTimes, visibleKeys, key, baseInfo.array)
		@ctx.seen.pop()
		@reduceToSingleString output, baseInfo.base, baseInfo.braces, keysLimited
	
	formatArray: (value, recurseTimes, visibleKeys, keys) ->
		
		output = []
		
		for val, i in value
			s = String(i)
			own = hasOwn(value, s)
			output.push(if own then @formatProperty(value, recurseTimes, visibleKeys, s, true) else "")
		
		for key in keys
			output.push @formatProperty(value, recurseTimes, visibleKeys, key, true) unless key.match(/^\d+$/)
		
		output
	
	formatProperty: (value, recurseTimes, visibleKeys, key, array) ->
		
		property = new ObjectProperty {
			value: value
			recurseTimes: recurseTimes
			visibleKeys: visibleKeys
			key: key
			array: array
			ctx: @ctx
			formatValue: (v, recurse) => @formatValue(v, recurse)
		}
		return property.format()
	
	formatObjectShortcut: (value, keys) ->
		
		# IE doesn't make error fields non-enumerable
		# http://msdn.microsoft.com/en-us/library/ie/dww52sbt(v=vs.94).aspx
		return @formatError(value) if isError(value) and (keys.indexOf("message") >= 0 or keys.indexOf("description") >= 0)
		
		return null if keys.length
		
		if isFunction(value)
			name = (if value.name then ": " + value.name else "")
			return @stylize("[Function" + name + "]", "special")
		
		return @stylize(RegExp::toString.call(value), "regexp") if isRegExp(value)
		return @stylize(Date::toString.call(value), "date") if isDate(value)
		return @formatError(value) if isError(value)
		
		null
	
	formatPrimitive: (value) ->
		return @stylize("undefined", "undefined") if isUndefined(value)
		if isString(value)
			simple = "'" + JSON.stringify(value).replace(/^"|"$/g, "").replace(/'/g, "\\'").replace(/\\"/g, "\"") + "'"
			return @stylize(simple, "string")
		return @stylize("" + Math.round(value*10000)/10000, "number") if isNumber(value)  # ZZZ rounding should be a parameter
		return @stylize("" + value, "boolean") if isBoolean(value)
		
		# For some reason typeof null is "object", so special case here.
		return @stylize "null", "null" if isNull(value)
		null
	
	formatError: (value) ->
		"[" + Error::toString.call(value) + "]"
	
	haltProcessing: (value) ->
		if isRegExp(value)
			@stylize(RegExp::toString.call(value), "regexp")
		else
			@stylize("[Object]", "special")
	
	reduceToSingleString: (output, base, braces, keysLimited) ->
		numLinesEst = 0
		length = reduce(output, (prev, cur) ->
			numLinesEst++
			numLinesEst++ if cur.indexOf(@lf) >= 0
			prev + cur.replace(/\u001b\[\d\d?m/g, "").length + 1
		, 0)
		return braces[0] + ((if base is "" then "" else "#{base+@lf}")) + "" + output.join(" #{@lf}") + "" + braces[1] if length > 60
		braces[0] + base + "" + output.join(", ") + "" + (if keysLimited then "..." else "") + braces[1]
		
		#return braces[0] + ((if base is "" then "" else "#{base+@lf} ")) + " " + output.join(",#{@lf}  ") + " " + braces[1] if length > 60
		#braces[0] + base + " " + output.join(", ") + " " + (if keysLimited then "..." else "") + braces[1]
	
	getBase: (value) ->
		base = ""
		array = isArray(value)
		braces = if array then ["[", "]"] else ["{", "}"]
		
		# Make functions say that they are functions
		if isFunction(value)
			n = (if value.name then ": " + value.name else "")
			base = " [Function" + n + "]"
			
		# Make RegExps say that they are RegExps
		base = " " + RegExp::toString.call(value) if isRegExp(value)
		
		# Make dates with properties first say the date
		base = " " + Date::toUTCString.call(value) if isDate(value)
		
		# Make error with message first say the error
		base = " " + @formatError(value) if isError(value)
		
		{base, braces, array}
	
	getKeys: (value) ->
		keys = objectKeys value
		keysLimited = keys.length > @ctx.keysLimit
		keys = keys[..@ctx.keysLimit-1] if keysLimited
		visibleKeys = arrayToHash keys
		try
			keys = Object.getOwnPropertyNames(value) if @ctx.showHidden and Object.getOwnPropertyNames  # ZZZ dangerous?
		{keys, visibleKeys, keysLimited}
	
	customFormat: (value, recurseTimes) ->
		# Check that value is an object with an inspect function on it.
		# Filter out the util module because its inspect function is special.
		# Also filter out any prototype objects using the circular check.
		custom =
			@ctx.customInspect and
			value and 
			isFunction(value.inspect) and
			value.inspect isnt inspect and 
			not (value.constructor and value.constructor:: is value)
		return null unless custom
		ret = value.inspect(recurseTimes, @ctx)
		ret = @formatValue(ret, recurseTimes) unless isString(ret)  # Recursion
		ret
	
	stylize: (value) ->
		@ctx.stylize value
	


class ObjectProperty
	
	lf: "\n"
	
	constructor: (@spec) ->
		@value = @spec.value
		@key = @spec.key
		@desc = value: undefined
		try
			# ie6 › navigator.toString
			# throws Error: Object doesn't support this property or method
			@desc.value = @value[@key]
		try
			# ie10 › Object.getOwnPropertyDescriptor(window.location, 'hash')
			# throws TypeError: Object doesn't support this action
			@desc = Object.getOwnPropertyDescriptor(@value, @key) or desc if Object.getOwnPropertyDescriptor
	
	format: ->
		str = @val()
		return str if @spec.array and @key.match(/^\d+$/)
		name = @name(str)
		"#{name}:#{str}"
	
	name: (str) ->
		return "[" + @key + "]" unless hasOwn(@spec.visibleKeys, @key)
		name = JSON.stringify "#{@key}"
		if name.match(/^"([a-zA-Z_][a-zA-Z_0-9]*)"$/)
			name = name.substr(1, name.length - 2)
			name = @stylize name, "name"
		else
			name = name.replace(/'/g, "\\'").replace(/\\"/g, "\"").replace(/(^"|"$)/g, "'")
			name = @stylize name, "string"
		name
	
	val: ->
		return str if str = @getterSetter()
		return @stylize("[Circular]", "special") if @spec.ctx.seen.indexOf(@desc.value) isnt -1  # ZZZ use method?
		
		nextRecurse = if isNull(@spec.recurseTimes) then null else @spec.recurseTimes - 1
		str = @spec.formatValue(@desc.value, nextRecurse)  # Recursion
		return str unless str.indexOf(@lf) isnt -1
		
		lines = str.split "\n"
		array = @spec.array
		spaces = if array then "" else ""
#		spaces = if array then " " else "  "
		#spaces = if array then "  " else "   "
		l = lines.map((line) -> spaces + line).join(@lf)
		str = if array then l.substr(0) else @lf + l
		#str = if array then l.substr(2) else @lf + l
	
	getterSetter: ->
		str = null
		if @desc.get
			if @desc.set
				str @stylize("[Getter/Setter]", "special")
			else
				str = @stylize("[Getter]", "special")
		else if @desc.set
			str = @stylize("[Setter]", "special")
		str
	
	stylize: (x) ->
		@spec.ctx.stylize x
	

#----------------------------------------------------------------------------------------------#

objectKeys = (val) ->
	Object.keys val if Object.keys

_extend = (origin, add) ->
	# Don't do anything if add isn't an object
	return origin  if not add or not isObject(add)
	keys = objectKeys(add)
	i = keys.length
	origin[keys[i]] = add[keys[i]] while i--
	origin

isArray = (v) ->
	v.constructor is Array

reduce = (array, f) ->
	return 0 unless array  # MVC not sure about this...
	array.reduce f

# indexOf edited inline

stylizeNoColor = (str, styleType) ->
	str

isBoolean = (arg) ->
	typeof arg is "boolean"

isUndefined = (arg) ->
	arg is undefined

stylizeWithColor = (str, styleType) ->
	style = inspect.styles[styleType]
	if style
		"\u001b[" + inspect.colors[style][0] + "m" + str + "\u001b[" + inspect.colors[style][1] + "m"
	else
		str
isFunction = (arg) ->
	typeof arg is "function"

isString = (arg) ->
	typeof arg is "string"

isNumber = (arg) ->
	typeof arg is "number"

isNull = (arg) ->
	arg is null

hasOwn = (obj, prop) ->
	Object::hasOwnProperty.call obj, prop

isRegExp = (re) ->
	isObject(re) and objectToString(re) is "[object RegExp]"

isObject = (arg) ->
	typeof arg is "object" and arg isnt null

isError = (e) ->
	isObject(e) and (objectToString(e) is "[object Error]" or e instanceof Error)

isDate = (d) ->
	isObject(d) and objectToString(d) is "[object Date]"

objectToString = (o) ->
	Object::toString.call o

arrayToHash = (array) ->
	hash = {}
	hash[val] = true for val in array
	hash

# ZZZ later, make thise Inspector static properties?
inspect.colors =
	bold: [1, 22]
	italic: [3, 23]
	underline: [4, 24]
	inverse: [7, 27]
	white: [37, 39]
	grey: [90, 39]
	black: [30, 39]
	blue: [34, 39]
	cyan: [36, 39]
	green: [32, 39]
	magenta: [35, 39]
	red: [31, 39]
	yellow: [33, 39]

inspect.styles =
	special: "cyan"
	number: "yellow"
	boolean: "yellow"
	undefined: "grey"
	null: "bold"
	string: "green"
	date: "magenta"
	regexp: "red"

window.$inspect2 = inspect # MVC - export